# gyte-lint

## Scopo
`gyte-lint` è il guard-rail del repo:
1) esegue **shellcheck** sugli script `scripts/gyte-*`
2) valida i **manifest** generati da `gyte-explain` (modalità `--manifest`)

È pensato per uso locale e CI.

## Uso
```bash
gyte-lint
gyte-lint --manifest [RUN_DIR]
```

## Modalità
1) Shellcheck (default)
gyte-lint
Cerca gli script scripts/gyte-*
Considera “shell script” quelli con shebang compatibile
Esegue shellcheck su quelli trovati

stdout/stderr: tipicamente stampa l’elenco file e gli eventuali warning/error.

## Exit code:
0 ok
1 warning/error shellcheck (o problemi simili)

2) Manifest validation
gyte-lint --manifest
gyte-lint --manifest out/gyte-explain-YYYYMMDD-HHMMSS

Se RUN_DIR è omesso, di solito prende la “last run” sotto ./out/ (policy tool-specific).

## Verifica:
- esistenza manifest.json di run
- esistenza items/<ID>/manifest.json
- campi minimi / enum / tipi base
- coerenza minima tra status e paths

## Cosa non fa:
- non verifica che i transcript siano “giusti”
- non garantisce che YouTube sia accessibile
- non fa test rete

## Exit code:
0 ok
1 manifest invalidi / campi mancanti / incoerenze

## Esempi
Locale: controllo veloce
./scripts/gyte-lint

Validare l’ultima run
./scripts/gyte-lint --manifest

Validare una run specifica
RUN="./out/gyte-explain-20260203-124339"
./scripts/gyte-lint --manifest "$RUN"

## Troubleshooting
- shellcheck not found: installa shellcheck (su Ubuntu: sudo apt-get install shellcheck).
- manifest missing: stai puntando alla run sbagliata o gyte-explain non è arrivato a scrivere manifest.json.
- manifest “ok” ma file mancanti: può succedere in error path; il consumer deve verificare i file sul filesystem.
