<#
.SYNOPSIS
  Configuração automática e isolada do ambiente IA Editor (Windows).
.DESCRIPTION
  Detecta hardware (CPU/GPU NVIDIA, AMD ou Intel) e ferramentas já instaladas
  no sistema (ffmpeg, node, python, uv) para evitar reinstalações desnecessárias,
  mantendo dependências Python (.venv), Node (node_modules) e caches (.cache)
  totalmente isolados na pasta do projeto.
#>
param(
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
Set-Location $ProjectRoot

function Write-Step([string]$Msg) { Write-Host "`n==> $Msg" -ForegroundColor Cyan }
function Write-Ok([string]$Msg)   { Write-Host "  [OK] $Msg" -ForegroundColor Green }
function Write-Warn([string]$Msg) { Write-Host "  [AVISO] $Msg" -ForegroundColor Yellow }

function Refresh-SessionPath {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user    = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:PATH = "$machine;$user"
}

# 1. Detectar Hardware (CPU e GPU)
Write-Step "Detectando hardware do sistema..."
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$cpuName = ($cpu.Name).Trim()
$cpuVendor = if ($cpuName -match "Intel") { "intel" } elseif ($cpuName -match "AMD") { "amd" } else { "other" }

$gpus = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft Basic|Remote|Virtual" }
$gpuNames = @($gpus | ForEach-Object { $_.Name })

$gpuVendor = "none"
$gpuName   = "CPU only"
$cudaVer   = $null
$torchIndex = "https://download.pytorch.org/whl/cpu"
$whisperDevice = "cpu"

$nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if ($nvidiaSmi -or ($gpuNames -match "NVIDIA")) {
    $gpuVendor = "nvidia"
    $gpuName = ($gpuNames | Where-Object { $_ -match "NVIDIA" } | Select-Object -First 1)
    if (-not $gpuName) { $gpuName = "NVIDIA GPU" }
    if ($nvidiaSmi) {
        $smiOut = (& nvidia-smi 2>&1 | Out-String)
        if ($smiOut -match "CUDA(?:\s+UMD)?\s+Version:\s*(\d+)\.(\d+)") {
            $cudaMajor = [int]$Matches[1]
            $cudaMinor = [int]$Matches[2]
            $cudaVer = "$cudaMajor.$cudaMinor"
            if ($cudaMajor -gt 13 -or ($cudaMajor -eq 13 -and $cudaMinor -ge 0)) {
                $torchIndex = "https://download.pytorch.org/whl/cu130"
            } elseif ($cudaMajor -eq 12 -and $cudaMinor -ge 8) {
                $torchIndex = "https://download.pytorch.org/whl/cu128"
            } elseif ($cudaMajor -eq 12 -and $cudaMinor -ge 6) {
                $torchIndex = "https://download.pytorch.org/whl/cu126"
            } else {
                $torchIndex = "https://download.pytorch.org/whl/cu124"
            }
            $whisperDevice = "cuda"
        } else {
            $torchIndex = "https://download.pytorch.org/whl/cu128"
            $whisperDevice = "cuda"
        }
    }
} elseif ($gpuNames -match "AMD|Radeon") {
    $gpuVendor = "amd"
    $gpuName = ($gpuNames | Where-Object { $_ -match "AMD|Radeon" } | Select-Object -First 1)
    # No Windows, PyTorch oficial usa CPU para Whisper (ROCm nativo é Linux); FFmpeg usa AMF
    $torchIndex = "https://download.pytorch.org/whl/cpu"
    $whisperDevice = "cpu"
} elseif ($gpuNames -match "Intel") {
    $gpuVendor = "intel"
    $gpuName = ($gpuNames | Where-Object { $_ -match "Intel" } | Select-Object -First 1)
    if ($gpuName -match "Arc") {
        $torchIndex = "https://download.pytorch.org/whl/xpu"
        $whisperDevice = "xpu"
    } else {
        $torchIndex = "https://download.pytorch.org/whl/cpu"
        $whisperDevice = "cpu"
    }
}

Write-Ok "CPU: $cpuName ($cpuVendor)"
Write-Ok "GPU principal: $gpuName (vendor=$gpuVendor, cuda=$cudaVer)"
Write-Ok "PyTorch index alvo: $torchIndex | Whisper device: $whisperDevice"

# 2. Verificar ferramentas base do sistema (não reinstala o que já existe)
Write-Step "Verificando ferramentas do sistema (FFmpeg, Node.js, Python/uv)..."
$hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)

