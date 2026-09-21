param([Parameter(Mandatory=$true)][string]$JobDirectory)
$ErrorActionPreference='Stop'
$Script:ToolDir=$PSScriptRoot
$config=Get-Content -LiteralPath (Join-Path $JobDirectory 'config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$script:jobState=@{state='running';completed=0;total=@($config.videos).Count;phase='准备素材';current='';outputs=@();preview=$null;error=''}
function Save-JobState {
    $tmp=Join-Path $JobDirectory 'status.tmp'
    [IO.File]::WriteAllText($tmp,($script:jobState|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tmp -Destination (Join-Path $JobDirectory 'status.json') -Force
}
try {
    $env:TEMP=Join-Path $JobDirectory 'temp'
    [void](New-Item -ItemType Directory -Path $env:TEMP -Force)
    . (Join-Path $Script:ToolDir 'extract_frames_core.ps1')
    function Write-ToolLog {
        param([object]$LogBox,[string]$Message)
        [IO.File]::AppendAllText((Join-Path $JobDirectory 'activity.log'), ('['+(Get-Date -Format 'HH:mm:ss')+'] '+$Message+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
        $script:jobState.phase=switch -Regex ($Message) {
            'Preparing|temp copy' {'准备素材';break}
            'Extracting|Exporting at|Final frame output' {'正在抽帧';break}
            'background|Background|Color range|picked samples' {'处理透明背景';break}
            'outline' {'处理描边';break}
            'resiz|Resize' {'调整画布';break}
            'GIF' {'生成 GIF';break}
            default {$script:jobState.phase}
        }
        Save-JobState
    }
    $arguments=@{}
    foreach($property in $config.arguments.PSObject.Properties){$arguments[$property.Name]=$property.Value}
    Save-JobState
    if($config.operation -eq 'resize') {
        $script:jobState.total=1
        $folder=Resize-ImagesToCanvas @arguments
        if($config.outline.Enabled -and $config.outline.Width -gt 0){
            $folder=Add-OutlineToFrames -FramesFolder $folder -UseOutline $true -OutlineWidth $config.outline.Width -OutlineColorHex $config.outline.Color -OutlinePosition $config.outline.Position
        }
        $script:jobState.outputs=@($folder);$script:jobState.completed=1
    } else {
        foreach($video in $config.videos) {
            # Cooperative stop completes the current file and its core cleanup.
            if(Test-Path -LiteralPath (Join-Path $JobDirectory 'stop')){$script:jobState.state='stopped';break}
            $script:jobState.current=[IO.Path]::GetFileName($video)
            $script:jobState.phase='准备素材';Save-JobState
            if($config.operation -eq 'preview') {
                $preview=New-PreviewFrame -VideoPath $video @arguments
                # Preview reflects the disabled cutout switch too.
                if(!$config.removeBackground){
                    $preview.Cutout=$preview.Original
                    if($arguments.TargetWidth -gt 0 -and $arguments.TargetHeight -gt 0){
                        $previewFolder=Join-Path $JobDirectory 'preview-canvas'
                        [void](New-Item -ItemType Directory -Path $previewFolder)
                        Copy-Item -LiteralPath $preview.Original -Destination (Join-Path $previewFolder 'frame.png')
                        $resized=Resize-ImagesToCanvas -ImageFolder $previewFolder -TargetWidth $arguments.TargetWidth -TargetHeight $arguments.TargetHeight
                        $preview.Cutout=(Get-ChildItem -LiteralPath $resized -Filter '*.png'|Select-Object -First 1).FullName
                    }
                    if($arguments.UseOutline -and $arguments.OutlineWidth -gt 0){
                        $outlineFolder=Join-Path $JobDirectory 'preview-outline'
                        [void](New-Item -ItemType Directory -Path $outlineFolder)
                        Copy-Item -LiteralPath $preview.Cutout -Destination (Join-Path $outlineFolder 'frame.png')
                        $outlined=Add-OutlineToFrames -FramesFolder $outlineFolder -UseOutline $true -OutlineWidth $arguments.OutlineWidth -OutlineColorHex $arguments.OutlineColorHex -OutlinePosition $arguments.OutlinePosition
                        $preview.Cutout=(Get-ChildItem -LiteralPath $outlined -Filter '*.png'|Select-Object -First 1).FullName
                    }
                }
                $script:jobState.preview=$preview
            } else {
                $folder=Convert-VideoToFrames -VideoPath $video @arguments
                $script:jobState.outputs+=@($folder)
            }
            $script:jobState.completed++;Save-JobState
        }
    }
    if($script:jobState.state -eq 'running'){$script:jobState.state='done'}
} catch {$script:jobState.state='failed';$script:jobState.error=$_.Exception.Message}
finally {Save-JobState}
