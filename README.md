# GYTE
GiadaWare YouTube Toolkit Extractor — extract transcript, audio e video da YouTube via yt-dlp + bash.

GYTE è una mini–suite da linea di comando per scaricare da YouTube in modo pulito:
* Trascrizioni testuali (pulite da timestamp e markup)
* Solo audio (MP3, qualità configurabile)
* Video completo (MP4, best audio+video uniti)
* Reflow del testo (una frase per riga, a partire dai transcript)
* Traduzione assistita via AI dei transcript (tramite comando esterno configurabile)
* Trascrizione locale di file audio/video via Whisper (opzionale)

Basato su [`yt-dlp`](https://github.com/yt-dlp/yt-dlp), con script pensati per corsi interi e playlist lunghe.
> ⚠️ GYTE non aggira alcuna protezione DRM.  
> Usa YouTube tramite yt-dlp così com'è.  
> Sta a te rispettare Termini di Servizio e copyright dei contenuti.

---

## Requisiti
- Linux / macOS (servono: `bash`, `sed`, `awk`, `xargs`)
- Python 3 (se usi `yt-dlp` via pip)  
  oppure il binario standalone di `yt-dlp` per Linux
- `yt-dlp` nel PATH, ad esempio:

  ```bash
  pip install yt-dlp
  ```

  oppure (esempio binario standalone):

  ```bash
  curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -o ~/.local/bin/yt-dlp
  chmod +x ~/.local/bin/yt-dlp
  ```

- `ffmpeg` installato (per l'estrazione audio/video)

- Per il modulo AI opzionale (`gyte-translate` + `gyte-openai`):
  - Python 3
  - libreria `openai` installata nel tuo ambiente:

    ```bash
    pip install openai
    ```

- Per la trascrizione locale con Whisper (`gyte-whisper-local`, opzionale):
  - Python 3
  - tool Whisper CLI installato (ad esempio via `openai-whisper` in un venv):

    ```bash
    python3 -m venv ~/venv/whisper
    source ~/venv/whisper/bin/activate
    pip install -U openai-whisper
    ```

---

### 🔍 gyte-doctor
Per verificare velocemente se l'ambiente è pronto per usare GYTE:

```bash
gyte-doctor
```

Controlla:
  - presenza di `yt-dlp` nel PATH
  - presenza di `ffmpeg` nel PATH
  - `$HOME/.local/bin` nel PATH
  - eventuale runtime JS (node/deno) come dipendenza opzionale (soft)

Ritorna exit code `0` se le dipendenze essenziali sono OK, `1` altrimenti.

---

## Installazione
Clona il repository:

```bash
git clone https://github.com/gcomneno/gyte.git
cd gyte
```

### Installazione rapida (script di install)
Dalla root del progetto:

```bash
chmod +x install/gyte-install
./install/gyte-install
```

Di default gli script verranno symlinkati in:

```bash
$HOME/.local/bin
```

Puoi scegliere una directory diversa usando:

```bash
./install/gyte-install --prefix "/percorso/personalizzato"
# oppure
./install/gyte-install --prefix "/percorso/personalizzato"
```

Assicurati che la directory scelta sia nel tuo `PATH`.  
In caso di dubbi, puoi usare anche:

```bash
gyte-doctor
```

per verificare rapidamente l’ambiente.

### Installare ffmpeg
GYTE usa `ffmpeg` per:
- estrarre solo l'audio dai video (`gyte-audio`)
- unire audio+video nei file (`gyte-video`)

Esempi di installazione:

**Ubuntu / Debian**

```bash
sudo apt update
sudo apt install ffmpeg
ffmpeg -version
```

**macOS (Homebrew)**

```bash
brew install ffmpeg
ffmpeg -version
```

Su altri sistemi operativi puoi installare **ffmpeg** tramite il gestore di pacchetti distribuzione-specifico oppure scaricare un build precompilato e aggiungerlo al PATH.

---

### 🚀 Installazione CLI (user-level, no sudo)
GYTE fornisce una serie di comandi gyte-* accessibili da qualunque directory del sistema.
L’installazione è locale all’utente, non richiede privilegi elevati e non modifica componenti globali.

#### ✔ Installazione standard
Dalla root del repository:
```bash
./install/gyte-install
```

Questo installer:
  - individua automaticamente tutti gli script `gyte-*` nella cartella `bin/`,
  - crea i symlink in `~/.local/bin` (o nella directory indicata in `--prefix DIR`),
  - non usa `sudo` e non scrive fuori da `$HOME`,
  - non scarica né esegue codice remoto.

Al termine, se `~/.local/bin` è nel tuo `PATH`, puoi usare direttamente:
```bash
gyte-transcript
gyte-transcript-pl
gyte-audio
gyte-video
gyte-translate
gyte-reflow-text
gyte-merge-pl
gyte-whisper-local
...
```

#### ✔ Installazione in una directory scelta dall’utente
Puoi scegliere una directory personalizzata, purché sia sotto `$HOME`:
```bash
./install/gyte-install --prefix "$HOME/bin"
```
oppure tramite variabile d’ambiente:
```bash
./install/gyte-install --prefix "$HOME/bin"
```

#### ⚠ Nota di sicurezza
L’installer è progettato per ambienti user-level: se scegli cartelle esterne a `$HOME`, l’operazione potrebbe fallire (e non è consigliata).
Nessun file viene mai sovrascritto senza che venga segnalato.
Nessuna chiave API viene letta, usata o memorizzata durante l’installazione.
Se la directory di destinazione non è nel `PATH`, lo script mostra un messaggio con la riga da aggiungere al tuo `~/.bashrc`.

---

## Comandi disponibili

### 1. Trascrizioni — `gyte-transcript`

Video singolo o playlist: scarica sottotitoli (normali o auto–generati) e produce, per ogni video, i file di testo/markup seguenti nella **directory di output**.

Esempio base:

```bash
gyte-transcript 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Per ogni video ottieni:

- `Uploader - Titolo [VIDEO_ID].en.txt`  
  → transcript pulito (senza timestamp, numeri di riga, tag HTML, righe vuote / duplicate)
- `Uploader - Titolo [VIDEO_ID].en.srt`  
  → sottotitoli in formato SRT “classico” (timestamp `HH:MM:SS,mmm --> HH:MM:SS,mmm`)
- `Uploader - Titolo [VIDEO_ID].en.md`  
  → versione Markdown, con un `#` iniziale e il testo del transcript

Di default lo script prova le lingue `it,en` (prima italiano, poi inglese).  
Le lingue sono configurabili via env:

```bash
YT_TRANSCRIPT_LANGS="en,fr" gyte-transcript 'https://www.youtube.com/watch?v=VIDEO_ID'
```

In caso di errori temporanei (es. HTTP 429 da YouTube), lo script prova comunque a pulire i `.vtt` eventualmente scaricati.

#### Directory di output
Per default i file vengono creati nella **directory corrente**.

Puoi cambiare la cartella di output in due modi:

```bash
# via variabile d’ambiente
GYTE_OUTDIR="/tmp/gyte-out" gyte-transcript 'https://www.youtube.com/watch?v=VIDEO_ID'

# via flag (ha priorità su GYTE_OUTDIR)
gyte-transcript --outdir "/tmp/gyte-out" 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Priorità:

1. `--outdir`
2. `GYTE_OUTDIR`
3. directory corrente

---

### 2. Trascrizioni su playlist — `gyte-transcript-pl`
Pensato per corsi interi / playlist lunghe.

Esempio:

```bash
gyte-transcript-pl 'https://www.youtube.com/playlist?list=PLXXXXX' 4
```

Oppure partendo da una URL con `watch` + `list=`:

```bash
gyte-transcript-pl 'https://www.youtube.com/watch?v=AAA&list=PLXXXXX' 4
```

Cosa fa:

1. Normalizza l'URL in  
   `https://www.youtube.com/playlist?list=PLXXXXX`
2. Recupera il titolo della playlist
3. Crea una cartella:

   ```text
   yt-playlist-NOME_PLAYLIST
   ```

4. Dentro quella cartella:
   - salva `urls.txt` con tutte le URL dei video
   - lancia fino a `MAX_JOBS` processi `gyte-transcript` in parallelo (default: 4)
   - genera, per ogni video, i file `.txt`, `.srt`, `.md` descritti sopra
   - genera `playlist.md`, con:
     - `# Playlist: NOME_PLAYLIST` in testa (se disponibile)
     - una sezione `## ...` per ogni video, in ordine playlist, con il relativo transcript Markdown

Suggerimento: se YouTube inizia a rispondere con molti HTTP 429 (Too Many Requests), puoi ridurre il parallelismo, ad esempio:

```bash
gyte-transcript-pl 'https://www.youtube.com/playlist?list=PLXXXXX' 1
```

Oppure usare la modalità sequenziale (`--no-parallel`) con una pausa tra un video e l’altro:

```bash
GYTE_SLEEP_BETWEEN=2 gyte-transcript-pl --no-parallel 'https://www.youtube.com/watch?v=AAA&list=PLXXXXX'
```

---

### 3. Merge transcript di playlist — `gyte-merge-pl`
Dopo aver generato i transcript di una playlist con `gyte-transcript-pl`, puoi unire tutti i `.txt` in un unico file “merged” ordinato:

```bash
cd yt-playlist-NOME_PLAYLIST
gyte-merge-pl
```

Cosa fa:

- cerca tutti i `.txt` nella directory della playlist,
- li concatena in:

  ```text
  NOME_PLAYLIST.merged.txt
  ```

- aggiunge, per ogni blocco, un’intestazione del tipo:

  ```text
  # [N] Titolo video (ID)
  # File: filename.txt
  ```

Utile per avere un unico “malloppone” di testo per l’intera playlist.

---

### 4. Solo audio — `gyte-audio`
Scarica solo l'audio dei video (o playlist) e lo converte in MP3 (o altro formato supportato da ffmpeg).

Esempio:

```bash
gyte-audio 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Impostazioni di default:

- formato: `mp3`
- qualità target: `192K`

#### Qualità e formato (audio)

Puoi personalizzare il formato / la qualità in due modi.

**API storica** (ancora supportata):

```bash
AUDIO_FORMAT=opus AUDIO_QUALITY=160K gyte-audio 'https://www.youtube.com/watch?v=VIDEO_ID'
```

**API GYTE (ha priorità se impostata):**

```bash
GYTE_AUDIO_FORMAT=opus GYTE_AUDIO_QUALITY=160K gyte-audio 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Priorità:
1. `GYTE_AUDIO_FORMAT` / `GYTE_AUDIO_QUALITY`
2. `AUDIO_FORMAT` / `AUDIO_QUALITY`
3. default interni dello script (`mp3` / `192K`)

Funziona anche con playlist (`--yes-playlist` è già attivo), salvando un file audio per ogni video.

---

### 5. Video completo — `gyte-video`

Scarica il miglior video+audio disponibili e li unisce in un unico file.

Esempio:

```bash
gyte-video 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Caratteristiche:

- usa `bv*+ba/best` per combinare best video + best audio
- per default crea file MP4 (remux con ffmpeg, niente ricompressione se non necessario)
- zero sottotitoli / zero embed

#### Formato di output (video)
Puoi cambiare il formato container di output (quando supportato da yt-dlp/ffmpeg) impostando:

```bash
GYTE_VIDEO_FORMAT=mkv gyte-video 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Se `GYTE_VIDEO_FORMAT` non è impostato, lo script usa il formato predefinito (`mp4`), come nelle versioni precedenti.

Supporta anche playlist:

```bash
gyte-video 'https://www.youtube.com/playlist?list=PLXXXXX'

# Layout consigliato per playlist/corsi:
gyte-video --playlist-layout --archive downloaded.txt 'https://www.youtube.com/playlist?list=PLXXXXX'
```

---

### 6. Reflow testo — `gyte-reflow-text`
Normalizza un `.txt` (ad esempio generato da `gyte-transcript`) in modo “comodo da leggere / diffare / dare in pasto ad AI”.

Di default fa **entrambi**:
- compattazione in paragrafi (righe spezzate riunite),
- split in frasi: **una frase per riga**.

Modalità esplicite:
- `--paragraphs` → solo compattazione paragrafi (niente split in frasi)
- `--sentences` → solo split in frasi (assume input già compattato)

Opzioni utili:
- `--max-width N` → wrap dolce a N caratteri (non spezza parole)
- `--stats` → statistiche su stderr (stdout resta pulito)

Esempi:

```bash
# default: paragraphs + sentences
gyte-reflow-text lecture1.en.txt > lecture1.en.sentences.txt

# solo compattazione
gyte-reflow-text --paragraphs lecture1.en.txt > lecture1.en.paragraphs.txt

# solo split in frasi (input già compattato)
gyte-reflow-text --sentences lecture1.en.paragraphs.txt > lecture1.en.sentences.txt

# output più “terminal/diff friendly”
gyte-reflow-text --max-width 100 lecture1.en.txt > lecture1.en.wrap.txt

# stats (non sporca lo stdout)
gyte-reflow-text --stats lecture1.en.txt > /dev/null
```

Nota: lo splitter è “smarter” e prova a NON spezzare su abbreviazioni IT/EN (Prof., e.g., Mr.), decimali/versioni (3.14, v1.2) ed enumerazioni (1., A.).

Demo rapida: `examples/reflow-splitter-demo.sh` (con sample in `examples/reflow-splitter-sample.txt`).

#### Preset AI-friendly

```bash
# Transcript -> reflow "AI-friendly" -> translate (comando AI esterno)
gyte-transcript URL --outdir out/
gyte-reflow-text --ai-friendly out/video.it.txt > out/video.it.ai.txt
GYTE_AI_CMD='gyte-openai --model gpt-4.1-mini' gyte-translate --to en out/video.it.ai.txt
```

Sanitizzazione UTF-8 (opt-in)

# Esempio file "sporco" (byte non UTF-8)
```bash
printf 'ok\xffbad\n' > /tmp/dirty.txt

# Ripulisce e garantisce stdout UTF-8 valido
gyte-reflow-text --strict-utf8 /tmp/dirty.txt > /tmp/dirty.clean.txt
```

---

### 7. Traduzione AI dei transcript — `gyte-translate`
Usa un comando AI esterno (configurato via `GYTE_AI_CMD`) per tradurre i transcript generati da GYTE (`.txt`, `.md`, ecc.).

Esempio:

```bash
export GYTE_AI_CMD='my-ai-wrapper --model gpt4'
gyte-translate --to en lecture.it.txt
# -> produce: lecture.en.txt
```

Regole di naming default:

- `lecture.it.txt` → `lecture.en.txt`
- `notes.md` → `notes.en.md`
- `raw_transcript` → `raw_transcript.en`

---

### 8. Trascrizione locale MP4/audio — `gyte-whisper-local`
`gyte-whisper-local` usa un comando di speech-to-text locale (di default `whisper`) per estrarre transcript da file **locali** (`.mp4`, `.mp3`, ecc.), senza passare da YouTube.

Esempio base:

```bash
gyte-whisper-local lesson1.mp4
```

Cosa fa:

- verifica che il file esista
- chiama il comando STT (default: `whisper`) con:
  - modello configurabile (`--model` o `GYTE_WHISPER_MODEL`)
  - lingua opzionale (`--lang/--language` o `GYTE_WHISPER_LANG`)
  - output in una directory scelta (`--outdir` o `GYTE_OUTDIR`)
- genera nella directory di output:
  - `<basename>.txt` – testo puro
  - `<basename>.srt` – sottotitoli SRT

Opzioni principali:

- `--model MODEL`  
  Modello Whisper da usare (`tiny`, `base`, `small`, `medium`, `large`).  
  Default: valore di `GYTE_WHISPER_MODEL` o `"small"`.

- `--lang LANG` / `--language LANG`  
  Lingua di lavoro (es. `en`, `it`, `fr`).  
  Default: valore di `GYTE_WHISPER_LANG` o `"auto"` (auto-detect lato Whisper).

- `--outdir DIR`  
  Directory di output.  
  Default: `GYTE_OUTDIR` o directory corrente.

Env utili:

- `GYTE_WHISPER_MODEL` – modello di default per `gyte-whisper-local`
- `GYTE_WHISPER_LANG` – lingua di default (o `auto`)
- `GYTE_OUTDIR` – directory di output di default
- `GYTE_STT_BIN` – comando STT da usare (default: `whisper`)

Esempi:

```bash
# Modello small, lingua auto, output nella cwd
gyte-whisper-local "Git-GitHub-CrashCourse.mp4"

# Forza lingua inglese e mette tutto in ./transcripts
GYTE_OUTDIR="transcripts" gyte-whisper-local --lang en "Git-GitHub-CrashCourse.mp4"

# Usa un binario STT alternativo (es. wrapper personale)
GYTE_STT_BIN="my-whisper-wrapper" gyte-whisper-local lesson1.mkv
```

Dopo la generazione puoi combinare con gli altri strumenti GYTE, ad esempio:

```bash
gyte-reflow-text "Git-GitHub-CrashCourse.txt"   > "Git-GitHub-CrashCourse.en.sentences.txt"

gyte-translate --from en --to it   "Git-GitHub-CrashCourse.en.sentences.txt"
```

---

### 📦 Output filesystem & Manifest API

`gyte-explain` produce un output strutturato su filesystem.
Questa struttura è **stabile e pensata come API** per script, tooling e post-processing automatico.

#### Struttura generale

```text
out/
└── gyte-explain-YYYYMMDD-HHMMSS/
    ├── manifest.json              # RUN manifest
    └── items/
        └── 001/
            ├── manifest.json      # ITEM manifest
            ├── title.txt
            ├── url.txt
            ├── langs.txt
            ├── row.tsv
            ├── transcript.txt     # se disponibile
            ├── summary.txt        # se generato
            └── transcript_error.txt  # in caso di errore
```

---

#### RUN manifest — `out/<run>/manifest.json`
Contiene:
- metadati della run
- configurazione risolta
- lista item processati
- conteggi aggregati

Esempio (ridotto):
```json
{
  "schema": "gyte.manifest.run.v1",
  "gyte_version": "v1.1.0",
  "run": {
    "id": "gyte-explain-20260203-124339",
    "status": "ok"
  },
  "config": {
    "ai_mode": "local",
    "langs": ["it", "en"],
    "argv": ["gyte-explain", "1", "--ai", "local"]
  },
  "counts": {
    "items_total": 1,
    "items_ok": 1,
    "items_error": 0
  },
  "items": {
    "001": {
      "status": "ok",
      "path": "items/001/manifest.json"
    }
  }
}
```

---

#### ITEM manifest — `out/<run>/items/<ID>/manifest.json`
È **sempre scritto**, anche in caso di errore.

Campi chiave:
- `status`: `ok | no_transcript | invalid_url | error`
- `transcript_source`: `subs | whisper | none`
- `summary_source`: `local | openai | none`
- `error_message`: stringa o `null`
- `paths`: percorsi relativi agli artefatti
- `meta.exists`: presenza reale dei file su disco

Esempio (errore URL):
```json
{
  "schema": "gyte.manifest.item.v1",
  "id": "001",
  "status": "invalid_url",
  "transcript_source": "none",
  "summary_source": "none",
  "error_message": "invalid url",
  "paths": {
    "title": "title.txt",
    "url": "url.txt",
    "transcript_error": "transcript_error.txt"
  }
}
```

👉 **Garanzia**: tool esterni possono fidarsi del manifest senza dover inferire stato dai file.

---

### ✨ v1.1.0 — Manifest API & determinismo

**Novità principali**
- Aggiunto `manifest.json` **sempre scritto**:
  * uno per RUN
  * uno per ogni ITEM
- Manifest progettati come **API stabile su filesystem**
- Stato esplicito per ogni item:
  * `ok`
  * `no_transcript`
  * `invalid_url`
  * `error`
- Tracciamento sorgenti:
  * transcript: `subs | whisper | none`
  * summary: `local | openai | none`
- `argv` serializzato come **lista di token** (non stringa)
- `gyte_version` risolta automaticamente:
  * file `VERSION` → `git describe` → `UNKNOWN`

**Garanzie**
- Nessun cambiamento a:
  * stdout
  * stderr
  * exit code
- Nessuna dipendenza aggiuntiva (solo bash + python stdlib)

**Perché conta**
- GYTE ora è **script-friendly**, automabile e introspezionabile
- Il filesystem diventa una API affidabile, non un effetto collaterale

---

## Modulo AI esterno – `gyte-translate`
`gyte-translate` non contiene nessuna logica di AI “interna`: si limita a prendere un file di testo e a passarlo a un comando esterno che legge da `stdin` e scrive il risultato su `stdout`.

Il comando esterno viene configurato tramite:
```bash
export GYTE_AI_CMD='my-ai-wrapper --model gpt4'
```

Durante l’esecuzione, GYTE imposta due variabili d’ambiente che il comando può usare:
- `SRC_LANG`    – lingua sorgente (es. `auto`, `it`, `en`)
- `TARGET_LANG` – lingua di destinazione (es. `en`, `it`, `fr`)

### Uso base
```bash
gyte-translate --to en lecture.it.txt
# -> legge lecture.it.txt
# -> invoca: SRC_LANG=auto TARGET_LANG=en bash -c "$GYTE_AI_CMD"
# -> salva il risultato in lecture.en.txt
```

### Opzioni principali
- `--to, --target-lang LANG`  
  Lingua di destinazione (obbligatoria, oppure via `GYTE_AI_TARGET_LANG`).

- `--from, --source-lang LANG`  
  Lingua sorgente (default: `auto` o `GYTE_AI_SOURCE_LANG`).

- `--out FILE`  
  File di output esplicito.  
  Se omesso, GYTE costruisce il nome da quello di input inserendo `.LANG` prima dell’estensione.

- `--dry-run`  
  Mostra la configurazione risolta (file, lingue, comando AI) senza eseguire la chiamata.

### Note su chiavi API e limiti
`gyte-translate` **non** gestisce chiavi API, token, retry, throttling, ecc.  
Tutta la logica di autenticazione e di gestione errori è a carico del comando configurato in `GYTE_AI_CMD`.

Questo permette di usare:
- wrapper personali,
- CLI ufficiali di provider,
- script intermedi che spezzano file troppo lunghi, ecc.

---

## Integrazione AI (opzionale)
Alcune funzioni (es. `gyte-openai` + `gyte-translate`) richiedono il client Python `openai`.

Installazione opzionale:
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements-optional.txt
```

Poi esporta:
```bash
export OPENAI_API_KEY='sk-...'
export GYTE_AI_CMD='gyte-openai --model gpt-4.1-mini'
```

---

### Esempio: usare `gyte-translate` con OpenAI (`gyte-openai`)
Il repository include un wrapper di riferimento per OpenAI:

- script: `scripts/gyte-openai`
- uso: come valore di `GYTE_AI_CMD`

> ⚠️ **Sicurezza API key**
> - NON salvare mai la tua API key in file, script o repository.
> - Usala solo tramite variabile d'ambiente `OPENAI_API_KEY`.
> - Non committare mai uno `export OPENAI_API_KEY="sk-..."` dentro script versionati.

Prerequisiti:
```bash
pip install openai
export OPENAI_API_KEY="sk-..."   # NON committare mai questa riga
```

Poi puoi configurare GYTE così:
```bash
export GYTE_AI_CMD='gyte-openai --model gpt-4.1-mini'
```

# esempio: traduci da italiano a inglese
gyte-translate --from it --to en sample.it.txt
# -> produce: sample.en.txt

Se non specifichi `--from`, `gyte-translate` usa `auto` come lingua sorgente (o `GYTE_AI_SOURCE_LANG` se impostata).

Puoi verificare la configurazione senza chiamare l’API con `--dry-run`:

```bash
echo "Ciao mondo, questo è un test." > sample.it.txt

SRC_LANG=it TARGET_LANG=en   gyte-openai --model gpt-4.1-mini --dry-run < sample.it.txt
```

Il wrapper:
- legge il testo da **stdin**,
- usa `SRC_LANG` / `TARGET_LANG` (impostate da `gyte-translate`),
- chiama il modello OpenAI scelto,
- scrive SOLO il testo tradotto su **stdout** (nessun log mischiato ai dati).

---

# Esempi GYTE
La cartella `examples` contiene esempi pratici di utilizzo di GYTE:

- `basic-usage.sh`  
  Esempio di utilizzo base su un singolo video: transcript, audio, video e reflow del testo.

- `mit-ocw-python.sh`  
  Esempio pensato per una playlist di corso (MIT 6.100L) con estrazione transcript.

- `sample-transcript.raw.txt`  
  Esempio di transcript "grezzo" come potrebbe uscire da `gyte-transcript`.

- `sample-transcript.sentences.txt`  
  Lo stesso testo, dopo il passaggio con `gyte-reflow-text` (una frase per riga).

- `ai-openai-translate.sh`  
  Esempio di utilizzo combinato di `gyte-translate` + `gyte-openai` (senza mai salvare l’API key in chiaro negli script).

Questi file sono solo dimostrativi: sostituisci le URL e i nomi file con quelli che ti servono nel tuo contesto reale.

---

## Come impostare la lingua per le trascrizioni
Per impostazione predefinita, `gyte-transcript` usa:
```bash
YT_TRANSCRIPT_LANGS="it,en"
```

cioè:
- prova prima a scaricare i sottotitoli in italiano (`it`);
- se non disponibili, ripiega su inglese (`en`).

Puoi cambiare questo comportamento impostando l'env prima del comando.

```bash
# Solo inglese
YT_TRANSCRIPT_LANGS="en" gyte-transcript "https://www.youtube.com/watch?v=VIDEO_ID"

# Francese con fallback su inglese
YT_TRANSCRIPT_LANGS="fr,en" gyte-transcript "https://www.youtube.com/watch?v=VIDEO_ID"
```

Se vuoi forzare una lingua meno comune (es. tedesco) sapendo che spesso ci sono solo auto–sub:
```bash
# Solo tedesco
YT_TRANSCRIPT_LANGS="de" gyte-transcript "https://www.youtube.com/watch?v=VIDEO_ID"
```

Nota: l’ordine delle lingue in `YT_TRANSCRIPT_LANGS` è significativo: viene usata la prima disponibile nell’elenco.

---

# 🔐 Sicurezza & Privacy
GYTE è progettato secondo i principi DevSecOps minimalisti, con l’obiettivo di evitare rischi comuni nella supply-chain, nell’uso di wrapper AI e negli script shell. Non raccoglie né invia alcun dato proprio: tutto avviene localmente, tramite strumenti standard.

## ✦ Come GYTE protegge l’utente

#### Nessuna chiave nel codice o negli script.
Tutti i segreti (es. OPENAI_API_KEY) devono essere forniti solo tramite variabili d’ambiente.
GYTE non stampa mai il valore di tali variabili.

#### Wrapper yt-dlp “blindati”.
Gli script rifiutano opzioni pericolose come:
`--exec*`, `--postprocessor-args`, `--run-postprocessor`

impedendo l’esecuzione accidentale di comandi arbitrari.

#### Validazione input rigorosa.
Le URL devono iniziare con `http(s)://`
(così non possono trasformarsi in opzioni nascoste tipo `-someflag`).

#### Nessuna dipendenza remota eseguita automaticamente.
Non esistono sequenze `curl | sh`, script bootstrap legacy o download silenziosi.

#### Limitazione volontaria degli input AI.
Gli script di traduzione supportano:

- `GYTE_AI_MAX_INPUT_BYTES` / `GYTE_AI_MAX_INPUT_CHARS`

per evitare di inviare per errore file enormi ai provider AI.

#### File generati esclusi dal repository.
Il `.gitignore` protegge il repo da:
  - media scaricati (mp4/mp3/mkv…),
  - sottotitoli, log, tmp,
  - virtualenv e file `.env` con segreti.

## ✦ Cosa non fa GYTE (per scelta)
- Non gestisce chiavi API. Le usa solo se già impostate nell’ambiente dell’utente.
- Non esegue comandi arbitrari forniti all’interno di URL, alias o variabili.
- Non modifica il sistema dell’utente (no installazioni, no permessi elevati).

## ✦ Buone pratiche consigliate
- Mantieni `yt-dlp` e `ffmpeg` aggiornati.
- Non salvare transcript sensibili nelle cartelle versionate.
- Usa un `.env` locale (ignorato dal repo) per configurare API key.
- Prima di usare provider AI, valuta se il contenuto del transcript è adatto a essere inviato a terze parti.

---

## Roadmap
Vedi il file `docs/ROADMAP.md` per i dettagli.

---

## Specs & Commands
- `docs/commands/` (comandi)
- `docs/spec/` (specifiche/manifest)
- `docs/CHANGELOG.md` (storia versioni)

---

## Licenza
Rilasciato sotto licenza MIT.  
Vedi il file `LICENSE` per i dettagli.
