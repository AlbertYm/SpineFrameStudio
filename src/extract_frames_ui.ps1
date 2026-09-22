Add-Type -Path (Join-Path $Script:ToolDir 'studio_controls.cs') -ReferencedAssemblies System.Windows.Forms,System.Drawing
function Run-ConsoleMode {
    $ok = 0
    $failed = 0
    foreach ($video in $InputVideos) {
        try {
            $full = (Resolve-Path -LiteralPath $video -ErrorAction Stop).Path
            [void](Convert-VideoToFrames -VideoPath $full -Root $OutputRoot -ExtractMode $Mode -FrameRate $Fps -ExactFrameCount $FrameCount -LogBox $null)
            $ok++
        } catch {
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            $failed++
        }
    }
    Write-Host "Finished. Success: $ok. Failed: $failed."
    if ($failed -gt 0) { exit 1 }
}

function Add-Label {
    param($Parent, [string]$Text, [int]$X, [int]$Y, [int]$W = 120)
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($W, 22)
    $label.ForeColor = [System.Drawing.Color]::FromArgb(238,238,238)
    $label.BackColor = [System.Drawing.Color]::Transparent
    $Parent.Controls.Add($label)
    return $label
}

function Add-TextBox {
    param($Parent, [int]$X, [int]$Y, [int]$W = 120, [string]$Text = '')
    $box = New-Object SpineStudio.RoundTextBox
    $box.Location = New-Object System.Drawing.Point($X, $Y)
    $box.Size = New-Object System.Drawing.Size($W, 24)
    $box.Text = $Text
    $box.BackColor = [SpineStudio.Theme]::Input
    $box.ForeColor = [System.Drawing.Color]::White
    $Parent.Controls.Add($box)
    return $box
}

function Add-Button {
    param($Parent, [string]$Text, [int]$X, [int]$Y, [int]$W = 120, [int]$H = 32)
    $button = New-Object SpineStudio.RoundButton
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Size = New-Object System.Drawing.Size($W, $H)
    $button.FlatStyle = 'Flat'
    $button.BackColor = [System.Drawing.Color]::FromArgb(238,238,238)
    $button.ForeColor = [System.Drawing.Color]::FromArgb(18,18,18)
    $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(170,170,170)
    $Parent.Controls.Add($button)
    return $button
}

function Add-Card {
    param($Parent, [int]$X, [int]$Y, [int]$W, [int]$H)
    $panel = New-Object SpineStudio.RoundPanel
    $panel.Location = New-Object System.Drawing.Point($X, $Y)
    $panel.Size = New-Object System.Drawing.Size($W, $H)
    $panel.BackColor = [System.Drawing.Color]::FromArgb(44,44,44)
    $Parent.Controls.Add($panel)
    return $panel
}

function Add-DroppedVideosToTextBox {
    param($TextBox, [string[]]$Paths)
    if($script:StudioBusy){return}
    $videoExts = @('.mp4','.mov','.avi','.mkv','.webm','.m4v','.wmv','.gif')
    $existing = @($TextBox.Text -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $items = New-Object 'System.Collections.Generic.List[string]'
    foreach ($item in $existing) { if (-not $items.Contains($item)) { $items.Add($item) } }
    foreach ($path in $Paths) {
        if ((Test-Path -LiteralPath $path -PathType Leaf) -and ($videoExts -contains ([System.IO.Path]::GetExtension($path).ToLowerInvariant()))) {
            if (-not $items.Contains($path)) { $items.Add($path) }
        }
    }
    if ($items.Count -gt 0) { $TextBox.Text = ($items.ToArray() -join [Environment]::NewLine) }
}

function Get-PreviewImagePoint {
    param([System.Windows.Forms.PictureBox]$PictureBox, [int]$MouseX, [int]$MouseY)
    if ($null -eq $PictureBox -or $null -eq $PictureBox.Image) { return $null }
    if ($PictureBox.ClientSize.Width -le 0 -or $PictureBox.ClientSize.Height -le 0) { return $null }
    if ($MouseX -lt 0 -or $MouseY -lt 0 -or $MouseX -ge $PictureBox.ClientSize.Width -or $MouseY -ge $PictureBox.ClientSize.Height) { return $null }
    $x = [int][Math]::Floor($MouseX * ($PictureBox.Image.Width / [double]$PictureBox.ClientSize.Width))
    $y = [int][Math]::Floor($MouseY * ($PictureBox.Image.Height / [double]$PictureBox.ClientSize.Height))
    if ($x -lt 0) { $x = 0 }
    if ($y -lt 0) { $y = 0 }
    if ($x -ge $PictureBox.Image.Width) { $x = $PictureBox.Image.Width - 1 }
    if ($y -ge $PictureBox.Image.Height) { $y = $PictureBox.Image.Height - 1 }
    return @{ X = $x; Y = $y }
}

function Add-PixelPerfectPreviewPaint {
    param([System.Windows.Forms.PictureBox]$PictureBox)
    $PictureBox.Add_Paint({
        param($sender, $eventArgs)
        if ($null -eq $sender.Image) { return }
        $graphics = $eventArgs.Graphics
        $graphics.Clear([System.Drawing.Color]::FromArgb(49,53,59))
        $checkBrush=[System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(60,65,72))
        try {
            $clip=[Drawing.RectangleF]::Intersect($graphics.ClipBounds,[Drawing.RectangleF]::new(0,0,$sender.ClientSize.Width,$sender.ClientSize.Height)); $cell=16
            for($cy=[int]([Math]::Floor($clip.Top/$cell)*$cell);$cy -lt $clip.Bottom;$cy+=$cell){
                for($cx=[int]([Math]::Floor($clip.Left/$cell)*$cell);$cx -lt $clip.Right;$cx+=$cell){
                    if((($cx/$cell+$cy/$cell)%2) -eq 0){$graphics.FillRectangle($checkBrush,$cx,$cy,$cell,$cell)}
                }
            }
        } finally {$checkBrush.Dispose()}
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
        $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighSpeed
        $destRect = [System.Drawing.Rectangle]::new(0, 0, [Math]::Max(1, $sender.ClientSize.Width), [Math]::Max(1, $sender.ClientSize.Height))
        $graphics.DrawImage($sender.Image, $destRect)

        $scaleX = $sender.ClientSize.Width / [double]$sender.Image.Width
        $scaleY = $sender.ClientSize.Height / [double]$sender.Image.Height
        if ($scaleX -ge 8.0 -and $scaleY -ge 8.0) {
            $clip = $graphics.ClipBounds
            $startX = [Math]::Max(0, [int][Math]::Floor($clip.Left / $scaleX))
            $endX = [Math]::Min($sender.Image.Width, [int][Math]::Ceiling($clip.Right / $scaleX))
            $startY = [Math]::Max(0, [int][Math]::Floor($clip.Top / $scaleY))
            $endY = [Math]::Min($sender.Image.Height, [int][Math]::Ceiling($clip.Bottom / $scaleY))
            $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(80, 255, 255, 255), 1)
            try {
                for ($ix = $startX; $ix -le $endX; $ix++) {
                    $px = [int][Math]::Round($ix * $scaleX)
                    $graphics.DrawLine($pen, $px, [int]$clip.Top, $px, [int]$clip.Bottom)
                }
                for ($iy = $startY; $iy -le $endY; $iy++) {
                    $py = [int][Math]::Round($iy * $scaleY)
                    $graphics.DrawLine($pen, [int]$clip.Left, $py, [int]$clip.Right, $py)
                }
            } finally { $pen.Dispose() }
        }
    })
}

