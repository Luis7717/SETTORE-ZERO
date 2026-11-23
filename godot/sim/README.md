# Motore della partita in GDScript (`godot/sim/`)

Porting riga per riga del motore puro JavaScript (`src/sim.js` + `src/sim/*.js`) per Godot 4.7.2.
Niente nodi né grafica: solo classi `RefCounted` con tipi statici, che girano anche senza scena (`godot -s`).
Stessi nomi del JS: costanti (`DUEL_R`, `RUN_MAX_LEN`, …), metodi e campi (`userRun`, `p.beatBy`, `m.ball.kick`, …),
così una modifica al motore JS si riporta qui cercando lo stesso nome.

**Il porting dà gli stessi bit del JS:** stessi numeri casuali, stesse funzioni matematiche, e in 7 partite intere
lo stato (pallone e 22 giocatori) è identico al JS a ogni passo, con stessi eventi, punteggio e statistiche.

## File: JS → GDScript

| JS | GDScript | Contenuto |
|---|---|---|
| `src/sim/core.js` (`rng32`) | `rng.gd` (`SimRng`) | numeri casuali con seme, maschere a 32 bit e `Math.imul` esatti |
| `src/sim/core.js` | `core.gd` (`SimCore`) | misure del campo, formazioni, `effStats`, `headingOf`, `ballPhys`, `segInfo`; `hyp` = `Math.hypot` di V8 |
| — | `fmath.gd` (`SimMath`) | `sin`, `cos`, `atan2` fdlibm, gli stessi bit di V8 (vedi sotto) |
| oggetti letterali del JS | `records.gd` (`SimRec`) | classi dei dati: `Player`, `Ball`, `Kick`, `Shot`, `Move`, `Run`, `Duel`, `Restart`, `Advantage`, … |
| `src/sim/match.js` (stato e aiuti) | `base.gd` | campi della partita, `rnd`, `ev`, `team`, `gk`, `place`, `anchor`, `offsideY`, `runOf`, … |
| `src/sim/duel.js` | `duel.gd` | duello, dribbling, fuga e Scatto (`aheadLine`, `updateFlee`, `burst`), area di tiro, calo per uso |
| `src/sim/motion.js` | `motion.gd` | movimento, contrasti, contatti col pallone, colpi di testa, parate, falli |
| `src/sim/ai.js` | `ai.gd` | IA: tiro, passaggi, portatore, difesa, appoggi, portiere |
| `src/sim/match.js` | `match.gd` (`SimMatch`) | `Match`: calci, pallone, ripartenze, regole, comandi del giocatore (`user*`) |
| `src/sim.js` | — | in GDScript si usa direttamente `match.gd` |
| — | `stili.gd` (solo Godot) | stili di gioco (attacco/difesa): parametri, nomi, stile delle squadre della CPU |
| — | `testa.gd`, `raccatta.gd`, `riprese.gd` (solo Godot) | colpo di testa controllato; raccattapalle; riprese senza teletrasporto (opzione `riprese`) |

Uso dal gioco: `var m := SimMatch.new({"seed": 7, "halfLen": 150.0, "human": [true, false], "teams": [a, b]})`,
poi `m.step(dt)` a ogni fotogramma, `m.events` da leggere e svuotare, i comandi `m.userPath(...)`, `m.userKick(...)`, ….
Le squadre sono dizionari come in JS (`{"name", "formation", "players": [...]}`, vedi `tests/harness.gd` → `mkTeam`).
A fine partita chiamare **`m.dispose()`** (vedi "Differenze").

## Differenze dal JS (tutte senza effetto sul risultato)

- **Mixin → ereditarietà.** In JS `Match` riceve i metodi di `duel.js`, `motion.js`, `ai.js`; qui è una catena
  `base.gd → duel.gd → motion.gd → ai.gd → match.gd`. I metodi che un file "basso" chiama ma che stanno più in alto
  (`kick`, `setRestart`, `followPath`, `endDuel`, …) hanno in `base.gd` un segnaposto che `match.gd` ridefinisce.
  Gli script si richiamano con `preload` relativi: funzionano anche senza la cache delle `class_name` (`godot -s`).
