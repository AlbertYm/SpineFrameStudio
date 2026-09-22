function Get-SpineCliPath {
    param([string]$ConfiguredPath = '')
    $candidates = New-Object 'System.Collections.Generic.List[string]'
    if (-not [string]::IsNullOrWhiteSpace($ConfiguredPath)) { $candidates.Add($ConfiguredPath) }
    try {
        $command = Get-Command Spine.com -ErrorAction Stop
        if ($command.Source) { $candidates.Add($command.Source) }
    } catch {}
    if ($env:ProgramFiles) { $candidates.Add((Join-Path $env:ProgramFiles 'Spine\Spine.com')) }
    if (${env:ProgramFiles(x86)}) { $candidates.Add((Join-Path ${env:ProgramFiles(x86)} 'Spine\Spine.com')) }
    if ($env:LOCALAPPDATA) { $candidates.Add((Join-Path $env:LOCALAPPDATA 'Spine\Spine.com')) }
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    return $null
}

function Get-UniqueDirectory {
    param([Parameter(Mandatory=$true)][string]$Parent, [Parameter(Mandatory=$true)][string]$Name)
    [void](New-Item -ItemType Directory -Path $Parent -Force)
    $safe = $Name -replace '[\\/:*?"<>|]', '_'
    if ([string]::IsNullOrWhiteSpace($safe)) { $safe = 'spine_animation' }
    $candidate = Join-Path $Parent $safe
    $index = 2
    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path $Parent ('{0}_{1:D3}' -f $safe, $index)
        $index++
    }
    [void](New-Item -ItemType Directory -Path $candidate)
    return $candidate
}

function Get-PngSequenceInfo {
    param([Parameter(Mandatory=$true)][string]$FramesFolder)
    Add-Type -AssemblyName System.Drawing
    $files = @(Get-ChildItem -LiteralPath $FramesFolder -File -Filter '*.png' | Sort-Object Name)
    if ($files.Count -eq 0) { throw "没有可用于 Spine 的 PNG：$FramesFolder" }
    $width = 0; $height = 0
    foreach ($file in $files) {
        $image = [Drawing.Image]::FromFile($file.FullName)
        try {
            if ($width -eq 0) { $width = $image.Width; $height = $image.Height }
            elseif ($image.Width -ne $width -or $image.Height -ne $height) {
                throw "序列帧画布不一致：$($file.Name) 是 $($image.Width)x$($image.Height)，预期 ${width}x${height}。"
            }
        } finally { $image.Dispose() }
    }
    return [pscustomobject]@{ Files=$files; Width=$width; Height=$height; Count=$files.Count }
}

function Invoke-SpineProcess {
    param(
        [Parameter(Mandatory=$true)][string]$SpinePath,
        [Parameter(Mandatory=$true)][string[]]$Arguments,
        [Parameter(Mandatory=$true)][string]$LogPath
    )
    $errorPath = $LogPath + '.stderr'
    $quotedArguments = @($Arguments | ForEach-Object { $value=[string]$_; if($value -match '\s'){ '"' + $value.Replace('"','\"') + '"' } else { $value } })
    $process = Start-Process -FilePath $SpinePath -ArgumentList $quotedArguments -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $LogPath -RedirectStandardError $errorPath
    if (Test-Path -LiteralPath $errorPath) {
        $errorText = Get-Content -LiteralPath $errorPath -Raw -ErrorAction SilentlyContinue
        if ($errorText) { [IO.File]::AppendAllText($LogPath, [Environment]::NewLine + $errorText, [Text.UTF8Encoding]::new($false)) }
        Remove-Item -LiteralPath $errorPath -Force -ErrorAction SilentlyContinue
    }
    if ($process.ExitCode -ne 0) {
        $tail = if (Test-Path -LiteralPath $LogPath) { (Get-Content -LiteralPath $LogPath -Tail 20 -Encoding UTF8) -join ' ' } else { '' }
        throw "Spine 命令失败（退出码 $($process.ExitCode)）：$tail"
    }
}

