# Ativa o ambiente local isolado deste projeto (sem alterar configurações globais do Windows)
$ProjectRoot = $PSScriptRoot

$VenvActivate = Join-Path $ProjectRoot ".venv\Scripts\Activate.ps1"
if (Test-Path $VenvActivate) {
    . $VenvActivate
} else {
    Write-Warning "Ambiente virtual .venv não encontrado em $VenvActivate. Execute .\setup.ps1 primeiro."
}

$NodeBin = Join-Path $ProjectRoot "node_modules\.bin"
if ((Test-Path $NodeBin) -and ($env:PATH -notlike "*$NodeBin*")) {
    $env:PATH = "$NodeBin;$env:PATH"
}

$CacheRoot = Join-Path $ProjectRoot ".cache"
$env:XDG_CACHE_HOME = $CacheRoot
$env:TORCH_HOME = Join-Path $CacheRoot "torch"
$env:HYPERFRAMES_CACHE_DIR = Join-Path $CacheRoot "hyperframes"

$HwFile = Join-Path $CacheRoot "hardware.env"
if (Test-Path $HwFile) {
    Get-Content $HwFile | ForEach-Object {
        if ($_ -match "^([^#=]+)=(.*)$") {
            [Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), "Process")
        }
    }
}

Write-Host "Ambiente isolado ativo em: $ProjectRoot" -ForegroundColor Green
Write-Host "  - .venv: $((Get-Command python -ErrorAction SilentlyContinue).Source)"
Write-Host "  - hyperframes: $((Get-Command hyperframes -ErrorAction SilentlyContinue).Source)"
Write-Host "  - ffmpeg (sistema): $((Get-Command ffmpeg -ErrorAction SilentlyContinue).Source)"
Write-Host "  - cache local: $CacheRoot"
if ($env:TRESDEMENOS_WHISPER_DEVICE) {
    Write-Host "  - hardware: $($env:TRESDEMENOS_GPU_VENDOR) ($($env:TRESDEMENOS_WHISPER_DEVICE)) | encoder: $($env:TRESDEMENOS_FFMPEG_ENCODER)"
}
