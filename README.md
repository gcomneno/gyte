# GYTE
GiadaWare YouTube Toolkit Extractor — extract transcript, audio e video da YouTube via yt-dlp + bash.

GYTE è una mini–suite da linea di comando per scaricare da YouTube in modo pulito:
* Trascrizioni testuali (pulite da timestamp e markup)
* Solo audio (MP3, qualità configurabile)
* Video completo (MP4, best audio+video uniti)
* Reflow del testo (una frase per riga, a partire dai transcript)

Basato su [`yt-dlp`](https://github.com/yt-dlp/yt-dlp), con script pensati per corsi interi e playlist lunghe.
> ⚠️ GYTE non aggira alcuna protezione DRM.
> Usa YouTube tramite yt-dlp così com'è.
> Sta a te rispettare Termini di Servizio e copyright dei contenuti.

---

## Requisiti
- Linux / macOS (servono: bash, sed, awk, xargs)

- Python 3 (se usi `yt-dlp` via pip)
  oppure il binario standalone di `yt-dlp` per Linux

- `yt-dlp` nel PATH, ad esempio:

  pip install yt-dlp

  oppure (esempio binario standalone):

  curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux -o ~/.local/bin/yt-dlp  
  chmod +x ~/.local/bin/yt-dlp

- `ffmpeg` installato (per l'estrazione audio/video)

---

### 🔍 gyte-doctor
Per verificare velocemente se l'ambiente è pronto per usare GYTE:

```bash
gyte-doctor
````

Controlla:

* presenza di yt-dlp nel PATH
* presenza di ffmpeg nel PATH
* ~/.local/bin nel PATH
* eventuale runtime JS (node/deno) come dipendenza opzionale!

Ritorna exit code 0 se le dipendenze essenziali sono OK, 1 altrimenti.

---

## Installazione

Clona il repository:

```bash
git clone https://github.com/gcomneno/gyte.git
cd gyte
```

Rendi eseguibili gli script:

```bash
chmod +x scripts/gyte-*
```

Opzionale: aggiungili al PATH (esempio con `~/.local/bin`):

```bash
# dalla root del progetto GYTE

mkdir -p ~/.local/bin
ln -sf "$(pwd)/scripts/gyte-transcript"    ~/.local/bin/gyte-transcript
ln -sf "$(pwd)/scripts/gyte-transcript-pl" ~/.local/bin/gyte-transcript-pl
ln -sf "$(pwd)/scripts/gyte-audio"         ~/.local/bin/gyte-audio
ln -sf "$(pwd)/scripts/gyte-video"         ~/.local/bin/gyte-video
ln -sf "$(pwd)/scripts/gyte-reflow-text"   ~/.local/bin/gyte-reflow-text
```

Assicurati che `~/.local/bin` sia nel tuo PATH.

### Installare ffmpeg

GYTE usa `ffmpeg` per:

* estrarre solo l'audio dai video (`gyte-audio`)
* unire audio+video nei file MP4 (`gyte-video`)

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

## Comandi disponibili

### 1. Trascrizioni — `gyte-transcript`

Video singolo o playlist: scarica sottotitoli (normali o auto–generati) e produce, per ogni video, i file di testo/markup seguenti nella **directory di output**.

Esempio base:

```bash
gyte-transcript 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Per ogni video ottieni:

* `Uploader - Titolo [VIDEO_ID].en.txt`
  → transcript pulito (senza timestamp, numeri di riga, tag HTML, righe vuote / duplicate)
* `Uploader - Titolo [VIDEO_ID].en.srt`
  → sottotitoli in formato SRT “classico” (timestamp `HH:MM:SS,mmm --> HH:MM:SS,mmm`)
* `Uploader - Titolo [VIDEO_ID].en.md`
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

   * salva `urls.txt` con tutte le URL dei video
   * lancia fino a `MAX_JOBS` processi `gyte-transcript` in parallelo (default: 4)
   * genera, per ogni video, i file `.txt`, `.srt`, `.md` descritti sopra
   * genera `playlist.md`, con:

     * `# Playlist: NOME_PLAYLIST` in testa (se disponibile)
     * una sezione `## ...` per ogni video, in ordine playlist, con il relativo transcript Markdown

Suggerimento: se YouTube inizia a rispondere con molti HTTP 429 (Too Many Requests), puoi ridurre il parallelismo, ad esempio:

```bash
gyte-transcript-pl 'https://www.youtube.com/playlist?list=PLXXXXX' 1
```

Oppure usare la modalità sequenziale (`--no-parallel`) con una pausa tra un video e l’altro:

```bash
GYTE_SLEEP_BETWEEN=2 \
  gyte-transcript-pl --no-parallel 'https://www.youtube.com/watch?v=AAA&list=PLXXXXX'
```

---

### 3. Solo audio — `gyte-audio`

Scarica solo l'audio dei video (o playlist) e lo converte in MP3 (o altro formato supportato da ffmpeg).

Esempio:

```bash
gyte-audio 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Impostazioni di default:

* formato: `mp3`
* qualità target: ~192 kbps

Configurabile via env:

```bash
AUDIO_FORMAT=opus AUDIO_QUALITY=160K gyte-audio 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Funziona anche con playlist (`--yes-playlist`), salvando un file audio per ogni video.

---

### 4. Video completo — `gyte-video`

Scarica il miglior video+audio disponibili e li unisce in un MP4.

Esempio:

```bash
gyte-video 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Caratteristiche:

* usa `bv*+ba/best` per combinare best video + best audio
* `--merge-output-format mp4` → tenta di remuxare in MP4 senza ricodifica
* zero sottotitoli / zero embed

Supporta anche playlist:

```bash
gyte-video 'https://www.youtube.com/playlist?list=PLXXXXX'
```

---

### 5. Reflow testo — `gyte-reflow-text`

Prende un `.txt` (ad esempio generato da `gyte-transcript`) e lo normalizza in:

* paragrafi compattati (righe spezzate riunite),
* una **frase per riga** (split su `. ! ?`).

Esempi:

```bash
# input da file
gyte-reflow-text lecture1.en.txt > lecture1.en.sentences.txt

# input da stdin
cat lecture1.en.txt | gyte-reflow-text > lecture1.en.sentences.txt
```

Se non specifichi `inputfile` o passi `-`, legge da `stdin`.

---

# Esempi GYTE

La cartella `examples` contiene esempi pratici di utilizzo di GYTE:

* `basic-usage.sh`
  Esempio di utilizzo base su un singolo video: transcript, audio, video e reflow del testo.

* `mit-ocw-python.sh`
  Esempio pensato per una playlist di corso (MIT 6.100L) con estrazione transcript.

* `sample-transcript.raw.txt`
  Esempio di transcript "grezzo" come potrebbe uscire da `gyte-transcript`.

* `sample-transcript.sentences.txt`
  Lo stesso testo, dopo il passaggio con `gyte-reflow-text` (una frase per riga).

Questi file sono solo dimostrativi: sostituisci le URL e i nomi file con quelli che ti servono nel tuo contesto reale.

## Come impostare la lingua per le trascrizioni

Per impostazione predefinita, `gyte-transcript` usa:

```bash
YT_TRANSCRIPT_LANGS="it,en"
```

cioè:

* prova prima a scaricare i sottotitoli in italiano (it);
* se non disponibili, ripiega su inglese (en).

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

## Roadmap

Vedi il file `ROADMAP.md` per i dettagli.

---

## Licenza

Rilasciato sotto licenza MIT.
Vedi il file `LICENSE` per i dettagli.
