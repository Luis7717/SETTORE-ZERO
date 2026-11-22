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
- **three.js sta in `www/assets/three.min.js`** (dal 2026-11-20), non dentro `index.html`: tutto three + gli addons
  importati dal gioco (GLTFLoader, SkeletonUtils, BufferGeometryUtils), esposti come `window.__THREE` e
  `window.__THREE_ADDONS`. `index.html` lo carica con un `<script src>` normale **prima** del codice del gioco; nel
  codice si continua a scrivere `import * as THREE from 'three'` (e `three/addons/...`): in build un plugin li gira sui
  globali, in Node (test) restano il pacchetto vero. Se il file manca il gioco mostra un messaggio (`#nothree`), non
  una pagina vuota. `build.mjs` si ferma se three rientra in `index.html`; `test/unit/split-three.test.mjs` lo ricontrolla.
  Nuovi addons: basta importarli, finiscono da soli in `three.min.js`. Non è nel manifesto (è codice, non un file da scaricare).
- Ordine di caricamento (`src/assets.js`): 0) `assets/three.min.js` (sincrono, indispensabile); 1) menu subito; 2) all'ingresso in partita la tappa `match`
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
- `build.mjs` → `www/index.html` (~350 KB) + `www/assets/three.min.js` (~800 KB) + `www/assets/` (esbuild);
  `--single` incorpora anche three. `App/` involucro iOS (WKWebView + schema `app://`),
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
  Le novità chieste da Luis, divise in fasi, sono in `PIANO.md` (dal 2026-11-21 le novità vanno nella versione Godot).
- `npm run golden:update` → rigenera l'impronta delle partite a seme fisso (`test/fixtures/golden.json`).
  Solo quando il comportamento cambia **di proposito**; mai per far passare un refactoring.
- Prove su schermo: `node test/flow1.mjs shots`, `node test/preview-shot.mjs shots` (Puppeteer, iPhone 390×844). Chrome: variabile `CHROME`,
  predefinito `C:/Program Files/Google/Chrome/Application/chrome.exe`. Debug in pagina: `window.__G`, `__career`, `__view`, `__ui`, `__start`.

## Gesti (tutto a un dito)
- Col pallone, fuori dal duello: disegna dal giocatore = **strada da correre** (con tanta strada davanti scatta); linea che finisce in porta = tiro.
- **Duello** (portatore a 7 m da un difensore davanti, anche "per linee": vedi Scatto): visuale bassa, tempo all'8%. Si
  passa a qualunque compagno **solo disegnando** fino al compagno (il tocco sul compagno non passa più, 2026-11-20);
  oppure tasto **Dribbling** in basso. Il tasto **prenota** il dribbling (2026-11-21): sparisce, il tempo torna normale e
  il portatore corre verso il difensore puntando il lato scelto; il dribbling vero (esito, giochetto) parte solo a 2 m
  dal difensore (`DRIB_NEAR`, al massimo 1,2 s dopo il tocco, `DRIB_BOOK_MAX`). Lato: opposto allo sbilanciamento del
  difensore, verso lo spazio libero, sempre verso il centro entro 8 m dalla linea laterale (`dribSide`); il giochetto va
  da quel lato (`e.side`) e il portatore gli passa accanto senza attraversarlo. Se il duello finisce prima (palla persa,
  passaggio, difensore lontano) la prenotazione si annulla. L'IA dribbla subito, a 3,2 m, come prima.
- **Area di tiro** (ultimi 20 m prima della porta avversaria, col pallone): tempo al 22%; linea in porta = tiro,
  ogni altra linea = passaggio (fino a un compagno entro 5 m, o nello spazio): nei rallenty niente corsa disegnata (2026-11-21). Anche sulle rimesse il passaggio si disegna.
- **Visuale girata col dito** (duello e area di tiro, pallone nostro): trascinare di lato partendo lontano dal portatore
  gira la telecamera intorno a lui (si afferra il campo: 150° per schermo, al massimo ±100°, `src/camuser.js`); niente
  più rotazione automatica. Il tocco breve sul campo o su un compagno lì non fa niente. Resta finché dura il rallenty
  con lo stesso portatore, poi torna dritta da sola.
- **Scatto** (fuga, Luis 2026-11-21): si divide il campo in linee parallele alle linee di porta. Avversario a meno di
  4 m **alla pari o dietro** il portatore (non più avanti di 0,5 m verso la porta avversaria, `LEVEL_TOL`) = niente duello:
  il tempo rallenta (8%), si può **passare** disegnando (ogni linea è un passaggio, niente corsa) e il tasto in basso è **Scatto**; toccandolo il portatore si stacca (+15% di velocità per 1,2 s,
  l'avversario resta indietro e non contrasta per 0,6 s) e prosegue dritto per 14 m. Riesce sempre. Avversario **davanti**
  per linee = duello col **Dribbling** o il passaggio disegnato. L'IA dribbla come prima.
- La finta è stata tolta (2026-11-20).
- Calcio d'angolo: telecamera alle spalle del battitore; dito vicino al battitore = cross, lontano = trascinando si gira la visuale.
- **Niente doppio tocco** sui calci da fermo (2026-11-21): chi batte rimessa, angolo, punizione, rinvio, calcio d'inizio o
  rigore non può toccare il pallone finché non l'ha toccato un altro (compagno, avversario o portiere: dopo il palo il
  rigorista no, dopo la parata sì). Niente punizione indiretta: semplicemente non lo tocca (`b.dbl`, `dblBan`). La CPU
  manda sul pallone un altro e il controllo passa a lui; se dopo 6 s nessuno l'ha toccato il battitore torna libero
  (`DBL_FREE`, sicurezza). Il rilancio del portiere dalle mani non conta.
