#!/usr/bin/env bash
set -euo pipefail

# Esempio di utilizzo base di GYTE su un singolo video.
# Prima di usare questo script, assicurati che i comandi seguenti siano nel PATH:
#   - gyte-transcript
#   - gyte-audio
#   - gyte-video
#   - gyte-reflow-text

VIDEO_URL="https://www.youtube.com/watch?v=VIDEO_ID_REPLACE_ME"

echo ">> Transcript del video"
gyte-transcript "$VIDEO_URL"

echo
echo ">> Audio del video (MP3)"
gyte-audio "$VIDEO_URL"

echo
echo ">> Video completo (MP4)"
gyte-video "$VIDEO_URL"

echo
echo ">> Reflow del transcript (se esiste un .txt appena creato)"
# Prende il primo .txt trovato nella directory corrente
TXT_FILE="$(ls *.txt 2>/dev/null | head -n 1 || true)"

if [ -n "${TXT_FILE:-}" ]; then
  OUT_FILE="${TXT_FILE%.txt}.sentences.txt"
  echo "   - Input : $TXT_FILE"
  echo "   - Output: $OUT_FILE"
  gyte-reflow-text "$TXT_FILE" > "$OUT_FILE"
else
  echo "   Nessun file .txt trovato nella cartella corrente."
fi
