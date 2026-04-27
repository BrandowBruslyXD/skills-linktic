# skills-linktic — instalador one-liner para Windows (PowerShell).
#
# Uso (remoto, desde PowerShell normal — NO requiere admin):
#   irm https://raw.githubusercontent.com/BrandowBruslyXD/skills-linktic/main/install.ps1 | iex
#
# Uso (local, desde checkout):
#   powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

function Info($m) { Write-Host "ℹ  $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "✓  $m" -ForegroundColor Green }
function Warn($m) { Write-Host "⚠  $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "✗  $m" -ForegroundColor Red; exit 1 }

function Require-Cmd($name, $hint) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Warn "Falta '$name' en el sistema."
        Write-Host "   $hint"
        Die "Prerrequisito no satisfecho: $name"
    }
}

Write-Host ""
Write-Host "════ skills-linktic — instalador ════" -ForegroundColor Magenta
Write-Host ""

Require-Cmd "git"    "Instálalo con: winget install --id Git.Git -e   (o desde https://git-scm.com)"
Require-Cmd "python" "Instálalo con: winget install --id Python.Python.3.12 -e   (necesitas Python 3.10+)"

# Validar versión de Python
$pyOk = & python -c "import sys; print(int(sys.version_info >= (3,10)))"
$pyVer = & python -c "import sys; print('%d.%d' % sys.version_info[:2])"
if ($pyOk.Trim() -ne "1") {
    Die "Se requiere Python 3.10+; encontrado: $pyVer"
}
Ok "Python $pyVer detectado"

$RepoUrl    = if ($env:REPO_URL)    { $env:REPO_URL }    else { "https://github.com/BrandowBruslyXD/skills-linktic.git" }
$InstallDir = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { Join-Path $env:USERPROFILE "skills-linktic" }

# Modo checkout local
if ((Test-Path "./setup.bat") -and (Test-Path "./skills/_common.py")) {
    Info "Detectado checkout local en $((Get-Location).Path)"
    $Target = (Get-Location).Path
} else {
    if ((Test-Path $InstallDir) -and -not (Test-Path (Join-Path $InstallDir ".git"))) {
        Die "$InstallDir existe pero no es un repositorio git. Renómbralo o bórralo."
    }
    if (Test-Path $InstallDir) {
        Info "Actualizando repositorio existente en $InstallDir..."
        Push-Location $InstallDir
        try {
            git pull --ff-only
            if ($LASTEXITCODE -ne 0) {
                Die "git pull --ff-only falló. Revisa: cd $InstallDir; git status"
            }
        } finally { Pop-Location }
    } else {
        Info "Clonando $RepoUrl en $InstallDir..."
        git clone --depth=1 $RepoUrl $InstallDir
        if ($LASTEXITCODE -ne 0) { Die "Clonado falló." }
    }
    $Target = $InstallDir
}

Ok "Repositorio en: $Target"
Write-Host ""

Info "Ejecutando setup..."
# Pasamos args restantes (ej. --skip-login)
$setupArgs = if ($args) { $args -join ' ' } else { '' }
& cmd /c "`"$Target\setup.bat`" $setupArgs"
if ($LASTEXITCODE -ne 0) { Die "setup.bat falló (código $LASTEXITCODE)" }

# Configurar PATH a nivel USUARIO (NO usamos `setx` que trunca a 1024 chars).
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($null -eq $userPath) { $userPath = "" }
$paths = $userPath -split ";" | Where-Object { $_ -ne "" }
if ($paths -notcontains $Target) {
    $newPath = if ($userPath) { "$userPath;$Target" } else { "$Target" }
    [Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    Ok "Agregado al PATH (User scope): $Target"
} else {
    Ok "PATH ya contenía $Target"
}

Write-Host ""
Ok "Instalación finalizada."
Write-Host ""

@"
🚀 Para usar 'skills' AHORA en esta sesión de PowerShell:

   `$env:PATH += ";$Target"

   (o cierra y reabre la terminal)

📌 En terminales nuevas el comando 'skills' estará disponible automáticamente.

Comandos:
   skills ripor   --descripcion "..." --evidencia "..."
   skills ticket  --asunto "..." --descripcion "..."
   skills login
   skills help
"@ | Write-Host
