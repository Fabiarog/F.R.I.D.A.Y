@echo off
chcp 65001 >nul
title F.R.I.D.A.Y. Hub Central - Iniciando...
color 0B

echo.
echo  ================================================
echo   F.R.I.D.A.Y. Hub Central v4.2
echo   Female Replacement Intelligent Digital Assistant
echo  ================================================
echo.

:: Verifica se Python esta disponivel
python --version >nul 2>&1
if errorlevel 1 (
    echo  [ERRO] Python nao encontrado no PATH.
    echo  Instale Python 3.11+ em https://python.org
    pause
    exit /b 1
)

for /f "tokens=*" %%v in ('python --version 2^>^&1') do echo  [OK] %%v encontrado.

:: Vai para o diretorio server
cd /d "%~dp0server"

:: Instala dependencias se necessario
echo  [..] Verificando dependencias Python (aguarde)...
pip install -r requirements.txt -q
if errorlevel 1 (
    echo  [AVISO] Algumas dependencias podem nao ter instalado corretamente.
    echo  Tente: pip install fastapi uvicorn psutil
)
echo  [OK] Dependencias prontas.

echo.
echo  ================================================
echo   Hub ativo em:
echo   WebSocket : ws://0.0.0.0:8000/ws
echo   HUD Web   : http://localhost:8000
echo   Swagger   : http://localhost:8000/docs
echo  ================================================
echo   Celular: abra http://[SEU_IP]:8000 no browser
echo   (descubra seu IP com: ipconfig)
echo  ================================================
echo.
echo  Pressione CTRL+C para encerrar o Hub.
echo.

:: Inicia o servidor
python server.py

pause
