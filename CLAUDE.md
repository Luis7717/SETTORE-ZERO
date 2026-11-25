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
- **Col pallone ogni linea è un calcio** (Luis 2026-11-22), in ogni zona del campo e non solo nei rallenty: si disegna
  dal pallone (o dal portatore); linea che finisce in porta = **tiro**, ogni altra = **passaggio** (a un compagno entro 5 m
  dalla fine o nello spazio). Niente più strada da correre né scatto lungo disegnato: il portatore si muove da solo (IA,
  `ai.gd`); col pallone il tocco e il dito tenuto non lo guidano. Restano i tasti Scatto e Dribbling dei rallenty.
- **Forma del tratto** (`sim/match.gd`, `spec.tratto`): curvatura = quanto la linea si allontana dalla corda inizio-fine.
  Sotto `max(CURVE_MIN_M 1,2 m, CURVE_MIN_FRAC 15% della lunghezza)` è **dritta** = **rasoterra** (ma il passaggio dritto
  più lungo di `TRATTO_LOFT_M` 25 m o con un avversario sulla linea, `blocked`, va **alto ma dritto**, Luis 2026-11-23; passaggio rasoterra che
  arriva al compagno a `GROUND_ARRIVE` 5 m/s o si ferma dove finisce la linea nello spazio; tiro rasoterra che rotola
  fino al punto della porta). Sopra è **curva** = **a effetto e alta**: gira dal lato della curva disegnata (la pancia del
  volo è quella della linea) e si alza scavalcando chi sta in mezzo, di più con più curva (`CURVE_T_MIN`,
  `CURVE_T_EXTRA`; tiro a giro con punto più alto `CURL_APEX_MIN..MAX`, entra all'altezza dove finisce la linea). Anche il
  cross: dritto rasoterra, curvo alto (apre il fermatempo del colpo di testa); `isCross` tolto. L'IA (senza `tratto`)
  resta come prima. **Passaggio a giro corto** (Godot, Luis 2026-11-24, con `rifiniture`): il tratto curvo fino a
  `CURVE_GROUND_M` 20 m resta **rasoterra a effetto** se la curva passa libera (`arcBlocked`); con un avversario sulla
  curva si alza e lo scavalca come prima; oltre 20 m curvo = alto. Senza rifiniture (lezioni, confronti col JS) come
  prima. Test `tests/test_passaggio_giro.gd`. Il tiro caricato è stato scartato (Luis 2026-11-22): la potenza la sceglie il gioco.
- **Di prima** (2026-11-22): mentre un nostro passaggio viaggia, dito sul compagno che lo riceverà (entro 6 m dal volo
  previsto, `PRIMA_VOLO_M`) = si disegna già il calcio dopo (passaggio o tiro, stessa forma del tratto); a dito alzato la
  linea resta **tratteggiata** (verde, gialla se tiro) sul compagno finché arriva il pallone, poi lui calcia **subito,
  senza stop** (`userQueue` / `fireQueued`, un po' meno preciso: `FIRST_SIG` + `FIRST_SIG_STAT` per punto che manca a
  100). Se il pallone lo prende un altro, cambia volo o il gioco si ferma, il calcio si annulla. Se il pallone arriva
  mentre si disegna ancora, la linea continua come un calcio normale.
- **Portatore che si muove da solo** (versione Godot, Luis 2026-11-22): il portatore della squadra umana si muove
  sempre da solo (`humanCarrierAuto` in `godot/sim/ai.gd`, opzione `portaAuto` del Match, predefinita sì; i test
  confrontati col JS la spengono): avanza nello spazio libero cercando linee di passaggio libere, entra in area se può,
  protegge palla se pressato, rallenta se non ha compagni davanti, gira intorno ai difensori e resta in campo, secondo
  lo **stile d'attacco** (contropiede punta la porta di corsa, possesso avanza piano, fasce va sulla linea laterale e in
  fondo aspetta il cross, lanci lunghi resta quasi fermo a testa alta). **Non passa e non tira mai da solo**: il dito
  sceglie passaggi e tiri, e i tasti Dribbling e Scatto nei rallenty (nel duello e nella fuga avanza piano e dritto
  come prima).
