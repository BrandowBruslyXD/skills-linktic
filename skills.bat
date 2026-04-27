@echo off
REM skills-linktic - Comandos globales para Windows

REM Función para encontrar el directorio de instalación
goto :find_skills_dir

:find_skills_dir
set "SKILLS_DIR="
if exist "%USERPROFILE%\skills-linktic" (
    if exist "%USERPROFILE%\skills-linktic\skills\_common.py" (
        set "SKILLS_DIR=%USERPROFILE%\skills-linktic"
        goto :main
    )
)
if exist "%USERPROFILE%\.skills-linktic" (
    if exist "%USERPROFILE%\.skills-linktic\skills\_common.py" (
        set "SKILLS_DIR=%USERPROFILE%\.skills-linktic"
        goto :main
    )
)
echo ❌ No se encontró skills-linktic instalado. Ejecuta la instalación primero.
exit /b 1

:main
if "%~1"=="" goto :help
if "%~1"=="help" goto :help
if "%~1"=="-h" goto :help
if "%~1"=="--help" goto :help

REM Activar entorno virtual
if not exist "%SKILLS_DIR%\.venv\Scripts\activate.bat" (
    echo ❌ Entorno virtual no encontrado en %SKILLS_DIR%\.venv
    exit /b 1
)
call "%SKILLS_DIR%\.venv\Scripts\activate.bat"

if "%~1"=="ripor" (
    shift
    python "%SKILLS_DIR%\skills\registro-horas\registrar_horas.py" %*
    goto :eof
)
if "%~1"=="ticket" (
    shift
    python "%SKILLS_DIR%\skills\ticket-infra\crear_ticket_confiani.py" %*
    goto :eof
)
if "%~1"=="login" (
    python "%SKILLS_DIR%\skills\registro-horas\registrar_horas.py" --login-manual
    goto :eof
)

echo ❌ Comando desconocido: %~1
echo Usa 'skills help' para ver comandos disponibles
exit /b 1

:help
echo skills-linktic - Comandos disponibles:
echo.
echo   skills ripor --descripcion "..." --evidencia "..."    Registrar horas
echo   skills ticket --asunto "..." --descripcion "..."     Crear ticket
echo   skills login                                         Login manual Ripor
echo   skills help                                          Esta ayuda
echo.
echo Ejemplos:
echo   skills ripor --descripcion "Trabajo realizado" --evidencia "https://link"
echo   skills ticket --asunto "Configurar servidor" --descripcion "Detalle completo"
goto :eof