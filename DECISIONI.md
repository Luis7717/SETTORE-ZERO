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