# FFmpeg / FFprobe
$ffmpegCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
$ffprobeCmd = Get-Command ffprobe -ErrorAction SilentlyContinue
if ($ffmpegCmd -and $ffprobeCmd) {
    Write-Ok "FFmpeg já instalado: $($ffmpegCmd.Source)"
} else {
    Write-Warn "FFmpeg/FFprobe não encontrado no PATH."
    if (-not $DryRun) {
        if ($hasWinget) {
            Write-Host "  Instalando FFmpeg via winget (Gyan.FFmpeg)..."
            winget install -e --id Gyan.FFmpeg --accept-package-agreements --accept-source-agreements
            Refresh-SessionPath
        } else {
            throw "Instale o FFmpeg manualmente (ex.: winget install Gyan.FFmpeg) e execute novamente."
        }
    }
}

# Detectar melhor encoder FFmpeg suportado
$ffmpegEncoder = "libx264"
$ffmpegCmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($ffmpegCmd) {
    $encoders = (& ffmpeg -hide_banner -encoders 2>&1 | Out-String)
    if ($gpuVendor -eq "nvidia" -and $encoders -match "h264_nvenc") { $ffmpegEncoder = "h264_nvenc" }
    elseif ($gpuVendor -eq "amd" -and $encoders -match "h264_amf")  { $ffmpegEncoder = "h264_amf" }
    elseif ($gpuVendor -eq "intel" -and $encoders -match "h264_qsv"){ $ffmpegEncoder = "h264_qsv" }
}
Write-Ok "Encoder FFmpeg selecionado: $ffmpegEncoder"

# Node.js >= 22
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
$nodeOk = $false
if ($nodeCmd) {
    $nodeVerRaw = (& node --version).Trim().TrimStart("v")
    $nodeMajor = [int]($nodeVerRaw.Split(".")[0])
    if ($nodeMajor -ge 22) {
        $nodeOk = $true
        Write-Ok "Node.js v$nodeVerRaw já instalado (>= 22): $($nodeCmd.Source)"
    } else {
        Write-Warn "Node.js v$nodeVerRaw encontrado, mas hyperframes requer >= 22."
    }
} else {
    Write-Warn "Node.js não encontrado."
}
if (-not $nodeOk -and -not $DryRun) {
    if ($hasWinget) {
        Write-Host "  Instalando Node.js LTS via winget..."
        winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
        Refresh-SessionPath
    } else {
        throw "Instale Node.js >= 22 (https://nodejs.org) e execute novamente."
    }
}

# Python / uv (referência: Python 3.14; compatível com >=3.12,<3.15)
$uvCmd = Get-Command uv -ErrorAction SilentlyContinue
$pyCmd = Get-Command python -ErrorAction SilentlyContinue
$sysPyCompatible = $false
$sysPyVer = ""

if ($pyCmd) {
    $pyCheck = (& $pyCmd.Source -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>$null)
    if ($LASTEXITCODE -eq 0 -and $pyCheck) {
        $sysPyVer = $pyCheck.Trim()
        $parts = $sysPyVer.Split(".")
        $pyMaj = [int]$parts[0]
        $pyMin = [int]$parts[1]
        if ($pyMaj -eq 3 -and $pyMin -ge 12 -and $pyMin -le 14) {
            $sysPyCompatible = $true
            Write-Ok "Python $sysPyVer compatível (>=3.12,<3.15; ref. 3.14): $($pyCmd.Source)"
        } else {
            Write-Warn "Python $sysPyVer encontrado em $($pyCmd.Source), mas está fora da faixa compatível (>=3.12,<3.15; ref. 3.14)."
        }
    }
}

if ($uvCmd) {
    Write-Ok "uv já instalado (usará Python 3.14 isolado se necessário): $($uvCmd.Source)"
} elseif ($sysPyCompatible) {
    Write-Ok "Usando Python compatível do sistema ($sysPyVer)."
} else {
    Write-Warn "É necessário uv para provisionar Python 3.14 compatível de forma isolada."
    if (-not $DryRun) {
        if ($hasWinget) {
            Write-Host "  Instalando uv via winget..."
            winget install -e --id astral-sh.uv --accept-package-agreements --accept-source-agreements
            Refresh-SessionPath
            $uvCmd = Get-Command uv -ErrorAction SilentlyContinue
        } else {
            throw "Instale uv (https://docs.astral.sh/uv/) ou Python 3.12-3.14 e execute novamente."
        }
    }
}

# Verificar modelo Whisper (global vs local)
$whisperModel = "medium"
$cacheRoot = Join-Path $ProjectRoot ".cache"
$localWhisperDir = Join-Path $cacheRoot "whisper"
$localModelFile = Join-Path $localWhisperDir "$whisperModel.pt"

