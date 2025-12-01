#!/usr/bin/env bash
set -euo pipefail

# Esempio di utilizzo di:
#   - gyte-translate
#   - gyte-ai-openai
#
# ATTENZIONE:
#   - NON inserire mai la tua API key nel codice di questo file.
#   - NON committare mai una riga del tipo:
#       export OPENAI_API_KEY="sk-..."
#   - Imposta sempre la key SOLO nell'ambiente della tua shell.

########################################
# 1. Check variabili d'ambiente
########################################

if [ -z "${OPENAI_API_KEY:-}" ]; then
  echo "[ERROR] OPENAI_API_KEY non impostata." >&2
  echo "        Esempio (da eseguire nella tua shell, NON da committare):" >&2
  echo '          export OPENAI_API_KEY="sk-..."' >&2
  exit 1
fi

# Comando AI da usare con gyte-translate
: "${GYTE_AI_CMD:=gyte-ai-openai --model gpt-4.1-mini}"

########################################
# 2. File di input di esempio
########################################

INPUT_FILE="${1:-sample.it.txt}"

if [ ! -f "$INPUT_FILE" ]; then
  echo "[INFO] File di input non trovato: $INPUT_FILE" >&2
  echo "[INFO] Creo un esempio minimale in italiano..." >&2
  cat > "$INPUT_FILE" << 'EOF'
Ciao mondo! Questo è un piccolo esempio di transcript da tradurre.
GYTE è una mini-suite da linea di comando per lavorare con video e corsi YouTube.
EOF
fi

########################################
# 3. Esecuzione gyte-translate
########################################

echo ">> Using GYTE_AI_CMD: $GYTE_AI_CMD"
echo ">> Input file        : $INPUT_FILE"
echo ">> Target language   : en"

export GYTE_AI_CMD

gyte-translate \
  --from it \
  --to en \
  "$INPUT_FILE"

echo
echo ">> Traduzione completata. Controlla il file generato (es. *.en.txt)."

