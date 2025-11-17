# 🎙️ Giadaware — yt-transcript

Tool da linea di comando per estrarre in modo massivo le **trascrizioni testuali** da video e playlist YouTube usando [`yt-dlp`](https://github.com/yt-dlp/yt-dlp).

- Supporta **video singoli** e **playlist**
- Converte automaticamente i `.vtt` in `.txt` ripuliti (niente timestamp, tag HTML, righe duplicate)
- Per le playlist crea una cartella dedicata e può lavorare in **parallelo** su più video

> ⚠️ Questo progetto non aggira nessuna protezione DRM, si limita a usare pubblicamente l’API di YouTube tramite yt-dlp.  
> Usalo rispettando i Termini di Servizio della piattaforma e il copyright dei contenuti.

---

## Requisiti

- Linux / macOS (richiede `bash`, `sed`, `awk`, `xargs`)
- Python 3
- `yt-dlp` installato nel PATH, ad esempio:

```bash
pip install yt-dlp

