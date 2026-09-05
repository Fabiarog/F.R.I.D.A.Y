@echo off
setlocal
chcp 65001 >nul
title F.R.I.D.A.Y. Local
cd /d "%~dp0"

if "%1"=="dev" goto :run_dev
if "%1"=="build" goto :run_build

if exist "src-tauri\target\release\friday-core.exe" (
  echo [INFO] Iniciando executavel de producao...
  start "" "src-tauri\target\release\friday-core.exe"
  exit /b 0
)

:run_dev
where npm >nul 2>&1
if errorlevel 1 (
  echo [ERRO] Node.js nao foi encontrado.
  echo Instale Node.js 20 ou superior e tente novamente.
  pause
  exit /b 1
)

if not exist "%USERPROFILE%\.cargo\bin\cargo.exe" (
  echo [ERRO] Rust nao foi encontrado.
  echo Instale Rust pelo rustup antes de iniciar o modo de desenvolvimento.
  pause
  exit /b 1
)

set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"
echo Iniciando F.R.I.D.A.Y. Local em modo de desenvolvimento (atualizado)...
call npm run dev

if errorlevel 1 pause
exit /b 0

:run_build
set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"
echo Compilando versao final de producao...
call npm run build

if errorlevel 1 pause
endlocal

