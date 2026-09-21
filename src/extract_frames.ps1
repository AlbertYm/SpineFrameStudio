param(
    [string[]]$InputVideos = @(),
    [string]$Mode = 'fps',
    [string]$Fps = '',
    [int]$FrameCount = 10,
    [string]$OutputRoot = '',
    [switch]$Gui
)

function Get-ToolDirectory {
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { $candidates += $PSScriptRoot }
    if (-not [string]::IsNullOrWhiteSpace($PSCommandPath)) { $candidates += (Split-Path -Parent $PSCommandPath) }
    if ($MyInvocation -and $MyInvocation.MyCommand -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) { $candidates += (Split-Path -Parent $MyInvocation.MyCommand.Path) }
    try {
        $processPath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        if (-not [string]::IsNullOrWhiteSpace($processPath)) { $candidates += (Split-Path -Parent $processPath) }
    } catch {}
    try { $candidates += (Get-Location).Path } catch {}
    foreach ($candidate in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    return [Environment]::CurrentDirectory
}

$Script:ToolDir = Get-ToolDirectory
if ([string]::IsNullOrWhiteSpace($OutputRoot)) { $OutputRoot = $Script:ToolDir }

$corePath = Join-Path $Script:ToolDir 'extract_frames_core.ps1'
$uiPath = Join-Path $Script:ToolDir 'extract_frames_ui.ps1'
if (-not (Test-Path -LiteralPath $corePath)) { throw "Missing required file: $corePath" }
if (-not (Test-Path -LiteralPath $uiPath)) { throw "Missing required file: $uiPath" }

. $corePath
. $uiPath

if ($InputVideos.Count -gt 0 -and -not $Gui) {
    Run-ConsoleMode
} else {
    Run-GuiMode
}
