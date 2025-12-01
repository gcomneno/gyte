#!/usr/bin/env bash
set -euo pipefail

# Esempio workflow playlist (tipo corso MIT OCW Python)
#
# ATTENZIONE:
#   Sostituisci PLAYLIST_URL con una URL reale di playlist YouTube
#   prima di eseguire.
#
# Cosa fa:
#   - scarica transcript per tutta la playlist (gyte-transcript-pl)
#   - genera playlist.md aggregato
#   - unisce tutti i .txt in un singolo file con gyte-merge-pl

usage() {
  cat >&2 << 'EOF'
Uso:
  ./mit-ocw-python.sh "https://www.youtube.com/watch?v=AAA&list=PLXXXX"

Esempio:
  ./mit-ocw-python.sh "https://www.youtube.com/watch?v=AAA&list=PLXXXX"
EOF
}

if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  usage
  exit 0
fi

if [ "$#" -ne 1 ]; then
  echo "Errore: devi passare esattamente 1 URL di playlist." >&2
  usage
  exit 1
fi

PLAYLIST_URL="$1"

if [[ "$PLAYLIST_URL" != http://* && "$PLAYLIST_URL" != https://* ]]; then
  echo "Errore: URL non valido: '$PLAYLIST_URL' (deve iniziare con http:// o https://)" >&2
  exit 1
fi

if [[ "$PLAYLIST_URL" != *"list="* ]]; then
  echo "Errore: sembra che l'URL non contenga un parametro 'list=' (non è una playlist completa)." >&2
  exit 1
fi

echo ">> Scarico transcript per tutta la playlist..."
gyte-transcript-pl "$PLAYLIST_URL" 4

echo
echo ">> Cerco directory playlist appena creata..."
PLAYLIST_DIR="$(find . -maxdepth 1 -type d -name 'yt-playlist-*' | head -n 1 || true)"

if [ -z "$PLAYLIST_DIR" ]; then
  echo "Errore: nessuna directory 'yt-playlist-*' trovata dopo gyte-transcript-pl." >&2
  exit 1
fi

echo ">> Directory playlist: $PLAYLIST_DIR"
echo ">> Merge dei transcript in un unico file..."
gyte-merge-pl "$PLAYLIST_DIR"

echo
echo ">> Esempio completato."
echo "   - Cartella playlist: $PLAYLIST_DIR"
echo "   - File aggregato: $(basename "$PLAYLIST_DIR").merged.txt"
echo "   - File playlist Markdown: playlist.md dentro la stessa cartella."