function Export-SpineTemplateJson {
    param(
        [Parameter(Mandatory=$true)][string]$TemplatePath,
        [Parameter(Mandatory=$true)][string]$SpinePath,
        [Parameter(Mandatory=$true)][string]$WorkingDirectory,
        [string]$SpineVersion = '4.1.24'
    )
    if (-not (Test-Path -LiteralPath $TemplatePath -PathType Leaf)) { throw "Spine 模板不存在：$TemplatePath" }
    if ([IO.Path]::GetExtension($TemplatePath).ToLowerInvariant() -eq '.json') { return (Resolve-Path -LiteralPath $TemplatePath).Path }
    $exportFolder = Join-Path $WorkingDirectory 'template-export'
    [void](New-Item -ItemType Directory -Path $exportFolder)
    $log = Join-Path $WorkingDirectory 'spine-template-export.log'
    Invoke-SpineProcess -SpinePath $SpinePath -Arguments @('--update',$SpineVersion,'--input',$TemplatePath,'--output',$exportFolder,'--export','json') -LogPath $log
    $jsonFiles = @(Get-ChildItem -LiteralPath $exportFolder -File -Filter '*.json' | Where-Object { $_.Name -notlike '*.export.json' })
    if ($jsonFiles.Count -ne 1) { throw "模板导出后应得到 1 个 Skeleton JSON，实际得到 $($jsonFiles.Count) 个。详见 $log" }
    return $jsonFiles[0].FullName
}

