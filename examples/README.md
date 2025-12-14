# Esempi GYTE (`examples/`)

Questa directory contiene **esempi minimi e sicuri** per usare GYTE.

> ⚠️ **Importante (sicurezza)**  
> - Nessuna chiave API reale deve mai comparire qui.  
> - Tutte le configurazioni sensibili vanno in **variabili d’ambiente** (es. `OPENAI_API_KEY`, `GYTE_AI_CMD`).  
> - I transcript di esempio sono sintetici / non sensibili.

## File presenti

- `sample-transcript.raw.txt`  
  Transcript “grezzo” di esempio (righe spezzate, punteggiatura un po’ sporca).

- `sample-transcript.sentences.txt`  
  Versione “reflow” a frasi, ottenibile con `gyte-reflow-text`.

- `basic_usage.sh`  
  Mostra come usare i comandi principali GYTE con una URL di esempio.

- `ai-openai-translate.sh`  
  Esempio di traduzione usando il wrapper `gyte-openai` via `gyte-translate`.

- `mit-ocw-python.sh`  
  Esempio di workflow su playlist (simile a MIT OCW) usando `gyte-transcript-pl`
  e `gyte-merge-pl`. Usa una URL **placeholder** che devi sostituire a mano.

## Linee guida

- Prima di usare gli script di esempio, esporta le variabili necessarie, ad es.:

  ```bash
  export OPENAI_API_KEY='sk-...'
  export GYTE_AI_CMD='gyte-openai --model gpt-4.1-mini'
  ```

Non aggiungere mai in questo directory:
  - chiavi API reali,
  - transcript con dati personali,
  - file audio/video di grandi dimensioni (il .gitignore del repo li esclude comunque).
