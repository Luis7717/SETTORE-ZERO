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

## Fase D — come gioca la squadra
- **4. Stili di gioco**: nella schermata della Rosa si sceglie come gioca e si muove la squadra: **contropiede**,
  **possesso palla** (tanti passaggi corti), **gioco sulle fasce**, e altri (es. pressing alto, lanci lunghi).
  Vale per i compagni guidati dalla CPU e per le squadre avversarie (ognuna col suo stile).

## Fase E — modi di gioco nuovi
- **5. Momenti chiave** (fatta il 2026-11-22, da provare sull'iPhone; si sceglie sopra GIOCA, nell'amichevole e in
  Impostazioni, `settings.momenti`; codice in `godot/scripts/partita/momenti*.gd`, numeri in `DECISIONI.md`): invece di tutta la partita si giocano **circa 10 azioni** (Luis: "circa 10 in totale non 15"); il resto lo simula il
  motore e si vede come cronaca scritta. Più la mia squadra è forte rispetto all'avversaria, più azioni sono offensive;
  più l'avversaria è forte, più sono difensive; **mai meno di 3 azioni offensive**, anche con la squadra più scarsa, e
  devono essere occasioni vere (posizioni da cui si può segnare). Il resto sono azioni difensive e offensive miste.
  Ogni **azione offensiva parte da centrocampo** (o poco oltre) col pallone alla mia squadra verso la porta avversaria;
  ogni **azione difensiva** è lo stesso al contrario: parte da centrocampo con l'avversario che attacca verso la mia porta.
- **13. Allenamento libero**: tiri, punizioni, rigori con punteggio.

## Tenute da parte (da provare più avanti)
- 2. Tiro caricato col dito fermo (più forza, meno precisione).
- 3. Passaggio di prima (disegnare il gesto successivo mentre il pallone viaggia).

## Fuori dalle fasi
- **Altezza e corporatura** dei giocatori (2026-11-22, fatta, da provare sull'iPhone): basso/medio/alto e
  snello/normale/robusto, si vedono sulla figura e cambiano le statistiche in partita; il campione li sceglie
  nell'editor. Numeri in `DECISIONI.md`.