- **Funzioni matematiche.** `sin`, `cos`, `atan2` di Godot usano la libreria C del sistema e differiscono da V8 di
  1 ulp in parte dei casi (misurato su 2000 valori: sin 61, cos 81, atan2 381); su iPhone la libreria è un'altra
  ancora. Bastava per far divergere lo stato dal JS già dopo 2-9 s di partita (prima differenza ai passi 128-510),
  anche se eventi e punteggio delle 7 partite di prova restavano uguali. `fmath.gd` porta fdlibm (le stesse di V8):
  con quelle lo stato è identico bit per bit, e uguale su Windows, Mac e iPhone. Costo: ~2 µs a chiamata contro
  0,08 µs (incluso nella misura di velocità qui sotto). Le costanti di fdlibm sono scritte come parole esadecimali:
  Godot legge alcuni decimali lunghi con 1 ulp di errore (10 costanti su 41).
- **`Math.hypot`** di V8 non è `sqrt(a²+b²)`: `core.gd` → `hyp`/`hyp3` ne rifà l'algoritmo (normalizza per il
  massimo, somma di Kahan). Mai usare `Vector2` nel motore: è a 32 bit.
- **`Array.sort` del JS è stabile, `sort_custom` di Godot no:** dove l'ordine dei pari conta si usa `stableSort`.
- **`x || d`, `Math.sign(-0)`, `Math.round`**: aiuti `orf`, `sign_`, `round_` in `core.gd` con la stessa semantica.
- **Chiusure:** le lambda di GDScript copiano le variabili locali; dove il JS le modificava da una chiusura
  (`passOptions` → `consider`) c'è un metodo che ritorna il valore nuovo (`_consider`).
- **`pass`** è una parola riservata: la variabile si chiama `pass_`. Il cartellino "nessuno" è `""` (in JS `null`).
- **`lookFor`** (aspetto del giocatore, solo grafica) consuma un numero casuale come in JS e ritorna `null`.
- **Riferimenti circolari:** i giocatori si puntano tra loro (`supC`, `beatBy`) e il conteggio dei riferimenti di
  Godot non li libera da solo: **`m.dispose()`** a fine partita, altrimenti ~20 oggetti restano in memoria a partita.
- `match.gd` (1004 righe) e `ai.gd` (868) superano le 800 righe consigliate: seguono uno a uno `match.js` e `ai.js`
  (righe JS più dense), per ritrovare subito il punto corrispondente; non vanno spezzati finché il JS resta così.

## Test

```
godot --headless --path godot -s res://tests/run_tests.gd              # tutti (~2,5 min)
godot --headless --path godot -s res://tests/run_tests.gd -- duel      # solo file o test col nome che contiene "duel"
```

Esce con codice 0 se passano tutti, 1 se uno fallisce. Ogni `tests/test_*.gd` estende `test_base.gd` e ha metodi
`test_*() -> bool` (Arrange/Act/Assert come in `test/unit`); `harness.gd` = `test/lib/harness.mjs` + `scene.mjs`.
Attenzione: con `-s`, un errore di script blocca Godot senza uscire; in automatico usare un `timeout`.

| File | Porting di | Test |
|---|---|---|
| `test_equivalence.gd` | — | numeri casuali, `hypot`, `sin`/`cos`/`atan2` contro V8; 7 partite intere bit per bit |
| `test_defense.gd` | `defense-help`, `defense-runs`, `defense-shape` | linee corte, contrasto magnetico, intercetto, raggio difensivo, pressing, rientro |
| `test_attack.gd` | `attack-spacing`, `sprint` | smarcamento, profondità sul fuorigioco, scatto ed energia |
| `test_duel.gd` | `duel`, `dribble-beat` | duello, dribbling, difensore saltato, colpi di testa e `tes`, stanchezza, area di tiro |
| `test_dribbling.gd` | `dribble-book`, `no-double-touch` | dribbling prenotato (parte vicino, tempo massimo, annullato col duello, lato), niente doppio tocco sui calci da fermo |
| `test_sprint.gd` | `flee` (fuga e Scatto) | fuga con l'avversario alla pari o dietro "per linee", duello solo davanti, chiusure (tempo, alla pari, passaggio), Scatto dritto senza contrasti, squadra 1 |
| `test_rules.gd` | `out-of-play`, `advantage`, `wall`, `path`, `preview`, `sanity`, `air` | portiere e respinte, spazzata, contrasti, vantaggio, barriera, strada disegnata, anteprima, fuorigioco, partita senza NaN |

