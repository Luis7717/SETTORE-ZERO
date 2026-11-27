# Decisioni prese in autonomia

Scelte fatte senza chiedere (regola: "nel dubbio la strada più semplice, annotata qui").

## Fase 1A — 2026-11-19

1. **Divisione di `sim.js`** in `src/sim/` (`core.js`, `ai.js`, `motion.js`, `match.js`).
   I metodi di IA e movimento sono classi separate i cui metodi vengono copiati su `Match.prototype`:
   è il modo più semplice di dividere una classe grande senza cambiare nessuna riga di logica.
   Confronto con l'impronta a seme fisso registrata prima: identico al primo colpo.
2. **Impronta rigenerata una sola volta**, alla fine della 1A, perché il comportamento del motore è cambiato
   di proposito (uscite, IA, portieri). Il refactoring di `kick()` (separato in `launch()` + `predictKick()`)
   è stato verificato a parte: 500 calci casuali identici al vecchio codice, stessi numeri casuali consumati.
3. **Obiettivo gol e tiri NON raggiunto** (regola dei tre tentativi). Con `test/balance.mjs` a pari forza:
   l'IA tira 8-11 volte, l'umano simulato 3-6; i gol totali restano circa 1 a partita (obiettivo 2-4).
   Il test resta in `test/unit/balance.test.mjs` come `todo`: si vede in `npm test` con i numeri veri.
   Cosa ho capito (utile per riprendere):
   - I tiri da 20-30 m li parano quasi tutti; i gol arrivano dai tiri in area, che sono pochi:
     la squadra arriva negli ultimi 30 m ma non entra in area (difesa schierata al limite, attaccanti fermi sulla linea del fuorigioco).
   - L'umano simulato è più "sterile" dell'IA perché la sua squadra pressa con un solo giocatore e le sue
     scelte col pallone sono quelle dell'IA ma contro una difesa che pressa e copre di più.
   - Prossimo passo sensato: inserimenti in area senza palla e passaggi corti al limite (uno-due), non altre soglie.
4. **Portieri un po' meno perfetti**: tuffo più lento (`GK_AI_SPEED`, `GK_HUMAN_SPEED` in `motion.js`) e reazione
   più lenta del portiere del computer. Il portiere comandato dal "bot" leggeva la traiettoria in modo perfetto
   e parava quasi tutto da 20 m. **Da provare sull'iPhone**: con un dito vero il tuffo potrebbe risultare troppo lento;
   in quel caso alzare `GK_HUMAN_SPEED`.
5. **Rimesse laterali sotto obiettivo** (circa 0,1-0,8 a squadra, obiettivo 2): restano come test `todo`.
   Ho aggiunto spazzate in fallo laterale, contrasti e deviazioni che spingono la palla verso la linea
   e gli esterni larghi in attacco, ma il gioco resta concentrato al centro.
6. **Angoli**: respinte del portiere (60% di quelle non bloccate) e tiri ribattuti in area (40%) finiscono oltre
   la linea di fondo, sempre fuori dai pali o sopra la traversa (testato: mai un gol da queste deviazioni).
7. **Tiri ribattuti**: un tiro si ferma su un difensore solo se lo prende quasi in pieno (0,6 m invece di 0,95):
   prima più di metà dei tiri finiva addosso a un difensore. L'IA ora controlla la linea verso il palo a cui mira
   davvero (prima guardava il centro della porta e tirava sul palo, dove stavano i difensori).
8. **Lanci e cross**: l'IA sceglie il lancio alto solo con più margine (si perdeva 1 lancio su 2) e il cross solo
   se il compagno in area è libero; i colpi di testa arriveranno nella 1B.
9. **Anteprima della traiettoria**: puntini azzurri calcolati con la stessa fisica del pallone e **senza** l'errore
   di mira (quello resta: il tiro vero può scostarsi un po'). Linea del fuorigioco rossa sul campo, nascosta su
   rimessa, rinvio e angolo (lì il fuorigioco non vale).
10. **A-capo LF**: aggiunto `.gitattributes` (`eol=lf`) e normalizzati i sorgenti; su Windows con `autocrlf`
    i file avevano a-capo misti.
11. **Salvataggi**: nessun cambio a `career.js` né alla chiave `tag_save_v1` in questa fase.

## Caricamento a pezzi — 2026-11-19

Regola nuova di Luis: niente più file unico né limite di 15 MB; `www/index.html` sotto 1 MB, file pesanti in
`www/assets/`, nessun file sopra 20 MB. Fatto per primo e da solo: i contenuti nuovi (stadio, menu, audio, modelli)
restano sui loro rami finché la build su GitHub di questo blocco non è riuscita.

1. **Manifesto dei file** in `assets/manifest.json` (tappe `match` e `music`), incorporato nel codice da `build.mjs`.
   I file elencati ma assenti vengono segnalati e tolti in build; a gioco avviato un file che fallisce si salta
   (testato in Node e con Puppeteer, `test/loading-shot.mjs`).
2. **I file si scaricano interi come ArrayBuffer** (`fetch`), poi chi li usa li decodifica (audio con
   `decodeAudioData`, modelli con GLTFLoader). Niente `<audio>`: così il gestore `app://` non deve gestire richieste a pezzi (Range).
3. **Schema `app://localhost/`** (se un giorno WebKit gestisse già `app`, l'app usa `tiroagiro://`). File serviti dalla
   cartella `www/` dentro l'app, con controllo che il percorso non esca da lì.
4. **Recupero del salvataggio**: la pagina `App/legacy.html` viene copiata nell'app esattamente dove stava la vecchia
   `index.html`, così ha la stessa origine `file://` e lo stesso `localStorage`. Legge `tag_save_v1` e lo passa all'app;
   l'app apre il gioco su `app://` passando il testo in `window.__legacySave`; `src/legacy-save.js` lo copia solo se nella
   nuova origine non c'è già un salvataggio. L'app smette di ripetere il passaggio solo quando la pagina conferma l'esito
   (se la copia fallisce riprova al prossimo avvio; il vecchio salvataggio resta comunque intatto nella vecchia origine).
   **La parte Swift non è stata provata**: qui c'è solo Windows. GitHub la compila, ma il funzionamento va provato sull'iPhone.
5. **Suoni**: `src/audio.js` usa i file veri se ci sono (id: crowd, goal, ooh, whistle, whistle_long, kick, post, net, music),
   altrimenti il suono sintetizzato di prima. Il manifesto per ora è vuoto: nessun contenuto nuovo entra in questo blocco.
6. **Tempo di apertura del menu**: misurato con `test/menu-time.mjs` (Chrome senza scheda grafica, servito via http,
   15 aperture, mediana): prima ~600 ms, dopo ~600 ms. Nessuna differenza perché prima non c'erano file pesanti
   incorporati: il guadagno si vedrà quando arriveranno modelli e audio, che non peseranno più sull'apertura.
7. **Prove a schermo via http**: `test/shot.mjs` ora serve `www/` con un piccolo server locale (`test/lib/serve.mjs`),
   perché con `file://` Chrome blocca il caricamento dei file in `www/assets/`.
8. **Correzioni dopo la revisione** (revisore automatico, nessun problema critico):
   se la vecchia origine non si lascia leggere l'app riprova al prossimo avvio invece di darla per vuota;
   l'attesa della pagina di passaggio sale a 8 s; il vecchio salvataggio resta anche come copia di sicurezza
   in UserDefaults (`legacySaveBackup`, mai cancellata) e comunque intatto nella vecchia origine;
   se il processo della pagina viene chiuso dal sistema il gioco si ricarica; ogni file ha 20 s di tempo massimo
   e una tappa con file falliti si riprova alla partita successiva.
   Caso limite rimasto: se la pagina di passaggio non risponde entro 8 s e Luis crea una nuova carriera, il vecchio
   salvataggio non viene copiato sopra (non si sovrascrive mai), ma resta recuperabile dalla copia di sicurezza.

## Contenuti integrati dopo il caricamento a pezzi — 2026-11-19

1. **Menu nuovi** (subagente Sonnet, ramo `wt-menu`): stili in `src/ui-style.js`, inseriti da `ui.js`. Le vecchie regole
   CSS del template restano (le nuove prevalgono); si possono togliere in una pulizia futura. `color-mix()` serve iOS 16.2+,
   sotto ripiega sul colore base.
2. **Stadio serale** (subagente Opus, ramo `stadio-grafica`): `src/stadium.js`, 7-9 draw call e ~15.500 triangoli.
   Costruito subito dopo il primo disegno del menu (non prima), così non ritarda l'apertura. Le luci della scena restano
   quelle di prima (giorno): da rivedere nella fase grafica se l'atmosfera serale stona.
3. **Suoni veri**: scelti dalla ricerca (tutti CC0 da Freesound, licenza ricontrollata sulle pagine). Ho usato le anteprime
   MP3 di Freesound (scaricabili senza account) e ritagliato i tratti misurando il volume (non posso ascoltarli):
   tifo costante 195-220 s e boato 109,6-116 s della registrazione Millerntor, "ooh" di Sandermotions, fischi, calcio, musica
   "Race song loop". Totale 1,5 MB in `www/assets/audio/`. Pallone sul palo e rete restano sintetizzati.
   **Da ascoltare sull'iPhone**: volumi relativi (`CROWD_SAMPLE_GAIN`, `KICK_SAMPLE_GAIN` in `src/audio.js`) e il piccolo
   stacco possibile a ogni giro del loop del pubblico (MP3 non è perfetto per i loop).
4. **Modelli 3D**: Kenney "Animated Characters: Protagonists" (CC0), convertito in GLB e ridotto a 720 triangoli
   (124 KB, `assets/models/player.glb`). Corsa e fermo sono clip veri; calcio, colpo di testa, scivolata, tuffo, a terra ed
   esultanza sono pose procedurali sulle ossa. Le draw call scendono da ~160-200 a ~55; i triangoli salgono di ~10 mila
   (accettato: per un iPhone 13 Pro 32 mila triangoli in scena sono pochi). Senza il file restano le figure a box.
   **Da provare sull'iPhone**: fps, cadenza della corsa (`RUN_REF`, `RUN_FULL` in `src/players3d.js`), leggibilità da lontano.

## Fase 1B (motore e gesti) — 2026-11-19

1. **Scatto**: nessun gesto nuovo. Tenendo premuto, se il dito è a più di 6 m dal giocatore controllato
   (`SPRINT_DIST` in `match.js`) il giocatore scatta: +16% di velocità a energia piena, solo +7% circa a energia 0,2
   (`SPRINT_BONUS`). Consuma energia 3,5 volte più in fretta (`SPRINT_DRAIN`); sotto 2,5 m/s l'energia si recupera
   (0,004 al secondo, vale per tutti i giocatori). `input.js` passa il flag come 4° argomento di `move`; se `main.js`
   non lo inoltra, `userMove` lo ricalcola uguale dalla distanza (così funziona già senza toccare `main.js`).
   Solo il giocatore comandato dall'umano scatta; l'IA non scatta.
2. **Finta**: scorrimento veloce col pallone (stessa soglia della scivolata) in una direzione che si scosta di almeno
   60° da quella di corsa (`FEINT_DOT`). Il portatore cambia direzione di colpo e per 0,3 s non può essere contrastato;
   ogni difensore entro 3,5 m che stava entrando (contatto, scivolata in preparazione, o in avvicinamento) resta
   sbilanciato 0,7 s con probabilità 0,5 + 1,5·(dribbling − difesa)/100, tra 15% e 85%. Ricarica 1,2 s.
   Scorrere in avanti non fa nulla (resta il vecchio "stop"). L'IA non fa finte.
   Se `out.feint` non esiste (oggi `main.js` non ce l'ha) `input.js` chiama direttamente `match.userFeint`.
3. **Colpi di testa e al volo**: un attaccante su un lancio alto di un compagno, entro 17 m dalla porta, colpisce verso
   la porta di testa (pallone tra 1,3 e 2,6 m) o al volo (tra 0,5 e 1,3 m) invece di stoppare. Un difensore entro 32 m
   dalla propria porta respinge di testa i palloni alti (1,3-2,6 m) che non sono della sua squadra. Altrove un pallone
   sopra 1,7 m resta ingiocabile come prima. Sui lanci vicino alle porte i giocatori ora vanno incontro al pallone fino
   a 2,4 m d'altezza (`AIR_REACH` in `ai.js`), altrimenti non ci arrivava quasi mai nessuno (0,1 colpi di testa a partita).
   Il colpo verso la porta mira al palo lontano dal portiere (75%) con errore di direzione e altezza (`this.gauss`) che
   dipende da tiro (+ fisico per la testa) e cresce se c'è un avversario addosso. Il fuorigioco sul cross si fischia anche
   se si colpisce di testa. Statistiche nuove: `stats.headers`, `stats.volleys` (contano anche come tiri).
   Per l'umano è automatico, come chiesto: chi è in zona e riceve il pallone alto colpisce verso la porta.
4. **Barriera**: punizione entro 30 m dalla porta → 2 (da molto defilato), 3, 4 o 5 (sotto 20 m) difensori a 9,15 m,
   sulla linea tra pallone e un punto a metà tra centro e palo vicino; stanno fermi finché si batte (`p.wall`).
   `restart.wallSide` dice il lato coperto; il computer tira sul lato opposto. La respinta la fanno i contatti di sempre.
   L'attesa del computer prima di battere sale di 0,6 s quando c'è la barriera.
5. **Vantaggio**: fallo (non in area, non da rosso) su un portatore che tiene il pallone da 5 m prima della metà campo in
   avanti, senza un altro avversario entro 3 m → si gioca (evento `advantage`). Se entro 2,5 s la squadra perde palla →
   punizione nel punto del fallo (`advantage_back`); se tira o passano i 2,5 s → finito (`advantage_over`).
   Il fallo e l'eventuale giallo restano segnati subito. In partita è raro (le scivolate fallose in attacco sono poche).
6. **Difficoltà per divisione**: la forza delle squadre già sale con la divisione (valutazioni 50-60, 60-70, 70-82 →
   abilità circa 0,23 / 0,44 / 0,71); in più `career.skillOf` aggiunge 0,08 in Prima e 0,04 in Seconda (`DIV_SKILL`).
   Amichevoli: si usa la mia divisione. Nessun campo nuovo nel salvataggio.
7. **Numeri** (stessi semi, 20 partite, prima → dopo):
   `npm run balance -- 60 60 20`: gol 0,5-0,6 → 0,3-0,8, tiri 4,2-8,3 → 6,0-10,3, possesso 49% → 45%.
   `node test/diag-flow.mjs 60 20 bot`: umano tiri 5,8 → 5,5, gol 0,3 → 0,1; IA tiri 8,8 → 10,3, gol 0,4 → 0,9;
   colpi di testa verso la porta: umano 0,1, IA 0,8 a partita (+0,1 al volo), un terzo dei gol dell'IA arriva così;
   respinte di testa ~2 a squadra. Lo scatto da solo non cambia i numeri (provato spegnendolo: 0,3-0,7).
   **L'umano simulato non ne guadagna**: crossa poco e ha meno angoli; i suoi gol erano già pochissimi (vedi 1A, punto 3).
   Obiettivo 2-4 gol a partita ancora non raggiunto: i due test `todo` restano.
8. **Impronta rigenerata una volta** alla fine (`npm run golden:update`), con tutto il resto verde.

## Richieste del 2026-11-19 sera (dopo la prova sull'iPhone)

1. **Allenamento**: per ogni meccanica una scheda di spiegazione e poi 3 prove in 3 situazioni diverse
   (passaggio, tiro, corsa e scatto, finta, recupera palla, scivolata, dribbling, portiere). Parte da solo alla
   creazione della squadra (con "Salta l'allenamento"); le pagine "Come si gioca" restano nel menu.
   In allenamento non ci sono espulsioni né stanchezza: ogni prova riparte pulita.
2. **Duello col difensore**: telecamera più bassa e più avanti, anelli verdi sotto i 3 compagni più liberi,
   tempo al 35% (`DUEL_SLOW` in main.js, `DUEL_LOW`/`DUEL_MATES` in render.js), tasto giallo **Dribbling** in basso.
   La regola del duello e del dribbling è nel motore (subagente, sezione "Duello e statistiche").
3. **Statistiche**: "si abbassa" interpretato come calo DENTRO la partita (torna pieno alla partita dopo):
   velocità che cala col tempo in base alla resistenza (= `fis`), dribbling e colpi di testa che calano un poco
   a ogni successo. Statistica nuova "colpi di testa" (`tes`), calcolata per i giocatori dei salvataggi vecchi.
   Ricordate a Luis le due che non aveva elencato: passaggio e portiere.

## Duello e statistiche (motore) — 2026-11-19

1. **Duello** (`src/sim/duel.js`, costanti in cima): si apre quando il portatore della squadra umana, se è il giocatore
   controllato, ha un avversario (in gioco, non stordito) **davanti** entro 4,5 m (`DUEL_R`). "Davanti" = entro ~70° dal
   verso di corsa (`DUEL_FRONT`); se è quasi fermo conta il verso in cui guarda. Stato: `m.duel = { team, p, o, t }`.
   Eventi `duel_start { p, o }` e `duel_end { p, o, reason }`, con `reason` uno fra `'passaggio'` (il portatore calcia,
   tiri compresi), `'dribbling'` (dribbling riuscito), `'palla persa'` (contrasto, dribbling fallito, pallone perso),
   `'lontano'` (avversario oltre 6,5 m o alle spalle), `'tempo'` (2,5 s, `DUEL_MAX`) e in più `'gioco fermo'`
   (rimessa, fallo, gol, fine tempo, sostituzione). Dopo la fine lo stesso portatore non riapre un duello per 1 s (`DUEL_CD`).
   `m.duelFor(T)` è vero solo mentre esiste il duello della squadra T. Per l'IA non si apre mai un duello (niente
   rallentatore né protezione): l'IA usa solo la regola del dribbling.
2. **hint**: ho scelto la via più semplice, `m.hint(T)` resta `'attack'` durante il duello (così `input.js` lascia
   disegnare il passaggio senza modifiche); il duello si chiede con `m.duelFor(T)`.
3. **Finestra di protezione**: per i primi 0,6 s di tempo partita (`DUEL_GUARD`) il difensore del duello non ruba palla
   (niente contrasto a contatto, non prepara né completa la scivolata). Gli altri avversari sì.
4. **Dribbling**: `m.userDribble(T)` (true se il tentativo parte; l'esito con l'evento `dribble { p, o, ok }`).
   Riuscita = 0,5 + 1,2·(dribbling − difesa)/100, tra 15% e 85%, tirata con `this.rnd()`. Riuscito: il portatore scatta
   oltre il difensore (3 m oltre, 2,5 m di lato; verso il centro se è vicino alla linea laterale), il difensore resta
   sbilanciato 0,8 s, il portatore non è contrastabile per 0,35 s. Fallito: entro 2 m il difensore prende il pallone
   (60%) altrimenti lo devia verso di sé; il portatore resta fermo 0,35 s. Ricarica 1,2 s per giocatore (`DRIB_CD`).
   L'IA (e quindi anche l'umano simulato dei test) prova il dribbling quando non ha scelto un passaggio e ha un
   avversario davanti entro 3,2 m: probabilità 22% + (dribbling − difesa)/100, tra 5% e 60% (`AI_DRIB_TRY`).
5. **Colpi di testa `tes`**: `effStats` lo legge dal giocatore se c'è, altrimenti lo ricava con `headingOf(src)`
   (`core.js`): media di fisico e tiro, +8 difensori, +2 attaccanti, −1 centrocampisti, −5 portieri, più una piccola
   variazione fissa (−4..+4) presa dalle altre statistiche, senza numeri casuali. **Non viene scritto nel salvataggio.**
   `genPlayer` lo scrive per i giocatori nuovi con la stessa formula: così non consuma numeri casuali in più e le squadre
   avversarie (rigenerate dal seme a ogni partita) restano identiche a prima. Vale anche la penalità di ruolo.
   Limite: per ora `tes` salvato non cresce con l'allenamento né cala con l'età (quello ricavato segue fis e tir).
6. **Dove si usa `tes`** (prima faceva da colpo di testa la media tiro + fisico): precisione e forza del colpo di testa
   verso la porta, forza e direzione della respinta di testa (prima solo caso), e il nuovo **contrasto aereo**: se sul
   pallone alto (da 1,3 m) arrivano giocatori di tutte e due le squadre, vince con probabilità
   0,5 + 1,5·(differenza tes)/100 + 0,6·(metri di vantaggio), tra 15% e 85% (evento `aerial { p: vincitore, o }`).
   Il tiro al volo resta sul tiro.
7. **Stanchezza dentro la partita** (`p.wear = { dri: 1, tes: 1 }`, creato a ogni partita nuova, `substitute` lo riporta a 1):
   ogni dribbling riuscito −3% del dribbling effettivo fino all'80% (`WEAR_DRI`), ogni colpo di testa vinto (verso la
   porta o respinta) −2% di `tes` fino all'85% (`WEAR_TES`). Il calo è applicato direttamente a `p.st`.
   Velocità: c'era già ed è stata solo resa chiara: `vmax` scende fino all'86% (`SPEED_TIRED` in `match.js`) quando
   `p.energy` va verso 0,2; l'energia cala correndo, più piano con più fisico (`fis` = resistenza), più in fretta nello scatto.
8. **Numeri** `node test/diag-flow.mjs 60 12 bot`, prima → dopo: umano tiri 5,4 → 6,3, gol 0,2 → 0,7; IA tiri 8,8 → 9,7,
   gol 0,9 → 0,6. Dribbling a partita: umano simulato 2,4 (1,3 riusciti), IA 2,8 (1,3 riusciti). Duelli dell'umano
   simulato ~41 a partita ma brevissimi (0,2 s in media, quasi tutti chiusi col passaggio): l'umano simulato passa
   subito; un giocatore vero, col rallentatore, li terrà aperti di più. **Da guardare sull'iPhone**: se i duelli sono
   troppi, alzare `DUEL_CD` o abbassare `DUEL_R`. La protezione di 0,6 s aiuta l'umano.
9. Impronta rigenerata una volta alla fine (`npm run golden:update`), con tutto il resto verde.

## Corsa a strada e parata con linea — 2026-11-20

1. **Fuori dal duello niente passaggi**: col pallone la linea disegnata dal giocatore è la **strada da correre**
   (`userPath` nel motore, testato); scatta finché davanti restano più di 6 m di strada. Una linea che finisce in porta
   resta un **tiro** (Luis non l'ha escluso: scelta mia, la più semplice). Il passaggio si fa solo nel duello o sulle
   rimesse (disegnando o toccando il compagno). La regola è nei comandi (`input.js`), non nel motore: il computer
   continua a passare come prima. "Tieni premuto" per correre resta come alternativa.
2. **Parata**: sul tiro avversario la visuale va bassa dietro la propria porta (`GK_CAM_BACK`, `GK_CAM_H` in render.js)
   e il tempo va al 25% (`GK_SLOW`). Si tira una linea dal portiere al punto della porta; il tuffo parte quando si alza
   il dito, verso quel punto. Se il punto è lontano dal portiere o il dito si alza tardi non ci arriva: la portata
   dipende già da velocità del tuffo e statistica di parata (`GK_HUMAN_SPEED` + `por`) e dal tempo che manca al pallone.
3. Allenamento e "Come si gioca" aggiornati: passaggio provato davanti a un difensore, corsa disegnando la strada,
   parata con la linea.

## Difesa a linee e raggio di intercetto — 2026-11-20

1. **Linee in difesa**: dito su un proprio giocatore (non il portiere) e si disegna la strada: lui la segue (`userRun`
   nel motore, testato). Al massimo **3** linee insieme: la quarta sostituisce la più vecchia, una nuova dello stesso
   giocatore sostituisce la sua. Le linee si cancellano quando la squadra riprende palla. Con tanta strada davanti scatta.
   A schermo resta il tratto ancora da fare (azzurro, sottile: WebGL disegna linee da 1 px; da ingrossare se serve).
2. **Scivolata**: dal giocatore controllato un tratto **rapido e corto** (meno di 250 ms, `SLIDE_FLICK_MS` in input.js) è
   ancora la scivolata; più lento o più lungo è una linea. Lo scorrimento veloce partendo dal campo vuoto resta scivolata.
   Tocco su un compagno = passi a comandarlo.
3. **Raggio difensivo sui passaggi** (`reachOf` in motion.js): 0,95 m a parità 60 contro 60, +0,008 m per ogni punto di
   difesa del difensore, −0,008 m per ogni punto di passaggio di chi passa, tra 0,6 e 1,35 m. Vale per tutti (anche il
   computer), quindi l'impronta a seme fisso è stata rigenerata. Diagnosi (12 partite, bot): passaggi riusciti umano 88%,
   computer 94%; gol umano 0,7, computer 0,5.

4. **Correzione di Luis (2026-11-20)**: niente limite di 3 linee: tutti i giocatori di movimento possono avere la loro linea, il portiere no.

## Editor e dettaglio giocatori — 2026-11-20

Richiesta di Luis: giocatori molto più dettagliati, editor all'inizio (occhi e colore, tagli di capelli, stile della
maglia, maniche, calzettoni…), poi nome e numero sulla schiena e uno stemma inventato per ogni squadra con il suo editor.

1. **Modello**: resta il Kenney "Animated Characters: Protagonists" (CC0) già nel gioco (`assets/models/player.glb`,
   124 KB, 720 triangoli). La versione non semplificata (1.604 triangoli) non si è potuta scaricare: il sito di Kenney dà il
   file solo da una sessione del browser. Il dettaglio in più viene da:
   - **capelli veri**: una calotta generata dal codice attorno alla testa (raggi dal centro della testa contro i suoi
     triangoli, più lo spessore del taglio), agganciata all'osso `Head` e **fusa nella stessa geometria** del corpo:
     resta **1 draw call per giocatore**. 17 tagli (calvo e rasato solo dipinti; coda e chignon con un pezzo in più).
     Da 720 a 1.380 triangoli per giocatore (il più pesante: "Lunghi"). Geometrie in cache per taglio e vestibilità.
   - **texture 512×512 per giocatore** (era 256 condivisa): viso con occhi (6 forme, 7 colori, iride, pupilla, riflesso),
     sopracciglia (6), barba (7), naso, bocca, orecchie, cute sotto i capelli con attaccatura morbida che segue il taglio;
     maglia con motivo, colletto, maniche, stemma sul petto, **cognome e numero sulla schiena**; pantaloncini con banda,
     calzettoni bassi/alti/ripiegati, scarpe colorate con fascia, guanti per il portiere. Nell'editor la texture è 1024.
   - **maglia larga o aderente**: il busto si gonfia o si stringe un poco lungo le normali (geometria a parte in cache).
2. **Aspetto persistente**: `p.look = { skin, hair, hairColor, eyes, eyeColor, brows, beard, boots }` (indici in
   `src/looks.js`). Senza `look` (salvataggi vecchi, mercato, demo) l'aspetto si calcola da id e nome, sempre uguale, e
   **non si scrive** nel salvataggio. Il motore (`Match.lookFor`) usa l'aspetto del giocatore sorgente e consuma lo stesso
   numero casuale di prima: l'impronta a seme fisso non cambia. Avversari: aspetto dal seme della squadra.
3. **Stile della divisa** (`s.kitStyle`): maglia aderente/larga, maniche corte/lunghe/senza, colletto girocollo/a V/polo,
   motivo tinta unita/righe verticali/orizzontali/banda diagonale/metà e metà, pantaloncini corti/lunghi, calzettoni
   alti/bassi/ripiegati. Predefinito: tutto al primo valore. Portiere: maniche lunghe, tinta unita, guanti.
   Avversari: stile dal seme.
4. **Numeri di maglia** (`p.num`): ai salvataggi vecchi vengono assegnati al caricamento, per ruolo (portieri 1, 12, 22;
   difensori 2-6…; centrocampisti 8, 10, 7…; attaccanti 9, 11…) senza doppioni; chi viene comprato ne riceve uno libero.
   Il campione sceglie il suo: se era di un altro, l'altro ne prende uno libero. Avversari: 1-11 per posizione.
   Sulla schiena il cognome in maiuscolo; colore nel secondario della squadra se si legge, altrimenti bianco o nero.
