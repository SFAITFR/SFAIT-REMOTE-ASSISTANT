@echo off
setlocal
"%LOCALAPPDATA%\Programs\Python\Python312\python.exe" -m pip %*
exit /b %ERRORLEVEL%
