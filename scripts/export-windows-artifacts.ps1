param(
    [string]$SourcePortableExe = "target\release\rustdesk-portable-packer.exe",
    [string]$SourceSetupExe = "",
    [string]$SourceMsi = "",
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Resolve-DownloadsDirectory {
    $downloads = [Environment]::GetFolderPath("UserProfile")
    if (-not $downloads) {
        throw "Impossible de résoudre le dossier utilisateur."
    }
    return Join-Path $downloads "Downloads"
}

function Resolve-Version {
    param([string]$RequestedVersion)

    if ($RequestedVersion) {
        return $RequestedVersion
    }

    $cargoToml = Join-Path $repoRoot "Cargo.toml"
    if (-not (Test-Path $cargoToml)) {
        throw "Cargo.toml introuvable."
    }

    $versionLine = Select-String -Path $cargoToml -Pattern '^version = "(.*)"$' | Select-Object -First 1
    if (-not $versionLine) {
        throw "Version introuvable dans Cargo.toml."
    }

    return $versionLine.Matches[0].Groups[1].Value
}

function Copy-Artifact {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )

    $destinationDir = Split-Path -Parent $DestinationPath
    if (-not (Test-Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir | Out-Null
    }

    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
}

$resolvedPortableExe = ""
if ($SourcePortableExe) {
    $resolvedPortableExe = Join-Path $repoRoot $SourcePortableExe
    if (-not (Test-Path $resolvedPortableExe)) {
        throw "Binaire portable introuvable: $resolvedPortableExe"
    }
}

$resolvedSetupExe = ""
if ($SourceSetupExe) {
    $resolvedSetupExe = Join-Path $repoRoot $SourceSetupExe
    if (-not (Test-Path $resolvedSetupExe)) {
        throw "Binaire setup introuvable: $resolvedSetupExe"
    }
}

if (-not $resolvedPortableExe -and -not $resolvedSetupExe -and -not $SourceMsi) {
    throw "Aucun artefact a exporter n'a ete fourni."
}

$versionValue = Resolve-Version -RequestedVersion $Version
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$downloadsDir = Resolve-DownloadsDirectory
$exportDir = Join-Path $downloadsDir "SFAIT-Remote-Assistant\$timestamp"

if ($resolvedSetupExe) {
    $setupName = "SFAIT_Remote_Assistant_${versionValue}_windows_setup_${timestamp}.exe"
    $setupPath = Join-Path $exportDir $setupName
    Copy-Artifact -SourcePath $resolvedSetupExe -DestinationPath $setupPath
}

if ($resolvedPortableExe) {
    $portableName = "SFAIT_Remote_Assistant_${versionValue}_windows_portable_${timestamp}.exe"
    $portablePath = Join-Path $exportDir $portableName
    Copy-Artifact -SourcePath $resolvedPortableExe -DestinationPath $portablePath
}

if ($SourceMsi) {
    $resolvedSourceMsi = Join-Path $repoRoot $SourceMsi
    if (-not (Test-Path $resolvedSourceMsi)) {
        throw "MSI introuvable: $resolvedSourceMsi"
    }

    $msiName = "SFAIT_Remote_Assistant_${versionValue}_windows_installer_${timestamp}.msi"
    $msiPath = Join-Path $exportDir $msiName
    Copy-Artifact -SourcePath $resolvedSourceMsi -DestinationPath $msiPath
}

Write-Host "Exports Windows créés dans: $exportDir"
Get-ChildItem -LiteralPath $exportDir | Select-Object FullName, Length, LastWriteTime