5. **Stemma** (`s.crest = { shape, pattern, icon }`, `src/crest.js`): 10 sagome, 10 motivi, 20 simboli disegnati qui
   (pallone, stella, leone, aquila, torre, corona, fulmine, quercia, onda, sole, ancora, chiave, spiga, lupo, cavallo,
   ruota, montagna, fiamma, giglio, toro). Colori dalla maglia. Senza `s.crest` si calcola dal nome del club.
   Squadre del computer: dal loro seme. Sostituisce il vecchio stemma in hub, prossima partita, classifica, calendario,
   risultato; piccolo sul petto della maglia in partita.
6. **Editor**: dopo nome e colori della squadra → "Lo stemma" (Forma, Motivo, Simbolo) → "Crea il tuo campione"
   (Viso, Capelli, Divisa, Nome e ruolo) con anteprima 3D che ruota (renderer three.js dedicato nel canvas della
   schermata, spento uscendo; si gira col dito; primo piano per viso e capelli). La carriera nasce solo alla conferma
   finale; il campione entra in rosa come un giovane forte della Terza Divisione (livello `CHAMP_LEVEL` = 62, età 17-21).
   Rosa → scheda giocatore → "Aspetto" (Viso, Capelli, Scarpe). Impostazioni → "Stile della divisa" e "Stemma".
7. **Numeri** (`node test/players-shot.mjs`, Chrome headless con SwiftShader, 390×844): prima scena 61 draw call /
   32.294 triangoli (giocatori 37 / 15.870), dopo 57 / 42.208 (giocatori 33 / 25.776); fps 26,9 → 25,9 (solo confronto);
   `view.update` 0,34 → 0,31 ms. Memoria in più: 22 texture 512 (~1,4 MB l'una con le mipmap, ~30 MB in tutto).
   **Da provare sull'iPhone**: fps, tempo d'ingresso in partita (22 texture dipinte), leggibilità di numeri e visi.

## 2026-11-20 — Finta tolta, duello prima, area di tiro, passaggio a chiunque
- **Finta tolta** su richiesta: niente gesto, niente lezione nel tutorial (ora 7 lezioni), tolti `userFeint`/`feint` dal motore e il loro test.
- **Duello prima**: `DUEL_R` da 4,5 a 7 m (chiusura per lontananza da 6,5 a 9,5 m). Umano simulato: circa 52 duelli a partita (prima circa 40).
- **Area di tiro**: negli ultimi `ZONE_DIST` = 20 m prima della porta avversaria, col pallone tra i piedi del controllato,
  il tempo va al 40% (`ZONE_SLOW`) e si può passare: linea in porta = tiro, linea che finisce entro 5 m da un compagno
  (o tocco sul compagno) = passaggio, linea altrove = strada da correre (così si può ancora entrare in area palla al piede).
  Il duello ha la precedenza (35%, tasto Dribbling). Metodi `inZone(T)`, `passFor(T)` in `src/sim/duel.js`, con test.
- **Anelli verdi tolti**: nel duello e nell'area di tiro si passa a qualunque compagno. Resta solo il cerchio sul
  ricevitore mentre il dito sta disegnando il passaggio, come conferma di chi riceverà.
- Impronta golden rigenerata (cambia il raggio del duello).

## 2026-11-20 — La CPU non difende al posto della persona, scivolata tolta, rallenty più lento
- **Squadra umana senza palla** (avversario in possesso, o pallone libero che non viene da un nostro passaggio/tiro):
  si muove solo chi ha una linea disegnata, e il controllato col dito tenuto premuto o col tocco sul campo. Tutti gli
  altri restano **fermi** (`manualDef(T)` in `src/sim/ai.js`). Il portiere resta automatico nel piazzamento.
  In attacco i compagni senza palla si smarcano ancora da soli (servono per passare).
- Linea di difesa: l'ultimo punto va raggiunto davvero (`RUN_END_REACH` = 0,4 m invece di 1,3), così una linea
  disegnata fin sull'avversario arriva al contrasto.
- Tutorial "Recupera palla": l'avversario col pallone resta fermo (prima, libero di muoversi, passava a vuoto e
  perdeva palla da solo, e il nostro controllato lo inseguiva in automatico). Si supera solo disegnando la linea.
- **Scivolata tolta** dai gesti e dal tutorial (ora 6 lezioni). Nel motore `userSlide` resta solo per le prove a schermo;
  l'IA avversaria entra ancora in scivolata.
- **Rallenty più lento**: duello 20% (era 35%), area di tiro 22% (era 40%), parata 15% (era 25%), mentre si disegna
  la corsa 30% (era 50%), mentre si disegna una linea di difesa 18% (era 30%).
- Bot dei test: insegue col dito anche il pallone libero (come farebbe una persona). Impronta golden rigenerata.
- **Scivolata tolta anche all'IA** (richiesta successiva): il pressatore avversario ruba palla solo col contatto.
  Il motore della scivolata resta (prove a schermo e test dei falli). Effetto: i falli venivano quasi solo dalle
  scivolate, quindi ora punizioni, cartellini e rigori per fallo saranno rarissimi. Impronta golden rigenerata.

## 2026-11-20 — Giochetti nel dribbling
- Solo grafica (`src/tricks.js`, pose in `src/players3d.js` `trickPose`, pallone spostato in `src/render.js`): il motore
  decide se il dribbling riesce, la grafica sceglie come farlo vedere. Nessun cambio al motore né all'impronta golden.
- Sei giochetti in ordine di bellezza: finta di corpo, doppio passo, elastico, veronica, sombrero, colpo dell'arcobaleno.
  Il più bello possibile si sblocca ogni 10 punti di dribbling da 35 in su (85+ = arcobaleno); di solito si fa il più
  bello che si sa fare (60%), a volte uno o due più semplici. Si usa il dribbling del momento (cala con l'uso).
- Valgono anche per gli avversari. Per i nostri compare il nome del giochetto in grande.
- Prova a schermo: `node test/tricks-shot.mjs shots`.

## 2026-11-20 — Tutorial passaggio più largo, telecamera più vicina
- Lezione Passaggio: il difensore parte a 11 m (`PASS_DEF_DIST`; prima 3,5 m, il duello si apriva subito), compagni
  un po' più lontani. Prima si corre verso il difensore, poi nel duello si passa.
- Telecamera di gioco (verticale): `CAM_BACK` 16 m dietro il pallone e `CAM_H` 10,5 m d'altezza (prima 22 e 16,5);
  l'allargamento su rimesse e disegno pesa meno (+6/+5 m invece di +10/+11). Giocatori più grandi a schermo.

## 2026-11-20 — Rallenty ancora più lento, visuale del duello verso i compagni
- Rallenty −5 punti: duello 15%, area di tiro 17%, parata 10%, mentre si disegna la corsa 25%, linea di difesa 13%,
  mentre si disegna un passaggio o tiro 8% (`PASS_DRAW_SLOW`, prima 13%).
- Visuale del duello (`duelSide` in `render.js`): se c'è almeno un compagno davanti (entro 35 m, cono di ~45°) resta
  dritta, un po' più alta e lontana di prima (`DUEL_LOW` 0,3, `DUEL_BACK`); se no gira intorno al portatore verso il
  lato con più compagni, dell'85% dell'angolo verso la loro media, al massimo ~70°. Prova: `node test/duel-side-shot.mjs shots`.

## 2026-11-20 — Telecamera in difesa larga, tutorial sistemato
- In difesa (avversario col pallone o pallone libero) la telecamera **non si avvicina**: zoom largo, più indietro di
  `DEF_BACK` 6 m, più alta di `DEF_UP` 6 m e con lo sguardo 12 m più verso la propria porta, per vedere e muovere più
  difensori. Tolta l'inquadratura bassa da dietro la propria porta quando l'avversario si avvicina (resta solo quella della parata).
- La telecamera segue col **tempo vero** (`view.rdt`), non col tempo rallentato: nel rallenty non resta più indietro.
  Se il pallone salta di più di 12 m (nuova prova del tutorial) ci va subito.
- Vicino alla porta avversaria la telecamera si avvicina solo con la palla verso il centro: sulla fascia
  (|x| > 4 m, del tutto da 12 m) resta normale, così il portatore non esce dallo schermo (tutorial Tiro, prova 2).
- Tutorial: ogni prova cancella le linee di difesa rimaste (`m.runs`) e il gesto in corso; prima in "Recupera palla" il
  giocatore poteva partire da solo su una linea vecchia. Prova a schermo: `node test/tut-lessons-shot.mjs shots`.

## 2026-11-20 — Corpo rifinito a parti (busto, gambe, testa), braccia da fermo
- Uniti busto (`src/body/busto.js`), gambe (`src/body/gambe.js`) e testa (`src/body/testa.js`), ognuno chiamato da
  `src/athlete3d.js` con una riga; ordine: testa, busto, gambe. Il test delle gambe ora confronta col modello che ha già testa e busto.
- **Posa da fermo**: `IDLE_FIX.arms` da 0,28 a −0,05 rad. La vecchia chiusura delle braccia, pensata per le braccia
  corte del primo modello, con le braccia nuove (dita a 3,3 T) metteva mani e avambracci dentro cosce e busto:
  da davanti il giocatore sembrava senza braccia e le dita spuntavano dai pantaloncini come una macchia color pelle.
  Due test lo controllano (`gambe.test.mjs`, `busto.test.mjs`). Non controllato: le mani durante la corsa.
- **Da provare sull'iPhone**: giocatore fermo da davanti, di lato e da dietro; visi e capelli sulla testa nuova.

## 2026-11-20 — Menu principale col campione che si allena, editor opaco
- **Menu principale** (schermata iniziale e hub): tolta la partita dimostrativa sullo sfondo. Al suo posto il campione
  della carriera (o, senza carriera, un giocatore coi colori scelti) che si allena in trasparenza: palleggi, un
  giochetto (a ogni giro il successivo dei sei), corsa palla al piede, tiro (`src/menu-routine.js`, funzione pura con
  test; `src/menu-bg.js`, renderer dedicato in un canvas fisso dietro il menu, acceso solo su quelle due schermate).
  Schede del menu semitrasparenti lì sopra. Il modello sta nella tappa `match`, che quindi si scarica in sottofondo già
  al menu (come faceva l'editor): il menu è usabile subito, il campione compare appena pronto.
- **Menu trasparenti sull'iPhone**: `color-mix()` con `var()` dentro, sui Safari che non lo conoscono, rendeva vuoto lo
  sfondo (non basta una regola di riserva prima: la regola diventa invalida solo al calcolo). Ora i colori della
  squadra mescolati sono variabili CSS calcolate in JS (`teamMixVars`). Si vedeva la partita dietro i menu e le
  opzioni dell'editor scorrevano dietro l'anteprima.
- **Forme degli occhi** visibili: palpebre dipinte nella finestra davvero visibile del bulbo (`src/body/occhi.js`).

## 2026-11-20 — Visuale della parata con la porta intera, visuale larga nel rallenty in attacco
Richieste di Luis dopo la prova sull'iPhone: "quando devo parare a volte non vedo nemmeno tutta la porta" e "durante il
rallenty deve allargare un po' la visuale, direi un 180 gradi almeno, ho più scelte".
- **Inquadratura calcolata** (`src/camfit.js`, conti puri testati in Node): con l'orientamento della telecamera fissato,
  `fitView` la sposta di lato e all'indietro lungo l'asse finché i punti scelti stanno nel riquadro coi margini (punteggio
  in alto, suggerimento e Dribbling in basso); se arretrare non basta allarga il campo visivo; se nemmeno così salta i
  punti meno importanti (prima i più lontani). La telecamera insegue l'inquadratura col tempo vero (`POSE_K` 5/s in
  `render.js`) ed entra/esce con una transizione morbida.
- **Parata** (`saveView`): telecamera dietro la propria porta, girata verso chi tira dell'80% dell'angolo del tiro (al
  massimo ~54°, `SAVE_YAW_K`, `SAVE_YAW_MAX`), parte 7 m dietro la linea (`SAVE_BACK`) e arretra fino a 15 m
  (`SAVE_MAX_BACK`, la tribuna di fondo è a 18 m), poi allarga il campo visivo fino a 96° (`SAVE_FOV_MAX`). Tiene
  **sempre** la porta intera con 0,9 m di margine ai lati e 0,7 m sopra la traversa (`SAVE_PAD`, `SAVE_PAD_TOP`) e il
  portiere; poi il pallone. Tolte `GK_CAM_BACK`/`GK_CAM_H`. Prima, in verticale, a 6,5 m dalla porta si vedevano solo
  ~4 m di larghezza: i pali restavano fuori in tutti e 5 i tiri provati. Il prezzo: la porta è più piccola a schermo
  (occupa la larghezza dello schermo, non di più).
- **Rallenty in attacco** (`wideView`): nel duello, nell'area di tiro e mentre si disegna col pallone (`view.drawing` da
  `main.js`) la telecamera va più alta e più indietro (inclinata ~38°, `WIDE_PITCH`), guarda 13 m davanti al portatore
  (`WIDE_AHEAD`; nell'area di tiro non oltre 6 m prima della porta) e tiene a schermo il portatore (con 2,5 m d'aria ai
  lati), nell'area di tiro la porta avversaria, poi i compagni entro 35 m davanti o di fianco (`WIDE_R`, `WIDE_BEHIND`),
  dal più vicino. Distanza 22–36 m (`WIDE_MIN_DIST`, `WIDE_MAX_DIST`), campo visivo fino a 88° (`WIDE_FOV_MAX`).
  La rotazione del duello verso il lato con i compagni (`duelSide`) resta com'era.
- **Limite onesto**: in verticale "180°" alla lettera non ci sta. Un compagno 25 m di fianco **sulla stessa linea** del
  portatore entra solo con il portatore alto ~16 px: resta fuori (c'è un test che lo dice). Entrano i compagni larghi un
  po' più avanti (la visuale si allarga con la distanza) e, nel duello senza nessuno davanti, la visuale gira verso di loro.
  Il portatore scende fino a ~27–30 px nei casi più larghi (era 45–75 px); l'anello giallo e la freccia restano.
- Prove: `node --test test/unit/camfit.test.mjs` (telecamera three messa come in render.js: pali, traversa, portiere,
  pallone, compagni tenuti = compagni a schermo); a schermo `node test/save-cam-shot.mjs shots` (5 tiri: prima 4–5 punti
  della porta fuori per tiro, ora nessuno) e `node test/wide-cam-shot.mjs shots` (duello, area di tiro, disegno).
- **Da provare sull'iPhone**: parate da vari punti (si vede tutta la porta? la linea dal portiere si tira bene anche
  con la porta vista di sbieco?); nel duello e nell'area di tiro, i compagni larghi ora a schermo e il portatore non
  troppo piccolo; mentre si disegna la corsa la telecamera si sposta un poco nei primi istanti (il disegno resta
  attaccato al campo). Se il portatore è troppo piccolo: abbassare `WIDE_MAX_DIST`/`WIDE_FOV_MAX` in `src/camfit.js`.

## 2026-11-20 — La squadra umana senza palla torna a muoversi (pressing, rientro, smarcamento), linee corte, scatto visibile
Richieste di Luis dopo la prova sull'iPhone: "in difesa restano tutti fermi e in attacco", "non fanno pressing",
"linee di difesa troppo lunghe", "rendilo più magnetico", "l'intercetto in corsa rimbalza", "lo scatto non si vede",
"non passo il centrocampo, si raggruppano". **Cambia la regola "La CPU non difende al posto della persona"** (sopra).
- **Difesa senza linea né dito** (`humanDefend` in `src/sim/ai.js`): la linea disegnata vale sempre più di tutto
  (anche del pressing), il controllato col dito segue il dito; tutti gli altri li muove la CPU:
  - **pressing**: il più vicino al portatore va sul pallone e prova a rubarlo (`hPress`, calcolato con
    `computeChasers`); due se il portatore è nella nostra trequarti (`HUM_PRESS_ZONE` = 33 m dalla nostra linea di fondo).
    Chi pressa già conta come 4 m più vicino (`HUM_PRESS_KEEP`), così due quasi alla pari non si scambiano di continuo.
    Il controllato fa parte del conto: se la persona lo sta già portando sul portatore la CPU non ne aggiunge un altro.
  - **posizione**: posto di squadra (`anchor`) con marcatura a zona dell'avversario più vicino (`HUM_MARK_R` 7,5 m);
    difensori almeno `HUM_BEHIND_D` = 2 m dietro la palla, centrocampisti al massimo 1 m davanti (`HUM_BEHIND_C`) e
    stretti sulla linea palla-porta (`HUM_MID_LANE` 0,3: chiudono i passaggi centrali); chi non pressa resta ad almeno
    `HUM_SCREEN` = 4 m dal portatore. Lontano più di `HUM_RECOVER` = 8 m dal posto, verso la propria porta: rientro con lo scatto.
  - **pallone vagante** (rimpallo, contrasto): ci va il più rapido. I **passaggi avversari in volo no**: l'intercetto
    resta alla persona (col pallone in volo la CPU che correva a intercettare toglieva all'IA quasi tutti i tiri).
  - Allenamento "Recupera palla": `m.autoDef[0] = false` (lezione con `noAutoDef`), lì chi non ha linea resta fermo.
- **Linee di difesa corte**: `RUN_MAX_LEN` = 14 m dal giocatore (`clipLen` in `src/sim/match.js`), tagliate nel motore e
  già mentre si disegnano (`src/input.js`; `render.js` disegna `r.path`, quindi la linea si vede tagliata senza toccarlo).
  Finita la linea il giocatore torna subito alla CPU; se è finita addosso al pallone resta attaccato al pallone per
  `HUM_STICK_T` = 1,5 s.
- **Contrasto magnetico** (solo per chi muove la persona: controllato, linea, linea appena finita — `directed()`):
  entro `HUM_MAGNET_R` = 3 m dal pallone l'ultimo tratto va dritto sul pallone; raggio di contrasto +`HUM_TACKLE_R` 0,3 m;
  pallone libero (non calciato) agganciato da +`HUM_REACH_FREE` 0,25 m; niente rallentamento ×2,4 del contrasto.
  I giocatori mossi dalla CPU (anche il pressatore) rubano palla come prima (più piano del controllato).
- **Intercetto in corsa**: un passaggio avversario intercettato da un giocatore della squadra umana si controlla sempre
  (niente deviazione del 30% né respinta per velocità alta). L'IA resta com'era (deviazioni e respinte): è realistico e
  il suo equilibrio era già misurato.
- **Scatto**: lungo una strada disegnata il portatore puntava sempre al punto successivo, a 1-2 m, e `movePlayers`
  frenava (velocità = distanza × 3,2): 5-6,8 m/s invece di 7,6, scatto invisibile. Ora punta a un punto almeno
  `PATH_LOOK` = 3 m più avanti (anche le linee di difesa). `SPRINT_BONUS` da 0,16 a 0,22. Animazione: il clip di scatto
  dipende da `p.sprint` (`sprintMix` in `src/athlete3d.js`: chi scatta lo usa da 5-6,6 m/s, la corsa normale solo da 7,6 m/s).
- **Attacco della squadra umana** (`support`/`offerSupport`): i compagni senza palla evitano i punti a meno di
  `SPACE_MIN` = 9 m da un compagno (penalità `SPACE_PEN` nella scelta, poi spostamento `SPACE_PUSH`), le punte attaccano
  la linea del fuorigioco già da `DEEP_FROM` = −30 m, il secondo d'appoggio si offre a 15-18 m (`SUPPORT_FAR`), chi è già
  d'appoggio conta 4 m più vicino (`HELP_KEEP`: prima i due d'appoggio cambiavano ogni 0,1 s e i giocatori zigzagavano).
- **Numeri** (umano simulato contro IA a pari forza 60; `node test/diag-flow.mjs 60 20 bot` e `npm run balance -- 60 60 20`):

  | | prima (fermi) | dopo |
  |---|---|---|
  | balance: V-N-P, gol, tiri | 0-2-18, 0,5-3,3, 6,0-19,1 | 4-7-9, 0,2-0,7, 6,5-4,3 |
  | diag umano: tiri / gol | 5,7 / 0,5 | 9,3 / 0,8 |
  | diag umano: azioni oltre metà campo / negli ultimi 30 m | 9,8 / 5,3 (su 15,6) | 15,2 / 8,4 (su 19,7) |
  | diag umano: palle perse centro / ultimi 30 / difesa | 11,0 / 4,5 / 0,1 | 12,3 / 7,0 / 0,3 |
  | diag IA: tiri / gol | 9,3 / 1,6 | 2,6 / 0,3 |
  | in difesa nella nostra metà: nostri giocatori davanti alla palla | 7,05 | 2,24 (IA 2,94) |
  | compagni entro 6 m dal portatore / coppie di compagni a meno di 6 m | 0,19 / 0,15 | 0,23 / 0,13 |
  | distanza media dal compagno più vicino | 13,7 m | 13,3 m |

  L'IA tira molto meno: prima la difesa era fatta di statue. Riferimento IA contro IA (`diag-flow 60 20 ai`): circa
  7 tiri e 0,5-0,8 gol a squadra. Nella prova con l'umano simulato, che pressa sempre col controllato e insegue ogni
  pallone libero, l'IA scende sotto quel livello. Nessuno dei pezzi da solo (intercetto, pressing in due, linea dietro
  la palla, contrasto più largo) lo spiega: tolti uno alla volta l'IA resta a 1-4 tiri. **Obiettivo non raggiunto**:
  meno angoli (circa 0,8-1,1 a squadra; il test degli angoli ora è `todo`).
  Spazi in partita: con l'umano simulato i grappoli erano già pochi; il test `attack-spacing.test.mjs` parte dai
  compagni ammucchiati intorno al portatore: prima, dopo 5-8 s, 1,75 coppie a meno di 6 m e 7,5 m di distanza media; ora
  meno di 0,3 coppie e più di 12 m. Il numero che conta di più per "passare il centrocampo" (passaggi intercettati in
  mezzo, circa 10 a partita) non è cambiato.
- Test: `defense-shape`, `defense-help`, `attack-spacing` (nuovi), `defense-runs` e `sprint` aggiornati.
  `test/diag-flow.mjs` ora stampa anche gli spazi. Impronta golden rigenerata.
- **Da provare sull'iPhone**: rientro e pressing quando si perde palla; linea di difesa lunga che si ferma a 14 m;
  contrasto vicino al portatore; intercetto in corsa; scatto lungo una strada (velocità e animazione); smarcamento a
  centrocampo.

## 2026-11-20 — Rosa a campo con le carte
- Richiesta di Luis (con l'immagine della rosa di un gioco famoso): campo visto dall'alto con gli 11 titolari come carte
  nei posti della formazione, panchina scorrevole sotto, tocco per scegliere e scambiare, confronto verde/rosso.
  Preso solo lo schema: **grafica nostra** (pannelli scuri, oro per gli accenti, colori della squadra), niente carte dorate,
  niente loghi né scritte copiate, niente "chemistry".
- **Schermata ferma** (classe `fix` su `.scr`): barra alta, in alto un riquadro fisso di 150 px (formazioni + Forza squadra
  + "Migliori 11", oppure il pannello del giocatore, oppure il confronto), il campo prende lo spazio che resta, sotto la
  panchina che scorre in orizzontale. Niente scorrimento verticale.
- **Carte** (`src/ui-squad.js`, 64×70 px): valutazione nel ruolo del posto (colore per fascia come `ovrCls`, anche il
  bordo), ruolo del posto (colori `pP/pD/pC/pA`), ritratto, cognome. **Fuori ruolo**: etichetta arancio col ruolo vero.
- **Posizioni** (`src/squad-layout.js`, puro, testato): i posti di `FORMATIONS` si raggruppano in file (y entro 0,1),
  file a passo uguale dal portiere in basso agli attaccanti in alto; in ogni fila le x della formazione, allargate dove le
  carte si toccherebbero; piccolo spostamento dentro la fila (terzini e ali più avanti) solo se c'è spazio; se il campo è
  piccolo la carta si rimpicciolisce (minimo 72%). Test: nessuna sovrapposizione e niente fuori dal campo per ogni
  formazione e altezze da 330 a 560 px; a 390×844 meno le aree sicure il campo è alto 418 px e le carte restano a 64 px.
- **Tocchi** (scelta mia): 1° tocco sceglie (pannello con statistiche, "Aspetto" e "Vendi"); 2° tocco su un altro con cui
  si può scambiare apre il **confronto** (valori verdi per chi è meglio, rossi per chi è peggio, Forza prima → dopo);
  si scambia toccandolo ancora o con "Scambia". Prima lo scambio era al 2° tocco: così si vede prima di decidere.
  Panchina→panchina sceglie l'altro. Con un giocatore scelto le altre carte mostrano un **badge** verde/rosso (quanto
  cambia la somma delle valutazioni dei titolari): solo per chi è nello stesso ruolo o se lo scambio migliora, per non
  riempire il campo di numeri assurdi (attaccante in porta).
- **Ritratto**: viso SVG disegnato (`src/face2d.js`): pelle, colore e taglio dei capelli (17 tagli approssimati),
  barba, maglia e colletto coi colori della squadra. Niente WebGL: 18–24 piccoli SVG, costo trascurabile.
- Scambio: `swapLineup` (nuovo array, non tocca il vecchio) usato da `Career.swap`; `lineup` resta un array di id,
  salvataggio `tag_save_v1` invariato.
- Prove: `node --test test/unit/squad.test.mjs`; a schermo `node test/squad-shot.mjs shots` (4 formazioni, fuori ruolo,
  scelto, confronto, scambio campo↔panchina con controllo del salvataggio, panchina scorsa, portiere + Vendi, Aspetto,
  e 390×763 = spazio vero tra le aree sicure; controlla che non scorra e che le carte non si sovrappongano).
- **Da provare sull'iPhone**: carte abbastanza grandi da toccare e leggere? Il confronto prima dello scambio va bene o
  Luis preferisce lo scambio subito al 2° tocco? La panchina scorre bene col dito senza muovere la pagina? I visi.

## 2026-11-20 — three.js in un file a parte (`www/assets/three.min.js`)
Problema: `www/index.html` pesava 986 KB (limite 1 MB) e le animazioni in arrivo aggiungono codice. Dentro c'erano
three.js (592 KB), gli addons (49 KB) e il nostro codice (~330 KB).
- **Tecnica**: due build esbuild in `build.mjs`. 1) Il gioco (`src/main.js`) con un plugin che risolve `three` e
  `three/addons/...` (anche `three/examples/jsm/...`) in moduli ponte CommonJS (`module.exports = globalThis.__THREE`,
  `globalThis.__THREE_ADDONS['examples/jsm/loaders/GLTFLoader.js']`); il plugin annota gli addons usati. 2) Il file di
  three: `import * as T from 'three'` + gli addons annotati, in formato iife, che crea i due globali. Gli addons sono
  nello stesso file di three e importano lo stesso three: una sola istanza (le classi e i controlli `instanceof` coincidono).
