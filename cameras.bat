```bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

:: ═══════════════════════════════════════════════════════════
::  CAMERA SETTINGS — CHANGE ONLY THIS SECTION
:: ═══════════════════════════════════════════════════════════

:: Full path to ffmpeg.exe
:: Example: C:\ffmpeg\bin\ffmpeg.exe
set "FF=C:\ffmpeg\bin\ffmpeg.exe"

:: Camera name
:: Example: cam1, front_gate, parking
:: Do not use these characters: \ / : * ? " < > |
set "CAM_NAME=YOUR_CAMERA_NAME"

:: Camera IP address
:: Example: 192.168.50.33
set "CAM_IP=YOUR_CAMERA_IP"

:: RTSP stream address
:: Replace:
:: YOUR_LOGIN   — camera username
:: YOUR_PASSWORD — camera password
::
:: Channel 101 = main stream, high quality
:: Channel 102 = sub stream, lower quality
set "URL=rtsp://YOUR_LOGIN:YOUR_PASSWORD@%CAM_IP%:554/Streaming/Channels/101"

:: Folder where video files will be saved
:: Example: Z:\Cam\Cam1
set "OUT=Z:\Cam\YOUR_CAMERA_FOLDER"

:: Log folder
:: Usually you do not need to change this line
set "LOG_DIR=%OUT%\logs"

:: ═══════════════════════════════════════════════════════════
::  RECONNECT SETTINGS — USUALLY DO NOT NEED TO CHANGE
:: ═══════════════════════════════════════════════════════════

set "WAIT_MIN=3"
set "WAIT_MAX=120"
set "WAIT_RESET_AFTER=300"
set "RTSP_TIMEOUT=10000000"

if not exist "%OUT%" mkdir "%OUT%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

set "WAIT=%WAIT_MIN%"
set "TOTAL_STARTS=0"
set "TOTAL_FAILS=0"

title %CAM_NAME% — %CAM_IP%

:: ═══════════════════════════════════════════════════════════
:loop
for /f "tokens=1-3 delims=." %%a in ("%date%") do set "TODAY=%%c-%%b-%%a"
set "LOG=%LOG_DIR%\%CAM_NAME%_%TODAY%.log"
set "FFLOG=%LOG_DIR%\%CAM_NAME%_%TODAY%_ffmpeg.log"

:: ─── Ping ────────────────────────────────────────────────
ping -n 1 -w 2000 %CAM_IP% >nul 2>&1
if errorlevel 1 (
    call :log "PING_FAIL" "camera unreachable, waiting %WAIT%s"
    title %CAM_NAME% — OFFLINE
    timeout /t %WAIT% /nobreak >nul
    call :increase_wait
    goto loop
)

:: ─── RTSP port ───────────────────────────────────────────
powershell -NoProfile -Command "try{$c=New-Object Net.Sockets.TcpClient;$c.Connect('%CAM_IP%',554);$c.Close();exit 0}catch{exit 1}" >nul 2>&1
if errorlevel 1 (
    call :log "RTSP_CLOSED" "port 554 closed, waiting %WAIT%s"
    timeout /t %WAIT% /nobreak >nul
    call :increase_wait
    goto loop
)

:: ─── Starting ffmpeg ───────────────────────────────────────
set /a "TOTAL_STARTS+=1"
call :log "START" "connecting [#%TOTAL_STARTS%, backoff=%WAIT%s]"
title %CAM_NAME% — REC #%TOTAL_STARTS%

for /f "tokens=1-4 delims=:,. " %%a in ("%time: =0%") do (
    set /a "T_START=%%a*3600 + %%b*60 + %%c"
)

"%FF%" -hide_banner -loglevel info ^
  -rtsp_transport tcp ^
  -rtsp_flags prefer_tcp ^
  -timeout %RTSP_TIMEOUT% ^
  -buffer_size 4194304 ^
  -fflags +discardcorrupt+genpts+igndts ^
  -use_wallclock_as_timestamps 1 ^
  -thread_queue_size 512 ^
  -err_detect ignore_err ^
  -max_delay 5000000 ^
  -i "%URL%" ^
  -an -map 0:v:0 ^
  -c:v copy ^
  -fps_mode passthrough ^
  -muxdelay 0 -muxpreload 0 ^
  -avoid_negative_ts make_zero ^
  -flush_packets 1 ^
  -f segment ^
  -segment_time 600 ^
  -segment_atclocktime 1 ^
  -break_non_keyframes 1 ^
  -reset_timestamps 1 ^
  -strftime 1 ^
  -segment_format_options mpegts_flags=+resend_headers ^
  -write_empty_segments 0 ^
  "%OUT%\%%Y-%%m-%%d_%%H-%%M-%%S.ts" 2>>"%FFLOG%"

set "EXIT_CODE=%errorlevel%"

for /f "tokens=1-4 delims=:,. " %%a in ("%time: =0%") do (
    set /a "T_END=%%a*3600 + %%b*60 + %%c"
)
set /a "RUNTIME=T_END - T_START"
if !RUNTIME! lss 0 set /a "RUNTIME=RUNTIME + 86400"

set /a "RT_H=RUNTIME / 3600"
set /a "RT_M=(RUNTIME %% 3600) / 60"
set /a "RT_S=RUNTIME %% 60"
if !RT_H! lss 10 set "RT_H=0!RT_H!"
if !RT_M! lss 10 set "RT_M=0!RT_M!"
if !RT_S! lss 10 set "RT_S=0!RT_S!"

if !RUNTIME! geq %WAIT_RESET_AFTER% (
    call :log "STABLE" "exit=%EXIT_CODE%, runtime=%RT_H%:%RT_M%:%RT_S% — OK, reset backoff"
    set "WAIT=%WAIT_MIN%"
) else (
    set /a "TOTAL_FAILS+=1"
    call :increase_wait
    if !RUNTIME! leq 10 (
        call :log "CRASH" "exit=%EXIT_CODE%, runtime=%RT_H%:%RT_M%:%RT_S% — INSTANT FAIL, wait=%WAIT%s [fails=%TOTAL_FAILS%/%TOTAL_STARTS%]"
    ) else if !RUNTIME! leq 60 (
        call :log "UNSTABLE" "exit=%EXIT_CODE%, runtime=%RT_H%:%RT_M%:%RT_S% — short, wait=%WAIT%s [fails=%TOTAL_FAILS%/%TOTAL_STARTS%]"
    ) else (
        call :log "STOPPED" "exit=%EXIT_CODE%, runtime=%RT_H%:%RT_M%:%RT_S%, wait=%WAIT%s [fails=%TOTAL_FAILS%/%TOTAL_STARTS%]"
    )
)

echo.>> "%FFLOG%"
echo ---- %date% %time% exit=%EXIT_CODE% runtime=%RUNTIME%s ---->> "%FFLOG%"
echo.>> "%FFLOG%"

title %CAM_NAME% — waiting %WAIT%s...
timeout /t %WAIT% /nobreak >nul
goto loop

:: ═══════════════════════════════════════════════════════════
:log
set "LVL=%~1"
set "MSG=%~2"
set "TS=%date% %time:~0,8%"
set "LINE=[%TS%] [%CAM_NAME%] [%LVL%] %MSG%"
echo %LINE%
echo %LINE%>> "%LOG%"
exit /b

:increase_wait
set /a "WAIT=WAIT * 2"
if !WAIT! gtr %WAIT_MAX% set "WAIT=%WAIT_MAX%"
exit /b
```
