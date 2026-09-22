param([switch]$ForPublicRelease,[switch]$WithoutFfmpeg)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root 'src'
$v = Get-Content (Join-Path $src 'version.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$dependency = Get-Content (Join-Path $root 'compliance/dependency-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($ForPublicRelease) {
    if (!$WithoutFfmpeg -and $dependency.redistributionReady -ne $true) { throw 'Public release with bundled FFmpeg blocked: third-party corresponding source and license review are incomplete. Use -WithoutFfmpeg or see compliance/README.md.' }
    if (!$WithoutFfmpeg -and (Get-FileHash (Join-Path $src 'ffmpeg.exe') -Algorithm SHA256).Hash -ne $dependency.ffmpeg.binarySha256) { throw 'FFmpeg does not match the reviewed dependency manifest.' }
}
if (!$WithoutFfmpeg -and !(Test-Path (Join-Path $src 'ffmpeg.exe'))) { throw 'Place a trusted Windows x64 ffmpeg.exe in src first, or build with -WithoutFfmpeg.' }
if (!$ForPublicRelease) { Write-Warning 'Local verification build only. Do not upload this output as a public release.' }
Import-Module (Join-Path $root 'third_party/ps2exe/ps2exe.psd1') -Force
$suffix=if($WithoutFfmpeg){'_no-ffmpeg'}else{''}
$package = Join-Path $root ('dist/SpineFrameStudio_' + $v.version + $suffix)
$zip = $package + '.zip'
if ((Test-Path $package) -or (Test-Path $zip)) { throw 'Output exists. Preserve it and select a new version or a clean checkout.' }
New-Item -ItemType Directory -Path $package -Force | Out-Null
$files=@('extract_frames.ps1','extract_frames_core.ps1','extract_frames_ui.ps1','workbench_worker.ps1','spine_project.ps1','studio_controls.cs','ui_text.json','version.json','打开抽帧工具.bat','拖拽视频到这里抽帧.bat')
if(!$WithoutFfmpeg){$files+='ffmpeg.exe'}
foreach ($name in $files) { Copy-Item -LiteralPath (Join-Path $src $name) -Destination $package }
Copy-Item (Join-Path $root 'docs/使用说明.md') (Join-Path $package 'README_先看这里.md')
Copy-Item (Join-Path $root 'THIRD_PARTY_NOTICES.md') $package
Copy-Item (Join-Path $root 'LICENSE') $package
Copy-Item (Join-Path $root 'licenses') (Join-Path $package 'licenses') -Recurse
Copy-Item (Join-Path $root 'compliance') (Join-Path $package 'compliance') -Recurse
Copy-Item (Join-Path $root 'third_party') (Join-Path $package 'third_party') -Recurse
if($WithoutFfmpeg){
    @'
此公开包不包含 ffmpeg.exe。

使用抽帧、GIF 和预览功能前，请从可信来源取得 Windows x64 FFmpeg，任选一种方式配置：
1. 把 ffmpeg.exe 放在本目录；或
2. 把 FFmpeg 加入系统 PATH。

官方下载说明：https://ffmpeg.org/download.html
软件启动和界面预览不依赖在线服务；创建 .spine 工程还需要本机安装并激活 Spine 4.1.24。
'@ | Set-Content -LiteralPath (Join-Path $package 'FFMPEG_REQUIRED_先看这里.txt') -Encoding UTF8
}
Invoke-ps2exe -InputFile (Join-Path $package 'extract_frames.ps1') -OutputFile (Join-Path $package $v.executable) -NoConsole -STA -x64 -DPIAware -Title $v.product -Product $v.product -Version $v.fileVersion
Get-ChildItem $package -File -Recurse | Where-Object Name -ne 'SHA256SUMS.txt' | Sort-Object FullName | ForEach-Object { '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash,$_.FullName.Substring($package.Length + 1).Replace('\','/') } | Set-Content (Join-Path $package 'SHA256SUMS.txt') -Encoding UTF8
Compress-Archive -LiteralPath $package -DestinationPath $zip
Get-FileHash $zip -Algorithm SHA256
