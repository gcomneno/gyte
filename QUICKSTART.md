# GYTE

**GYTE** è una collezione di strumenti CLI per costruire una rassegna ragionata di contenuti YouTube e trasformarla in **artefatti locali, riproducibili e/o automatizzabili**.

Filosofia chiave:
- strumenti semplici, shell-first
- **stdout per dati**, **stderr per log**
- output su filesystem come **API implicita**
- zero dipendenze inutili

---

## Quickstart

1) Genera una rassegna (TSV)
```bash
gyte-digest
```

2) Analizza un item (senza IA)
```bash
gyte-explain 001 --ai local
```

3) Esplora l’output generato
```bash
ls out/
ls out/<run>/items/001/
```

Troverai:
- transcript.txt
- summary.txt (se attivo)
- manifest.json (sempre presente)

## Struttura dell’output
Ogni esecuzione di gyte-explain crea una run directory:
```json
out/<run>/
  manifest.json
  items/
    <ID>/
      manifest.json
      title.txt
      url.txt
      langs.txt
      row.tsv
      transcript.txt
      summary.txt
```

Il filesystem sotto `out/` è pensato per essere consumato da script esterni (Bash, Python, ecc..).

## Documentazione

### Command reference (consigliato)
`docs/commands/` — documentazione per ogno singolo comando

```text
gyte-digest
gyte-explain
gyte-lint
gyte-whisper-local
```

## Specifiche
`docs/spec/manifest_v1.md` — contratto JSON dei manifest

## Documentazione di progetto
`docs/CHANGELOG.md`
`docs/SECURITY.md`
`docs/THREAT_MODEL.md`

## Installazione
Metodo consigliato:
```bash
./bin/gyte-install
```

In alternativa, puoi usare i comandi direttamente da repo (scripts/ o bin/).

## Qualità e sicurezza
- Lint automatico: gyte-lint
- Validazione output: gyte-lint --manifest
- CI deterministica (no rete obbligatoria)
- Dipendenze AI opzionali e isolate

## Licenza
Vedi `LICENSE`.
