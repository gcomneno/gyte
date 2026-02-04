# Changelog — GYTE
Questo documento traccia l’evoluzione storica del progetto GYTE.

Il versionamento segue **Semantic Versioning (SemVer)**.

Formato:
- MAJOR: cambiamenti incompatibili
- MINOR: nuove funzionalità compatibili
- PATCH: fix e miglioramenti interni

---

## v1.2.0 — 2026-02-03

### Highlights
- Release stabile e consolidata del toolchain GYTE.
- Packaging locale in `~/.local/bin` tramite wrapper dedicati.
- Supporto robusto a esecuzione via symlink.

### Fixed
- Risoluzione corretta del path dei wrapper `bin/gyte-*` anche se invocati tramite symlink.
- Exit code e comportamento invariati rispetto alle versioni precedenti.

### CI & Testing
- CI deterministica su push/PR.
- Smoke test offline (`tests/smoke.sh`) riproducibile.

### Documentation
- README aggiornato con quickstart.
- Documentazione comandi in `docs/commands/`.
- Specifica formale del manifest v1 in `docs/spec/`.

---

## v1.1.0

### Notes
- Versione intermedia con miglioramenti strutturali e di documentazione.
- Non considerata milestone stabile principale.

---

## v1.0.0

### Notes
- Prima release funzionale del progetto.
- Struttura base dei comandi GYTE e pipeline CLI.

---

## Policy note

I tag storici non vengono riscritti retroattivamente.
Le nuove release avanzano in modo incrementale per garantire:
- tracciabilità
- compatibilità CI
- riproducibilità delle pipeline
