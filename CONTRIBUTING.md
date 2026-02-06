# Contributing to GYTE

Grazie per l’interesse! GYTE accetta contributi su CLI, pipeline, provider, test e documentazione.

## Setup rapido (sviluppo)

Requisiti:
- Python (vedi `pyproject.toml`)
- `git`

Esempio di setup locale:

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -U pip
pip install -e ".[dev]"
```

### Quality gates (prima di aprire una PR)
GYTE usa CI con lint + test.

ruff check .
pytest

Se tocchi la CLI o i provider:
- aggiungi test quando sensato
- mantieni i comandi “umani” (UX prima della magia)

## Tipi di contributi benvenuti
- Bugfix riproducibili
- Nuovi provider / miglioramenti pipeline
- Test e CI
- Docs ed esempi CLI

## Linee guida
- PR piccole e focalizzate
- Niente credenziali, token o dati sensibili
- Mantieni separazione netta dei provider
- Aggiorna README se cambi API/CLI

## Licenza
Contribuendo accetti la licenza del progetto.
