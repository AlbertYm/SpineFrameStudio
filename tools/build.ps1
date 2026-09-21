param([switch]$ForPublicRelease)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root 'src'
$v = Get-Content (Join-Path $src 'version.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$dependency = Get-Content (Join-Path $root 'compliance/dependency-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($ForPublicRelease) {
    if ($dependency.redistributionReady -ne $true) { throw 'Public release blocked: third-party corresponding source and license review are incomplete. See compliance/README.md.' }
    if ((Get-FileHash (Join-Path $src 'ffmpeg.exe') -Algorithm SHA256).Hash -ne $dependency.ffmpeg.binarySha256) { throw 'FFmpeg does not match the reviewed dependency manifest.' }
}
if (!(Test-Path (Join-Path $src 'ffmpeg.exe'))) { throw 'Place a trusted Windows x64 ffmpeg.exe in src first.' }
if (!$ForPublicRelease) { Write-Warning 'Local verification build only. Do not upload this output as a public release.' }
Import-Module (Join-Path $root 'third_party/ps2exe/ps2exe.psd1') -Force
$package = Join-Path $root ('dist/SpineFrameStudio_' + $v.version)
$zip = $package + '.zip'
if ((Test-Path $package) -or (Test-Path $zip)) { throw 'Output exists. Preserve it and select a new version or a clean checkout.' }
New-Item -ItemType Directory -Path $package -Force | Out-Null
foreach ($name in @('extract_frames.ps1','extract_frames_core.ps1','extract_frames_ui.ps1','workbench_worker.ps1','studio_controls.cs','ui_text.json','version.json','ffmpeg.exe','打开抽帧工具.bat','拖拽视频到这里抽帧.bat')) { Copy-Item -LiteralPath (Join-Path $src $name) -Destination $package }
Copy-Item (Join-Path $root 'docs/使用说明.md') (Join-Path $package 'README_先看这里.md')
Copy-Item (Join-Path $root 'THIRD_PARTY_NOTICES.md') $package
Copy-Item (Join-Path $root 'LICENSE') $package
Copy-Item (Join-Path $root 'licenses') (Join-Path $package 'licenses') -Recurse
Copy-Item (Join-Path $root 'compliance') (Join-Path $package 'compliance') -Recurse
Copy-Item (Join-Path $root 'third_party') (Join-Path $package 'third_party') -Recurse
Invoke-ps2exe -InputFile (Join-Path $package 'extract_frames.ps1') -OutputFile (Join-Path $package $v.executable) -NoConsole -STA -x64 -DPIAware -Title $v.product -Product $v.product -Version $v.fileVersion
Get-ChildItem $package -File -Recurse | Where-Object Name -ne 'SHA256SUMS.txt' | Sort-Object FullName | ForEach-Object { '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash,$_.FullName.Substring($package.Length + 1).Replace('\','/') } | Set-Content (Join-Path $package 'SHA256SUMS.txt') -Encoding UTF8
Compress-Archive -LiteralPath $package -DestinationPath $zip
Get-FileHash $zip -Algorithm SHA256
