### 🎯 ROADMAP

1. **Merge transcript di playlist**
   - [x] aggregato Markdown `playlist.md` che:
     - [x] legge i file `.md` in `yt-playlist-*`
     - [x] crea un unico `playlist.md` con intestazioni per video (ordine playlist).
   - [x] script dedicato `gyte-merge-pl` che:
     - [x] legge tutti i `.txt` in `yt-playlist-*`
     - [x] crea un unico `PLAYLIST_NAME.merged.txt`
     - [x] opzionale: intestazione con `# [N] Titolo video (ID)` prima di ogni blocco.

2. **Opzioni di output più flessibili**
   - [x] variabile/env o flag `--outdir` per cambiare cartella di destinazione rispetto alla cwd (`GYTE_OUTDIR` + `--outdir` in `gyte-transcript`).
   - [x] supporto per output alternativi in `gyte-transcript`:
     - [x] `.srt` (reformatting dei timestamp da `.vtt`)
     - [x] `.md` (con intestazione per video).

3. **Qualità audio/video configurabile “pulita”**
   - [x] env tipo `GYTE_AUDIO_QUALITY`, `GYTE_AUDIO_FORMAT`, `GYTE_VIDEO_FORMAT`
   - [x] documentare 2–3 preset tipici nel README (sezione audio/video).

4. **“Modo sicuro YouTube”**
   - [x] aggiungere un piccolo throttling opzionale (sleep tra video) nelle playlist per ridurre il rischio di 429:
     - `GYTE_SLEEP_BETWEEN=2` secondi (già implementato)
   - [x] flag `--no-parallel` per forzare sequenziale in `gyte-transcript-pl` (già implementato).

5. **UX / Messaggi**
   - [x] log un po’ più leggibili (prefisso `>>` / `[INFO]` / `[WARN]`)
   - [x] gestione esplicita del caso:
     - [x] nessun sottotitolo trovato per le lingue richieste
     - [x] solo `auto-sub` disponibili → messaggio dedicato
     - [x] lingua fallback (es: `it` fallisce → uso `en` e lo dico chiaramente).

6. **Check dipendenze**
   - [x] script `gyte-doctor` che controlla:
     - [x] presenza `yt-dlp`
     - [x] presenza `ffmpeg`
     - [x] eventuale runtime JS (deno/node) e stampa warning “soft”.

7. **GitHub Actions (CI mini)**
   - [x] workflow che:
     - [x] fa un `shellcheck` sugli script
     - [x] lancia una `dry-run` su una URL di test (senza scaricare media, solo metadata/titoli).

8. **Packaging light**
   - [x] cartella `install/` con:
     - [x] uno script `install-gyte.sh` che:
       - [x] copia/symlinka i `gyte-*` in `~/.local/bin`
       - [x] stampa riepilogo comandi disponibili.

9. **Modulo AI esterno per traduzione transcript**
   - [x] integrazione opzionale con servizio AI esterno per tradurre i transcript (.txt / .md)
   - [x] CLI helper dedicato (es. `gyte-translate`) che prende in input file + lingua target
   - [x] documentazione nel README su configurazione chiavi/API e limiti d’uso
