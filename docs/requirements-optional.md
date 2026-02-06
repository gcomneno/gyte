# Optional dependencies
GYTE funziona con un set minimo di dipendenze. 
Alcune funzionalità richiedono tool/dipendenze opzionali.

## Install opzionali (Python)
Se vuoi abilitare extra opzionali:
```bash
pip install -r requirements-optional.txt
```

## Note
Mantieni le dipendenze opzionali fuori dal path “core” quando possibile.

Se un comando richiede una dipendenza opzionale, deve fallire con messaggio chiaro e suggerire come installarla.
