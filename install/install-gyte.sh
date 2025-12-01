#!/usr/bin/env bash
set -euo pipefail

# Uso:
#   install-gyte.sh [--target-dir DIR]
#
# Esempi:
#   # installazione standard in ~/.local/bin
#   ./install/install-gyte.sh
#
#   # installazione in una directory custom (sconsigliata fuori da $HOME)
#   ./install/install-gyte.sh --target-dir "$HOME/bin"
#
# Env:
#   GYTE_INSTALL_DIR   directory di destinazione (default: $HOME/.local/bin)
#
# Cosa fa:
#   - individua la cartella "scripts/" del repo GYTE
#   - crea la cartella di destinazione se non esiste
#   - crea symlink per tutti gli script "gyte-*" in TARGET_DIR
#   - stampa un riepilogo dei comandi installati e una nota sul PATH
#
# Cosa NON fa (per scelta di sicurezza):
#   - non usa sudo
#   - non installa nulla fuori da directory controllate dall'utente senza avvisare
#   - non scarica né esegue codice remoto

usage() {
  cat >&2 << 'EOF'
Uso:
  install-gyte.sh [--target-dir DIR]

Esempi:
  # installazione standard in ~/.local/bin
  ./install/install-gyte.sh

  # installazione in una directory custom (user-level)
  ./install/install-gyte.sh --target-dir "$HOME/bin"

Env:
  GYTE_INSTALL_DIR   directory di destinazione (default: $HOME/.local/bin)

Note di sicurezza:
  - Questo script è pensato per installare GYTE a livello utente (sotto $HOME).
  - Non usa sudo e non modifica directory di sistema globali.
EOF
}

TARGET_DIR="${GYTE_INSTALL_DIR:-"$HOME/.local/bin"}"

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --target-dir)
      if [ $# -lt 2 ]; then
        echo "Errore: --target-dir richiede un argomento" >&2
        exit 2
      fi
      TARGET_DIR="$2"
      shift 2
      ;;
    --target-dir=*)
      TARGET_DIR="${1#--target-dir=}"
      shift
      ;;
    --*)
      echo "Opzione non riconosciuta: $1" >&2
      usage
      exit 2
      ;;
    *)
      # niente argomenti posizionali previsti
      echo "Argomento non previsto: $1" >&2
      usage
      exit 2
      ;;
  esac
done

# Individua la root del repo a partire da questo script
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/scripts"

if [ ! -d "$SCRIPTS_DIR" ]; then
  echo "Errore: directory scripts/ non trovata in $REPO_ROOT" >&2
  exit 1
fi

# Colleziona gli script gyte-*
shopt -s nullglob
gyte_scripts=( "$SCRIPTS_DIR"/gyte-* )
shopt -u nullglob

if [ "${#gyte_scripts[@]}" -eq 0 ]; then
  echo "Errore: nessuno script 'gyte-*' trovato in $SCRIPTS_DIR" >&2
  exit 1
fi

# Avviso se il target non è sotto $HOME (scelta consapevole)
if [[ "$TARGET_DIR" != "$HOME"/* && "$TARGET_DIR" != "$HOME" ]]; then
  echo ">> [WARN] La directory di destinazione NON è sotto \$HOME:" >&2
  echo "          $TARGET_DIR" >&2
  echo "          Questo script non usa sudo; l'installazione potrebbe fallire" >&2
  echo "          e non è consigliato installare GYTE in percorsi globali." >&2
fi

echo ">> Repo root      : $REPO_ROOT"
echo ">> Scripts source : $SCRIPTS_DIR"
echo ">> Target dir     : $TARGET_DIR"
echo

# Crea la directory di destinazione (se possibile)
if ! mkdir -p -- "$TARGET_DIR" 2>/dev/null; then
  echo "Errore: impossibile creare la directory di destinazione: $TARGET_DIR" >&2
  echo "Suggerimento: usa una directory sotto \$HOME, ad es.:" >&2
  echo "  ./install/install-gyte.sh --target-dir \"\$HOME/.local/bin\"" >&2
  exit 1
fi

linked=0

for src in "${gyte_scripts[@]}"; do
  base="$(basename "$src")"
  dest="$TARGET_DIR/$base"

  # Se lo script non è eseguibile, avvisa (non cambiamo i permessi qui)
  if [ ! -x "$src" ]; then
    echo ">> [WARN] Script non eseguibile: $src (controlla i permessi nel repo)" >&2
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    echo "   [update] $dest -> $src"
  else
    echo "   [new]    $dest -> $src"
  fi

  ln -sfn -- "$src" "$dest"
  linked=$((linked + 1))
done

echo
echo ">> Creati/aggiornati $linked symlink in: $TARGET_DIR"

# Check PATH
LOCAL_BIN="$TARGET_DIR"
case ":$PATH:" in
  *":$LOCAL_BIN:"*)
    echo ">> [OK] $LOCAL_BIN è già nel PATH."
    ;;
  *)
    echo ">> [WARN] $LOCAL_BIN NON è nel PATH."
    echo "         Aggiungi qualcosa tipo:"
    echo "           export PATH=\"$LOCAL_BIN:\$PATH\""
    echo "         nel tuo ~/.bashrc o equivalente."
    ;;
esac

echo
echo "Comandi disponibili (se $TARGET_DIR è nel PATH):"
for src in "${gyte_scripts[@]}"; do
  base="$(basename "$src")"
  echo "  - $base"
done

echo
echo "Installazione GYTE completata."
