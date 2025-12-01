#!/usr/bin/env bash
set -euo pipefail

# Esempio: usare gyte-translate + gyte-ai-openai per tradurre un transcript
#
# Prerequisiti:
#   - variabile OPENAI_API_KEY impostata
#   - comando GYTE_AI_CMD impostato, es.:
#       export GYTE_AI_CMD='gyte-ai-openai --model gpt-4.1-mini'
#
# Uso:
#   ./ai-openai-translate.sh

usage() {
  cat >&2 << 'EOF'
Uso:
  ./ai-openai-translate.sh

Prerequisiti:
  export OPENAI_API_KEY='sk-...'
  export GYTE_AI_CMD='gyte-ai-openai --model gpt-4.1-mini'

Questo script traduce:
  sample-transcript.sentences.txt  ->  sample-transcript.sentences.en.txt
EOF
}

if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

INPUT_FILE="${SCRIPT_DIR}/sample-transcript.sentences.txt"

if [ ! -f "$INPUT_FILE" ]; then
  echo "Errore: file di input non trovato: $INPUT_FILE" >&2
  exit 1
fi

if [ -z "${GYTE_AI_CMD:-}" ]; then
  echo "Errore: GYTE_AI_CMD non impostata." >&2
  echo "Esempio:" >&2
  echo "  export GYTE_AI_CMD='gyte-ai-openai --model gpt-4.1-mini'" >&2
  exit 1
fi

if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "Errore: OPENAI_API_KEY non impostata (necessaria per gyte-ai-openai)." >&2
  exit 1
fi

echo ">> Dry-run di gyte-translate..."
gyte-translate \
  --from it \
  --to en \
  --out "${SCRIPT_DIR}/sample-transcript.sentences.en.txt" \
  --dry-run \
  "$INPUT_FILE"

echo
echo ">> Esecuzione reale..."
gyte-translate \
  --from it \
  --to en \
  --out "${SCRIPT_DIR}/sample-transcript.sentences.en.txt" \
  "$INPUT_FILE"

echo ">> Fatto: ${SCRIPT_DIR}/sample-transcript.sentences.en.txt"
