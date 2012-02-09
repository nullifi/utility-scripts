@echo off
REM Launch powershell script as administrator
powershell Start-Process powershell {%TEMP%\trust-relationship-fixer.ps1 onboot} -Verb RunAs