function Add-JsonProperty {
    param([Parameter(Mandatory=$true)]$Object, [Parameter(Mandatory=$true)][string]$Name, $Value)
    $existing = $Object.PSObject.Properties[$Name]
    if ($null -ne $existing) { $Object.$Name = $Value }
    else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function New-BasicSpineData {
    param([int]$Width, [int]$Height, [string]$SlotName, [string]$SpineVersion)
    $halfWidth = $Width / 2.0; $halfHeight = $Height / 2.0
    return [pscustomobject][ordered]@{
        skeleton = [pscustomobject][ordered]@{ hash=''; spine=$SpineVersion; x=-$halfWidth; y=-$halfHeight; width=$Width; height=$Height; images='./images/' }
        bones = @([pscustomobject][ordered]@{ name='root' })
        slots = @([pscustomobject][ordered]@{ name=$SlotName; bone='root' })
        skins = @([pscustomobject][ordered]@{ name='default'; attachments=[pscustomobject]@{} })
        animations = [pscustomobject]@{}
    }
}

function Find-ClippedTargetSlot {
    param($Data)
    $slotNames = @($Data.slots | ForEach-Object { [string]$_.name })
    foreach ($skin in @($Data.skins)) {
        if ($null -eq $skin.attachments) { continue }
        foreach ($slotProperty in $skin.attachments.PSObject.Properties) {
            foreach ($attachmentProperty in $slotProperty.Value.PSObject.Properties) {
                $attachment = $attachmentProperty.Value
                if ([string]$attachment.type -ne 'clipping') { continue }
                $startIndex = [Array]::IndexOf($slotNames, [string]$slotProperty.Name)
                $endIndex = if ($attachment.end) { [Array]::IndexOf($slotNames, [string]$attachment.end) } else { $slotNames.Count }
                if ($startIndex -ge 0) {
                    for ($i=$startIndex+1; $i -lt $slotNames.Count -and ($endIndex -lt 0 -or $i -le $endIndex); $i++) { return $slotNames[$i] }
                }
            }
        }
    }
    return $null
}

function Add-SpineFrameAnimation {
    param(
        [Parameter(Mandatory=$true)]$Data,
        [Parameter(Mandatory=$true)]$Sequence,
        [Parameter(Mandatory=$true)][string]$AnimationName,
        [Parameter(Mandatory=$true)][string]$SlotName,
        [Parameter(Mandatory=$true)][double]$Fps,
        [Parameter(Mandatory=$true)][bool]$Loop,
        [Parameter(Mandatory=$true)][string]$ImageSubfolder
    )
    $slot = @($Data.slots | Where-Object { [string]$_.name -eq $SlotName } | Select-Object -First 1)
    if ($slot.Count -eq 0) { throw "模板中没有 Slot：$SlotName" }
    $skin = @($Data.skins | Where-Object { [string]$_.name -eq 'default' } | Select-Object -First 1)
    if ($skin.Count -eq 0) { $skin = @($Data.skins | Select-Object -First 1) }
    if ($skin.Count -eq 0) { throw '模板没有可写入的 Skin。' }
    if ($null -eq $skin[0].attachments) { Add-JsonProperty $skin[0] 'attachments' ([pscustomobject]@{}) }
    $slotAttachments = $skin[0].attachments.PSObject.Properties[$SlotName]
    if ($null -eq $slotAttachments) {
        Add-JsonProperty $skin[0].attachments $SlotName ([pscustomobject]@{})
        $slotAttachments = $skin[0].attachments.PSObject.Properties[$SlotName]
    }
    $keys = New-Object System.Collections.Generic.List[object]
    for ($i=0; $i -lt $Sequence.Files.Count; $i++) {
        $baseName = [IO.Path]::GetFileNameWithoutExtension($Sequence.Files[$i].Name)
        $attachmentName = $AnimationName + '/' + $baseName
        $attachment = [pscustomobject][ordered]@{ name=($ImageSubfolder+'/'+$baseName); width=$Sequence.Width; height=$Sequence.Height }
        Add-JsonProperty $slotAttachments.Value $attachmentName $attachment
        $key = [ordered]@{ name=$attachmentName }
        if ($i -gt 0) { $key.time = [Math]::Round($i / $Fps, 6) }
        $keys.Add([pscustomobject]$key)
    }
    $duration = [Math]::Round($Sequence.Files.Count / $Fps, 6)
    $endName = if ($Loop) { $AnimationName + '/' + [IO.Path]::GetFileNameWithoutExtension($Sequence.Files[0].Name) } else { $AnimationName + '/' + [IO.Path]::GetFileNameWithoutExtension($Sequence.Files[$Sequence.Files.Count-1].Name) }
    $keys.Add([pscustomobject][ordered]@{ time=$duration; name=$endName })
    Add-JsonProperty $slot[0] 'attachment' ($AnimationName + '/' + [IO.Path]::GetFileNameWithoutExtension($Sequence.Files[0].Name))
    if ($null -eq $Data.animations) { Add-JsonProperty $Data 'animations' ([pscustomobject]@{}) }
    $animation = [pscustomobject][ordered]@{ slots=[pscustomobject]@{} }
    $slotTimeline = [pscustomobject][ordered]@{ attachment=$keys.ToArray() }
    Add-JsonProperty $animation.slots $SlotName $slotTimeline
    Add-JsonProperty $Data.animations $AnimationName $animation
    return $duration
}

function Copy-TemplateImages {
    param($Data, [string]$TemplatePath, [string]$DestinationImages)
    if ([IO.Path]::GetExtension($TemplatePath).ToLowerInvariant() -eq '.json') { $base = Split-Path -Parent $TemplatePath }
    else { $base = Split-Path -Parent $TemplatePath }
    $imagesSetting = if ($Data.skeleton -and $Data.skeleton.images) { [string]$Data.skeleton.images } else { './images/' }
    if ([IO.Path]::IsPathRooted($imagesSetting)) { $source = $imagesSetting }
    else { $source = [IO.Path]::GetFullPath((Join-Path $base $imagesSetting)) }
    if (Test-Path -LiteralPath $source -PathType Container) {
        Get-ChildItem -LiteralPath $source -Force | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $DestinationImages -Recurse -Force }
    }
}

