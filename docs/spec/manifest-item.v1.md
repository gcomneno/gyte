# GYTE Manifest Spec — ITEM (v1)
Questo documento definisce il formato JSON dell’ITEM manifest:
- Path: `out/<run>/items/<ID>/manifest.json`
- Deve essere scritto **sempre**, anche in caso di errore.
- È pensato come API stabile su filesystem (consumo da script/tools).

## Schema ID
- `schema`: `"gyte.manifest.item.v1"` (stringa fissa)

## Campi (obbligatori)

### Identità e configurazione
- `id` (string) — ID item, tipicamente `"001"` (3 cifre, padded)
- `title` (string) — titolo del video (come da TSV)
- `url` (string) — URL (normalizzato a youtube.com quando valido; altrimenti raw)
- `langs` (array di string) — lingue richieste (es. `["it","en"]`)
- `ai_mode` (string enum) — `"local" | "openai" | "whisper" | "off"`

### Provenienza contenuti
- `transcript_source` (string enum) — `"subs" | "whisper" | "none"`
- `summary_source` (string enum) — `"local" | "openai" | "none"`

### Stato
- `status` (string enum) — `"ok" | "no_transcript" | "invalid_url" | "error"`
- `error_message` (string|null) — messaggio breve; `null` se non presente

### Paths (relativi alla directory ITEM)
- `paths` (object, string->string)
  - `title`: `"title.txt"`
  - `url`: `"url.txt"`
  - `langs`: `"langs.txt"`
  - `row_tsv`: `"row.tsv"`
  - `transcript`: `"transcript.txt"`
  - `summary`: `"summary.txt"`
  - `transcript_error`: `"transcript_error.txt"`

### Timestamp
- `timestamps` (object)
  - `created` (string ISO-8601, timezone aware)
  - `updated` (string ISO-8601, timezone aware)

### Meta
- `meta` (object)
  - `exists` (object, string->bool) — presenza reale dei file (best-effort)
  - `reflowed_transcript` (bool)
  - `stdout_summary_emitted` (bool)
  - `inputs.tsv_row_present` (bool)

## Regole di coerenza (soft)
Queste regole sono consigliate per validatori; non devono bloccare l’esecuzione.

- Se `status == "ok"`:
  - `transcript_source != "none"`
  - `paths.transcript` dovrebbe esistere (`meta.exists.transcript == true`)
- Se `status == "invalid_url"`:
  - `transcript_source == "none"`
  - `summary_source == "none"`
  - `error_message` dovrebbe essere una stringa non vuota
- Se `status == "no_transcript"`:
  - `transcript_source == "none"`
  - `summary_source == "none"`
  - `error_message` tipicamente `null`
- Se `ai_mode == "off"`:
  - `summary_source == "none"`

## Esempio minimale (ok)
```json
{
  "schema": "gyte.manifest.item.v1",
  "id": "001",
  "title": "Example",
  "url": "https://www.youtube.com/watch?v=abc123",
  "langs": ["it", "en"],
  "ai_mode": "local",
  "transcript_source": "subs",
  "summary_source": "local",
  "status": "ok",
  "error_message": null,
  "paths": {
    "title": "title.txt",
    "url": "url.txt",
    "langs": "langs.txt",
    "row_tsv": "row.tsv",
    "transcript": "transcript.txt",
    "summary": "summary.txt",
    "transcript_error": "transcript_error.txt"
  },
  "timestamps": {
    "created": "2026-02-03T13:45:00+01:00",
    "updated": "2026-02-03T13:45:10+01:00"
  },
  "meta": {
    "exists": {
      "title": true,
      "url": true,
      "langs": true,
      "row_tsv": true,
      "transcript": true,
      "summary": true,
      "transcript_error": false
    },
    "reflowed_transcript": true,
    "stdout_summary_emitted": true,
    "inputs": {"tsv_row_present": true}
  }
}
