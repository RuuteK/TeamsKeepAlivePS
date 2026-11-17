@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -STA -File "%~dp0TeamsKeepAlive.ps1"
echo.
echo Jesli wystapil blad, skopiuj powyzszy komunikat.
pause
