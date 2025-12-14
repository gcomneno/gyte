# THREAT MODEL – GYTE (GiadaWare YouTube Toolkit Extractor)
Versione: 1.0  
Scope: tool CLI per scaricare transcript / audio / video da YouTube e tradurli usando provider AI esterni.

---

## 1. Contesto e scopo

GYTE è una raccolta di script CLI (Bash + Python) che:

- usano `yt-dlp` per:
  - scaricare sottotitoli (`gyte-transcript`, `gyte-transcript-pl`),
  - estrarre audio (`gyte-audio`),
  - scaricare video (`gyte-video`);
- elaborano testi (`gyte-reflow-text`, `gyte-merge-pl`);
- delegano la traduzione a un **comando AI esterno** configurato via `GYTE_AI_CMD` (`gyte-translate`, `gyte-openai`).

Non è un servizio multi-tenant, ma uno strumento usato su macchine personali/server di fiducia.  
L’obiettivo del threat model è **ridurre i rischi ragionevoli** per:

- l’utente che esegue GYTE,
- la sua macchina/ambiente (file, credenziali, token),
- il flusso CI/CD del repo.

---

## 2. Asset da proteggere

1. **Ambiente locale dell’utente**
   - File personali nella stessa macchina.
   - Shell / PATH / permessi utente.
2. **Credenziali e segreti**
   - API key dei provider AI (`OPENAI_API_KEY`, ecc.).
   - Token di autenticazione usati da wrapper esterni (mai gestiti direttamente da GYTE, ma comunque presenti nell’ambiente).
3. **Integrità del codice GYTE**
   - Script Bash e Python nel repo.
   - Workflow CI.
4. **Integrità dei contenuti generati**
   - Transcript, audio, video, file Markdown.
   - File di traduzione (es. `*.en.txt`, `*.en.md`).

---

## 3. Attori

### 3.1 Attori legittimi

- **Utente CLI**: esegue GYTE su macchina personale o server controllato.
- **Maintainer del repo**: aggiorna codice, CI, dipendenze.

### 3.2 Potenziali attaccanti

- **Pacchetto malevolo nella supply chain**
  - Dependence Python (es. `openai`, `yt-dlp`, tool extra).
  - Action GitHub malevola o compromessa.
- **Input ostile**
  - URL YouTube costruite ad arte per rompere i wrapper.
  - File di testo “malformati” (HTML strano, caratteri edge, ecc.).
- **Ambiente utente compromesso**
  - Variabili d’ambiente con comandi/chiavi mescolati.
  - Config `yt-dlp` (`common.conf`, `profile-transcript.conf`) non sicuri ma già presenti sul sistema.

---

## 4. Ingressi / Superfici di attacco

1. **CLI / argv**
   - URL YouTube, percorsi file, opzioni aggiuntive passate agli script.
2. **Variabili d’ambiente**
   - `GYTE_AI_CMD`, `OPENAI_API_KEY`, `YT_TRANSCRIPT_LANGS`, `GYTE_AUDIO_FORMAT`, ecc.
3. **File locali**
   - Input text/markdown.
   - File `.vtt` scaricati da `yt-dlp`.
4. **Dipendenze esterne**
   - `yt-dlp`, `ffmpeg`, `openai` (libreria Python).
5. **CI/CD**
   - Workflow GitHub Actions.
   - Dependabot.

---

## 5. Threat principali (GYTE-specific)

### T1 – Abuso delle opzioni pericolose di `yt-dlp`

**Descrizione:**  
Un utente (o uno script esterno) prova a usare GYTE per eseguire comandi aggiuntivi tramite opzioni yt-dlp (es. `--exec`, `--postprocessor-args`, ecc.), trasformando GYTE in un wrapper per comandi arbitrari.

**Impatto:**  
Esecuzione di comandi shell non previsti → possibile compromissione della macchina.

**Mitigazioni attuali:**

- `gyte-audio`, `gyte-video`, `gyte-transcript`:
  - parsing degli argomenti extra e creazione di `safe_args` / `safe_extra_args`;
  - blocco esplicito di:
    - `--exec`, `--exec-*`,
    - `--exec-before-download`, `--exec-after-download`,
    - `--run-postprocessor`, `--postprocessor-args`.
- URL validate:
  - deve iniziare con `http://` o `https://`;
  - non può iniziare con `-` (niente injection via “URL”).

**Residual risk:**  
Basso, limitato a nuove opzioni yt-dlp future non ancora filtrate.

---

### T2 – Uso pericoloso di `GYTE_AI_CMD` (wrapper AI)

**Descrizione:**  
`GYTE_AI_CMD` è un comando arbitrario eseguito come:

