#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=1 ;;
    *) echo "Uso: ./clean.sh [--dry-run]"; exit 1 ;;
  esac
done

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

WORK_DIR="$PROJECT_ROOT/.cache/trabalho"
REMOVED=0
FREED_KB=0

if [ -d "$WORK_DIR" ]; then
  SIZE_KB="$(du -sk "$WORK_DIR" 2>/dev/null | cut -f1 || echo 0)"
  FREED_KB=$((FREED_KB + SIZE_KB))
  REMOVED=$((REMOVED + 1))
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DryRun] Removeria pasta residual: $WORK_DIR (${SIZE_KB} KB)"
  else
    rm -rf "$WORK_DIR"
    echo "[OK] Pasta residual removida: $WORK_DIR (${SIZE_KB} KB)"
  fi
fi

while IFS= read -r -d '' f; do
  SIZE_KB="$(du -sk "$f" 2>/dev/null | cut -f1 || echo 0)"
  FREED_KB=$((FREED_KB + SIZE_KB))
  REMOVED=$((REMOVED + 1))
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DryRun] Removeria arquivo temporário: $f"
  else
    rm -f "$f"
    echo "[OK] Arquivo temporário removido: $f"
  fi
done < <(find "$PROJECT_ROOT" -maxdepth 1 -type f \( -name "*.tmp" -o -name "*.log" \) -print0)

if [ "$REMOVED" -eq 0 ]; then
  echo "Nenhum arquivo residual encontrado. O projeto já está limpo!"
else
  FREED_MB="$(awk "BEGIN {printf \"%.2f\", $FREED_KB / 1024}")"
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Total que seria liberado: ${FREED_MB} MB (preservando .venv, node_modules, modelos em .cache, Video Bruto e Video Pronto)."
  else
    echo "Limpeza concluída! Espaço liberado: ${FREED_MB} MB (preservados .venv, node_modules, modelos em .cache, Video Bruto e Video Pronto)."
  fi
fi
