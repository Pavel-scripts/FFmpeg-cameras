```bat
@echo off
chcp 65001 >nul
setlocal

:: ═══════════════════════════════════════════════════════════
::  FOLDER SETTINGS — CHANGE ONLY THIS SECTION
:: ═══════════════════════════════════════════════════════════

:: Camera recording folders
:: Replace these paths with your own camera folders.
:: Example: Z:\Cam\Cam1
set "CAM1=YOUR_CAMERA_1_FOLDER"
set "CAM2=YOUR_CAMERA_2_FOLDER"
set "CAM3=YOUR_CAMERA_3_FOLDER"

:: Recycle folder
:: All .ts files inside this folder will be deleted.
:: Example: Z:\@Recycle
set "RECYCLE=YOUR_RECYCLE_FOLDER"

:: Number of days to keep camera recordings.
:: Files older than this value will be deleted.
:: Example: 3 means files older than 3 days.
set "KEEP_DAYS=3"

:: Time between cleanup checks, in seconds.
:: 3600 seconds = 60 minutes
:: 1800 seconds = 30 minutes
:: 7200 seconds = 2 hours
set "CHECK_INTERVAL=3600"

:: ═══════════════════════════════════════════════════════════
::  CLEANUP LOOP
:: ═══════════════════════════════════════════════════════════

:loop
echo ==========================================
echo %date% %time%
echo Cleaning camera .ts files older than %KEEP_DAYS% days...
echo ==========================================

:: Check every camera folder and delete .ts files
:: older than the number of days specified in KEEP_DAYS.
for %%P in ("%CAM1%" "%CAM2%" "%CAM3%") do (
  if exist "%%~P" (
    forfiles /p "%%~P" /s /m *.ts /d -%KEEP_DAYS% /c "cmd /c del /q @path" 2>nul
  ) else (
    echo WARNING: Folder not found: %%~P
  )
)

echo ------------------------------------------
echo Deleting all .ts files from: %RECYCLE%
echo ------------------------------------------

if exist "%RECYCLE%" (
  :: Delete all .ts files from the recycle folder.
  forfiles /p "%RECYCLE%" /s /m *.ts /c "cmd /c del /q @path" 2>nul

  :: Delete empty folders remaining inside the recycle folder.
  :: Folders are processed from the deepest level first.
  for /f "delims=" %%D in ('dir /ad /b /s "%RECYCLE%" ^| sort /r') do rd "%%D" 2>nul
) else (
  echo WARNING: Recycle folder not found: %RECYCLE%
)

:: Wait before running the next cleanup check.
echo Done. Next check in %CHECK_INTERVAL% seconds...
timeout /t %CHECK_INTERVAL% /nobreak >nul
goto loop
```
