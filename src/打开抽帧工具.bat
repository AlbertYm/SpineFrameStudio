@echo off
setlocal

REM Spine Video Frame Extractor - GUI launcher

pushd "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -STA -File ".\extract_frames.ps1"

if errorlevel 1 (
    echo.
    echo Tool startup failed. The error message is shown above.
    echo Please send a screenshot if you want me to fix it further.
    pause
)

endlocal
