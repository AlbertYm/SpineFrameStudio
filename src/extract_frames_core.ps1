Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Get-CoreDirectory {
    if ($Script:ToolDir -and -not [string]::IsNullOrWhiteSpace($Script:ToolDir)) { return $Script:ToolDir }
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { return $PSScriptRoot }
    try {
        $processPath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        if (-not [string]::IsNullOrWhiteSpace($processPath)) { return (Split-Path -Parent $processPath) }
    } catch {}
    return (Get-Location).Path
}

function Get-FFmpegPath {
    $toolDir = Get-CoreDirectory
    $candidates = @(
        (Join-Path $toolDir 'ffmpeg.exe'),
        (Join-Path $toolDir 'tools\ffmpeg.exe'),
        (Join-Path (Split-Path -Parent $toolDir) 'ffmpeg.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    $cmd = Get-Command ffmpeg.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Test-VideoFile {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    return @('.mp4','.mov','.avi','.mkv','.webm','.m4v','.wmv','.gif') -contains $ext
}

function Test-ImageFile {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    return @('.png','.jpg','.jpeg','.bmp','.gif','.tif','.tiff') -contains $ext
}

function Get-SafeFolderName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return 'video' }
    $safe = [regex]::Replace($Name, '[<>:"/\\|?*]', '_').Trim().TrimEnd('.')
    if ([string]::IsNullOrWhiteSpace($safe)) { return 'video' }
    return $safe
}

function New-UniqueFolderFromName {
    param([string]$Root, [string]$BaseName)
    $safe = Get-SafeFolderName -Name $BaseName
    $candidate = Join-Path $Root $safe
    if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $candidate = Join-Path $Root ($safe + '_' + $stamp)
    if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }
    $i = 2
    while ($true) {
        $next = Join-Path $Root ($safe + '_' + $stamp + '_' + $i)
        if (-not (Test-Path -LiteralPath $next)) { return $next }
        $i++
    }
}

function New-UniqueFrameFolder {
    param([string]$VideoPath, [string]$Root)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($VideoPath)
    return New-UniqueFolderFromName -Root $Root -BaseName ($baseName + '_frames')
}

function New-CutoutFolder {
    param([string]$FramesFolder)
    $parent = Split-Path -Parent $FramesFolder
    $leaf = Split-Path -Leaf $FramesFolder
    return New-UniqueFolderFromName -Root $parent -BaseName ($leaf + '_cutout')
}

function Write-ToolLog {
    param([object]$LogBox, [string]$Message)
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $Message"
    if ($null -ne $LogBox) {
        $LogBox.AppendText($line + [Environment]::NewLine)
        $LogBox.SelectionStart = $LogBox.TextLength
        $LogBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    } else {
        Write-Host $line
    }
}

function Convert-HexToColor {
    param([string]$Hex)
    $h = $Hex.Trim()
    if ($h.StartsWith('#')) { $h = $h.Substring(1) }
    if ($h.Length -ne 6 -or $h -notmatch '^[0-9a-fA-F]{6}$') { throw 'Manual background color must be a hex value like #65DDE0. Leave it blank for auto corner color.' }
    return [System.Drawing.Color]::FromArgb(255, [Convert]::ToInt32($h.Substring(0,2),16), [Convert]::ToInt32($h.Substring(2,2),16), [Convert]::ToInt32($h.Substring(4,2),16))
}

function Get-ColorHex {
    param([System.Drawing.Color]$Color)
    return ('#{0:X2}{1:X2}{2:X2}' -f $Color.R, $Color.G, $Color.B)
}

function Get-AutoBackgroundColor {
    param([string]$FirstPng)
    $bmp = $null
    try {
        $bmp = New-Object System.Drawing.Bitmap($FirstPng)
        $samples = @(
            $bmp.GetPixel(0,0),
            $bmp.GetPixel([Math]::Max(0,$bmp.Width-1),0),
            $bmp.GetPixel(0,[Math]::Max(0,$bmp.Height-1)),
            $bmp.GetPixel([Math]::Max(0,$bmp.Width-1),[Math]::Max(0,$bmp.Height-1))
        )
        $r = [int](($samples | Measure-Object R -Average).Average)
        $g = [int](($samples | Measure-Object G -Average).Average)
        $b = [int](($samples | Measure-Object B -Average).Average)
        return [System.Drawing.Color]::FromArgb(255,$r,$g,$b)
    } finally { if ($null -ne $bmp) { $bmp.Dispose() } }
}

