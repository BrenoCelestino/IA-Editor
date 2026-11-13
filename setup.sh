#!/usr/bin/env bash
set -euo pipefail

# Configuração automática e isolada do ambiente IA Editor (Linux)
# Detecta hardware (CPU/GPU NVIDIA, AMD ou Intel) e ferramentas já instaladas
# para evitar reinstalações desnecessárias, mantendo tudo isolado no projeto.

FORCE=0
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --force|-f) FORCE=1 ;;
    --dry-run|-n) DRY_RUN=1 ;;
    *) echo "Uso: ./setup.sh [--force] [--dry-run]"; exit 1 ;;
  esac
done

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

step() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }
ok()   { printf '  \033[32m[OK]\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m[AVISO]\033[0m %s\n' "$1"; }

run_pkg_install() {
  local pkgs=("$@")
  local sudo_cmd=""
  if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
    sudo_cmd="sudo"
  fi
  if command -v apt-get >/dev/null 2>&1; then
    $sudo_cmd apt-get update && $sudo_cmd apt-get install -y "${pkgs[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    $sudo_cmd dnf install -y "${pkgs[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    $sudo_cmd pacman -Sy --noconfirm "${pkgs[@]}"
  else
    warn "Gerenciador de pacotes não reconhecido. Instale manualmente: ${pkgs[*]}"
    return 1
  fi
}

# 1. Detectar Hardware (CPU e GPU)
step "Detectando hardware do sistema..."
CPU_NAME="$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | xargs || uname -m)"
CPU_VENDOR="other"
if echo "$CPU_NAME" | grep -qi "Intel"; then CPU_VENDOR="intel";
elif echo "$CPU_NAME" | grep -qi "AMD"; then CPU_VENDOR="amd"; fi

GPU_VENDOR="none"
GPU_NAME="CPU only"
TORCH_INDEX="https://download.pytorch.org/whl/cpu"
WHISPER_DEVICE="cpu"

LSPCI_GPU=""
if command -v lspci >/dev/null 2>&1; then
  LSPCI_GPU="$(lspci | grep -iE 'vga|3d|display' || true)"
fi

if command -v nvidia-smi >/dev/null 2>&1 || echo "$LSPCI_GPU" | grep -qi "NVIDIA"; then
  GPU_VENDOR="nvidia"
  GPU_NAME="$(echo "$LSPCI_GPU" | grep -i "NVIDIA" | head -n1 | cut -d: -f3- | xargs || echo "NVIDIA GPU")"
  CUDA_VER="$(nvidia-smi 2>/dev/null | sed -nE 's/.*CUDA( UMD)? Version: ([0-9]+\.[0-9]+).*/\2/p' | head -n1 || true)"
  if [ -n "$CUDA_VER" ]; then
    CUDA_MAJ="${CUDA_VER%%.*}"
    CUDA_MIN="${CUDA_VER#*.}"
    if [ "$CUDA_MAJ" -gt 13 ] || { [ "$CUDA_MAJ" -eq 13 ] && [ "$CUDA_MIN" -ge 0 ]; }; then
      TORCH_INDEX="https://download.pytorch.org/whl/cu130"
    elif [ "$CUDA_MAJ" -eq 12 ] && [ "$CUDA_MIN" -ge 8 ]; then
      TORCH_INDEX="https://download.pytorch.org/whl/cu128"
    elif [ "$CUDA_MAJ" -eq 12 ] && [ "$CUDA_MIN" -ge 6 ]; then
      TORCH_INDEX="https://download.pytorch.org/whl/cu126"
    else
      TORCH_INDEX="https://download.pytorch.org/whl/cu124"
    fi
    WHISPER_DEVICE="cuda"
  else
    TORCH_INDEX="https://download.pytorch.org/whl/cu128"
    WHISPER_DEVICE="cuda"
  fi
elif echo "$LSPCI_GPU" | grep -qiE "AMD|ATI|Radeon"; then
  GPU_VENDOR="amd"
  GPU_NAME="$(echo "$LSPCI_GPU" | grep -iE "AMD|ATI|Radeon" | head -n1 | cut -d: -f3- | xargs || echo "AMD GPU")"
  if [ -e /dev/kfd ] && { command -v rocminfo >/dev/null 2>&1 || [ -d /opt/rocm ]; }; then
    TORCH_INDEX="https://download.pytorch.org/whl/rocm6.2"
    WHISPER_DEVICE="cuda" # PyTorch ROCm expõe interface torch.cuda
  else
    warn "GPU AMD detectada sem driver ROCm (/dev/kfd). Usando PyTorch CPU para Whisper."
    TORCH_INDEX="https://download.pytorch.org/whl/cpu"
    WHISPER_DEVICE="cpu"
  fi
elif echo "$LSPCI_GPU" | grep -qi "Intel"; then
  GPU_VENDOR="intel"
  GPU_NAME="$(echo "$LSPCI_GPU" | grep -i "Intel" | head -n1 | cut -d: -f3- | xargs || echo "Intel GPU")"
  if echo "$GPU_NAME" | grep -qi "Arc"; then
    TORCH_INDEX="https://download.pytorch.org/whl/xpu"
    WHISPER_DEVICE="xpu"
  else
    TORCH_INDEX="https://download.pytorch.org/whl/cpu"
    WHISPER_DEVICE="cpu"
  fi
fi

ok "CPU: $CPU_NAME ($CPU_VENDOR)"
ok "GPU principal: $GPU_NAME (vendor=$GPU_VENDOR)"
ok "PyTorch index alvo: $TORCH_INDEX | Whisper device: $WHISPER_DEVICE"

# 2. Verificar ferramentas base do sistema (não reinstala o que já existe)
step "Verificando ferramentas do sistema (FFmpeg, Node.js, Python/uv)..."

if command -v ffmpeg >/dev/null 2>&1 && command -v ffprobe >/dev/null 2>&1; then
  ok "FFmpeg já instalado: $(command -v ffmpeg)"
else
  warn "FFmpeg/FFprobe não encontrado."
  if [ "$DRY_RUN" -eq 0 ]; then
    run_pkg_install ffmpeg
  fi
fi

FFMPEG_ENCODER="libx264"
if command -v ffmpeg >/dev/null 2>&1; then
  ENCODERS="$(ffmpeg -hide_banner -encoders 2>&1 || true)"
  if [ "$GPU_VENDOR" = "nvidia" ] && echo "$ENCODERS" | grep -q "h264_nvenc"; then FFMPEG_ENCODER="h264_nvenc";
  elif [ "$GPU_VENDOR" = "intel" ] && echo "$ENCODERS" | grep -q "h264_qsv"; then FFMPEG_ENCODER="h264_qsv";
  elif { [ "$GPU_VENDOR" = "amd" ] || [ "$GPU_VENDOR" = "intel" ]; } && echo "$ENCODERS" | grep -q "h264_vaapi"; then FFMPEG_ENCODER="h264_vaapi"; fi
fi
ok "Encoder FFmpeg selecionado: $FFMPEG_ENCODER"

NODE_OK=0
if command -v node >/dev/null 2>&1; then
  NODE_VER="$(node --version | sed 's/^v//')"
  NODE_MAJ="${NODE_VER%%.*}"
  if [ "$NODE_MAJ" -ge 22 ]; then
    NODE_OK=1
    ok "Node.js v$NODE_VER já instalado (>= 22): $(command -v node)"
  else
    warn "Node.js v$NODE_VER encontrado, mas hyperframes requer >= 22."
  fi
else
  warn "Node.js não encontrado."
fi
if [ "$NODE_OK" -eq 0 ] && [ "$DRY_RUN" -eq 0 ]; then
  echo "Instale Node.js >= 22 (ex.: via nvm ou NodeSource) e execute ./setup.sh novamente."
  exit 1
fi

HAS_UV=0
SYS_PY_COMPAT=0
SYS_PY_VER=""

if command -v python3 >/dev/null 2>&1; then
  SYS_PY_VER="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")' 2>/dev/null || true)"
  if [ -n "$SYS_PY_VER" ]; then
    PY_MAJ="${SYS_PY_VER%%.*}"
    PY_REST="${SYS_PY_VER#*.}"
    PY_MIN="${PY_REST%%.*}"
    if [ "$PY_MAJ" -eq 3 ] && [ "$PY_MIN" -ge 12 ] && [ "$PY_MIN" -le 14 ]; then
      SYS_PY_COMPAT=1
      ok "Python $SYS_PY_VER compatível (>=3.12,<3.15; ref. 3.14): $(command -v python3)"
    else
      warn "Python $SYS_PY_VER encontrado em $(command -v python3), mas está fora da faixa compatível (>=3.12,<3.15; ref. 3.14)."
    fi
  fi
fi

if command -v uv >/dev/null 2>&1; then
  HAS_UV=1
  ok "uv já instalado (usará Python 3.14 isolado se necessário): $(command -v uv)"
elif [ "$SYS_PY_COMPAT" -eq 1 ]; then
  ok "Usando Python compatível do sistema ($SYS_PY_VER)."
else
  warn "É necessário uv para provisionar Python 3.14 compatível de forma isolada (~/.local/bin)..."
  if [ "$DRY_RUN" -eq 0 ]; then
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    HAS_UV=1
  fi
fi

# Verificar modelo Whisper (global vs local)
WHISPER_MODEL="medium"
CACHE_ROOT="$PROJECT_ROOT/.cache"
LOCAL_WHISPER_DIR="$CACHE_ROOT/whisper"
LOCAL_MODEL_FILE="$LOCAL_WHISPER_DIR/$WHISPER_MODEL.pt"
GLOBAL_MODEL_FILE=""

if [ -n "${XDG_CACHE_HOME:-}" ] && [ "$XDG_CACHE_HOME" != "$CACHE_ROOT" ] && [ -s "$XDG_CACHE_HOME/whisper/$WHISPER_MODEL.pt" ]; then
  GLOBAL_MODEL_FILE="$XDG_CACHE_HOME/whisper/$WHISPER_MODEL.pt"
elif [ -s "$HOME/.cache/whisper/$WHISPER_MODEL.pt" ]; then
  GLOBAL_MODEL_FILE="$HOME/.cache/whisper/$WHISPER_MODEL.pt"
fi

if [ -s "$LOCAL_MODEL_FILE" ]; then
  ok "Modelo Whisper '$WHISPER_MODEL' já presente localmente: $LOCAL_MODEL_FILE"
elif [ -n "$GLOBAL_MODEL_FILE" ]; then
  ok "Modelo Whisper '$WHISPER_MODEL' encontrado no cache global: $GLOBAL_MODEL_FILE (será reutilizado sem novo download)"
else
  warn "Modelo Whisper '$WHISPER_MODEL' não encontrado globalmente nem localmente (será baixado em .cache/whisper/)."
fi

if [ "$DRY_RUN" -eq 1 ]; then
  step "Modo --dry-run concluído — nenhuma alteração foi gravada."
  exit 0
fi

# 3. Configurar ambiente Python isolado (.venv)
step "Configurando ambiente Python isolado (.venv)..."
VENV_PY="$PROJECT_ROOT/.venv/bin/python"
NEED_PY=0
RECREATE_VENV=0

if [ "$FORCE" -eq 1 ] || [ ! -x "$VENV_PY" ]; then
  NEED_PY=1
  RECREATE_VENV=1
else
  VENV_VER="$("$VENV_PY" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")' 2>/dev/null || true)"
  if [ -n "$VENV_VER" ]; then
    V_MAJ="${VENV_VER%%.*}"
    V_REST="${VENV_VER#*.}"
    V_MIN="${V_REST%%.*}"
    if [ "$V_MAJ" -ne 3 ] || [ "$V_MIN" -lt 12 ] || [ "$V_MIN" -gt 14 ]; then
      warn ".venv existente usa Python $VENV_VER, fora da faixa compatível (>=3.12,<3.15). Recriando..."
      NEED_PY=1
      RECREATE_VENV=1
    fi
  else
    NEED_PY=1
    RECREATE_VENV=1
  fi