$globalCandidates = @()
if ($env:XDG_CACHE_HOME -and ($env:XDG_CACHE_HOME -ne $cacheRoot)) {
    $globalCandidates += (Join-Path $env:XDG_CACHE_HOME "whisper\$whisperModel.pt")
}
if ($env:USERPROFILE) {
    $globalCandidates += (Join-Path $env:USERPROFILE ".cache\whisper\$whisperModel.pt")
}
$globalModelFile = $globalCandidates | Where-Object { (Test-Path $_) -and ((Get-Item $_).Length -gt 0) } | Select-Object -First 1

if ((Test-Path $localModelFile) -and ((Get-Item $localModelFile).Length -gt 0)) {
    Write-Ok "Modelo Whisper '$whisperModel' já presente localmente: $localModelFile"
} elseif ($globalModelFile) {
    Write-Ok "Modelo Whisper '$whisperModel' encontrado no cache global: $globalModelFile (será reutilizado sem novo download)"
} else {
    Write-Warn "Modelo Whisper '$whisperModel' não encontrado globalmente nem localmente (será baixado em .cache\whisper\)."
}

if ($DryRun) {
    Write-Step "Modo DryRun concluído — nenhuma alteração foi gravada."
    exit 0
}

# 3. Configurar ambiente Python isolado (.venv)
Write-Step "Configurando ambiente Python isolado (.venv)..."
$venvPython = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
$needPythonInstall = $Force -or -not (Test-Path $venvPython)
$recreateVenv = $Force -or -not (Test-Path $venvPython)

if (-not $recreateVenv) {
    $venvVer = (& $venvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>$null)
    if ($LASTEXITCODE -eq 0 -and $venvVer) {
        $vParts = $venvVer.Trim().Split(".")
        $vMaj = [int]$vParts[0]
        $vMin = [int]$vParts[1]
        if (-not ($vMaj -eq 3 -and $vMin -ge 12 -and $vMin -le 14)) {
            Write-Warn ".venv existente usa Python $($venvVer.Trim()), fora da faixa compatível (>=3.12,<3.15). Recriando..."
            $recreateVenv = $true
            $needPythonInstall = $true
        }
    } else {
        $recreateVenv = $true
        $needPythonInstall = $true
    }
}

if (-not $needPythonInstall) {
    $checkPy = & $venvPython -c "import yt_dlp, whisper, torch, PIL, numpy; dev='cuda' if torch.cuda.is_available() else ('xpu' if hasattr(torch,'xpu') and torch.xpu.is_available() else 'cpu'); print(dev)" 2>$null
    if ($LASTEXITCODE -eq 0 -and $checkPy) {
        $detectedPyDev = $checkPy.Trim()
        if ($detectedPyDev -eq $whisperDevice -or ($whisperDevice -eq "cpu")) {
            Write-Ok ".venv já configurado e funcional (Python $($venvVer.Trim()), torch device: $detectedPyDev)."
        } else {
            Write-Warn ".venv existente está em '$detectedPyDev', mas hardware suporta '$whisperDevice'. Atualizando..."
            $needPythonInstall = $true
        }
    } else {
        $needPythonInstall = $true
    }
}

if ($needPythonInstall) {
    if ($uvCmd) {
        if ($recreateVenv) {
            uv venv .venv --python "3.14" --clear
            if ($LASTEXITCODE -ne 0) {
                uv venv .venv --python ">=3.12,<3.15" --clear
            }
        }
        uv pip install --python $venvPython --index-url $torchIndex "torch>=2.11.0"
        uv pip install --python $venvPython "yt-dlp[default]>=2026.10.26" "openai-whisper>=20250625" "pillow>=11.0.0" "numpy>=2.0.0"
    } else {
        if ($recreateVenv) {
            python -m venv .venv
        }
        & $venvPython -m pip install --upgrade pip
        & $venvPython -m pip install --index-url $torchIndex "torch>=2.11.0"
        & $venvPython -m pip install "yt-dlp[default]>=2026.10.26" "openai-whisper>=20250625" "pillow>=11.0.0" "numpy>=2.0.0"
    }
    Write-Ok "Dependências Python instaladas em .venv."
}

# 4. Configurar Node.js local (hyperframes) e Chrome Headless Shell isolado
Write-Step "Configurando HyperFrames local (node_modules) e cache isolado (.cache)..."
$hfBin = Join-Path $ProjectRoot "node_modules\.bin\hyperframes.ps1"
if ($Force -or -not (Test-Path $hfBin)) {
    if (Test-Path (Join-Path $ProjectRoot "package-lock.json")) {
        npm ci
    } else {
        npm install
    }
    Write-Ok "Pacotes Node instalados localmente em node_modules\."
} else {
    Write-Ok "HyperFrames já instalado localmente."
}

