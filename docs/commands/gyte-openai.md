# gyte-openai
Comandi della famiglia `gyte-openai*` per interagire con modelli OpenAI all’interno delle pipeline GYTE, mantenendo tracciabilità tramite manifest v1.

I wrapper principali sono:
- `gyte-openai`
- `gyte-openai-digest`

- eventuali alias compatibili (`gyte-ai-openai`, se presenti)

---

## Scopo
`gyte-openai` consente di:
- inviare contenuti testuali a un modello OpenAI
- ricevere output strutturato o testuale
- integrare il risultato nel **manifest v1** (run + item)
- mantenere una pipeline CLI riproducibile ed utilizzabile tramite "scripting"

Non è un tool interattivo: è pensato per automazioni e batch.

---

## Requisiti
- Sistema: Linux (testato su Ubuntu)
- Bash: `bash >= 4`
- Connettività Internet
- Una chiave API OpenAI valida

Dipendenze runtime:
- `curl`
- `jq`

---

## Variabili d’ambiente
Le seguenti variabili sono lette dai comandi `gyte-openai*`:

| Variabile                 | Descrizione                                       |
|---------------------------|---------------------------------------------------|
| `OPENAI_API_KEY`          | **Obbligatoria.** Chiave API OpenAI               |
| `GYTE_OPENAI_MODEL`       | Modello da usare (default consigliato nel codice) |
| `GYTE_OPENAI_TEMPERATURE` | Temperatura di generazione (se supportata)        |
| `GYTE_OPENAI_MAX_TOKENS`  | Limite massimo token in output                    |
| `GYTE_OPENAI_TIMEOUT`     | Timeout richieste HTTP                            |

Esempio:
```bash
export OPENAI_API_KEY="sk-xxxx"
export GYTE_OPENAI_MODEL="gpt-4o-mini"
```

Nota: evita di versionare o loggare queste variabili.

## Uso base
```bash
gyte-openai --help
```

### Esempio minimale:
echo "Riassumi questo testo" | gyte-openai

### Il comando:
- legge input da stdin
- invia il prompt al modello
- stampa l’output su stdout
- ritorna exit code ≠ 0 in caso di errore

---

# gyte-openai-digest
gyte-openai-digest è pensato per:
- riassunti
- estrazione concetti chiave
- output più corti e normalizzati

## Esempio:
cat articolo.txt | gyte-openai-digest

## Integrazione con il manifest v1
Quando invocato in una pipeline GYTE completa, gyte-openai:
- legge i metadati del run
- aggiunge un item relativo alla chiamata OpenAI
- registra modello, parametri e stato

## Struttura minimale (estratto):
```json
{
  "run": {
    "tool": "gyte-openai",
    "status": "ok"
  },
  "items": [
    {
      "type": "openai",
      "model": "gpt-4o-mini",
      "result": "..."
    }
  ]
}
```

Vedi `docs/spec/manifest-v1.md` per i dettagli completi.

## Privacy e controllo costi

⚠️ Attenzione:
tutto ciò che invii viene mandato a un servizio esterno, per cui evita input con dati sensibili!

Buone pratiche:
- usa gyte-digest o gyte-reflow-text prima di OpenAI
- limita MAX_TOKENS
- testa prima con input ridotti
- evita loop automatici senza controllo

## Troubleshooting rapido

### Errore: chiave mancante
OPENAI_API_KEY not set
→ esporta la variabile d’ambiente.

### Timeout
→ riduci input o aumenta GYTE_OPENAI_TIMEOUT.

### Rate limit
→ rallenta le chiamate o batcha i contenuti.

## Esempi di workflow

### Esempio 1 — Riassunto controllato
```bash
cat note.txt \
  | gyte-reflow-text \
  | gyte-openai-digest \
  > summary.txt
```

### Esempio 2 — Pipeline con manifest
```bash
gyte-explain input.txt \
  | gyte-openai \
  | gyte-merge-pl output.json
```

## Riferimenti
`docs/spec/manifest-v1.md`
`docs/commands/gyte-explain.md`
`tests/smoke.sh`
