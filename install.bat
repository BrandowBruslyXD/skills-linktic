@echo off
setlocal enabledelayedexpansion

echo Instalando skills-linktic en Windows...

if exist "setup.bat" (
    if exist "skills\_common.py" (
        echo Detectado checkout local en %cd%
        set "TARGET=%cd%"
        goto :setup
    )
)

set REPO_URL=https://github.com/BrandowBruslyXD/skills-linktic.git
set INSTALL_DIR=%USERPROFILE%\skills-linktic

if exist "%INSTALL_DIR%" (
    if not exist "%INSTALL_DIR%\.git" (
        echo ERROR: %INSTALL_DIR% existe pero no es un repositorio git.
        exit /b 1
    )
    echo Actualizando repositorio existente...
    cd /d "%INSTALL_DIR%"
    git pull --ff-only
    if %errorlevel% neq 0 (
        echo ERROR: git pull --ff-only fallo. Resuelve manualmente con: cd %INSTALL_DIR% ^&^& git status
        exit /b 1
    )
) else (
    echo Clonando repositorio...
    git clone "%REPO_URL%" "%INSTALL_DIR%"
    if %errorlevel% neq 0 exit /b 1
    cd /d "%INSTALL_DIR%"
)
set "TARGET=%INSTALL_DIR%"

:setup
echo Ejecutando setup...
call "%TARGET%\setup.bat" %*

echo.
echo Instalacion finalizada.
echo Comando 'skills' disponible al reiniciar CMD/PowerShell.
