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