fi

if [ "$NEED_PY" -eq 0 ]; then
  if ! "$VENV_PY" -c "import yt_dlp, whisper, torch, PIL, numpy" >/dev/null 2>&1; then
    NEED_PY=1
  else
    ok ".venv já configurado e funcional (Python $VENV_VER)."
  fi
fi

if [ "$NEED_PY" -eq 1 ]; then
  if [ "$HAS_UV" -eq 1 ]; then
    if [ "$RECREATE_VENV" -eq 1 ]; then
      uv venv .venv --python "3.14" --clear || uv venv .venv --python ">=3.12,<3.15" --clear
    fi
    uv pip install --python "$VENV_PY" --index-url "$TORCH_INDEX" "torch>=2.11.0"
    uv pip install --python "$VENV_PY" "yt-dlp[default]>=2026.10.26" "openai-whisper>=20250625" "pillow>=11.0.0" "numpy>=2.0.0"
  else
    if [ "$RECREATE_VENV" -eq 1 ]; then
      python3 -m venv .venv
    fi
    "$VENV_PY" -m pip install --upgrade pip
    "$VENV_PY" -m pip install --index-url "$TORCH_INDEX" "torch>=2.11.0"
    "$VENV_PY" -m pip install "yt-dlp[default]>=2026.10.26" "openai-whisper>=20250625" "pillow>=11.0.0" "numpy>=2.0.0"
  fi
  ok "Dependências Python instaladas em .venv."