$cacheRoot = Join-Path $ProjectRoot ".cache"
$hfCache = Join-Path $cacheRoot "hyperframes"
New-Item -ItemType Directory -Force -Path $cacheRoot, $hfCache, $localWhisperDir | Out-Null
$env:HYPERFRAMES_CACHE_DIR = $hfCache
$env:XDG_CACHE_HOME = $cacheRoot

$chromeExists = Get-ChildItem -Path (Join-Path $hfCache "chrome") -Filter "chrome-headless-shell.exe" -Recurse -ErrorAction SilentlyContinue
if ($Force -or -not $chromeExists) {
    npx hyperframes browser ensure
} else {
    Write-Ok "Chrome Headless Shell já em cache local: $($chromeExists[0].FullName)"
}

# 5. Modelo Whisper (reutilizar cache global do usuário se existir, senão baixar localmente)
if ((Test-Path $localModelFile) -and ((Get-Item $localModelFile).Length -gt 0) -and -not $Force) {
    Write-Ok "Modelo Whisper '$whisperModel' já em cache local: $localModelFile"
} elseif ($globalModelFile) {
    Write-Host "  Reutilizando modelo Whisper global ($globalModelFile) sem baixar novamente..."
    try {
        if (Test-Path $localModelFile) { Remove-Item $localModelFile -Force }
        New-Item -ItemType HardLink -Path $localModelFile -Target $globalModelFile | Out-Null
        Write-Ok "Hardlink criado para modelo global: $localModelFile"
    } catch {
        Copy-Item -Path $globalModelFile -Destination $localModelFile -Force
        Write-Ok "Modelo global copiado para cache local: $localModelFile"
    }
} else {
    Write-Host "  Baixando modelo Whisper '$whisperModel' para .cache\whisper\..."
    & $venvPython -c "import whisper; whisper._download(whisper._MODELS['$whisperModel'], r'$localWhisperDir', False)"
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao baixar o modelo Whisper '$whisperModel'."
    }
    Write-Ok "Modelo Whisper '$whisperModel' baixado em: $localModelFile"
}

# 6. Garantir fontes locais em assets\fonts\ (portável entre Windows e Linux)
$fontsDir = Join-Path $ProjectRoot "assets\fonts"
New-Item -ItemType Directory -Force -Path $fontsDir | Out-Null
$fontMap = @{
    "Rubik-Bold.ttf"       = "https://github.com/google/fonts/raw/main/ofl/rubik/static/Rubik-Bold.ttf"
    "Rubik-BoldItalic.ttf" = "https://github.com/google/fonts/raw/main/ofl/rubik/static/Rubik-BoldItalic.ttf"
}
foreach ($fontName in $fontMap.Keys) {
    $destFont = Join-Path $fontsDir $fontName
    if ((Test-Path $destFont) -and ((Get-Item $destFont).Length -gt 0)) {
        Write-Ok "Fonte local disponível: assets\fonts\$fontName"
    } else {
        $winFont = Join-Path $env:WINDIR "Fonts\$fontName"
        if (Test-Path $winFont) {
            Copy-Item $winFont $destFont -Force
            Write-Ok "Fonte copiada para uso local: assets\fonts\$fontName"
        } else {
            Write-Host "  Baixando fonte $fontName para assets\fonts\..."
            Invoke-WebRequest -Uri $fontMap[$fontName] -OutFile $destFont -UseBasicParsing
            Write-Ok "Fonte baixada localmente: assets\fonts\$fontName"
        }
    }
}

# 7. Salvar perfil de hardware detectado em .cache\hardware.env
$hwFile = Join-Path $cacheRoot "hardware.env"
@(
    "TRESDEMENOS_OS=windows"
    "TRESDEMENOS_CPU_VENDOR=$cpuVendor"
    "TRESDEMENOS_GPU_VENDOR=$gpuVendor"
    "TRESDEMENOS_GPU_NAME=$gpuName"
    "TRESDEMENOS_WHISPER_DEVICE=$whisperDevice"
    "TRESDEMENOS_FFMPEG_ENCODER=$ffmpegEncoder"
) | Set-Content -Path $hwFile -Encoding UTF8
Write-Ok "Perfil de hardware salvo em .cache\hardware.env"

Write-Step "Setup concluído! Para ativar o ambiente no terminal execute:"
Write-Host "  . .\activate-env.ps1" -ForegroundColor Yellow