- Difesa: dito su un proprio giocatore e disegna = linea da seguire (tutti tranne il portiere); tieni premuto sul campo =
  muovi il controllato. Le linee di difesa sono lunghe al massimo 14 m; finita la linea il giocatore torna alla CPU.
  Senza linea la CPU difende (2026-11-20): uno (due vicino alla nostra porta) pressa il portatore, gli altri rientrano
  dietro la palla nella loro posizione; la linea disegnata ha sempre la precedenza. Contrasto un po' "magnetico" per chi
  muove la persona; un passaggio avversario intercettato dà il possesso. La scivolata del giocatore è stata tolta. Raggio di
  intercetto = difesa del difensore contro passaggio di chi passa.
- **Meteo** (2026-11-21, campo facoltativo `meteo` delle opzioni del motore, senza = come prima): **pioggia** = palla più
  veloce (attrito del rotolamento ×0,75), scivolata ×1,3 e chi perde un contrasto resta fermo ×1,25; **neve** = palla
  più lenta (×1,35). Sereno e nuvoloso non cambiano niente. Il meteo e l'ora (pomeriggio, tramonto, notte coi fari)
  si scelgono solo nella versione Godot (`godot/scripts/partita/meteo.gd`, col seme; in campionato secondo la giornata).
- **Colpo di testa controllato** (Godot, Luis 2026-11-22, `godot/sim/testa.gd`): pallone alto di un compagno (cross,
  lancio, angolo) che sta per arrivare ad altezza di testa a un nostro attaccante entro 17 m dalla porta avversaria =
  **fermatempo**: il pallone arriva alla testa dopo **3 secondi veri** (`TESTA_FERMATEMPO_S` in
  `scripts/partita/fermatempo_testa.gd`, velocità = volo che manca / secondi veri che mancano), visuale con la porta,
  controllo a chi colpisce, cerchio giallo intorno a lui che si svuota con la scritta piccola "Di testa!". Linea col dito
  verso la porta = colpo di testa lì (precisione secondo `tes`), verso un compagno o il campo = sponda; disegnata la
  linea il tempo torna normale e il colpo parte appena arriva il pallone. **Senza linea il pallone è perso** (nessun
  compagno lo tocca: passa sopra, lo prende la difesa o il portiere). Senza fermatempo i colpi di testa restano
  automatici come prima. Il cross disegnato dalla fascia verso l'area è sempre un pallone alto (`isCross`).
  Nel motore vale solo con l'opzione `"testa": true` (la mette il gioco; i confronti col JS restano identici).
- Portiere: sul tiro la visuale va dietro la propria porta e il tempo rallenta; linea dal portiere al punto della porta,
  il tuffo parte quando si alza il dito.

## Versione Godot (in costruzione)
- Cartella **`godot/`** (Godot 4.7.2-stable, GDScript, renderer Mobile, 390×844 verticale): `project.godot`,
  `export_presets.cfg` (preset `iOS` e `Windows Desktop`), `scenes/`, `scripts/`, `shaders/`, `assets/` (licenze in
  `godot/CREDITI.md`), `sim/` + `tests/` = motore in GDScript. Guida completa: `godot/README.md`.
- Coordinate: Godot X = x, Y = altezza, Z = −y (come three.js nel web), funzioni in `godot/scripts/coord.gd`.
- Comandi (G = `Godot_v4.7.2-stable_win64_console.exe`, in `C:\Users\forma\Documents\godot-tools`):
  `$G --headless --path godot --import` · `$G --headless --path godot -- --esci-dopo=4` (niente errori) ·
  `$G --path godot -- --schermata=shots/x.png --dopo=3` (anche `--vista=vicina|porta|alta`, `--senza-vsync`, `--prova-tocchi`).
- Meteo e ora della partita: `scripts/partita/meteo.gd` (prove: `--meteo=sereno|nuvoloso|pioggia|neve`, `--ora=giorno|tramonto|notte`).
- Build: workflow `.github/workflows/tiro-a-giro-godot-ipa.yml` (push su `tiro-a-giro` che tocca `godot/**`) →
  release **`tiro-a-giro-godot-ipa`**, `TiroAGiroGodot.ipa`, bundle `it.tiroagiro.godot` ("Tiro a Giro 3D"), iOS 15+,
  chip A12+. Il workflow web ignora i cambi solo in `godot/`.