- **Rosa in alto** (Godot, Luis 2026-11-24, `scripts/menu/rosa_scelte.gd`): tre tasti uguali **Formazione** /
  **Attacco** / **Difesa** con la scelta attuale; ognuno apre un menu a comparsa (una riga di spiegazione per scelta,
  scelta attuale in giallo, si chiude toccando fuori o con la ×). "Migliori 11" tolto (resta `autoLineup`).
  **8 formazioni** in `sim/core.gd`: le 4 del web (prime, identiche) + 4-5-1, 3-4-3, 5-3-2, 4-1-4-1. La CPU sorteggia
  come il JS tra le 4 del web (`aiMatchTeam`), poi metà squadre usa la "cugina" nuova (`FORMAZIONE_CUGINA`,
  `formazioneDi`, in partita con `avversarioPartita`). Test: `tests/test_formazioni.gd`.
- **Rosa e tattica nella pausa** (Godot, Luis 2026-11-24): nelle partite della carriera (campionato, amichevole) la
  pausa e l'intervallo hanno il tasto **Rosa e tattica**: la Rosa del menu (`rosa.gd` con `{"in_partita": true, "cambi",
  "carriera"}`) si apre sopra la partita ferma, senza Aspetto, Vendi né altre schermate, con "Cambi N/5" (quanti restano)
  e **Torna alla partita**. Regole in `scripts/partita/cambi_partita.gd`: al massimo 5 sostituzioni (intervallo
  compreso), chi è uscito resta in panchina "USCITO", l'espulso non si tocca, chi entra ha energia piena; scambi tra
  titolari, formazione (gli stessi 11 nei posti nuovi, `formazione_stessi_11`) e stili liberi. Chiusa la Rosa i cambi
  vanno subito nel motore (`SimMatch.cambiaSquadra`: stesso giocatore = stesso src, posti e ruoli della formazione, stili;
  evento `sub` con `fuori`, cronaca "Cambio: entra X, esce Y") e si salvano nella carriera. A Riprendi / Secondo tempo
  la **scena del cambio** (`cambio_regia.gd`, 3,4 s veri, tempo fermo, un tocco la salta): chi esce cammina verso la
  linea laterale a centrocampo, chi entra corre al suo posto, targhette ▲ verde / ▼ rossa e riquadro CAMBIO in basso,
  telecamera dal lato opposto. Non nelle lezioni, nelle prove di tiro né senza carriera. **Campione sempre titolare**
  fuori partita: nella Rosa del menu non va in panchina (`Carriera.swap`, `campioneInPanchina`), `autoLineup`/`fixLineup`
  lo tengono; in partita si può sostituire, ma `tieniCampione` lo rimette titolare a fine partita, all'avvio della
  successiva (`squadraPartita`) e al caricamento. Prove: `-- --pausa-rosa[=pausa|giocatore|formazione|cambi]`,
  `--scena=cambio` (carriera di prova su `user://prova_pausa_rosa.json`); test `tests/test_cambi_partita.gd`,
  `-s res://tests/prova_cambio.gd`, controlli in `controlli_menu.gd`.
  Il **campione non si vende** (Luis 2026-11-25): `Carriera.sell` lo rifiuta e nella Rosa ha solo il tasto Aspetto.
