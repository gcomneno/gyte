# gyte-digest

## Scopo
`gyte-digest` genera una mini “rassegna” dal feed **YouTube Subscriptions** usando i cookies del browser.

Produce un TSV con colonne:
#id<TAB>title<TAB>url
001<TAB>...<TAB>https://www.youtube.com/watch?v=...

Questo TSV è pensato per essere consumato da `gyte-explain`.

## Uso

```bash
gyte-digest [--scan N] [--browser NAME] [--out FILE] [--pretty] [--verbose]
```

### Opzioni
--scan N
Quanti video prendere dal feed (default tipico: 8).
Viene sanificato: min 1, max 200.

--browser NAME
Browser per yt-dlp --cookies-from-browser (es. firefox, chrome, chromium, brave...).

--out FILE
Path del TSV salvato su disco (default: ./in/urls.tsv).
La directory viene creata se manca.

--pretty
Stampa su stdout una tabella “carina” (colonne fisse, troncamento, larghezze auto via tput cols).
Nota: il TSV viene comunque salvato in --out.

--verbose
Log su stderr.

-h, --help
Help.

## Input
Nessun input esterno: legge direttamente il feed:
https://www.youtube.com/feed/subscriptions

## Output
File su disco
Scrive sempre un TSV su --out (default ./in/urls.tsv).

## stdout / stderr
Se NON usi --pretty: stampa su stdout il contenuto del TSV (incluso header commentato).
Se usi --pretty: stdout contiene la tabella formattata; il TSV resta in --out.

stderr contiene log solo con --verbose oppure messaggi d’errore.

## Exit code
0: ok
1: errore runtime (tipicamente yt-dlp fallito, feed non leggibile, parsing non produce item)

## Dettagli di parsing (importanti)
- normalizza \t letterale in TAB reale
- rimuove CR (\r)
- scarta shorts
- accetta youtube.com/watch?v=... e youtu.be/...
- assegna ID progressivi con padding a 3 cifre (001, 002, ...)

## Esempi
Generare TSV standard
gyte-digest > /tmp/urls.tsv
head -n 5 /tmp/urls.tsv

Salvare in un file specifico
gyte-digest --scan 20 --out ./in/mia_rassegna.tsv

Output “pretty” (solo visuale)
gyte-digest --scan 12 --pretty

Passaggio a gyte-explain
gyte-digest --out ./in/urls.tsv
gyte-explain 001 --in ./in/urls.tsv --ai local

## Troubleshooting
yt-dlp non legge il feed: controlla che il browser sia loggato su YouTube e che --cookies-from-browser funzioni.
TSV vuoto: feed vuoto o parsing che ha scartato tutto (es. solo shorts).
pretty widths strane: tput cols non disponibile o terminale non standard; usa output TSV normale.
