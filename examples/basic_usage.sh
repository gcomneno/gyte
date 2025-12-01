#!/usr/bin/env bash
set -euo pipefail

# Esempio di uso base GYTE:
#   - transcript singolo video
#   - audio
#   - video
#
# Sostituisci VIDEO_URL con una URL reale di YouTube prima di eseguire.

usage() {
  cat >&2 << 'EOF'
Uso:
  ./basic_usage.sh "https://www.youtube.com/watch?v=XXXX"

Esempio:
  ./basic_usage.sh "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
EOF
}

if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  usage
  exit 0
fi

if [ "$#" -ne 1 ]; then
  echo "Errore: devi passare esattamente 1 URL YouTube." >&2
  usage
  exit 1
fi

VIDEO_URL="$1"

# Sanity check minimo
if [[ "$VIDEO_URL" != http://* && "$VIDEO_URL" != https://* ]]; then
  echo "Errore: URL non valido: '$VIDEO_URL' (deve iniziare con http:// o https://)" >&2
  exit 1
fi

echo ">> Transcript (.txt/.srt/.md) con gyte-transcript..."
gyte-transcript "$VIDEO_URL"

echo
echo ">> Estrazione audio con gyte-audio..."
gyte-audio "$VIDEO_URL"

echo
echo ">> Download video con gyte-video..."
gyte-video "$VIDEO_URL"

echo
echo ">> Esempio completato."