- **Stili di gioco** (Fase D, `godot/sim/stili.gd`): nella Rosa, tasti **Attacco** e **Difesa**: attacco (Equilibrato, Contropiede,
  Possesso, Fasce, Lanci lunghi) e difesa (Equilibrata, Pressing, Catenaccio, A uomo, Fuorigioco). Valgono per i
  compagni della CPU e per gli avversari (stile fisso per squadra, mostrato nell'hub). Campi `stileAtt`/`stileDif`
  della squadra del Match e del salvataggio; senza, motore identico a prima.
- **Duello** (portatore a 7 m da un difensore davanti, anche "per linee": vedi Scatto): visuale bassa, tempo all'8%. Si
  passa a qualunque compagno **solo disegnando** fino al compagno (il tocco sul compagno non passa più, 2026-11-20);
  oppure tasto **Dribbling** in basso. Il tasto **prenota** il dribbling (2026-11-21): sparisce e il portatore corre
  verso il difensore puntando il lato scelto; il dribbling vero (esito, giochetto) parte solo a 2 m
  dal difensore (`DRIB_NEAR`, al massimo 1,2 s dopo il tocco, `DRIB_BOOK_MAX`). **Regia del dribbling** (Godot, Luis
  2026-11-24, `scripts/partita/dribbling_regia.gd`): dal tocco alla fine il tempo resta in rallenty (40% nella corsa,
  30% nel giochetto e nel sorpasso, poi torna normale piano, `USCITA_K`), la telecamera gira di 45° intorno al
  portatore dal lato del dribbling, più bassa e vicina (`dribble_view` in `camfit.gd`, `_drib_step` in
  `telecamera_partita.gd`), poi torna dritta da sola; il timer del rallenty non conta. Nel motore (solo con
  `rifiniture`, `dribShow` in `sim/duel.gd`): riuscito = il portatore frena davanti al difensore, finta di lato dal
  lato opposto per `DRIB_SHOW_T` 0,35 s col giochetto a schermo (difensore battuto che si butta verso la finta e
  interviene a vuoto), poi cambia direzione e scatta oltre più veloce (`p.burst`, evento `dribble_go`); fallito = frena (non gli finisce
  addosso), contrasto del difensore e portatore che inciampa (`vista.dribbling` / `vista.dribbling_go`).
  **Animazioni del dribbling** (Luis 2026-11-24, "animazioni da rivedere"): coreografie calcolate ancorate al campo
  (`scripts/partita/mosse/coreo.gd` + `coreo_dribbling.gd`, niente file nuovi): piedi fermi a terra finché appoggiano,
  passi programmati dove sarà il corpo (più un passo da solo se una gamba si allunga troppo), pallone mosso solo dai
  tocchi (suola, finta, esterno nello scatto; alla fine torna quello del motore), verso del corpo che gira dolce.
  Giochetti della persona: finta di corpo, doppio passo, elastico; difensore che si butta sulla finta e allunga la gamba
  a vuoto, contrasto col piede di traverso, inciampo con passo di recupero. I dribbling dell'IA tengono i giochetti di
  prima. Solo grafica: motore ed esito identici. Test `tests/test_coreo.gd`; prova da vicino a passo fisso:
  `prova_vista.tscn -- --scena=dribbling_ok|dribbling_ko [--giochetto=elastico] --foto=CARTELLA/x`.
  Esito con la stessa probabilità di prima. Prove: `--scena=dribbling|dribbling_ok|dribbling_ko`. Lato: opposto allo sbilanciamento del
  difensore, verso lo spazio libero, sempre verso il centro entro 8 m dalla linea laterale (`dribSide`); il giochetto va
  da quel lato (`e.side`) e il portatore gli passa accanto senza attraversarlo. Se il duello finisce prima (palla persa,
  passaggio, difensore lontano) la prenotazione si annulla. L'IA dribbla subito, a 3,2 m, come prima.
- **Area di tiro** (ultimi 20 m prima della porta avversaria, col pallone): tempo al 22%; linea in porta = tiro,
  ogni altra linea = passaggio (fino a un compagno entro 5 m, o nello spazio). Anche sulle rimesse il passaggio si disegna.
- **Timer del rallenty** (Godot, Luis 2026-11-23): il rallenty col pallone (duello, fuga, area di tiro) dura al massimo
  **10 secondi veri** (`RALLENTY_MAX_S` in `godot/scripts/partita/timer_rallenty.gd`), con un cerchietto bianco sopra il
  portatore che si svuota; mentre il dito disegna il timer è fermo. Scaduto senza linea né tasto, `m.userCalm` chiude
  duello/fuga e il gioco torna a velocità normale col portatore che va da solo; per lo stesso portatore duello e fuga
  non si riaprono per `CALM_CD` 4 s di partita, l'area di tiro (se è scaduta lì) finché non perde il pallone. Non nelle
  lezioni dell'allenamento né nelle prove di tiro.
- **Visuale girata col dito** (duello e area di tiro, pallone nostro): trascinare di lato partendo lontano dal portatore
  gira la telecamera intorno a lui (si afferra il campo: 150° per schermo, al massimo ±100°, `src/camuser.js`); niente
  più rotazione automatica. Il tocco breve sul campo o su un compagno lì non fa niente. Resta finché dura il rallenty
  con lo stesso portatore, poi torna dritta da sola.
  **Anche in gioco normale** (Godot, Luis 2026-11-24: "mentre corre da solo vorrei già girare la telecamera"): col
  pallone nostro in gioco, mentre il portatore corre da solo, il dito appoggiato lontano da lui e dal pallone e
  trascinato di lato gira la visuale intorno a lui (stessa soglia, sensibilità e limiti, `drag_cam_on` /
  `ball_cam_on` in `visuale_dito.gd` e `camuser.gd`); il gioco **non rallenta** e il portatore continua da solo; dal
  pallone resta il calcio disegnato (punti dello schermo → campo con la telecamera vera, quindi anche girata).
  La visuale girata resta finché lo stesso portatore ha il pallone; dopo un passaggio a un compagno resta ancora
  `CAM_USER_PASS_HOLD` 4 s finché il possesso è nostro (si vede il passaggio dopo; trascinando di nuovo resta col nuovo
  portatore), perso il possesso torna subito dritta piano (`hold_yaw` in `camuser.gd`, letto da `vista.gd`). Senza
  pallone (difesa) niente cambia. Le frecce d'aiuto dell'HUD restano solo nei rallenty. Prova:
  `res://scenes/partita.tscn -- --scena=giro|giro_linea`.
- **Scatto** (fuga, Luis 2026-11-21): si divide il campo in linee parallele alle linee di porta. Avversario a meno di
  4 m **alla pari o dietro** il portatore (non più avanti di 0,5 m verso la porta avversaria, `LEVEL_TOL`) = niente duello:
  il tempo rallenta (8%), si può **passare** disegnando (ogni linea è un passaggio, niente corsa) e il tasto in basso è **Scatto**; toccandolo il portatore si stacca (+15% di velocità per 1,2 s,
  l'avversario resta indietro e non contrasta per 0,6 s) e prosegue dritto per 14 m. Riesce sempre. Avversario **davanti**
  per linee = duello col **Dribbling** o il passaggio disegnato. L'IA dribbla come prima.
  Godot (Luis 2026-11-23, "dopo lo scatto si blocca"): con `portaAuto` e `rifiniture` la corsa dritta dura quanto lo
  scatto (1,2 s), poi il portatore torna subito alla guida automatica secondo lo stile, e la fuga non si riapre per
  `BURST_FLEE_CD` 3,5 s (prima si fermava sulla meta finché durava il comando, l'avversario lo riprendeva e la fuga
  riapriva il rallenty col portatore fermo).
- La finta è stata tolta (2026-11-20).
- Calcio d'angolo: telecamera alle spalle del battitore; dito vicino al battitore = cross, lontano = trascinando si gira la visuale.
- **Rimessa laterale nostra** (Godot, Luis 2026-11-23): quando il battitore è sulla linea (`restart.sulPosto()`) la
  telecamera entra piano alle spalle del battitore, fuori dal campo, girata verso il campo e un po' verso la porta
  avversaria (`throw_view` in `camfit.gd`, `_throw_step` in `telecamera_partita.gd`), col battitore in basso al centro;
  dito vicino al battitore = passaggio, lontano = trascinando si gira la visuale (mai verso le tribune). Le
  rimesse della CPU restano con la telecamera normale.
  Luis 2026-11-24 (`riprese.gd`): il battitore (di tutte e due le squadre) aspetta col pallone sopra la testa
  `THROW_STAND` 1,2 m **oltre** la linea laterale (`throwStand`); al lancio fa i passi fino alla linea (`r.rinc`/`r.pend`,
  `THROW_STEP_SPD`) e il pallone parte da lì, dentro il campo. Con `rifiniture`, mentre si aspetta la rimessa gli altri
  restano dentro il campo (`throwRoom`, dopo `assign`): almeno `THROW_ROOM_MIN` 4,5 m dalla linea, +0,1 m per metro di
  distanza lungo la linea fino a 7 m; i compagni d'appoggio si smarcano a 8-11 m dal battitore (`offerSupport`).
  Misura: `-s res://tools/misura_rimesse.gd -- --partite=40`; prova: `--scena=fuori_lato_cpu` (rimessa della CPU).
- **Calcio d'inizio** (Godot, Luis 2026-11-24, opzione `rifiniture`): nel cerchio di centrocampo (9,15 m) solo il
  battitore; tutti gli altri fuori dal cerchio e nella propria metà finché il pallone non è calciato (anche dopo un gol
  e nel secondo tempo): `kickoffClear` in `godot/sim/motion.gd` (messi in campo e ogni passo dell'attesa) e bersagli
  dell'IA in `ai.gd`. Test: `tests/test_calcio_inizio.gd`.
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
- **Contatti e recupero palla** (Godot, Luis 2026-11-24, `godot/sim/contatti.gd`, opzione `"contatti": true` del Match
  messa dal gioco, spenta nei confronti col JS): i giocatori si spingono via morbidamente sotto `SEP_R` 0,9 m tra i centri
  (le figure ×1,25 a 0,7 m si compenetravano; chi va addosso perde la velocità verso l'altro, il portatore non viene
  spostato). Quando la persona recupera il pallone dalla CPU: protetto per `RESPIRO_PROTECT` 0,8 s e gli avversari entro
  2,5 m non contrastano per `RESPIRO_CD` 1,1 s. Passaggio della persona: chi stava entro `SHIELD_NEAR` 1,5 m dal pallone
  (o entro 2,5 m ma non sulla linea) non lo intercetta nei primi `SHIELD_D` 3 m. Misure: righe CONTATTI/RECUPERI/PASSAGGI P
  di `tools/controllo_gameplay.gd` (`--senza-contatti` per confronto); prove: `prova_vista --scena=contatto --dist=0.7`,
  `--scena=recupero` (anche nel gioco).
- **Falli** (Godot, Luis 2026-11-24, `godot/sim/falli.gd`, opzione `"falli": true` del Match messa dal gioco, spenta in
  lezioni, prove di tiro e confronti col JS): pochi, circa 2-3 a partita (tempi da 2:30). Solo sui contrasti **da dietro**
  o **di fianco un po' dietro** (il frontale resta pulito) e **in ritardo** (addosso di corsa a chi ha appena calciato);
  più falli con più velocità, meno difesa, pioggia; la squadra della persona ×0,3; il portiere mai. Usa `foulCall`
  (`motion.gd`): giallo (secondo = rosso, espulso), rigore in area (fallo in ritardo sul tiro in area: il tiro va avanti,
  rigore se non è gol), vantaggio o punizione con barriera. HUD: cartellino disegnato sopra la scritta (`hud.mostra_cartellino`); Ammonizioni/Espulsioni nel tabellino.
  Prove: `--scena=fallo|rigore|espulso`.
- **Meteo** (2026-11-21, campo facoltativo `meteo` delle opzioni del motore, senza = come prima): **pioggia** = palla più
  veloce (attrito del rotolamento ×0,75), scivolata ×1,3 e chi perde un contrasto resta fermo ×1,25; **neve** = palla
  più lenta (×1,35). Sereno e nuvoloso non cambiano niente. Il meteo e l'ora (pomeriggio, tramonto, notte coi fari)
  si scelgono solo nella versione Godot (`godot/scripts/partita/meteo.gd`, col seme; in campionato secondo la giornata).
- **Colpo di testa controllato** (Godot, Luis 2026-11-22, `godot/sim/testa.gd`): pallone alto di un compagno (cross,
  lancio, angolo) che sta per arrivare ad altezza di testa a un nostro attaccante entro 17 m dalla porta avversaria =
  **fermatempo**: il tempo si **ferma del tutto** (niente rallenty, Luis 2026-11-23) per **3 secondi veri**
  (`TESTA_FERMATEMPO_S` in `scripts/partita/fermatempo_testa.gd`; se il dito sta ancora disegnando si aspetta che lo
  alzi), visuale vicina come nel tiro (`head_view` in `camfit.gd`: chi colpisce grande in basso, la porta sopra),
  controllo a chi colpisce, come col pallone nel rallenty (dito vicino a lui = linea, lontano = trascinando gira la visuale), cerchio giallo intorno a lui che si svuota con la scritta piccola "Di testa!". Linea col dito
  verso la porta = colpo di testa lì (precisione secondo `tes`), verso un compagno o il campo = sponda; disegnata la
  linea il tempo torna normale e il colpo parte appena arriva il pallone. **Finiti i 3 secondi senza linea il pallone è perso** (`headExpire`: non si disegna più) (nessun
  compagno lo tocca: passa sopra, lo prende la difesa o il portiere). Senza fermatempo i colpi di testa restano
  automatici come prima. Il cross alto si disegna col tratto curvo. Il fermatempo si apre solo se nessun avversario
  (portiere compreso) arriva sul pallone chiaramente prima; il difensore che arriva insieme se lo contende in salto
  (chi ha già disegnato la linea ha un piccolo vantaggio, `HEAD_DUEL_EDGE`); con la linea il colpo parte anche se il
  pallone arriva un po' più basso (al volo).
  **Salto conteso** (Luis 2026-11-24, `kind` "def" / "pass" di `HeadWin`): stesso fermatempo (tempo fermo 3 s, stessa
  visuale e cerchio) anche **in difesa** sui palloni alti della CPU (cross, lanci) a più di `HEAD_DEF_ZONE` 15 m dalla
  metà campo verso la nostra porta e **sui nostri passaggi alti** (da 1,7 m in su, `HEAD_PASS_LO`) a più di
  `HEAD_PASS_ZONE` 15 m nella metà avversaria (a centrocampo il salto resta automatico come prima), ma solo se un avversario è **attaccato** a chi colpisce (`headRival`: entro `HEAD_ATT_NEAR`
  2,5 m da lui, arriva entro `HEAD_ATT_R` 1,5 m dal punto al più `HEAD_ATT_T` 0,3 s dopo di lui e non dopo il pallone)
  e il nostro **vince il salto**, deciso col seme prima di aprire (`headDuelRoll`: come `aerialDuel`, `tes` più
  anticipo). In difesa la scritta è "Respingi!" e la linea è sempre un passaggio/rinvio di testa (anche se finisce in
  porta, `headCanShoot`); sul passaggio si tira solo entro 17 m dalla porta. Passaggio di testa lungo al massimo
  `HEAD_PASS_MAX` 30 m. **Senza linea entro 3 s, o col salto perso, colpisce l'avversario** (`headGive`: lui di testa
  con la sua IA, tiro o respinta se può, altrimenti `headRivalHit` a un compagno libero più avanti; il nostro non tocca
  il pallone). Senza avversario attaccato tutto come prima: il lancio sulla fascia si controlla e si corre. I cross in
  attacco (`kind` "att") restano identici. Prove: `--scena=testa_difesa|testa_difesa_linea|testa_passaggio|
  testa_passaggio_linea|testa_fascia`; test `godot/tests/test_testa_contesa.gd`.
  **Cross o filtrante** (Luis 2026-11-24, "l'attaccante la riceverebbe, la controllerebbe e andrebbe avanti"): il
  fermatempo "att" (e il colpo di testa automatico verso la porta, `airPlay`) vale solo sui **cross** (`headCross`):
  da angolo o punizione (`kick.rs`), partiti dalla fascia (oltre `HEAD_CROSS_X` 17 m dal centro, `kick.x0`) o che
  arrivano di traverso (più di `HEAD_CROSS_ANG` 35° dalla direzione della porta). Il lancio dritto dal centro verso la
  porta è un **filtrante**: l'attaccante lo controlla e va avanti (il salto conteso col difensore attaccato resta).
  Nel motore vale solo con l'opzione `"testa": true` (la mette il gioco; i confronti col JS restano identici).
- **Riprese senza teletrasporto** (Godot, Luis 2026-11-23, `godot/sim/riprese.gd`, opzione `"riprese": true` del Match
  messa dal gioco, spenta in allenamento/prove e nei confronti col JS): rimessa, rinvio dal fondo e angolo non hanno più
  il nero né il battitore messo sul posto. Il pallone esce e si ferma poco fuori; il battitore corre a prenderlo, si
  china, lo raccoglie e lo porta al posto (rimessa: 1-2 passi oltre la linea, dove l'ha raccolto entro 3 m dall'uscita). Rinvio e
  angolo col pallone lontano (oltre 9 m dal posto) o dietro la rete: lo prende il **raccattapalle** di quel fondo
  (`godot/sim/raccatta.gd`, due ragazzini in tuta giallo fluo, uno dietro ogni porta davanti ai cartelloni, grafica in
  `scripts/partita/raccattapalle_vista.gd`): corre al pallone sempre fuori dal campo girando intorno alla rete, si
  china, lo raccoglie, si gira e lo lancia a due mani (clip della rimessa) col pallonetto al battitore, poi torna
  camminando al posto; non è un giocatore, niente numeri casuali. Il pallone fermo non resta mai dentro la rete. La
  rimessa la va sempre a prendere il battitore. Rinvio e angolo: appoggia il pallone, fa
  2 m indietro un po' di lato e al calcio prende la rincorsa. Gli altri vanno di corsa ai loro posti; la telecamera segue
  il pallone (l'angolo entra piano nella sua visuale). Durante la scena (`restart.scena`) non si batte; un tocco la fa
  andare ×3 (`SCENA_VELOCE` in `gioco.gd`, vale anche per il raccattapalle). Rinvio e angolo vanno da soli al doppio della velocità
  (`SCENA_FONDO`, Luis 2026-11-23: metà del tempo): rimessa ~2,7 s, rinvio ~2,5 s, angolo e raccattapalle 2-4 s. Prove:
  `--scena=fuori_lato|fuori_fondo|fuori_fondo_vicino|fuori_rete|fuori_angolo`, sequenze con `--schermata=... --ogni=0.5 --dopo=6`.
  "Tutto nero" (Luis 2026-11-24): la meta del raccattapalle non sta mai dentro il rettangolo della rete
  (`raccattaFuoriRete`; prima, col pallone fermo nel fondo della rete, diventava NaN e trascinava pallone e telecamera);
  la telecamera scarta pose non finite (`posa_valida` in `telecamera_partita.gd`). Controllo a schermo spento, partite
  vere col dito finto: `-s res://tools/controllo_telecamera.gd -- --semi=4 --da=100 --nodi`; test `tests/test_nero.gd`.
- **Portiere** (Luis 2026-11-23): **predefinito automatico** (`gkManuale` false nelle Impostazioni, chiave nuova del
  salvataggio; la vecchia `autoGk` resta ma non conta, `Carriera.portiere_auto`): para il motore di sempre, secondo
  tiro e precisione del tiratore contro la bravura del portiere (misure: `tests/parate_fasce.gd`).
  Con `parata` il portiere automatico e quello della CPU sul tiro, dopo la reazione, vanno a passi laterali e si
  tuffano solo quando al pallone mancano `PARA_LEAD` 0,45 s (o il tempo che serve alla mano), come quello manuale
  (`_gkAutoTimed`, Luis 2026-11-24: "tirando dal centrocampo il portiere si butta a terra e la palla va in rete";
  prima da 48 m ne parava 5/12, ora 12/12). Nelle lezioni guidate
  sempre manuale. **Manuale (prova)**: sul tiro la visuale va dietro la propria porta e il tempo **si ferma** per 3 s
  veri (`scripts/partita/fermatempo_parata.gd`, `parata_regia.gd`, cerchio "Para!"), con un **bersaglio** rosso
  sulla porta (`bersaglio_tiro.gd`: ellisse che contiene il punto vero, centro spostato col seme, più grande con
  tiratore bravo e tiro forte) e la scia tratteggiata del volo fino al suo centro. Linea dal portiere al punto della
  porta = alzato il dito il tempo riparte e il portiere va verso quel punto (passi fino a `PARA_STEP`, tuffo quando
  al pallone manca `PARA_LEAD`), ma si ferma dove arriva (`PARA_DIVE_MAX` + bravura: un tiro forte nell'angolo
  lontano resta spesso gol). Finiti i 3 s senza linea fa da solo: dopo la reazione si tuffa verso il centro del
  bersaglio (tuffo `auto`, la lezione non lo conta). Motore `godot/sim/parata.gd`, opzione `"parata": true` del Match.

## Versione Godot (in costruzione)
- Cartella **`godot/`** (Godot 4.7.2-stable, GDScript, renderer Mobile, 390×844 verticale): `project.godot`,
  `export_presets.cfg` (preset `iOS` e `Windows Desktop`), `scenes/`, `scripts/`, `shaders/`, `assets/` (licenze in
  `godot/CREDITI.md`), `sim/` + `tests/` = motore in GDScript. Guida completa: `godot/README.md`.
- Coordinate: Godot X = x, Y = altezza, Z = −y (come three.js nel web), funzioni in `godot/scripts/coord.gd`.
- Comandi (G = `Godot_v4.7.2-stable_win64_console.exe`, in `C:\Users\forma\Documents\godot-tools`):
  `$G --headless --path godot --import` · `$G --headless --path godot -- --esci-dopo=4` (niente errori) ·
  `$G --path godot -- --schermata=shots/x.png --dopo=3` (anche `--vista=vicina|porta|alta`, `--senza-vsync`, `--prova-tocchi`).
- **Stellina del campione** (Luis 2026-11-24): quando il controllato è il campione (`src.champ`) sopra di lui c'è una
  stellina gialla (`TV.stellina()`, ×`STELLA_K` 1,1) al posto del triangolo (`vista.gd` `_aggiorna_segni`).
- **Maglie di casa e trasferta** (Luis 2026-11-24, `scripts/carriera/divise.gd`, applicate in `app.gd` `_partita`):
  casa = colori della squadra, trasferta = maglia fissa per colore (`TRASFERTA`, chiara per le scure e scura per le
  chiare). La squadra di casa veste quella di casa; l'ospite la sua di casa se si distingue (`SIMILI`), altrimenti la
  trasferta (poi colori invertiti, poi bianco/nero). In campionato fuori casa l'ospite sono io. Niente campi nuovi nel
  salvataggio. Test `tests/test_divise.gd`.
- I **Momenti chiave** sono stati tolti (Luis 2026-11-23): resta solo la partita intera. Il campo `settings.momenti` dei
  salvataggi vecchi resta ma non conta più.
- **Esultanze del campione** (15, `scripts/partita/mosse/esultanza.gd`, Luis 2026-11-25 "falle giuste"): oltre a
  braccia e gambe con la IK, ora si gira anche la **mano** (`mano(lato, t, dita, palmo, peso)`: le dita del modello non si
  piegano, conta dove puntano e dove guarda il palmo; `hq`/`hw` in `figura.applica_mossa`). Saluto con mano tesa e dritta
  alla tempia, cuore con le punte che si toccano, braccia conserte vere, mani dietro le orecchie, mano di taglio sulla
  bocca, mano sulla pancia nell'inchino. Prova: `-s res://tests/foto_esultanze.gd -- --busto|--zoom=2 --guarda=1.8
  --solo=saluto`; misure: `-s res://tools/misura_esultanza.gd -- --id=saluto --t=2`; test `tests/test_esultanze.gd`.
- Allenamento libero (tiri/punizioni/rigori a punti, record nel campo `prove` del salvataggio): `scripts/partita/prove_tiro*.gd`, menu `scripts/menu/allenamento_libero.gd`, prova `-- --prove=tiri --bot`.
- Meteo e ora della partita: `scripts/partita/meteo.gd` (prove: `--meteo=sereno|nuvoloso|pioggia|neve`, `--ora=giorno|tramonto|notte`).
- Build: workflow `.github/workflows/tiro-a-giro-godot-ipa.yml` (push su `tiro-a-giro` che tocca `godot/**`) →
  release **`tiro-a-giro-godot-ipa`**, `TiroAGiroGodot.ipa`, bundle `it.tiroagiro.godot` ("Tiro a Giro 3D"), iOS 15+,
  chip A12+. Il workflow web ignora i cambi solo in `godot/`.
