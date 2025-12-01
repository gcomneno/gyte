# GYTE – Release Checklist v1.0.0

Obiettivo: verificare che dopo il refactoring + hardening DevSecOps:
- tutti i comandi `gyte-*` funzionino come previsto,
- i nuovi guardrail di sicurezza siano effettivi,
- la CI e la parte AI opzionale siano coerenti,
- il tag `v1.0.0` rappresenti uno stato “pulito e riproducibile”.

---

## 1. Igiene del repo
- [x] `git status` → working tree **clean**
- [x] Nessun file grosso/strano in `git status` (media, `.env`, roba in `examples/` ecc.)
- [x] `.gitignore` aggiornato e committato
- [x] `requirements.txt` SENZA `openai`
- [x] `requirements-optional.txt` con:
  ```txt
  openai>=1.0.0,<2.0.0
  ```

Comandi suggeriti:
```bash
git status
ls -R examples
```

## 2. Installazione CLI (user-level, no sudo)

    Pulizia eventuale:
        rm -f "$HOME/.local/bin"/gyte-*

    Installazione:
        ./install/install-gyte.sh

    Verifica PATH:
        command -v gyte-transcript
        command -v gyte-video

    Checklist:
        Lo script install/install-gyte.sh è andato a buon fine.
        ~/.local/bin contiene symlink gyte-*.

    Almeno un gyte-* è nel PATH (command -v non fallisce).

## 3. Smoke test su CLI core (yt-dlp-based)
Scegli un video singolo e una playlist corta di YouTube per i test (video pubblici, non “strani”).

### 3.1 gyte-doctor
    gyte-doctor
    yt-dlp trovato
    ffmpeg trovato
    Messaggi [OK]/[WARN] coerenti
    Exit code 0

### 3.2 gyte-transcript (singolo video)
```bash
mkdir -p /tmp/gyte-test-single
cd /tmp/gyte-test-single

gyte-transcript "https://www.youtube.com/watch?v=VIDEO_ID"
```

Verifiche:
creati file *.txt, *.srt, *.md
nessun .vtt residuo
    nessun errore in output

### 3.3 gyte-audio
Sempre in /tmp/gyte-test-single:
    GYTE_AUDIO_FORMAT=mp3 GYTE_AUDIO_QUALITY=192K gyte-audio "https://www.youtube.com/watch?v=VIDEO_ID"

creato un .mp3 con nome Uploader - Titolo [ID].ext
    nessun errore ffmpeg / yt-dlp

### 3.4 gyte-video

GYTE_VIDEO_FORMAT=mp4 gyte-video "https://www.youtube.com/watch?v=VIDEO_ID"

creato .mp4
    nessun warning strano su merge/remux

## 4. Playlist workflow

### 4.1 gyte-transcript-pl (playlist corta)
```bash
mkdir -p /tmp/gyte-test-pl
cd /tmp/gyte-test-pl

gyte-transcript-pl "https://www.youtube.com/watch?v=AAA&list=PLXXXX" 4
```

Verifiche:

creata una directory yt-playlist-*
    dentro:
        urls.txt non vuoto
        file *.txt, *.srt, *.md per alcuni video
        playlist.md aggregato

### 4.2 gyte-merge-pl
Dentro la directory della playlist:
```bash
cd yt-playlist-*
gyte-merge-pl
```

creato <NOME_PLAYLIST>.merged.txt
    il file contiene blocchi con header tipo # [N] Titolo…

## 5. Script di mungitura testo
In root repo o in una dir di test:

### 5.1 gyte-reflow-text
gyte-reflow-text examples/sample-transcript.raw.txt > /tmp/gyte-reflow-out.txt

nessun errore
    l’output è ragionevolmente “a frasi”

### 5.2 gyte-merge-pl con directory passata
Già coperto in §4.2, ma:
    gyte-merge-pl yt-playlist-*

    comportamento identico alla chiamata “dentro” la directory

## 6. Integrazione AI (opzionale)

### 6.1 Setup virtualenv (facoltativo ma consigliato)
```bash
cd /percorso/gyte
python -m venv .venv
source .venv/bin/activate

pip install -r requirements-optional.txt
```

### 6.2 gyte-ai-openai dry-run
```bash
export OPENAI_API_KEY='sk-...'
echo "Ciao mondo" | gyte-ai-openai --dry-run
```

mostra config risolta
conferma modello e lingue
    non invoca l’API (dry-run)

### 6.3 gyte-translate dry-run + reale
```bash
export GYTE_AI_CMD='gyte-ai-openai --model gpt-4.1-mini'

gyte-translate \
  --from it \
  --to en \
  --out /tmp/gyte-ai-test.en.txt \
  --dry-run \
  examples/sample-transcript.sentences.txt
```

dry-run mostra config
    nessun errore

Poi esecuzione reale (se vuoi davvero provare la chiamata):
```bash
gyte-translate \
  --from it \
  --to en \
  --out /tmp/gyte-ai-test.en.txt \
  examples/sample-transcript.sentences.txt
```

file /tmp/gyte-ai-test.en.txt creato
    contenuto coerente (traduzione plausibile)

## 7. Verifica guardrail di sicurezza

### 7.1 URL malformata
gyte-transcript "-NOT_A_URL" || echo "OK (fallito come previsto)"
    lo script rifiuta l’input con messaggio di errore chiaro

### 7.2 Opzioni yt-dlp non permesse
gyte-video "https://www.youtube.com/watch?v=VIDEO_ID" --exec "echo PWNED" && echo "ERRORE" || echo "OK (bloccato)"
    lo script fallisce e segnala che l’opzione non è consentita

## 8. CI / DevSecOps
Workflow GitHub Actions verde
Job Shellcheck scripts OK
Job pip-audit (optional AI deps) eseguito (anche se trova CVE, per ora è soft)
    dependabot.yml attivo per:
        github-actions
        pip (requirements-optional.txt)

## 9. Changelog e versione
[1.0.0] – 2025-12-01

### 9.1 Bump versione
Se hai un file VERSION o qualcosa di simile, portalo a: 1.0.0
