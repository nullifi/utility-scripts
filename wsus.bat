@echo off
REM Change the following variable to your WSUS server hostname
set WSUSSERVER=wsus.contoso.com

REM Windows Version check. Will probably fail on Win8.
set VERSIONCHECK=0
VER | FIND "Version 6." > nul 2> nul
IF %ERRORLEVEL% == 0 ( set VERSIONCHECK=1 )
REM Windows Vista/7, check if running as administrator
IF %VERSIONCHECK% == 1 ( OPENFILES > nul 2> nul )
IF %ERRORLEVEL% == 1 ( set ADMINCHECK=0 )

REM We're on Windows 7, not running as administrator
IF %VERSIONCHECK% == 1 IF %ADMINCHECK% == 0 ( goto ERRORADMIN )

:START
cls
echo Temporary WSUS Script
echo ==============================
echo This script will flip between using the internal WSUS server and Microsoft's servers.
echo.
set /p WSUSSETTING=Type [W] to use WSUS or [C] to clear the setting and use MS servers:

IF /i (%WSUSSETTING%) == (W) goto CONTINUE
if /i (%WSUSSETTING%) == (C) goto CONTINUE

echo.
echo Error: Invalid selection
pause
goto START

:CONTINUE
echo Stopping Update Services...
net stop wuauserv
REM Delete timeout registry entries
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v LastWaitTimeout /f >nul 2> nul
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v DetectionStartTime /f >nul 2> nul
reg delete "HKLM\Software\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" /v NextDetectionTime /f >nul 2> nul

IF /i (%WSUSSETTING%) == (W) goto USEWSUS
IF /i (%WSUSSETTING%) == (C) goto USEMS

:USEWSUS
echo Changing update server to local WSUS server...
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate" /v WUServer /t REG_SZ /d "http://%WSUSSERVER%:8530" /f > nul 2> nul
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate" /v WUStatusServer /t REG_SZ /d "http://%WSUSSERVER%:8530" /f > nul 2> nul
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 0 /f > nul 2> nul
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 3 /f > nul 2> nul
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AutoInstallMinorUpdate /t REG_DWORD /d 1 /f > nul 2> nul
reg add "HKEY_LOCAL_MACHINE\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v UseWUServer /t REG_DWORD /d 1 /f > nul 2> nul
goto COMPLETE

:USEMS
echo Clearing WSUS update server...
reg delete "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v WUServer /f > nul 2> nul
reg delete "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate" /v WUStatusServer /f > nul 2> nul
reg delete "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU" /v UseWUServer /f > nul 2> nul
goto COMPLETE

:ERRORADMIN
REM Not running as administrator
echo ---
echo To prevent permissions issues, please run this script as an administrator. This script will now exit.
PAUSE
EXIT /B 1

:COMPLETE
echo Starting Update Services...
net start wuauserv

:END
echo ---
echo Complete.
pause