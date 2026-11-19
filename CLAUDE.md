# Tiro a Giro — regole del progetto

## Come lavorare con Luis
- Parla sempre in **italiano**, in modo semplice. Testi del gioco in italiano.
- Lavoro a **fasi**: alla fine di ogni fase test verdi, build, commit, push e **fermarsi** ad aspettare il giudizio sull'iPhone.
- Non dire mai "provato su iPhone": dire cosa è stato verificato e come (test in Node, schermate Puppeteer 390×844), e cosa resta da provare a Luis.

## Ramo e push
- Questo gioco vive SOLO sul ramo **`tiro-a-giro`** di `github.com/Luis7717/SETTORE-ZERO`. **Mai toccare `main`** (è Settore Zero, un altro gioco).
- In locale si lavora nel worktree `C:\Users\forma\Documents\SETTORE-ZERO-gioco2`, ramo `gioco2`.
  Push: `git push origin gioco2:tiro-a-giro` → parte la build dell'IPA (release `tiro-a-giro-ipa`).

## Regole fisse
- Gioco **offline a più file** (regola cambiata il 2026-11-19: non più file unico, niente limite di 15 MB):
  `www/index.html` = codice e menu, **sotto 1 MB**; modelli, texture e audio in `www/assets/` (sorgenti in `assets/`,
  elenco in `assets/manifest.json`). **Nessun singolo file sopra i 20 MB.** `build.mjs` controlla entrambi i limiti.
- Ordine di caricamento (`src/assets.js`): 1) menu subito; 2) all'ingresso in partita la tappa `match`
  (stadio, giocatori, suoni) con barra di avanzamento; 3) la tappa `music` in sottofondo. Un file che manca o fallisce
  si salta: il gioco parte lo stesso senza quel pezzo.
- Nell'app iOS i file sono serviti su schema proprio `app://localhost/` (`WKURLSchemeHandler` in `App/main.swift`).
- Schermo **verticale**, giocabile con **un dito**.
- `src/sim.js` (e `src/sim/*`) = motore puro: **nessuna dipendenza grafica**, gira in Node.
- **Ogni modifica al motore ha un test in Node** (`test/unit/*.test.mjs`).
- Squadre, giocatori e sponsor **inventati**; grafica originale, niente copiato da altri giochi.
  Modelli 3D solo CC0 / CC-BY, incorporati nel file e citati nel README.
- I salvataggi esistenti (`localStorage`, chiave **`tag_save_v1`**) devono continuare a funzionare:
  campi nuovi si aggiungono con valori predefiniti, mai rinominare o cambiare la chiave.
  Passando da `file://` ad `app://` l'origine cambia: al primo avvio l'app legge il vecchio salvataggio con
  `App/legacy.html` (messa dove stava la vecchia `index.html`) e la pagina lo copia (`src/legacy-save.js`, mai sovrascrive).
- Il motore usa solo numeri casuali con seme (`this.rnd()` / `rng32`), **mai `Math.random`**: le partite devono essere ripetibili.

## Struttura
- `src/sim.js` — punto d'ingresso del motore (ripubblica `src/sim/*`): fisica, IA, regole, partita (`Match`).
- `src/render.js` grafica three.js · `src/input.js` gesti · `src/career.js` campionato, mercato, salvataggio ·
  `src/ui.js` menu · `src/main.js` collegamento e ciclo · `src/audio.js` suoni sintetizzati.
- `src/assets.js` caricamento a pezzi · `src/legacy-save.js` recupero del vecchio salvataggio.
- `build.mjs` → `www/index.html` + `www/assets/` (esbuild). `App/` involucro iOS (WKWebView + schema `app://`),
  `.github/workflows/` build IPA (copia tutta `www/` nell'app).
- Coordinate: x = larghezza (−32..32), y = lunghezza (−50..50); la squadra 0 attacca verso +y.

## Comandi
- `npm install` · `npm run build` · `npm test` (test del motore con `node:test`).
- `npm run build:single` → `dist/tiro-a-giro.html`, versione a file unico con i file incorporati, **solo per provarla nel browser**.
- `node test/loading-shot.mjs shots` → prova del caricamento a pezzi (file mancante, barra, musica, file unico).
- `node test/menu-time.mjs http 15` → tempo di apertura del menu. Le prove a schermo servono `www/` via http (`test/lib/serve.mjs`).
- `npm run balance -- 60 60 20` → umano simulato contro IA: vittorie, gol, tiri, possesso.
  **I numeri di equilibrio si misurano con questo** (non IA contro IA: nella squadra umana pressa solo il controllato).
- `node test/diag-flow.mjs 60 20 bot` → diagnosi dell'attacco: azioni, ultimi 30 m, palle perse per zona e motivo, angoli, rimesse.
- `node test/sim-test.mjs ai 12` → IA contro IA, conteggio eventi.
- Le regolazioni del motore sono costanti con nome in cima a `src/sim/ai.js`, `motion.js`, `match.js`.
  Le scelte fatte in autonomia e gli obiettivi non ancora raggiunti sono in `DECISIONI.md`.
  Il lavoro in parallelo coi subagenti (compito, modello, stato, file toccati) è in `PARALLELO.md`.
- `npm run golden:update` → rigenera l'impronta delle partite a seme fisso (`test/fixtures/golden.json`).
  Solo quando il comportamento cambia **di proposito**; mai per far passare un refactoring.
- Prove su schermo: `node test/flow1.mjs shots`, `node test/preview-shot.mjs shots` (Puppeteer, iPhone 390×844). Chrome: variabile `CHROME`,
  predefinito `C:/Program Files/Google/Chrome/Application/chrome.exe`. Debug in pagina: `window.__G`, `__career`, `__view`, `__ui`, `__start`.

## Gesti (tutto a un dito)
- Col pallone, fuori dal duello: disegna dal giocatore = **strada da correre** (con tanta strada davanti scatta); linea che finisce in porta = tiro.
- **Duello** (portatore a 4,5 m da un difensore davanti): visuale bassa, tempo al 35%, anelli verdi sui compagni liberi.
  Solo qui (e sulle rimesse) si passa: disegna fino al compagno o toccalo; oppure tasto **Dribbling** in basso.
- Col pallone, scorrimento veloce di lato = finta.
- Difesa: dito su un proprio giocatore e disegna = linea da seguire (fino a 3 insieme); tratto rapido e corto dal
  controllato o scorrimento veloce dal campo = scivolata; tieni premuto sul campo = muovi il controllato. Raggio di
  intercetto = difesa del difensore contro passaggio di chi passa.
- Portiere: sul tiro la visuale va dietro la propria porta e il tempo rallenta; linea dal portiere al punto della porta,
  il tuffo parte quando si alza il dito.
