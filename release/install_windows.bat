@echo off
rem One UI 9 for POCO X8 Pro (klee) - o9-65 TEST BUILD - clean install (WIPES DATA)
rem Writes to the CURRENT active slot only. Never runs set_active. Never touches
rem preloader, lk or IMEI partitions.
setlocal enabledelayedexpansion
cd /d "%~dp0"
where fastboot >nul 2>&1 || (echo fastboot not found. Install Android platform-tools and add it to PATH. & pause & exit /b 1)

echo Waiting for device in bootloader (fastboot) mode...
set PROD=
for /f "tokens=2" %%a in ('fastboot getvar product 2^>^&1 ^| findstr /b "product:"') do set PROD=%%a
if not "%PROD%"=="klee" (echo This is not a POCO X8 Pro / klee. Stopped. & pause & exit /b 1)
set US=
for /f "tokens=2" %%a in ('fastboot getvar is-userspace 2^>^&1 ^| findstr /b "is-userspace:"') do set US=%%a
if "%US%"=="yes" (echo You are in fastbootd. Run: fastboot reboot bootloader  and start again. & pause & exit /b 1)
set SLOT=
for /f "tokens=2" %%a in ('fastboot getvar current-slot 2^>^&1 ^| findstr /b "current-slot:"') do set SLOT=%%a
set SLOT=%SLOT:_=%
if not "%SLOT%"=="a" if not "%SLOT%"=="b" (echo Could not read the current slot. Stopped. & pause & exit /b 1)

echo.
echo Device: klee   Active slot: %SLOT%   (the slot will NOT be changed)
echo This TEST build will be flashed to slot %SLOT% and userdata + metadata will be ERASED.
echo Make sure you have a full backup of all partitions and Fenrir lk + preloader installed.
set /p OK=Type YES to continue:
if not "%OK%"=="YES" (echo Cancelled. & pause & exit /b 0)

set N=0
set TOTAL=29
if "%SLOT%"=="a" set TOTAL=30
for %%p in (apusys audio_dsp ccu connsys_bt connsys_gnss connsys_wifi dpm gpueb gz mcupm modem mvpu_algo pi_img scp spmfw sspm tee vcp boot init_boot vendor_boot dtbo vbmeta_system vbmeta_vendor) do (
  set /a N+=1
  echo. & echo ===== Step !N! / !TOTAL! : %%p_%SLOT% =====
  fastboot flash %%p_%SLOT% images\%%p.img || goto fail
)
set /a N+=1 & echo. & echo ===== Step !N! / !TOTAL! : vbmeta_%SLOT% =====
fastboot --disable-verity --disable-verification flash vbmeta_%SLOT% images\vbmeta.img || goto fail
set /a N+=1 & echo. & echo ===== Step !N! / !TOTAL! : super (big, takes a few minutes) =====
fastboot flash super images\super.img || goto fail
if "%SLOT%"=="a" (
  set /a N+=1
  echo. & echo ===== Step !N! / !TOTAL! : super slot A metadata =====
  fastboot flash super images\super_slot_a_meta.img || goto fail
)
set /a N+=1 & echo. & echo ===== Step !N! / !TOTAL! : erase metadata =====
fastboot erase metadata || goto fail
set /a N+=1 & echo. & echo ===== Step !N! / !TOTAL! : wipe userdata =====
fastboot -w || goto fail
echo. & echo ===== Step !TOTAL! / !TOTAL! : rebooting =====
fastboot reboot
echo.
echo Done. First boot takes a few minutes. Finish setup and wait 3+ minutes before the first reboot.
pause
exit /b 0

:fail
echo.
echo FLASHING FAILED. Do NOT reboot. Ask for help and include this window's output.
pause
exit /b 1
