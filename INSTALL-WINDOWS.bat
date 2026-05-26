@echo off
REM ==========================================================================
REM  INSTALL-WINDOWS.bat - Lancador a prova de politica de execucao restrita
REM  Use este arquivo se o Windows bloquear a execucao de scripts .ps1.
REM  Ele chama o INSTALL-WSL2.ps1 com -ExecutionPolicy Bypass e pede elevacao.
REM ==========================================================================
setlocal
set "AQUI=%~dp0"

echo Solicitando privilegios de administrador...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%AQUI%INSTALL-WSL2.ps1'"

echo.
echo Uma nova janela elevada foi aberta com o instalador.
echo Acompanhe a instalacao por la.
pause
endlocal
