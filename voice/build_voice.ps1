$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$voiceRoot = Join-Path $projectRoot "voice"
$venvRoot = Join-Path $projectRoot ".voice-venv"
$modelRoot = Join-Path $voiceRoot "model"
$modelMarker = Join-Path $modelRoot "final.mdl"
$downloadRoot = Join-Path $voiceRoot ".downloads"
$archivePath = Join-Path $downloadRoot "vosk-model-small-pt-0.3.zip"
$modelUrl = "https://alphacephei.com/vosk/models/vosk-model-small-pt-0.3.zip"
$workerOutput = Join-Path $voiceRoot "bin\voice-worker.exe"
$workerSource = Join-Path $voiceRoot "voice_worker.py"

if (-not (Test-Path $venvRoot)) {
    python -m venv $venvRoot
}

$python = Join-Path $venvRoot "Scripts\python.exe"
& $python -m pip install --disable-pip-version-check -r (Join-Path $voiceRoot "requirements.txt")

if (-not (Test-Path $modelMarker)) {
    New-Item -ItemType Directory -Force $downloadRoot | Out-Null
    if (-not (Test-Path $archivePath)) {
        Write-Host "Baixando modelo pequeno de português (31 MB)..."
        Invoke-WebRequest -Uri $modelUrl -OutFile $archivePath
    }

    $extractRoot = Join-Path $downloadRoot "extracted"
    if (Test-Path $extractRoot) {
        Remove-Item -LiteralPath $extractRoot -Recurse -Force
    }
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractRoot -Force
    $extractedModel = Join-Path $extractRoot "vosk-model-small-pt-0.3"
    if (-not (Test-Path (Join-Path $extractedModel "final.mdl"))) {
        throw "O arquivo baixado não contém um modelo Vosk válido."
    }
    New-Item -ItemType Directory -Force $modelRoot | Out-Null
    Copy-Item -Path (Join-Path $extractedModel "*") -Destination $modelRoot -Recurse -Force
}

$workerNeedsBuild = -not (Test-Path $workerOutput)
if (-not $workerNeedsBuild) {
    $workerNeedsBuild = (Get-Item $workerSource).LastWriteTimeUtc -gt (Get-Item $workerOutput).LastWriteTimeUtc
}

if ($workerNeedsBuild) {
    New-Item -ItemType Directory -Force (Split-Path $workerOutput) | Out-Null
    & $python -m PyInstaller `
        --noconfirm `
        --clean `
        --onefile `
        --console `
        --name voice-worker `
        --distpath (Split-Path $workerOutput) `
        --workpath (Join-Path $downloadRoot "pyinstaller-build") `
        --specpath $downloadRoot `
        --collect-binaries vosk `
        --hidden-import _cffi_backend `
        $workerSource
}

if (-not (Test-Path $workerOutput)) {
    throw "O executável de voz não foi gerado."
}

& $workerOutput --model $modelRoot --self-test
Write-Host "Núcleo de voz pronto: $workerOutput"
