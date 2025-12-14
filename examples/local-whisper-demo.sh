#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

WHISPER="$REPO_ROOT/scripts/gyte-whisper-local"
REFLOW="$REPO_ROOT/scripts/gyte-reflow-text"
TRANSLATE="$REPO_ROOT/scripts/gyte-translate"

if [ $# -lt 1 ]; then
  echo "Uso: $0 INPUT.(mp4|mp3|wav|...)" >&2
  echo "Opzionale: export GYTE_WHISPER_MODEL=small; export GYTE_WHISPER_LANG=it" >&2
  echo "Opzionale traduzione: export GYTE_AI_CMD='gyte-openai --model gpt-4.1-mini'  (e OPENAI_API_KEY nel tuo env)" >&2
  exit 2
fi

INPUT="$1"
if [ ! -f "$INPUT" ]; then
  echo "Errore: file non trovato: $INPUT" >&2
  exit 1
fi

BASENAME="$(basename -- "$INPUT")"
BASE="${BASENAME%.*}"
OUTDIR="$REPO_ROOT/out/local-$BASE"

mkdir -p -- "$OUTDIR"

echo "== Step 1: Whisper local -> .txt + .srt ==" >&2
"$WHISPER" --outdir "$OUTDIR" "$INPUT"

TXT="$OUTDIR/$BASE.txt"
SRT="$OUTDIR/$BASE.srt"

echo "" >&2
echo "Output atteso:" >&2
echo "  TXT: $TXT" >&2
echo "  SRT: $SRT" >&2

if [ ! -f "$TXT" ]; then
  echo "Errore: non trovo il TXT generato: $TXT" >&2
  exit 1
fi

if [ -x "$REFLOW" ]; then
  echo "" >&2
  echo "== Step 2 (opzionale): Reflow AI-friendly (una frase per riga) ==" >&2
  AI_TXT="$OUTDIR/$BASE.ai.txt"
  "$REFLOW" --ai-friendly "$TXT" > "$AI_TXT"
  echo "  AI_TXT: $AI_TXT" >&2
else
  echo "" >&2
  echo "Skip reflow: non trovo eseguibile $REFLOW" >&2
  AI_TXT="$TXT"
fi

# Traduzione: solo se hai gyte-translate e GYTE_AI_CMD
if [ -x "$TRANSLATE" ] && [ -n "${GYTE_AI_CMD:-}" ]; then
  echo "" >&2
  echo "== Step 3 (opzionale): Translate via GYTE_AI_CMD ==" >&2
  echo "Nota: NON mettere mai OPENAI_API_KEY in file/script. Solo env." >&2

  # esempio: verso en (cambia come vuoi)
  "$TRANSLATE" --to en "$AI_TXT"
else
  echo "" >&2
  echo "Skip translate: serve scripts/gyte-translate + env GYTE_AI_CMD impostata." >&2
  echo "Esempio:" >&2
  echo "  export GYTE_AI_CMD='gyte-openai --model gpt-4.1-mini'" >&2
  echo "  gyte-translate --to en \"$AI_TXT\"" >&2
fi

echo "" >&2
echo "Done ✅  (outdir: $OUTDIR)" >&2
