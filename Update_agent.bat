@echo off
setlocal enabledelayedexpansion

REM ParamŠtres
set "API_URL=https://api.github.com/repos/SFAITFR/SFAIT-REMOTE-ASSISTANT/releases/latest"
set "SETUP_FILE=%TEMP%\SFAIT_Remote_Assistant_setup.exe"
set "APP_EXE=C:\Program Files\SFAIT Remote Assistant\SFAIT Remote Assistant.exe"
set "VERSION_DIR=%APPDATA%\SFAIT Remote Assistant"
set "VERSION_FILE=%VERSION_DIR%\version.txt"

REM Cr‚er dossier version s'il n'existe pas
if not exist "%VERSION_DIR%" (
    mkdir "%VERSION_DIR%"
)

REM R‚cup‚rer la version distante via GitHub
for /f "delims=" %%a in ('powershell -Command "(Invoke-RestMethod -Uri '%API_URL%').tag_name"') do set "REMOTE_VERSION=%%a"

REM Nettoyer pr‚fixe "v"
set "REMOTE_VERSION_CLEAN=%REMOTE_VERSION%"
if /i "%REMOTE_VERSION:~0,1%"=="v" set "REMOTE_VERSION_CLEAN=%REMOTE_VERSION:~1%"

REM Lire version locale
set "LOCAL_VERSION=Non install‚"
if exist "%APP_EXE%" (
    if exist "%VERSION_FILE%" (
        for /f "delims=" %%v in ('type "%VERSION_FILE%"') do (
            set "RAW_LOCAL_VERSION=%%v"
        )
        REM Nettoyer version locale
        for /f "delims=" %%v in ('powershell -Command "\"!RAW_LOCAL_VERSION!\".Trim()"') do set "LOCAL_VERSION=%%v"
    )
)

echo Version actuellement install‚e: [%LOCAL_VERSION%]
echo Version la plus r‚cente: [%REMOTE_VERSION_CLEAN%]

REM Si programme non install‚
if not exist "%APP_EXE%" (
    echo Application non trouv‚e. Installation initiale...
    goto :INSTALL
)

REM Comparer versions
if /i "%LOCAL_VERSION%"=="%REMOTE_VERSION_CLEAN%" (
    echo Pas de mise … jour n‚cessaire.
    goto :RUN
)

REM Sinon mise … jour
echo Nouvelle version d‚tect‚e. T‚l‚chargement de la nouvelle mise … jour...
:INSTALL

REM PowerShell avec barre de progression stable
powershell -NoLogo -NoProfile -Command ^
    "$release = Invoke-RestMethod -Uri '%API_URL%';" ^
    "$asset = $release.assets | Where-Object { $_.name -like '*setup.exe' };" ^
    "$url = $asset.browser_download_url;" ^
    "$dest = '%SETUP_FILE%';" ^
    "$wc = New-Object System.Net.WebClient;" ^
    "Register-ObjectEvent -InputObject $wc -EventName DownloadProgressChanged -Action { Write-Progress -Activity 'SFAIT Remote Assistant t‚l‚charge la derniŠre version disponible. Veuillez patienter...' -Status $EventArgs.ProgressPercentage -PercentComplete $EventArgs.ProgressPercentage } | Out-Null;" ^
    "$wc.DownloadFileAsync($url, $dest);" ^
    "while ($wc.IsBusy) { Start-Sleep -Milliseconds 200 }"

if exist "%SETUP_FILE%" (
    echo Installation silencieuse...
    start /wait "" "%SETUP_FILE%" /VERYSILENT
    echo Mise … jour de la version locale...
    echo %REMOTE_VERSION_CLEAN% > "%VERSION_FILE%"
) else (
    echo Erreur : setup.exe non t‚l‚charg‚.
    pause
    exit /b 1
)

:RUN
REM Lancer l'application
if exist "%APP_EXE%" (
    start "" "%APP_EXE%"
) else (
    echo Application non trouv‚e : %APP_EXE%
)

exit /b