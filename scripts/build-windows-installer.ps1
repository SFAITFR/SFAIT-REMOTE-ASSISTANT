param(
    [string]$AppName = "SFAIT Remote Assistant",
    [string]$Manufacturer = "EI THOB ALAN - SFAIT",
    [string]$DistDir = "flutter\build\windows\x64\runner\Release",
    [string]$PortableExe = "target\release\rustdesk-portable-packer.exe",
    [string]$NuGetExe = "target\tools\nuget.exe"
)

$ErrorActionPreference = "Stop"

function Assert-LastExitCode {
    param([string]$Message)

    if ($LASTEXITCODE -ne 0) {
        throw $Message
    }
}

function Normalize-PathEnvironment {
    $pathValue = $null

    if (Test-Path Env:Path) {
        $pathValue = (Get-Item Env:Path).Value
        Remove-Item Env:Path
    }
    if (Test-Path Env:PATH) {
        if (-not $pathValue) {
            $pathValue = (Get-Item Env:PATH).Value
        }
        Remove-Item Env:PATH
    }

    if ($pathValue) {
        [Environment]::SetEnvironmentVariable("Path", $pathValue, "Process")
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$distSourceDir = Join-Path $repoRoot $DistDir
if (-not (Test-Path $distSourceDir)) {
    throw "Dossier de build Windows introuvable: $distSourceDir"
}

$portableSourceExe = Join-Path $repoRoot $PortableExe
if (-not (Test-Path $portableSourceExe)) {
    throw "Binaire portable introuvable: $portableSourceExe"
}

$msbuild = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
if (-not (Test-Path $msbuild)) {
    throw "MSBuild introuvable: $msbuild"
}

$python = Join-Path $repoRoot "scripts\python3.cmd"
if (-not (Test-Path $python)) {
    throw "Wrapper Python introuvable: $python"
}

$stageRoot = Join-Path $repoRoot "target\windows-installer"
$distStageDir = Join-Path $stageRoot "dist"
$msiWorkDir = Join-Path $stageRoot "msi"
$iconStagePath = Join-Path $stageRoot "icon.ico"
$signOutputDir = Join-Path $repoRoot "SignOutput"

if (Test-Path $stageRoot) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $distStageDir | Out-Null
New-Item -ItemType Directory -Path $signOutputDir -Force | Out-Null

Copy-Item -LiteralPath (Join-Path $repoRoot "res\icon.ico") -Destination $iconStagePath -Force
Copy-Item -Path (Join-Path $distSourceDir "*") -Destination $distStageDir -Recurse -Force

$appExeName = "$AppName.exe"
Copy-Item -LiteralPath (Join-Path $distStageDir "rustdesk.exe") -Destination (Join-Path $distStageDir $appExeName) -Force

Copy-Item -LiteralPath (Join-Path $repoRoot "res\msi") -Destination $msiWorkDir -Recurse -Force

$preprocessFile = Join-Path $msiWorkDir "preprocess.py"
$preprocessContent = Get-Content -Raw $preprocessFile
$preprocessContent = $preprocessContent.Replace('f"{dist_app} {args}"', 'f''"{dist_app}" {args}''')
$preprocessContent = $preprocessContent.Replace("https://github.com/rustdesk/rustdesk/issues/", "https://github.com/SFAITFR/SFAIT-REMOTE-ASSISTANT/issues")
$preprocessContent = $preprocessContent.Replace("https://github.com/rustdesk/rustdesk", "https://github.com/SFAITFR/SFAIT-REMOTE-ASSISTANT")
Set-Content -Path $preprocessFile -Value $preprocessContent -Encoding UTF8

$nugetTarget = Join-Path $repoRoot $NuGetExe
if (-not (Test-Path $nugetTarget)) {
    $nugetDir = Split-Path -Parent $nugetTarget
    if (-not (Test-Path $nugetDir)) {
        New-Item -ItemType Directory -Path $nugetDir | Out-Null
    }
    Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile $nugetTarget
}

Push-Location $msiWorkDir
try {
    Normalize-PathEnvironment

    & $python ".\preprocess.py" `
        --dist-dir $distStageDir `
        --app-name $AppName `
        --manufacturer $Manufacturer
    Assert-LastExitCode "Le preprocess MSI a echoue."

    & $nugetTarget restore ".\msi.sln"
    Assert-LastExitCode "La restauration NuGet du projet MSI a echoue."

    & $msbuild ".\msi.sln" /restore /p:Configuration=Release /p:Platform=x64
    Assert-LastExitCode "La compilation du projet MSI a echoue."
}
finally {
    Pop-Location
}

$builtMsi = Get-ChildItem -Path $msiWorkDir -Recurse -Filter *.msi |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $builtMsi) {
    throw "Aucun fichier MSI n'a ete genere."
}

$portableOutput = Join-Path $signOutputDir "SFAIT_Remote_Assistant_portable.exe"
$msiOutput = Join-Path $signOutputDir "SFAIT_Remote_Assistant_installer.msi"

Copy-Item -LiteralPath $portableSourceExe -Destination $portableOutput -Force
Copy-Item -LiteralPath $builtMsi.FullName -Destination $msiOutput -Force

Write-Host "MSI genere: $($builtMsi.FullName)"
Get-Item $portableOutput, $msiOutput | Select-Object FullName, Length, LastWriteTime
