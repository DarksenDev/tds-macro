@echo off
setlocal EnableDelayedExpansion
chcp 65001 > nul
cd %temp%

for /f "delims=#" %%E in ('"prompt #$E# & for %%E in (1) do rem"') do set "\e=%%E"
set cyan=%\e%[96m
set green=%\e%[92m
set purple=%\e%[95m
set blue=%\e%[94m
set red=%\e%[91m
set yellow=%\e%[93m
set reset=%\e%[0m

if [%1]==[] (
    echo %red%This script must be run from TDS Macro!%reset%
    <nul set /p "=%red%Press any key to exit . . . %reset%"
    pause >nul
    exit /b 1
)

echo %cyan%Downloading %~nx1...%reset%
powershell -Command ""(New-Object Net.WebClient).DownloadFile('%1', '%temp%\%~nx1')""
if %errorlevel% neq 0 (
    echo %red%Download failed! Check your internet connection.%reset%
    pause
    exit /b 1
)
echo %cyan%Download complete!%reset%
echo:

for %%a in ("%~2") do set "a2=%%~dpa"
echo %purple%Extracting %~nx1...%reset%
for /f delims^=^ EOL^= %%g in ('cscript //nologo "%~f0?.wsf" "%a2%" "%temp%\%~nx1"') do set "f=%%g"
call set folder=%%a2%%!f!
echo %purple%Extract complete!%reset%
echo:

echo %yellow%Deleting %~nx1...%reset%
del /f /q "%temp%\%~nx1" >nul
echo %yellow%Deleted successfully!%reset%
echo:

if exist "%~2\" (
    if %~3 == 1 (
        echo %blue%Deleting old version...%reset%
        rd /s /q "%~2" >nul
        echo %blue%Old version deleted successfully!%reset%
        echo:
    )
) else (
    echo %red%Error: Previous TDS Macro folder not found!%reset%
    echo %red%Updated version: !folder!%reset%
    <nul set /p "=%red%Press any key to exit . . . %reset%"
    pause >nul
    exit /b 1
)

echo %green%Update complete! Starting TDS Macro...%reset%
timeout /t 3 >nul

if exist "!folder!\AutoHotkey.exe" (
    start "" "!folder!\AutoHotkey.exe" "!folder!\Main.ahk"
) else if exist "!folder!\lib\AutoHotkey.exe" (
    start "" "!folder!\lib\AutoHotkey.exe" "!folder!\Main.ahk"
) else (
    echo %yellow%AutoHotkey.exe not found. Please start Main.ahk manually.%reset%
)

exit /b 0


<job><script language="VBScript">
set fso = CreateObject("Scripting.FileSystemObject")
set objShell = CreateObject("Shell.Application")
set FilesInZip = objShell.NameSpace(WScript.Arguments(1)).items
for each folder in FilesInZip
	WScript.Echo folder
next
objShell.NameSpace(WScript.Arguments(0)).CopyHere FilesInZip, 20
set fso = nothing
set objShell = nothing
</script></job>