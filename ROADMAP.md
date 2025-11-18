### 🎯 ROADMAP

1. **Merge transcript di playlist**
   - [ ] script tipo `gyte-merge-pl` che:
     - legge tutti i `.txt` in `yt-playlist-*`
     - crea un unico `PLAYLIST_NAME.merged.txt`
     - opzionale: intestazione con `# [N] Titolo video (ID)` prima di ogni blocco.

2. **Opzioni di output più flessibili**
   - [ ] variabile/env o flag `--outdir` per cambiare cartella di destinazione rispetto alla cwd.
   - [ ] supporto per output alternativi:
     - [ ] `.srt` (solo reformatting dei timestamp da `.vtt`)
     - [ ] `.md` (magari con intestazioni per video).

3. **Qualità audio/video configurabile “pulita”**
   - [ ] env tipo `GYTE_AUDIO_QUALITY`, `GYTE_VIDEO_FORMAT`
   - [ ] documentare 2–3 preset tipici nel README.

4. **“Modo sicuro YouTube”**
   - [ ] aggiungere un piccolo throttling opzionale (sleep tra video) nelle playlist per ridurre il rischio di 429:
     - env tipo `GYTE_SLEEP_BETWEEN=2` secondi
   - [ ] flag `--no-parallel` per forzare sequenziale in `gyte-transcript-pl`.

5. **UX / Messaggi**
   - [ ] log un po’ più leggibili (prefisso `>>` / `[..]` per i vari step)
   - [ ] gestione più esplicita dei casi:
     - niente sottotitoli trovati
     - solo `auto-sub` disponibili
     - lingua fallback (es: `it` fallisce → uso `en` e lo dico chiaramente).

6. **Check dipendenze**
   - [ ] script `gyte-doctor` che controlla:
     - presenza `yt-dlp`
     - presenza `ffmpeg`
     - eventuale runtime JS (deno/node) e stampa warning “soft”.

7. **GitHub Actions (CI mini)**
   - [ ] workflow che:
     - fa un `shellcheck` sugli script
     - lancia una `dry-run` su una URL di test (senza scaricare media, solo metadata/titoli).

8. **Packaging light**
   - [ ] cartella `install/` con:
     - [ ] uno script `install-gyte.sh` che:
       - copia/symlinka i `gyte-*` in `~/.local/bin`
       - stampa riepilogo comandi disponibili.
