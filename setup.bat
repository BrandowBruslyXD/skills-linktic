@echo off
setlocal enabledelayedexpansion

set ROOT=%~dp0
if "%ROOT:~-1%"=="\" set ROOT=%ROOT:~0,-1%
cd /d "%ROOT%"

set SKIP_LOGIN=0
set SKIP_CONFIG=0
:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--skip-login"  set SKIP_LOGIN=1
if /I "%~1"=="--skip-config" set SKIP_CONFIG=1
if /I "%~1"=="-h"     goto show_help
if /I "%~1"=="--help" goto show_help
shift
goto parse_args
:show_help
echo Uso: setup.bat [--skip-login] [--skip-config]
exit /b 0
:args_done

echo Verificando Python...
where python >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: No se encontro Python. Instala Python 3.10+ desde https://python.org
    pause
    exit /b 1
)

python -c "import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)"
if %errorlevel% neq 0 (
    echo ERROR: Se requiere Python 3.10+
    pause
    exit /b 1
)

python -c "import venv" 2>nul
if %errorlevel% neq 0 (
    echo ERROR: El modulo 'venv' no esta disponible. Reinstala Python desde python.org
    pause
    exit /b 1
)

REM Detectar venv corrupto
if exist ".venv" (
    if not exist ".venv\Scripts\python.exe" (
        echo .venv parece corrupto, recreando...
        rmdir /s /q .venv
    )
)
if not exist ".venv" (
    echo Creando entorno virtual...
    python -m venv .venv
)

call .venv\Scripts\activate.bat
echo Actualizando pip...
python -m pip install --upgrade --quiet pip setuptools wheel

echo Instalando dependencias...
if exist "skills\registro-horas\requirements.txt" python -m pip install --quiet -r skills\registro-horas\requirements.txt
if exist "skills\ticket-infra\requirements.txt"  python -m pip install --quiet -r skills\ticket-infra\requirements.txt

echo Instalando Chromium para Playwright...
python -m playwright install chromium

echo Configurando credenciales de Confiani...
if exist ".env" (
    echo Usando credenciales existentes en .env
) else (
    set /p CONFIANI_USER=Correo de Confiani:
    set /p CONFIANI_PASSWORD=Password de Confiani:
    python -c "import os; open(r'%ROOT%\.env','w',encoding='utf-8').write('CONFIANI_USER=' + os.environ['CONFIANI_USER'] + '\nCONFIANI_PASSWORD=' + os.environ['CONFIANI_PASSWORD'] + '\n')"
    set CONFIANI_USER=
    set CONFIANI_PASSWORD=
    attrib +h .env
    echo Credenciales guardadas en .env
)

if "%SKIP_CONFIG%"=="1" (
    echo Saltando config.local.toml --skip-config
) else if exist "config.local.toml" (
    echo config.local.toml ya existe
) else (
    echo.
    echo Configuracion personal proyecto / centro de costo:
    set /p RIPOR_PROYECTO=Proyecto en Ripor (texto exacto):
    set /p CONFIANI_PROCESO=Proceso Confiani:
    set /p CONFIANI_SERVICIO=Servicio Confiani:
    set /p CONFIANI_CC=Centro de costo prefijo:
    python -c "import os; open(r'%ROOT%\config.local.toml','w',encoding='utf-8').write('# Generado por setup.bat\n\n[ripor]\n' + ('proyecto = \"' + os.environ.get('RIPOR_PROYECTO','') + '\"\n' if os.environ.get('RIPOR_PROYECTO') else '') + '\n[confiani]\n' + ''.join([f'{k} = \"{os.environ[v]}\"\n' for k,v in [('proceso','CONFIANI_PROCESO'),('servicio','CONFIANI_SERVICIO'),('centro_costo_prefijo','CONFIANI_CC')] if os.environ.get(v)]))"
    set RIPOR_PROYECTO=
    set CONFIANI_PROCESO=
    set CONFIANI_SERVICIO=
    set CONFIANI_CC=
    echo config.local.toml creado.
)

if "%SKIP_LOGIN%"=="1" (
    echo Saltando login Ripor --skip-login
) else if exist "skills\registro-horas\state.json" (
    echo Sesion de Ripor ya existe
) else (
    echo Configurando sesion de Ripor Google OAuth...
    pause
    python skills\registro-horas\registrar_horas.py --login-manual
)

echo.
echo Instalacion completa.
echo Comando 'skills' disponible tras agregar %ROOT% al PATH (lo hace install.ps1).
echo.
echo Comandos:
echo    skills ripor   --descripcion "..." --evidencia "..."
echo    skills ticket  --asunto "..." --descripcion "..."
echo    skills login
echo    skills help
echo.
pause
