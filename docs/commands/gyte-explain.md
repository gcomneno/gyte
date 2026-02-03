# gyte-explain

## Scopo
`gyte-explain` prende un **ID** (da un TSV tipo quello prodotto da `gyte-digest`) e genera, sotto `out/<run>/`, un set di artefatti per quell’item:
- file “atomici” (`title.txt`, `url.txt`, `langs.txt`, `row.tsv`)
- `transcript.txt` (reflowed se possibile, altrimenti raw “promosso”)
- `summary.txt` (opzionale; default: estrattivo locale)
- `transcript_error.txt` in caso di problemi
- **manifest** sempre scritto:
  - `out/<run>/manifest.json`
  - `out/<run>/items/<ID>/manifest.json`

Il filesystem sotto `out/` è una **API implicita**: non cambiare nomi/path a caso.

## Uso
```bash
gyte-explain ID [opzioni]
```

Dove ID è l’identificatore dell’item nel TSV (es. 1, 001, 0001 — viene normalizzato internamente).

## Input TSV
Default: input interno del tool (o percorso configurato dal progetto).

Puoi forzare un TSV via --in FILE.

Il TSV atteso è tab-separated con colonne:
id<TAB>title<TAB>url

Gestione robusta:
- CRLF ok
- \t letterale normalizzato
- ID non padded accettati (vengono normalizzati)
- URL youtu.be/... accettati (vengono normalizzati)

## Opzioni principali

```sh
--in FILE
TSV sorgente.

--ai local|openai|whisper|off
Se e come usare AI. Filosofia: niente magia.

local: summary estrattivo locale (Python stdlib). Default tipico.

openai: summary via provider esterno (se configurato).

whisper: usa trascrizione locale solo se esplicitamente richiesto.

off: niente summary.

--langs it,en
Lingue preferite per cercare sottotitoli.

--run DIR
Imposta una run folder deterministica. Clobber consentito solo sotto items/<ID>.

(eventuale) --out-base DIR
Base folder per out/ (utile per test/smoke/CI).
```

## Output
stdout / stderr

stdout: contiene solo il summary (se prodotto).
In caso di errore o di summary disabilitato → stdout vuoto.

stderr: log e messaggi d’errore.

## Exit code tipici:
0 → ok
2 → input invalido / URL non YouTube / errore “di uso”
3 → nessun transcript disponibile (no_transcript)

(altri) → errori runtime

Gli exit code precisi sono parte della compatibilità: non vanno “ottimizzati” senza motivo.

## Artefatti su disco
Root run:
```sh
out/<run>/
  manifest.json
  items/
    <ID>/
      manifest.json
      title.txt
      url.txt
      langs.txt
      row.tsv
      transcript.txt               (se presente)
      summary.txt                  (se presente)
      transcript_error.txt         (se error/no transcript/invalid url)
```

Il manifest dichiara sempre:
- status finale (ok, invalid_url, no_transcript, error)
- sorgenti (transcript_source, summary_source)
- path relativi agli artefatti

Per i dettagli del formato JSON: vedi spec manifest_v1.
→ docs/spec/manifest_v1.md

## Esempi
Caso OK (transcript da subs + summary locale)
ID=001
gyte-explain "$ID" --ai local > /tmp/gyte_stdout.txt 2> /tmp/gyte_stderr.txt

### stdout deve contenere summary (se prodotto)
head -n 5 /tmp/gyte_stdout.txt

### trova l’ultimo run
RUN="$(ls -1dt ./out/gyte-explain-* | head -n 1)"
ITEM="$RUN/items/$(printf "%03d" "$ID")"

test -f "$RUN/manifest.json"
test -f "$ITEM/manifest.json"
test -f "$ITEM/transcript.txt"
test -f "$ITEM/summary.txt"

### Caso invalid_url (manifest sempre scritto)
cat > /tmp/gyte_bad.tsv <<'TSV'
1	Video finto	https://example.com/not-youtube
TSV

gyte-explain 1 --in /tmp/gyte_bad.tsv --ai off > /tmp/out.txt 2> /tmp/err.txt || true

### Verifica:
RUN="$(ls -1dt ./out/gyte-explain-* | head -n 1)"
ITEM="$RUN/items/001"

test -f "$RUN/manifest.json"
test -f "$ITEM/manifest.json"
test -f "$ITEM/transcript_error.txt"

### Troubleshooting
“invalid_url”: l’URL non è YouTube/outu.be o è malformata.
“no_transcript”: nessun subtitle disponibile per le lingue richieste (e whisper non attivo).
Manifest presente ma artefatti mancanti: in caso di errore, il manifest può indicare path “previsti” ma non creati. Il campo exists (se presente) descrive cosa è stato effettivamente scritto.
Whisper: è opzionale e “pesante”; va attivato solo con --ai whisper.