function Convert-HexListToColors {
    param([string]$HexList)
    $colors = New-Object 'System.Collections.Generic.List[System.Drawing.Color]'
    if ([string]::IsNullOrWhiteSpace($HexList)) { return $colors.ToArray() }
    foreach ($item in ($HexList -split '[,;\s]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) { $colors.Add((Convert-HexToColor -Hex $item)) }
    return $colors.ToArray()
}

function Resize-CanvasFit {
    param([System.Drawing.Bitmap]$SourceBitmap, [int]$TargetWidth, [int]$TargetHeight)
    if ($TargetWidth -le 0 -or $TargetHeight -le 0) { return $SourceBitmap }
    $target = New-Object System.Drawing.Bitmap($TargetWidth, $TargetHeight, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($target)
    try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(0,0,0,0))
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $scale = [Math]::Min($TargetWidth / [double]$SourceBitmap.Width, $TargetHeight / [double]$SourceBitmap.Height)
        $newW = [int][Math]::Max(1, [Math]::Round($SourceBitmap.Width * $scale))
        $newH = [int][Math]::Max(1, [Math]::Round($SourceBitmap.Height * $scale))
        $x = [int][Math]::Round(($TargetWidth - $newW) / 2)
        $y = [int][Math]::Round(($TargetHeight - $newH) / 2)
        $graphics.DrawImage($SourceBitmap, $x, $y, $newW, $newH)
        return $target
    } finally { $graphics.Dispose() }
}

function Save-TransparentPng {
    param(
        [string]$SourcePath,
        [string]$DestinationPath,
        [System.Drawing.Color]$KeyColor,
        [int]$ToleranceValue,
        [bool]$UseSoftEdge = $false,
        [int]$SoftnessValue = 20,
        [bool]$UseColorRange = $false,
        [object]$RangeColorA = $null,
        [object]$RangeColorB = $null,
        [System.Drawing.Color[]]$SampleColors = @(),
        [int]$TargetWidth = 0,
        [int]$TargetHeight = 0,
        [bool]$UseDespill = $false,
        [int]$DespillStrength = 40,
        [int]$ChokePixels = 0,
        [int]$MinAlpha = 0
    )

    $src = $null; $working = $null; $bitmapData = $null; $final = $null
    try {
        $src = New-Object System.Drawing.Bitmap($SourcePath)
        $working = New-Object System.Drawing.Bitmap($src.Width, $src.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($working)
        try {
            $graphics.Clear([System.Drawing.Color]::FromArgb(0,0,0,0))
            $graphics.DrawImage($src, 0, 0, $src.Width, $src.Height)
        } finally { $graphics.Dispose() }

        $rect = New-Object System.Drawing.Rectangle(0,0,$working.Width,$working.Height)
        $bitmapData = $working.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $stride = [Math]::Abs($bitmapData.Stride)
        $bytes = New-Object byte[] ($stride * $working.Height)
        [System.Runtime.InteropServices.Marshal]::Copy($bitmapData.Scan0, $bytes, 0, $bytes.Length)

        $keyR = [int]$KeyColor.R; $keyG = [int]$KeyColor.G; $keyB = [int]$KeyColor.B
        $useRange = ($UseColorRange -and $null -ne $RangeColorA -and $null -ne $RangeColorB)
        $rangeMinR = if ($useRange) { [Math]::Min([int]$RangeColorA.R, [int]$RangeColorB.R) } else { 0 }
        $rangeMaxR = if ($useRange) { [Math]::Max([int]$RangeColorA.R, [int]$RangeColorB.R) } else { 0 }
        $rangeMinG = if ($useRange) { [Math]::Min([int]$RangeColorA.G, [int]$RangeColorB.G) } else { 0 }
        $rangeMaxG = if ($useRange) { [Math]::Max([int]$RangeColorA.G, [int]$RangeColorB.G) } else { 0 }
        $rangeMinB = if ($useRange) { [Math]::Min([int]$RangeColorA.B, [int]$RangeColorB.B) } else { 0 }
        $rangeMaxB = if ($useRange) { [Math]::Max([int]$RangeColorA.B, [int]$RangeColorB.B) } else { 0 }
        $sampleList = @($SampleColors)
        $softLimit = [Math]::Min(255, $ToleranceValue + [Math]::Max(1, $SoftnessValue))
        $despillStrength = [Math]::Max(0, [Math]::Min(100, $DespillStrength))
        $chokePixels = [Math]::Max(0, $ChokePixels)
        $minAlpha = [Math]::Max(0, [Math]::Min(255, $MinAlpha))

        for ($y = 0; $y -lt $working.Height; $y++) {
            $rowOffset = $y * $stride
            for ($x = 0; $x -lt $working.Width; $x++) {
                $offset = $rowOffset + ($x * 4)
                $b = [int]$bytes[$offset]; $g = [int]$bytes[$offset + 1]; $r = [int]$bytes[$offset + 2]; $a = [int]$bytes[$offset + 3]
                $best = [Math]::Max([Math]::Abs($r - $keyR), [Math]::Max([Math]::Abs($g - $keyG), [Math]::Abs($b - $keyB)))
                if ($useRange) {
                    $rangeDr = 0; $rangeDg = 0; $rangeDb = 0
                    if ($r -lt $rangeMinR) { $rangeDr = $rangeMinR - $r } elseif ($r -gt $rangeMaxR) { $rangeDr = $r - $rangeMaxR }
                    if ($g -lt $rangeMinG) { $rangeDg = $rangeMinG - $g } elseif ($g -gt $rangeMaxG) { $rangeDg = $g - $rangeMaxG }
                    if ($b -lt $rangeMinB) { $rangeDb = $rangeMinB - $b } elseif ($b -gt $rangeMaxB) { $rangeDb = $b - $rangeMaxB }
                    $best = [Math]::Min($best, [Math]::Max($rangeDr, [Math]::Max($rangeDg, $rangeDb)))
                }
                if ($sampleList.Count -gt 0) {
                    foreach ($sample in $sampleList) {
                        $d = [Math]::Max([Math]::Abs($r - [int]$sample.R), [Math]::Max([Math]::Abs($g - [int]$sample.G), [Math]::Abs($b - [int]$sample.B)))
                        if ($d -lt $best) { $best = $d }
                    }
                }
                if ($best -le $ToleranceValue) {
                    $a = 0
                } elseif ($UseSoftEdge -and $best -le $softLimit) {
                    $a = [int](255 * (($best - $ToleranceValue) / [Math]::Max(1, ($softLimit - $ToleranceValue))))
                    if ($a -lt 0) { $a = 0 }
                    if ($a -gt $bytes[$offset + 3]) { $a = [int]$bytes[$offset + 3] }
                }
                if ($UseDespill -and $a -gt 0) {
                    $coverage = $a / 255.0
                    $blend = ($despillStrength / 100.0) * (1.0 - $coverage)
                    if ($blend -gt 0) {
                        $r = [int][Math]::Round($r - (($keyR - $r) * $blend))
                        $g = [int][Math]::Round($g - (($keyG - $g) * $blend))
                        $b = [int][Math]::Round($b - (($keyB - $b) * $blend))
                        $r = [Math]::Max(0, [Math]::Min(255, $r))
                        $g = [Math]::Max(0, [Math]::Min(255, $g))
                        $b = [Math]::Max(0, [Math]::Min(255, $b))
                    }
                }
                if ($chokePixels -gt 0 -and $a -gt 0) {
                    if ($x -lt $chokePixels -or $y -lt $chokePixels -or $x -ge ($working.Width - $chokePixels) -or $y -ge ($working.Height - $chokePixels)) { $a = 0 }
                }
                if ($a -lt $minAlpha) { $a = 0 }
                $bytes[$offset] = [byte]$b; $bytes[$offset + 1] = [byte]$g; $bytes[$offset + 2] = [byte]$r; $bytes[$offset + 3] = [byte]$a
            }
            if (($y % 64) -eq 0) { [System.Windows.Forms.Application]::DoEvents() }
        }

        [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $bitmapData.Scan0, $bytes.Length)
        $working.UnlockBits($bitmapData)
        $bitmapData = $null

        if ($TargetWidth -gt 0 -and $TargetHeight -gt 0) {
            $final = Resize-CanvasFit -SourceBitmap $working -TargetWidth $TargetWidth -TargetHeight $TargetHeight
            $final.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
        } else {
            $working.Save($DestinationPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
    } finally {
        if ($null -ne $bitmapData) { try { $working.UnlockBits($bitmapData) } catch {} }
        if ($null -ne $final) { $final.Dispose() }
        if ($null -ne $working) { $working.Dispose() }
        if ($null -ne $src) { $src.Dispose() }
    }
}

function Save-OutlinedPng {
    param(
        [Parameter(Mandatory=$true)][string]$SourcePath,
        [Parameter(Mandatory=$true)][string]$DestinationPath,
        [int]$OutlineWidth = 0,
        [string]$OutlineColorHex = '#000000',
        [string]$OutlinePosition = 'outside'
    )
    if ($OutlineWidth -le 0) {
        if ($SourcePath -ne $DestinationPath) { Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force }
        return
    }
    if ($OutlineWidth -gt 128) { throw 'Outline width is too large. Use a value from 1 to 128.' }

    try { $outlineColor = Convert-HexToColor -Hex $OutlineColorHex } catch { throw 'Outline color must be a hex value like #000000.' }
    $position = if ([string]::IsNullOrWhiteSpace($OutlinePosition)) { 'outside' } else { $OutlinePosition.Trim().ToLowerInvariant() }
    $insideRadius = 0
    $outsideRadius = 0
    switch ($position) {
        'inside' { $insideRadius = $OutlineWidth }
        'inner' { $insideRadius = $OutlineWidth }
        'center' { $insideRadius = [int][Math]::Ceiling($OutlineWidth / 2.0); $outsideRadius = [int][Math]::Ceiling($OutlineWidth / 2.0) }
        'middle' { $insideRadius = [int][Math]::Ceiling($OutlineWidth / 2.0); $outsideRadius = [int][Math]::Ceiling($OutlineWidth / 2.0) }
        default { $outsideRadius = $OutlineWidth }
    }
    $maxRadius = [Math]::Max($insideRadius, $outsideRadius)
    if ($maxRadius -le 0) { return }

    $src = $null; $srcStream = $null; $working = $null; $srcData = $null; $destBmp = $null; $destData = $null
    try {
        $srcBytesForLoad = [System.IO.File]::ReadAllBytes($SourcePath)
        $srcStream = New-Object System.IO.MemoryStream(,$srcBytesForLoad)
        $src = New-Object System.Drawing.Bitmap($srcStream)
        $working = New-Object System.Drawing.Bitmap($src.Width, $src.Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($working)
        try {
            $graphics.Clear([System.Drawing.Color]::FromArgb(0,0,0,0))
            $graphics.DrawImage($src, 0, 0, $src.Width, $src.Height)
        } finally { $graphics.Dispose() }

        $rect = New-Object System.Drawing.Rectangle(0,0,$working.Width,$working.Height)
        $srcData = $working.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $stride = [Math]::Abs($srcData.Stride)
        $srcBytes = New-Object byte[] ($stride * $working.Height)
        [System.Runtime.InteropServices.Marshal]::Copy($srcData.Scan0, $srcBytes, 0, $srcBytes.Length)
        $working.UnlockBits($srcData)
        $srcData = $null

        $destBytes = New-Object byte[] ($srcBytes.Length)
        [Array]::Copy($srcBytes, $destBytes, $srcBytes.Length)
        $width = $working.Width
        $height = $working.Height
        $outlineR = [byte]$outlineColor.R
        $outlineG = [byte]$outlineColor.G
        $outlineB = [byte]$outlineColor.B
        $outlineA = [byte]$outlineColor.A
        $alphaThreshold = 16

        $searchRadius = [int][Math]::Ceiling($maxRadius + 1.0)
        $offsets = New-Object 'System.Collections.Generic.List[object]'
        for ($dy = -$searchRadius; $dy -le $searchRadius; $dy++) {
            for ($dx = -$searchRadius; $dx -le $searchRadius; $dx++) {
                if ($dx -eq 0 -and $dy -eq 0) { continue }
                $dist = [Math]::Sqrt(($dx * $dx) + ($dy * $dy))
                if ($dist -le ($maxRadius + 1.0)) { $offsets.Add(@{ X = $dx; Y = $dy; Dist = $dist }) }
            }
        }
        $insideSoftLimit = $insideRadius + 1.0
        $outsideSoftLimit = $outsideRadius + 1.0
        $outlineOpacity = $outlineA / 255.0

        for ($y = 0; $y -lt $height; $y++) {
            $rowOffset = $y * $stride
            for ($x = 0; $x -lt $width; $x++) {
                $offset = $rowOffset + ($x * 4)
                $a = [int]$srcBytes[$offset + 3]
                $isSourcePixel = ($a -ge $alphaThreshold)
                $outsideCoverage = 0.0
                $insideCoverage = 0.0

                if ($outsideRadius -gt 0 -and -not $isSourcePixel) {
                    foreach ($o in $offsets) {
                        $dist = [double]$o.Dist
                        if ($dist -gt $outsideSoftLimit) { continue }
                        $nx = $x + [int]$o.X
                        $ny = $y + [int]$o.Y
                        if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $width -or $ny -ge $height) { continue }
                        $nOffset = ($ny * $stride) + ($nx * 4)
                        $nAlpha = [int]$srcBytes[$nOffset + 3]
                        if ($nAlpha -lt $alphaThreshold) { continue }
                        $edgeCoverage = $outsideSoftLimit - $dist
                        if ($edgeCoverage -gt 1.0) { $edgeCoverage = 1.0 }
                        if ($edgeCoverage -lt 0.0) { $edgeCoverage = 0.0 }
                        $candidate = $edgeCoverage * [Math]::Min(1.0, ($nAlpha / 255.0))
                        if ($candidate -gt $outsideCoverage) { $outsideCoverage = $candidate }
                    }
                }

                if ($insideRadius -gt 0 -and $isSourcePixel) {
                    foreach ($o in $offsets) {
                        $dist = [double]$o.Dist
                        if ($dist -gt $insideSoftLimit) { continue }
                        $nx = $x + [int]$o.X
                        $ny = $y + [int]$o.Y
                        $nearTransparent = $false
                        if ($nx -lt 0 -or $ny -lt 0 -or $nx -ge $width -or $ny -ge $height) {
                            $nearTransparent = $true
                        } else {
                            $nOffset = ($ny * $stride) + ($nx * 4)
                            if ([int]$srcBytes[$nOffset + 3] -lt $alphaThreshold) { $nearTransparent = $true }
                        }
                        if (-not $nearTransparent) { continue }
                        $edgeCoverage = $insideSoftLimit - $dist
                        if ($edgeCoverage -gt 1.0) { $edgeCoverage = 1.0 }
                        if ($edgeCoverage -lt 0.0) { $edgeCoverage = 0.0 }
                        if ($edgeCoverage -gt $insideCoverage) { $insideCoverage = $edgeCoverage }
                    }
                }

                if ($outsideCoverage -gt 0.0) {
                    $finalAlpha = [int][Math]::Round(255.0 * $outsideCoverage * $outlineOpacity)
                    if ($finalAlpha -gt 255) { $finalAlpha = 255 }
                    if ($finalAlpha -gt $a) {
                        $destBytes[$offset] = $outlineB
                        $destBytes[$offset + 1] = $outlineG
                        $destBytes[$offset + 2] = $outlineR
                        $destBytes[$offset + 3] = [byte]$finalAlpha
                    }
                } elseif ($insideCoverage -gt 0.0) {
                    $blend = $insideCoverage * $outlineOpacity
                    if ($blend -gt 1.0) { $blend = 1.0 }
                    $destBytes[$offset] = [byte][Math]::Max(0, [Math]::Min(255, [Math]::Round(($outlineB * $blend) + ([int]$srcBytes[$offset] * (1.0 - $blend)))))
                    $destBytes[$offset + 1] = [byte][Math]::Max(0, [Math]::Min(255, [Math]::Round(($outlineG * $blend) + ([int]$srcBytes[$offset + 1] * (1.0 - $blend)))))
                    $destBytes[$offset + 2] = [byte][Math]::Max(0, [Math]::Min(255, [Math]::Round(($outlineR * $blend) + ([int]$srcBytes[$offset + 2] * (1.0 - $blend)))))
                    $destBytes[$offset + 3] = [byte]$a
                }
            }
            if (($y % 64) -eq 0) { [System.Windows.Forms.Application]::DoEvents() }
        }

        $destBmp = New-Object System.Drawing.Bitmap($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $destData = $destBmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        [System.Runtime.InteropServices.Marshal]::Copy($destBytes, 0, $destData.Scan0, $destBytes.Length)
        $destBmp.UnlockBits($destData)
        $destData = $null

        $savePath = $DestinationPath
        $replaceOriginal = $false
        if ([string]::Equals($SourcePath, $DestinationPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $savePath = Join-Path ([System.IO.Path]::GetDirectoryName($DestinationPath)) ([System.IO.Path]::GetFileNameWithoutExtension($DestinationPath) + '.outline_tmp_' + [guid]::NewGuid().ToString('N') + '.png')
            $replaceOriginal = $true
        }
        $destBmp.Save($savePath, [System.Drawing.Imaging.ImageFormat]::Png)
        if ($replaceOriginal) { Move-Item -LiteralPath $savePath -Destination $DestinationPath -Force }
    } finally {
        if ($null -ne $destData) { try { $destBmp.UnlockBits($destData) } catch {} }
        if ($null -ne $srcData) { try { $working.UnlockBits($srcData) } catch {} }
        if ($null -ne $destBmp) { $destBmp.Dispose() }
        if ($null -ne $working) { $working.Dispose() }
        if ($null -ne $src) { $src.Dispose() }
        if ($null -ne $srcStream) { $srcStream.Dispose() }
    }
}

function Add-OutlineToFrames {
    param(
        [Parameter(Mandatory=$true)][string]$FramesFolder,
        [bool]$UseOutline = $false,
        [int]$OutlineWidth = 0,
        [string]$OutlineColorHex = '#000000',
        [string]$OutlinePosition = 'outside',
        [object]$LogBox = $null
    )
    if (-not $UseOutline -or $OutlineWidth -le 0) { return $FramesFolder }
    $frames = @(Get-ChildItem -LiteralPath $FramesFolder -Filter '*.png' -File | Sort-Object Name)
    if ($frames.Count -eq 0) { throw 'No PNG frames found for outline.' }
    Write-ToolLog -LogBox $LogBox -Message "Adding outline. Width=$OutlineWidth Color=$OutlineColorHex Position=$OutlinePosition"
    $i = 0
    foreach ($frame in $frames) {
        $i++
        Save-OutlinedPng -SourcePath $frame.FullName -DestinationPath $frame.FullName -OutlineWidth $OutlineWidth -OutlineColorHex $OutlineColorHex -OutlinePosition $OutlinePosition
        if (($i % 10) -eq 0 -or $i -eq $frames.Count) { Write-ToolLog -LogBox $LogBox -Message "Processed outline: $i / $($frames.Count)" }
    }
    return $FramesFolder
}

function Remove-SolidBackgroundFromFrames {
    param(
        [Parameter(Mandatory=$true)][string]$FramesFolder,
        [string]$ManualColor = '',
        [string]$RangeColorAHex = '',
        [string]$RangeColorBHex = '',
        [string]$SampleColorHexList = '',
        [int]$ToleranceValue = 30,
        [bool]$UseSoftEdge = $false,
        [int]$SoftnessValue = 20,
        [int]$TargetWidth = 0,
        [int]$TargetHeight = 0,
        [bool]$UseDespill = $false,
        [int]$DespillStrength = 40,
        [int]$ChokePixels = 0,
        [int]$MinAlpha = 0,
        [object]$LogBox = $null
    )

    $frames = @(Get-ChildItem -LiteralPath $FramesFolder -Filter '*.png' -File | Sort-Object Name)
    if ($frames.Count -eq 0) { throw 'No PNG frames found for background removal.' }
    $useRange = (-not [string]::IsNullOrWhiteSpace($RangeColorAHex)) -and (-not [string]::IsNullOrWhiteSpace($RangeColorBHex))
    $rangeA = $null; $rangeB = $null
    if ($useRange) {
        $rangeA = Convert-HexToColor -Hex $RangeColorAHex
        $rangeB = Convert-HexToColor -Hex $RangeColorBHex
        Write-ToolLog -LogBox $LogBox -Message "Color range enabled: $(Get-ColorHex -Color $rangeA) to $(Get-ColorHex -Color $rangeB)"
    }
    $samples = Convert-HexListToColors -HexList $SampleColorHexList
    if ($samples.Count -gt 0) { Write-ToolLog -LogBox $LogBox -Message "Extra picked samples: $($samples.Count)" }
    if ([string]::IsNullOrWhiteSpace($ManualColor)) {
        $keyColor = Get-AutoBackgroundColor -FirstPng $frames[0].FullName
        Write-ToolLog -LogBox $LogBox -Message "Auto background color from frame corners: $(Get-ColorHex -Color $keyColor)"
    } else {
        $keyColor = Convert-HexToColor -Hex $ManualColor
        Write-ToolLog -LogBox $LogBox -Message "Manual background color: $(Get-ColorHex -Color $keyColor)"
    }

    $cutoutFolder = New-CutoutFolder -FramesFolder $FramesFolder
    New-Item -ItemType Directory -Path $cutoutFolder -Force | Out-Null
    Write-ToolLog -LogBox $LogBox -Message "Cutout output folder: $cutoutFolder"
    Write-ToolLog -LogBox $LogBox -Message "Removing background. Tolerance=$ToleranceValue SoftEdge=$UseSoftEdge Softness=$SoftnessValue Resize=${TargetWidth}x${TargetHeight}"

    $i = 0
    foreach ($frame in $frames) {
        $i++
        $dest = Join-Path $cutoutFolder $frame.Name
        Save-TransparentPng -SourcePath $frame.FullName -DestinationPath $dest -KeyColor $keyColor -ToleranceValue $ToleranceValue -UseSoftEdge $UseSoftEdge -SoftnessValue $SoftnessValue -UseColorRange $useRange -RangeColorA $rangeA -RangeColorB $rangeB -SampleColors $samples -TargetWidth $TargetWidth -TargetHeight $TargetHeight -UseDespill $UseDespill -DespillStrength $DespillStrength -ChokePixels $ChokePixels -MinAlpha $MinAlpha
        Write-ToolLog -LogBox $LogBox -Message "Processed background removal: $i / $($frames.Count)"
    }
    Write-ToolLog -LogBox $LogBox -Message "Background removal done. Transparent PNG folder: $cutoutFolder"
    return $cutoutFolder
}

function Invoke-FFmpeg {
    param([string]$FFmpegPath, [string[]]$Arguments)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $output = & $FFmpegPath @Arguments 2>&1; $exit = $LASTEXITCODE } finally { $ErrorActionPreference = $old }
    return @{ ExitCode = $exit; Output = ($output | Out-String) }
}

function Copy-VideoToTemp {
    param([string]$VideoPath, [string]$TempRoot)
    $ext = [System.IO.Path]::GetExtension($VideoPath)
    if ([string]::IsNullOrWhiteSpace($ext)) { $ext = '.mp4' }
    $tempInput = Join-Path $TempRoot ('input' + $ext.ToLowerInvariant())
    Copy-Item -LiteralPath $VideoPath -Destination $tempInput -Force
    return $tempInput
}

function Get-SelectedFrameFiles {
    param([object[]]$Frames, [int]$WantedCount)
    if ($WantedCount -le 0) { throw 'Frame count must be a positive integer.' }
    if ($Frames.Count -eq 0) { throw 'No frames were created.' }
    if ($WantedCount -ge $Frames.Count) { return $Frames }
    $selected = New-Object 'System.Collections.Generic.List[object]'
    if ($WantedCount -eq 1) {
        $idx = [int][Math]::Round(($Frames.Count - 1) / 2)
        $selected.Add($Frames[$idx])
        return $selected.ToArray()
    }
    $used = @{}
    for ($i = 0; $i -lt $WantedCount; $i++) {
        $idx = [int][Math]::Round($i * (($Frames.Count - 1) / [double]($WantedCount - 1)))
        while ($used.ContainsKey($idx) -and $idx -lt ($Frames.Count - 1)) { $idx++ }
        while ($used.ContainsKey($idx) -and $idx -gt 0) { $idx-- }
        $used[$idx] = $true
        $selected.Add($Frames[$idx])
    }
    return ($selected.ToArray() | Sort-Object Name)
}

function Resize-FramesToCanvas {
    param([Parameter(Mandatory=$true)][string]$FramesFolder, [int]$TargetWidth, [int]$TargetHeight, [object]$LogBox = $null)
    if ($TargetWidth -le 0 -or $TargetHeight -le 0) { return $FramesFolder }
    $frames = @(Get-ChildItem -LiteralPath $FramesFolder -Filter '*.png' -File | Sort-Object Name)
    if ($frames.Count -eq 0) { throw 'No PNG frames found for resizing.' }
    $parent = Split-Path -Parent $FramesFolder
    $leaf = Split-Path -Leaf $FramesFolder
    $resizeFolder = New-UniqueFolderFromName -Root $parent -BaseName ($leaf + '_resized')
    New-Item -ItemType Directory -Path $resizeFolder -Force | Out-Null
    Write-ToolLog -LogBox $LogBox -Message "Resize output folder: $resizeFolder"
    $i = 0
    foreach ($frame in $frames) {
        $i++
        $src = $null; $resized = $null
        try {
            $src = New-Object System.Drawing.Bitmap($frame.FullName)
            $resized = Resize-CanvasFit -SourceBitmap $src -TargetWidth $TargetWidth -TargetHeight $TargetHeight
            $resized.Save((Join-Path $resizeFolder $frame.Name), [System.Drawing.Imaging.ImageFormat]::Png)
        } finally { if ($null -ne $resized) { $resized.Dispose() }; if ($null -ne $src) { $src.Dispose() } }
        if (($i % 10) -eq 0 -or $i -eq $frames.Count) { Write-ToolLog -LogBox $LogBox -Message "Processed resizing: $i / $($frames.Count)" }
    }
    return $resizeFolder
}

function Get-ImageFilesFromFolder {
    param([Parameter(Mandatory=$true)][string]$ImageFolder)
    if (-not (Test-Path -LiteralPath $ImageFolder -PathType Container)) { throw "Image folder does not exist: $ImageFolder" }
    return @(Get-ChildItem -LiteralPath $ImageFolder -File | Where-Object { Test-ImageFile -Path $_.FullName } | Sort-Object Name)
}

function Resize-ImagesToCanvas {
    param([Parameter(Mandatory=$true)][string]$ImageFolder, [int]$TargetWidth, [int]$TargetHeight, [object]$LogBox = $null)
    if ($TargetWidth -le 0 -or $TargetHeight -le 0) { throw 'Target size is required for image folder resizing.' }
    $images = @(Get-ImageFilesFromFolder -ImageFolder $ImageFolder)
    if ($images.Count -eq 0) { throw 'No supported image files found. Supported: png, jpg, jpeg, bmp, gif, tif, tiff.' }
    $parent = Split-Path -Parent $ImageFolder
    $leaf = Split-Path -Leaf $ImageFolder
    $resizeFolder = New-UniqueFolderFromName -Root $parent -BaseName ($leaf + '_resized')
    New-Item -ItemType Directory -Path $resizeFolder -Force | Out-Null
    Write-ToolLog -LogBox $LogBox -Message "Image resize output folder: $resizeFolder"
    Write-ToolLog -LogBox $LogBox -Message "Resizing $($images.Count) images to ${TargetWidth}x${TargetHeight} with transparent padding."
    $i = 0
    foreach ($image in $images) {
        $i++
        $src = $null; $resized = $null
        try {
            $src = New-Object System.Drawing.Bitmap($image.FullName)
            $resized = Resize-CanvasFit -SourceBitmap $src -TargetWidth $TargetWidth -TargetHeight $TargetHeight
            $destName = [System.IO.Path]::GetFileNameWithoutExtension($image.Name) + '.png'
            $resized.Save((Join-Path $resizeFolder $destName), [System.Drawing.Imaging.ImageFormat]::Png)
        } finally { if ($null -ne $resized) { $resized.Dispose() }; if ($null -ne $src) { $src.Dispose() } }
        if (($i % 10) -eq 0 -or $i -eq $images.Count) { Write-ToolLog -LogBox $LogBox -Message "Processed image resizing: $i / $($images.Count)" }
    }
    Write-ToolLog -LogBox $LogBox -Message "Image folder resizing done: $resizeFolder"
    return $resizeFolder
}

function Get-OutputFrameName {
    param([int]$Index, [string]$Prefix, [bool]$UseSpineNames)
    if ($UseSpineNames -and -not [string]::IsNullOrWhiteSpace($Prefix)) { return ('{0}_{1:D4}.png' -f (Get-SafeFolderName -Name $Prefix), $Index) }
    return ('frame_{0:D4}.png' -f $Index)
}

function Move-SelectedFramesToOutput {
    param([object[]]$SelectedFrames, [string]$OutputFolder, [bool]$UseSpineNames, [string]$Prefix)
    $i = 0
    foreach ($frame in $SelectedFrames) {
        $i++
        $name = Get-OutputFrameName -Index $i -Prefix $Prefix -UseSpineNames $UseSpineNames
        Move-Item -LiteralPath $frame.FullName -Destination (Join-Path $OutputFolder $name) -Force
    }
    return $i
}

function New-GifPreview {
    param([string]$FramesFolder, [int]$FrameRate, [object]$LogBox = $null)
    $ffmpeg = Get-FFmpegPath
    if (-not $ffmpeg) { throw 'FFmpeg was not found for GIF preview.' }
    $frames = @(Get-ChildItem -LiteralPath $FramesFolder -Filter '*.png' -File | Sort-Object Name)
    if ($frames.Count -eq 0) { throw 'No PNG frames found for GIF preview.' }
    $tempRoot = Join-Path $env:TEMP ('spine_gif_' + [guid]::NewGuid().ToString('N'))
    $tempIn = Join-Path $tempRoot 'in'
    $tempGif = Join-Path $tempRoot 'preview.gif'
    try {
        New-Item -ItemType Directory -Path $tempIn -Force | Out-Null
        $i = 0
        foreach ($frame in $frames) { $i++; Copy-Item -LiteralPath $frame.FullName -Destination (Join-Path $tempIn ('frame_{0:D4}.png' -f $i)) -Force }
        $pattern = Join-Path $tempIn 'frame_%04d.png'
        $result = Invoke-FFmpeg -FFmpegPath $ffmpeg -Arguments @('-hide_banner','-y','-framerate',([string]$FrameRate),'-i',$pattern,$tempGif)
        if ($result.ExitCode -ne 0) { throw "GIF preview failed:`n$($result.Output)" }
        $dest = Join-Path $FramesFolder 'preview.gif'
        Move-Item -LiteralPath $tempGif -Destination $dest -Force
        Write-ToolLog -LogBox $LogBox -Message "GIF preview created: $dest"
        return $dest
    } finally { if (Test-Path -LiteralPath $tempRoot) { try { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue } catch {} } }
}

function Convert-VideoToFrames {
    param(
        [Parameter(Mandatory=$true)][string]$VideoPath,
        [Parameter(Mandatory=$true)][string]$Root,
        [string]$ExtractMode = 'fps',
        [string]$FrameRate = '',
        [int]$ExactFrameCount = 10,
        [bool]$DoRemoveBg = $false,
        [string]$ManualBgColor = '',
        [string]$RangeColorAHex = '',
        [string]$RangeColorBHex = '',
        [string]$SampleColorHexList = '',
        [int]$BgTolerance = 30,
        [bool]$UseSoftEdge = $false,
        [int]$SoftnessValue = 20,
        [int]$TargetWidth = 0,
        [int]$TargetHeight = 0,
        [bool]$UseDespill = $false,
        [int]$DespillStrength = 40,
        [int]$ChokePixels = 0,
        [int]$MinAlpha = 0,
        [bool]$UseSpineNames = $false,
        [string]$Prefix = '',
        [bool]$MakePreviewGif = $false,
        [int]$PreviewGifFps = 12,
        [bool]$UseOutline = $false,
        [int]$OutlineWidth = 0,
        [string]$OutlineColorHex = '#000000',
        [string]$OutlinePosition = 'outside',
        [object]$LogBox = $null
    )

    $ffmpeg = Get-FFmpegPath
    if (-not $ffmpeg) { throw 'FFmpeg was not found. Put ffmpeg.exe in this tool folder, or install FFmpeg and add it to PATH.' }
    if (-not (Test-VideoFile -Path $VideoPath)) { throw "Unsupported video or GIF file: $VideoPath" }
    if (-not (Test-Path -LiteralPath $Root)) { New-Item -ItemType Directory -Path $Root -Force | Out-Null }

    $outFolder = New-UniqueFrameFolder -VideoPath $VideoPath -Root $Root
    New-Item -ItemType Directory -Path $outFolder -Force | Out-Null
    $tempRoot = Join-Path $env:TEMP ('spine_frames_' + [guid]::NewGuid().ToString('N'))
    $tempOut = Join-Path $tempRoot 'out'

    try {
        New-Item -ItemType Directory -Path $tempOut -Force | Out-Null
        Write-ToolLog -LogBox $LogBox -Message 'Preparing temp copy for FFmpeg path compatibility...'
        $tempInput = Copy-VideoToTemp -VideoPath $VideoPath -TempRoot $tempRoot
        $pattern = Join-Path $tempOut 'frame_%04d.png'
        $ffArgs = @('-hide_banner', '-y', '-i', $tempInput)
        $modeClean = $ExtractMode.ToLowerInvariant()
        if ($modeClean -eq 'count') {
            if ($ExactFrameCount -le 0) { throw 'Exact frame count must be a positive integer.' }
            $ffArgs += @('-vsync','0')
            Write-ToolLog -LogBox $LogBox -Message "Extracting all temp frames, then evenly selecting $ExactFrameCount frames."
        } else {
            $fpsClean = $FrameRate.Trim()
            if (-not [string]::IsNullOrWhiteSpace($fpsClean)) {
                $num = 0.0
                if (-not [double]::TryParse($fpsClean, [ref]$num) -or $num -le 0) { throw 'FPS must be a positive number.' }
                $ffArgs += @('-vf', "fps=$fpsClean")
                Write-ToolLog -LogBox $LogBox -Message "Exporting at $fpsClean fps: $VideoPath"
            } else {
                $ffArgs += @('-vsync','0')
                Write-ToolLog -LogBox $LogBox -Message "Exporting at original frame rate: $VideoPath"
            }
        }
        $ffArgs += @('-start_number','1',$pattern)
        Write-ToolLog -LogBox $LogBox -Message "Final frame output folder: $outFolder"
        $result = Invoke-FFmpeg -FFmpegPath $ffmpeg -Arguments $ffArgs
        if ($result.ExitCode -ne 0) { throw "FFmpeg failed:`n$($result.Output)" }

        $allFrames = @(Get-ChildItem -LiteralPath $tempOut -Filter '*.png' -File | Sort-Object Name)
        if ($allFrames.Count -eq 0) { throw 'FFmpeg finished, but no PNG frames were created.' }
        if ($modeClean -eq 'count') {
            if ($ExactFrameCount -gt $allFrames.Count) { Write-ToolLog -LogBox $LogBox -Message "Requested $ExactFrameCount frames, but source only produced $($allFrames.Count). Using all frames." }
            $selectedFrames = @(Get-SelectedFrameFiles -Frames $allFrames -WantedCount $ExactFrameCount)
        } else {
            $selectedFrames = $allFrames
        }

        $finalPrefix = if ([string]::IsNullOrWhiteSpace($Prefix)) { [System.IO.Path]::GetFileNameWithoutExtension($VideoPath) } else { $Prefix }
        $moved = Move-SelectedFramesToOutput -SelectedFrames $selectedFrames -OutputFolder $outFolder -UseSpineNames $UseSpineNames -Prefix $finalPrefix
        Write-ToolLog -LogBox $LogBox -Message "Frame extraction done. Exported $moved PNG files."

        $finalFolder = $outFolder
        if ($DoRemoveBg) {
            $finalFolder = Remove-SolidBackgroundFromFrames -FramesFolder $outFolder -ManualColor $ManualBgColor -RangeColorAHex $RangeColorAHex -RangeColorBHex $RangeColorBHex -SampleColorHexList $SampleColorHexList -ToleranceValue $BgTolerance -UseSoftEdge $UseSoftEdge -SoftnessValue $SoftnessValue -TargetWidth $TargetWidth -TargetHeight $TargetHeight -UseDespill $UseDespill -DespillStrength $DespillStrength -ChokePixels $ChokePixels -MinAlpha $MinAlpha -LogBox $LogBox
        } elseif ($TargetWidth -gt 0 -and $TargetHeight -gt 0) {
            $finalFolder = Resize-FramesToCanvas -FramesFolder $outFolder -TargetWidth $TargetWidth -TargetHeight $TargetHeight -LogBox $LogBox
        }
        if ($UseOutline -and $OutlineWidth -gt 0) { $finalFolder = Add-OutlineToFrames -FramesFolder $finalFolder -UseOutline $UseOutline -OutlineWidth $OutlineWidth -OutlineColorHex $OutlineColorHex -OutlinePosition $OutlinePosition -LogBox $LogBox }
        if ($MakePreviewGif) { [void](New-GifPreview -FramesFolder $finalFolder -FrameRate $PreviewGifFps -LogBox $LogBox) }
        return $finalFolder
    } finally {
        if (Test-Path -LiteralPath $tempRoot) { try { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue } catch {} }
    }
}

function New-PreviewFrame {
    param(
        [string]$VideoPath,
        [string]$ManualColor,
        [string]$RangeColorAHex,
        [string]$RangeColorBHex,
        [string]$SampleColorHexList,
        [int]$ToleranceValue,
        [bool]$UseSoftEdge,
        [int]$SoftnessValue,
        [int]$TargetWidth,
        [int]$TargetHeight,
        [bool]$UseDespill = $false,
        [int]$DespillStrength = 40,
        [int]$ChokePixels = 0,
        [int]$MinAlpha = 0,
        [bool]$UseOutline = $false,
        [int]$OutlineWidth = 0,
        [string]$OutlineColorHex = '#000000',
        [string]$OutlinePosition = 'outside',
        [object]$LogBox = $null
    )
    $ffmpeg = Get-FFmpegPath
    if (-not $ffmpeg) { throw 'FFmpeg was not found.' }
    if (-not (Test-VideoFile -Path $VideoPath)) { throw 'Choose a video or GIF file first.' }
    $tempRoot = Join-Path $env:TEMP ('spine_preview_' + [guid]::NewGuid().ToString('N'))
    $tempOut = Join-Path $tempRoot 'out'
    try {
        New-Item -ItemType Directory -Path $tempOut -Force | Out-Null
        $tempInput = Copy-VideoToTemp -VideoPath $VideoPath -TempRoot $tempRoot
        $original = Join-Path $tempOut 'preview_original.png'
        $cutout = Join-Path $tempOut 'preview_cutout.png'
        $result = Invoke-FFmpeg -FFmpegPath $ffmpeg -Arguments @('-hide_banner','-y','-i',$tempInput,'-frames:v','1',$original)
        if ($result.ExitCode -ne 0) { throw "Preview extraction failed:`n$($result.Output)" }
        $key = if ([string]::IsNullOrWhiteSpace($ManualColor)) { Get-AutoBackgroundColor -FirstPng $original } else { Convert-HexToColor -Hex $ManualColor }
        $rangeA = $null; $rangeB = $null
        $useRange = (-not [string]::IsNullOrWhiteSpace($RangeColorAHex)) -and (-not [string]::IsNullOrWhiteSpace($RangeColorBHex))
        if ($useRange) { $rangeA = Convert-HexToColor -Hex $RangeColorAHex; $rangeB = Convert-HexToColor -Hex $RangeColorBHex }
        $samples = Convert-HexListToColors -HexList $SampleColorHexList
        Save-TransparentPng -SourcePath $original -DestinationPath $cutout -KeyColor $key -ToleranceValue $ToleranceValue -UseSoftEdge $UseSoftEdge -SoftnessValue $SoftnessValue -UseColorRange $useRange -RangeColorA $rangeA -RangeColorB $rangeB -SampleColors $samples -TargetWidth $TargetWidth -TargetHeight $TargetHeight -UseDespill $UseDespill -DespillStrength $DespillStrength -ChokePixels $ChokePixels -MinAlpha $MinAlpha
        if ($UseOutline -and $OutlineWidth -gt 0) { Save-OutlinedPng -SourcePath $cutout -DestinationPath $cutout -OutlineWidth $OutlineWidth -OutlineColorHex $OutlineColorHex -OutlinePosition $OutlinePosition }
        $persist = Join-Path $env:TEMP 'spine_frame_tool_preview'
        if (-not (Test-Path -LiteralPath $persist)) { New-Item -ItemType Directory -Path $persist -Force | Out-Null }
        $origFinal = Join-Path $persist 'preview_original.png'
        $cutFinal = Join-Path $persist 'preview_cutout.png'
        Copy-Item -LiteralPath $original -Destination $origFinal -Force
        Copy-Item -LiteralPath $cutout -Destination $cutFinal -Force
        Write-ToolLog -LogBox $LogBox -Message "Preview ready. Color=$(Get-ColorHex -Color $key)"
        return @{ Original = $origFinal; Cutout = $cutFinal; Color = (Get-ColorHex -Color $key) }
    } finally { if (Test-Path -LiteralPath $tempRoot) { try { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue } catch {} } }
}

function Set-PictureBoxImage {
    param([object]$PictureBox, [string]$Path)
    if ($null -ne $PictureBox.Image) { $old = $PictureBox.Image; $PictureBox.Image = $null; $old.Dispose() }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $ms = New-Object System.IO.MemoryStream(,$bytes)
    $img = [System.Drawing.Image]::FromStream($ms)
    $PictureBox.Image = $img
}

function Get-ZoomImagePoint {
    param([object]$PictureBox, [int]$MouseX, [int]$MouseY)
    if ($null -eq $PictureBox.Image) { return $null }
    $imgW = $PictureBox.Image.Width; $imgH = $PictureBox.Image.Height; $boxW = $PictureBox.ClientSize.Width; $boxH = $PictureBox.ClientSize.Height
    $ratio = [Math]::Min($boxW / [double]$imgW, $boxH / [double]$imgH)
    $drawW = $imgW * $ratio; $drawH = $imgH * $ratio; $offsetX = ($boxW - $drawW) / 2; $offsetY = ($boxH - $drawH) / 2
    if ($MouseX -lt $offsetX -or $MouseY -lt $offsetY -or $MouseX -gt ($offsetX + $drawW) -or $MouseY -gt ($offsetY + $drawH)) { return $null }
    $x = [int](($MouseX - $offsetX) / $ratio); $y = [int](($MouseY - $offsetY) / $ratio)
    if ($x -lt 0) { $x = 0 }; if ($y -lt 0) { $y = 0 }; if ($x -ge $imgW) { $x = $imgW - 1 }; if ($y -ge $imgH) { $y = $imgH - 1 }
    return @{ X = $x; Y = $y }
}

function Get-VideoListFromText {
    param([string]$Text)
    return @($Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Parse-TargetSize {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return @{ Width = 0; Height = 0 } }
    $clean = $Text.Trim().ToLowerInvariant().Replace(' ','')
    if ($clean -notmatch '^(\d+)[x\*](\d+)$') { throw 'Size must look like 256x256. Leave it blank for original size.' }
    $w = [int]$matches[1]; $h = [int]$matches[2]
    if ($w -le 0 -or $h -le 0) { throw 'Size width and height must be positive.' }
    return @{ Width = $w; Height = $h }
}

function Get-ThemePalette {
    param([string]$ThemeId)
    switch ($ThemeId.ToLowerInvariant()) {
        'midnight' {
            return @{ Name='Charcoal'; FormTop=[System.Drawing.Color]::FromArgb(18,18,18); FormBottom=[System.Drawing.Color]::FromArgb(28,28,28); HeaderA=[System.Drawing.Color]::FromArgb(42,42,42); HeaderB=[System.Drawing.Color]::FromArgb(26,26,26); Card=[System.Drawing.Color]::FromArgb(40,40,40); CardAlt=[System.Drawing.Color]::FromArgb(52,52,52); Border=[System.Drawing.Color]::FromArgb(150,150,150); Accent=[System.Drawing.Color]::FromArgb(235,235,235); Accent2=[System.Drawing.Color]::FromArgb(120,120,120); Text=[System.Drawing.Color]::FromArgb(245,245,245); Muted=[System.Drawing.Color]::FromArgb(190,190,190); Input=[System.Drawing.Color]::FromArgb(28,28,28); InputBorder=[System.Drawing.Color]::FromArgb(110,110,110); Button=[System.Drawing.Color]::FromArgb(238,238,238); ButtonHover=[System.Drawing.Color]::FromArgb(210,210,210); ButtonText=[System.Drawing.Color]::FromArgb(18,18,18); Picture=[System.Drawing.Color]::FromArgb(22,22,22) }
        }
        'studio' {
            return @{ Name='Studio Gray'; FormTop=[System.Drawing.Color]::FromArgb(20,20,20); FormBottom=[System.Drawing.Color]::FromArgb(34,34,34); HeaderA=[System.Drawing.Color]::FromArgb(56,56,56); HeaderB=[System.Drawing.Color]::FromArgb(34,34,34); Card=[System.Drawing.Color]::FromArgb(42,42,42); CardAlt=[System.Drawing.Color]::FromArgb(54,54,54); Border=[System.Drawing.Color]::FromArgb(165,165,165); Accent=[System.Drawing.Color]::FromArgb(230,230,230); Accent2=[System.Drawing.Color]::FromArgb(125,125,125); Text=[System.Drawing.Color]::FromArgb(244,244,244); Muted=[System.Drawing.Color]::FromArgb(190,190,190); Input=[System.Drawing.Color]::FromArgb(30,30,30); InputBorder=[System.Drawing.Color]::FromArgb(120,120,120); Button=[System.Drawing.Color]::FromArgb(238,238,238); ButtonHover=[System.Drawing.Color]::FromArgb(210,210,210); ButtonText=[System.Drawing.Color]::FromArgb(18,18,18); Picture=[System.Drawing.Color]::FromArgb(26,26,26) }
        }
        default {
            return @{ Name='Monochrome'; FormTop=[System.Drawing.Color]::FromArgb(18,18,18); FormBottom=[System.Drawing.Color]::FromArgb(28,28,28); HeaderA=[System.Drawing.Color]::FromArgb(42,42,42); HeaderB=[System.Drawing.Color]::FromArgb(26,26,26); Card=[System.Drawing.Color]::FromArgb(40,40,40); CardAlt=[System.Drawing.Color]::FromArgb(52,52,52); Border=[System.Drawing.Color]::FromArgb(150,150,150); Accent=[System.Drawing.Color]::FromArgb(235,235,235); Accent2=[System.Drawing.Color]::FromArgb(120,120,120); Text=[System.Drawing.Color]::FromArgb(245,245,245); Muted=[System.Drawing.Color]::FromArgb(190,190,190); Input=[System.Drawing.Color]::FromArgb(28,28,28); InputBorder=[System.Drawing.Color]::FromArgb(110,110,110); Button=[System.Drawing.Color]::FromArgb(238,238,238); ButtonHover=[System.Drawing.Color]::FromArgb(210,210,210); ButtonText=[System.Drawing.Color]::FromArgb(18,18,18); Picture=[System.Drawing.Color]::FromArgb(22,22,22) }
        }
    }
}

function Apply-ControlTheme {
    param([System.Windows.Forms.Control]$Control, [hashtable]$Theme)
    if ($null -eq $Control -or $null -eq $Theme) { return }
    if ($Control -is [System.Windows.Forms.Form]) { $Control.BackColor = $Theme.FormBottom; $Control.ForeColor = $Theme.Text }
    elseif ($Control -is [System.Windows.Forms.GroupBox]) { $Control.BackColor = $Theme.Card; $Control.ForeColor = $Theme.Text }
    elseif ($Control -is [System.Windows.Forms.Panel]) { $Control.BackColor = $Theme.Card; $Control.ForeColor = $Theme.Text }
    elseif ($Control -is [System.Windows.Forms.Label]) { $Control.ForeColor = $Theme.Text; $Control.BackColor = [System.Drawing.Color]::Transparent }
    elseif ($Control -is [System.Windows.Forms.TextBox] -or $Control -is [System.Windows.Forms.ComboBox]) { $Control.BackColor = $Theme.Input; $Control.ForeColor = $Theme.Text }
    elseif ($Control -is [System.Windows.Forms.Button]) { $Control.FlatStyle = 'Flat'; $Control.BackColor = $Theme.Button; $Control.ForeColor = $Theme.ButtonText; $Control.FlatAppearance.BorderColor = $Theme.Border; $Control.FlatAppearance.MouseOverBackColor = $Theme.ButtonHover; $Control.FlatAppearance.MouseDownBackColor = $Theme.Accent2 }
    elseif ($Control -is [System.Windows.Forms.CheckBox] -or $Control -is [System.Windows.Forms.RadioButton]) { $Control.ForeColor = $Theme.Text; $Control.BackColor = [System.Drawing.Color]::Transparent }
    elseif ($Control -is [System.Windows.Forms.PictureBox]) { $Control.BackColor = $Theme.Picture }
    foreach ($child in $Control.Controls) { Apply-ControlTheme -Control $child -Theme $Theme }
}

function Apply-FormThemePaint {
    param([System.Windows.Forms.Form]$Form, [hashtable]$Theme)
    $Form.Tag = $Theme
    $Form.Add_Paint({
        param($sender, $e)
        $theme = $sender.Tag
        if ($null -eq $theme) { return }
        $rect = $sender.ClientRectangle
        if ($rect.Width -le 0 -or $rect.Height -le 0) { return }
        $brush = $null
        $headerBrush = $null
        $glow = $null
        try {
            $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new($rect, $theme.FormTop, $theme.FormBottom, 90.0)
            $e.Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $e.Graphics.FillRectangle($brush, $rect)

            $headerWidth = [Math]::Max(1, ([int]$rect.Width - 16))
            $headerRect = [System.Drawing.Rectangle]::new(8, 8, $headerWidth, 78)
            $headerBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new($headerRect, $theme.HeaderA, $theme.HeaderB, 0.0)
            $e.Graphics.FillRectangle($headerBrush, $headerRect)

            $glowColor = [System.Drawing.Color]::FromArgb(22, $theme.Accent.R, $theme.Accent.G, $theme.Accent.B)
            $glow = [System.Drawing.SolidBrush]::new($glowColor)
            $e.Graphics.FillEllipse($glow, 40, 18, 260, 120)
        } catch {
            $sender.BackColor = $theme.FormBottom
        } finally {
            if ($null -ne $glow) { $glow.Dispose() }
            if ($null -ne $headerBrush) { $headerBrush.Dispose() }
            if ($null -ne $brush) { $brush.Dispose() }
        }
    })
    $Form.Add_Resize({ param($sender, $e) $sender.Invalidate() })
}

function Get-UiText {
    $resourcePath = Join-Path (Get-CoreDirectory) 'ui_text.json'
    if (Test-Path -LiteralPath $resourcePath) {
        try { return Get-Content -LiteralPath $resourcePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
    }
    $fallbackJson = @'
{
  "zh-CN": {},
  "en-US": {
    "title": "Spine Video Frame Extractor Pro",
    "headerTitle": "Spine Frame Extractor Pro",
    "subtitle": "Frame extraction, transparent cutout, edge cleanup, and Spine-ready output.",
    "languageLabel": "Language:",
    "languageChineseLabel": "Chinese",
    "languageEnglishLabel": "English",
    "videoFilter": "Video and GIF files|*.mp4;*.mov;*.avi;*.mkv;*.webm;*.m4v;*.wmv;*.gif|All files|*.*",
    "videosLabel": "Video / GIF files:",
    "chooseVideos": "Choose Video / GIF",
    "clear": "Clear",
    "fpsMode": "FPS / original rate",
    "fpsHint": "blank = original",
    "countMode": "Evenly sample N frames",
    "outputLabel": "Output root:",
    "chooseFolder": "Choose Folder",
    "removeBg": "Remove solid color background after extraction",
    "mainColor": "Main color:",
    "tolerance": "Tolerance:",
    "softEdge": "Soft edge",
    "softness": "Softness:",
    "rangeA": "Range A:",
    "rangeB": "Range B:",
    "samples": "Picked samples:",
    "clearSamples": "Clear Samples",
    "previewCutout": "Preview Cutout",
    "targetSize": "Output size:",
    "targetHint": "Example: 256x256",
    "edgeDespill": "Edge despill / cleanup",
    "despillStrength": "Strength:",
    "choke": "Choke:",
    "minAlpha": "Min alpha:",
    "imageFolder": "Image folder:",
    "choose": "Choose",
    "resizeImageFolder": "Resize Image Folder",
    "resizeUsesTarget": "Uses Output size above.",
    "resizeCreatesFolder": "Creates a new _resized folder.",
    "spineNames": "Spine prefix naming",
    "prefix": "Prefix:",
    "createGif": "Create preview GIF",
    "gifFps": "GIF fps:",
    "extract": "Extract Frames",
    "openOutput": "Open Output Root",
    "originalPreview": "Original Preview",
    "cutoutPreview": "Cutout Preview",
    "pickHintInitial": "Click Preview Cutout first, then pick colors on the original image.",
    "pickHintReady": "Focus a color field, then click the original image. Right-click adds a sample. Zoom in for pixel-grid picking and use the scrollbars.",
    "zoom": "Zoom:",
    "zoomFit": "Fit",
    "outline": "Add outline",
    "outlineWidth": "Width:",
    "outlinePosition": "Position:",
    "outlineColor": "Color:",
    "outlineOutside": "Outside",
    "outlineCenter": "Center",
    "outlineInside": "Inside",
    "pickTargetMain": "Pick target: Main color. Click the original preview.",
    "pickTargetRangeA": "Pick target: Range A. Click the original preview.",
    "pickTargetRangeB": "Pick target: Range B. Click the original preview.",
    "pickTargetSamples": "Pick target: Samples. Click the original preview to add colors.",
    "previewFirst": "Click Preview Cutout first.",
    "chooseVideoFirst": "Choose a video or GIF first.",
    "chooseAtLeastOneVideo": "Choose at least one video or GIF file.",
    "chooseImageFolder": "Choose an image folder first.",
    "targetSizeRequired": "Output size is required. Example: 256x256.",
    "gifFpsInvalid": "GIF fps must be a positive integer.",
    "finished": "Finished.",
    "doneTitle": "Done",
    "imageFolderResized": "Image folder resized.",
    "previewErrorTitle": "Preview Error",
    "pickColorErrorTitle": "Pick Color Error",
    "errorTitle": "Error",
    "resizeErrorTitle": "Resize Error",
    "sampleAdded": "Sample color added: {0}",
    "rangeAPicked": "Range A picked: {0}",
    "rangeBPicked": "Range B picked: {0}",
    "mainPicked": "Main color picked: {0}",
    "processing": "Processing: {0}"
  }
}
'@
    return $fallbackJson | ConvertFrom-Json
}

function Get-UiString {
    param([object]$UiText, [string]$Language, [string]$Key, [string]$Fallback = '')
    $t = $UiText.$Language
    if ($null -eq $t) { $t = $UiText.'en-US' }
    if ($null -ne $t) {
        $property = $t.PSObject.Properties[$Key]
        if ($null -ne $property -and $null -ne $property.Value) { return [string]$property.Value }
    }
    return $Fallback
}

function Set-UiLanguage {
    param([object]$UiText, [string]$Language, [hashtable]$Controls)
    $t = $UiText.$Language
    if ($null -eq $t) { $t = $UiText.'en-US' }
    $textMap = [ordered]@{
        form='title'; title='headerTitle'; subtitle='subtitle'; lblLanguage='languageLabel'
        lblVideo='videosLabel'; btnBrowseVideo='chooseVideos'; btnClearVideos='clear'
        lblOutput='outputLabel'; btnBrowseOutput='chooseFolder'; rbFps='fpsMode'
        lblFpsHint='fpsHint'; rbCount='countMode'; lblTargetSize='targetSize'; lblTargetHint='targetHint'
        chkRemoveBg='removeBg'; lblBgColor='mainColor'; lblTolerance='tolerance'
        chkSoftEdge='softEdge'; lblSoft='softness'; lblRangeA='rangeA'; lblRangeB='rangeB'
        lblSamples='samples'; btnClearSamples='clearSamples'; btnPreview='previewCutout'; lblZoom='zoom'; btnZoomReset='zoomFit'
        chkDespill='edgeDespill'; lblDespill='despillStrength'; lblChoke='choke'; lblMinAlpha='minAlpha'
        lblImageFolder='imageFolder'; btnImageFolder='choose'; btnResizeFolder='resizeImageFolder'
        hintImageResize='resizeUsesTarget'; hintImageResize2='resizeCreatesFolder'
        chkSpineNames='spineNames'; lblPrefix='prefix'; chkGif='createGif'; lblGif='gifFps'
        chkOutline='outline'; lblOutlineWidth='outlineWidth'; lblOutlinePosition='outlinePosition'; lblOutlineColor='outlineColor'
        btnStart='extract'; btnOpenOutput='openOutput'; lblOriginalPreview='originalPreview'
        lblCutoutPreview='cutoutPreview'; lblPick='pickHintInitial'
    }
    foreach ($entry in $textMap.GetEnumerator()) {
        if (-not $Controls.ContainsKey($entry.Key)) { continue }
        $control = $Controls[$entry.Key]
        if ($null -eq $control) { continue }
        $property = $t.PSObject.Properties[$entry.Value]
        if ($null -ne $property -and $null -ne $property.Value) { $control.Text = [string]$property.Value }
    }
    return $t
}