fi

# 4. Configurar Node.js local (hyperframes) e Chrome Headless Shell isolado
step "Configurando HyperFrames local (node_modules) e cache isolado (.cache)..."
if [ "$FORCE" -eq 1 ] || [ ! -x "$PROJECT_ROOT/node_modules/.bin/hyperframes" ]; then
  if [ -f "$PROJECT_ROOT/package-lock.json" ]; then
    npm ci
  else
    npm install
  fi
  ok "Pacotes Node instalados localmente em node_modules/."
else
  ok "HyperFrames já instalado localmente."
fi

CACHE_ROOT="$PROJECT_ROOT/.cache"
HF_CACHE="$CACHE_ROOT/hyperframes"
mkdir -p "$CACHE_ROOT" "$HF_CACHE" "$LOCAL_WHISPER_DIR"
export HYPERFRAMES_CACHE_DIR="$HF_CACHE"
export XDG_CACHE_HOME="$CACHE_ROOT"

if [ "$FORCE" -eq 1 ] || [ ! -d "$HF_CACHE/chrome" ]; then
  npx hyperframes browser ensure
else
  ok "Chrome Headless Shell já em cache local."
fi

# 5. Modelo Whisper (reutilizar cache global do usuário se existir, senão baixar localmente)
if [ -s "$LOCAL_MODEL_FILE" ] && [ "$FORCE" -eq 0 ]; then
  ok "Modelo Whisper '$WHISPER_MODEL' já em cache local: $LOCAL_MODEL_FILE"
