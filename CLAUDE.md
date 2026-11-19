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
- Resta **un solo file offline** (`www/index.html`), schermo **verticale**, giocabile con **un dito**.
- `src/sim.js` (e `src/sim/*`) = motore puro: **nessuna dipendenza grafica**, gira in Node.
- **Ogni modifica al motore ha un test in Node** (`test/unit/*.test.mjs`).
- Squadre, giocatori e sponsor **inventati**; grafica originale, niente copiato da altri giochi.
  Modelli 3D solo CC0 / CC-BY, incorporati nel file e citati nel README.
- I salvataggi esistenti (`localStorage`, chiave **`tag_save_v1`**) devono continuare a funzionare:
  campi nuovi si aggiungono con valori predefiniti, mai rinominare o cambiare la chiave.
- Il motore usa solo numeri casuali con seme (`this.rnd()` / `rng32`), **mai `Math.random`**: le partite devono essere ripetibili.

## Struttura
- `src/sim.js` — punto d'ingresso del motore (ripubblica `src/sim/*`): fisica, IA, regole, partita (`Match`).
- `src/render.js` grafica three.js · `src/input.js` gesti · `src/career.js` campionato, mercato, salvataggio ·
  `src/ui.js` menu · `src/main.js` collegamento e ciclo · `src/audio.js` suoni sintetizzati.
- `build.mjs` → `www/index.html` (esbuild, tutto in un file). `App/` involucro iOS (WKWebView), `.github/workflows/` build IPA.
- Coordinate: x = larghezza (−32..32), y = lunghezza (−50..50); la squadra 0 attacca verso +y.

## Comandi
- `npm install` · `npm run build` · `npm test` (test del motore con `node:test`).
- `npm run balance -- 60 60 20` → umano simulato contro IA: vittorie, gol, tiri, possesso.
  **I numeri di equilibrio si misurano con questo** (non IA contro IA: nella squadra umana pressa solo il controllato).
- `node test/diag-flow.mjs 60 20 bot` → diagnosi dell'attacco: azioni, ultimi 30 m, palle perse per zona e motivo, angoli, rimesse.
- `node test/sim-test.mjs ai 12` → IA contro IA, conteggio eventi.
- Le regolazioni del motore sono costanti con nome in cima a `src/sim/ai.js`, `motion.js`, `match.js`.
  Le scelte fatte in autonomia e gli obiettivi non ancora raggiunti sono in `DECISIONI.md`.
- `npm run golden:update` → rigenera l'impronta delle partite a seme fisso (`test/fixtures/golden.json`).
  Solo quando il comportamento cambia **di proposito**; mai per far passare un refactoring.
- Prove su schermo: `node test/flow1.mjs shots`, `node test/preview-shot.mjs shots` (Puppeteer, iPhone 390×844). Chrome: variabile `CHROME`,
  predefinito `C:/Program Files/Google/Chrome/Application/chrome.exe`. Debug in pagina: `window.__G`, `__career`, `__view`, `__ui`, `__start`.

## Gesti (tutto a un dito)
- Dal portatore: disegna = passaggio/tiro (linea curva = a giro), il tempo rallenta.
- Tieni premuto sul campo = corsa; tocco su un compagno = passaggio diretto.
- Difesa: tieni premuto = muovi il difensore; scorrimento veloce = scivolata.
- Portiere: scorri verso il lato del tiro.
