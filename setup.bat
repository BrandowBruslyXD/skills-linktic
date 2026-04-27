@echo off
setlocal enabledelayedexpansion

set ROOT=%~dp0
if "%ROOT:~-1%"=="\" set ROOT=%ROOT:~0,-1%
cd /d "%ROOT%"

set SKIP_LOGIN=0
:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="--skip-login" set SKIP_LOGIN=1
if /I "%~1"=="-h" goto show_help
if /I "%~1"=="--help" goto show_help
shift
goto parse_args
:show_help
echo Uso: setup.bat [--skip-login]
exit /b 0
:args_done

echo Verificando Python...
where python >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: No se encontro Python. Instala Python 3.10+ desde https://python.org
    pause
    exit /b 1
)

for /f "tokens=*" %%V in ('python -c "import sys; print(\"%%d.%%d\" %% sys.version_info[:2])"') do set PY_VER=%%V
python -c "import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)"
if %errorlevel% neq 0 (
    echo ERROR: Se requiere Python 3.10+. Encontrado: !PY_VER!
    pause
    exit /b 1
)

echo Creando entorno virtual...
if not exist ".venv" (
    python -m venv .venv
)

echo Activando entorno y actualizando pip...
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip setuptools wheel

echo Instalando dependencias...
if exist "skills\registro-horas\requirements.txt" (
    python -m pip install -r skills\registro-horas\requirements.txt
)
if exist "skills\ticket-infra\requirements.txt" (
    python -m pip install -r skills\ticket-infra\requirements.txt
)

echo Instalando Chromium para Playwright...
python -m playwright install chromium

echo Configurando credenciales de Confiani...
if exist ".env" (
    echo Usando credenciales existentes en .env
) else (
    set /p CONFIANI_USER=Correo de Confiani:
    set /p CONFIANI_PASSWORD=Password de Confiani:

    REM Escribimos el .env via Python para evitar interpolacion de cmd con caracteres especiales.
    python -c "import os; open(r'%ROOT%\.env','w',encoding='utf-8').write('CONFIANI_USER=' + os.environ['CONFIANI_USER'] + '\nCONFIANI_PASSWORD=' + os.environ['CONFIANI_PASSWORD'] + '\n')"
    set CONFIANI_USER=
    set CONFIANI_PASSWORD=

    attrib +h .env
    echo Credenciales guardadas en .env
)

if "%SKIP_LOGIN%"=="1" (
    echo Saltando login Ripor (--skip-login)
) else if exist "skills\registro-horas\state.json" (
    echo Sesion de Ripor ya existe. Si expiro: skills login
) else (
    echo Configurando sesion de Ripor (Google OAuth)...
    echo Se abrira Chrome para que hagas login con Google.
    pause
    python skills\registro-horas\registrar_horas.py --login-manual
)

echo.
echo Configurando comando 'skills' en PATH (User scope)...
REM Usamos PowerShell para evitar la truncacion de 1024 chars que tiene `setx`.
powershell -NoProfile -Command ^
  "$p=[Environment]::GetEnvironmentVariable('PATH','User'); ^
   if (-not $p) { $p='' }; ^
   if (($p -split ';') -notcontains '%ROOT%') { ^
     $new = if ($p) { \"$p;%ROOT%\" } else { '%ROOT%' }; ^
     [Environment]::SetEnvironmentVariable('PATH', $new, 'User'); ^
     Write-Host 'Agregado al PATH (User). Reinicia CMD/PowerShell.' ^
   } else { Write-Host 'PATH ya contiene %ROOT%' }"

echo.
echo Instalacion completa.
echo.
echo Comandos:
echo    skills ripor   --descripcion "..." --evidencia "..."
echo    skills ticket  --asunto "..." --descripcion "..."
echo    skills login
echo    skills help
echo.
pause
