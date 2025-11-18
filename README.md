# GYTE
GiadaWare YouTube Toolkit Extractor — extract transcript, audio e video da YouTube via yt-dlp + bash.
---

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

  curl -L [https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux](https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux) -o ~/.local/bin/yt-dlp
  chmod +x ~/.local/bin/yt-dlp

- `ffmpeg` installato (per l'estrazione audio/video)

---

## Installazione

Clona il repository:

```
git clone https://github.com/gcomneno/gyte.git
cd gyte
```

Rendi eseguibili gli script:

```
chmod +x scripts/gyte-*
```

Opzionale: aggiungili al PATH (esempio con `~/.local/bin`):

```
mkdir -p ~/.local/bin
ln -sf "$(pwd)/scripts/gyte-transcript"    ~/.local/bin/gyte-transcript
ln -sf "$(pwd)/scripts/gyte-transcript-pl" ~/.local/bin/gyte-transcript-pl
ln -sf "$(pwd)/scripts/gyte-audio"         ~/.local/bin/gyte-audio
ln -sf "$(pwd)/scripts/gyte-video"         ~/.local/bin/gyte-video
ln -sf "$(pwd)/scripts/gyte-reflow-text"   ~/.local/bin/gyte-reflow-text
```

Assicurati che `~/.local/bin` sia nel tuo PATH.

---

## Comandi disponibili

### 1. Trascrizioni — `gyte-transcript`

Video singolo o playlist: scarica sottotitoli (normali o auto–generati) e produce uno o più `.txt` puliti nella cartella corrente.

Esempio:

```
gyte-transcript 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Per ogni video:

* scarica i sottotitoli in italiano e inglese (lingue default: `it,en`)
* converte i `.vtt` in `.txt` rimuovendo:

  * intestazioni WEBVTT / timestamp
  * numeri di riga
  * tag HTML
  * righe vuote e duplicati consecutivi

Output tipico:

```
Uploader - Titolo [VIDEO_ID].en.txt
```

Lingue configurabili via env:

```
YT_TRANSCRIPT_LANGS="en,fr" gyte-transcript 'https://www.youtube.com/watch?v=VIDEO_ID'
```

In caso di errori temporanei (es. HTTP 429 da YouTube), lo script prova comunque a pulire i `.vtt` eventualmente scaricati.

---

### 2. Trascrizioni su playlist — `gyte-transcript-pl`

Pensato per corsi interi / playlist lunghe.

Esempio:

```
gyte-transcript-pl 'https://www.youtube.com/playlist?list=PLXXXXX' 4
```

Oppure partendo da una URL con `watch` + `list=`:

```
gyte-transcript-pl 'https://www.youtube.com/watch?v=AAA&list=PLXXXXX' 4
```

Cosa fa:

1. Normalizza l'URL in
   `https://www.youtube.com/playlist?list=PLXXXXX`

2. Recupera il titolo della playlist

3. Crea una cartella:

   ```
   yt-playlist-NOME_PLAYLIST
   ```

4. Dentro quella cartella:

   * salva `urls.txt` con tutte le URL dei video
   * lancia fino a `MAX_JOBS` processi `gyte-transcript` in parallelo
   * genera un `.txt` di trascrizione per ogni video

Suggerimento: se YouTube inizia a rispondere con molti HTTP 429 (Too Many Requests), puoi ridurre il parallelismo, ad esempio:

```
gyte-transcript-pl 'https://www.youtube.com/playlist?list=PLXXXXX' 1
```

---

### 3. Solo audio — `gyte-audio`

Scarica solo l'audio dei video (o playlist) e lo converte in MP3 (o altro formato supportato da ffmpeg).

Esempio:

```
gyte-audio 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Impostazioni di default:

* formato: `mp3`
* qualità target: ~192 kbps

Configurabile via env:

```
AUDIO_FORMAT=opus AUDIO_QUALITY=160K gyte-audio 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Funziona anche con playlist (`--yes-playlist`), salvando un file audio per ogni video.

---

### 4. Video completo — `gyte-video`

Scarica il miglior video+audio disponibili e li unisce in un MP4.

Esempio:

```
gyte-video 'https://www.youtube.com/watch?v=VIDEO_ID'
```

Caratteristiche:

* usa `bv*+ba/best` per combinare best video + best audio
* `--merge-output-format mp4` → tenta di remuxare in MP4 senza ricodifica
* zero sottotitoli / zero embed

Supporta anche playlist:

```
gyte-video 'https://www.youtube.com/playlist?list=PLXXXXX'
```

---

### 5. Reflow testo — `gyte-reflow-text`

Prende un `.txt` (ad esempio generato da `gyte-transcript`) e lo normalizza in:

* paragrafi compattati (righe spezzate riunite),
* una **frase per riga** (split su `. ! ?`).

Esempi:

```
# input da file
gyte-reflow-text lecture1.en.txt > lecture1.en.sentences.txt

# input da stdin
cat lecture1.en.txt | gyte-reflow-text > lecture1.en.sentences.txt
```

Se non specifichi `inputfile` o passi `-`, legge da `stdin`.

---

## Roadmap
vedi il file `ROADMAP` per i dettagli
---

## Licenza
Rilasciato sotto licenza MIT.
Vedi il file `LICENSE` per i dettagli.
