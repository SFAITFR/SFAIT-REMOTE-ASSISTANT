@echo off
setlocal
"%LOCALAPPDATA%\Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe" --git-executable "C:\Program Files\Git\cmd\git.exe" -e sfait-3245 flutter %*
exit /b %ERRORLEVEL%
