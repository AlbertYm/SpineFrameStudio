@echo off
setlocal

REM Spine Video Frame Extractor Pro - drag and drop launcher
REM Drag one or more video or GIF files onto this .bat file. The GUI will open with these files preloaded.

pushd "%~dp0"

if "%~1"=="" (
    echo Drag video or GIF files onto this bat file.
    echo Supported: mp4, mov, avi, mkv, webm, m4v, wmv, gif.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -STA -Command "$videos = @(); foreach ($a in $args) { $videos += $a }; & '.\extract_frames.ps1' -Gui -InputVideos $videos" %*

if errorlevel 1 (
    echo.
    echo Tool failed. The error message is shown above.
    pause
    exit /b 1
)

endlocal