function Run-GuiMode {
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $uiText = Get-UiText
    $script:CurrentLanguage = 'zh-CN'
    $theme = Get-ThemePalette -ThemeId 'monochrome'
    $theme.FormTop = $theme.FormBottom = [SpineStudio.Theme]::Background
    $theme.Card = [SpineStudio.Theme]::Surface
    $theme.Text = [SpineStudio.Theme]::Text
    $theme.Muted = [SpineStudio.Theme]::Muted
    $theme.Input = [SpineStudio.Theme]::Input
    $theme.Border = [SpineStudio.Theme]::Border
    $theme.Accent = [SpineStudio.Theme]::Cyan
    $theme.Picture = [System.Drawing.Color]::FromArgb(23,23,27)

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Spine Video Frame Extractor Pro New Version'
    $form.StartPosition = 'CenterScreen'
    $form.Size = New-Object System.Drawing.Size(1440, 920)
    $form.MinimumSize = New-Object System.Drawing.Size(1120, 760)
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
    $form.MaximizeBox = $true
    $form.MinimizeBox = $true
    $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi
    $form.AutoScroll = $false
    $form.AutoScrollMinSize = New-Object System.Drawing.Size(0, 0)
    $form.BackColor = [System.Drawing.Color]::FromArgb(24,24,24)
    $form.ForeColor = [System.Drawing.Color]::White
    try { $form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10) } catch {}

    $title = Add-Label $form 'Spine Frame Extractor Pro' 24 18 320
    $title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 18)
    $subtitle = Add-Label $form 'Frame extraction, transparent cutout, edge cleanup, Spine-ready output.' 26 54 620
    $subtitle.ForeColor = [System.Drawing.Color]::FromArgb(190,190,190)
    $lblLanguage = Add-Label $form 'Language:' 1020 28 72
    $lblLanguage.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    $cmbLanguage = New-Object System.Windows.Forms.ComboBox
    $cmbLanguage.Location = New-Object System.Drawing.Point(1092, 24)
    $cmbLanguage.Size = New-Object System.Drawing.Size(138, 26)
    $cmbLanguage.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $cmbLanguage.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
    [void]$cmbLanguage.Items.Add((Get-UiString -UiText $uiText -Language 'zh-CN' -Key 'languageChineseLabel' -Fallback 'Chinese'))
    [void]$cmbLanguage.Items.Add((Get-UiString -UiText $uiText -Language 'en-US' -Key 'languageEnglishLabel' -Fallback 'English'))
    $cmbLanguage.SelectedIndex = 0
    $form.Controls.Add($cmbLanguage)

    $cardInput = Add-Card $form 20 92 440 190
    $cardInput.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
    $lblVideo = Add-Label $cardInput 'Video files:' 16 14 120
    $txtVideo = Add-TextBox $cardInput 16 40 300
    $txtVideo.Multiline = $true
    $txtVideo.Size = New-Object System.Drawing.Size(300, 72)
    $txtVideo.AllowDrop = $true
    if ($InputVideos.Count -gt 0) { $txtVideo.Text = ($InputVideos -join [Environment]::NewLine) }
    $btnVideo = Add-Button $cardInput 'Choose' 326 40 90
    $btnClear = Add-Button $cardInput 'Clear' 326 78 90
    $lblOutput = Add-Label $cardInput 'Output root:' 16 124 96
    $txtOutput = Add-TextBox $cardInput 118 120 298 $OutputRoot
    $btnOutput = Add-Button $cardInput 'Folder' 326 150 90

    $cardMode = Add-Card $form 480 92 470 190
    $cardMode.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
    $rbFps = New-Object System.Windows.Forms.RadioButton
    $rbFps.Text = 'FPS / original rate'
    $rbFps.Checked = $true
    $rbFps.Location = New-Object System.Drawing.Point(18, 18)
    $rbFps.Size = New-Object System.Drawing.Size(160, 24)
    $rbFps.ForeColor = [System.Drawing.Color]::White
    $rbFps.BackColor = [System.Drawing.Color]::Transparent
    $cardMode.Controls.Add($rbFps)
    $txtFps = Add-TextBox $cardMode 210 18 70
    $lblFpsHint = Add-Label $cardMode 'blank = original' 292 21 150
    $rbCount = New-Object System.Windows.Forms.RadioButton
    $rbCount.Text = 'Evenly sample N frames'
    $rbCount.Location = New-Object System.Drawing.Point(18, 55)
    $rbCount.Size = New-Object System.Drawing.Size(180, 24)
    $rbCount.ForeColor = [System.Drawing.Color]::White
    $rbCount.BackColor = [System.Drawing.Color]::Transparent
    $cardMode.Controls.Add($rbCount)
    $txtFrameCount = Add-TextBox $cardMode 210 54 60 '10'
    $lblTargetSize = Add-Label $cardMode 'Output size:' 18 104 96
    $txtTargetSize = Add-TextBox $cardMode 120 100 90 ''
    $lblTargetHint = Add-Label $cardMode 'Example: 256x256' 220 104 180

    $cardBg = Add-Card $form 20 304 930 190
    $cardBg.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
    $chkRemoveBg = New-Object System.Windows.Forms.CheckBox
    $chkRemoveBg.Text = 'Remove solid color background after extraction'
    $chkRemoveBg.Checked = $true
    $chkRemoveBg.Location = New-Object System.Drawing.Point(16, 16)
    $chkRemoveBg.Size = New-Object System.Drawing.Size(330, 24)
    $chkRemoveBg.ForeColor = [System.Drawing.Color]::White
    $chkRemoveBg.BackColor = [System.Drawing.Color]::Transparent
    $cardBg.Controls.Add($chkRemoveBg)
    $lblBgColor = Add-Label $cardBg 'Main color:' 16 54 82
    $txtBgColor = Add-TextBox $cardBg 108 50 88 ''
    $lblTolerance = Add-Label $cardBg 'Tolerance:' 220 54 78
    $txtTolerance = Add-TextBox $cardBg 310 50 55 '30'
    $chkSoftEdge = New-Object System.Windows.Forms.CheckBox
    $chkSoftEdge.Text = 'Soft edge'
    $chkSoftEdge.Checked = $true
    $chkSoftEdge.Location = New-Object System.Drawing.Point(380, 50)
    $chkSoftEdge.Size = New-Object System.Drawing.Size(90, 24)
    $chkSoftEdge.ForeColor = [System.Drawing.Color]::White
    $chkSoftEdge.BackColor = [System.Drawing.Color]::Transparent
    $cardBg.Controls.Add($chkSoftEdge)
    $lblSoft = Add-Label $cardBg 'Softness:' 490 54 78
    $txtSoftness = Add-TextBox $cardBg 575 50 55 '20'
    $lblRangeA = Add-Label $cardBg 'Range A:' 16 91 80
    $txtRangeA = Add-TextBox $cardBg 105 87 90 ''
    $lblRangeB = Add-Label $cardBg 'Range B:' 220 91 80
    $txtRangeB = Add-TextBox $cardBg 300 87 90 ''
    $lblSamples = Add-Label $cardBg 'Samples:' 415 91 76
    $txtSamples = Add-TextBox $cardBg 500 87 240 ''
    $btnClearSamples = Add-Button $cardBg 'Clear samples' 755 84 120
    $btnPreview = Add-Button $cardBg 'Preview cutout' 16 132 140

    $cardEdge = Add-Card $form 20 516 440 100
    $cardEdge.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
    $chkDespill = New-Object System.Windows.Forms.CheckBox
    $chkDespill.Text = 'Edge despill / cleanup'
    $chkDespill.Checked = $true
    $chkDespill.Location = New-Object System.Drawing.Point(16, 16)
    $chkDespill.Size = New-Object System.Drawing.Size(180, 24)
    $chkDespill.ForeColor = [System.Drawing.Color]::White
    $chkDespill.BackColor = [System.Drawing.Color]::Transparent
    $cardEdge.Controls.Add($chkDespill)
    $lblDespill = Add-Label $cardEdge 'Strength:' 16 56 80
    $txtDespill = Add-TextBox $cardEdge 95 52 55 '40'
    $lblChoke = Add-Label $cardEdge 'Choke:' 165 56 60
    $txtChoke = Add-TextBox $cardEdge 225 52 45 '1'
    $lblMinAlpha = Add-Label $cardEdge 'Min alpha:' 285 56 80
    $txtMinAlpha = Add-TextBox $cardEdge 365 52 45 '20'

    $cardImageResize = Add-Card $form 20 636 440 118
    $cardImageResize.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
    $lblImageFolder = Add-Label $cardImageResize 'Image folder:' 16 16 106
    $txtImageFolder = Add-TextBox $cardImageResize 130 12 208 ''
    $btnImageFolder = Add-Button $cardImageResize 'Choose' 348 10 68
    $btnResizeFolder = Add-Button $cardImageResize 'Resize Image Folder' 16 56 180 34
    $hintImageResize = Add-Label $cardImageResize 'Uses Output size.' 210 54 210
    $hintImageResize.ForeColor = [System.Drawing.Color]::FromArgb(190,190,190)
    $hintImageResize2 = Add-Label $cardImageResize 'Creates a new _resized folder.' 210 78 210
    $hintImageResize2.ForeColor = [System.Drawing.Color]::FromArgb(190,190,190)

    $cardAction = Add-Card $form 480 516 470 258
    $cardAction.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
    $btnStart = Add-Button $cardAction 'Extract Frames' 16 16 190 42
    $btnOpenOutput = Add-Button $cardAction 'Open Output Root' 220 16 190 42
    $chkSpineNames = New-Object System.Windows.Forms.CheckBox
    $chkSpineNames.Text = 'Spine prefix naming'
    $chkSpineNames.Checked = $false
    $chkSpineNames.Location = New-Object System.Drawing.Point(16, 66)
    $chkSpineNames.Size = New-Object System.Drawing.Size(160, 24)
    $cardAction.Controls.Add($chkSpineNames)
    $lblPrefix = Add-Label $cardAction 'Prefix:' 180 69 70
    $txtPrefix = Add-TextBox $cardAction 250 65 180 ''

    $chkGif = New-Object System.Windows.Forms.CheckBox
    $chkGif.Text = 'Create preview GIF'
    $chkGif.Checked = $false
    $chkGif.Location = New-Object System.Drawing.Point(16, 94)
    $chkGif.Size = New-Object System.Drawing.Size(160, 24)
    $cardAction.Controls.Add($chkGif)
    $lblGif = Add-Label $cardAction 'GIF fps:' 180 97 70
    $txtGifFps = Add-TextBox $cardAction 250 93 60 '12'

    $chkOutline = New-Object System.Windows.Forms.CheckBox
    $chkOutline.Text = 'Add outline'
    $chkOutline.Checked = $false
    $chkOutline.Location = New-Object System.Drawing.Point(16, 124)
    $chkOutline.Size = New-Object System.Drawing.Size(120, 24)
    $cardAction.Controls.Add($chkOutline)
    $lblOutlineWidth = Add-Label $cardAction 'Width:' 140 128 52
    $txtOutlineWidth = Add-TextBox $cardAction 195 124 42 '2'
    $lblOutlinePosition = Add-Label $cardAction 'Position:' 250 128 66
    $cmbOutlinePosition = New-Object System.Windows.Forms.ComboBox
    $cmbOutlinePosition.Location = New-Object System.Drawing.Point(320, 124)
    $cmbOutlinePosition.Size = New-Object System.Drawing.Size(110, 26)
    $cmbOutlinePosition.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    [void]$cmbOutlinePosition.Items.Add('Outside')
    [void]$cmbOutlinePosition.Items.Add('Center')
    [void]$cmbOutlinePosition.Items.Add('Inside')
    $cmbOutlinePosition.SelectedIndex = 0
    $cardAction.Controls.Add($cmbOutlinePosition)
    $lblOutlineColor = Add-Label $cardAction 'Color:' 16 158 52
    $txtOutlineColor = Add-TextBox $cardAction 70 154 90 '#000000'

    $txtLog = Add-TextBox $cardAction 16 188 430 ''
    $txtLog.Multiline = $true
    $txtLog.ScrollBars = 'Vertical'
    $txtLog.ReadOnly = $true
    $txtLog.Size = New-Object System.Drawing.Size(430, 52)

    $cardPreview = Add-Card $form 970 92 280 662
    $cardPreview.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
    $lblOriginalPreview = Add-Label $cardPreview 'Original preview' 14 12 250
    $lblOriginalPreview.ForeColor = [System.Drawing.Color]::FromArgb(190,190,190)
    $pnlOriginalViewport = New-Object System.Windows.Forms.Panel
    $pnlOriginalViewport.Location = New-Object System.Drawing.Point(14, 40)
    $pnlOriginalViewport.Size = New-Object System.Drawing.Size(252, 252)
    $pnlOriginalViewport.BorderStyle = 'FixedSingle'
    $pnlOriginalViewport.BackColor = [System.Drawing.Color]::FromArgb(22,22,22)
    $pnlOriginalViewport.AutoScroll = $true
    $pnlOriginalViewport.TabStop = $true
    $cardPreview.Controls.Add($pnlOriginalViewport)
    $picOriginal = New-Object System.Windows.Forms.PictureBox
    $picOriginal.Location = New-Object System.Drawing.Point(0, 0)
    $picOriginal.Size = New-Object System.Drawing.Size(252, 252)
    $picOriginal.BorderStyle = 'None'
    $picOriginal.BackColor = [System.Drawing.Color]::FromArgb(22,22,22)
    $picOriginal.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Normal
    $picOriginal.Cursor = [System.Windows.Forms.Cursors]::Cross
    $picOriginal.TabStop = $true
    Add-PixelPerfectPreviewPaint -PictureBox $picOriginal
    $pnlOriginalViewport.Controls.Add($picOriginal)
    $lblCutoutPreview = Add-Label $cardPreview 'Cutout preview' 14 310 250
    $lblCutoutPreview.ForeColor = [System.Drawing.Color]::FromArgb(190,190,190)
    $pnlCutoutViewport = New-Object System.Windows.Forms.Panel
    $pnlCutoutViewport.Location = New-Object System.Drawing.Point(14, 338)
    $pnlCutoutViewport.Size = New-Object System.Drawing.Size(252, 252)
    $pnlCutoutViewport.BorderStyle = 'FixedSingle'
    $pnlCutoutViewport.BackColor = [System.Drawing.Color]::FromArgb(22,22,22)
    $pnlCutoutViewport.AutoScroll = $true
    $pnlCutoutViewport.TabStop = $true
    $cardPreview.Controls.Add($pnlCutoutViewport)
    $picCutout = New-Object System.Windows.Forms.PictureBox
    $picCutout.Location = New-Object System.Drawing.Point(0, 0)
    $picCutout.Size = New-Object System.Drawing.Size(252, 252)
    $picCutout.BorderStyle = 'None'
    $picCutout.BackColor = [System.Drawing.Color]::FromArgb(22,22,22)
    $picCutout.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Normal
    $picCutout.TabStop = $true
    Add-PixelPerfectPreviewPaint -PictureBox $picCutout
    $pnlCutoutViewport.Controls.Add($picCutout)
    $lblZoom = Add-Label $cardPreview 'Zoom:' 14 596 46
    $btnZoomOut = Add-Button $cardPreview '-' 62 592 30 26
    $lblZoomValue = Add-Label $cardPreview '100%' 100 596 48
    $btnZoomIn = Add-Button $cardPreview '+' 150 592 30 26
    $btnZoomReset = Add-Button $cardPreview 'Fit' 188 592 58 26
    $lblPickHint = Add-Label $cardPreview 'Click Preview cutout first, then pick colors on the original image.' 14 626 250
    $lblPickHint.Size = New-Object System.Drawing.Size(250, 34)
    $lblPickHint.ForeColor = [System.Drawing.Color]::FromArgb(190,190,190)
    $script:PreviewOriginalPath = $null
    $script:ColorPickTarget = 'main'
    $script:PreviewZoom = 1.0

    $applyPreviewZoom = {
        if($script:ApplyingZoom){return}
        $script:ApplyingZoom=$true
        try {
        $previewPairs = @(
            @{ Picture = $picOriginal; Viewport = $pnlOriginalViewport },
            @{ Picture = $picCutout; Viewport = $pnlCutoutViewport }
        )
        foreach ($pair in $previewPairs) {
            $picture = $pair.Picture
            $viewport = $pair.Viewport
            if ($null -eq $picture -or $null -eq $viewport) { continue }
            if ($null -eq $picture.Image) {
                $picture.Location = New-Object System.Drawing.Point(0, 0)
                $picture.Size = $viewport.ClientSize
                continue
            }
            if($script:PreviewZoom -le 1.0){
                $viewport.AutoScroll=$false
                $viewport.AutoScrollPosition=[Drawing.Point]::Empty
            }else{$viewport.AutoScroll=$true}
            $viewW = [Math]::Max(1, $viewport.ClientSize.Width)
            $viewH = [Math]::Max(1, $viewport.ClientSize.Height)
            $fitScale = [Math]::Min($viewW / [double]$picture.Image.Width, $viewH / [double]$picture.Image.Height)
            if ($fitScale -le 0) { $fitScale = 1.0 }
            $scale = $fitScale * $script:PreviewZoom
            $newW = [int][Math]::Max(1, [Math]::Round($picture.Image.Width * $scale))
            $newH = [int][Math]::Max(1, [Math]::Round($picture.Image.Height * $scale))
            $x = 0
            $y = 0
            if ($newW -lt $viewW) { $x = [int][Math]::Floor(($viewW - $newW) / 2) }
            if ($newH -lt $viewH) { $y = [int][Math]::Floor(($viewH - $newH) / 2) }
            $picture.Location = New-Object System.Drawing.Point($x, $y)
            $picture.Size = New-Object System.Drawing.Size($newW, $newH)
            $picture.Invalidate()
        }
        $lblZoomValue.Text = ('{0}%' -f [int][Math]::Round($script:PreviewZoom * 100))
        } finally {$script:ApplyingZoom=$false}
    }
    $setPreviewZoom = {
        param([double]$Zoom)
        if ($Zoom -lt 1.0) { $Zoom = 1.0 }
        if ($Zoom -gt 32.0) { $Zoom = 32.0 }
        $script:PreviewZoom = [Math]::Round($Zoom, 2)
        & $applyPreviewZoom
    }



    $layoutPreviewPanel = { }

    $openDlg = New-Object System.Windows.Forms.OpenFileDialog
    $openDlg.Filter = 'Video and GIF files|*.mp4;*.mov;*.avi;*.mkv;*.webm;*.m4v;*.wmv;*.gif|All files|*.*'
    $openDlg.Multiselect = $true
    $folderDlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $videoDropTargets = @($form, $cardInput, $txtVideo)
    foreach ($dropTarget in $videoDropTargets) {
        $dropTarget.AllowDrop = $true
        $dropTarget.Add_DragEnter({
            param($sender, $eventArgs)
            if ($eventArgs.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::Copy }
            else { $eventArgs.Effect = [System.Windows.Forms.DragDropEffects]::None }
        })
        $dropTarget.Add_DragDrop({
            param($sender, $eventArgs)
            $paths = [string[]]$eventArgs.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
            Add-DroppedVideosToTextBox -TextBox $txtVideo -Paths $paths
        })
    }
    $btnVideo.Add_Click({ if ($openDlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Add-DroppedVideosToTextBox -TextBox $txtVideo -Paths $openDlg.FileNames } })
    $btnOutput.Add_Click({
        $currentOutput = $txtOutput.Text.Trim()
        if (-not [string]::IsNullOrWhiteSpace($currentOutput) -and (Test-Path -LiteralPath $currentOutput -PathType Container)) { $folderDlg.SelectedPath = $currentOutput }
        if ($folderDlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $txtOutput.Text = $folderDlg.SelectedPath }
    })
    $btnImageFolder.Add_Click({
        $currentImageFolder = $txtImageFolder.Text.Trim()
        $currentOutput = $txtOutput.Text.Trim()
        if (-not [string]::IsNullOrWhiteSpace($currentImageFolder) -and (Test-Path -LiteralPath $currentImageFolder -PathType Container)) { $folderDlg.SelectedPath = $currentImageFolder }
        elseif (-not [string]::IsNullOrWhiteSpace($currentOutput) -and (Test-Path -LiteralPath $currentOutput -PathType Container)) { $folderDlg.SelectedPath = $currentOutput }
        if ($folderDlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $txtImageFolder.Text = $folderDlg.SelectedPath }
    })
    $btnClear.Add_Click({ $txtVideo.Clear() })
    $updateOutlineControls = {
        $enabled = $chkOutline.Checked
        foreach ($ctrl in @($txtOutlineWidth,$txtOutlineColor,$cmbOutlinePosition,$lblOutlineWidth,$lblOutlineColor,$lblOutlinePosition)) {
            if ($null -ne $ctrl) { $ctrl.Enabled = $enabled }
        }
    }
    $getOutlineSettings = {
        $outlineEnabled = $chkOutline.Checked
        $outlineWidth = 0
        $outlineColor = $txtOutlineColor.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($outlineColor)) { $outlineColor = '#000000' }
        if ($outlineEnabled) {
            if ((-not [int]::TryParse($txtOutlineWidth.Text.Trim(), [ref]$outlineWidth)) -or $outlineWidth -le 0 -or $outlineWidth -gt 128) { throw 'Outline width must be an integer from 1 to 128.' }
            if ($outlineColor -notmatch '^#[0-9a-fA-F]{6}$') { throw 'Outline color must look like #000000.' }
        }
        $outlinePosition = 'outside'
        if ($cmbOutlinePosition.SelectedIndex -eq 1) { $outlinePosition = 'center' }
        elseif ($cmbOutlinePosition.SelectedIndex -eq 2) { $outlinePosition = 'inside' }
        return @{ Enabled = $outlineEnabled; Width = $outlineWidth; Color = $outlineColor; Position = $outlinePosition }
    }
    $chkSpineNames.Add_CheckedChanged({ $txtPrefix.Enabled = $chkSpineNames.Checked })
    $chkGif.Add_CheckedChanged({ $txtGifFps.Enabled = $chkGif.Checked })
    $chkOutline.Add_CheckedChanged({ & $updateOutlineControls })
    $txtPrefix.Enabled = $chkSpineNames.Checked
    $txtGifFps.Enabled = $chkGif.Checked
    & $updateOutlineControls
    $txtBgColor.Add_Enter({ $script:ColorPickTarget = 'main'; $lblPickHint.Text = Get-UiString -UiText $uiText -Language $script:CurrentLanguage -Key 'pickTargetMain' -Fallback 'Pick target: Main color.' })
    $txtRangeA.Add_Enter({ $script:ColorPickTarget = 'rangeA'; $lblPickHint.Text = Get-UiString -UiText $uiText -Language $script:CurrentLanguage -Key 'pickTargetRangeA' -Fallback 'Pick target: Range A.' })
    $txtRangeB.Add_Enter({ $script:ColorPickTarget = 'rangeB'; $lblPickHint.Text = Get-UiString -UiText $uiText -Language $script:CurrentLanguage -Key 'pickTargetRangeB' -Fallback 'Pick target: Range B.' })
    $txtSamples.Add_Enter({ $script:ColorPickTarget = 'samples'; $lblPickHint.Text = Get-UiString -UiText $uiText -Language $script:CurrentLanguage -Key 'pickTargetSamples' -Fallback 'Pick target: Samples.' })
    $btnClearSamples.Add_Click({ $txtSamples.Clear() })
    $zoomWithWheel = {
        param($sender, $eventArgs)
        if ($eventArgs.Delta -gt 0) { & $setPreviewZoom ($script:PreviewZoom * 1.15) }
        elseif ($eventArgs.Delta -lt 0) { & $setPreviewZoom ($script:PreviewZoom / 1.15) }
    }
    $pnlOriginalViewport.Add_MouseEnter({ $pnlOriginalViewport.Focus() })
    $pnlCutoutViewport.Add_MouseEnter({ $pnlCutoutViewport.Focus() })
    $picOriginal.Add_MouseEnter({ $pnlOriginalViewport.Focus() })
    $picCutout.Add_MouseEnter({ $pnlCutoutViewport.Focus() })
    $btnZoomIn.Add_Click({ & $setPreviewZoom ($script:PreviewZoom * 1.25) })
    $btnZoomOut.Add_Click({ & $setPreviewZoom ($script:PreviewZoom / 1.25) })
    $btnZoomReset.Add_Click({ & $setPreviewZoom 1.0 })
    $pnlOriginalViewport.Add_MouseWheel($zoomWithWheel)
    $pnlCutoutViewport.Add_MouseWheel($zoomWithWheel)
    $picOriginal.Add_MouseWheel($zoomWithWheel)
    $picCutout.Add_MouseWheel($zoomWithWheel)
    $picOriginal.Add_MouseClick({
        param($sender, $eventArgs)
        try {
            if ([string]::IsNullOrWhiteSpace($script:PreviewOriginalPath) -or -not (Test-Path -LiteralPath $script:PreviewOriginalPath)) { throw (Get-UiString -UiText $uiText -Language $script:CurrentLanguage -Key 'previewFirst' -Fallback 'Click Preview Cutout first.') }
            $point = Get-PreviewImagePoint -PictureBox $picOriginal -MouseX $eventArgs.X -MouseY $eventArgs.Y
            if ($null -eq $point) { return }
            $bitmap = New-Object System.Drawing.Bitmap -ArgumentList $script:PreviewOriginalPath
            try {
                $hex = Get-ColorHex -Color $bitmap.GetPixel($point.X, $point.Y)
            } finally { $bitmap.Dispose() }
            $addSample = {
                param([string]$pickedHex)
                $items = @($txtSamples.Text -split '[,;\s]+' | ForEach-Object { $_.Trim().ToUpperInvariant() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
                if ($items -notcontains $pickedHex.ToUpperInvariant()) { $items += $pickedHex.ToUpperInvariant() }
                $txtSamples.Text = ($items -join ' ')
            }
            if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Right -or $script:ColorPickTarget -eq 'samples') {
                & $addSample $hex
                Write-ToolLog -LogBox $txtLog -Message ([string]::Format((Get-UiString -UiText $uiText -Language $script:CurrentLanguage -Key 'sampleAdded' -Fallback 'Sample color added: {0}'), $hex))
            } elseif ($script:ColorPickTarget -eq 'rangeA') {
                $txtRangeA.Text = $hex
                Write-ToolLog -LogBox $txtLog -Message ([string]::Format((Get-UiString -UiText $uiText -Language $script:CurrentLanguage -Key 'rangeAPicked' -Fallback 'Range A picked: {0}'), $hex))
            } elseif ($script:ColorPickTarget -eq 'rangeB') {
                $txtRangeB.Text = $hex
                Write-ToolLog -LogBox $txtLog -Message ([string]::Format((Get-UiString -UiText $uiText -Language $script:CurrentLanguage -Key 'rangeBPicked' -Fallback 'Range B picked: {0}'), $hex))
            } else {
                $txtBgColor.Text = $hex
                Write-ToolLog -LogBox $txtLog -Message ([string]::Format((Get-UiString -UiText $uiText -Language $script:CurrentLanguage -Key 'mainPicked' -Fallback 'Main color picked: {0}'), $hex))
            }
        } catch { [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, (Get-UiString -UiText $uiText -Language $script:CurrentLanguage -Key 'pickColorErrorTitle' -Fallback 'Pick Color Error')) | Out-Null }
    })


    $btnPreview.Add_Click({ & $startWorkbenchJob 'preview' })
    $btnStart.Add_Click({ & $startWorkbenchJob 'extract' })
    $btnResizeFolder.Add_Click({ & $startWorkbenchJob 'resize' })

    $languageControls = @{
        form=$form; title=$title; subtitle=$subtitle; lblLanguage=$lblLanguage
        lblVideo=$lblVideo; btnBrowseVideo=$btnVideo; btnClearVideos=$btnClear
        lblOutput=$lblOutput; btnBrowseOutput=$btnOutput; rbFps=$rbFps
        lblFpsHint=$lblFpsHint; rbCount=$rbCount; lblTargetSize=$lblTargetSize; lblTargetHint=$lblTargetHint
        chkRemoveBg=$chkRemoveBg; lblBgColor=$lblBgColor; lblTolerance=$lblTolerance
        chkSoftEdge=$chkSoftEdge; lblSoft=$lblSoft; lblRangeA=$lblRangeA; lblRangeB=$lblRangeB
        lblSamples=$lblSamples; btnClearSamples=$btnClearSamples; btnPreview=$btnPreview
        chkDespill=$chkDespill; lblDespill=$lblDespill; lblChoke=$lblChoke; lblMinAlpha=$lblMinAlpha
        lblImageFolder=$lblImageFolder; btnImageFolder=$btnImageFolder; btnResizeFolder=$btnResizeFolder
        hintImageResize=$hintImageResize; hintImageResize2=$hintImageResize2
        chkSpineNames=$chkSpineNames; lblPrefix=$lblPrefix; chkGif=$chkGif; lblGif=$lblGif
        chkOutline=$chkOutline; lblOutlineWidth=$lblOutlineWidth; lblOutlinePosition=$lblOutlinePosition; lblOutlineColor=$lblOutlineColor
        btnStart=$btnStart; btnOpenOutput=$btnOpenOutput; lblOriginalPreview=$lblOriginalPreview
        lblCutoutPreview=$lblCutoutPreview; lblZoom=$lblZoom; btnZoomReset=$btnZoomReset; lblPick=$lblPickHint
    }
    $applyLanguage = {
        $script:CurrentLanguage = if ($cmbLanguage.SelectedIndex -eq 1) { 'en-US' } else { 'zh-CN' }
        [void](Set-UiLanguage -UiText $uiText -Language $script:CurrentLanguage -Controls $languageControls)
        $selectedOutlineIndex = $cmbOutlinePosition.SelectedIndex
        $cmbOutlinePosition.Items.Clear()
        [void]$cmbOutlinePosition.Items.Add((Get-UiString -UiText $uiText -Language $script:CurrentLanguage -Key 'outlineOutside' -Fallback 'Outside'))
        [void]$cmbOutlinePosition.Items.Add((Get-UiString -UiText $uiText -Language $script:CurrentLanguage -Key 'outlineCenter' -Fallback 'Center'))
        [void]$cmbOutlinePosition.Items.Add((Get-UiString -UiText $uiText -Language $script:CurrentLanguage -Key 'outlineInside' -Fallback 'Inside'))
        if ($selectedOutlineIndex -lt 0 -or $selectedOutlineIndex -ge $cmbOutlinePosition.Items.Count) { $selectedOutlineIndex = 0 }
        $cmbOutlinePosition.SelectedIndex = $selectedOutlineIndex
        $openDlg.Filter = Get-UiString -UiText $uiText -Language $script:CurrentLanguage -Key 'videoFilter' -Fallback 'Video and GIF files|*.mp4;*.mov;*.avi;*.mkv;*.webm;*.m4v;*.wmv;*.gif|All files|*.*'
    }
    $cmbLanguage.Add_SelectedIndexChanged($applyLanguage)

    # The studio shell uses a quiet solid background to preserve preview color judgement.
    Apply-ControlTheme -Control $form -Theme $theme
    foreach ($mutedControl in @($subtitle,$hintImageResize,$hintImageResize2,$lblOriginalPreview,$lblCutoutPreview,$lblPickHint)) {
        if ($null -ne $mutedControl) { $mutedControl.ForeColor = $theme.Muted }
    }
    # All layout numbers are logical 96-DPI units. Resizing reflows the comparison view.
    $form.SuspendLayout()
    $studioMark=New-Object SpineStudio.StudioMark
    $studioMark.AccessibleName='Spine 抽帧工作室'
    $studioMark.TabStop=$false
    $form.Controls.Add($studioMark)
    $studioSettings = New-Object System.Windows.Forms.Panel
    $studioSettings.BackColor = $theme.FormBottom
    $form.Controls.Add($studioSettings)
    $studioPages = @()
    foreach ($i in 0..3) {
        $page = New-Object System.Windows.Forms.Panel
        $page.AutoScroll = $true
        $page.BackColor = $theme.FormBottom
        $studioSettings.Controls.Add($page)
        $studioPages += $page
    }
    $studioTabs = @()
    foreach ($i in 0..3) {
        $tab = Add-Button $studioSettings '' ($i * 112) 0 108 40
        $tab.Tag = $i
        $tab.Add_KeyDown({param($sender,$e)
            if($e.KeyCode -eq 'Right' -or $e.KeyCode -eq 'Left'){
                $delta=if($e.KeyCode -eq 'Right'){1}else{3}
                $next=$studioTabs[(([int]$sender.Tag+$delta)%4)]
                $next.Focus();$next.PerformClick();$e.Handled=$true
            }
        })
        $tab.AccessibleRole = [System.Windows.Forms.AccessibleRole]::PageTab
        $tab.Add_Click({
            param($sender,$e)
            for ($j=0; $j -lt 4; $j++) {
                $selected = ($j -eq [int]$sender.Tag)
                $studioPages[$j].Visible = $selected
                $studioTabs[$j].Variant = if ($selected) { 'selected' } else { 'secondary' }
                $studioTabs[$j].Invalidate()
            }
        })
        $studioTabs += $tab
    }
    function Place-StudioControl($Control,[int]$X,[int]$Y,[int]$W,[int]$H) {
        $Control.SetBounds($X,$Y,$W,$H)
        $Control.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
    }
    $studioPages[0].Controls.Add($cardInput)
    $studioPages[0].Controls.Add($cardMode)
    $studioPages[1].Controls.Add($cardBg)
    $studioPages[1].Controls.Add($cardEdge)
    $studioPages[2].Controls.Add($cardAction)
    $studioPages[2].Controls.Add($cardImageResize)
    $spineCard=Add-Card $studioPages[3] 0 0 450 474
    $chkCreateSpine=New-Object System.Windows.Forms.CheckBox
    $chkCreateSpine.Text='抽帧后创建 Spine 动画工程';$chkCreateSpine.Location=[Drawing.Point]::new(20,18);$chkCreateSpine.Size=[Drawing.Size]::new(400,28)
    $chkCreateSpine.ForeColor=$theme.Text;$chkCreateSpine.BackColor=[Drawing.Color]::Transparent;$spineCard.Controls.Add($chkCreateSpine)
    $lblSpineAnimation=Add-Label $spineCard '动画名称' 20 62 100
    $txtSpineAnimation=Add-TextBox $spineCard 130 58 280 'sequence'
    $lblSpineFps=Add-Label $spineCard '动画 FPS' 20 106 100
    $txtSpineFps=Add-TextBox $spineCard 130 102 92 '12'
    $chkSpineLoop=New-Object System.Windows.Forms.CheckBox
    $chkSpineLoop.Text='循环播放';$chkSpineLoop.Checked=$true;$chkSpineLoop.Location=[Drawing.Point]::new(250,102);$chkSpineLoop.Size=[Drawing.Size]::new(150,28)
    $chkSpineLoop.ForeColor=$theme.Text;$chkSpineLoop.BackColor=[Drawing.Color]::Transparent;$spineCard.Controls.Add($chkSpineLoop)
    $lblSpineTemplate=Add-Label $spineCard '模板工程' 20 154 100
    $txtSpineTemplate=Add-TextBox $spineCard 20 184 300 ''
    $btnSpineTemplate=Add-Button $spineCard '选择模板' 330 180 100 38
    $lblSpineSlot=Add-Label $spineCard 'Mask 内目标 Slot（留空自动识别）' 20 234 380
    $txtSpineSlot=Add-TextBox $spineCard 20 264 410 ''
    $chkOpenSpine=New-Object System.Windows.Forms.CheckBox
    $chkOpenSpine.Text='完成后打开生成的 Spine 工程';$chkOpenSpine.Location=[Drawing.Point]::new(20,312);$chkOpenSpine.Size=[Drawing.Size]::new(390,28)
    $chkOpenSpine.ForeColor=$theme.Text;$chkOpenSpine.BackColor=[Drawing.Color]::Transparent;$spineCard.Controls.Add($chkOpenSpine)
    $spineHelp=Add-Label $spineCard '不选模板：创建一根 root 骨骼和一个序列 Slot。`n选择模板：复制骨骼、Skin、Clipping/Mask、Draw Order 和已有动画，再把新序列加入目标 Slot。`n原模板不会被覆盖。' 20 358 410
    $spineHelp.Text=$spineHelp.Text.Replace('`n',[Environment]::NewLine);$spineHelp.Height=94;$spineHelp.ForeColor=$theme.Muted
    $spineDialog=New-Object System.Windows.Forms.OpenFileDialog
    $spineDialog.Filter='Spine 模板|*.spine;*.json|Spine 工程|*.spine|Skeleton JSON|*.json'
    $btnSpineTemplate.Add_Click({if($spineDialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK){$txtSpineTemplate.Text=$spineDialog.FileName}})
    $updateSpineFields={
        $enabled=$chkCreateSpine.Checked
        foreach($control in @($txtSpineAnimation,$txtSpineFps,$chkSpineLoop,$txtSpineTemplate,$btnSpineTemplate,$txtSpineSlot,$chkOpenSpine)){$control.Enabled=$enabled}
    }
    $chkCreateSpine.Add_CheckedChanged($updateSpineFields);& $updateSpineFields
    Place-StudioControl $cardInput 0 0 450 246
    Place-StudioControl $lblVideo 20 18 300 24
    Place-StudioControl $txtVideo 20 50 410 86
    $txtVideo.ScrollBars = 'Both'; $txtVideo.WordWrap = $false
    Place-StudioControl $btnVideo 20 146 140 38
    Place-StudioControl $btnClear 172 146 90 38
    Place-StudioControl $lblOutput 20 199 88 25
    Place-StudioControl $txtOutput 108 197 210 28
    Place-StudioControl $btnOutput 326 193 104 38
    Place-StudioControl $cardMode 0 262 450 188
    Place-StudioControl $rbFps 20 20 225 28
    Place-StudioControl $txtFps 298 20 110 28
    Place-StudioControl $lblFpsHint 298 52 135 24
    Place-StudioControl $rbCount 20 84 245 28
    Place-StudioControl $txtFrameCount 298 84 110 28
    Place-StudioControl $lblTargetSize 20 136 110 24
    Place-StudioControl $txtTargetSize 130 132 110 28
    Place-StudioControl $lblTargetHint 250 136 180 24
    $studioImportHint = Add-Label $studioPages[0] '支持拖入多个视频 / GIF。每次导出新建文件夹，保留原始素材。' 18 474 410
    $studioImportHint.Height=58; $studioImportHint.ForeColor=$theme.Muted
    Place-StudioControl $cardBg 0 0 450 298
    Place-StudioControl $chkRemoveBg 20 18 410 28
    Place-StudioControl $lblBgColor 20 65 80 24
    Place-StudioControl $txtBgColor 108 60 94 28
    Place-StudioControl $lblTolerance 226 65 94 24
    Place-StudioControl $txtTolerance 336 60 74 28
    Place-StudioControl $chkSoftEdge 20 108 130 28
    Place-StudioControl $lblSoft 220 111 116 24
    Place-StudioControl $txtSoftness 336 106 74 28
    Place-StudioControl $lblRangeA 20 157 80 24
    Place-StudioControl $txtRangeA 108 152 94 28
    Place-StudioControl $lblRangeB 226 157 90 24
    Place-StudioControl $txtRangeB 336 152 94 28
    Place-StudioControl $lblSamples 20 201 110 24
    Place-StudioControl $txtSamples 132 196 298 28
    Place-StudioControl $btnClearSamples 292 242 138 38
    Place-StudioControl $cardEdge 0 314 450 146
    Place-StudioControl $chkDespill 20 18 410 26
    Place-StudioControl $lblDespill 20 58 120 24
    Place-StudioControl $txtDespill 20 90 108 28
    Place-StudioControl $lblChoke 160 58 120 24
    Place-StudioControl $txtChoke 160 90 108 28
    Place-StudioControl $lblMinAlpha 302 58 128 24
    Place-StudioControl $txtMinAlpha 302 90 108 28
    Place-StudioControl $cardAction 0 0 450 290
    Place-StudioControl $chkSpineNames 20 20 215 28
    Place-StudioControl $lblPrefix 20 62 96 24
    Place-StudioControl $txtPrefix 130 58 300 28
    Place-StudioControl $chkGif 20 106 220 28
    Place-StudioControl $lblGif 250 110 94 24
    Place-StudioControl $txtGifFps 350 106 80 28
    Place-StudioControl $chkOutline 20 158 180 28
    Place-StudioControl $lblOutlineWidth 222 162 90 24
    Place-StudioControl $txtOutlineWidth 350 158 80 28
    Place-StudioControl $lblOutlinePosition 20 210 92 24
    Place-StudioControl $cmbOutlinePosition 130 206 132 28
    Place-StudioControl $lblOutlineColor 20 250 92 24
    Place-StudioControl $txtOutlineColor 130 246 132 28
    Place-StudioControl $cardImageResize 0 306 450 192
    Place-StudioControl $lblImageFolder 20 18 300 24
    Place-StudioControl $txtImageFolder 20 50 300 28
    Place-StudioControl $btnImageFolder 332 46 98 38
    Place-StudioControl $btnResizeFolder 20 98 230 40
    Place-StudioControl $hintImageResize 20 150 205 26
    Place-StudioControl $hintImageResize2 220 150 210 26

    $studioFooter = New-Object SpineStudio.RoundPanel
    $form.Controls.Add($studioFooter)
    foreach ($ctrl in @($btnStart,$btnOpenOutput,$txtLog)) {$studioFooter.Controls.Add($ctrl)}
    $studioStatus = Add-Label $studioFooter '就绪 · 选择素材后开始' 20 14 700
    $studioStatus.ForeColor=$theme.Accent
    $studioProgress = New-Object SpineStudio.StudioProgress
    $studioProgress.AccessibleName='批次完成进度 / Completed files'
    $studioFooter.Controls.Add($studioProgress)
    $txtLog.Font=New-Object System.Drawing.Font('Microsoft YaHei UI',9)
    $txtLog.WordWrap=$false; $txtLog.ScrollBars='Both'
    $btnStart.Variant='primary'; $btnStart.Font=New-Object System.Drawing.Font('Microsoft YaHei UI',11,[System.Drawing.FontStyle]::Bold)
    $btnPreview.Variant='accent'
    $cardPreview.Controls.Add($btnPreview)
    $studioPreviewTitle=Add-Label $cardPreview '画面对照' 22 18 260
    $studioPreviewTitle.Font=New-Object System.Drawing.Font('Microsoft YaHei UI',14,[System.Drawing.FontStyle]::Bold)
    $studioPreviewTitle.Height=32
    foreach($viewport in @($pnlOriginalViewport,$pnlCutoutViewport)){$viewport.BackColor=$theme.Picture}
    $btnZoomOut.AccessibleName='缩小预览 / Zoom out'; $btnZoomIn.AccessibleName='放大预览 / Zoom in'
    foreach($pic in @($picOriginal,$picCutout)){
        $pic.Add_Paint({param($sender,$e)
            if($null -eq $sender.Image){
                $message=if($script:CurrentLanguage -eq 'zh-CN'){'添加视频或 GIF，选择素材后点击「更新预览」'}else{'Add a video or GIF, then select Update preview'}
                [System.Windows.Forms.TextRenderer]::DrawText($e.Graphics,$message,$sender.Font,$sender.ClientRectangle,[SpineStudio.Theme]::Muted,([System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter))
            }
        })
    }
    $studioLanguage={
        $cn=$script:CurrentLanguage -eq 'zh-CN'
        $names=if($cn){@('素材与抽帧','抠图与清边','导出设置','Spine 动画')}else{@('Source','Cutout','Export','Spine')}
        for($i=0;$i -lt 4;$i++){$studioTabs[$i].Text=$names[$i]}
        $studioPreviewTitle.Text=if($cn){'画面对照'}else{'Preview comparison'}
        if($studioProgress.Value -eq 0 -and !$script:StudioBusy){$studioStatus.Text=if($cn){'就绪 · 选择素材后开始'}else{'Ready · Choose source files to begin'}}
        $studioImportHint.Text=if($cn){'支持拖入多个视频 / GIF。每次导出新建文件夹，保留原始素材。描边设置位于「导出设置」。'}else{'Drop video or GIF files into the input. Exports use new folders. Outline settings are under Export.'}
        $picOriginal.Invalidate();$picCutout.Invalidate()
    }
    $cmbLanguage.Add_SelectedIndexChanged($studioLanguage)
    & $studioLanguage
    $studioPages[0].Visible=$true;$studioPages[1].Visible=$false;$studioPages[2].Visible=$false
    $studioTabs[0].Variant='selected'
    # Readable tooltips and explicit names preserve keyboard and assistive access.
    $studioTips=New-Object System.Windows.Forms.ToolTip
    $studioTips.AutoPopDelay=15000
    $studioTips.SetToolTip($txtVideo,'视频 / GIF 路径；每行一个文件。可点击选择素材或拖入文件。')
    $studioTips.SetToolTip($txtFps,'留空保持原始帧率；填写正数按指定 FPS 抽帧。')
    $studioTips.SetToolTip($txtOutput,'每次抽帧生成独立子目录。')
    foreach($entry in @(@($txtVideo,'视频或 GIF 路径'),@($txtOutput,'输出目录'),@($txtFps,'输出 FPS'),@($txtFrameCount,'抽帧张数'),@($txtTargetSize,'输出画布尺寸'),@($txtBgColor,'背景主颜色'),@($txtRangeA,'背景颜色范围 A'),@($txtRangeB,'背景颜色范围 B'),@($txtSamples,'取色样本'),@($txtLog,'处理日志'))){$entry[0].AccessibleName=$entry[1];if($entry[0] -is [SpineStudio.RoundTextBox]){$entry[0].Controls[0].AccessibleName=$entry[1]}}
    $script:StudioBusy=$false
    $form.Add_FormClosing({param($sender,$e) if($script:StudioBusy){$e.Cancel=$true;$studioStatus.Text='正在处理，请等待当前任务结束后关闭。'}})
    $layoutPreviewPanel = {
        $scale=$form.DeviceDpi / 96.0
        function U([double]$n){return [int][Math]::Round($n*$scale)}
        $w=[int]($form.ClientSize.Width/$scale);$h=[int]($form.ClientSize.Height/$scale)
        $form.SuspendLayout()
        $studioMark.SetBounds((U 24),(U 24),(U 56),(U 54))
        $title.SetBounds((U 98),(U 20),(U 650),(U 36))
        $subtitle.SetBounds((U 100),(U 61),(U 700),(U 26))
        $lblLanguage.SetBounds((U ($w-240)),(U 34),(U 96),(U 26))
        $cmbLanguage.SetBounds((U ($w-140)),(U 30),(U 112),(U 28))
        $studioSettings.SetBounds((U 24),(U 108),(U 474),(U ($h-284)))
        foreach($page in $studioPages){$page.SetBounds(0,(U 54),(U 474),(U ($h-338)))}
        $cardPreview.SetBounds((U 520),(U 108),(U ($w-544)),(U ($h-284)))
        $pw=$cardPreview.ClientSize.Width;$ph=$cardPreview.ClientSize.Height
        $btnPreview.SetBounds(($pw-(U 164)),(U 14),(U 144),(U 40))
        $sideBySide=($pw -ge (U 700))
        if($sideBySide){
            $vw=[int](($pw-(U 60))/2);$vh=$ph-(U 194)
            $lblOriginalPreview.SetBounds((U 20),(U 72),$vw,(U 26))
            $lblCutoutPreview.SetBounds(($vw+(U 40)),(U 72),$vw,(U 26))
            $pnlOriginalViewport.SetBounds((U 20),(U 106),$vw,$vh)
            $pnlCutoutViewport.SetBounds(($vw+(U 40)),(U 106),$vw,$vh)
        }else{
            $vw=$pw-(U 40);$vh=[int](($ph-(U 228))/2)
            $lblOriginalPreview.SetBounds((U 20),(U 66),$vw,(U 24))
            $pnlOriginalViewport.SetBounds((U 20),(U 94),$vw,$vh)
            $lblCutoutPreview.SetBounds((U 20),((U 106)+$vh),$vw,(U 24))
            $pnlCutoutViewport.SetBounds((U 20),((U 134)+$vh),$vw,$vh)
        }
        $zy=$ph-(U 78)
        $lblZoom.SetBounds((U 20),($zy+(U 8)),(U 54),(U 24))
        $btnZoomOut.SetBounds((U 80),$zy,(U 38),(U 36))
        $lblZoomValue.SetBounds((U 126),($zy+(U 8)),(U 60),(U 24))
        $btnZoomIn.SetBounds((U 190),$zy,(U 38),(U 36))
        $btnZoomReset.SetBounds((U 240),$zy,(U 104),(U 36))
        $lblPickHint.SetBounds((U 20),($zy+(U 42)),($pw-(U 40)),(U 36))
        $studioFooter.SetBounds((U 24),(U ($h-156)),(U ($w-48)),(U 136))
        $fw=$studioFooter.ClientSize.Width
        $studioStatus.SetBounds((U 20),(U 14),($fw-(U 440)),(U 26))
        $txtLog.SetBounds((U 20),(U 48),($fw-(U 440)),(U 66))
        $studioProgress.SetBounds(($fw-(U 396)),(U 18),(U 372),(U 8))
        $btnOpenOutput.SetBounds(($fw-(U 396)),(U 54),(U 174),(U 54))
        $btnStart.SetBounds(($fw-(U 208)),(U 54),(U 184),(U 54))
        $form.ResumeLayout()
        & $applyPreviewZoom
    }
    $form.ResumeLayout()

    # Material workbench: the canvas owns the flexible space; inspector is stable.
    $studioMark.Hide();$subtitle.Hide();$cardInput.Hide();$studioImportHint.Hide()
    $lblOriginalPreview.Hide();$lblCutoutPreview.Hide();$studioPreviewTitle.Hide();$lblZoom.Hide()
    $title.Font=[Drawing.Font]::new('Microsoft YaHei UI',12,[Drawing.FontStyle]::Bold)
    $form.MinimumSize=[Drawing.Size]::new(1120,760)
    $sourcePanel=New-Object System.Windows.Forms.Panel
    $sourcePanel.BackColor=$theme.Card;$form.Controls.Add($sourcePanel)
    foreach($control in @($btnVideo,$btnClear)){$sourcePanel.Controls.Add($control)}
    $sourceTitle=Add-Label $sourcePanel '素材' 14 12 130
    $sourceTitle.Font=[Drawing.Font]::new($form.Font,[Drawing.FontStyle]::Bold)
    $btnRemove=Add-Button $sourcePanel '移除选中' 0 0 100 32
    $sourceList=New-Object SpineStudio.SourceListView
    $sourceList.View='Details';$sourceList.FullRowSelect=$true;$sourceList.MultiSelect=$true
    $sourceList.HideSelection=$false;$sourceList.HeaderStyle='None';$sourceList.BorderStyle='None'
    $sourceList.BackColor=$theme.Card;$sourceList.ForeColor=$theme.Text;$sourceList.ShowItemToolTips=$true
    $sourceList.AccessibleName='素材列表';$sourceList.AllowDrop=$true
    [void]$sourceList.Columns.Add('文件',360);[void]$sourceList.Columns.Add('类型',70)
    [void]$sourceList.Columns.Add('大小',90)
    $sourcePanel.Controls.Add($sourceList)
    $sourceEmpty=Add-Label $sourcePanel '拖入视频 / GIF，或点击「添加素材」' 16 62 600
    $sourceEmpty.ForeColor=$theme.Muted;$sourceEmpty.AllowDrop=$true
    $sourceList.Add_DragEnter({param($s,$e) if(!$script:StudioBusy -and $e.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)){$e.Effect='Copy'}})
    $sourceEmpty.Add_DragEnter({param($s,$e) if(!$script:StudioBusy -and $e.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)){$e.Effect='Copy'}})
    $dropSources={param($s,$e) if(!$script:StudioBusy){Add-DroppedVideosToTextBox $txtVideo $e.Data.GetData([Windows.Forms.DataFormats]::FileDrop)}}
    $sourceList.Add_DragDrop($dropSources);$sourceEmpty.Add_DragDrop($dropSources)
    $canvasName=Add-Label $cardPreview '预览' 16 14 500
    $canvasName.AutoEllipsis=$true;$canvasName.ForeColor=$theme.Muted
    $viewOriginal=Add-Button $cardPreview '原图' 0 0 72 32
    $viewResult=Add-Button $cardPreview '结果' 0 0 72 32
    $viewCompare=Add-Button $cardPreview '并排对照' 0 0 100 32
    $script:WorkbenchView='result';$script:PreviewSource='';$script:PreviewDirty=$false
    $script:WorkbenchJob=$null;$script:LastExport='';$script:WorkbenchLogOpen=$false
    $viewOriginal.Add_Click({$script:WorkbenchView='original'; & $layoutPreviewPanel})
    $viewResult.Add_Click({$script:WorkbenchView='result'; & $layoutPreviewPanel})
    $viewCompare.Add_Click({$script:WorkbenchView='compare'; & $layoutPreviewPanel})
    $btnPreview.Variant='secondary'
    $inspectorTitle=Add-Label $studioSettings '处理参数' 12 12 430
    $inspectorTitle.Font=[Drawing.Font]::new($form.Font,[Drawing.FontStyle]::Bold)
    Place-StudioControl $cardMode 0 0 450 188
    foreach($card in @($cardMode,$cardBg,$cardEdge,$cardAction,$cardImageResize)){$card.Width=438}
    $cardPreview.Anchor=[Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Left
    $extractHelp=Add-Label $studioPages[0] '按张数：在整段素材中均匀选帧。\n按 FPS：保持原时长，改变采样频率。\n\n画布尺寸留空时保持原始尺寸；\n指定尺寸时等比缩放，透明补边。' 20 214 410
    $extractHelp.Text=$extractHelp.Text.Replace('\n',[Environment]::NewLine)
    $extractHelp.Height=155;$extractHelp.ForeColor=$theme.Muted
    $workflowHelp=Add-Label $studioPages[0] '先更新预览，再检查透明边缘，最后导出。' 20 390 410
    $workflowHelp.Height=50;$workflowHelp.ForeColor=$theme.Muted
    foreach($control in @($lblOutput,$txtOutput,$btnOutput)){$studioFooter.Controls.Add($control)}
    $btnLog=Add-Button $studioFooter '处理日志' 0 0 94 32
    $btnStop=Add-Button $studioFooter '完成本文件后停止' 0 0 174 34
    $btnStop.Visible=$false
    $logPanel=New-Object System.Windows.Forms.Panel
    $logPanel.BackColor=$theme.Card;$logPanel.Visible=$false;$form.Controls.Add($logPanel)
    $logTitle=Add-Label $logPanel '处理日志 · 失败时可复制此处内容排查' 16 10 750
    $logTitle.ForeColor=$theme.Muted
    $logPanel.Controls.Add($txtLog)
    $txtLog.ReadOnly=$true
    $btnLog.Add_Click({$script:WorkbenchLogOpen=!$script:WorkbenchLogOpen;& $layoutPreviewPanel})
    $btnOpenOutput.Add_Click({$folder=if($script:LastExport){$script:LastExport}else{$txtOutput.Text};if(Test-Path -LiteralPath $folder){Start-Process explorer.exe ('"'+$folder+'"')}})
    $studioStatus.AutoEllipsis=$true;$studioStatus.ForeColor=$theme.Muted
    $lblPickHint.AutoEllipsis=$true;$lblPickHint.ForeColor=$theme.Muted
    $studioTips.SetToolTip($btnStop,'完成正在处理的文件后停止。已经生成的结果会保留。')
    $studioTips.SetToolTip($viewOriginal,'在原图上取色。预览显示素材的第一帧。')
    $studioTips.SetToolTip($viewCompare,'宽窗口并排显示原图与结果；窄窗口自动显示结果单画布。')
    $studioTips.SetToolTip($txtTolerance,'颜色容差：0–255。越大，越多相近颜色会变透明。')
    $studioTips.SetToolTip($txtMinAlpha,'最低透明度阈值：0–255。低于阈值的像素会完全透明。')
    $studioTips.SetToolTip($txtDespill,'去色溢强度：0–100。用于减轻主体边缘的背景色残留。')
    $studioTips.SetToolTip($txtChoke,'向内收缩边缘的像素数。建议从 0 或 1 开始。')
    $studioTips.SetToolTip($txtBgColor,'留空自动取四角背景色。聚焦此输入框，再切到原图点击取色。')
    $refreshEnabled={
        $has=$sourceList.Items.Count -gt 0
        $btnStart.Enabled=$has -and !$script:StudioBusy
        $btnPreview.Enabled=$has -and !$script:StudioBusy
        $btnRemove.Enabled=$sourceList.SelectedItems.Count -gt 0 -and !$script:StudioBusy
        $btnClear.Enabled=$has -and !$script:StudioBusy
        $btnVideo.Enabled=!$script:StudioBusy
        $sourceList.Enabled=!$script:StudioBusy
        $studioSettings.Enabled=!$script:StudioBusy
        $txtOutput.Enabled=!$script:StudioBusy;$btnOutput.Enabled=!$script:StudioBusy
        $btnOpenOutput.Enabled=![string]::IsNullOrWhiteSpace($txtOutput.Text)
    }
    $syncSources={
        $selected=@($sourceList.SelectedItems|ForEach-Object{$_.Tag})
        $sourceList.BeginUpdate();$sourceList.Items.Clear()
        foreach($path in @(Get-VideoListFromText -Text $txtVideo.Text)){
            $item=[Windows.Forms.ListViewItem]::new([IO.Path]::GetFileName($path));$item.Tag=$path;$item.ToolTipText=$path
            [void]$item.SubItems.Add([IO.Path]::GetExtension($path).TrimStart('.').ToUpperInvariant())
            $length=if(Test-Path -LiteralPath $path -PathType Leaf){'{0:N1} MB' -f ((Get-Item -LiteralPath $path).Length/1MB)}else{'文件不存在'}
            [void]$item.SubItems.Add($length);[void]$sourceList.Items.Add($item)
            if($selected -contains $path){$item.Selected=$true}
        }
        if($sourceList.SelectedItems.Count -eq 0 -and $sourceList.Items.Count -gt 0){$sourceList.Items[0].Selected=$true}
        $sourceList.EndUpdate();$sourceEmpty.Visible=$sourceList.Items.Count -eq 0
        $sourceTitle.Text=if($script:CurrentLanguage -eq 'zh-CN'){"素材  $($sourceList.Items.Count)"}else{"Sources  $($sourceList.Items.Count)"}
        if($sourceList.Items.Count -eq 0){
            foreach($pic in @($picOriginal,$picCutout)){if($pic.Image){$old=$pic.Image;$pic.Image=$null;$old.Dispose()}}
            $script:PreviewSource='';$script:PreviewDirty=$false;$canvasName.Text='预览'
            if(!$script:StudioBusy){$studioStatus.Text='等待添加素材'}
        } elseif(!$script:StudioBusy){$studioStatus.Text="已添加 $($sourceList.Items.Count) 个素材，可更新预览或开始导出"}
        & $refreshEnabled
    }
    $txtVideo.Add_TextChanged($syncSources)
    $sourceList.Add_SelectedIndexChanged({
        & $refreshEnabled
        if($sourceList.SelectedItems.Count -gt 0){
            $selectedPath=[string]$sourceList.SelectedItems[0].Tag
            if($script:PreviewSource -ne $selectedPath){
                foreach($pic in @($picOriginal,$picCutout)){if($pic.Image){$old=$pic.Image;$pic.Image=$null;$old.Dispose()}}
                $canvasName.Text=[IO.Path]::GetFileName($selectedPath)+' · 待更新预览'
            }
        }
    })
    $btnRemove.Add_Click({
        $remove=@($sourceList.SelectedItems|ForEach-Object{$_.Tag})
        $txtVideo.Text=(@(Get-VideoListFromText -Text $txtVideo.Text|Where-Object{$_ -notin $remove}) -join [Environment]::NewLine)
    })
    $sourceList.Add_KeyDown({param($s,$e) if($e.KeyCode -eq 'Delete' -and $btnRemove.Enabled){$btnRemove.PerformClick();$e.Handled=$true}})
    $markPreviewDirty={if($picOriginal.Image -and !$script:StudioBusy){$script:PreviewDirty=$true;$canvasName.Text=[IO.Path]::GetFileName($script:PreviewSource)+' · 参数已改变，请更新预览'}}
    foreach($box in @($txtTargetSize,$txtBgColor,$txtTolerance,$txtSoftness,$txtRangeA,$txtRangeB,$txtSamples,$txtDespill,$txtChoke,$txtMinAlpha,$txtOutlineWidth,$txtOutlineColor)){$box.Add_TextChanged($markPreviewDirty)}
    foreach($check in @($chkRemoveBg,$chkSoftEdge,$chkDespill,$chkOutline)){$check.Add_CheckedChanged($markPreviewDirty)}
    $cmbOutlinePosition.Add_SelectedIndexChanged($markPreviewDirty)
    $updateSamplingFields={$txtFps.Enabled=$rbFps.Checked;$txtFrameCount.Enabled=$rbCount.Checked}
    $rbFps.Add_CheckedChanged($updateSamplingFields);$rbCount.Add_CheckedChanged($updateSamplingFields)
    & $updateSamplingFields
    $workbenchLanguage={
        $cn=$script:CurrentLanguage -eq 'zh-CN'
        $form.Text='Spine Frame Studio 2026.9.22';$title.Text='Spine Frame Studio'
        $studioTabs[0].Text=if($cn){'抽帧'}else{'Frames'}
        $studioTabs[1].Text=if($cn){'透明与边缘'}else{'Cutout'}
        $studioTabs[2].Text=if($cn){'导出工具'}else{'Export'}
        $studioTabs[3].Text=if($cn){'Spine 动画'}else{'Spine'}
        $btnVideo.Text=if($cn){'添加素材'}else{'Add files'}
        $btnClear.Text=if($cn){'清空'}else{'Clear'}
        $btnRemove.Text=if($cn){'移除选中'}else{'Remove'}
        $btnPreview.Text=if($cn){'更新预览'}else{'Update preview'}
        $btnStart.Text=if($cn){'开始导出'}else{'Export frames'}
        $btnOpenOutput.Text=if($cn){'打开输出'}else{'Open output'}
        $btnOutput.Text=if($cn){'选择目录'}else{'Browse'}
        $btnLog.Text=if($cn){'处理日志'}else{'Activity log'}
        $inspectorTitle.Text=if($cn){'处理参数'}else{'Inspector'}
        $viewOriginal.Text=if($cn){'原图'}else{'Original'}
        $viewResult.Text=if($cn){'结果'}else{'Result'}
        $viewCompare.Text=if($cn){'并排对照'}else{'Compare'}
        $btnZoomReset.Text=if($cn){'适合画布'}else{'Fit canvas'}
        $sourceEmpty.Text=if($cn){'拖入视频 / GIF，或点击「添加素材」'}else{'Drop videos / GIFs here, or choose Add files'}
        $chkCreateSpine.Text=if($cn){'抽帧后创建 Spine 动画工程'}else{'Create a Spine animation after export'}
        $lblSpineAnimation.Text=if($cn){'动画名称'}else{'Animation name'}
        $lblSpineFps.Text=if($cn){'动画 FPS'}else{'Animation FPS'}
        $chkSpineLoop.Text=if($cn){'循环播放'}else{'Loop'}
        $lblSpineTemplate.Text=if($cn){'模板工程'}else{'Template project'}
        $btnSpineTemplate.Text=if($cn){'选择模板'}else{'Browse'}
        $lblSpineSlot.Text=if($cn){'Mask 内目标 Slot（留空自动识别）'}else{'Target slot inside mask (blank = auto)'}
        $chkOpenSpine.Text=if($cn){'完成后打开生成的 Spine 工程'}else{'Open generated Spine project'}
        $extractHelp.Text=if($cn){"按张数：在整段素材中均匀选帧。`n按 FPS：保持原时长，改变采样频率。`n`n画布尺寸留空时保持原始尺寸；`n指定尺寸时等比缩放，透明补边。"}else{"Frame count: evenly sample the whole clip.`nFPS: sample at a chosen rate.`n`nLeave canvas size blank for original size.`nA specified size fits with transparent padding."}
        $workflowHelp.Text=if($cn){'先更新预览，再检查透明边缘，最后导出。'}else{'Update preview, inspect edges, then export.'}
    }
    $cmbLanguage.Add_SelectedIndexChanged($workbenchLanguage)
    $layoutPreviewPanel={
        $scale=$form.DeviceDpi/96.0
        function U([double]$n){[int][Math]::Round($n*$scale)}
        function B($c,$x,$y,$w,$h){$c.SetBounds((U $x),(U $y),(U $w),(U $h))}
        $w=$form.ClientSize.Width/$scale;$h=$form.ClientSize.Height/$scale
        $left=$w-510;$body=$h-186
        $form.SuspendLayout()
        B $title 20 14 530 30;B $lblLanguage ($w-222) 18 92 26;B $cmbLanguage ($w-130) 13 110 28
        B $sourcePanel 16 56 $left 134
        B $sourceTitle 14 13 ($left-346) 26
        B $btnVideo ($left-318) 7 110 34;B $btnRemove ($left-202) 7 110 34;B $btnClear ($left-86) 7 72 34
        B $sourceList 14 48 ($left-28) 78;B $sourceEmpty 18 70 ($left-36) 28
        $sourceList.Columns[0].Width=U ($left-210);$sourceList.Columns[1].Width=U 66;$sourceList.Columns[2].Width=U 96
        B $studioSettings ($w-478) 56 462 ($h-194)
        B $inspectorTitle 12 12 430 26
        foreach($i in 0..3){B $studioTabs[$i] ($i*113) 48 108 36; B $studioPages[$i] 0 96 462 ($h-290)}
        B $cardPreview 16 202 $left ($h-340)
        $pw=$left;$ph=$h-340
        B $canvasName 16 12 ($pw-32) 25
        B $viewOriginal 14 42 76 34;B $viewResult 94 42 76 34;B $viewCompare 174 42 106 34
        B $btnPreview ($pw-156) 42 142 34
        $dual=$script:WorkbenchView -eq 'compare' -and $pw -ge 760
        $showOriginal=$script:WorkbenchView -eq 'original'
        $pnlOriginalViewport.Visible=$dual -or $showOriginal
        $pnlCutoutViewport.Visible=$dual -or !$showOriginal
        if($dual){
            $vw=($pw-42)/2
            B $pnlOriginalViewport 14 88 $vw ($ph-154)
            B $pnlCutoutViewport (28+$vw) 88 $vw ($ph-154)
        }else{
            B $pnlOriginalViewport 14 88 ($pw-28) ($ph-154)
            B $pnlCutoutViewport 14 88 ($pw-28) ($ph-154)
        }
        $viewOriginal.Variant=if($showOriginal){'selected'}else{'secondary'}
        $viewResult.Variant=if(!$showOriginal -and !$dual){'selected'}else{'secondary'}
        $viewCompare.Variant=if($dual){'selected'}else{'secondary'}
        foreach($v in @($viewOriginal,$viewResult,$viewCompare)){$v.Invalidate()}
        B $btnZoomOut 14 ($ph-54) 34 32;B $lblZoomValue 55 ($ph-49) 64 24
        B $btnZoomIn 119 ($ph-54) 34 32;B $btnZoomReset 160 ($ph-54) 106 32
        B $lblPickHint 280 ($ph-51) ($pw-296) 32
        $lblPickHint.Text=if($script:CurrentLanguage -eq 'zh-CN'){'首帧预览 · 原图点击取色'}else{'First frame · Pick on original'}
        B $studioFooter 16 ($h-122) ($w-32) 106
        $fw=$w-32
        B $lblOutput 14 14 80 26;B $txtOutput 98 10 ($fw-496) 32
        B $btnOutput ($fw-388) 8 108 36;B $btnOpenOutput ($fw-272) 8 112 36
        B $btnStart ($fw-150) 8 136 40
        B $studioStatus 14 61 ($fw-340) 28
        B $btnStop ($fw-300) 56 184 34;B $btnLog ($fw-108) 56 94 34
        B $studioProgress 14 98 ($fw-28) 4
        $logPanel.Visible=$script:WorkbenchLogOpen
        B $logPanel 16 ($h-360) ($w-32) 226
        B $txtLog 14 40 ($w-60) 170
        if($script:WorkbenchLogOpen){$logPanel.BringToFront()}
        $form.ResumeLayout(); & $applyPreviewZoom
    }
    function Get-WorkbenchInteger($Box,[string]$Label,[int]$Min,[int]$Max){
        $n=0
        if(![int]::TryParse($Box.Text.Trim(),[ref]$n) -or $n -lt $Min -or $n -gt $Max){$Box.Controls[0].Focus();throw "$Label 请输入 $Min–$Max 的整数。"}
        return $n
    }
    $startWorkbenchJob={param([string]$operation)
        if($script:StudioBusy){return}
        try {
            $videos=@(Get-VideoListFromText -Text $txtVideo.Text)
            if($operation -ne 'resize' -and $videos.Count -eq 0){throw '请先添加视频或 GIF。'}
            if($operation -eq 'preview' -and $sourceList.SelectedItems.Count -gt 0){$videos=@([string]$sourceList.SelectedItems[0].Tag)}
            if($operation -eq 'preview'){$videos=@($videos[0])}
            if($operation -ne 'resize'){foreach($video in $videos){if(!(Test-VideoFile -Path $video)){throw "素材不存在或不受支持：$video"}}}
            $modeValue=if($rbCount.Checked){'count'}else{'fps'}
            if($operation -eq 'extract'){
                if([string]::IsNullOrWhiteSpace($txtOutput.Text)){throw '请选择输出目录。'}
                if($rbCount.Checked){[void](Get-WorkbenchInteger $txtFrameCount '抽帧张数' 1 100000)}
                if($rbFps.Checked -and $txtFps.Text.Trim()){$fpsCheck=0.0;if(![double]::TryParse($txtFps.Text.Trim(),[ref]$fpsCheck) -or $fpsCheck -le 0){throw 'FPS 请输入正数，或留空保持原帧率。'}}
                if($chkCreateSpine.Checked){
                    if([string]::IsNullOrWhiteSpace($txtSpineAnimation.Text)){throw '请填写 Spine 动画名称。'}
                    $spineFpsCheck=0.0;if(![double]::TryParse($txtSpineFps.Text.Trim(),[ref]$spineFpsCheck) -or $spineFpsCheck -le 0 -or $spineFpsCheck -gt 240){throw 'Spine 动画 FPS 请输入 0–240 之间的正数。'}
                    if($txtSpineTemplate.Text.Trim() -and !(Test-Path -LiteralPath $txtSpineTemplate.Text.Trim() -PathType Leaf)){throw 'Spine 模板文件不存在。'}
                }
            }
            $size=Parse-TargetSize -Text $txtTargetSize.Text.Trim()
            foreach($entry in @(@($txtTolerance,'颜色容差',0,255),@($txtSoftness,'柔化范围',0,255),@($txtDespill,'去色溢强度',0,100),@($txtChoke,'收边像素',0,100),@($txtMinAlpha,'最低透明度',0,255))){[void](Get-WorkbenchInteger $entry[0] $entry[1] $entry[2] $entry[3])}
            $outline=& $getOutlineSettings
            $gifFpsValue=12;if($chkGif.Checked){$gifFpsValue=Get-WorkbenchInteger $txtGifFps 'GIF FPS' 1 120}
            $arguments=switch($operation){
                'extract' { @{Root=$txtOutput.Text.Trim(); ExtractMode=$modeValue; FrameRate=$txtFps.Text.Trim(); ExactFrameCount=([int]$txtFrameCount.Text); DoRemoveBg=$chkRemoveBg.Checked; ManualBgColor=$txtBgColor.Text.Trim(); RangeColorAHex=$txtRangeA.Text.Trim(); RangeColorBHex=$txtRangeB.Text.Trim(); SampleColorHexList=$txtSamples.Text.Trim(); BgTolerance=([int]$txtTolerance.Text); UseSoftEdge=$chkSoftEdge.Checked; SoftnessValue=([int]$txtSoftness.Text); TargetWidth=$size.Width; TargetHeight=$size.Height; UseDespill=$chkDespill.Checked; DespillStrength=([int]$txtDespill.Text); ChokePixels=([int]$txtChoke.Text); MinAlpha=([int]$txtMinAlpha.Text); UseSpineNames=$chkSpineNames.Checked; Prefix=$txtPrefix.Text.Trim(); MakePreviewGif=$chkGif.Checked; PreviewGifFps=$gifFpsValue; UseOutline=$outline.Enabled; OutlineWidth=$outline.Width; OutlineColorHex=$outline.Color; OutlinePosition=$outline.Position} }
                'preview' { @{ManualColor=$txtBgColor.Text.Trim(); RangeColorAHex=$txtRangeA.Text.Trim(); RangeColorBHex=$txtRangeB.Text.Trim(); SampleColorHexList=$txtSamples.Text.Trim(); ToleranceValue=([int]$txtTolerance.Text); UseSoftEdge=$chkSoftEdge.Checked; SoftnessValue=([int]$txtSoftness.Text); TargetWidth=$size.Width; TargetHeight=$size.Height; UseDespill=$chkDespill.Checked; DespillStrength=([int]$txtDespill.Text); ChokePixels=([int]$txtChoke.Text); MinAlpha=([int]$txtMinAlpha.Text); UseOutline=$outline.Enabled; OutlineWidth=$outline.Width; OutlineColorHex=$outline.Color; OutlinePosition=$outline.Position} }
                'resize' {
                    if(!(Test-Path -LiteralPath $txtImageFolder.Text.Trim() -PathType Container)){throw '请选择存在的图片目录。'}
                    if($size.Width -le 0 -or $size.Height -le 0){throw '请在抽帧页填写画布尺寸，例如 256x256。'}
                    @{ImageFolder=$txtImageFolder.Text.Trim();TargetWidth=$size.Width;TargetHeight=$size.Height}
                }
            }
            $jobDirectory=Join-Path $env:TEMP ('SpineWorkbench_'+[guid]::NewGuid().ToString('N'))
            [void](New-Item -ItemType Directory -Path $jobDirectory)
            $spineOptions=@{Enabled=($operation -eq 'extract' -and $chkCreateSpine.Checked);AnimationName=$txtSpineAnimation.Text.Trim();Fps=$txtSpineFps.Text.Trim();Loop=$chkSpineLoop.Checked;TemplatePath=$txtSpineTemplate.Text.Trim();TargetSlot=$txtSpineSlot.Text.Trim();OpenAfter=$chkOpenSpine.Checked;Version='4.1.24'}
            $config=@{operation=$operation;videos=$videos;arguments=$arguments;outline=$outline;removeBackground=$chkRemoveBg.Checked;spine=$spineOptions}
            [IO.File]::WriteAllText((Join-Path $jobDirectory 'config.json'),($config|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
            $worker=Join-Path $Script:ToolDir 'workbench_worker.ps1'
            $process=Start-Process -FilePath (Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-STA','-File',('"'+$worker+'"'),'-JobDirectory',('"'+$jobDirectory+'"')) -WindowStyle Hidden -PassThru -RedirectStandardError (Join-Path $jobDirectory 'stderr.log')
            $script:WorkbenchJob=@{Directory=$jobDirectory;Process=$process;Operation=$operation;Started=Get-Date;Videos=$videos;LastState=$null}
            $script:StudioBusy=$true;$studioProgress.Value=0;$studioProgress.Maximum=[Math]::Max(1,$videos.Count)
            $studioStatus.ForeColor=$theme.Text;$studioStatus.Text='正在准备任务…';$txtLog.Clear()
            $btnStop.Visible=$operation -eq 'extract' -and $videos.Count -gt 1;$btnStop.Enabled=$true;$btnStop.Text='完成本文件后停止'
            & $refreshEnabled;$jobTimer.Start()
        } catch {
            $studioStatus.Text='无法开始：'+$_.Exception.Message;$studioStatus.ForeColor=[Drawing.ColorTranslator]::FromHtml('#FFB3AC')
            $studioTips.SetToolTip($studioStatus,$studioStatus.Text);$txtLog.AppendText($studioStatus.Text+[Environment]::NewLine)
        }
    }
    $btnStop.Add_Click({
        if($script:WorkbenchJob){[IO.File]::WriteAllText((Join-Path $script:WorkbenchJob.Directory 'stop'),'stop');$btnStop.Enabled=$false;$btnStop.Text='本文件完成后停止'}
    })
    $jobTimer=New-Object Windows.Forms.Timer;$jobTimer.Interval=250
    $jobTimer.Add_Tick({
        if(!$script:WorkbenchJob){return}
        try {
            $job=$script:WorkbenchJob;$statusFile=Join-Path $job.Directory 'status.json'
            if(Test-Path -LiteralPath $statusFile){
                try {$state=Get-Content -LiteralPath $statusFile -Raw -Encoding UTF8|ConvertFrom-Json;$job.LastState=$state}catch{return}
                $elapsed=[int]((Get-Date)-$job.Started).TotalSeconds
                $studioProgress.Maximum=[Math]::Max(1,[int]$state.total);$studioProgress.Value=[int]$state.completed
                $studioStatus.Text="$($state.phase) · $($state.completed)/$($state.total) 个文件 · ${elapsed}s · $($state.current)"
                $studioTips.SetToolTip($studioStatus,$studioStatus.Text)
                $logFile=Join-Path $job.Directory 'activity.log'
                if(Test-Path -LiteralPath $logFile){$newLog=Get-Content -LiteralPath $logFile -Tail 100 -Encoding UTF8;$txtLog.Text=$newLog -join [Environment]::NewLine;$txtLog.SelectionStart=$txtLog.TextLength;$txtLog.ScrollToCaret()}
                if($state.state -in @('done','failed','stopped')){
                    $jobTimer.Stop();$script:StudioBusy=$false;$btnStop.Visible=$false
                    if($state.state -eq 'done'){
                        if($job.Operation -eq 'preview'){
                            $script:PreviewOriginalPath=$state.preview.Original
                            Set-PictureBoxImage $picOriginal $state.preview.Original;Set-PictureBoxImage $picCutout $state.preview.Cutout
                            $script:PreviewSource=$job.Videos[0];$script:PreviewDirty=$false
                            $canvasName.Text=[IO.Path]::GetFileName($script:PreviewSource)+" · $($picOriginal.Image.Width) × $($picOriginal.Image.Height) · 首帧"
                            $script:WorkbenchView='result';& $setPreviewZoom 1.0;& $layoutPreviewPanel
                            $studioStatus.Text="预览已更新 · ${elapsed}s"
                        }else{
                            $script:LastExport=@($state.outputs)[-1]
                            if(@($state.spineProjects).Count -gt 0){
                                $script:LastExport=Split-Path -Parent ([string]@($state.spineProjects)[-1])
                                $studioStatus.Text="导出和 Spine 工程创建完成 · $($state.completed) 个文件 · ${elapsed}s"
                                if($state.openSpine -and @($state.spineProjects).Count -eq 1){Start-Process -FilePath ([string]@($state.spineProjects)[0])}
                            }else{$studioStatus.Text="导出完成 · $($state.completed) 个文件 · ${elapsed}s · 点击「打开输出」查看"}
                        }
                        $studioStatus.ForeColor=[Drawing.ColorTranslator]::FromHtml('#A9D5B6')
                    }elseif($state.state -eq 'stopped'){
                        $studioStatus.Text="任务已停止 · 已完成 $($state.completed) 个文件，结果已保留"
                        if(@($state.outputs).Count -gt 0){$script:LastExport=@($state.outputs)[-1]}
                    }else{
                        $studioStatus.Text='处理失败：'+$state.error
                        $txtLog.AppendText([Environment]::NewLine+$studioStatus.Text)
                        $script:WorkbenchLogOpen=$true;& $layoutPreviewPanel
                        $studioStatus.ForeColor=[Drawing.ColorTranslator]::FromHtml('#FFB3AC')
                    }
                    $studioTips.SetToolTip($studioStatus,$studioStatus.Text)
                    $script:WorkbenchLastJob=$job;$script:WorkbenchJob=$null;& $refreshEnabled
                }
            }
            if($script:WorkbenchJob -and $job.Process.HasExited -and (!$job.LastState -or $job.LastState.state -eq 'running')){
                throw '后台进程意外退出。请查看处理日志。'
            }
        }catch{
            $jobTimer.Stop();$script:StudioBusy=$false;$btnStop.Visible=$false
            $studioStatus.Text='处理失败：'+$_.Exception.Message
            if($script:WorkbenchJob){$errorLog=Join-Path $script:WorkbenchJob.Directory 'stderr.log';if(Test-Path -LiteralPath $errorLog){$txtLog.AppendText((Get-Content -LiteralPath $errorLog -Raw))}}
            $script:WorkbenchLogOpen=$true;$script:WorkbenchJob=$null;& $refreshEnabled;& $layoutPreviewPanel
        }
    })
    $form.Add_FormClosed({$jobTimer.Stop();$jobTimer.Dispose();$studioTips.Dispose()})

    & $applyLanguage
    & $workbenchLanguage
    & $syncSources
    & $layoutPreviewPanel
    $form.Add_Resize({ & $layoutPreviewPanel })

    $ff = Get-FFmpegPath
    if ($ff) { $txtLog.AppendText("FFmpeg found: $ff" + [Environment]::NewLine) } else { $txtLog.AppendText('FFmpeg not found.' + [Environment]::NewLine) }
    $form.Add_FormClosed({
        if ($null -ne $picOriginal.Image) { $oldOriginal = $picOriginal.Image; $picOriginal.Image = $null; $oldOriginal.Dispose() }
        if ($null -ne $picCutout.Image) { $oldCutout = $picCutout.Image; $picCutout.Image = $null; $oldCutout.Dispose() }
    })
    if ($env:SPINE_STUDIO_VERIFY -eq '1') {
        $script:StudioTestContext = @{ Form=$form; Video=$txtVideo; Output=$txtOutput; Start=$btnStart; Preview=$btnPreview; Original=$picOriginal; Cutout=$picCutout; Tabs=$studioTabs; Pages=$studioPages; Status=$studioStatus; Count=$rbCount; FrameCount=$txtFrameCount; RemoveBg=$chkRemoveBg; Language=$cmbLanguage; Log=$txtLog; ZoomIn=$btnZoomIn; ZoomOut=$btnZoomOut; ZoomReset=$btnZoomReset; CreateSpine=$chkCreateSpine; SpineTemplate=$txtSpineTemplate; SpineSlot=$txtSpineSlot; SpineAnimation=$txtSpineAnimation; SpineFps=$txtSpineFps }
        if ($env:SPINE_STUDIO_VERIFY_SCRIPT) { . $env:SPINE_STUDIO_VERIFY_SCRIPT }
        return $null
    }
    [void]$form.ShowDialog()
}
