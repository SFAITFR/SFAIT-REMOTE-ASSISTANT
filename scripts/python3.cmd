@echo off
setlocal
"%LOCALAPPDATA%\Programs\Python\Python312\python.exe" %*
exit /b %ERRORLEVEL%
