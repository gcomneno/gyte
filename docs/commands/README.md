# GYTE — Command reference
Questa cartella contiene la documentazione **per singolo comando** `gyte-*`.

Regole di lettura rapide:
- **stdout**: output “consumabile” (pipeline).  
- **stderr**: log ed errori.

- Se uno script scrive su disco, lo fa sotto `out/` (o in un path esplicito passato via flag).

## Indice

### Core (workflow “digest → explain”)
- [`gyte-explain`](./gyte-explain.md) — dato un ID da TSV, genera artefatti in `out/<run>/items/<ID>/` + manifest.

### Spec / contratti
- [`manifest_v1`](../spec/manifest_v1.md) — contratto JSON per `out/<run>/manifest.json` e `out/<run>/items/<ID>/manifest.json`

## Note sul progetto
- La struttura generale del repo e i file principali sono descritti nella documentazione principale.
