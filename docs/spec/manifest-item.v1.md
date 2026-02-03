# GYTE manifest v1
Questa spec descrive il **contratto** dei manifest prodotti da `gyte-explain`.

Obiettivo:
- rendere l’output filesystem consumabile da script esterni (bash/python)
- avere uno stato macchina-leggibile anche in caso di errore
- zero dipendenze esterne: JSON scritto con shell + python stdlib

I manifest sono **sempre** scritti, anche in caso di errore.

Percorsi:
- Run: `out/<run>/manifest.json`
- Item: `out/<run>/items/<ID>/manifest.json`

## Convenzioni
- Tutti i path in `paths.*` sono **relativi** alla cartella item: `out/<run>/items/<ID>/`
- Timestamp in formato ISO-8601 (UTC o local time esplicitato dal producer)
- Campi sconosciuti possono essere aggiunti in futuro: i consumer devono ignorarli.

Valori enum (v1):
- `status`: `ok | no_transcript | invalid_url | error`
- `transcript_source`: `subs | whisper | none`
- `summary_source`: `local | openai | none`
- `ai_mode`: `local | openai | whisper | off`

## Item manifest (minimo garantito)
Esempio schematico:
```json
{
  "id": "001",
  "title": "…",
  "url": "https://www.youtube.com/watch?v=…",
  "langs": ["it","en"],
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
    "transcript_error": null
  },

  "timestamps": {
    "created_at": "2026-02-03T12:43:00+01:00",
    "updated_at": "2026-02-03T12:43:02+01:00"
  },

  "meta": {
    "gyte_version": "vX.Y.Z",
    "producer": "gyte-explain"
  }
}
```

## Campi richiesti
id (string): ID normalizzato (tipicamente 001)
title (string): titolo (anche se parziale o “best effort”)
url (string): URL normalizzata
langs (array<string>): lingue richieste / risolte
ai_mode (string enum): modalità richiesta
transcript_source (enum): subs|whisper|none
summary_source (enum): local|openai|none
status (enum): ok|no_transcript|invalid_url|error
error_message (string|null): messaggio umano; può essere null (non bloccare il consumer)
paths (object): path relativi, valori string o null
timestamps (object): almeno created_at
meta (object): almeno producer; gyte_version consigliato

## Semantica status
ok  
Transcript presente e (se attivo) summary prodotto.

invalid_url
URL non valida (non YouTube / malformata). In genere:

transcript_source = none

summary_source = none

paths.transcript_error = "transcript_error.txt"

no_transcript
Nessun subtitle trovato e whisper non usato. In genere:

transcript_source = none

paths.transcript_error = "transcript_error.txt"

error
Errore runtime non classificato (es. failure tool esterno). error_message dovrebbe spiegare.

## Run manifest
Scopo: descrivere “questa run” e gli item processati.

Schematicamente:
```json
{
  "run": {
    "id": "gyte-explain-20260203-124339",
    "status": "ok",
    "started_at": "2026-02-03T12:43:00+01:00",
    "ended_at": "2026-02-03T12:43:02+01:00",
    "out_dir": "."
  },
  "config": {
    "argv": ["gyte-explain", "001", "--ai", "local"],
    "ai_mode": "local",
    "langs": ["it","en"]
  },
  "counts": {
    "items_total": 1,
    "ok": 1,
    "invalid_url": 0,
    "no_transcript": 0,
    "error": 0
  },
  "items": {
    "001": {
      "status": "ok",
      "item_dir": "items/001"
    }
  },
  "meta": {
    "gyte_version": "vX.Y.Z",
    "producer": "gyte-explain"
  }
}
```

## Note
items può contenere un sottoinsieme di campi; l’item manifest è la fonte completa.

run.status può essere:
- ok se tutti gli item sono ok
- error se almeno uno è invalid_url|no_transcript|error (policy a scelta del producer)

## Compatibilità / evoluzione
v1 è “append-only”: possiamo aggiungere campi senza rompere i consumer.

Se un consumer vuole essere robusto:
- non assumere che error_message sia sempre stringa non-vuota
- non assumere che tutti i file in paths.* esistano davvero: verificare su filesystem
