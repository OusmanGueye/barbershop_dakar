Param(
    [switch]$UseCanvasKit,
    [switch]$AutoInstallNetlify,
    [hashtable]$DartDefines
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK]   $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "[ERR]  $msg" -ForegroundColor Red }

# 0) Sanity checks
if (-not (Test-Path "./pubspec.yaml")) {
    Write-Err "Ce script doit être lancé depuis la RACINE du projet Flutter (pubspec.yaml introuvable)."
    exit 1
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Err "Flutter n'est pas installé ou non présent dans le PATH."
    exit 1
}

# 1) Build Flutter Web
Write-Info "Nettoyage & récupération des dépendances..."
flutter clean | Out-Null
flutter pub get | Out-Null

# Construit la liste des --dart-define
$dartDefineArgs = @()
if ($DartDefines) {
    foreach ($k in $DartDefines.Keys) {
        $v = $DartDefines[$k]
        $dartDefineArgs += "--dart-define=$k=$v"
    }
}
if ($UseCanvasKit) {
    # Compatible avec anciennes versions qui n'ont pas --web-renderer
    $dartDefineArgs += "--dart-define=FLUTTER_WEB_USE_SKIA=true"
}

Write-Info "Build Flutter Web (release)..."
$buildCmd = @("build","web","--release") + $dartDefineArgs
flutter @buildCmd

# 2) Fichier de redirection Netlify
$webDir = Join-Path -Path "build" -ChildPath "web"
if (-not (Test-Path $webDir)) {
    Write-Err "Le dossier $webDir n'existe pas. Le build a-t-il échoué ?"
    exit 1
}

$redirectsPath = Join-Path -Path $webDir -ChildPath "_redirects"
if (-not (Test-Path $webDir)) {
    New-Item -ItemType Directory -Force -Path $webDir | Out-Null
}
"/*    /index.html    200" | Out-File -Encoding ascii -FilePath $redirectsPath
Write-Ok "Créé: $redirectsPath"

# 3) Netlify CLI
$hasNetlify = $null -ne (Get-Command netlify -ErrorAction SilentlyContinue)
if (-not $hasNetlify) {
    if ($AutoInstallNetlify) {
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            Write-Info "Installation de Netlify CLI via npm -g..."
            npm i -g netlify-cli
        } else {
            Write-Err "npm introuvable. Installe Node.js/NPM ou lance sans -AutoInstallNetlify."
            exit 1
        }
    } else {
        Write-Err "Netlify CLI introuvable. Installe-le avec: npm i -g netlify-cli (ou relance avec -AutoInstallNetlify)"
        exit 1
    }
}

# 4) Déploiement Netlify
Write-Info "Déploiement Netlify en production..."
# La première fois, Netlify peut demander de lier un site (interactif).
# Le script relaie simplement les invites.
$ntlOutput = netlify deploy --prod --dir "$webDir" 2>&1

$ntlOutput | ForEach-Object { $_ }

# 5) Extraction de l'URL publique
$lien = $null

# Cherche "Website URL:"
$match1 = ($ntlOutput | Select-String -Pattern "Website URL:\s*(https?://\S+)").Matches
if ($match1.Count -gt 0) {
    $lien = $match1[0].Groups[1].Value
}

# Cherche "Live URL:"
if (-not $lien) {
    $match2 = ($ntlOutput | Select-String -Pattern "Live URL:\s*(https?://\S+)").Matches
    if ($match2.Count -gt 0) {
        $lien = $match2[0].Groups[1].Value
    }
}

# Cherche toute URL netlify.app
if (-not $lien) {
    $match3 = ($ntlOutput | Select-String -Pattern "(https?://[a-zA-Z0-9\-]+\.netlify\.app\S*)").Matches
    if ($match3.Count -gt 0) {
        $lien = $match3[$match3.Count-1].Value
    }
}

if ($lien) {
    Write-Ok "Déploiement terminé. URL: $lien"
} else {
    Write-Warn "Déployé. Impossible d'extraire l'URL automatiquement depuis la sortie."
    Write-Warn "Vérifie ci-dessus la sortie de 'netlify deploy' pour l'URL."
}

Write-Ok "Terminé."