Non portati: i test della grafica e del menu (`busto`, `camfit`, `camuser`, `eyes`, `gambe`, `hair`, `head`, `looks`,
`moves`, `tricks`, `menu-routine`, `ui-style`, `assets`, `legacy-save`, `squad`, `split-three`, `stadium-robust`,
`tutorial`); quelli che usano `career.js` o `tutorial.js` (`difficulty`, la parte di `duel` con `genPlayer`, le due
prove della lezione "Dribbling" in `dribble-beat`); quelli segnati `todo` in `out-of-play`; `balance`; il conteggio dei
colpi di testa su 6 partite in `air`; `golden` (lo coprono le tracce, che sono più severe); in `duel` il controllo dei
campi di `m.duel` (qui è una classe); in `sprint` la scelta del clip d'animazione (`sprintMix`, grafica).

### Equivalenza col JS

`node test/export-trace.mjs` scrive in `tests/fixtures/` i riferimenti presi dal motore JS:
`rng.json` (500 numeri per 7 semi), `math.json` (2000 valori di sin, cos, atan2, hypot), `sprint.json` (17 scene di
fuga e tasto Scatto, che le partite col bot non usano mai: avversario dietro, alla pari, davanti per linee, squadra 1;
apertura di fuga o duello, esito del tocco e impronta dello stato per 2,4 s), `dribble.json` (12 scene del tasto
Dribbling prenotato: esito del tocco, eventi col lato, impronta per 2,4 s), `restart.json` (10 calci da fermo battuti
corti, col battitore che insegue il pallone o a campo pieno: impronta per 7,5 s), `trace_0..6.json`
(7 partite: un'impronta dello stato a ogni passo, gli eventi col passo, lo stato in chiaro ogni 120 passi,
punteggio e statistiche). **Va rilanciato a ogni modifica del motore JS**, e il porting va aggiornato finché
`test_equivalence.gd` torna verde: se un'impronta differisce, il test dice da quale passo e di quanto.

Risultato attuale: 3500 numeri casuali, 2000 `hypot`/`sin`/`cos`/`atan2` identici; 7 partite (5 come il golden JS
più 2 da 2×150 s, 78 482 passi in tutto) identiche al JS a ogni passo, con stessi eventi, punteggio e statistiche.

### Velocità

`godot --headless --path godot -s res://tests/bench.gd` (PC Windows di sviluppo, Godot 4.7.2):

| | passi al secondo | per passo |
|---|---|---|
| Node (V8 con JIT) | ~29 000 (a caldo) | 0,034 ms |
| GDScript | ~1 800 | 0,56 ms (mediana 0,43, 99% 1,5, massimo 3,1) |

GDScript è circa 16 volte più lento di V8, ma un passo per fotogramma costa ~3% dei 16,7 ms a 60 fps sul PC.
GDScript non ha JIT né sul PC né sull'iPhone, quindi conta solo la CPU: su un iPhone recente si stima da 1 a 2 volte
il tempo del PC, cioè ~0,5-1 ms a passo e punte di 3-6 ms nei passi più pesanti (dentro i 16,7 ms, ma da tenere d'occhio). Da misurare sul telefono; se servisse,
i punti da alleggerire sono le chiamate a `sin`/`cos`/`atan2` fdlibm, `segInfo` (allocazioni) e `passOptions`.