elif [ -n "$GLOBAL_MODEL_FILE" ]; then
  echo "  Reutilizando modelo Whisper global ($GLOBAL_MODEL_FILE) sem baixar novamente..."
  ln -sf "$GLOBAL_MODEL_FILE" "$LOCAL_MODEL_FILE"
  ok "Link simbólico criado para modelo global: $LOCAL_MODEL_FILE"
else
  echo "  Baixando modelo Whisper '$WHISPER_MODEL' para .cache/whisper/..."
  "$VENV_PY" -c "import whisper; whisper._download(whisper._MODELS['$WHISPER_MODEL'], '$LOCAL_WHISPER_DIR', False)"
  ok "Modelo Whisper '$WHISPER_MODEL' baixado em: $LOCAL_MODEL_FILE"
fi

# 6. Garantir fontes locais em assets/fonts/ (portável entre Windows e Linux)
FONTS_DIR="$PROJECT_ROOT/assets/fonts"
mkdir -p "$FONTS_DIR"
for FONT_NAME in "Rubik-Bold.ttf" "Rubik-BoldItalic.ttf"; do
  DEST_FONT="$FONTS_DIR/$FONT_NAME"
  if [ -s "$DEST_FONT" ]; then
    ok "Fonte local disponível: assets/fonts/$FONT_NAME"
  else
    echo "  Baixando fonte $FONT_NAME para assets/fonts/..."
    curl -fsSL "https://github.com/google/fonts/raw/main/ofl/rubik/static/$FONT_NAME" -o "$DEST_FONT"
    ok "Fonte baixada localmente: assets/fonts/$FONT_NAME"
  fi
done

# 7. Salvar perfil de hardware detectado em .cache/hardware.env
cat > "$CACHE_ROOT/hardware.env" <<EOF
TRESDEMENOS_OS=linux
TRESDEMENOS_CPU_VENDOR=$CPU_VENDOR
TRESDEMENOS_GPU_VENDOR=$GPU_VENDOR
TRESDEMENOS_GPU_NAME=$GPU_NAME
TRESDEMENOS_WHISPER_DEVICE=$WHISPER_DEVICE
TRESDEMENOS_FFMPEG_ENCODER=$FFMPEG_ENCODER
EOF
ok "Perfil de hardware salvo em .cache/hardware.env"

step "Setup concluído! Para ativar o ambiente no terminal execute:"
echo "  source ./activate-env.sh"
