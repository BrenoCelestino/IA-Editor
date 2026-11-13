#!/usr/bin/env bash
# Ativa o ambiente local isolado deste projeto no Linux/macOS

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$PROJECT_ROOT/.venv/bin/activate" ]; then
  # shellcheck disable=SC1091
  source "$PROJECT_ROOT/.venv/bin/activate"
else
  echo "[AVISO] Ambiente virtual .venv não encontrado. Execute ./setup.sh primeiro." >&2
fi

NODE_BIN="$PROJECT_ROOT/node_modules/.bin"
if [ -d "$NODE_BIN" ] && [[ ":$PATH:" != *":$NODE_BIN:"* ]]; then
  export PATH="$NODE_BIN:$PATH"
fi

CACHE_ROOT="$PROJECT_ROOT/.cache"
export XDG_CACHE_HOME="$CACHE_ROOT"
export TORCH_HOME="$CACHE_ROOT/torch"
export HYPERFRAMES_CACHE_DIR="$CACHE_ROOT/hyperframes"

if [ -f "$CACHE_ROOT/hardware.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$CACHE_ROOT/hardware.env"
  set +a
fi

echo "Ambiente isolado ativo em: $PROJECT_ROOT"
echo "  - .venv: $(command -v python || true)"
echo "  - hyperframes: $(command -v hyperframes || true)"
echo "  - ffmpeg (sistema): $(command -v ffmpeg || true)"
echo "  - gpu/whisper: ${TRESDEMENOS_GPU_VENDOR:-auto} (${TRESDEMENOS_WHISPER_DEVICE:-auto}) | encoder: ${TRESDEMENOS_FFMPEG_ENCODER:-libx264}"