function New-SpineAnimationProject {
    param(
        [Parameter(Mandatory=$true)][string]$FramesFolder,
        [Parameter(Mandatory=$true)][string]$OutputRoot,
        [Parameter(Mandatory=$true)][string]$AnimationName,
        [double]$Fps = 12,
        [bool]$Loop = $true,
        [string]$TemplatePath = '',
        [string]$TargetSlot = '',
        [string]$SpinePath = '',
        [string]$SpineVersion = '4.1.24'
    )
    if ($Fps -le 0 -or $Fps -gt 240) { throw 'Spine 动画 FPS 必须大于 0 且不超过 240。' }
    $safeAnimation = ($AnimationName -replace '[\\/:*?"<>|]', '_').Trim()
    if ([string]::IsNullOrWhiteSpace($safeAnimation)) { throw '请填写 Spine 动画名称。' }
    $sequence = Get-PngSequenceInfo -FramesFolder $FramesFolder
    $projectFolder = Get-UniqueDirectory -Parent $OutputRoot -Name ($safeAnimation + '_spine')
    $imagesFolder = Join-Path $projectFolder 'images'
    [void](New-Item -ItemType Directory -Path $imagesFolder)
    $cli = Get-SpineCliPath -ConfiguredPath $SpinePath
    $templateJson = $null
    if (-not [string]::IsNullOrWhiteSpace($TemplatePath)) {
        if ($null -eq $cli -and [IO.Path]::GetExtension($TemplatePath).ToLowerInvariant() -eq '.spine') { throw '使用 .spine 模板需要安装 Spine，并能找到 Spine.com。' }
        $templateJson = Export-SpineTemplateJson -TemplatePath $TemplatePath -SpinePath $cli -WorkingDirectory $projectFolder -SpineVersion $SpineVersion
        $data = Get-Content -LiteralPath $templateJson -Raw -Encoding UTF8 | ConvertFrom-Json
        Copy-TemplateImages -Data $data -TemplatePath $TemplatePath -DestinationImages $imagesFolder
        Add-JsonProperty $data.skeleton 'images' './images/'
        if ([string]::IsNullOrWhiteSpace($TargetSlot)) { $TargetSlot = Find-ClippedTargetSlot -Data $data }
        if ([string]::IsNullOrWhiteSpace($TargetSlot)) { throw '无法自动确定 Mask 内的目标 Slot，请填写目标 Slot 名称。' }
    } else {
        if ([string]::IsNullOrWhiteSpace($TargetSlot)) { $TargetSlot = 'sequence' }
        $data = New-BasicSpineData -Width $sequence.Width -Height $sequence.Height -SlotName $TargetSlot -SpineVersion $SpineVersion
    }
    $sequenceImages = Join-Path $imagesFolder $safeAnimation
    [void](New-Item -ItemType Directory -Path $sequenceImages -Force)
    foreach ($file in $sequence.Files) { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $sequenceImages $file.Name) }
    $duration = Add-SpineFrameAnimation -Data $data -Sequence $sequence -AnimationName $safeAnimation -SlotName $TargetSlot -Fps $Fps -Loop $Loop -ImageSubfolder $safeAnimation
    $jsonPath = Join-Path $projectFolder ($safeAnimation + '.json')
    [IO.File]::WriteAllText($jsonPath, ($data | ConvertTo-Json -Depth 100), [Text.UTF8Encoding]::new($false))
    $projectPath = Join-Path $projectFolder ($safeAnimation + '.spine')
    $state = 'json-only'
    $logPath = Join-Path $projectFolder 'spine-import.log'
    if ($null -ne $cli) {
        Invoke-SpineProcess -SpinePath $cli -Arguments @('--update',$SpineVersion,'--input',$jsonPath,'--output',$projectPath,'--import',$safeAnimation) -LogPath $logPath
        if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) { throw "Spine 返回成功，但未生成工程：$projectPath" }
        $state = 'project-created'
    }
    $report = [ordered]@{
        schemaVersion=1; createdAt=(Get-Date).ToString('o'); state=$state; animation=$safeAnimation; fps=$Fps; loop=$Loop
        frames=$sequence.Count; width=$sequence.Width; height=$sequence.Height; durationSeconds=$duration; targetSlot=$TargetSlot
        template=if($TemplatePath){(Resolve-Path -LiteralPath $TemplatePath).Path}else{$null}; maskPreservation=if($TemplatePath){'template-runtime-data'}else{'not-applicable'}
        json=$jsonPath; project=if(Test-Path -LiteralPath $projectPath){$projectPath}else{$null}; spineCli=$cli; spineVersion=$SpineVersion
    }
    $reportPath = Join-Path $projectFolder 'spine-generation-report.json'
    [IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    return [pscustomobject]@{ Folder=$projectFolder; Json=$jsonPath; Project=if(Test-Path -LiteralPath $projectPath){$projectPath}else{$null}; Report=$reportPath; State=$state; TargetSlot=$TargetSlot; Frames=$sequence.Count }
}