- **Perché così**: il codice del gioco e i test in Node non cambiano (`import * as THREE from 'three'` resta, in Node
  è il pacchetto vero); nessun elenco di nomi da tenere aggiornato (il ponte CommonJS passa l'oggetto intero; con un
  ponte ESM servirebbe l'elenco di tutti gli export di three, ~30 KB di nomi). Scartati: `<script type="module">` con
  import map (dipende dal supporto e dall'ordine dei moduli in WKWebView, e da `file://` per il file unico i moduli non
  vanno); dividere in più pezzi con `splitting` (solo formato esm, stesso problema).
- **three intero, non sfoltito**: il file contiene tutto three (793 KB contro 592 KB della parte usata prima), così
  qualunque classe nuova (es. per le animazioni) funziona senza toccare la build. Il menu non è più lento: tempo di
  apertura (`node test/menu-time.mjs http 15`) mediana 903 ms prima, 852–856 ms dopo (Chrome su PC, swiftshader).
- **Dimensioni**: `www/index.html` 986 KB → 350 KB; `www/assets/three.min.js` 793 KB (con la licenza MIT di three in fondo).
  File unico (`npm run build:single`) 4255 KB, three incorporato in un secondo `<script>` prima del gioco.
- **Caricamento**: `<script src="assets/three.min.js">` sincrono prima del codice del gioco (è locale, nell'app su
  `app://`, tipo `text/javascript` già in `App/main.swift`; il workflow copia tutta `www/`). Se il file manca o si
  rompe, il codice del gioco non parte e compare il messaggio `#nothree` ("Il gioco non riesce a partire… chiudi e
  riapri l'app; se non basta, reinstallala") invece di una pagina vuota.
- **Controlli**: `build.mjs` si ferma se nel metafile del gioco compare un file di `node_modules/three/`, avvisa sopra
  800 KB e controlla i 20 MB anche per `three.min.js`; `test/unit/split-three.test.mjs` controlla che `www/index.html`
  non contenga three (frase `THREE.WebGLRenderer:`), stia sotto 700 KB e carichi `three.min.js` prima del codice, e
  carica `three.min.js` in un contesto `vm` di Node: three intero (443 nomi) e ogni addon chiesto dal gioco presente;
  nomi `three/build/...` diversi da three stesso (es. `three/webgpu`) fermano la build;
  `node test/loading-shot.mjs shots` prova anche three mancante (schermata `load-2-senza-three.png`).
- **Da provare sull'iPhone**: apertura del menu (tempo e nessuna pagina vuota), ingresso in partita, giocatori e stadio
  come prima.

## 2026-11-20 — Visuale girata col dito nel rallenty, passaggio solo disegnato
Richieste di Luis: "quando si rallenta per tiro e passaggio devo poter muovere io la telecamera a destra e sinistra,
togli l'automatismo" e "toccare un compagno non deve fargli fare il passaggio, bisogna sempre disegnarlo".
- **Tolta la rotazione automatica** del duello (`duelSide`, `sideK`, `DUEL_SIDE_MAX/K`, `DUEL_AHEAD_R` in `render.js`;
  tolta anche la prova `test/duel-side-shot.mjs`). Resta l'**inquadratura larga** del rallenty (`wideView`, "allargare
  la visuale per avere più scelte"), ma girata dell'angolo scelto dalla persona.
- **Gesto** (`src/input.js`, modo `'cam'`): nel duello o nell'area di tiro, col pallone del controllato, un dito che si
  appoggia lontano da pallone/portatore (fuori dal raggio del disegno) e si sposta di lato di almeno 12 px (più di lato
  che in verticale) gira la visuale intorno al portatore. Il disegno dal portatore resta linea (il modo si decide quando
  il dito si appoggia, quindi una linea non diventa mai rotazione e viceversa). In difesa e fuori dal rallenty non cambia nulla.
  Nel rallenty "tieni premuto sul campo = corri lì" non c'è più (si corre disegnando la strada).
- **Sensibilità e limiti** (`src/camuser.js`): 150° per una larghezza di schermo (mezzo schermo ≈ 75°), limite ±100°
  dalla direzione d'attacco: oltre si guarderebbe all'indietro e il campo davanti sparirebbe. Verso: **si afferra il
  campo** (dito verso destra = il campo scorre a destra = si guarda più a sinistra), come girare una mappa; se sull'iPhone
  sembra al contrario basta `CAM_USER_GRAB = 1`. Mentre il dito gira, l'inquadratura insegue più in fretta (`POSE_K_DRAG` 14/s).
- **Ritorno**: l'angolo resta finché dura il rallenty con lo stesso portatore (anche passando da duello ad area di
  tiro) e mentre si disegna una linea; finito il rallenty (passaggio, tiro, palla persa, uscita dall'area) torna dritto
  da solo in circa 1–1,5 s (`CAM_USER_RETURN`). Chi riceve il passaggio riparte con la visuale dritta.
- **Area di tiro**: con la visuale girata oltre 40° (`CAM_USER_GOAL_YAW`) la porta avversaria non si tiene più a
  schermo per forza (altrimenti la telecamera andrebbe lontanissima).
- **Linee e tocchi** con la visuale girata: `worldToScreen`/`screenToGround`/`screenToGoal` usano la telecamera vera
  (`this.cam`), i punti della linea sono salvati in coordinate di campo. Prova a schermo: con la visuale girata di 54°
  la linea disegnata finisce a 0,02–0,03 m dal compagno e il passaggio parte.
- **Suggerimento**: nel rallenty due frecce discrete ‹ › ai lati; finché non si è mai girata la visuale anche la
  scritta "⟷ Trascina il campo per girare la visuale" in alto (stesso stile del suggerimento in basso). Campo nuovo nel
  salvataggio `camTip` (assente = mostra la scritta). Riga anche in "Come si gioca".
- **Passaggio solo disegnato**: il tocco breve su un compagno col pallone (duello, area di tiro, rimesse) non fa più
  niente; sulle rimesse il dito ovunque disegna dalla palla. In difesa il tocco su un compagno lo fa ancora comandare.
  Testi aggiornati: suggerimento del duello, tutorial "Passaggio", "Come si gioca".
- Prove: `test/unit/camuser.test.mjs` (angolo, limiti, ritorno, inquadratura girata fino a ±100° col portatore a
  schermo, gesti con una visuale finta: rotazione, tocco senza passaggio, linea = passaggio, rimessa, difesa);
  `node test/cam-user-shot.mjs shots` (duello e area: dritta, sinistra, destra, linea con visuale girata, ritorno;
  tocco su un compagno; lezione "Passaggio" del tutorial fatta disegnando: 3 prove su 3 riuscite).
- **Da provare sull'iPhone**: se il verso del trascinamento sembra naturale, se 150°/schermo è troppo o poco, se il
  gesto parte mai per sbaglio, leggibilità delle frecce e della scritta.

## 2026-11-20 — Palleggio, giochetti e tiro con fisica vera e cinematica inversa
Richiesta di Luis: il giocatore sullo sfondo del menu faceva movimenti senza senso (palleggio e giochetti), solo la
corsa andava bene. Non ci sono clip CC0/CC-BY di palleggio o skill per questo scheletro, quindi i movimenti sono
**calcolati**: posa del corpo come funzione del tempo + cinematica inversa sulle ossa, pallone con la fisica vera.
- **Come funziona** (`src/moves/*`, nessuna dipendenza grafica): per ogni movimento si danno chiavi per bacino, busto,
  testa, caviglie (o il punto del piede che deve toccare il pallone: collo, suola, punta, interno, esterno, tallone,
  coscia, testa) e mani; curve morbide fra le chiavi. Il pallone è a pezzi: fermo, rotola, vola (gravità vera, tempo
  di volo = sqrt(2(H-y0)/g) + sqrt(2(H-y1)/g)), portato dal piede (pallone = punto del piede + normale × raggio). La
  rotazione del pallone è integrata: rotola senza strisciare, in volo ha un effetto costante. Lo sguardo segue il pallone.
- `src/ik.js`: IK a due ossa (anca-ginocchio-caviglia col ginocchio verso il davanti del piede, spalla-gomito-mano).
  `src/move-pose.js` mette la posa sul modello dopo il clip; le ossa toccate (anche la posizione del bacino) si
  salvano in `f.saved` e si rimettono al fotogramma dopo, quindi la seconda passata si annulla da sola.
- **Palleggio** (`src/moves/juggle.js`, 11 s): alzata con la suola e la punta, collo destro e sinistro, coscia, un
  colpo alto, testa, rimbalzi a terra e stop di suola. Gamba d'appoggio piegata, bacino sul piede d'appoggio, braccia
  che bilanciano, saltelli tra un tocco e l'altro.
- **Giochetti** (`src/moves/tricks.js`): finta (peso a sinistra e via a destra), doppio passo (le gambe girano sopra
  il pallone fermo), elastico (esterno fuori e interno dentro dello stesso piede, il pallone rotola e si ferma),
  veronica (suola sul pallone e mezzo giro su un piede, poi sull'altro), sombrero e arcobaleno a parabola vera.
  Due versioni: menu (gesti 1,6 volte più lenti, i voli no, finiscono con lo stop) e partita (pallone grande e 0,6 m
  davanti, finisce quando il pallone ricade). In partita l'atleta fa il movimento intero (`Players3D.trickMove`, col
  sinistro specchiato), `ballOffset` prende il pallone dallo stesso movimento e le durate in `TRICKS` sono quelle dei
  movimenti (finta 0,55 s, doppio passo 0,85, elastico 0,75, veronica 1,0, sombrero 1,5, arcobaleno 2,0: i due voli
  alti durano di più perché con la gravità vera un pallone a 2-2,9 m non può scendere prima). Il motore non è toccato.
- **Tiro del menu** (`src/moves/shot.js`): passo col sinistro, destro indietro, collo pieno sul pallone, che parte a
  21 m/s e vola con la gravità; poi un pallone nuovo arriva rotolando per il giro dopo. La corsa resta il clip.
- **Verifiche in Node** (`test/unit/moves.test.mjs`, modello vero): IK entro 1 cm su tutte le pose, contatto a ogni
  tocco entro 2 cm (di solito 0), pelle mai più di 1,5 cm dentro il pallone (2,5 cm col pallone grande della partita),
  accelerazione del pallone in volo = -g. A schermo: `node test/menu-anim-shot.mjs shots [passo] [vicino]` e
  `node test/tricks-shot.mjs shots mosaico [passo] [lato]` fanno mosaici di fotogrammi fitti.
- **Non ancora**: niente rimbalzi del pallone sul corpo né scarpe che scivolano zero (in partita il giocatore si muove
  col motore mentre i piedi fanno il giochetto). Col pallone grande della partita restano compenetrazioni di 1-2 cm
  in qualche fotogramma (punta e polpaccio nell'arcobaleno).
- **Da provare sull'iPhone**: palleggio e giochetti nel menu (fluidità, se il contatto si vede), giochetti in partita
  nel duello (tasto Dribbling, anche col sinistro), durata dei voli di sombrero e arcobaleno in partita.

## 2026-11-20 — Versione Godot: niente conversione del salvataggio
Luis: "Non mi interessa il salvataggio convertito". L'app Godot ("Tiro a Giro 3D", `it.tiroagiro.godot`) parte con un salvataggio suo, nuovo; non si legge né si copia `tag_save_v1` della versione web. La regola su `tag_save_v1` resta valida solo per la versione web.

## 2026-11-20 — Dribbling: il difensore saltato non si attacca più al portatore
Segnalazione di Luis (iPhone): "nel tutorial Dribbling il giocatore si appiccica al portatore e non permette di dribblare".
- **Causa (misurata in Node, non i commit sospettati)**: il contrasto "magnetico" vale solo per i difensori umani mossi
  dalla persona (`directed()`), le durate dei giochetti in `TRICKS` le usa solo la grafica (il motore non le legge) e il
  codice di prima del pressing (9e1649f) dà gli stessi numeri. Il difetto era nel dribbling stesso: il duello si apre a
  7 m (nella lezione il difensore parte proprio a 7 m) e il dribbling si decide subito, ma lo sbilanciamento del
  difensore (0,8 s) partiva dal tocco. Toccato a 6-7 m, finiva prima che il portatore arrivasse: il difensore, ancora
  davanti, riapriva il duello e gli si attaccava (0,70 m, la distanza minima tra due giocatori). Scena del test
  (dribbling riuscito toccato all'apertura del duello, 166 riusciti su 200 semi): prima difensore che riapre il duello e
  riprende palla entro 3 s nel **100%** dei casi, distanza a +2 s 0,70 m; ora 0%, distanza a +2 s 4,0 m.
- **Tasto che non rispondeva**: dopo un tentativo la prova nuova della lezione ereditava le attese (`dribCd` 1,2 s e
  `duelCd` 1 s di partita); col rallenty a 0,08 sono fino a 15 s veri col tasto in vista che non fa nulla. Lezione con
  tocco 1 s vero dopo l'apertura del duello: prima circa 1 tocco su 5 rifiutato, ora nessuno.
- **Correzione nel motore** (`src/sim/duel.js`, `motion.js`): lo sbilanciamento (fermo) dura `DRIB_STUN` 0,8 s **da quando
  il portatore arriva** a 1 m dal difensore (più il tempo per arrivarci); poi per `DRIB_BEAT` 1,2 s il difensore resta
  "saltato" (`p.beat`, `p.beatBy`): corre a metà velocità (`DRIB_BEAT_SPD`), non può contrastare chi l'ha saltato (né col
  contatto né in scivolata) e non gli riapre il duello. Gli altri difensori no. Stessa regola per umano e IA. La corsa
  del portatore dopo il dribbling dura finché arriva oltre il difensore (prima 0,6 s fissi, poi tornava dritto e gli
  passava accanto). `userDribble` non guarda più `dribCd` (resta per l'IA): fra due duelli passa già `DUEL_CD`.
- **Lezione** (`src/tutorial.js`): ogni prova riparte senza attese rimaste (duello, dribbling, contrasti) e il difensore
  della lezione ha difesa 15, così il dribbling riesce con la probabilità massima (85%): riuscita per tentativo 57% → 83%
  (tocco 1 s dopo il duello, 120 prove con squadre di carriera nuova); 26 tentativi per 24 prove superate su 8 partite nel
  test (prima 38). Sbilanciato + saltato = 2 s dopo l'arrivo, quanto il giochetto più lungo (arcobaleno 2,0 s): durante
  il giochetto il difensore saltato non tocca il portatore.
- **Equilibrio** (`node test/balance.mjs 60 60 60`): prima V14 N22 P24, gol 0,5-0,8, tiri 7,3-4,9; ora V15 N21 P24, gol
  0,6-0,8, tiri 7,1-4,7. `diag-flow 60 20 bot`: gol umano 0,8 → 1,1, IA 0,3 → 0,2; dribbling umano 2,7 (riusciti 1,4) →
  2,6 (1,5), IA 2,6 (1,4) → 2,5 (0,9: la probabilità non è cambiata, 20 partite sono poche). In partita col tasto toccato
  nel 40% dei duelli: palla ancora nostra 2 s dopo un dribbling riuscito 82% → 85% (ripresa dal difensore saltato già 0% prima: in partita il portatore non va dritto addosso al difensore come nella lezione).
- Test: `test/unit/dribble-beat.test.mjs` (4 su 5 falliscono sul codice di prima). Golden rigenerato (cambio voluto).
  A schermo: `node test/tut-dribble-shot.mjs shots [prova]` (tocca il tasto vero e salva i fotogrammi del giochetto).
- **Da provare sull'iPhone**: lezione Dribbling (tasto subito dopo il rallenty e anche più tardi, da vicino), che il
  difensore resti fermo e poi insegua piano; in partita che dopo un dribbling il vantaggio si senta ma non sia troppo.

## 2026-11-20 — "In partita manca lo sfondo" sull'iPhone: stadio robusto, diagnostica, canvas più leggeri
Segnalazione di Luis (foto, IPA di `2931068`): campo, giocatori, tabellone e minimappa ci sono, sopra il campo tutto nero
(niente tribune, pubblico, tetto, cartelloni, maxischermo, cielo). In Chrome sul PC lo stadio c'è.
- **Causa trovata (molto probabile)**: la texture del pubblico (`src/stadium-crowd.js`) usava `ctx.roundRect`, che Safari
  ha solo da iOS 16. Su un iOS più vecchio la chiamata lancia, `buildStadium` (in un `setTimeout`) si ferma e lo stadio
  resta `null` senza che nessuno lo sappia; il cielo era aggiunto alla fine, quindi niente cielo e sfondo nero.
  Riprodotto in WebKit (Playwright 1.49 / WebKit 18.2 su Windows, nello scratchpad, niente dipendenze nel progetto)
  togliendo `roundRect` dal prototipo: stessa identica schermata della foto ed errore
  `i.roundRect is not a function`. Coerente con la correzione di stamattina su `color-mix()` (manca prima di iOS 16.2):
  l'iPhone di Luis ha probabilmente un iOS 15 o 16.0/16.1. Con WebKit 18.2 normale lo stadio c'è anche col codice vecchio.
- **Altre ipotesi controllate**: three in un file a parte (`824c3b8`) va in WebKit (stadio presente, addons uguali);
  memoria dei canvas: misurata in WebKit (WeakRef su ogni canvas creato, conta anche quelli non ancora raccolti) al
  massimo **85 MB** (hub e partita, dpr 1; su iPhone con dpr 3 i due canvas WebGL aggiungono ~20 MB): sotto il limite di
  Safari iOS (224-384 MB secondo il modello), quindi non è la causa, ma l'abbiamo ridotta lo stesso.
- **Correzioni**:
  1. `roundTop()` con `arcTo` al posto di `roundRect` (va su tutti i Safari).
  2. `buildStadium` a pezzi: cielo (per primo), 5 texture, forma delle tribune, cartelloni, panchine, struttura, pubblico,
     luci, bandiere, maxischermo, tribuna alle spalle (struttura, pubblico, luci), terreno: ognuno nel suo try/catch;
     se uno fallisce gli altri restano (senza atlante le tribune hanno i soli colori), `stadium.parts` dice cosa c'è.
     Ridisegni durante la partita (colori dei tifosi, risultato sul maxischermo) protetti allo stesso modo.
     Sfondo di riserva blu di sera (`FALLBACK_SKY`) messo subito in `render.js`: mai più nero. Se la texture del campo
     non si disegna, prato verde semplice (`plainPitch`).
  3. **Diagnostica** (`src/diag.js`): errori in `window.__errs` (anche quelli globali, catturati da uno script in testa a
     `index.html` prima di three, e le promesse rifiutate), `console.error`, conteggio dei canvas vivi. In **pausa** una
     riga piccola "Diagnostica · stadio: ok · canvas: 25 · 11 MB · WebGL2 · dpr 3" e il primo e gli ultimi errori.
  4. **Canvas svuotati dopo il caricamento sulla GPU** (`src/canvas-mem.js`): `renderer.initTexture` e poi canvas a 0×0 per
     le texture dello stadio, del campo e dei giocatori (partita, sfondo del menu, editor). Chi ridisegna (tifosi,
     maxischermo) rifà il canvas, lo ricarica e lo svuota di nuovo; se il contesto WebGL si perde e torna, i canvas si
     ridisegnano (`userData.rebuild`) prima che three ricarichi. Canvas di passaggio della barba e dei capelli liberati
     subito; texture dei giocatori tolti liberate senza aspettare il garbage collector. Memoria dei canvas in WebKit:
     menu 34 → 8 MB, hub e rosa 85 → 13 MB, partita 82 → 11,5 MB.
- **Prove**: `test/unit/stadium-robust.test.mjs` (stadio con un finto canvas: completo; senza `roundRect`; canvas del
  pubblico negato = manca solo il pubblico; nessun canvas = tribune, terreno e sfondo blu; bandiere negate; svuotamento,
  ridisegno e ritorno del contesto; diagnostica). In WebKit: partita con lo stadio intero anche senza `roundRect`;
  pubblico negato → riga Diagnostica con l'errore; tutti i canvas ≥1024 negati → cielo blu, tribune a colori, campo verde.
- **Da provare sull'iPhone**: lo stadio si vede? Se manca ancora (anche solo un pezzo), mettere in pausa e fotografare la
  riga "Diagnostica" in fondo.

## 2026-11-20 — Calcio d'angolo: telecamera alle spalle del battitore
Luis: "Il calcio d'angolo non ha la telecamera dietro al battitore". `cornerView` in `src/camfit.js` (+ `cornerStep` in `src/render.js`): per ogni angolo (nostro o avversario) la telecamera sta 4 m dietro la bandierina, alta 9 m, girata verso il centro della porta; battitore in basso al centro, porta e area piccola in alto. L'area di rigore intera non si chiede: col telefono in verticale la telecamera dovrebbe spostarsi di lato e il battitore finirebbe sul bordo. Dopo il calcio torna dolcemente alla visuale normale. Prova: `node test/corner-cam-shot.mjs <cartella>`.
Anche nel calcio d'angolo la visuale si gira trascinando il dito lontano dal battitore (Luis: "Anche quella deve essere mobile come i passaggi"): `cornerCamOn` in `src/camuser.js`; il dito vicino al pallone o al battitore disegna il cross. Girata, la telecamera tiene il battitore in basso al centro e smette di inseguire la porta (passaggio dolce entro ~20°).

## 2026-11-20 — Passaggio a Godot: fase 1

Luis ha scelto di passare a un'app vera fatta con **Godot 4.7.2-stable**. La versione web resta intatta; la nuova vive
in `godot/` (dettagli in `godot/README.md`). Scelte fatte in autonomia:

1. **Renderer Mobile** (non Forward+ né Compatibility): è quello pensato per i telefoni, su iPhone usa Metal, ha ombre,
   nebbia, MSAA e le "instance uniform" (un solo materiale per i 22 giocatori, colori diversi per ognuno).
   Conseguenza decisa da Godot: l'IPA chiede un **chip A12** (iPhone XS / XR o più nuovi).
2. **Schermo**: 390×844 punti logici, stretch `canvas_items` + `expand`, solo verticale, niente 120 Hz (60 fps come
   obiettivo, meno calore). Il 3D si disegna largo al massimo 780 px e si ingrandisce con FSR (su iPhone a 3×: scala
   0,67). Contatore FPS/memoria dentro l'area sicura.
3. **Coordinate**: Godot X = x, Y = altezza, Z = −y, come three.js nel web: i numeri di `src/render.js` (telecamera
   16 m dietro, 10,5 m in alto, 9 m avanti, campo visivo verticale 70°) e la direzione del sole si copiano uguali.
4. **Righe del campo nello shader** (`godot/shaders/erba.gdshader`): la prima versione disegnava strisce e righe in
   una texture da 1344×1984 come il web, ma i cerchi venivano a scalini; calcolate per pixel sono nitide a ogni
   distanza, senza sfarfallio lontano, e sul telefono risparmiano ~10 MB.
5. **Divisa nello shader** (`godot/shaders/divisa.gdshader`): invece di dipingere una texture per giocatore come
   `src/athlete3d.js`, ogni vertice si porta dietro la sua posizione nella posa a T (CUSTOM0) e lo shader sceglie maglia,
   maniche, pantaloncini, calzettoni, scarpe, pelle, capelli con le stesse misure del web (frazioni tra anca e
   caviglia). Mancano ancora numero, nome, stemma, motivi della maglia, viso e capelli veri: fasi successive.
6. **Animazioni**: AnimationTree con BlendSpace1D (fermo 0, corsa 4,2 m/s, scatto 8 m/s, passi sincronizzati) e
   velocità del clip che segue la velocità vera, come i riferimenti di `src/athlete3d.js`.
7. **Build IPA**: Godot esporta solo il progetto Xcode, `xcodebuild` compila senza firma, poi firma ad-hoc come l'app
   web. Godot vuole per forza un Team ID anche solo per il progetto: ne mettiamo uno finto (`AAAAAAAAAA`) che
   `xcodebuild` ignora (`DEVELOPMENT_TEAM=""`). iOS minimo **15.0** (il minimo di Godot 4.7). Bundle
   `it.tiroagiro.godot`, nome "Tiro a Giro 3D", release `tiro-a-giro-godot-ipa`. Due Mac (`macos-15`, `macos-26`)
   perché non si sa con quale Xcode i template di Godot 4.7.2 si collegano senza problemi: un job finale pubblica
   l'IPA di macos-26 o, se manca, quella di macos-15. In cache solo l'editor e `ios.zip`.
8. **Template di export sul PC**: scaricati (1,28 GB, SHA-512 controllato) ma estratti solo `ios.zip` e i template
   Windows in `%APPDATA%\Godot\export_templates\4.7.2.stable`. Ne valeva la pena: l'export iOS da Windows produce lo
   stesso progetto Xcode che userà GitHub, così bundle id, nome, iOS minimo, icone, orientamento e nome dello schema
   (`TiroAGiroGodot`) sono stati controllati davvero; l'export Windows ha dimostrato che il gioco esportato (non
   l'editor) parte e gira.
9. **Memoria nel contatore**: nelle build "release" (quella dell'IPA) `OS.get_static_memory_usage()` vale 0; il
   contatore mostra memoria video e RAM libera secondo il sistema (`OS.get_memory_info()`), più la memoria del motore
   quando c'è (editor e debug).

Verificato sul PC (Windows, RTX 3070): importazione senza errori, scena senza schermo senza errori, schermate
390×844 (campo, giocatore da vicino, porta, campo intero), prova dei tocchi automatica, export iOS (progetto Xcode) ed
export Windows. **Non verificato**: la build su GitHub (niente push in questa fase) e tutto ciò che riguarda l'iPhone.

## 2026-11-20 — Godot fase 1 provata sull'iPhone
Luis: "Tutto funzionante", contatore a **60 fps fissi** con la scena di prova (22 giocatori, stadio semplice, ombre del sole). Fase 1 chiusa; la fase 2 (partita giocabile) parte quando il motore in GDScript è pronto.

## 2026-11-20 — Godot: motore in GDScript
Il motore puro (`src/sim.js` + `src/sim/*`) è portato riga per riga in `godot/sim/` (GDScript, Godot 4.7.2), stessi nomi
di costanti, metodi e campi; dettagli e corrispondenza dei file in `godot/sim/README.md`.
- **Stessa partita del JS, bit per bit.** Numeri casuali (`rng32`, maschere a 32 bit) e `Math.hypot` rifatti esatti.
  `sin`/`cos`/`atan2` di Godot (libreria C del sistema) differiscono da V8 di 1 ulp in parte dei casi (su 2000 valori:
  sin 61, cos 81, atan2 381) e lo stato divergeva dal JS già al passo 128-510 (2-9 s), pur con eventi e punteggio
  uguali nelle partite di prova. Scelta: portare fdlibm (le funzioni di V8) in `godot/sim/fmath.gd` invece di
  tollerare lo scarto: così 7 partite intere (78 482 passi) sono identiche al JS a ogni passo, e la partita è la stessa
  su Windows, Mac e iPhone (librerie C diverse). Costo ~2 µs a chiamata, già dentro le misure qui sotto.
- **Verifica:** `node test/export-trace.mjs` scrive i riferimenti JS in `godot/tests/fixtures/` (da rilanciare a ogni
  modifica del motore JS); `godot --headless --path godot -s res://tests/run_tests.gd` li confronta e porta 81 test di
  `test/unit` (difesa, attacco, scatto, duello e dribbling, regole, portiere, barriera, vantaggio, colpi di testa):
  88 test verdi. I test di grafica, menu, carriera e tutorial non sono portati (elenco nel README).
- **Velocità** (PC di sviluppo): GDScript ~1 800 passi/s (0,56 ms a passo, 99% sotto 1,5 ms, massimo 3,1 ms), Node ~29 000.
  Un passo a fotogramma è ~3% dei 16,7 ms; su iPhone stimati 0,5-1 ms a passo. **Da misurare sul telefono.**
- `m.dispose()` a fine partita: i riferimenti circolari tra giocatori (`supC`, `beatBy`) Godot non li libera da solo.

## 2026-11-20 — Godot fase 2: gioco
Partita giocabile in Godot, parte "gioco" (la vista con giocatori, animazioni e telecamere la fa un altro lavoro in
parallelo). Scena principale ora `godot/scenes/partita.tscn`; dettagli e contratto della vista in `godot/README.md`
("Partita (fase 2)"). Scelte fatte in autonomia:
1. **Ciclo uguale al web**: gesti → motore a passi di al massimo 1/60 s col tempo scalato → eventi → vista; rallenty
   con le costanti attuali di `src/main.js` (duello 0,08, area 0,1, disegno di passaggio 0,04, di strada 0,25, di
   difesa 0,13, parata 0,1) e passaggio dolce del tempo (14/s). Un tempo dura 150 s come il predefinito del web.
2. **Gesti = porting di `src/input.js`** in `scripts/partita/gesti.gd`, logica pura: riceve posizioni e millisecondi,
   così gira nei test senza schermo (`tests/test_gesti.gd`, 20 test) con una vista finta come
   `test/unit/camuser.test.mjs`. Stessi nomi del JS (`down`, `move_ev`, `up`, `update`, `run_path`, `pick`, `spec`).
3. **La porta senza `screen_to_goal`**: il contratto della vista non ha il punto della porta sotto il dito (serve per
   tiro e tuffo). Se la vista ha `screen_to_goal` lo si usa; altrimenti lo si ricava con un'**omografia** da 4 punti
   della porta passati per `world_to_screen` (un piano visto da una telecamera arriva sullo schermo così, è esatto).
   Provato con una telecamera prospettica nei test (errore sotto 1 mm). Per questo `world_to_screen(...).z` deve dire
   "davanti alla telecamera", non "dentro lo schermo".
4. **Visuale girata col dito**: `camuser.gd` è della vista, quindi la parte del gesto (soglia 12 px, 150°/schermo,
   ±100°, verso "afferra il campo", angolo e rallenty) sta in `scripts/partita/visuale_dito.gd`; il ritorno a 0 e la
   porta tenuta a schermo restano alla vista. All'unione i due file si possono fondere.
5. **Anteprima del calcio in 2D** (puntini del volo, linea del fuorigioco, cerchio su chi riceve) disegnata dall'HUD
   sopra la vista con `world_to_screen`: il contratto non ha `setPreview`. Se la vista vera la farà in 3D, si toglie.
6. **Un dito solo**: un secondo dito si ignora; un tocco annullato dal sistema non dà ordini; i tocchi sui tasti
   dell'HUD (pausa, Dribbling) non arrivano ai gesti; l'app in sottofondo mette in pausa (come `visibilitychange`).
7. **Squadre di prova** (`scripts/partita/squadre_prova.gd`): Virtus Borgoalto (VIR, rosso, 4-4-2, livello 64) contro
   Aurora Portosole (AUR, blu, 4-3-3, livello 62), statistiche come `genPlayer` da un seme fisso, nomi inventati;
   stessa forma dei dati di `career.js` (colori 0xRRGGBB). Il seme della partita è a caso (`--seme=N` per le prove).
8. **Suoni**: file di `godot/assets/audio/`; il palo non ha un file e si genera un tono come il web. Pubblico che
   cresce col pallone negli ultimi 25 m prima di una porta (come lo stadio del web) e sale dopo un gol. Senza schermo
   i suoni sono spenti: col driver audio finto un suono in corso all'uscita resta in memoria e la build su GitHub
   (che cerca `ERROR:`) fallirebbe.
9. **Carattere**: quello di Godot ingrossato (`FontVariation`), non un carattere di sistema: stesse misure e stessi
   simboli su PC e iPhone. Il testo dei suggerimenti va a capo a mano (le Label con a-capo automatico dentro un
   contenitore sbagliavano l'altezza). Il tasto Dribbling sta sempre sopra il suggerimento.
10. **Fine partita**: schermata con risultato, esito, marcatori e statistiche, tasto "Nuova partita"; "Esci
   dall'amichevole" (con conferma) porta lì come partita abbandonata. Niente menu e carriera fino alla fase 3; niente
   cambi in pausa.

Verificato sul PC: 20 test dei gesti verdi più tutti quelli del motore; partite intere senza schermo col "dito finto"
(`--bot`) che usa solo i gesti veri, senza errori; schermate 390×844 con la vista finta (partita, rallenty con frecce,
disegno di un passaggio con anteprima, angolo, pausa, fine partita). **Non verificato**: iPhone (tocchi veri, aree
sicure vere, suoni, prestazioni) e la vista vera.

## 2026-11-20 — Godot fase 2: vista
La vista della partita (`godot/scripts/partita/`, `scenes/vista_partita.tscn`, classe `PartitaVista`) porta in Godot
quello che si vede in partita nel web: telecamere, giocatori animati, giochetti, pallone, reti, bandierine, linee.
Legge `SimMatch` e non lo cambia; contratto nel README di `godot/`. Ciclo di gioco, gesti e interfaccia sono un altro lavoro.
- **Conti della telecamera uguali al JS.** `camfit.gd` e `camuser.gd` sono porting riga per riga; `node test/export-vista.mjs`
  scrive i risultati del JS (parata, rallenty largo, angolo, fitView, dragYaw/relaxYaw/keepGoal) in
  `godot/tests/fixtures/vista.json` e i test li confrontano (posizione entro 2 cm: Vector3 di Godot è a 32 bit), più gli
  stessi controlli "dentro lo schermo" di `test/unit/camfit.test.mjs` e `camuser.test.mjs`. Il resto della telecamera
  (`View.update`: dietro l'azione, vicino alla porta, difesa, duello, girata) è copiato con le stesse costanti.
- **Giochetti: stessi movimenti del JS, applicati allo scheletro vero.** `mosse/*` porta `src/moves/*` con le misure del
  web (le pose combaciano col JS entro 2 mm a 17 istanti per giochetto, anche specchiate). Il modello Godot però non ha
  le proporzioni ritoccate del web (`body/gambe.js`, `busto.js`): la posa si applica con le lunghezze e gli
  orientamenti di riposo dello scheletro vero e con una IK a due ossa portata da `src/ik.js` (non `TwoBoneIK3D` di
  Godot, per avere le stesse pose del web e poterle provare senza schermo). Le caviglie arrivano entro 1,4 cm dal
  bersaglio; spalle e mani possono stare qualche cm più in là che nel web. **Limite noto.**
- **Pose procedurali sopra il clip** (calcio, colpo di testa, tuffo, scivolata, a terra, esultanza, portiere pronto) come
  `Players3D.pose`: rotazioni attorno agli assi del corpo, calcolate dalle pose locali (lo Skeleton3D aggiorna le pose
  globali solo al disegno: leggerle subito dava le rotazioni del fotogramma prima) e rimesse a posto al fotogramma dopo.
  Animazioni col tempo di gioco (AnimationTree in modo manuale), telecamera col tempo vero, come nel web.
- **Rete semplificata**: invece di una molla per vertice (web) un solo spostamento per porta, molla e smorzamento del web,
  distribuito dallo shader con una campana attorno al punto d'impatto; al massimo 45 cm, e il pallone a schermo si
  ferma nel telo (il motore lo tiene fino a 1,9 m oltre la linea). La propria porta è più trasparente (0,22 contro 0,78).
  Bandierine: onda nello shader (`waveFlags`). Niente scia, sbuffo d'erba e coriandoli (non richiesti in questa fase).
- **Tribune di fondo spostate a 18 m dalla linea di porta** (`stadio.gd`, erano a 9): come nel web; a 9 m la telecamera
  della parata (fino a 15 m dietro la porta) finiva dentro la tribuna.
- **Richieste del lavoro del gioco** (`wt-godot-gioco`): `screen_to_goal` restituisce `Vector3(x, h, valido)`,
  `world_to_screen` dice solo "davanti alla telecamera", `screen_to_field` dà `Vector2(INF, INF)` sul cielo, `set_zoom`
  come `setZoom`, `dispose()` sicura da `_exit_tree`, ritorno di `user_yaw` a 0 fatto dalla vista, `trick()` restituisce
  `{id, name, dur}`. `show_path` ha due parametri facoltativi in più (`end_h` per l'altezza del tiro, `recv`).
- **Verifica** (PC, RTX 3070): test senza schermo `test_camfit` 7, `test_camuser` 7, `test_mosse` 4, `test_figura` 5 (con quelli del motore: 111 test verdi, 0 falliti),
  `prova_vista.tscn -- --controlla` (campo → schermo → campo e porta, anche capovolto e
  girato); schermate 390×844 di partita, rallenty largo, visuale girata, parata e tuffo, calcio d'angolo, arcobaleno da
  vicino, linee (passaggio, anteprima, fuorigioco, difesa), gol. FPS senza vsync con 22 giocatori: ~315-340
  (fotogramma 2,8-3 ms; vista 1,5 ms di CPU, di cui ~0,6 ms le 22 AnimationTree; motore 0,2 ms).
  **Non verificato sull'iPhone.**

## 2026-11-21 — Scatto solo con l'avversario alla pari o dietro "per linee" (richiesta di Luis)
- Luis: "lo scatto deve essere attivabile solo se l'avversario é dietro (a livello di campo se lo dividessimo in tante linee
  parallele lui dovrebbe stare dietro o in parallelo alla nostra, se é davanti allora valgono le solite regole, dribling o
  passaggio)". Annulla la voce sotto del 2026-11-20 (Scatto nel duello) e riprende la fuga di `dfe6bd8`, ma col criterio
  "per linee" (coordinata lungo il campo) invece che di lato/alle spalle rispetto al verso di corsa.
- `aheadLine(c, o)` in `src/sim/duel.js`: o è davanti se sta più avanti di `LEVEL_TOL` = 0,5 m verso la porta che attacca c
  (1 m era troppo: un difensore a 1 m dritto davanti non apriva il duello). Il duello della persona si apre solo con
  l'avversario davanti per linee (oltre al cono di 70° di prima) e si chiude ("lontano") quando arriva alla pari: allora
  si apre la fuga. Fuga = avversario alla pari o dietro entro `FLEE_R` = 4 m, rallenty 8%, tasto Scatto (`userSprint` →
  `burst`: riesce sempre, +15% per 1,2 s, avversario "saltato" per 0,6 s, dritto 14 m nel verso di corsa). Nella fuga si passa
  (Luis: "deve rimanere la parte del passaggio"): linea fino a un compagno = passaggio. Poi Luis: "Durante i momenti di rallenty togli questa opzione" (la corsa
  disegnata): in duello, fuga e area di tiro ogni linea è un passaggio (fino al compagno o nello spazio) o un tiro se
  finisce in porta. `runPath()` in `src/input.js` usa `passFor`. Il tasto del duello torna **Dribbling**.
- Allenamento: torna la lezione "Dribbling" e se ne aggiunge una "Scatto" (avversario alle spalle). Prove:
  `test/unit/flee.test.mjs` (11 casi, anche squadra 1 e portatore che corre di lato), `node test/flee-shot.mjs shots`.
- Equilibrio (`npm run balance -- 60 60 20`): prima V5 N6 P9, gol 0,4-0,7, tiri 6,3-4,3; dopo V4 N7 P9, gol 0,4-0,8,
  tiri 6,0-4,5 (il bot non tocca Scatto; cambia solo quando si apre/chiude il duello). Impronte golden rigenerate.
- **Godot allineato** (motore `godot/sim/duel.gd`/`match.gd`/`base.gd` riga per riga: `aheadLine`, `frontOpp(c, R, lines)`,
  `fleeFor`/`sideOpp`/`updateFlee`/`endFlee`/`burst`, `passFor` con la fuga, chiusura 'passaggio'; tolti `sprintChance` e
  il ramo Scatto di `dribble`). Identico al JS bit per bit: `sprint.json` rifatta per la fuga (17 scene: dietro, alla pari,
  davanti per linee, squadra 1) e le 7 tracce rigenerate da `node test/export-trace.mjs`. Partita: tasto "Dribbling" nel
  duello e "Scatto" nella fuga, rallenty 8% anche nella fuga, scritta "Scatto!" sull'evento `burst` (niente giochetto),
  visuale larga e girabile nella fuga, nel rallenty ogni linea è un passaggio (`gesti.gd` → `run_path` usa `passFor`);
  allenamento con le lezioni Dribbling e Scatto; Come si gioca aggiornato. Test: `tests/test_sprint.gd` (porting di
  `flee.test.mjs` + 2 casi), fuga in `test_gesti.gd`. Dito finto: la linea ora finisce davvero sul punto voluto
  (`gesti.up` non usa il punto del rilascio; prima i tiri finivano poco prima della porta e diventavano strade, ora nel
  rallenty sarebbero passaggi nel vuoto) e nella lezione Passaggio passa anche nella fuga. **Non provato sull'iPhone.**

## 2026-11-20 — Tasto Scatto al posto del Dribbling (richiesta di Luis) — SOSTITUITA dalla voce del 2026-11-21
- Luis: "quando sei davanti all'avversario ... il tempo rallenta comunque, come se fosse per il passaggio, però compare un
  tasto che è lo scatto e lui scatta per staccarsi. E poi prosegue dritto." e poi "se è davanti non appare il tasto
  dribbling, appare il tasto scatto". Un primo tentativo (`dfe6bd8`: "fuga" con l'avversario di lato o alle spalle) era
  un malinteso ed è stato tolto.
- Scelta: il duello resta com'era (avversario davanti entro 7 m, rallenty all'8%, passaggio disegnato), ma il tasto è
  **Scatto** (`userSprint` → `dribble(p, o, true)` in `src/sim/duel.js`). Riuscita con `sprintChance` = come il
  dribbling ma con la **velocità** del portatore contro la difesa (stessi limiti 15-85%). Se riesce: difensore
  sbilanciato e "saltato" come col dribbling, portatore che gira di fianco a lui a 2 m dalla parte opposta e prosegue dritto
  fino a 14 m (`BURST_RUN`), +15% di velocità per 1,2 s (`BURST_T`, `BURST_SPD`). Se fallisce: come il dribbling fallito.
  Niente giochetto a schermo: scritta "Scatto!" o "Fermato!". L'IA dribbla ancora coi giochetti (equilibrio invariato,
  impronte golden invariate: il bot non tocca il tasto).
- La lezione dell'allenamento "Dribbling" diventa "Scatto". Prove: `test/unit/sprint.test.mjs`, `test/unit/dribble-beat.test.mjs`,
  `node test/sprint-shot.mjs shots` (Puppeteer 390×844).
- Godot allineato: `sprintChance`, `dribble(p, o, sprint)`, `userSprint`, `p.burst` in `godot/sim/`, identici al JS bit per bit anche
  sullo Scatto (nuova `tests/fixtures/sprint.json`, 14 scene da `node test/export-trace.mjs`); tasto "Scatto" nell'HUD, scritta
  "Scatto!"/"Fermato!" senza giochetto, lezione "Scatto" nell'allenamento, dito finto che tocca Scatto. **Non verificato sull'iPhone.**

## 2026-11-20 — Godot fase 3: sfondo menu e allenamento
- **Sfondo del menu = stessa routine del web, non un'animazione nuova.** `mosse/palleggi.gd`, `mosse/tiro.gd` e
  `scripts/menu/routine_menu.gd` portano `src/moves/juggle.js`, `shot.js` e `src/menu-routine.js` riga per riga; un
  test confronta 510 istanti del ciclo (114 s) con quelli esportati dal JS (`test/export-menu.mjs` →
  `godot/tests/fixtures/menu.json`) entro 2 mm. `giochetti.gd` ora costruisce sia la versione del menu (pallone
  piccolo, tempi ×1,6, sombrero 1,9 m con atterraggio vero) sia quella della partita (invariata: `test_mosse` passa).
  `corpo.gd` ha in più i punti di coscia e testa (`thigh_point`, `head_pt`) usati dai palleggi.
- **Un solo giocatore, scena leggera.** Campo e stadio della partita, una `figura.gd`, ombra a disco per il pallone;
  la telecamera gira piano (±0,32 rad in 38 s) e "respira" (±0,5 m in 23 s). Con `attivo = false` o nascosta la scena
  si ferma del tutto (niente `_process`, telecamera, cielo e sole staccati) per non pesare durante la partita.
  Inquadratura come il web (fov 30, 7,2 m): il campione riempie metà schermo, i tasti del menu staranno sopra.
- **Allenamento: logica pura uguale al web, interfaccia separata.** `allenamento.gd` non conosce la grafica: riceve un
  oggetto `ui` con `text()` e `card()` come il web, così i 7 test (i 5 di `tutorial.test.mjs` e i 2 della lezione
  Dribbling di `dribble-beat.test.mjs`) girano senza schermo. Il motore non si tocca: la lezione sposta solo giocatori e
  pallone. Correzione del dribbling compresa (attese azzerate a ogni prova, difensore con difesa 15): nei test 26
  tentativi per 24 prove superate, 0 fotogrammi col difensore saltato attaccato al portatore.
- **Aggancio minimo a `gioco.gd`** (lo modifica anche il lavoro della carriera): `var tipo`, la squadra avversaria e il
  tempo infinito in `_crea_partita`, `before()/after()` attorno ai passi del motore, suggerimenti e aiuto visuale spenti,
  testo "Esci dall'allenamento", e tutto il resto in un blocco in fondo al file. Finché non c'è `avvia(opz)` si parte con
  `--allenamento`; a fine allenamento si manda `finita(esito)` se il segnale esiste, sennò si ricomincia.
- **Squadra "Allenamento" fatta qui** (`Allenamento.squadra_ospite()`, livello ~40, seme fisso): nel web è
  `aiMatchTeam` della carriera, che in Godot non c'è ancora. Quando arriva la carriera si può sostituire.
- **Prova del dito finto**: `bot_allenamento.gd` supera tutte e 6 le lezioni (18 prove) solo con gesti a schermo, con 3
  semi diversi (~30 s a velocità 4). Schermate 390×844 di scheda e lezioni confrontate col web (`test/tut-lessons-shot.mjs`).
- **Verifica** (PC, RTX 3070): 144 test verdi, 0 falliti (anche `test_allenamento` 7 e `test_sfondo_menu` 6). Sfondo
  del menu: ~1500 FPS senza vsync, 120 con vsync; scena principale e menu senza errori senza schermo.
  **Non verificato sull'iPhone.**

## 2026-11-20 — Godot fase 3: carriera
Carriera, salvataggio e flusso dell'app in Godot (in parallelo: interfaccia dei menu, sfondo e allenamento guidato,
grafica). Scena principale ora `godot/scenes/app.tscn` con l'autoload `App`; dettagli e API in `godot/README.md`
("Carriera e flusso dell'app (fase 3)"). Scelte fatte in autonomia:
1. **Porting 1:1 di `src/career.js`** in `godot/scripts/carriera/carriera.gd` (`class_name Carriera`), stessi nomi di
   metodi e campi, stato in `c.s` con le stesse chiavi: chi fa i menu scrive leggendo `career.js` e `ui.js`.
   `looks.js` → `aspetto.gd`, la parte dati di `crest.js` → `stemma_dati.gd` (tracciati SVG come testo: il disegno lo
   fanno i menu). **A parità di seme la carriera è identica al JS** (`node test/export-carriera.mjs` →
   `tests/test_carriera.gd`: creazione, calendario, mercato, 20 giornate a caso, tre stagioni con promozioni e titolo).
2. **Per avere gli stessi numeri** si rifanno tre cose del JS (`scripts/carriera/js.gd`): l'ordinamento di V8
   (TimSort con inserimento binario: i mescolamenti `sort(() => r() - 0.5)` dipendono da quante volte si chiama r();
   verificato contro Node 26 da 8 a 63 elementi, sotto 8 V8 usa un altro metodo ma career.js mescola solo liste da
   10 e 32), `toFixed` esatto in `fmtMoney` (1005 k€ = "1,00 M€", 1125 k€ = "1,13 M€", come il JS) e i numeri interi
   dopo il JSON (Godot legge tutto come float e `[1.0].has(1)` è falso: al caricamento gli interi tornano int).
3. **Salvataggio nuovo, non si converte quello del web** (scelta di Luis): `user://salvataggio.json` =
   `{"versione": 1, "carriera": s}`. Scrittura su `.tmp`, controllo rileggendolo, il file di prima diventa `.bak`, il
   temporaneo prende il suo posto. Lettura: principale, poi temporaneo, poi copia; un principale rotto va in `.rotto`
   (non lo si cancella e non diventa la copia). Se non c'è niente di buono **non si crea una carriera da sola**: come
   nel web il menu propone "Nuova carriera" (serve il nome della squadra). Campi mancanti → predefiniti, calendario
   rotto → rifatto, formazione sbagliata → rifatta.
4. **Impostazioni in `s.settings` come il web** (`half`, `diff`, `sound`, `autoGk`) **più `music` e `vibra`**
   (predefinite true). Il segnaposto non le mostra: le userà il menu Impostazioni.
5. **`App` autoload + `scenes/app.tscn` principale**: le schermate sono scene in `scenes/menu/<nome>.tscn` che
   sostituiscono la scena corrente (`App.vai`); quelle che `App` apre da sola sono `principale` (avvio, ritorno) e
   `dopo_partita` (con `App.ultimo_esito`). Finché mancano si vede `segnaposto.tscn` (elenco in testo).
6. **Partita dall'app**: `gioco.gd` ha `avvia(opz)` e il segnale `finita(esito)`; se nessuno chiama `avvia` entro il
   primo fotogramma parte con le squadre di prova. Le vecchie opzioni (`--bot`, `--scena`, `--schermata`, …) senza
   `--app` fanno partire subito la partita di prova: i comandi delle fasi 1-2 funzionano come prima.
   `finita` parte al fischio finale (il risultato si registra subito, come il web, anche se poi l'app viene chiusa
   sulla schermata di fine), e il tasto "Continua" (prima "Nuova partita") emette `continua` per cambiare schermata;
   con "Esci" `finita` parte subito: in campionato 0-3 a tavolino e `finishMatch` (come il web), in amichevole
   ritorno al menu senza conseguenze.
   Amichevole: `App.gioca_amichevole(avversario)` accetta l'id di una squadra, un livello (come il web) o niente.
7. **Vista**: le divise arrivano col campo `kit` di `myMatchTeam`/`aiMatchTeam` (colori, `style`, `crest`); la vista
   le usa già per i colori. Il `look` della carriera è fatto di indici (non colori): in `vista.gd` una riga lo
   traduce con `Aspetto.colori` (prima avrebbe dato pelle e capelli quasi neri). Stile della maglia e stemma sulla
   maglia restano alla grafica.
8. **App in sottofondo o chiusa = salva subito.** La partita in corso non si salva (come il web): se l'app viene chiusa
   a metà partita, la giornata non viene registrata.

9. **Salvataggi scritti a metà**: calendario, classifica, squadre e giocatori controllati campo per campo; una
   stagione arrivata alla giornata 18 ma non chiusa si chiude al caricamento; `finishMatch` senza partita da giocare
   non fa niente (nel JS darebbe errore). Restano i limiti: `pow`/`exp` di Godot usano la libreria del sistema
   (V8 la sua), quindi su iPhone un risultato simulato può in casi rarissimi differire dal web a parità di seme.

Verificato sul PC (Windows, Godot 4.7.2): 144 test senza schermo verdi (13 nuovi: `test_carriera` 4,
`test_salvataggio` 9); stagione intera senza schermo con le partite vere e il dito finto (`--app --stagione-bot --bot
--veloce=8 --tempo=20`: 18 partite in 2 min 20 s, fine stagione, salvato, ricaricato dal file identico); "Esci" dalla
pausa in campionato (0-3 registrato) e in amichevole (nulla cambia) con `--prova-uscite`; schermate 390×844 del giro
senza carriera → menu → partita → fine → dopo partita → menu. **Non verificato**: iPhone (salvataggio in sottofondo
vero, prestazioni), le schermate vere dei menu (altro lavoro).

## 2026-11-20 — Godot fase 4: grafica
Grafica della partita nella versione Godot (`godot/`), solo vista: il motore non è cambiato. Nuove chiamate di
`PartitaVista` (contratto nel README di `godot/`): `tifo(tipo, squadra)`, `set_rallenty(k)`, `set_qualita(l)`, più
`qualita_auto` e `livello_qualita`.
- **Pubblico 3D** (`scripts/stadio/pubblico.gd`, `shaders/pubblico.gdshader`): un cartoncino per tifoso in MultiMesh a
  pezzi da 30 m (così la telecamera scarta quelli fuori schermo), girato verso la telecamera nello shader; figurine
  disegnate a codice (4 tipi × 2 pose). Curva di casa dietro la porta in basso, settore ospiti al centro dell'altra
  curva, misti ai lati; colori come `fanColors` del web. Le reazioni (in piedi, braccia su, salti, applauso) sono soglie
  per tifoso nello shader: la CPU scrive solo 2 vec4 per fotogramma. Sul gol l'altra tifoseria si siede.
- **Stadio**: cartelloni a led con 16 sponsor inventati che scorrono (porting di `src/stadium-ads.js`, testo disegnato
  una volta in una SubViewport), maxischermi col risultato e "GOOOL!" (`src/stadium-screen.js`), tettoie a sbalzo con
  travi e lampade, fari accesi sulle torri. Il bagliore (glow del renderer Mobile, soglia HDR 1) accende solo led,
  lampade e maxischermo.
- **Effetti** (`scripts/partita/effetti.gd`): scia del pallone sui tiri (> 17 m/s), sbuffo d'erba sul calcio da terra,
  900 coriandoli coi colori di chi segna. Le particelle si "scaldano" all'avvio sotto il campo: senza, il primo gol
  faceva un intoppo di ~150 ms (compilazione degli shader).
- **Profondità di campo** nel rallenty (fondo sfocato oltre il portatore) e nei primi piani: solo al livello alto, è la
  voce più cara (sul PC +0,19 ms di GPU a 780 px, il resto della scena 0,33 ms). **Occlusione ambientale (SSAO): il
  renderer Mobile non ce l'ha**; non messa. Ombre morbide: filtro "soft low" e sfocatura 1,6 al livello alto.
- **Rete a molle** (`scripts/rete_molle.gd`): 4 teli con una molla per nodo (17×7 il fondo), spostamenti in una
  texture float letta nei vertici; il pallone tiene gonfio il telo attorno a sé (al massimo 45 cm) e uscito ondeggia;
  dorme quando è ferma (niente conti). Test in `tests/test_rete.gd`.
- **Pallone dopo il gol a y ≈ ±51,9 e fino a ~2,6 m**: il motore Godot fa come quello web (`match.js` riga 381 /
  `match.gd` 526: la velocità verticale non si smorza nella rete), quindi **non è un errore del porting** e il motore
  non è stato toccato. Corretto nella vista: il pallone a schermo resta sotto il tetto della rete e non va oltre il telo
  gonfio (`_dentro_la_rete`). Nel web succede lo stesso (lì lo nasconde la rete a pezzi): da decidere se correggerlo
  anche nel motore, per tutti e due.
- **Aspetto dei giocatori** come il web (`aspetto.gd` = porting di `src/looks.js`, stessi numeri del JS nei test):
  pelle, colore e taglio dei capelli, barba, sopracciglia, occhi, scarpe, maniche, colletto, motivo, calzettoni,
  pantaloncini, maglia larga; cognome e numero sulla schiena da un atlante 8×4 disegnato una volta per partita. Tutto
  nello shader della divisa (instance uniform: un materiale per tutti). **Limite**: i capelli non sono mesh a parte
  come nel web: la zona coperta cambia col taglio e i vertici della testa si gonfiano; code e capelli lunghi non pendono.
  Niente stemma sul petto (il motore non passa lo stemma).
- **Texture HD** fatte dal progetto (`tools/genera_texture.gd`, CC0): pallone a 32 spicchi 1024×512 con normal map delle
  cuciture, fili d'erba in normal map che spariscono oltre 26 m, chiazze larghe sull'erba. Il file più grande è 650 KB.
  Bandierine col vento a raffiche, maglie che ondeggiano correndo (vertex shader).
- **Livelli grafici automatici** (`qualita.gd`): sotto 58 fps per 3 finestre di 1 s di fila (dopo 4 s) si scende:
  alto → medio (via profondità di campo, ombre più semplici) → basso (via bagliore, metà pubblico e particelle) →
  minimo (pubblico dipinto, niente scia e sbuffi). Non si risale. `--qualita=N` e `--senza=voce` in `prova_vista` per
  provare e misurare.
- **Misure** (PC con RTX 3070, condiviso con altre sessioni: i numeri ballano di ±15%), `prova_vista --senza-vsync
  --scala3d=2` (780 px come sull'iPhone): prima della fase GPU 0,25 ms, vista 0,92 ms di CPU; dopo GPU 0,35 ms in
  partita, 0,27 sulla festa del gol, 0,51 nel rallenty con profondità di campo (0,33 senza); vista 1,0-1,2 ms di CPU.
  Le singole voci (pubblico, cartelloni, schermi, tetti, fari, bagliore, ombre, effetti, aspetto) valgono ciascuna meno
  del rumore (< 0,03 ms di GPU). Stima per l'iPhone A12 (GPU ~20 volte più lenta, CPU ~3-4 volte, margine dimezzato):
  +2 ms di GPU in partita, +4 ms nel rallenty con la profondità di campo, +1 ms di CPU: dentro i 16,6 ms, ma la
  profondità di campo è la prima a saltare. **Non verificato sull'iPhone.**

## 2026-11-20 — Godot fase 3: menu
Interfaccia dei menu in Godot (`godot/scenes/menu/`, `godot/scripts/menu/`, dettagli in `godot/README.md`, "Menu
(fase 3)"). Scelte fatte in autonomia:
1. **Schermate costruite nel codice**, una scena minima per schermata (nome = nome per `App.vai`); base comune
   `MenuSchermata` (barra in alto, scorrimento, entrata, scritta gialla, aree sicure). Così le schermate seguono
   `ui.js` riga per riga e un cambio di stile si fa in un posto solo (`tema_menu.gd`).
2. **Stemmi e visi = stesso SVG del web** disegnato da ThorVG (test: 57 visi e 30 stemmi con testo identico). ThorVG
   non conosce `paint-order`: il bordo dello stemma si disegna prima del riempimento, come `drawCrest` del canvas.
3. **Carattere di sistema** come il web (niente file di caratteri da licenziare); pesi 500-900 con `SystemFont`.
4. **Impostazioni**: oltre a durata, difficoltà, portiere e audio ci sono **Musica** e **Vibrazione** (campi
   `music`, `vibra` già previsti dalla carriera, accesi se mancano). La vibrazione si sente a ogni tocco
   (`Input.vibrate_handheld`, 12 ms).
5. **Anteprima dell'editor**: il modello 3D della partita mostra solo i colori di pelle e capelli (niente taglio,
   occhi, barba, stile della maglia): per questo accanto c'è il viso disegnato (che invece li mostra tutti).
6. **Sfondo 3D anche dietro la casa della carriera** (come il web), con un velo scuro al 55% perché le schede si
   leggano; nel menu principale velo al 20%.
7. **Come si gioca** con lo stesso testo del web aggiornato (tasto **Scatto**, non più Dribbling).
8. **Mercato ordinato come il web** anche a pari valutazione (ordinamento stabile di V8, `MenuDati.ordina`).

Verificato sul PC (Windows, Godot 4.7.2): test senza schermo verdi (13 dei menu: visi, stemmi, semi, soldi, Rosa
uguale a `squad-layout.js`); 6 controlli dei gesti con le schermate vere (`--controlli`: ogni schermata si costruisce,
scambio in Rosa coi tre tocchi, acquisto in due tocchi, impostazioni salvate, nuova squadra dall'editor fino
all'allenamento, Continua → fine stagione); 24 schermate 390×844 confrontate con quelle del web (Puppeteer, stessa
carriera); giro dell'app menu → partita → dopo partita → menu senza errori; scorrimento col dito finto ~120 FPS sul
PC. **Non verificato**: iPhone (tocchi veri, tastiera del nome, aree sicure, fluidità, vibrazione).

## 2026-11-20 — Godot: animazioni mocap
Clip vere del "Free mocap pack 05: Soccer" di Anderson Rohr nella versione Godot (`godot/assets/mocap/mocap.res`,
`godot/scripts/partita/figura_mocap.gd`, strumento `godot/tools/converti_mocap.gd`; dettagli nel README di `godot/`).
- **Reindirizzamento fatto da noi, non col retarget di Godot.** Il pack (versione UE5) e il nostro modello hanno gli
  stessi nomi di ossa e sono tutti e due in posa a T: per ogni osso si prende la rotazione nel mondo rispetto alla posa
  a T, la si porta nel riferimento del corpo (sinistra, su, avanti) e la si rimette sul nostro osso. Spine diverse:
  spine_01←spine_02, spine_02←spine_04, spine_03←spine_05. Le versioni dell'altro piede/lato sono specchiate.
- **Solo le clip usate** (25, ~436 KB compresse con `Animation.compress`). I dribbling 1-3 non sono nell'app: sono
  giochetti da fermo (doppi passi, suola, finte) che non vanno con la corsa del motore né coi giochetti calcolati che
  ci sono già; si possono rifare con `--tutte`.
- **Root motion**: bacino fermo in orizzontale (lo spostamento è del motore, così il giocatore resta dove dice il
  motore), altezza tenuta e scalata sulle nostre gambe. Il verso delle clip è normalizzato (il pack non ne ha uno
  fisso): calci = piede al contatto in avanti, rimessa = mano al rilascio, il resto = sguardo medio del bacino.
- **Calci allineati al motore**: il calcio del motore è istantaneo (il pallone parte quando `kickAnim` riparte), quindi
  la clip parte proprio dal fotogramma del contatto (misurato: il piede più veloce vicino a terra) ed entra in 0,05 s.
  La rincorsa non si vede, si vedono contatto e accompagnamento: per la rincorsa servirebbe un preavviso dal motore.
- **Parate**: la clip sostituisce il tuffo calcolato solo se combacia (lato, distanza, altezza entro una soglia),
  altrimenti resta il tuffo calcolato. Nel pack la parata "alta" è un salto di lato, la "media" è quasi centrale e la
  "bassa" è un'uscita bassa di lato: i tuffi lunghi e orizzontali restano calcolati. La clip parte poco prima dello
  slancio, a velocità vera: partendo dallo stacco delle mani il portiere restava in piedi mentre il motore lo spostava.
  Il petto va verso il campo anche se in quel momento il portiere guardava altrove.
- **Esultanze col seme**: il seme della partita non è nel motore, quindi la scelta usa un hash di numero del gol,
  minuto, squadra e giocatore: stessa partita = stesse esultanze, niente `randi()`.
- **Difesa solo da (quasi) fermi**: la clip sta sul posto e sopra 3 m/s i piedi scivolerebbero. In partita i difensori
  vicini al portatore corrono spesso, quindi la si vede soprattutto quando aspettano il portatore.
- **Cartellini e palleggi pronti ma non usati**: il motore ha i cartellini ma non un arbitro; i palleggi sono per lo
  sfondo del menu (come usarli nel README).
- **Prestazioni** (PC, `prova_vista.tscn -- --senza-vsync --esci-dopo=15`): con mocap 506-546 FPS, fotogramma
  1,71-1,85 ms, vista 1,12-1,18 ms; con `--senza-mocap` 580-585 FPS, vista 1,00-1,01 ms (prima del lavoro 538-635 FPS,
  vista 0,93-1,05 ms). Costo circa 0,15 ms a fotogramma per 22 giocatori. Sull'iPhone A12 non è misurato: resta da provare.
- **Limiti**: niente rincorsa prima del calcio; colpo di testa calcolato; difesa poco visibile in partita vera; la
  parata alta è un salto più che un tuffo; nelle clip di palleggi e cartellini non c'è il pallone.

## 2026-11-21 — Godot: rifiniture menu
- **Tocco** (`App.clic()`): come `api.click` / `Sfx.click` del web, un triangolo a 520 Hz di 0,05 s che scende da 0,12
  a 0,001, generato in codice (`AudioPartita.tono_triangolo`), niente file. Suona solo con l'audio acceso; senza schermo
  niente suoni (come `audio_partita.gd`).
- **Impostazioni** (`App.impostazioni()`, come `api.settings`): chiamata dopo ogni scelta, all'avvio e a ogni cambio di
  schermata (così vale anche per una carriera appena creata o cancellata). Audio spento = bus principale muto: tace
  tutto, anche la partita (prima la partita suonava sempre). Musica: `assets/audio/music.mp3` c'era già in
  `godot/assets/` e in `godot/CREDITI.md` (neko_4444, CC0) ma non suonava; ora suona in loop a 0,35 nei menu con audio
  e musica accesi e si ferma in partita, come il web (che non ha la voce Musica: lì segue l'audio). Vibrazione: già letta
  a ogni tocco da `MenuSchermata._tocco` (in partita non si vibra). Durata, difficoltà e portiere valgono dalla partita
  dopo. Qualità grafica: nessuna voce, resta automatica (`qualita.gd`), come nel web.
- **Un solo porting di looks.js**: tolto `scripts/partita/aspetto.gd`, la vista usa `scripts/carriera/aspetto.gd`
  (`Aspetto`), con due funzioni nuove per lo shader della figura (`parametri_figura`, `stile_figura`) che usa anche
  l'editor; tolta `Aspetto.colori()` (mai usata). Risultati uguali: confronto vecchio/nuovo su ~6000 casi (aspetto,
  stile della squadra, cognomi, parametri) senza differenze, e `tests/test_aspetto.gd` ora confronta col JS anche
  tramite `tests/fixtures/aspetto.json` (`node test/export-aspetto.mjs`). Unica differenza teorica: un giocatore con
  `src` senza `id` ora fa come il web (`"undefined"`), prima usava `""`; nel gioco non succede (tutti hanno un id).
- **Anteprima dell'editor**: la figura riceve gli stessi parametri della partita (taglio, barba, sopracciglia, occhi,
  scarpe, stile della divisa, portiere con maniche lunghe/tinta unita/girocollo come `kitFor` del web). Manca solo
  numero e cognome sulla schiena (il web li ha): l'atlante delle schiene (`schiene.gd`) sta nel materiale condiviso
  della partita e prepararlo dall'editor è un lavoro a parte.
- **Corretto**: `MenuSchermata._entra` dava "Trying to cast a freed object" se la schermata si ridisegnava due volte
  nello stesso fotogramma (es. `vai` e subito `mostra`). Ora salta i nodi già liberati.
- Prove: `--app-schermate` passa anche da Impostazioni (con il controllo audio spento/acceso sul bus) ed editor
  dell'aspetto con taglio afro (Capelli, da vicino) e chignon (Scarpe, corpo intero).

## 2026-11-21 — Godot: righe del campo e tagli dell'erba
- **Righe mancanti sull'iPhone**: erano calcolate per pixel nello shader dell'erba (distanza dalla riga più vicina +
  `fwidth`, con la riga che da lontano si schiariva invece di restare larga un pixel). Sul PC (Vulkan, anche col
  renderer Mobile e il 3D a metà risoluzione) si vedono: il difetto **non si riproduce qui**. Causa più probabile: tutto
  dipendeva dai calcoli per pixel della GPU del telefono (derivate e precisione ridotta su Metal con coordinate fino a
  60 m; da lontano la riga copriva il 10-20% di un pixel e veniva sbiadita quasi a niente). Invece di inseguire il
  difetto alla cieca le righe ora sono **geometria vera** (`scripts/righe_campo.gd`, una mesh di ~1500 vertici 1,2 cm
  sopra l'erba, larghe 12 cm come il regolamento, misure di `sim/core.gd`): sono triangoli bianchi, non dipendono più
  da quei calcoli. Lo shader `righe.gdshader` fa i conti nei vertici (precisione piena) e allarga la riga solo quando
  a schermo sarebbe più sottile di 1,5 pixel, anche vista di traverso: da lontano resta visibile senza sfarfallare.
  Illuminata come l'erba, così le ombre dei giocatori ci passano sopra; normale forzata verso l'alto nel fragment
  (con `cull_disabled` archi e dischetti, girati al contrario, venivano neri).
- **Tagli dell'erba**: 8 (`strisce`, `strette`, `verticali`, `quadrotti`, `cerchi`, `uniforme`, `rombi`, `raggi` =
  strisce + cerchio a spicchi), tutti nello stesso shader dell'erba scelti con un intero (`taglio`): niente texture,
  bordi ammorbiditi con `fwidth` (da lontano le fasce si fondono invece di sfarfallare). Lo shader dell'erba ora è anche
  più leggero (niente più distanza dalle righe per ogni pixel).
- **Scelta del taglio**: ogni squadra ha il suo stadio, taglio fisso da `Tagli.da_seme(seme della squadra)`. In
  campionato conta la squadra di casa (in casa il seme del mio club `s.seed`, fuori quello dell'avversario, passato
  come `stadio_seme` in `avvia`); amichevole e allenamento: dal seme della partita (quindi a caso). Il menu resta col
  classico. `--campo=<nome>` sulla riga di comando vince su tutto (prove). Nessun campo nuovo nel salvataggio.
- **Da provare sull'iPhone**: che le righe si vedano (vicino e lontano) e i tagli; se le righe sembrassero troppo
  spesse da lontano, abbassare `min_px` in `shaders/righe.gdshader`.

## 2026-11-21 — Godot: pallone nell'allenamento e tuffo del portiere
Luis (IPA Godot sull'iPhone, tocco vero): "nel tutorial non c'è il pallone", poi "manca anche durante le partite";
"sembra che non si riesca a parare ... il portiere sembra che non si tuffi".
- **Pallone: sul PC si vede sempre** (Vulkan Forward Mobile, OpenGL compatibilità, D3D12, `.pck` esportato col preset
  Windows, finestra a scala 2×, allenamento da riga di comando e dal giro dell'app). Quindi il difetto è del telefono
  (Metal) e non della logica: in allenamento il nodo `Pallone` c'è, è acceso, sta dove dice il motore ed è
  nell'inquadratura dopo il setup di ogni lezione (provato). Nel codice il pallone della partita era l'**unico oggetto
  con StandardMaterial3D + normal map** (`pallone_n.png`) e filtro anisotropico; il pallone dello sfondo del menu e
  tutto il resto no. **Scelta**: `PartitaVista.materiale_pallone()` = solo la texture HD (`pallone.png`), niente normal
  map né anisotropico (come il materiale semplice del web, MeshPhong con la sola mappa); in più, se il giro del pallone
  diventasse non finito si azzera (un pallone con basi NaN sparirebbe). **Non è una causa provata**: senza un iPhone
  qui non si può vedere Metal. Resta da chiedere a Luis se nello sfondo del menu (campione che palleggia) il pallone si
  vede: se sì, la causa era il materiale; se manca anche lì, è altro (e la prossima prova è un pallone di colore pieno
  senza texture). `pallone_n.png` resta negli asset (lo genera `tools/genera_texture.gd`), non usato.
- **Pallone coperto dal portatore** (visto sul PC, uguale nel web `test/duel-shot.mjs`): con la telecamera alta dietro
  chi porta palla, il pallone 0,6 m davanti ai piedi resta dietro il corpo. Non cambiato (è come il web).
- **Tuffo: la logica funziona anche col tocco vero.** Prova con `InputEventScreenTouch`/`ScreenDrag` passati da
  `Input` in pixel della finestra (anche a scala 2×), telecamera dietro la porta: `gesti.gd` apre il modo "dive",
  il punto in porta sotto il dito è giusto, al rilascio `m.userDive` fa partire il tuffo verso quel punto. Uguale al web
  (`src/input.js`, `src/sim/match.js`): il motore non è stato toccato.
- **Perché sembrava che non si tuffasse**: appena alzato il dito `diveWin` finisce (il portiere non è più in "play"),
  quindi il rallenty finiva e la **telecamera lasciava subito la visuale dietro la porta** (come nel web); il tuffo
  partiva mentre la visuale volava via, e senza pallone visibile sull'iPhone non si capiva niente. **Scelta**: la
  visuale della parata resta finché il nostro portiere è in tuffo col tiro ancora in volo
  (`TelecameraPartita.parata_in_vista`); il tempo torna normale come prima (il risultato non cambia: il motore è lo
  stesso). Il tuffo si vede (figura col corpo di lato, schermata `8_tuffo`). Con il portiere automatico (impostazione
  `autoGk`) niente visuale della parata, come prima.
- **Resta come nel web**: il tuffo parte quando si alza il dito; se lo si alza subito, con il pallone ancora lontano,
  il portiere arriva a terra prima del pallone ("troppo presto"). Se Luis lo trova troppo difficile, una scelta
  possibile è tenere il rallenty anche durante il tuffo o far partire il tuffo più tardi: da decidere con lui.
- Prove: `tests/test_gesti.gd` +2 (tuffo che arriva davvero al motore e visuale che resta; materiale del pallone),
  `tests/prova_partita.gd` nuova (partita vera senza schermo: pallone dopo ogni lezione, tuffo col tocco vero,
  figura che si tuffa; `-- --foto=CARTELLA` con la finestra salva le schermate).

## 2026-11-21 — Dribbling vicino al difensore e niente doppio tocco sui calci da fermo
Richieste di Luis provando la versione Godot sull'iPhone: "il dribbling lo deve fare vicino all'avversario e in base
alla posizione sceglie un dribbling e va in quella direzione" e "nella rimessa laterale può farsela da solo"
(poi: "controlla anche gli angoli").
- **Dribbling prenotato** (`src/sim/duel.js` → `dribBookStep`, `godot/sim/duel.gd`): il tasto non decide più subito.
  `userDribble` sceglie il lato (`duel.side`, evento `dribble_book`), il portatore corre verso un punto 1,2 m a lato del
  difensore (`DRIB_AIM`) e il dribbling vero parte a 2 m (`DRIB_NEAR`) o comunque 1,2 s di partita dopo il tocco
  (`DRIB_BOOK_MAX`, se il difensore arretra). La prenotazione vive dentro il duello: se il duello finisce (palla persa,
  passaggio, difensore lontano/alla pari) si annulla con lui; mentre è prenotato il duello non chiude per "tempo".
  Scelte mie: tempo normale durante la corsa verso il difensore (col rallenty all'8% 0,7 s di corsa sarebbero stati
  9 s veri) e tasto nascosto (`dribBooked`); niente evento di annullamento (basta `duel_end`).
- **Lato** (`dribSide`, senza numeri casuali): punteggio per lato = sbilanciamento del difensore rispetto alla linea di
  corsa (posizione + 0,3 s di velocità di lato, 1,5 per m) + spazio libero da altri avversari nel punto oltre il
  difensore (0,25 per m, fino a 8 m); entro 8 m dalla linea laterale mai verso fuori. Vale anche per l'IA: prima l'IA
  sceglieva a caso, e vicino alla linea laterale il vecchio codice (`-sign(x)·sign(uy)`) mandava in realtà **verso
  fuori** nonostante il commento dicesse "verso il centro". Il momento del dribbling dell'IA (3,2 m) non cambia.
- **Passa accanto senza attraversare**: da 2 m la linea dritta verso il punto 3 m oltre e 2,5 m di lato passava a 1 m
  dal difensore; ora lo spostamento di lato è almeno quanto serve per passargli a 1,5 m (`DRIB_WIDE`). Test: distanza
  minima > 0,9 m e portatore sempre dal lato scelto (`test/unit/dribble-book.test.mjs`).
- **Grafica**: l'evento `dribble` porta `side` (+1 = sinistra del portatore) e il giochetto usa quel lato (web
  `view.trick(p, r, side)`, Godot `vista.trick(p, r, side)`): +1 col destro, −1 specchiato col sinistro. Non ho fatto
  giochetti diversi "a rientrare": il lato specchia quelli che ci sono.
- **Niente doppio tocco** (`b.dbl` in `kick()` per rimessa, angolo, punizione, rinvio, calcio d'inizio, rigore; non per
  il rilancio del portiere dalle mani `gk`): `dblBan(p)` esclude il battitore da contatti, contrasto aereo, tuffo,
  scivolata e da chi va sul pallone (`computeChasers`). Si libera quando `b.last` cambia (qualunque tocco di un altro:
  controllo, deviazione, respinta, parata; il palo no). **Com'era prima**, misurato col codice di partenza
  (battitore che calcia a 3 m e insegue il pallone): rimessa, angolo, punizione, rinvio e calcio d'inizio = lo
  riprendeva da solo dopo 1,1-1,3 s (bastava che finissero i 0,35 s di `noT`); rigore sul palo = lo ribatteva dopo
  0,13 s. Ora nessuno dei sei.
- **Pallone fermo vicino al battitore e nessun altro**: la CPU manda sempre un altro (il battitore non è mai "chi va sul
  pallone") e nella squadra umana il controllo passa a quel compagno. Per sicurezza, se in 6 s di gioco nessun altro lo
  tocca il battitore torna libero (`DBL_FREE`): in partita non si vede, serve solo a non bloccare mai il gioco.
- **Equilibrio** (`npm run balance -- 60 60 20`, prima = codice di partenza copiato a parte): prima V4 N7 P9, gol
  0,4-0,8, tiri 6,0-4,5, possesso 49%; dopo V3 N9 P8, gol 0,3-0,7, tiri 5,5-4,3, possesso 48%. Con 80 partite: prima
  V18 N26 P36, gol 0,5-0,8, tiri 6,8-5,0, 49%; dopo V19 N29 P32, gol 0,5-0,7, tiri 6,9-4,7, 48%. Nessun cambio
  sensibile. Impronte delle partite (`golden`) rigenerate perché il comportamento è cambiato di proposito.
- **Godot**: porting riga per riga; `node test/export-trace.mjs` scrive anche `dribble.json` (12 scene di dribbling
  prenotato) e `restart.json` (10 scene di calci da fermo), identiche al JS bit per bit come le 7 partite.
- Da provare a Luis sull'iPhone: che la corsa verso il difensore a tempo normale non sembri troppo veloce dopo il
  rallenty, e che il giochetto "vada dalla parte giusta".
## 2026-11-21 — Godot fase B: carriera
Punti 6-9 del piano, solo nella versione Godot (dettagli in `godot/README.md`, "Carriera, fase B").
- **Dove**: la carriera Godot resta il porting di `career.js` (confrontato col JS dai test); le novità stanno in tre
  file nuovi (`crescita.gd`, `dirigenza.gd`, `forma.gd`), in chiavi nuove dello stato (`CHIAVI_GODOT`) e in due
  funzioni chiamate da `App`: `squadraPartita()` prima della partita, `dopoPartita(res, esito)` dopo `finishMatch`.
  Così `finishMatch`/`endSeason` restano uguali al web (in fondo a `endSeason` c'è solo `novita()`, che sceglie
  obiettivo e rivale nuovi senza numeri casuali e senza toccare le chiavi del web). I numeri casuali delle novità (infortuni) vengono da un seme
  loro (`semeB` + stagione + giornata), non da `s.seed`: la carriera "come il web" non cambia.
  `carriera.gd` supera le 800 righe (1090): è il porting 1:1 di `career.js` più la sezione fase B; tenuto insieme
  apposta perché le funzioni nuove usano lo stato e i metodi del porting.
- **6. Campione** (`champ: true`, quello dell'editor iniziale): conteggi per giocatore presi dagli eventi del
  motore nella scena della partita (`conta_giocatori.gd`, il motore non cambia). Progresso per ogni volta: gol 0,25
  e tiro in porta 0,08 e tiro 0,03 → Tiro; dribbling riuscito 0,1 → Dribbling; Scatto 0,08 → Velocità (+0,03
  Dribbling); passaggio riuscito 0,025 e assist 0,15 → Passaggio; contrasto 0,08 e intercetto 0,06 → Difesa;
  contrasto aereo vinto 0,08 → Colpo di testa (+0,04 Fisico); parata 0,08 → Parate; km corsi 0,04 Velocità e 0,06
  Fisico. Al massimo +0,5 per statistica a partita, poi per l'età (fino a 23 anni ×1, 27 ×0,85, 30 ×0,55, 33 ×0,25,
  oltre ×0,1; il calo dei vecchi resta quello di fine stagione del porting). Il progresso si accumula e a 1 la
  statistica sale di 1 (massimo 99). Solo in campionato. Dopo partita: "Tiro +1" in verde, "Dribbling +0,3" in
  chiaro. Con la stagione del bot (40 s a tempo, quasi niente tiri) il campione ha fatto +1 Velocità in 18 partite:
  giocando davvero dovrebbe salire di più (gol e dribbling pesano molto): resta da provare sull'iPhone.
- **7. Obiettivo**: dal posto della mia forza tra le 10 della divisione. Prima Divisione: 1° = titolo, 2°-5° =
  metà classifica (primi 5), altrimenti salvezza (non negli ultimi 2). Seconda e Terza: 1°-2° = promozione (primi 2),
  3°-6° = metà classifica, altrimenti salvezza. Fine stagione: raggiunto = premio ×6 / ×5 / ×3 / ×2 l'incasso della
  divisione (300/140/70 k€), mancato = −1,5 × l'incasso, senza mai portare la cassa sotto zero. Messaggio nella
  schermata di fine stagione, obiettivo nell'hub e linea in classifica.
- **8. Rivale**: la squadra della mia divisione con la forza più vicina (a pari distanza la più forte), scelta alla
  creazione (o al primo caricamento di un salvataggio vecchio) e tenuta finché resta nella mia divisione; dopo una
  promozione o retrocessione se ne sceglie una nuova. Derby: titolo "Derby · Giornata …", scritta "DERBY!", premio
  +0,5 × l'incasso della divisione se si vince; pubblico ×1,3 e cori più spessi (cori nuovi anche nelle partite
  normali, rari: il pubblico sale per 3,5 s ogni 28-45 s).
- **9. Forma**: chi gioca perde 14 − 0,05 × fisico (fisico 60 → −11), tutti recuperano 6 a giornata, chi non gioca
  altri 14; a inizio stagione tutti a 100 e guariti. Sotto 80 si parte stanchi: energia iniziale da 1 (forma 80) a 0,6
  (forma 0). Infortunio: per chi ha giocato 0,8% a partita in piena forma, fino a +4,5% sotto forma 70; durata 1-2
  giornate (70%), 3-4 (25%), 5-8 (5%). Nella stagione del bot (11 titolari sempre uguali): 4 infortuni.
  Gli infortunati non giocano: `schieraSani()` (anche in `autoLineup`/`fixLineup`, quindi "Migliori 11") mette il
  miglior sostituto sano; uno scambio che lo farebbe entrare è rifiutato (Rosa: avviso).
- **Motore**: energia iniziale facoltativa `energy0` del giocatore sorgente (`startEnergy`), in `src/sim/match.js` e
  `godot/sim/match.gd`, anche per chi entra dalla panchina. Senza il campo niente cambia: tracce 0-6 e golden
  identiche (`node test/export-trace.mjs` le riscrive uguali); traccia nuova `trace_7.json` con quattro giocatori
  stanchi, uguale al JS bit per bit.
- **Salvataggio**: stessa versione 1; chiavi nuove riempite al caricamento (`novita()`), salvataggi vecchi senza
  di esse si caricano (test).

## Statistiche a fine partita (Godot, fase C punto 14) — 2026-11-21

- **Dove**: schermata nuova `statistiche`, dal dopo partita col tasto "Statistiche e pagelle" (sopra "Continua",
  che resta l'ultimo). Vale per campionato e amichevole; l'allenamento non ha dopo partita, quindi niente
  statistiche (non aveva senso aggiungere una schermata in più a un allenamento senza fine).
- **Raccolta nel contatore che c'era già** (`conta_giocatori.gd`) invece di un secondo lettore di eventi: in
  `gioco.gd` cambia una riga (`tabellino` nell'esito). `per_giocatore()` resta identico per la crescita.
- **Posizione del tiro** = posizione di chi tira nel fotogramma del calcio. **Esito** = il primo fatto che segue:
  gol della sua squadra → gol; parata, o pallone preso dal portiere avversario → parato; respinta, spazzata o
  pallone preso da un altro → respinto; fuori, intervallo o ripresa del gioco → fuori. Il numero di tiri della
  mappa può differire di poco da "Tiri" del motore (il motore conta anche i passaggi che finiscono verso la porta).
- **Palla persa** = contrasto subito o passaggio preso da un avversario (un dribbling sbagliato finisce in un
  contrasto, quindi conta lì). **Gol subiti** = solo per chi era in campo in quel momento (gli espulsi no, chi
  entra dopo no).
- **Formula dei voti** (`voti.gd`): 6 di base; vittoria +0,5, sconfitta −0,5; gol +1, assist +0,6; dribbling +0,2
  (max +1), contrasti +0,25 (max +1,25), intercetti +0,15 (max +0,75), passaggi riusciti +0,03 (max +0,6), parate
  +0,4 (max +2); gol subiti −0,5 portiere, −0,3 difensore, −0,1 centrocampista; porta inviolata +0,5 portiere,
  +0,3 difensore; palle perse −0,1 (max −1,5); poi fra 4 e 10, al mezzo punto. Migliore in campo = più punti prima
  dell'arrotondamento (a pari punti il primo in elenco). Con i tetti un difensore che non sbaglia niente non supera
  quasi mai 8: i voti alti restano per chi segna o para tanto. **Da provare**: se i voti sembrano tutti uguali
  (6-6,5) nelle partite vere, alzare i pesi di contrasti e passaggi.
- **Colori**: squadra 0 gialla, squadra 1 blu, come le barre del dopo partita (non "mia/loro"); la mappa si gira
  perché la persona attacchi sempre verso l'alto.


## Fase C: replay del gol e cronaca scritta (solo Godot), 2026-11-21

- **Replay senza toccare il motore**: `scripts/partita/replay_buffer.gd` tiene gli ultimi 6 s di gioco (un campione
  ogni 1/30 s di gioco, 182 campioni; nei rallenty si registra meno spesso del video) con posizione, verso,
  velocità, stato, tuffo, calcio, festa ecc. di giocatori e pallone, più fase e ripresa. Nel replay, per ogni
  fotogramma, i valori registrati si scrivono sugli oggetti della partita, la vista li legge con `update_view` e
  subito dopo si rimettono i valori veri (le stesse Variant: identici bit per bit). Il motore è fermo per tutto il
  replay, quindi non vede mai i valori del replay. Scelta più semplice che rifare la vista su oggetti finti: figure,
  mocap, reti e scia funzionano da sole. Test: `test_replay_non_cambia_la_partita` (partita gemella identica dopo
  il replay, 20 s dopo). I file `godot/sim/*` non sono cambiati.
- **Quando**: dopo la festa del motore (fase "goal", 3,2 s), quando il passo dopo farebbe il calcio d'inizio, il
  motore resta fermo (`replay.trattieni`); poi `_fine_festa_gol()` → `dopo_esultanza()` → replay → calcio d'inizio.
  L'esultanza del campione (altro lavoro) si aggancia in `_fine_festa_gol()` e chiama `dopo_esultanza()` alla fine.
- **Cosa si rigioca**: da 2,2 s prima del gol a 0,6 s dopo; velocità 0,75, rallentatore 0,35 da 0,35 s prima del
  tiro a 0,5 s dopo; circa 5 s veri (al massimo 5: se l'azione è lunga si accelera tutto). Il tiro è l'ultimo calcio
  prima del gol trovato nel buffer (`tiro_prima`); la linea gialla col mirino e i puntini del volo crescono dietro al
  pallone. Visuale a caso (caso della grafica): "porta" (bassa dietro la linea di fondo di fianco al palo, 55%) o
  "lato" (bassa dalla linea laterale). Prima avevo messo la telecamera dietro la rete: la rete copriva tutto.
- **Non rigiocati**: i giochetti del dribbling (stanno nella vista, non nel motore) e la visuale girata col dito.
- **Niente replay in allenamento** (i gol degli esercizi sono tanti e brevi). Opzione `--senza-replay` per le prove.
- **Cronaca**: `scripts/partita/cronaca.gd`, logica pura (evento → frase o ""), caso suo (RandomNumberGenerator con
  seme a caso), 3-6 frasi per tipo, mai la stessa due volte di fila. Ritmo: il gol sempre; parata, palo, tiro fuori,
  occasione (tiro respinto da un difensore), rigore e cartellini se dall'ultima frase sono passati 2 s; dribbling
  riuscito, contrasto con pallone rubato, angolo e fallo semplice solo dopo 6 s e non sempre (70/35/60/60%). "Tiro
  fuori" = rinvio dal fondo entro 3 s da un tiro; un colpo di testa o al volo conta come tiro entro 20 m dalla porta.
  IA contro IA, 240 s: 7 frasi (`test_cronaca_di_una_partita_vera`). Niente cronaca in allenamento.
- **Dove**: pillola in alto a sinistra, 96 punti sotto il bordo dell'area sicura (sotto punteggio e scritta della
  visuale), larga al massimo fino alla minimappa; il gol in giallo per 5 s, il resto 3,6 s. Dentro l'HUD, sotto i
  menu (la pausa la copre).

## Fase C: esultanze del campione (solo Godot), 2026-11-21

- **15 esultanze procedurali** (`godot/scripts/partita/mosse/esultanza.gd`), fatte col sistema delle mosse che c'era
  già (chiavi di bacino, busto, testa, gambe, braccia + IK) più un "corpo intero" che sposta e gira tutta la figura
  (salti, capriola, giravolta, scivolata). Niente animazioni scaricate: dove il giocatore corre (aeroplano, rincorsa
  della scivolata, bandierina) le gambe le fa il clip di corsa che il gioco ha già. Controllate a occhio con
  `tests/foto_esultanze.gd` (6 istanti, due lati) e con i test (caviglie, mani, durata).
- **Solo il campione esulta** e solo dopo un gol suo per la mia squadra (non autogol, non in allenamento). Gli altri
  come prima.
- **Il motore non cambia**: l'esultanza dura 2,8-3,0 s e parte all'evento "goal", dentro la festa del motore (3,2 s).
  Il replay è trattenuto finché l'esultanza non finisce (o non la si salta col tocco): ordine esultanza → replay →
  calcio d'inizio. Finita, la posa finale resta fino al replay.
- **Telecamera**: davanti al campione, di tre quarti, 6,6 m, alta 2,4 m (i giocatori sono alti 2,3 m con la scala
  1,25); prima avevo messo 4,8 m e in ginocchio le mani uscivano dallo schermo. Il campione si gira verso il centro
  del campo nei primi 0,45 s.
- **Salvataggio**: il campo `esultanza` lo scrive solo `setEsultanza()` (dall'editor), **non** `addChampion()`:
  così il campione appena creato resta identico a quello del JS (test di equivalenza con le fixture) e i salvataggi
  vecchi, senza il campo, valgono come "Aeroplano" (predefinita). Valore sconosciuto → predefinita.
- **Editor**: scheda in più "Esultanza" (anche nella creazione); per farci stare 5 schede "Nome e ruolo" si chiama
  ora "Nome". Il nome lungo "Scivolata in ginocchio" è diventato "In ginocchio". Nel modellino del menu l'esultanza
  si ripete con una pausa di 1,1 s e la telecamera segue il bacino.
- **Da provare sull'iPhone**: se 3 s di esultanza più 5 s di replay sono troppi a ogni gol (il tocco salta tutti e due).


## 2026-11-21 — Meteo e ora del giorno (piano, fase C punto 10)
Dettagli in `godot/README.md`, "Meteo e ora del giorno".
- **Motore, in tutte e due le copie** (`src/sim/*` e `godot/sim/*`): campo facoltativo `meteo` delle opzioni della
  partita. Pioggia: attrito del rotolamento ×0,75 (`RAIN_ROLL`), scivolata ×1,3 (`RAIN_SLIDE`), chi perde un contrasto
  resta fermo ×1,25 (`RAIN_STUN`, i tre `stun` dei contrasti). Neve: attrito ×1,35 (`SNOW_ROLL`). Sereno, nuvoloso,
  valori sconosciuti o niente = motore identico (golden e tracce 0-7 uguali senza rigenerarle).
- **Passaggi rasoterra**: la forza si calcola con `max(ROLL, attrito)` (`rollKick`). Sul bagnato si calcia come
  all'asciutto e il pallone arriva più veloce (è la "palla più veloce" che si vede); sulla neve si calcia più forte,
  altrimenti tutti i passaggi si fermerebbero corti (un passaggio di 20 m finiva a 16,7 m). La durata del volo per
  l'effetto usa l'attrito vero.
- **La scivolata** del motore oggi non la fa nessuno (quella del giocatore è stata tolta, l'IA non entra più nello
  stato `prep`): il moltiplicatore c'è e ha il suo test, ma in partita conta soprattutto il contrasto più lungo.
- **Equilibrio** (`npm run balance -- 60 60 60 1 <meteo>`, 60 partite, umano simulato contro IA a pari forza):
  sereno V15 N22 P23, gol 0,6-0,7, tiri 6,5-4,8, possesso 48% · pioggia V19 N22 P19, gol 0,7-0,7, tiri 9,0-5,0, 50% ·
  neve V20 N18 P22, gol 1,0-1,1, tiri 8,8-6,3, 50%. Col brutto tempo si tira e si segna un po' di più (palla che
  corre sul bagnato, passaggi più forti sulla neve), senza cambiare chi vince: accettato.
- **Scelta**: seme proprio (`seme ^ SALE`, così non consuma i numeri della partita). In campionato la previsione
  dipende da carriera, stagione e giornata, così l'hub la può mostrare prima (stessa nella partita). Neve rara: 4,4%
  senza giornata, circa 5% di media su una stagione (0% alle prime e ultime giornate, 12% d'inverno).
- **Notte senza luci in più**: una sola luce con ombre (quella dei fari, alta e bianca); lo stadio va su uno strato
  che quella luce non illumina (`light_cull_mask`), così le tribune restano scure e il campo illuminato senza costi.
  FPS sul PC (finestra 390×844, `--esci-dopo=6`, PC carico di altre sessioni): sereno di giorno 96-98, pioggia di
  notte 96, neve al tramonto 98: uguali entro il rumore.
- **Pallone arancione sulla neve**: bianco su bianco non si vedeva.
- **Da provare sull'iPhone**: FPS con la pioggia (900 particelle) e di notte; se la notte sembra troppo chiara o
  troppo scura (`ORA_NOTTE.energia`, `NOTTE_AMBIENTE`); se le pozze sul bagnato piacciono; quanto si sente la palla
  più veloce sotto la pioggia.


## 2026-11-21 — Godot: capelli e barbe rifatti (Luis: "fatte malissimo")
Dettagli in `godot/README.md`, "Capelli e barbe".
- **Cosa non andava** (foto in `shots/capelli/prima/`): i capelli erano la testa stessa gonfiata lungo le normali
  dallo shader della divisa. La testa ha pochi vertici, quindi ricci, afro, punte e treccine venivano a gradini e a
  spigoli ("a punte"); tutti i tagli erano una calotta a tinta unita con l'attaccatura netta; caschetto e lunghi
  erano dipinti sul collo; coda e chignon erano bozzi. Le barbe erano macchie dipinte piatte: il pizzetto un
  rettangolo, la barba piena copriva anche naso e collo.
- **Scelta: mesh procedurali, niente modelli scaricati** (nessun CC0 adatto a questo modello e ai 17 tagli). Calotta
  appoggiata su una mappa dei raggi della testa vera (segue il cranio), barba fatta coi triangoli del viso.
  Stessi 17 tagli e 7 barbe, stessi id: i salvataggi non cambiano.
- **Prestazioni**: una mesh per coppia taglio + barba condivisa, un materiale solo, un disegno in più per
  giocatore, niente ombre proiettate dai capelli, niente trasparenza (pixel scartati), livelli di dettaglio.
  `prova_vista --senza-vsync --scala3d=2 --esci-dopo=12`: GPU 0,372 → 0,375 ms, disegno CPU 0,141 → 0,142-0,156 ms
  (rumore); `--esci-dopo=4` 95-97 FPS come la cartella di confronto senza modifiche (97-99), PC carico di altre sessioni.
- **Scelte**: "Rasato" resta dipinto (con grana); la cresta è una pinna, i lati rasati dipinti; "A punte" sono
  ciuffi a cono smussati voluti (le punte sono il taglio), mentre ricci e afro hanno volumi tondi e il riccio è nel
  rilievo dello shader. I lunghi arrivano a metà collo (più giù entrerebbero nella schiena quando gira la testa).
- **Da provare sull'iPhone**: FPS in partita con 22 giocatori; se da vicino (editor, esultanza) le barbe hanno un
  bordo troppo netto; se i capelli lunghi entrano nelle spalle nelle esultanze; tempo di avvio della partita
  (prima costruzione delle mesh, ~10 ms l'una sul PC).

## 2026-11-21 — Godot: erba con spessore ("il campo sembra ancora piatto")
- **Micro-ombre tra i fili** invece della sola normal map: nuova texture `erba_fili.png` (normale + altezza dei fili
  con media esatta 0,5, sostituisce `erba_n.png`). Il colore si moltiplica per un fattore che ha media 1: da vicino
  si vedono fili e buchi scuri, da lontano la mipmap fa la media e **i colori tarati dei manti non cambiano**. Tre
  scale; quella grossa (4,1 m) dà la grana che si vede dalla telecamera della partita (prima era tutto liscio).
- **Fili piegati dal taglio**: normale che pende in versi opposti nelle fasce alterne (`piega_fili` 0,06) e `LUCIDO`
  sull'asse vero del taglio (prima per le strisce verticali usava l'asse sbagliato).
- **Ciuffi in rilievo** (shell texturing, 4 strati, un solo disegno) solo con la telecamera sotto 4,5 m e a qualità
  alta; sopra le righe i fili sono bianchi (pezzi di riga passati allo shader, con test), così le righe hanno il bordo
  sfrangiato ma non si bucano (la prima prova le bucava di verde). Parte comune dell'erba in `erba_comune.gdshaderinc`.
- **Bagnato**: il rilievo fine faceva brillare punti sparsi sotto la pioggia: sul bagnato si spiana (`BAGNATO_PIATTO`).
- **Colori misurati** (sRGB medio di fasce, schermate 480×1040, strisce/vivo, prima → dopo): fascia chiara
  162 → 164 di verde, scura 137-138 → 134-136 (−1..−3%, nella prima misura con `piega_fili` 0,10; poi abbassato a
  0,06 per avvicinarsi). Milano: chiara 181-182 → 183, scura 134-137 → 131-136.
- **Costo GPU** (RTX 3070, 1320×1000 come i pixel del 3D sull'iPhone, prima → dopo): partita 0,43 → 0,46 ms (+6%,
  dopo aver tolto le letture inutili: pozze all'asciutto, fili fini lontano, ciuffi oltre 34 m); vicina senza ciuffi
  0,34 → 0,37; con i ciuffi 0,54 (+60%); esultanza senza ciuffi 0,39 → 0,42-0,47. Sull'iPhone (A12 molto più lento)
  la partita normale dovrebbe costare circa il 5-8% in più; i ciuffi nelle visuali basse sono la voce cara: per
  questo solo a qualità alta (al primo calo sotto 58 FPS la vista li spegne).
- **Non rifatto**: su richiesta di Luis a metà lavoro niente più finestre del gioco: le ultime modifiche
  (`piega_fili` 0,06, ciuffi solo a qualità alta, letture saltate con `textureGrad`, bagnato spianato) non hanno
  schermate nuove.
- **Da provare sull'iPhone**: se il campo sembra erba (partita, duello, replay ed esultanza da vicino), FPS nelle
  visuali basse coi ciuffi, sfarfallio dei fili muovendo la telecamera, pioggia.

## Capelli, barbe, occhi e mento come il web (Godot) — 2026-11-21

- **Capelli**: porting di `src/hair3d.js` (stesse forme e 17 id), non più la griglia fatta da noi. Texture dei
  capelli disegnata dalle funzioni del web con Puppeteer (`tools/make-godot-tex.mjs`) come pesi di colore, così una
  sola texture va per tutti i colori. Senza compressione VRAM: con la compressione in cima si vedevano quadretti.
- **Barbe**: tolto il guscio di triangoli (`barbe.gd`). Ipotesi sul perché sull'iPhone non si vedevano: il guscio
  sottile spariva coi livelli di dettaglio di Godot. Adesso sono dipinte nello stesso shader della pelle, come nel web,
  con le maschere del web (`viso_maschere.png`): non possono più sparire.
- **Occhi**: la forma non arrivava allo shader (`Aspetto.parametri_figura` non la passava) e l'iride stava al centro
  del riquadro, quasi sotto le palpebre. Ora forme di `EYE_FORMS` dentro la parte visibile del bulbo misurata sul
  modello. La testa del modello Godot non ha le correzioni della testa del web: la finestra è più piccola, quindi
  palpebre al massimo 0,9 e iride ×1,3 (scelta a occhio dalle foto, da confermare sull'iPhone).
- **Mento color maglia**: la parte sotto il mento finiva nel ramo del busto (si sceglieva per altezza). Ora testa e
  collo si riconoscono dall'osso dominante; lo scollo resta dov'era.
- **Riga scura all'attaccatura**: il bordo dei capelli rientra verso la testa e prendeva poca luce. Normale del
  bordo girata verso fuori (`BORDO_FUORI`) e risvolto col colore del bordo.
- **FPS** (`prova_vista --senza-vsync --scala3d=2 --qualita=3 --esci-dopo=12`, PC carico): prima GPU 0,401 ms,
  601 FPS, 47 disegni; dopo GPU 0,400 ms, 632 FPS, 49 disegni. Vicino (`--vicino=5`): prima 0,536 ms, dopo 0,519 ms.
- **Da provare sull'iPhone**: barbe e forme degli occhi nell'editor e in partita, grandezza dell'iride, attaccatura.

## 2026-11-22 — Godot: erba piatta sull'iPhone, causa trovata (filtro anisotropico)
- **Causa**: sull'iPhone l'erba **non si disegnava proprio**: si vedeva il terreno sotto (`TerrenoFuori` di
  `campo.gd`, un `StandardMaterial3D` #2c6428). Prove dalle due foto di Luis: il prato è un colore solo da cima a fondo
  (70,115,64 e 75,122,67 a ogni punto campionato: niente strisce, grana, fili, cambi con la distanza), con il blu
  ≈ 0,84 × il rosso in lineare come #2c6428, mentre l'erba ha blu 0. Nelle stesse foto mancano anche i **cartelloni a
  led** (solo il telaio blu scuro, sul PC si vedono gli sponsor) e la **rete delle porte** (pali e sostegni sì, la rete
  no). Erba, led e rete sono gli unici materiali con campionatori `filter_linear_mipmap_anisotropic`; tutti quelli che
  sull'iPhone si vedono (giocatori, capelli, pubblico, righe, bandierine) non li usano. Anche le righe "che non si
  vedevano" dentro lo shader dell'erba e l'erba "piatta da sempre" vengono da qui. Il meccanismo dentro Godot/Metal
  non si può vedere dal PC (niente Mac); la coincidenza dei tre materiali è la prova.
- **Correzione**: `erba_comune.gdshaderinc` usa `filter_linear_mipmap` (senza anisotropia) per grana, ciuffi e fili;
  `erba_fili.png` ora si importa con le mipmap (il filtro a mipmap non aveva livelli: da lontano i fili sfarfallavano
  invece di spegnersi). Test: `test_campo.gd` (niente anisotropico negli shader dell'erba, fili con mipmap).
- **Da fare (non erba)**: `led.gdshader` e `rete.gdshader` hanno lo stesso filtro: stessa correzione per far tornare
  sponsor e rete sull'iPhone.
- **Da provare sull'iPhone**: strisce del manto, grana e fili in partita; colore uguale alle schermate del PC.

## 2026-11-22 — Godot: palla più piccola, portiere a gioco fermo, via i suggerimenti in basso
1. **Palla**: raggio a schermo da 0,21 a 0,16 m (`Figura.PALLA_R` = `vista.gd BALL_R`): diametro
   0,32 m su giocatori alti 2,3 m (0,14 dell'altezza; vero 0,12, prima 0,18). Ombra del pallone ridotta in proporzione;
   rete, mani e replay usano lo stesso raggio; i giochetti restano misurati col pallone del web (0,21) per avere le
   stesse pose del JS (test_mosse): il pallone nei giochetti sta al più 5 cm più in basso del previsto. Motore invariato.
2. **Portiere a braccia aperte sul rinvio**: non era una posa a T, era la posa "pronto" (gambe piegate, braccia avanti e
   aperte) di `figura.gd`, data a ogni portiere fermo anche a gioco fermo e col pallone tra i piedi. Ora "pronto" solo
   in gioco e, a gioco fermo, solo per chi difende su rigore, angolo, punizione (`Figura.portiere_pronto`); altrimenti
   clip "fermo" come tutti. Rilancio dalle mani (ripresa "gk"): il portiere tiene il pallone davanti al petto (IK delle
   braccia, `_tieni_palla`; la vista lo legge con `pallone_in_mano` come nella rimessa), al calcio torna sul vero.
   Gli altri calci da fermo li battono giocatori di movimento: clip "fermo" o mocap (rimessa), nessuno a braccia aperte.
3. **Suggerimenti in basso tolti dalla partita** ("la telecronaca è ok"): tolte le tabelle `HINTS`/`RHINT` di `gioco.gd`.
   In allenamento non c'erano già (spiega il riquadro in alto, che resta). Tolti anche "PARA!" e "RIGORE": se sull'iPhone
   manca l'avviso del tuffo, si può rimettere solo quello.
4. Nuove scene di prova `--scena=rinvio` e `--scena=rilancio`.

## Divisa: colletti diversi e maglia larga vera (Godot) — 2026-11-22

- **Perché il colletto "non cambiava"**: il parametro arrivava allo shader (`stile.y`), ma i tre colletti erano quasi
  uguali. La V era tagliata dal cilindro del collo (`min(..., radiale)`): restava una V di 1-2 cm; la polo era solo
  una riga di 1,6 cm sul petto. Ora: girocollo = bordino tondo un po' più largo; a V = la pelle scende 10 cm sul petto
  (`V_FONDO`) come in `src/body/busto.js`, bordino largo uguale lungo i lati; polo = colletto rialzato sul collo
  (dipinto e staccato di 1,1 cm spostando i vertici, `POLO_RIALZO`), due risvolti sul petto con l'ombra,
  abbottonatura con due bottoni. Il mento resta color pelle: la testa non si sposta e non si dipinge col colletto.
- **Larga contro aderente**: prima la larga era solo +7 mm lungo la normale (= corpo più grosso, muscoli compresi).
  Ora `scripts/partita/vestibilita.gd` misura una volta le "valli" del corpo (levigatura, `CUSTOM2.x`): la larga le
  riempie, si svasa verso l'orlo, l'orlo scende 6 cm sopra i pantaloncini (con l'ombra), maniche più lunghe e ampie,
  pieghe (spariscono da lontano), stoffa opaca. L'aderente non si stacca, valli un filo più scure e stoffa più lucida.
  Scelte a occhio senza foto (la sera del 22 niente finestre sul PC): numeri da regolare guardando le foto.
- **Da provare**: foto dell'editor (`--app-schermate`, 6 nuove `editor_divisa_*`), partita da lontano
  (`prova_vista --divisa=C,M`), FPS prima/dopo, poi sull'iPhone.

## Tribune che sparivano, bandiere e cori (Godot) — 2026-11-22

- **Tribune**: dalle foto di Luis la gradinata dipinta non c'era proprio. Si vedevano i tifosi 3D sospesi davanti al
  muro di fondo, e quando la telecamera è più vicina alla tribuna (centrocampo) si vedeva il terreno verde sotto la
  gradinata (da dietro la porta la linea di vista finisce sul muro, e per questo la seconda foto sembrava a posto).
  Muretto e muro di fondo, che sono senza texture, invece si vedevano. **Causa**: il materiale della gradinata aveva il
  filtro anisotropico (più una texture RGB8 fatta a codice). Sull'iPhone i materiali col filtro anisotropico non si
  disegnano: era già successo al pallone il 2026-11-21, e lo stesso giorno l'ha visto l'agente dell'erba su erba, led
  e rete. Sul PC si vedono. **Cambiato**: filtro lineare con mipmap, texture RGBA8, più una rampa di riserva a tinta
  unita sotto (sull'iPhone la GPU scarta le superfici coperte, quindi quasi non costa). Un test vieta il filtro
  anisotropico in tutto `scripts/` e `shaders/`; erba, led e rete sono sistemati su altri rami e il test li salta
  finché non arriva il merge (`ANISO_ALTRI_RAMI`). Lo stadio è uguale per tutti i semi (cambia solo l'erba), quindi
  il difetto era in ogni stadio.
- **Bandiere**: 62 in un MultiMesh (150 vertici l'una, una chiamata di disegno), movimento nel vertex shader.
- **Cori**: sintetizzati da noi (niente file scaricati, quindi nessun dubbio sulla licenza). Non ho potuto ascoltarli
  (niente finestre né audio sul PC durante il lavoro): i volumi `CORI_*` sono stimati e vanno sentiti sull'iPhone.

## 2026-11-22 — Godot: altezza e corporatura dei giocatori (Luis: "deve avere un peso sulle statistiche")
Dettagli in `godot/README.md`, "Altezza e corporatura". File nuovo `godot/scripts/carriera/fisico.gd`.
- **Motore invariato**: il fisico cambia le statistiche *sorgente* sulle copie dei giocatori quando si costruisce la
  squadra per la partita (`squadraPartita`, `avversarioPartita` = `aiMatchTeam` + fisico). Niente cambi in `src/sim`
  né in `godot/sim`, golden e tracce uguali. Statistiche salvate, valutazione e valore = quelle di base (le funzioni
  portate dal JS restano identiche; `addChampion` non scrive i campi, li scrive `setFisico` dall'editor).
- **Punti** (sommati, limiti 1..99; nel motore: VEL velocità massima, RES (`fis`) accelerazione e resistenza, DRI
  dribbling/controllo/tenuta nei contrasti, DIF contrasti e intercetti, TES colpi di testa e duelli aerei, POR parate):
  | | VEL | RES | DRI | DIF | TES | POR |
  |---|---|---|---|---|---|---|
  | Basso | +1 | | +3 | −3 | −8 | −5 |
  | Alto | −1 | | −2 | +2 | +8 | +5 |
  | Snello | +2 | +1 | | −3 | −2 | |
  | Robusto | −2 | −2 | | +4 | +2 | |
  Medio e normale: niente. Il motore non ha una "forza" a parte: la forza nei contrasti è DIF (raggio e vittoria del
  contrasto); la tenuta del portatore è DRI, per questo il basso (baricentro basso) ha DRI in più e il robusto no.
- **Equilibrio**: senza contare testa e parate, la somma dei punti di ogni combinazione sta tra −1 e +1 (test). La
  testa conta poco nel motore (i duelli aerei sono rari: ~4 in 24 partite brevi IA contro IA), quindi l'alto ha un
  punto in meno sul resto. Prova (24 partite IA contro IA da 2×90 s, squadra tutta con un fisico contro la stessa
  squadra media/normale; prima di abbassare RES dello snello da +2 a +1): medio 9-7 · alto 6-7 · basso 7-4 ·
  robusto 7-14 · snello 8-6 · alto robusto 6-7 · basso snello 6-8. Con così pochi gol è tutto dentro il rumore
  (medio contro sé stesso 9-7): nessun fisico vince da solo. Una prova prima (alto con DRI −3, VEL −2, RES −2) dava
  6-13 in 16 partite: tolto un po' di svantaggio all'alto.
- **Distribuzione** (dal seme di id, nome e ruolo; su 1000): alti P 655, D 449, A 280, C 200; robusti D 428, P 310,
  A 246, C 157. Il campione senza campi (salvataggio vecchio) è medio/normale; gli altri giocatori dei salvataggi
  vecchi prendono il fisico dal seme (sono generati anche loro), senza scrivere niente nel file.
- **Figura**: scala del nodo della figura: altezza 0,94 / 1 / 1,06 su tutti gli assi (i più alti sono anche un po'
  più grossi, come nella realtà), corporatura 0,92 / 1 / 1,09 solo in X e Z (simmetrica: girando non si deforma).
  Origine ai piedi: piedi a terra (test). Scelta la scala del nodo invece delle ossa: le animazioni riscrivono le
  pose, e capelli, barba, divisa, IK e mocap seguono senza cambiare niente. Limite: un braccio alzato si allarga e
  si allunga col fattore della larghezza (al massimo 9%), non si nota.
- **Non fatto**: lo sfondo del menu (campione che palleggia) resta in scala normale (inquadratura fissa tarata);
  gli avversari non si scelgono il fisico.
- **Da provare sull'iPhone**: se la differenza di altezza (±6%) e di corporatura si vede in partita, se il robusto
  sembra grasso o solo grosso, se i numeri nella Rosa ("TES+10") sono chiari.

## 2026-11-22 — Portiere sui calci d'angolo e prese sulle parate (Luis: "la CPU segna sempre dagli angoli perché il portiere esce", "i portieri non tengono mai la palla")
- **Causa degli angoli**: il portiere usciva su quasi ogni cross (188 angoli su 200) verso il punto dove il pallone
  scendeva a 2,3 m, ma l'attaccante lo colpiva prima, a 2,4-2,6 m (fuori dalle mani del portiere, e il contrasto aereo
  escludeva il portiere): colpo di testa da 7-9 m a porta vuota (15 gol su 16 erano a porta vuota). In più i difensori
  della squadra umana non andavano mai sul cross (`humanDefend` inseguiva il pallone solo senza calcio in volo).
- **Correzione** (motore JS e GDScript, identici bit per bit, tracce e impronta rigenerate di proposito):
  il portiere esce sul cross solo se arriva sul punto di presa almeno 0,3 s prima del primo attaccante e entro 12 m
  dalla porta (`GK_CLAIM_*` in `ai`); uscito, non torna indietro a metà (`p.claim`). Altrimenti resta a 1,2 m dalla
  linea. Sui cross prende con le mani fino a 2,8 m (`GK_HAND_HI`); sotto un pallone alto conteso con un attaccante vince
  il 70% (+1% per punto di "por" sopra 60) e con un avversario addosso a volte respinge di pugno (evento `punch`).
  Il difensore umano che arriva prima sul cross vicino alla nostra porta va a colpirlo di testa.
- **Parate**: prima si bloccava solo sotto i 16 m/s (o centrale sotto 25), ma i tiri viaggiano quasi tutti a 30 m/s:
  3-6% di prese. Ora probabilità di presa (`catchChance`): alta su tiri lenti, centrali e bassi, cala con velocità,
  tuffo lontano dal corpo e pallone alto, sale con "por". La respinta in campo va verso l'esterno e lontano dalla porta.
- **Numeri** (`tests/angoli.gd` 200 angoli, `tests/parate.gd` 20 partite):
  angoli CPU contro di noi 8% → 12,5% col portiere manuale (15% automatico) ma **0 gol a porta vuota** (erano 15) e
  uscite a vuoto da 38 a 2; nostri angoli contro la CPU 3,5% → 6%. Prese sulle parate 3-6% → 43-46%.
- **Non raggiunto**: i gol da angolo contro di noi restano sopra l'obiettivo indicativo 3-8% (12-15%): i gol vengono
  da colpi di testa parati male dal portiere sulla linea e da seconde palle. Possibile passo: tuffo un po' più rapido
  sui colpi di testa da vicino.
- **Da provare sull'iPhone**: se il portiere ora sembra troppo "fermo" sui cross, se si vede la presa alta e il pugno.

## Momenti chiave (2026-11-22, Fase E punto 5, solo Godot)
- **Quante azioni**: 9, 10 o 11 col seme ("circa 10"). Quota d'attacco = 0,5 + (forza mia − forza loro) / 40, tra
  0,25 e 0,8; azioni d'attacco = quota × azioni arrotondata, **mai meno di 3**, e almeno **2 in difesa** anche con la
  squadra più forte (scelta mia: qualcosa da difendere c'è sempre). Forza = media delle statistiche dei titolari
  (il portiere col suo `por`). Media misurata (79 semi): differenza −14/−5/0/+5/+14 → quota 0,30/0,37/0,53/0,63/0,80.
- **Quando**: metà circa nel primo tempo tra il 4' e il 40', le altre tra il 49' e l'86', ad almeno 3 minuti l'una
  dall'altra. Orologio lento in questa modalità (`HALF_LEN` 900 s di gioco per tempo: 20 s = 1 minuto), così
  un'azione di 30 s porta avanti il tempo di un minuto e mezzo e non arriva mai all'intervallo.
- **Partenza**: pallone al centrocampista più centrale a 5 m (contropiede) o 11 m (manovra) oltre la metà campo;
  attaccanti 12-17 m più avanti; i centrocampisti centrali avversari già saltati, 7-10 m alle spalle del pallone
  (3 nel contropiede, 2 nella manovra; in difesa uno in meno: 2/1; più vicini di così rientravano e rubavano palla da
  dietro) e la difesa avversaria a 28-31 m (contropiede) o 25-28 m (manovra) dal pallone. Prove da questa partenza:
  IA contro IA 32 azioni d'attacco su 40 arrivano al tiro; "umano simulato" dei test (H.Bot) in attacco
  contropiede/manovra su 40: 2/3 gol, 8/15 parate, 16/7 palle perse (quasi tutte passaggi intercettati); in difesa
  1/3 gol subiti su 40.
- **Fine dell'azione**: gol (dopo festa e replay), parata (1,2 s dopo), palla fuori o in angolo (0,6 s), palla persa
  / recuperata (0,8 s), fallo (0,8 s; con il vantaggio si continua), **rigore = si gioca**, oppure 30 s di gioco.
  Il calcio d'angolo chiude l'azione (scelta mia: un angolo è un'altra azione, la si lascia alla cronaca).
- **Resto simulato**: minuto per minuto, ogni minuto col suo seme (seme della partita + minuto), quindi lo stesso
  seme dà gli stessi gol simulati comunque vadano le azioni. Per squadra e minuto: tiro con probabilità
  10 × quota / 90 (5 tiri in 90' a forze uguali), 40% nello specchio, di questi 30% gol, 6% palo; angoli 8 × quota /
  90, falli 7/90 (15% gialli). Possesso 0,5 + differenza/60 (tra 0,3 e 0,7). Chi tira: attaccanti 5, centrocampisti
  2, difensori 0,6; assist nel 60% dei gol. Gol, tiri, parate, angoli, falli e possesso vanno nel motore
  (punteggio, marcatori, statistiche) e nei conteggi (crescita del campione, voti, mappa dei tiri).
  Misure: 6 partite IA contro IA a forze uguali 7-5 in tutto; resto simulato 75 contro 50 in 59 partite 49-14.
- **Non fatto**: cambi e cartellini rossi nel resto simulato (solo gialli scritti); la stanchezza in partita cresce
  solo durante le azioni giocate (stanchezza e infortuni tra le partite restano quelli della carriera).
- **Da provare sull'iPhone**: se 10 azioni sono il numero giusto, se l'azione difensiva si capisce (parte con
  "Difendi!"), se la schermata tra le azioni si legge bene, se le azioni d'attacco sembrano occasioni vere.

## 2026-11-22 — Stili di gioco (Fase D) e portatore umano che si muove da solo (solo versione Godot)
- **Dove**: `godot/sim/stili.gd` (parametri con nome, nomi, spiegazioni, scelta per le squadre della CPU), agganci in
  `base.gd` (`anchor`), `ai.gd` (passaggi, cross, portatore, pressing, marcature, linea), `match.gd` (lettura dei campi
  `stileAtt`/`stileDif` della squadra). Ogni aggancio è dentro un `if` dello stile: senza stile (o equilibrato, o valore
  sconosciuto) il motore è identico bit per bit (tracce del JS uguali, `test_stili.gd` confronta 50 s passo per passo).
  Solo Godot: il JS non ha gli stili, resta il riferimento del comportamento predefinito.
- **Cosa fanno**: contropiede = squadra più bassa in attacco (−7% del campo) e punte più alte; per 7 s dopo il recupero
  il passaggio in avanti e il filtrante valgono di più, il portatore decide più in fretta e scatta. Possesso = appoggi
  più vicini (6,5-9,5 m) e uno in più, passaggi lunghi e lanci penalizzati, più voglia di passare. Fasce = mezzali larghe
  come le ali, cross già da 34 m e con meno spazio, il portatore corre sulla fascia. Lanci lunghi = il lancio alto si
  valuta anche con la linea rasoterra sicura, passaggi fino a 52 m, premio ai passaggi lunghi, punte più alte.
  Pressing = linea +6%, secondo pressatore sul portatore da 12 m prima della metà campo (squadra umana: un pressatore in
  più). Catenaccio = blocco −11% e più stretto (×0,8), si pressa solo entro 38 m dalla propria porta, più lontano il più
  vicino resta 5 m davanti al portatore. A uomo = difensori e centrocampisti con un avversario fisso (dai posti della
  formazione), lo seguono a 1,3 m dal lato della porta. Fuorigioco = difensori sulla stessa linea (il posto più alto tra
  loro, +2%), sempre 6 m dietro il pallone.
- **Misura** (`tools/misura_stili.gd`, 60 partite IA contro IA da 2×150 s, forza 65 contro 65, la squadra con lo stile
  contro una equilibrata, metà in casa e metà fuori; numeri della squadra con lo stile, a partita):

  | Stile | pass./azione | lanci alti | pass. >25 m | cross | linea (m) | recuperi alti | tiri | gol fatti | gol subiti | punti |
  |---|---|---|---|---|---|---|---|---|---|---|
  | Equilibrato (base) | 7,0 | 8% | 1,9 | 1,4 | 25,5 | 3,8 | 4,9 | 0,50 | 0,43 | 1,32 |
  | Contropiede | 3,6 | 11% | 3,4 | 1,3 | 24,0 | 3,6 | 4,5 | 0,77 | 0,63 | 1,42 |
  | Possesso | 11,1 | 3% | 0,9 | 0,7 | 25,2 | 2,3 | 1,9 | 0,20 | 0,35 | 1,07 |
  | Fasce | 7,4 | 8% | 1,8 | 2,4 | 25,5 | 3,8 | 4,5 | 0,32 | 0,38 | 1,17 |
  | Lanci lunghi | 6,4 | 22% | 9,2 | 4,3 | 25,8 | 4,2 | 3,9 | 0,47 | 0,48 | 1,20 |
  | Pressing | 6,3 | 8% | 2,1 | 1,5 | 29,6 | 4,0 | 4,6 | 0,33 | 0,25 | 1,28 |
  | Catenaccio | 7,7 | 8% | 2,0 | 1,0 | 14,9 | 2,1 | 2,9 | 0,38 | 0,33 | 1,27 |
  | A uomo | 6,4 | 6% | 2,1 | 2,1 | 37,0 | 7,4 | 6,8 | 0,63 | 0,42 | 1,37 |
  | Fuorigioco | 6,8 | 7% | 2,2 | 1,1 | 29,0 | 3,5 | 4,0 | 0,30 | 0,17 | 1,28 |

  "Linea" = difensore più arretrato quando si difende, metri dalla propria linea di fondo; "recuperi alti" = palloni
  presi nella metà campo avversaria. Punti: tutti tra 1,07 e 1,42 (la base contro sé stessa 1,32; con 60 partite il
  rumore è circa ±0,15): nessuno stile vince da solo. Prima della taratura il fuorigioco (linea +9%, 3 m dal pallone)
  faceva 2,13 punti con 1 gol subito in 40 partite e il pressing (secondo pressatore da −25 m) 1,80: abbassati. Il
  possesso con la soglia del tiro più alta non tirava quasi più (0,3 tiri a partita): tolta (`POSS_SHOT` = 0).
  Il fuorigioco fischiato resta rarissimo anche con la linea alta: gli attaccanti dell'IA stanno già sulla linea.
- **Squadre della CPU**: `Stili.perSquadra(seme, nome, forza, formazione)`, pesi dal prefisso del nome (Atletico =
  contropiede e pressing, Real = possesso e fuorigioco, Fortitudo = catenaccio e lanci, ...), dalla forza (forti:
  possesso e pressing; deboli: catenaccio, contropiede, lanci) e dalla formazione della stagione (4-3-3 = fasce, ...).
  Fisso per squadra nella stagione (cambia solo se cambia la formazione). Si vede nell'hub ("Loro: ...") ed è lo stesso
  della partita (`avversarioPartita`). Allenamento guidato: niente stili.
- **Salvataggio**: chiavi `stileAtt`/`stileDif` (tra le `CHIAVI_GODOT`), riempite da `novita()` con i predefiniti nei
  salvataggi vecchi; valori sconosciuti = predefiniti.
- **Portatore umano automatico** (`humanCarrierAuto`, opzione `portaAuto` del Match, predefinita sì; i test confrontati
  col JS la spengono): ogni 0,25 s prova 12 direzioni a 5 m e sceglie per avvicinamento al punto voluto, spazio dagli
  avversari, linee di passaggio libere verso i compagni (+0,35 l'una), ingresso in area con spazio (+1,5); punti a meno
  di 2,5 m da un avversario o vicini alle linee scartati. Pressato (avversario a meno di 2,6 m) protegge palla
  (andatura 0,6, anche di lato o indietro); con meno di 2 compagni davanti rallenta (0,55). Andatura per stile:
  equilibrato 0,85, contropiede 1 e scatto con strada libera, possesso 0,6, fasce verso la linea laterale e sul fondo
  (16 m) si stringe e aspetta il cross (0,45), lanci lunghi 0,4 a testa alta. In 2,5 s da metà campo: equilibrato
  avanza 12 m, contropiede 17,5, possesso 9, lanci 6; le fasce si allargano di 2,7 m. Mai passaggi né tiri da solo.
  Nel duello e nella fuga resta il movimento di prima (piano e dritto): i rallenty partono come prima (test).
- **Da provare sull'iPhone**: se gli stili si riconoscono guardando la partita (soprattutto contropiede e fasce), se il
  portatore automatico è comodo o va dove non si vuole, se il pannello Stile nella Rosa è chiaro.

## 2026-11-23 — Controllo del gameplay con partite simulate (solo versione Godot)
- **Strumento**: `godot/tools/controllo_gameplay.gd` + `godot/tools/dito_motore.gd`. Partite a livello di motore con
  una "persona simulata" che manda gli stessi comandi dei gesti (tratto dritto/curvo, dritto lungo, di prima, Dribbling,
  Scatto, colpo di testa nel fermatempo, tuffo, linee di difesa, riprese) con tempi di reazione in secondi VERI; il
  tempo scorre come in `gioco.gd` (rallenty, fermatempo di 3 s), così si misura anche il tempo vero. Opzioni del gioco:
  `testa`, `portaAuto`, `rifiniture`, meteo a rotazione, stile della CPU col suo seme. ~17 s a partita; più processi
  in parallelo e `--somma=` per sommare. È un giocatore "medio" scritto da me: i numeri assoluti dipendono da lui,
  i confronti prima/dopo no.
- **Bug corretto 1 — "campanili"**: un tiro ribattuto fino a 20 m dalla porta e mandato in angolo (`deflectBehind`,
  anche le respinte del portiere) volava a 3-6 m/s per arrivare oltre la linea: fino a 7 s in aria e 30-50 m di altezza
  (0,45 volte a partita; "pallone di nessuno" per più di 4 s 0,3 volte a partita). Ora con l'opzione `rifiniture` il volo
  dura al massimo `DEFLECT_T_MAX` = 1,4 s (pallone al più ~3 m). Dopo: 0 palloni sopra i 12 m in 160 partite (erano 73).
- **Bug corretto 2 — Scatto all'indietro**: col portatore automatico che protegge palla, lo Scatto seguiva il verso
  di corsa: 28% degli Scatti verso la propria porta, 12% di lato. Con `portaAuto` e `rifiniture` (`duel.gd burstDir`)
  se la corsa va meno in avanti di `BURST_FWD_MIN` (coseno 0,5) si scatta in avanti in diagonale (`BURST_SIDE` 0,6 m di
  lato per metro, ~31°) lontano dall'avversario, verso il centro vicino alla linea laterale. Dopo: 100% in avanti.
- **Opzione nuova `rifiniture`** del Match (predefinita false, la accende solo `gioco.gd`): i confronti col JS e
  l'impronta restano identici. Test: `tests/test_rifiniture.gd` (6).
- **Numeri** (umano 60 contro CPU 60, 160 partite da 2×150 s prima e dopo, stessi semi): V/N/P 43/64/53 → 40/67/53;
  gol 0,42-0,59 → 0,62-0,73; tiri 2,2-8,6 → 2,7-9,0; possesso umano 35% → 34%; tempo vero 412 s a partita;
  rallenty 25% del tempo vero (~137 volte a partita: duello 29, fuga 32, disegno 49, linee di difesa 45, parata 8, area 3).
  Forza della CPU (40 partite, dopo): contro 50 V/N/P 19/15/6 (gol 0,97-0,33); contro 70 1/15/24 (gol 0,17-1,55,
  **1 tiro a partita** per la persona). Stile della squadra umana (40 partite, CPU 60): possesso 9/22/9, fasce 10/22/8,
  lanci 11/19/10, contropiede 6/18/16, equilibrato 25%/42%/33%: nessuno stile rotto (rumore ±0,2 punti).
- **Meccaniche** (dopo, a partita): passaggio rasoterra 27 (79% al compagno), alto dritto 8 (71%), curvo 11 (70%);
  tiro rasoterra 45% gol (34% parati), **tiro a giro 11-15% gol (67% parati)**: è lento (vola ~1 s per salire al punto
  più alto `CURL_APEX_*` e scendere, ~15 m/s contro ~30 del rasoterra) e il portiere ci arriva. Di prima ~0,3 a partita,
  1 gol su 4. Colpo di testa col fermatempo solo 0,3-0,5 volte a partita (2 gol su 19 colpi). Duello 30 a partita,
  Dribbling riuscito 47% (a pari statistiche), palla persa dopo il dribbling fallito ~7 a partita (la fonte principale di
  palle perse). Scatto: palla persa nei 3 s dopo quasi mai (riesce sempre, come voluto). Portatore automatico: quasi mai
  perde palla da solo (0,03 a partita), mai "impallato" (fermo oltre 2,5 s senza avversari vicini), quasi mai fuori.
- **Non raggiunto / da decidere** (proposte nel rapporto, non fatte perché di gusto o fuori dal mio campo):
  falli = **zero** in tutte le partite (vengono solo dalle scivolate, tolte anche all'IA il 2026-11-20): niente
  punizioni, rigori, cartellini né vantaggio in partita. Gol da angolo della CPU 10-20% (obiettivo 3-8%; riprese = altro
  agente). Tiro a giro poco efficace. Fuga molto frequente (32 a partita) con lo Scatto che riesce sempre: tanti rallenty
  brevi. Contro una CPU più forte di 10 punti la persona tira una volta a partita.
- **Da provare sull'iPhone**: lo Scatto quando il portatore stava proteggendo palla (deve partire in avanti in
  diagonale), le respinte in angolo (niente più pallone altissimo).

## 2026-11-24 — Gol della CPU da calcio d'angolo (obiettivo 3-8% degli angoli, richiesta approvata da Luis)
- **Prima**: la CPU segnava dal 10% al 15% dei suoi angoli (metà di testa al primo tocco, metà sulla seconda palla).
  Causa: i nostri difensori sugli angoli restavano a zona sui loro posti; l'attaccante della CPU arrivava sul pallone
  libero (contesa aerea solo con un difensore entro 0,95 m: 41 volte su 400 angoli) e colpiva di testa da 7-10 m
  (20% di gol); il portiere usciva solo se in anticipo di 0,3 s.
- **Correzione** (solo con l'opzione `rifiniture`, che accende il gioco; nuovo file `godot/sim/angoli.gd` tra
  `riprese.gd` e `ai.gd`; confronti col JS e impronta identici, nessun numero casuale in più):
  - **Marcatura** (solo la squadra umana, i cui difensori sugli angoli li muove la CPU): all'angolo avversario i
    difensori di movimento prendono in consegna gli attaccanti più pericolosi entro 20 m dalla porta (colpi di testa
    meno 2 punti per metro di distanza), 2 restano a zona; stanno a 0,9 m dal lato della porta, di corsa mentre il cross
    vola, e per 3 s dopo il cross (seconda palla) se il pallone resta entro 25 m e non lo prende chi difende. Chi va sul
    pallone ci va lo stesso; linee disegnate e dito hanno la precedenza. La CPU sui nostri angoli resta a zona
    (`CORNER_MARK_CPU`): con la marcatura anche lì i gol della persona da angolo scendevano da 7,5% a 3,8%.
  - **Contesa aerea** (tutti e due): sul cross dell'angolo il difensore nella propria area si contende il pallone fino
    a 1,6 m (`AIR_MARK_R`, prima 0,95) con +15% (`CORNER_AIR_EDGE`).
  - **Portiere** (tutti e due): oltre alle uscite di prima, esce anche se è in anticipo di solo 0,1 s sul primo
    attaccante quando il cross scende entro 6 m dalla porta (`CORNER_GK_CLAIM_*` in `ai.gd`); sotto il pallone +12%
    (`CORNER_GK_WIN`). Provato a 7-14 m: il portiere prendeva quasi ogni cross (CPU al 2%, angoli inutili, 4 gol a
    porta vuota); 0,2-0,3 s di anticipo non cambiano niente (i tempi vanno a passi di 0,1 s).
  - In `motion.gd` solo due ganci (`airDuelR`, `gkClaimBonus`, segnaposto in `base.gd`), lontano dai contrasti.
- **Misura**: banco nuovo `godot/tools/banco_angoli.gd` (angoli ripetuti a seme fisso, partita con le opzioni del gioco,
  persona simulata `dito_motore.gd`, gol = entro 12 s come in `controllo_gameplay`).
  CPU contro di noi: **10,8% → 3,5%** (semi 1-3001, 400 angoli); altri semi: 14,5% → 5,5% (200 angoli); versione senza
  la seconda palla su 1000 angoli: 4,3%. Primo tocco di testa degli attaccanti 106 → 56 su 400, portiere che prende o
  respinge di pugno al primo tocco 7 → 59, gol a porta vuota 0-1. Nostri angoli contro la CPU: **7,5% → 8,0%**
  (400 angoli, rumore).
- **Partite** (`controllo_gameplay`, umano 60 contro CPU 60, 180 partite, stessi semi prima e dopo): gol da angolo della
  CPU **29 su 285 (10%) → 9 su 270 (3%)**; della persona 1/49 → 0/54 (la persona batte pochi angoli: il dato vero è
  quello del banco); V/N/P 52/85/43 → 79/64/37; gol a partita 0,67-0,54 → 0,76-0,39 (la CPU: −20 gol da angolo;
  la persona +17 gol, da tiri raso/a giro: non tocca gli angoli, la partita cambia strada dopo il primo angolo e il
  rumore su ~130 gol è ±11). Fluidità e "bug?" uguali a prima.
- **Obiettivo raggiunto** nel banco (3-8%). Test: `tests/test_angoli_difesa.gd` (8); `tests/corner_lab.gd` ha
  l'opzione `rifiniture` e conta il pugno come uscita non a vuoto.
- **Da provare sull'iPhone**: se sugli angoli della CPU i nostri difensori attaccati agli attaccanti sembrano naturali,
  se il portiere che esce sui cross corti piace.

## 2026-11-24 — Godot: tornano i falli (pochi), con punizioni, vantaggio, cartellini e qualche rigore
Il controllo del gameplay aveva visto **zero falli** in 400+ partite: venivano solo dalle scivolate, tolte il 2026-11-20.
Proposta approvata da Luis: rimetterli, pochi, sui contrasti da dietro o in ritardo.
- **Dove**: `godot/sim/falli.gd` (nuovo anello della catena tra `motion.gd` e `testa.gd`), opzione `"falli": true`
  del Match messa da `gioco.gd` (spenta in lezioni e prove di tiro; spenta nei test di confronto col JS, che restano
  identici). Il fallo usa `foulCall` di `motion.gd` (prima `foul`, che resta per la scivolata come in JS).
- **Regole** (costanti in cima a `falli.gd`): angolo = coseno tra dove guarda il portatore e dove sta chi entra.
  Sotto −0,35 **da dietro** (fallo 90% × fattori, giallo 35%), fino a 0,1 **di fianco** (40%, giallo 10%), sopra
  **frontale = sempre pulito** (e non consuma numeri casuali). **In ritardo**: entro 0,3 s dal calcio, avversario a
  meno di 1 m che va addosso a chi ha calciato a più di 3,5 m/s, 18% × fattori (un tentativo a testa per calcio), giallo
  30%. Fattori: velocità di chi entra (/5 m/s, 0,5-1,5), difesa (±1,5% per punto da 60, 0,5-1,6), pioggia ×1,25,
  **squadra della persona ×0,3** (la persona difende due terzi del tempo e la sua difesa "magnetica" entra tanto: con
  ×0,6 i suoi falli erano l'80%). Il portiere non fa falli.
- **Esito**: secondo giallo = rosso ed espulso (come prima). In area rigore. Vantaggio sul contrasto come prima
  (`advantageOk`), chi ha fatto fallo si ferma 0,5 s e non contrasta per 1 s. Fallo in ritardo fuori area: vantaggio
  solo negli ultimi 35 m (se il pallone si perde entro 2,5 s si torna alla punizione), più indietro punizione subito.
  Fallo in ritardo **sul tiro**: da fuori area non si fischia; in area il tiro va avanti ("Vantaggio!") e se non è gol
  è **rigore** (`penPend`, `falliStep`, al massimo 3 s; ribattuta presa da un compagno = si gioca).
- **Numeri** (`tools/controllo_gameplay.gd`, persona simulata, umano 60 contro CPU 60, 120 partite da 2×150 s, stessi
  semi; prima = codice di partenza, dopo = con l'opzione): falli 0 → **2,2 a partita** (persona 1,4, CPU 0,8; per 90'
  ~40), gialli 0 → 0,58, rossi 0 → 0 (1 su 60 partite in una prova intermedia), rigori 0 → 0,025 (3 in 120 partite,
  tutti dopo un fallo sul tiro in area), punizioni 0 → 1,5 (6 gol), vantaggi 0 → 0,94; V/N/P 29/52/39 → 35/44/41,
  gol 0,46-0,60 → 0,56-0,60, tiri 2,3-8,1 → 2,3-8,7. Come: in ritardo 198, da dietro 39, di fianco 27 (su 264).
- **Parti rimaste ferme e sistemate**: con un fallo e il vantaggio nello stesso passo la scritta "Ammonito" veniva
  coperta subito da "Vantaggio!"; sul rigore "RIGORE!" copriva il cartellino. Ora: cartellino disegnato sopra la
  scritta (`hud.mostra_cartellino`, giallo o rosso, sparisce con la scritta), "Ammonito"/"Espulso!" col nome,
  "Vantaggio!" col nome e il cartellino, "RIGORE!" col nome e il cartellino. Tabellino: righe Ammonizioni ed Espulsioni
  (solo se ce ne sono) nel dopo partita, nelle statistiche e nella fine partita di prova; "ammonito"/"espulso" nella
  pagella (`conta_giocatori` conta `gialli`/`rossi`, fuori dalla crescita). Nuove statistiche `yellows`/`reds` del Match.
  Punizione con barriera, rigore, espulsione (fuori dal campo, si gioca in 10), vantaggio e ritorno alla punizione
  verificati da test e schermate.
- **Non convince / da sapere**: la CPU non fa mai falli da dietro sul portatore della persona (alle spalle si apre la
  fuga col tasto Scatto e il difensore non contrasta): i falli della CPU sono quasi tutti in ritardo. I rigori restano
  rarissimi (1 ogni ~40 partite): in area i contrasti sono pochissimi. Il fallo non ha un'animazione (niente caduta,
  niente arbitro: le clip `giallo` dell'arbitro restano non usate).
- Test: `tests/test_falli.gd`. Prove a schermo: `--scena=fallo|rigore|espulso`.

## 2026-11-24 — Godot: giocatori che non si compenetrano, respiro dopo il recupero palla (opzione `contatti`)
Luis dall'iPhone: "ogni tanto i giocatori si compenetrano" e "quando il mio giocatore recupera la palla sono talmente uno
sopra l'altro che qualunque passaggio io faccia mi rubano la palla".
- Causa: il motore teneva i centri ad almeno 0,7 m (separazione rigida in `motion.gd`), ma le figure sono ingrandite
  ×1,25: a 0,7 m il difensore piegato in avanti entra con la testa nel petto del portatore (prova_vista
  `--scena=contatto --dist=0.7`); due giocatori stavano sotto 0,85 m il 30% del tempo di gioco. Dopo un recupero
  l'avversario più vicino era sotto 1 m nel 37% dei casi, il duello/fuga (rallenty che invita a passare) si apriva nel
  94%, e un passaggio della persona con un avversario entro 1 m veniva intercettato entro 1 s nel 44% dei casi (spesso
  nello stesso passo del calcio: il pallone parte 0,6 m davanti al portatore, cioè sui piedi di chi ha appena perso palla).
- Scelte (`godot/sim/contatti.gd`): spinta morbida fino a 0,9 m (il portatore non viene spostato, chi va addosso perde
  la velocità verso l'altro); respiro dopo il recupero della persona (0,8 s senza contrasti, avversari entro 2,5 m
  senza contrasto per 1,1 s); passaggio della persona non intercettabile nei primi 3 m da chi stava entro 1,5 m dal
  pallone, o entro 2,5 m fuori dalla linea del passaggio. Solo per la persona: la CPU non ha il respiro.
- Misure (controllo_gameplay, 80 partite stessi semi, `--senza-contatti` contro con): sotto 0,85 m 30% → 0% del tempo;
  distanza minima media 1,44 → 1,53 m; passaggi della persona intercettati entro 1 s 21% → 13% (con avversario entro
  1 m 44% → 12%); recuperi persi entro 2 s 21% → 19%, di cui per contrasto 12 → 3 (il resto sono dribbling scelti e
  passaggi più lunghi); V/N/P 35/30/15 → 34/34/12, gol 0,86-0,45 → 0,81-0,38. La CPU resta competitiva.
- Resta da provare sull'iPhone: se a 0,9 m le figure si toccano ancora nei contrasti di fianco; se il respiro sembra
  un regalo (eventualmente RESPIRO_PROTECT più corto).

## 2026-11-24 — Godot: fase difensiva della CPU e dei compagni CPU (Luis: "fai tutte le modifiche che ritieni sensate")
- **Dove**: `godot/sim/difesa.gd` (nuovo, nella catena tra `angoli.gd` e `ai.gd`), agganci in `ai.gd` (`defend`,
  `humanDefend`, `computeLines`, `_defLine`, `_styleDefPos`), `base.gd` (`anchor`: linea di pressing e fuorigioco),
  `match.gd` (rinvio dal fondo), `motion.gd` (tiro e compagno), regolazioni con nome in `stili.gd` (`*_R`) e in cima a
  `difesa.gd`. Tutto solo con l'opzione `rifiniture` (la accende `gioco.gd`): senza, motore identico (tracce del JS,
  `test_stili.gd`). Test: `tests/test_difesa_stili.gd` (7). Le linee disegnate e il dito della persona restano prima di
  tutto; la difesa "magnetica" non è toccata.
- **Cosa**: 1) rinvio dal fondo avversario: il portiere di chi difende resta in porta (prima andava al suo posto di
  squadra, ~33 m fuori, e con le riprese ci correva e poi tornava). 2) A uomo: abbinamenti rifatti ogni 0,1 s per zona e
  ruolo (prima i difensori sulle punte, poi i centrocampisti sui centrocampisti, poi gli avanzi; nessuno sui difensori
  avversari; la coppia di prima vale 5 m in meno per non scambiarsi di continuo), il difensore più centrale fa il libero
  dietro a tutti, sull'avversario al 78% (non più 88%) e al massimo 20 m dal proprio posto, difensori 2 m dietro la palla,
  centrocampisti al massimo 2 m davanti. 3) Fuorigioco: linea +6% (non più +2%), 4 m dietro il pallone (non 6), e quando
  il pallone va verso la porta avversaria a più di 3 m/s (passaggio indietro, rinvio) sale di 5 m tutta insieme, di corsa.
  4) Pressing: linea +8%, il secondo pressatore esce da 22 m prima della metà campo (non 12), corre; finché il primo
  non è addosso al portatore raddoppia, poi chiude la linea di passaggio verso il compagno più vicino (squadra della
  persona: lo stesso per il secondo dei suoi pressatori). 5) Rientri: col pallone nella propria metà gli esterni
  scendono (del tutto dal 25% del campo): i quinti della difesa a tre fino alla linea dei difensori, ali ed esterni
  alti fino a quella dei centrocampisti (regola su ruolo e posto, vale anche per le formazioni nuove). 6) Catenaccio:
  si prende in consegna l'avversario vicino al proprio posto fino a 10 m (non 7,5).
- **Bug trovato misurando**: un attaccante con un compagno proprio davanti tirava, il compagno "stoppava" il tiro nello
  stesso passo e tirava a sua volta: in una partita 400 tiri (studio, pressing 3-5-2, seme 7). Con `rifiniture` per
  0,3 s il tiro passa accanto ai compagni (`MATE_SHOT_T` in `motion.gd`).
- **Misura** (`tools/studio_stili.gd`, 8 partite per configurazione, stessi semi, CPU con lo stile contro CPU
  equilibrata 4-4-2, media delle 4 formazioni; prima > dopo):

  | Stile | linea (m) | larghezza | lunghezza | punte-centroc. | uomo vicino (m) | liberi | pressing 6 m | tiri subiti | gol subiti |
  |---|---|---|---|---|---|---|---|---|---|
  | Equilibrata | 25,5 > 25,1 | 35,4 > 35,2 | 30,3 > 30,1 | 12,9 > 12,8 | 8,1 > 8,1 | 2,4 > 2,5 | 0,7 > 0,7 | 8,0 > 7,6 | 0,4 > 0,5 |
  | Pressing | 31,2 > 33,5 | 34,8 > 34,7 | 30,3 > 30,2 | 12,9 > 12,5 | 6,5 > 6,3 | 2,0 > 1,8 | 0,9 > 1,0 | 3,3 > 1,7 | 0,3 > 0,1 |
  | Catenaccio | 15,7 > 15,7 | 32,2 > 31,5 | 31,2 > 31,9 | 13,1 > 14,6 | 9,7 > 9,0 | 3,3 > 3,2 | 0,6 > 0,6 | 5,6 > 6,7 | 0,5 > 0,8 |
  | A uomo | 42,2 > 28,3 | 51,5 > 44,9 | 28,0 > 35,0 | −0,3 > 8,0 | 4,6 > 7,0 | 0,4 > 1,7 | 1,0 > 0,9 | 2,7 > 6,3 | 0,2 > 0,6 |
  | Fuorigioco | 27,8 > 32,7 | 34,9 > 34,4 | 28,2 > 26,9 | 13,1 > 12,6 | 7,1 > 6,6 | 2,5 > 2,3 | 0,7 > 0,8 | 4,6 > 1,2 | 0,2 > 0,2 |

  Portiere fuori posto (oltre 18 m) mentre si difende: 1-3% del tempo > 0 in tutte le configurazioni. Rientri (media di
  tutta la fase difensiva): quinti del 3-5-2 44 > 39 m (difensori a 25), ali del 4-3-3 49,5 > 46,7; tiri subiti col
  4-3-3 equilibrato 13,9 > 10,8. A uomo la squadra ora è ordinata (mappa: linea a 28 m, libero dietro, centrocampisti
  davanti, punte sopra; prima difensori a metà campo e centrocampisti alla pari delle punte) e resta la più vicina agli
  avversari dopo il pressing (7,0 m contro 8,1 dell'equilibrata), ma non più incollata: subisce come una difesa normale
  (prima teneva gli avversari bassi perché era tutta nella loro metà campo).
- **Non raggiunto**: il pressing "a 6 m" sale poco (0,9 > 1,0 giocatori vicino al portatore): il secondo pressatore chiude
  la linea a 2,5-4 m invece di stare addosso; l'effetto si vede nei tiri subiti (dimezzati), non nel conteggio. Il
  fuorigioco fischiato resta ~0: gli attaccanti dell'IA non rischiano (lo fa l'altro lavoro sull'attacco). Catenaccio:
  gli avversari liberi nella propria metà restano 3,2 (blocco basso: quelli tra 25 e 50 m sono lontani per forza).
- **Equilibrio** (`tools/controllo_gameplay.gd`, forza 60 contro 60): stili della CPU a caso, 48 partite (semi 1-41):
  persona V/N/P 19/22/7 > 12/21/15, gol 0,75-0,48 > 0,54-0,69, tiri 2,1-7,0 > 2,3-7,7. CPU equilibrata, 24 partite:
  2/11/11 > 8/7/9. Cioè le modifiche generali non peggiorano la persona; il calo con gli stili viene dagli stili che
  prima difendevano male (a uomo, fuorigioco) e ora difendono come l'equilibrata. Rumore grande (stessi semi, gruppi di 8
  partite da 0/4/4 a 5/2/1).
- **Da provare sull'iPhone**: se contro una squadra "A uomo" la partita si apre (prima c'erano 40 m vuoti dietro), se
  con "Fuorigioco" la linea che sale insieme si vede e non sembra un difetto, se il pressing della CPU risulta fastidioso
  ma giusto, se gli esterni che rientrano a cinque si notano.

## 2026-11-24 — Godot: fase d'attacco della CPU (opzione `attacco`, dopo lo studio degli stili)
Luis: "Fai tutte le modifiche che ritieni sensate" sullo studio degli stili (`tools/studio_stili.gd`). Tutto in
`godot/sim/attacco.gd` (nella catena tra `ai.gd` e `parata.gd`, metodi che ridefiniscono `anchor`, `support`,
`computeChasers`, `passOptions`, `_styleScore` e chiamano `super()`), solo con l'opzione nuova `attacco` del Match
(la accende `gioco.gd`; spenta nei confronti col JS: impronte identiche). Regole sui ruoli e sui posti (bx/by, chi è
largo), non sui nomi delle formazioni: valgono anche per le formazioni nuove.
- **1. Nessuno entrava in area**: col pallone nostro sulla trequarti (oltre il 60% del campo) o sulla fascia (|x| > 14 m
  dal 50%) uno o due compagni (prima le punte, poi i centrocampisti; mai i compagni d'appoggio) vanno verso primo e
  secondo palo; finché il pallone è del portatore restano sulla linea del fuorigioco (o all'altezza del pallone se è più
  avanti), quando parte il nostro passaggio entrano di corsa. Il portatore della CPU crossa anche verso chi sta
  arrivando (in gioco adesso, arriva sul punto entro il volo del pallone + 0,6 s, punto libero 1,5 m; Fasce 1,0 m).
  Vale anche per i compagni CPU della persona (che decide lei se crossare).
- **2. Fuorigioco**: un attaccante della CPU vicino alla linea a volte anticipa il taglio (2 m oltre per 2 s; più spesso
  con più spazio dietro la difesa, contro la difesa Fuorigioco ×1,4, con squadre meno brave) e il portatore della CPU a
  volte non se ne accorge e gli passa il pallone (anche a una punta rimasta appena oltre, meno spesso). I compagni della
  persona non lo fanno (i suoi passaggi non diventano fuorigioco per colpa della CPU).
- **3. Contropiede**: in attacco non più basso (CONTRO_LOW veniva applicato quando attaccava), in difesa più basso
  (−4% del campo) e più stretto (×0,93); nella ripartenza centrocampisti e punte salgono di corsa. Con −6% e ×0,88 la
  squadra subiva il doppio dei tiri: ridotto.
- **4. Fasce**: con un esterno davanti sulla stessa fascia, sul lato del pallone dalla metà campo il terzino sale in
  sovrapposizione (+20% del campo) e l'esterno si stringe (72% della larghezza); la mezzala del 4-3-3 non va più sulla
  riga se c'è già l'ala.
- **5. Lanci lunghi / Contropiede**: nel contropiede il pallonetto vale meno (−0,35 e premio d'avanzamento ×0,2),
  nei lanci lunghi il lancio alto +0,25.
- **6. Terzino ed esterno sulla stessa riga**: il più arretrato sta all'80% della larghezza (24 m invece di 30).
- **Numeri** (studio_stili, stessi semi, 8 partite CPU contro CPU per stile e formazione, media delle 4 formazioni,
  prima → dopo): giocatori in area col pallone sulla trequarti: equilibrato 0,24 → 0,46, contropiede 0,11 → 0,38,
  possesso 0,17 → 0,57, fasce 0,08 → 0,77, lanci 0,70 → 0,69; cross a partita: 0,97 → 1,81, 0,78 → 1,84, 0,50 → 1,28,
  1,66 → 2,47, 1,81 → 2,72; azioni in cui il portatore entra in area (fasce) 0,9% → 7,0%. Fuorigioco: 0 → 1,35 a
  partita (le due squadre insieme); contro la persona simulata la CPU ne prende 0,2-2,2 a partita. Contropiede: linea
  difensiva in difesa 23,9 → ~21,2 m, in attacco 31,9 → ~35,4 m; palloni alti contropiede ~20% → ~13%, lanci lunghi
  27% → 37% (ora ben distinti). Larghezza in attacco ~54 → ~51 m. Giocatori fermi e ammassati: come prima (~0).
- **Equilibrio** (controllo_gameplay, persona 60 contro CPU 60, 40 partite stessi semi, `--senza-attacco` → con):
  V/N/P 15/19/6 → 16/21/3, gol 0,72-0,50 → 0,82-0,42, tiri 2,0-6,9 → 2,7-7,8, possesso umano 35% → 34%, fuorigioco
  della CPU 0 → 1,1 a partita. Il resto (rallenty, riprese, falli) uguale.
- **Non convince / da sapere**: le Fasce perdono più palloni (passaggi riusciti ~83% → ~75%: tanti cross contesi). Nel
  contropiede le ripartenze che arrivano negli ultimi 30 m entro 10 s calano (~28% → ~20%): meno pallonetti, squadra
  più bassa. Una prova con pallonetto meno penalizzato (0,15) non è stata misurata (misure fermate per memoria bassa).
  Nel controllo "portatore umano fuori" 1 → 4 in 40 partite (codice della persona non toccato, da tenere d'occhio).
- Test: `tests/test_attacco.gd` (10). Strumenti: `--senza-attacco` in `studio_stili.gd` e `controllo_gameplay.gd`.
- Da provare sull'iPhone: le corse sul primo e secondo palo quando si arriva sul fondo (si vede a chi crossare?), i
  fuorigioco della CPU (pochi e credibili?), il terzino che si sovrappone nelle Fasce.

## 2026-11-24 — Godot: colpo di testa conteso in difesa e sui passaggi alti (salto conteso, `sim/testa.gd`)
- **Prima, in difesa sui cross**: nessun fermatempo e nessun comando. Il nostro difensore entro 32 m dalla nostra
  porta (`HEAD_CLEAR_ZONE`) col pallone sopra 1,3 m respingeva **da solo** ("clear": alta, verso l'esterno, a caso,
  spesso agli avversari), oppure perdeva il contrasto aereo automatico (`aerialDuel`) e l'attaccante tirava di testa;
  più lontano dalla porta un pallone sopra 1,7 m gli passava sopra (non lo toccava proprio) e sotto lo stoppava. La
  linea disegnata in difesa non contava. Per questo non si capiva se colpiva da solo o no.
- **Ora** (`kind` "def" e "pass" di `HeadWin`): fermatempo come quello del cross (tempo fermo 3 s, visuale vicina,
  cerchio; in difesa scritta "Respingi!") quando un avversario è **attaccato** a chi colpisce per noi e **il nostro
  vince il salto**. Attaccato (`headRival`): entro `HEAD_ATT_NEAR` 2,5 m da lui adesso, arriva entro `HEAD_ATT_R` 1,5 m
  dal punto del colpo al più `HEAD_ATT_T` 0,3 s dopo di lui e non dopo il pallone. L'esito si decide col seme prima di
  aprire (`headDuelRoll`: 0,5 + 1,5 × differenza di `tes` + 1 per secondo di anticipo, tra 0,15 e 0,85): il fermatempo
  si apre solo se vince il nostro. Linea = passaggio/rinvio di testa (in difesa mai tiro, anche se la linea finisce in
  porta; sul passaggio tiro solo entro 17 m), lungo al massimo 30 m. **Senza linea entro 3 s, o col salto perso,
  colpisce l'avversario** (`headGive`, richiesta di Luis durante il lavoro: "chi ha il diritto e non lo usa lo passa
  all'altro"): tiro o respinta di testa se la sua IA li fa lì, altrimenti di testa a un compagno libero più avanti
  (`headRivalHit`); il nostro non tocca il pallone. Senza avversario attaccato tutto come prima (lancio sulla fascia:
  controllo e corsa). I cross in attacco (`kind` "att") identici a prima.
- **Momento speciale**: con la sola definizione di "attaccato" i fermatempo erano 9-12 a partita (la CPU marca stretta
  e la persona simulata lancia alto quando la linea è chiusa): 8,2 → 6,3 con l'avversario entro 2,5 m (prima 4); il
  limite 1,7 m sul passaggio non cambiava quasi niente. Deciso: solo negli ultimi 35 m (`HEAD_PASS_ZONE` /
  `HEAD_DEF_ZONE` 15 m oltre la metà campo); a centrocampo il salto resta automatico come prima.
- **Numeri** (controllo_gameplay, 10 partite 2×150 s, forza 60, seme 1): fermatempo in difesa 2,5 a partita, sui
  passaggi alti 1,3, cross 0,4; tempo vero fermo per la testa 7,1 s a partita. Salti decisi prima: difesa 25 vinti / 25
  persi, passaggi 13/12. Salto ceduto all'avversario: sponda 27, tiro 3, respinta 2. Nostri lanci alti (19 a partita):
  controllati 107 su 188, fermatempo 17. Risultati e resto come prima (V/N/P 2/6/2, nessun "BUG?").
- Test: `tests/test_testa_contesa.gd` (12). Strumenti: contatori `testa_fermatempo:def|pass`, `testa_salto:*`,
  `testa_ceduta:*`, `lancio_esito:*` in `controllo_gameplay.gd`; la persona simulata (`dito_motore.gd`, `harness.gd`,
  `bot_dito.gd`) nei salti contesi senza tiro disegna al compagno più avanti (`headMateTarget`). Scene:
  `--scena=testa_difesa|testa_difesa_linea|testa_passaggio|testa_passaggio_linea|testa_fascia`.
- Da provare sull'iPhone: si capisce subito perché il tempo si ferma in difesa (scritta "Respingi!")? 3 s bastano per
  disegnare il rinvio? Il salto ceduto all'avversario quando non si disegna è chiaro o sembra un errore?

## 2026-11-26 — Giochetti del dribbling rifatti (16) e corpi staccati
- **Chiesto**: "le animazioni delle skill fanno pena", più skill vere. Viste nei video: corpi uno dentro l'altro, i tre
  giochetti tutti uguali, postura rigida, inciampo che non si capiva.
- **Il giochetto lo sceglie il motore** (`sim/skill.gd`, solo con `rifiniture`): serve perché ognuno dura un tempo
  diverso (0,32-0,6 s contro 0,35 fissi di prima; media ~0,43). Generatore a parte (`skillRng`): `rnd()` non cambia e
  l'esito è lo stesso con e senza rifiniture (test `test_esito_uguale_con_e_senza_rifiniture`, `test_skill.gd`).
- **Distanza tra i due** (`DRIB_GAP`): provato a far partire il dribbling più lontano (2,6 m invece di 2): cambiava
  l'istante del numero casuale e quindi l'esito di alcuni semi; scartato. Ora l'esito arriva a 2 m come prima e DOPO
  il difensore indietreggia fino a 2,6 m (spostato lui, mai il portatore). Nel fallito il portatore resta fermo 0,6 s
  invece di 0,35 (cade su un ginocchio): è l'unica cosa che cambia un po' il gioco, a sfavore di chi sbaglia.
- **Telecamera del dribbling dall'altra parte**: prima stava dal lato del sorpasso e il portatore passava davanti al
  difensore coprendolo (a schermo sembravano uno dentro l'altro anche a 1,5 m); ora guarda nel verso dello scatto. Più
  vicina (7,5 m invece di 12) e più bassa: i giochetti a schermo erano piccoli.
- **Numeri** (`controllo_gameplay`, 10 partite 2×150 s, forza 60, seme 1; prima → dopo, col portatore fermo 0,8 s):
  V/N/P 2/6/2 → 3/2/5, gol 0,5-0,5 → 0,7-0,7, tiri 2,2-5,9 → 1,7-8,7, Dribbling 16,3 a partita (riusciti 44% → 39%),
  rallenty del dribbling 41 → 52 s veri a partita, "BUG?" nessuno. Campione piccolo (le partite cambiano dal primo
  dribbling in poi), ma la CPU tira di più: per prudenza il portatore fermo dopo il fallito è sceso da 0,8 a 0,6 s
  (non rimisurato).
- **Nomi**: niente nomi di calciatori veri a schermo ("Taglio secco", "Finta e giro").
- **Ancora debole** (visto nei video): colpo di tacco e taglio secco si leggono poco da lontano; la corsa subito dopo
  lo scatto è ancora un po' rigida; i dribbling dell'IA usano ancora i giochetti vecchi.
- Da provare sull'iPhone: i giochetti si distinguono? La telecamera dall'altra parte disturba? 0,6 s fermo dopo il
  dribbling fallito è troppo?

## 2026-11-26 — Godot: ruoli specifici (TD, DC, CDC, ES, COC, ATT, ...) e 14 moduli
Richiesta di Luis: ruoli veri al posto di D/C/A, compatibilità, seconda scelta, statistiche sensate per ruolo, moduli
nuovi. Correzioni arrivate durante il lavoro: nel 4-2-3-1 ai lati del trequartista ci sono gli esterni (non le ali);
le fasce si chiamano **esterno sinistro / destro (ES / ED)**.
- **Modello**: campi nuovi del giocatore `ruolo` e `ruolo2`; `pos` (P/D/C/A) resta ed è il gruppo del ruolo (motore,
  IA, confronti col JS). Tutto in `godot/sim/ruoli.gd`; la tabella dei ruoli per posto è `Ruoli.POSTI` (un posto solo
  da cambiare se Luis corregge un modulo; le posizioni x/y restano in `core.gd`).
- **Malus** (moltiplica tiro, passaggi, dribbling, difesa, testa, come il vecchio `POSPEN`; velocità e fisico no):
  suo ruolo 1 · seconda scelta 0,98 · compatibile 0,97 · altra fascia 0,94 · stessa linea 0,90 · linea accanto 0,86 ·
  terzino⇄ala stessa fascia 0,84 (tolto il 2026-11-27: ora 0,72, vedi sotto) · difesa⇄attacco 0,72 (era 0,82) · porta 0,6 come prima. Prima dentro la stessa linea
  non c'era malus: ora un DC terzino perde il 10%.
- **Valutazione**: pesi per ruolo sulle sotto-statistiche (`PESI`) più una taratura per ruolo (`tara()`), calcolata
  dalle tabelle, che fa valere un giocatore "generico" in media quanto valeva con la formula del web: così valore,
  prezzi, stipendi e forza squadra non si spostano. Il portiere resta con la formula del web.
- **Giocatori generati**: restano generati con gli stessi numeri casuali del web (`genPlayer`), poi `Ruoli.modella`
  sposta le sotto-statistiche secondo il profilo del ruolo e rimette la valutazione uguale a quella che avevano (le
  squadre della CPU restano forti uguali). Rosa nuova: 2 P, DC DC TS TD DC TD, CC CC ES ED CDC COC, ATT ATT AS AD.
- **Salvataggi vecchi**: nessuna statistica cambia. I titolari prendono il ruolo del posto dove la persona li ha
  messi (tra destra e sinistra le statistiche non dicono niente), gli altri il ruolo del loro gruppo dove valgono di
  più, con un freno ai doppioni (`QUOTE`). Seconda scelta: tra quelle sensate per il ruolo, dove valgono di più.
  Il potenziale `pot` si sposta di quanto si sposta la valutazione.
- **Scelte mie da confermare**: (1) il COC ha come seconde scelte possibili ATT/AS/AD, mai CC (Luis: "COC non può fare
  CC"); (2) terzino e ala dello stesso lato non sono compatibili direttamente (solo tramite l'esterno); (3) nel 4-3-2-1
  i due dietro la punta sono ATT (come scritto da Luis), quindi il modulo ha 3 attaccanti per il motore; (4) nessun
  comportamento nuovo dell'IA per ruolo: contano i posti del modulo; (5) il filtro del Mercato resta per gruppo
  (Portieri/Difensori/...), con la sigla specifica su ogni riga; (6) l'editor del campione fa scegliere tra i 12 ruoli;
  (7) a metà stagione crescono/calano le sotto-statistiche che contano per il ruolo (`PESI`), non più quelle del gruppo.
- **Non misurato**: l'equilibrio (vittorie, gol) con `controllo_gameplay`: le squadre della CPU hanno la stessa
  valutazione di prima ma statistiche distribuite diversamente (ali più veloci, centrali più forti di testa).

## 2026-11-26 — Godot: calci piazzati scelti nella Rosa, capitano = campione
- Tasto "Calci piazzati" accanto a "Forza squadra" (i tre tasti in alto restano tre): menu a due passi, 5 scelte e poi
  "Automatico" + i 10 titolari di movimento. Si sceglie solo tra i titolari; se poi il scelto va in panchina la scelta
  resta salvata ma in partita vale l'automatico (il menu lo dice).
- Punizioni: "lontana" oltre 25 m dalla porta avversaria (`PUN_LONTANA_M`). Oltre 45 m (`PUN_ZONA_M`, scelta mia) batte
  il più vicino come sempre: sennò il battitore scelto verrebbe portato a battere anche le punizioni nella nostra area.
- Senza scelta la punizione la batte sempre il più vicino (com'era): "automatico" non cerca il migliore in `pun`.
- Il portiere non si può scegliere. La CPU non usa le scelte.
- Capitano: "C" gialla sulla carta del campione e "· capitano" nel pannello. **Non fatto**: la fascia al braccio in
  partita (serve un pezzo nuovo nel modello della figura: non era "semplice"). Fatta il 2026-11-27, vedi sotto.

## 2026-11-27 — Fascia da capitano in partita; terzini mai ali
- **Chiesto** (Luis): "Mettila la fascia al braccio in partita, basta una striscia gialla sul braccio" e "i terzini
  non possono mai fare le ali, al massimo gli esterni come dicevamo".
- **Fascia**: dipinta nello shader della divisa, non un pezzo di modello: banda gialla sul braccio sinistro (x > 0
  nella posa a T) tra il 20% e il 47% del tratto spalla→gomito, cioè sopra l'orlo della manica corta (che finisce dal
  55%); con le maniche lunghe sta sulla manica, senza maniche sulla pelle. Segue il braccio da sola (posa di riposo),
  niente costo in più per gli altri 21. Bordi più scuri (fino al 55%) per vederla anche su una maglia gialla. Lo shader ha
  già 16 instance uniform (il massimo di Godot): l'accensione è `numero.z` + 2 (z era 0/1 = cognome sì/no). Solo il
  campione della squadra della persona (`p.team == me`, `src.champ`); se il campione esce in un cambio la fascia
  non passa a nessuno (scelta mia: il capitano è sempre il campione).
- **Terzini e ali**: incompatibili come difesa⇄attacco (0,72) anche dello stesso lato; nessuna seconda scelta tra
  loro; una seconda scelta vietata già salvata (o chiesta nell'editor del campione) diventa l'esterno del lato del
  ruolo (TS/AS → ES, TD/AD → ED). La formazione automatica non li mette mai lì finché c'è un altro giocatore
  (penale di 1000 punti nei conti, non nella valutazione mostrata). La Rosa resta libera: la persona può ancora
  mettere a mano un terzino sull'ala, col malus pieno e il badge "fuori ruolo".

## 2026-11-27 — Portiere che si butta a vuoto sui palloni da lontano
- **Chiesto** (Luis, provato sull'iPhone): "con i cross da lontano o tiri da lontano il portiere si butta a vuoto molto
  prima e la palla va in rete".
- **Causa** (`sim/parata.gd`, `_gkAutoTimed` per il portiere automatico e quello della CPU, `_paraTry` per il manuale):
  il tuffo partiva quando al pallone mancava `max(PARA_LEAD, need)`, con `need` = tempo che serve alla mano per arrivare
  al punto. Il tuffo dura 0,8 s (`motion.gd` `diveStep`, poi il portiere è a terra e non para più): se il punto era
  lontano dal portiere (angolo lontano, pallone fuori dai pali) `need` arrivava a 0,9-1,7 s e il portiere era già per
  terra quando arrivava il pallone. Secondo caso: un **lancio alto** da 30-40 m (cross, lancio lungo) che dopo il
  rimbalzo finirebbe verso la porta viene rilevato come tiro (`detectShot` guarda solo la traiettoria): il portiere
  restava sulla linea in "modo tiro", non usciva come sui cross e si tuffava anche 1-2 s prima su palloni che poi
  toccava un altro.
- **Cosa**: `PARA_DIVE_WIN` 0,7 s = il tuffo non parte mai prima (`paraDiveAt`, anche per il manuale, dove però già non
  succedeva). Sul lancio alto rilevato come tiro (`paraLancio`, `kick.type` "loft") finché all'arrivo manca più di
  0,7 s (o se è uscito a prenderlo) il portiere fa come sul cross (`_gkSulLancio`: `gkAI` di `ai.gd` col tiro nascosto:
  esce solo se ci arriva prima degli attaccanti, altrimenti resta tra i pali e si piazza); poi si tuffa se serve.
  `userDive` col portiere automatico non conta più (il gioco non la manda; il dito finto dei controlli sì e falsava le
  misure). Tutto solo con l'opzione `parata`: confronti col JS identici, nessun numero casuale nuovo.
- **Numeri** (`tools/misura_portiere.gd -- --scene --semi=4`, 28 tiri per caso, prima → dopo): tuffo partito più di
  0,8 s prima dell'arrivo, portiere della CPU: rasoterra 35 m 6 → 0 (gol 2 → 0), alto 40 m 6 → 0, mezza altezza 45 m
  5 → 0, a giro 45 m 5 → 0; nostro automatico: 4/4/4/4 → 0. Anticipo massimo 0,95-1,15 s → 0,68 s. Parate da 35-45 m
  salite di 2-4 su 28; da 25 m identiche; manuale identico. Partite vere (`-- --partite=8`, opzioni del gioco, dito
  finto): tuffi a vuoto troppo presto 1 → 1 (sono già rari col portiere automatico vero), gol a partita
  0,75-0,88 → 0,75-1,00 (campione piccolo, le partite divergono dal primo tuffo diverso). `controllo_gameplay` non
  accende `parata`: con questa modifica non cambia niente lì, non rimisurato.
- **Test**: `tests/test_portiere_lontano.gd` (tiri da 30-45 m: nessun tuffo finito prima del pallone e parate ≥ 70%;
  lanci lunghi rilevati come tiro: niente tuffo prima di 0,7 s; da 14-18 m all'angolo restano gol 20/23).
- **Ancora debole**: da lontano ora il portiere para quasi tutto quello che va nello specchio (il limite è solo la
  portata del tuffo); se i gol da fuori diventano troppo rari si può allargare il bersaglio o limitare i passi laterali.
  I lanci rilevati come tiro restano "tiri" per le statistiche e per `airPlay` (gli attaccanti non li colpiscono di
  testa al volo): non toccato. Da provare sull'iPhone: tiri da fuori e lanci lunghi della CPU contro il portiere
  automatico.
