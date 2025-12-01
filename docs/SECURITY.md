# **CHECKLIST-SECURE-SCRIPTS.md**
*(versione 1.0 — GYTE Secure Scripting Guidelines)*

Questa checklist serve a garantire che **ogni script Bash/Python del progetto GYTE** rispetti le regole minime di sicurezza per prevenire attacchi tipici sulla supply chain (arg injection, exec imprevisti, leak di segreti, file malevoli, ecc.).

---

## ✅ 1. Struttura di base obbligatoria (Bash)

Ogni script deve avere:

* `#!/usr/bin/env bash`
* `set -euo pipefail`
* gestione `-h` / `--help`
* errori stampati su `stderr`

Esempio:

```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
    usage
    exit 0
fi
```

---

## ✅ 2. Validazione degli input

### URL

* deve iniziare con `http://` o `https://`
* **mai** accettare URL che iniziano con `-`
  (inietterebbero opzioni in yt-dlp)

### File input

* `-f` prima di usarli
* niente path traversal ciechi (`../../qualcosa` → ok, ma *consapevole*)

### Lingue e formati

* rimuovere spazi: `var="${var//[[:space:]]/}"`

---

## ✅ 3. Sanitizzazione argomenti passati a yt-dlp

**MAI** inoltrare opzioni che eseguono comandi:

* `--exec`
* `--exec-before-download`
* `--exec-after-download`
* `--postprocessor-args`
* `--run-postprocessor`

Se presenti → errore e stop.

---

## ✅ 4. Sicurezza ambientale (env vars)

Gli script **non devono mostrare**:

* valori contenenti key,
* comandi completi che contengono token,
* contenuti di variabili come `OPENAI_API_KEY`.

Corretto:

```
GYTE_AI_CMD = openai-wrapper (via env)
```

NON corretto:

```
GYTE_AI_CMD = openai-wrapper --api-key=sk-...
```

---

## ✅ 5. Limiti opzionali di sicurezza

Quando opportuno (come in `gyte-translate`):

* `GYTE_AI_MAX_INPUT_BYTES` → previene input giganteschi da errori o abusi.

---

## ✅ 6. Dipendenze esterne

Ogni comando esterno deve essere verificato:

```bash
command -v yt-dlp >/dev/null || errore
command -v ffmpeg >/dev/null || warn
```

---

## ✅ 7. Output files: regole sane

* creare file *solo* volutamente (no autocreate in path sconosciuti)
* evitare sovrascritture non intenzionali:
  → uso di `mktemp` per output temporanei
* rimuovere file temporanei anche in caso di errore

---

## ✅ 8. Python wrapper: hardening minimo

* niente stampa accidentale di API key
* cattura eccezioni sulle API
* validazione argomenti
* messaggi di errore chiari
* input da `stdin` obbligatoriamente validato (`strip()` → non vuoto)

---

## ✅ 9. Policy per plugin/estensioni future

Ogni nuovo script deve rispettare:

* **NON** accettare mai comandi arbitrari passati dall’utente da eseguire
* **NON** usare `eval`
* **NON** usare parsing fragile tipo `for f in $(ls)`
  (sempre array, sempre quoting)

---

## ✅ 10. CI: requisiti minimi

Ogni script deve:

* passare ShellCheck
* evitare SC2086, SC2046, SC2001, SC2162, SC2164
* non contenere pattern pericolosi come `curl | sh`
* non contenere download da domini hardcoded “morti”

---

## 📌 Footer

Gli script GYTE seguono una filosofia semplice:

**“Sicuri per default, flessibili solo dove serve, mai pericolosi per sbaglio.”**

Se qualcosa può essere abusato, *prima o poi lo sarà*.
Per questo la pipeline accetta solo script **idempotenti, trasparenti e confinati**.
