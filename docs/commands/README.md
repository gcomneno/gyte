# GYTE — Command reference
Questa cartella contiene la documentazione **per singolo comando** `gyte-*`.

Regole di lettura rapide:
- **stdout**: output “consumabile” (pipeline).  
- **stderr**: log ed errori.
- Se uno script scrive su disco, lo fa sotto `out/` (o in un path esplicito passato via flag).

## Indice

### Core (workflow “digest → explain”)
- [`gyte-digest`](./gyte-digest.md) — genera un TSV dal feed YouTube Subscriptions.
- [`gyte-explain`](./gyte-explain.md) — dato un ID da TSV, genera artefatti in `out/<run>/items/<ID>/` + manifest.

### Guard-rail / qualità
- [`gyte-lint`](./gyte-lint.md) — shellcheck + validatore manifest.

### Optional (dipendenze pesanti)
- [`gyte-whisper-local`](./gyte-whisper-local.md) — trascrizione locale opt-in (usata solo se richiesta).

### Spec / contratti
- [`manifest_v1`](../spec/manifest_v1.md) — contratto JSON per `out/<run>/manifest.json` e `out/<run>/items/<ID>/manifest.json`

## Note sul progetto
- La struttura generale del repo e i file principali sono descritti nella documentazione storica. :contentReference[oaicite:0]{index=0}
- La postura “secure-by-default” e le regole di scripting sicuro restano valide. :contentReference[oaicite:1]{index=1} :contentReference[oaicite:2]{index=2}
