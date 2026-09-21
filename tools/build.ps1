$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root 'src'
$v = Get-Content (Join-Path $src 'version.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if (!(Test-Path (Join-Path $src 'ffmpeg.exe'))) { throw 'Place a trusted Windows x64 ffmpeg.exe in src first.' }
if (!(Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue)) { throw 'Install PS2EXE on the development machine first: Install-Module ps2exe -Scope CurrentUser' }
$package = Join-Path $root ('dist/SpineFrameStudio_' + $v.version)
$zip = $package + '.zip'
if ((Test-Path $package) -or (Test-Path $zip)) { throw 'Output exists. Preserve it and select a new version or a clean checkout.' }
New-Item -ItemType Directory -Path $package -Force | Out-Null
Copy-Item (Join-Path $src '*') $package
Copy-Item (Join-Path $root 'docs/使用说明.md') (Join-Path $package 'README_先看这里.md')
Copy-Item (Join-Path $root 'THIRD_PARTY_NOTICES.md') $package
Invoke-ps2exe -InputFile (Join-Path $package 'extract_frames.ps1') -OutputFile (Join-Path $package $v.executable) -NoConsole -STA -x64 -DPIAware -Title $v.product -Product $v.product -Version $v.fileVersion
Get-ChildItem $package -File | Where-Object Name -ne 'SHA256SUMS.txt' | Sort-Object Name | ForEach-Object { '{0}  {1}' -f (Get-FileHash $_.FullName -Algorithm SHA256).Hash,$_.Name } | Set-Content (Join-Path $package 'SHA256SUMS.txt') -Encoding UTF8
Compress-Archive -LiteralPath $package -DestinationPath $zip
Get-FileHash $zip -Algorithm SHA256
