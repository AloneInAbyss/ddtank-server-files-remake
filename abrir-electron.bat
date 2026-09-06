@echo off
cd /d "%~dp0Launcher.Electron"
if not exist "node_modules\electron" (
  echo Instalando Electron 11. Isso e so a primeira vez.
  call npm install
  if errorlevel 1 exit /b 1
)
call npm start
