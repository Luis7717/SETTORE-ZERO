# Piano delle novità (richiesta di Luis del 2026-11-21)

Le novità vanno nella **versione Godot** (quella che Luis gioca). La versione web resta com'è e riceve solo correzioni.
Il motore resta in due copie identiche (`src/sim` JS = riferimento con i test in Node, `godot/sim` = porting):
ogni cambio al motore si fa in tutte e due, con le fixture rigenerate.

## Fase A — correzioni dalla prova sull'iPhone (fatta)
- Righe bianche del campo che non si vedono; più tagli d'erba (strisce, quadrotti, cerchi concentrici, erba semplice...).
- Pallone invisibile (tutorial e partite); portiere che non si tuffa.
- Dribbling che parte vicino al difensore, verso il lato libero, col giochetto adatto al lato.
- Chi batte un calcio da fermo (rimessa, angolo, punizione, rinvio...) non può ritoccare il pallone per primo.
- Bordo scuro del rallenty più leggero (fatto).

## Fase B — carriera (fatta)
- **6. Il campione cresce giocando**: le statistiche del giocatore principale salgono con quello che fa in partita
  (dribbling riusciti → dribbling, gol e tiri → tiro, passaggi → passaggio, contrasti → difesa...).
- **7. Obiettivi della dirigenza**: a inizio stagione salvezza / metà classifica / promozione (o titolo), con soldi per il
  mercato in base al risultato.
- **8. Rivalità e derby**: una squadra del campionato è la rivale; pubblico più rumoroso, cori diversi, premio in più.
- **9. Stanchezza e infortuni tra le partite**: chi gioca sempre si stanca e ogni tanto si fa male; servono Rosa e cambi.

## Fase C — presentazione (fatta il 2026-11-21, da provare sull'iPhone)
- **1. Replay del gol**: 4-5 s di replay da un'altra visuale, al rallentatore, con la linea del tiro; si salta con un tocco.
- **11. Cronaca scritta**: frasi brevi in alto dopo le azioni importanti, generate dagli eventi del motore.
- **12. Esultanze**: solo per il **giocatore principale**; si sceglie nell'editor del personaggio (anche nell'editor
  iniziale) tra circa **15 esultanze**; dopo un suo gol parte quella scelta.
- **14. Statistiche a fine partita**: possesso, tiri, mappa dei tiri, voto a ogni giocatore.
- **10. Meteo e ora del giorno**: pioggia (palla più veloce, scivolate più lunghe), notte coi fari, neve rara.

## Fase D — come gioca la squadra (fatta il 2026-11-22, da provare sull'iPhone)
- **4. Stili di gioco**: nella schermata della Rosa si sceglie come gioca e si muove la squadra: **contropiede**,
  **possesso palla** (tanti passaggi corti), **gioco sulle fasce**, e altri (es. pressing alto, lanci lunghi).
  Vale per i compagni guidati dalla CPU e per le squadre avversarie (ognuna col suo stile).
  Fatto: nella Rosa tasto **Stile** con due selettori (attacco: equilibrato, contropiede, possesso, fasce, lanci lunghi;
  difesa: equilibrata, pressing alto, catenaccio, a uomo, fuorigioco), una riga di spiegazione ciascuno; ogni squadra
  della CPU ha il suo stile (fisso, dal seme e dall'identità), mostrato nell'hub prima della partita. Numeri in `DECISIONI.md`.
- **Portatore che si muove da solo** (aggiunta di Luis, 2026-11-22): senza strada il portatore della squadra umana avanza
  da solo secondo lo stile d'attacco (spazio libero, linee di passaggio, area, protezione palla, resta in campo); passaggi,
  tiri, Dribbling e Scatto restano al dito. La strada disegnata la toglie l'agente dei gesti.

## Fase E — modi di gioco nuovi
- **5. Momenti chiave** (fatta il 2026-11-22, da provare sull'iPhone; si sceglie sopra GIOCA, nell'amichevole e in
  Impostazioni, `settings.momenti`; codice in `godot/scripts/partita/momenti*.gd`, numeri in `DECISIONI.md`): invece di tutta la partita si giocano **circa 10 azioni** (Luis: "circa 10 in totale non 15"); il resto lo simula il
  motore e si vede come cronaca scritta. Più la mia squadra è forte rispetto all'avversaria, più azioni sono offensive;
  più l'avversaria è forte, più sono difensive; **mai meno di 3 azioni offensive**, anche con la squadra più scarsa, e
  devono essere occasioni vere (posizioni da cui si può segnare). Il resto sono azioni difensive e offensive miste.
  Ogni **azione offensiva parte da centrocampo** (o poco oltre) col pallone alla mia squadra verso la porta avversaria;
  ogni **azione difensiva** è lo stesso al contrario: parte da centrocampo con l'avversario che attacca verso la mia porta.
- **13. Allenamento libero** (fatto il 2026-11-22, da provare sull'iPhone): tiri, punizioni, rigori con punteggio.
  Dal menu principale e dalla casa della carriera (casella larga). Tira il **campione** (le sue statistiche contano)
  coi gesti della partita; portiere vero (squadra "Allenamento" livello 60, sempre uguale perché i record si
  confrontino). **Tiri**: 10 da posti diversi (4 fuori area, 6 dentro). **Punizioni**: 8 con la barriera del motore,
  da 18-28 m e di lato. **Rigori**: 5, poi a oltranza fino al primo errore (massimo 15). Gol = 10 punti, +5 vicino al
  palo (entro 0,9 m), +5 sotto la traversa (sopra 1,64 m): angolino = 20. Record per prova nel salvataggio (campo
  `prove`, assente nei salvataggi vecchi = nessun record); a fine prova punteggio, record e "Riprova" (posti nuovi).

## Tenute da parte (da provare più avanti)
- 2. Tiro caricato col dito fermo: **scartato** (Luis 2026-11-22). Al suo posto la **forma del tratto**: dritto =
  rasoterra, curvo = a effetto e alto, con la potenza giusta per arrivare dove finisce la linea (fatto, da provare
  sull'iPhone). Insieme: col pallone ogni linea è un passaggio o un tiro, niente più strada da correre; nell'allenamento
  guidato le lezioni Passaggio rasoterra, Passaggio a effetto, Tiro rasoterra e Tiro a giro con la linea guida da seguire.
- 3. Passaggio di prima (disegnare il gesto successivo mentre il pallone viaggia): **fatto** (2026-11-22, da provare sull'iPhone).

## Fuori dalle fasi
- **Altezza e corporatura** dei giocatori (2026-11-22, fatta, da provare sull'iPhone): basso/medio/alto e
  snello/normale/robusto, si vedono sulla figura e cambiano le statistiche in partita; il campione li sceglie
  nell'editor. Numeri in `DECISIONI.md`.
