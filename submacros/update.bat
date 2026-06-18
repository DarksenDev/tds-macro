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
    echo %red%Error: No download URL provided.%reset%
    pause >nul
    exit /b 1
)

set "DOWNLOAD_URL=%~1"
set "MACRO_DIR=%~2"

if not exist "%MACRO_DIR%" (
    echo %red%Macro folder not found: %MACRO_DIR%%reset%
    pause
    exit /b 1
)

echo %cyan%Downloading update...%reset%
powershell -Command "(New-Object Net.WebClient).DownloadFile('%DOWNLOAD_URL%', '%temp%\tds_update.zip')"
if not exist "%temp%\tds_update.zip" (
    echo %red%Download failed!%reset%
    pause
    exit /b 1
)
echo %cyan%Download complete!%reset%
echo:

echo %yellow%Cleaning old macro files...%reset%
set RETRIES=0
:clean_retry
del /f /s /q "%MACRO_DIR%\*" >nul 2>&1
for /d %%p in ("%MACRO_DIR%\*") do rd /s /q "%%p" >nul 2>&1

dir /b "%MACRO_DIR%" 2>nul | findstr . >nul && (
    set /a RETRIES+=1
    if !RETRIES! lss 10 (
        timeout /t 2 >nul
        goto clean_retry
    ) else (
        echo %red%Failed to clean folder after 10 attempts. Aborting.%reset%
        pause
        exit /b 1
    )
)
echo %green%Folder cleaned.%reset%
echo:

echo %purple%Extracting new version directly to %MACRO_DIR%...%reset%
set "vbs_file=%temp%\unzip.vbs"
(
echo Set objShell = CreateObject("Shell.Application"^)
echo Set zip = objShell.NameSpace("%temp%\tds_update.zip"^)
echo Set dest = objShell.NameSpace("%MACRO_DIR%"^)
echo dest.CopyHere zip.Items, 20
echo WScript.Sleep 3000
) > "%vbs_file%"

cscript //nologo "%vbs_file%"
del /f /q "%vbs_file%"
echo %purple%Extract complete!%reset%
echo:

del /f /q "%temp%\tds_update.zip" 2>nul

echo %green%Update completed! Starting TDS Macro...%reset%
timeout /t 2 >nul

if exist "%MACRO_DIR%\Main.ahk" (
    start "" "%MACRO_DIR%\Main.ahk"
) else (
    echo %yellow%Could not find Main.ahk.%reset%
)


(goto) 2>nul & start "" /b cmd /c timeout /t 2 >nul & del "%~f0" & exit

exit /b 0