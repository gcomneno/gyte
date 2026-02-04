# gyte-audio
`gyte-audio` è un wrapper **intenzionale** di `yt-dlp` che aggiunge tre cose concrete:

1) **Contratto riproducibile**: `--dry-run --json` produce una ricevuta macchina con **il comando esatto** e i parametri effettivi.
2) **Hardening**: blocca opzioni pericolose, e con `--strict` **ignora config globali** (`--ignore-config`) e blocca `--config-location`.
3) **Modalità metadata**: `--print` / `--print-template` per ispezionare titolo/filename/id senza scaricare.

Se ti sembra “solo un wrapper”, prova a fare le stesse cose **in modo ripetibile** con `yt-dlp` nudo in CI e poi ne riparliamo.

---

## Installazione rapida
Dipendenze principali:
- `yt-dlp`
- `ffmpeg` (necessario per estrazione audio)

Strumenti utili:
- `jq` (per leggere JSON)

Esempio:
```bash
sudo apt install ffmpeg jq
pipx install yt-dlp   # oppure apt/snap/venv come preferisci
````

---

## Esempi intelligenti (per intenti)

### 1) Scaricare audio subito (modo umano)

**Voce / podcast (leggero)**

```bash
gyte-audio --preset voice --out ./audio URL
```

**Qualità alta**

```bash
gyte-audio --preset hq --out ./audio URL
```

**Lossless**

```bash
gyte-audio --preset lossless --out ./audio URL
```

Override manuale (vince sul preset):

```bash
gyte-audio --preset hq --format opus --quality 128K --out ./audio URL
```

---

### 2) “Dimmi cosa farai, senza scaricare niente” (debug riproducibile)

**Comando shell copiabile**

```bash
gyte-audio --dry-run URL
```

**Ricevuta JSON (pulita, adatta al piping)**

```bash
gyte-audio --dry-run --json --preset voice URL | jq .
```

**Estrarre solo il comando esatto**

```bash
gyte-audio --dry-run --json URL | jq -r '.yt_dlp_cmd_string'
```

**Estrarre solo formato/qualità effettivi**

```bash
gyte-audio --dry-run --json --preset hq URL | jq -r '.audio_format,.audio_quality'
```

---

### 3) Pipeline/CI (dove il JSON smette di sembrare “sbrodolata”)

**Fail se strict non è attivo**

```bash
gyte-audio --dry-run --json --strict URL | jq -e '.strict == true' >/dev/null
```

**Loggare preset/quality in modo stabile**

```bash
gyte-audio --dry-run --json --preset voice URL | jq -r '.preset,.audio_quality'
```

**Diff strutturato tra due run**

```bash
gyte-audio --dry-run --json --preset voice URL > /tmp/a.json
GYTE_AUDIO_QUALITY=192K gyte-audio --dry-run --json --preset voice URL > /tmp/b.json
diff -u <(jq -S . /tmp/a.json) <(jq -S . /tmp/b.json)
```

---

### 4) Naming & output (prima di scaricare)

**Vedere il filename previsto**

```bash
gyte-audio --no-warnings --print filename URL
```

**Vedere il filename previsto con directory di output**

```bash
gyte-audio --no-warnings --print filename --out ./audio URL
```

---

### 5) Metadata (senza download)

**Titolo**

```bash
gyte-audio --no-warnings --print title URL
```

**ID**

```bash
gyte-audio --no-warnings --print id URL
```

**Template libero (pipeline-friendly)**

```bash
gyte-audio --no-warnings --print-template '%(title)s [%(id)s]' URL
```

Playlist (opt-in) con template:

```bash
gyte-audio --no-warnings --playlist --print-template '%(title)s' PLAYLIST_URL
```

---

### 6) Sicurezza (perché non è “solo wrapper”)

**Blocca opzioni pericolose (esempio)**

```bash
gyte-audio URL --exec 'rm -rf ~'     # deve fallire: è voluto
```

**Strict: ignora config globali**

```bash
gyte-audio --strict --dry-run URL
# nel comando risultante vedrai: --ignore-config
```

**Strict: blocca aggiramenti**

```bash
gyte-audio --strict --dry-run URL --config-location /tmp/x
# deve fallire: è voluto
```

---

## Note operative

* `--playlist` è opt-in: di default `gyte-audio` non scarica playlist.
* `--no-warnings` è utile quando vuoi output 1-riga pulito (print/template) e piping.
* `--json` è pensato per tooling: per umani è più comodo `--dry-run` semplice.

---

## TL;DR (3 comandi da ricordare)

```bash
gyte-audio --preset voice --out ./audio URL
gyte-audio --no-warnings --print filename --out ./audio URL
gyte-audio --dry-run --json --strict URL | jq -r '.yt_dlp_cmd_string'
```

---

## Troubleshooting

### Warning SABR di YouTube
Messaggi tipo:
```
Some web client https formats have been skipped...
YouTube is forcing SABR streaming...
```

**Cosa significa:** è un warning noto di `yt-dlp` dovuto ai cambiamenti di YouTube.  
**Non è un errore** e il download/print funziona comunque.

**Soluzione (output pulito):**
```bash
gyte-audio --no-warnings ...
```

### “Perché non scarica tutta la playlist?”

Perché **le playlist sono opt-in** per scelta di sicurezza.

**Soluzione:**
```bash
gyte-audio --playlist PLAYLIST_URL
```

---

### “Il risultato è diverso sulla mia macchina”

Probabile interferenza di config globali (`~/.config/yt-dlp.conf`).

**Soluzione deterministica:**
```bash
gyte-audio --strict ...
```

`--strict`:
- usa `--ignore-config`
- blocca `--config-location`
- rende il comportamento riproducibile

---

### Opzioni yt-dlp rifiutate (exec, postprocessor, ecc.)

Se vedi errori tipo:
```
Opzione yt-dlp non consentita
```

**Motivo:** `gyte-audio` blocca opzioni che eseguono comandi o hook esterni
(`--exec`, `--postprocessor-args`, ecc.).

**Soluzione:**
- se ti servono davvero → usa `yt-dlp` direttamente
- se no → stai più sicuro così

---

### Voglio solo il metadata, senza scaricare nulla

Usa le modalità `--print` o `--print-template`.

Esempi:
```bash
gyte-audio --print title URL
gyte-audio --print filename --out ./audio URL
gyte-audio --print-template '%(title)s [%(id)s]' URL
```

---

### Output sporco quando uso `--json`

`--json` **attiva automaticamente il quiet**.

Se vedi rumore:
-* stai probabilmente usando una versione vecchia
- oppure stai catturando `stderr` insieme a `stdout`

Uso corretto:
```bash
gyte-audio --dry-run --json URL | jq .
```

---

### Debug completo (consigliato)

Quando qualcosa non torna, questo è il comando “verità”:

```bash
gyte-audio --dry-run --json --strict URL | jq .
```

Ti dice **esattamente**:
- quali opzioni sono attive
- che formato/qualità verranno usati
- qual è il comando `yt-dlp` reale
