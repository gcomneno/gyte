# gyte-whisper-local

## Scopo
`gyte-whisper-local` è un tool **opzionale** per trascrizione locale.
Serve come backend quando vuoi usare `gyte-explain --ai whisper`.

Caratteristiche:
- nessuna dipendenza obbligatoria per GYTE base
- best-effort: usa il primo backend disponibile nel PATH o quello forzato dall’utente
- output contract pulito: **stdout = path** del `.txt` prodotto

## Uso
```bash
gyte-whisper-local [--model MODEL] [--lang LANG] [--outdir DIR] [--backend B] FILE
```

## Opzioni
--model MODEL
Modello (dipende dal backend). Se vuoto → default del backend.

--lang LANG
Lingua (es. it, en). Opzionale.

--outdir DIR
Directory output. Default: stessa directory del file input.

--backend B
auto|whispercpp|faster|openai (default: auto).
In auto, il tool sceglie in base ai binari trovati nel PATH.

## Backend
Se --backend auto:
- se trova whisper.cpp o whisper-cpp → usa whispercpp
- se trova faster-whisper → usa faster
- se trova whisper → usa openai
- Se non trova nulla: errore (exit 2)

## Output
Crea un file .txt in OUTDIR, con nome derivato da input: <stem>.txt

Stampa su stdout il path assoluto del file .txt prodotto (una riga)
stderr: solo errori.

## Exit code:
0 ok
2 uso invalido / file mancante / backend non disponibile / output mancante

## Esempi
Auto backend
gyte-whisper-local --backend auto ./audio.mp3 > /tmp/path.txt
cat /tmp/path.txt

Forzare whisper.cpp
gyte-whisper-local --backend whispercpp --lang it ./audio.mp3

Uso tramite gyte-explain
gyte-explain 001 --ai whisper --langs it,en

## Troubleshooting
- backend non determinato: installa whisper.cpp o faster-whisper (optional deps).
- output mancante o vuoto: il backend ha fallito; controlla che il file input sia valido e che il modello sia compatibile.