```bash
SRC_LANG=... TARGET_LANG=... bash -c "$GYTE_AI_CMD"
````

Se l’utente mette dentro chiavi o comandi troppo “grezzi”, può:

* loggare segreti,
* costruire pipeline pericolose.

**Impatto:**
Leak di segreti, comandi involontariamente pericolosi.

**Mitigazioni attuali:**

* `gyte-translate`:

  * non stampa mai il contenuto completo di `GYTE_AI_CMD` → mostra solo il “nome” (primo token);
  * permette un limite opzionale `GYTE_AI_MAX_INPUT_BYTES` per evitare input enormi non voluti;
  * valida input file e lingue.
* `gyte-openai`:

  * legge `OPENAI_API_KEY` solo da env;
  * rifiuta placeholder tipo `sk-...`, `YOUR_API_KEY_HERE`;
  * non stampa mai la chiave;
  * limite sulla dimensione dell’input (`GYTE_AI_MAX_INPUT_CHARS`).

**Residual risk:**
Medio (il wrapper AI resta responsabilità dell’utente), ma GYTE non amplifica il problema.

---

### T3 – Input e file eccessivi (DoS / costi imprevisti)

**Descrizione:**
Transcript o file enormi passati al provider AI → richiesta costosa, errori lato API, eventuali timeouts.

**Impatto:**
Costi imprevisti su API, blocchi temporanei, UX pessima.

**Mitigazioni attuali:**

* `gyte-openai`:

  * `GYTE_AI_MAX_INPUT_CHARS` con default ragionevole.
* `gyte-translate`:

  * `GYTE_AI_MAX_INPUT_BYTES` opzionale;
  * fail-fast se il file supera il limite.

**Residual risk:**
Controllato: l’utente può comunque alzare il limite *consapevolmente*.

---

### T4 – Script usati come “shim” per ambiente fragile

**Descrizione:**
GYTE viene eseguito in ambienti dove:

* `yt-dlp` è stato sostituito con un binario malevolo,
* file `.conf` di `yt-dlp` contengono opzioni pericolose.

**Impatto:**
GYTE diventa “vettore” di strumenti già compromessi.

**Mitigazioni attuali:**

* `gyte-doctor`:

  * verifica presenza/versions di `yt-dlp` e `ffmpeg`;
* Script wrapper:

  * non aggiungono mai `curl | sh` o download di ulteriori script;
  * non eseguono codice remoto non versionato.

**Residual risk:**
GYTE non può “disinfettare” un sistema già compromesso.
Il rischio resta *a carico dell’ambiente*, non del codice GYTE.

---

### T5 – Rischi nel CI / supply chain

**Descrizione:**

* Action GitHub malevola o modificata,
* dipendenze Python con CVE gravi.

**Impatto:**
Compromissione del repo, leak di token CI, modifiche subdole.

**Mitigazioni attuali:**

* CI GitHub:

  * `permissions: contents: read` (token con permessi minimi);
  * action ufficiali pin-ate (`actions/checkout@v4`, `actions/setup-python@v5`);
  * controlli:

    * ShellCheck sugli script,
    * `pip-audit` (soft-mode),
    * `bandit` (soft-mode).
* Dependabot:

  * attivo su:

    * GitHub Actions,
    * dipendenze Python (requirements opzionali).

**Residual risk:**
Basso per questo tipo di progetto; residuo legato a nuovi CVE e a compromissione a livello di piattaforma (GitHub).

---

## 6. Decisioni di design “security by default”

1. **Divieto di esecuzione comandi tramite yt-dlp**

   * Gli script GYTE non esporranno mai opzioni `--exec*` come “feature”.
2. **Segreti SOLO via env**

   * Nessun supporto a chiavi via CLI o file.
3. **Modalità “wrapper AI generico”**

   * GYTE non integra provider specifici nel core, ma li delega a `GYTE_AI_CMD`/wrapper dedicati.
4. **Fail-fast sugli errori critici**

   * Mancanza di `yt-dlp`, `ffmpeg`, chiave API, file input → errore immediato e chiaro.
5. **Nessun `curl | sh` o script remoto “magico”**

   * L’installazione resta documentata, non automatizzata con comandi non ispezionabili.

---

## 7. Miglioramenti futuri (nice-to-have)

* Aggiungere una **modalità “–dry-run”** più ampia per tutti gli script principali (dove ha senso).
* Introdurre un semplice `gyte doctor --security` per:

  * ricordare di non mettere chiavi in `GYTE_AI_CMD`,
  * mostrare un mini check delle variabili d’ambiente più sensibili.
* Integrare controlli aggiuntivi nella CI:

  * secret scanning (ad esempio tramite gitleaks o equivalente),
  * enforcement di alcune regole ShellCheck specifiche (SC2086, SC2046, ecc.).

---

## 8. Sintesi

GYTE rimane volutamente:

* **offline-friendly** (lavora su CLI locali),
* **senza backend né server propri**,
* **senza gestione diretta di segreti**.

Il threat model qui descritto assicura che:

* gli script non diventino una scorciatoia per eseguire comandi pericolosi,
* gli errori di configurazione più comuni (URL, chiavi, comandi AI) non causino disastri silenziosi,
* il progetto possa crescere mantenendo una postura DevSecOps coerente.
