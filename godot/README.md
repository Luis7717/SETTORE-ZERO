# Tiro a Giro 3D — versione Godot (in costruzione)

App vera del gioco fatta con **Godot 4.7.2-stable** (GDScript). Si costruisce a fasi; la versione web
(`src/`, `www/`, `App/`) resta intatta e continua a funzionare finché questa non la supera.

**Fase 1 (fondamenta)**: progetto, build IPA su GitHub Actions e una scena di prova da guardare: campo con le stesse
misure del gioco, stadio semplice, 22 giocatori in 4-4-2 che corrono avanti e indietro, pallone che passa tra i
giocatori di casa, telecamera verticale come nel web, contatore FPS e memoria, tocchi col dito.
Il motore (`src/sim/*`) è portato in GDScript in `sim/` (identico bit per bit al JS, vedi `sim/README.md`).

**Fase 2 (partita giocabile)**: due lavori in parallelo. Il **gioco** (questo: ciclo, gesti a un dito, rallenty,
HUD, suoni, squadre di prova, scena `scenes/partita.tscn`, ora scena principale) e la **vista** (giocatori,
animazioni, telecamere: `scenes/vista_partita.tscn`, altro lavoro). Finché la vista vera non c'è, il gioco usa una
vista finta (cilindri colorati). Dettagli sotto, in "Partita (fase 2)".

## Aprire il progetto

1. Scarica Godot 4.7.2-stable (https://godotengine.org/download/archive/4.7.2-stable/), versione normale (non .NET).
2. Apri Godot → *Importa* → scegli `godot/project.godot`. La prima volta importa modelli e suoni (cartella
   `godot/.godot/`, fuori dal repo).
3. F5 fa partire la partita (`scenes/partita.tscn`). Col mouse si gioca come col dito. La scena di prova della fase 1
   (`scenes/prova_campo.tscn`) resta: si apre dall'editor o con `$G --path godot res://scenes/prova_campo.tscn`.

## Struttura

| Cartella / file | Cosa c'è |
|---|---|
| `project.godot` | impostazioni: renderer Mobile, schermo verticale 390×844, compressione ETC2/ASTC (serve a iOS) |
| `export_presets.cfg` | preset **iOS** (usato dalla build su GitHub) e **Windows Desktop** (solo per provare l'export sul PC) |
| `scenes/prova_campo.tscn` | scena di prova: cielo e luce, telecamera, campo, stadio, squadre, contatore |
| `scripts/coord.gd` | misure del campo e passaggio coordinate gioco ↔ Godot |
| `scripts/campo.gd` | erba, porte con rete, bandierine |
| `scripts/stadio.gd` | cartelloni, tribune col pubblico dipinto, tetti, torri faro |
| `scripts/giocatore.gd` | un giocatore: modello, divisa, animazioni fermo/corsa/scatto |
| `scripts/telecamera.gd` | telecamera verticale come `src/render.js` |
| `scripts/hud.gd` | contatore FPS / memoria / disegni / risoluzione 3D, dentro l'area sicura |
| `scripts/prova_campo.gd` | movimenti finti, pallone, tocchi, opzioni per le prove da riga di comando |
| `shaders/erba.gdshader` | strisce e righe calcolate per pixel (nitide a ogni distanza, niente texture grande) |
| `shaders/divisa.gdshader` | colori della divisa per zone del corpo, come `src/athlete3d.js` |
| `assets/` | modelli, suoni, icona (licenze in `CREDITI.md`) |
| `tools/` | strumenti di sviluppo (icona, ispezione dei modelli): non finiscono nell'app |
| `scenes/partita.tscn` | **partita** (scena principale): `scripts/partita/gioco.gd` |
| `scenes/hud_partita.tscn` | interfaccia della partita: `scripts/partita/hud_partita.gd` |
| `scripts/partita/gioco.gd` | ciclo della partita (`frame()` di `src/main.js`): gesti → motore col tempo scalato → eventi → vista; pausa, intervallo, fine |
| `scripts/partita/gesti.gd` | comandi a un dito, porting di `src/input.js` (logica pura, provata senza schermo) |
| `scripts/partita/visuale_dito.gd` | visuale girata col dito: la parte "gesto" di `src/camuser.js` |
| `scripts/partita/hud_partita.gd` | punteggio, tempo, minimappa, suggerimenti, Dribbling, pausa, scritte, frecce, menu, FPS |
| `scripts/partita/minimappa.gd`, `anteprima.gd` | minimappa; anteprima del calcio disegnato (volo, fuorigioco, chi riceve) |
| `scripts/partita/audio_partita.gd` | suoni agganciati agli eventi del motore, pubblico che cresce vicino alla porta |
| `scripts/partita/squadre_prova.gd` | due squadre inventate (Virtus Borgoalto, Aurora Portosole) finché non c'è la carriera |
| `scripts/partita/vista_finta.gd` | vista finta con le firme della vista vera, solo per provare (non va nella scena finale) |
| `scripts/partita/bot_dito.gd` | "dito finto" per le prove: gioca coi gesti veri |
| `shaders/rallenty.gdshader` | bordo scuro del rallenty |
| `sim/`, `tests/` | motore di gioco in GDScript e i suoi test (`tests/test_gesti.gd` = gesti) |

## Coordinate

Gioco (come `src/sim/core.js`): x = larghezza (−32..32), y = lunghezza (−50..50), h = altezza; la squadra 0 attacca
verso +y. **Godot: X = x, Y = h, Z = −y** — la stessa convenzione di three.js nel web (`src/render.js`), così i numeri
di telecamera e luci si copiano senza cambiare segni. La porta verso cui attacca la squadra 0 è a Z = −50, cioè
davanti a una telecamera che guarda verso −Z. Funzioni: `Coord.a_godot(x, y, h)`, `Coord.da_godot(p)`,
`Coord.yaw_verso(dx, dy)` in `scripts/coord.gd`. Giocatori e pallone sono ingranditi di 1,25 come nel web.

## Provare dal PC (riga di comando)

Godot va lanciato con la versione *console* (stampa nel terminale). `G` = percorso di `Godot_v4.7.2-stable_win64_console.exe`.

```sh
$G --headless --path godot --import                       # importa (prima volta o dopo nuovi file)
$G --headless --path godot -- --esci-dopo=4                # scena senza schermo per 4 s: non deve stampare errori
$G --path godot -- --schermata=C:/percorso/campo.png --dopo=3          # schermata 390×844 ed esce
$G --path godot -- --vista=vicina --scegli=9 --schermata=C:/percorso/vicino.png --dopo=2   # giocatore da vicino
$G --path godot -- --vista=porta --schermata=...   /   --vista=alta --schermata=...      # porta e rete / campo intero
$G --path godot -- --senza-vsync --esci-dopo=10            # FPS massimi del PC (stampa FPS medi e memoria)
$G --path godot -- --prova-tocchi --esci-dopo=6            # tocco simulato su un giocatore e sul campo (serve la finestra)
```

Queste opzioni sono della scena di prova della fase 1: con la partita come scena principale si aggiunge
`res://scenes/prova_campo.tscn` dopo `--path godot`. Le schermate di prova vanno in `shots/` (ignorata da git).

## Partita (fase 2)

Ciclo come `src/main.js`: a ogni fotogramma **gesti** (`gesti.update`) → **motore** a passi di al massimo 1/60 s
col tempo scalato → **eventi** (suoni, scritte) → **vista** (`update_view(dt_game, dt_real)`, con
`dt_game = dt · max(velocità del tempo, 0,25)` e `dt_real = dt`, come `view.update` e `view.rdt` del web).
Rallenty con le costanti di `src/main.js`: duello 0,08, area di tiro 0,1, disegno di passaggio o tiro 0,04, di strada
0,25, di linea di difesa 0,13, parata 0,1; il tempo passa dolcemente da una velocità all'altra (14/s).
Tempo di un tempo: 150 s (come il web). Squadra della persona: la 0 (Virtus Borgoalto), contro Aurora Portosole (IA).

**Contratto della vista** (la vista vera è `class_name PartitaVista`, scena `scenes/vista_partita.tscn`; se manca si
usa `scripts/partita/vista_finta.gd`, che ha le stesse firme):

| Chi | Cosa | Quando |
|---|---|---|
| `gioco.gd` | `setup(m, 0)` | una volta, dopo aver creato la partita |
| `gioco.gd` | `drawing = gesti.drawing`, poi `update_view(dt_game, dt_real)` | a ogni fotogramma, dopo motore ed eventi (in pausa: 0, 0) |
| `gioco.gd` | `trick(p)` → `{name, ...}` (o una stringa) | evento `dribble`: nome del giochetto nella scritta grande |
| `gioco.gd` | `dispose()` | uscendo dalla scena (anche "Nuova partita") |
| `gesti.gd` | `world_to_screen(x, y, h)` → `Vector3(x_px, y_px, visibile)` | presa di pallone, portatore, giocatori; omografia della porta |
| `gesti.gd` | `screen_to_field(p)` → `Vector2` (non finito = cielo) | punti di strade, linee di difesa, "tieni premuto" |
| `gesti.gd` | `show_path(punti, kind)` / `clear_path()` | mentre si disegna: `run`, `pass`, `shot` (anche il tuffo), `def` (già tagliata a 14 m) |
| `gesti.gd` | `user_yaw`, `cam_drag` | visuale girata col dito (la vista la usa e la riporta a 0 fuori dal rallenty) |
| `anteprima.gd` | `world_to_screen` | puntini del volo, linea del fuorigioco, cerchio su chi riceve (2D sopra la vista) |
| facoltativi | `screen_to_goal(p, gy)` → `Vector3(x, h, 1/0)`, `set_zoom(z)` | se ci sono si usano; senza, la porta si trova con un'omografia da 4 punti di `world_to_screen` (pali e traversa) e lo zoom non si cambia |

`visibile` = il punto è **davanti** alla telecamera (non "dentro lo schermo"): serve all'omografia.

Gesti (porting di `src/input.js`, costanti con nome in cima a `gesti.gd`): strada dal portatore (con tanta strada
scatta), linea in porta = tiro, linea fino a un compagno = passaggio (**il tocco su un compagno col pallone non passa
mai**), duello col tasto Dribbling, area di tiro (linea al compagno entro 5 m = passaggio, altrove = corsa), linee di
difesa da ogni proprio giocatore tranne il portiere (si vedono già tagliate a 14 m), tieni premuto = muovi il
controllato (lontano = scatto), tocco su un proprio giocatore in difesa = comandarlo, portiere (linea dal portiere al
punto della porta, tuffo al rilascio), rimesse (si disegna da ovunque, tranne nel calcio d'angolo: solo vicino al
battitore), visuale girata col dito nel rallenty e nel calcio d'angolo (dito lontano dal portatore, soglia 12 px,
150° per schermo, ±100°, "si afferra il campo"). Un dito solo; i tocchi annullati dal sistema non danno ordini;
l'app che va in sottofondo mette in pausa.

```sh
$G --headless --path godot -s res://tests/run_tests.gd -- gesti          # test dei gesti (20, meno di 1 s)
$G --headless --path godot -- --bot --veloce=8 --esci-a-fine --seme=5    # partita intera col dito finto (~30 s)
$G --path godot -- --seme=3 --schermata=shots/hud.png --dopo=4           # schermata della partita
$G --path godot -- --seme=3 --scena=area --schermata=shots/area.png --dopo=2.5    # rallenty con frecce
$G --path godot -- --seme=3 --scena=disegno --schermata=...   /   --scena=pausa   /   --scena=angolo
$G --path godot -- --seme=4 --bot --veloce=12 --tempo=40 --esci-a-fine --alla-fine --schermata=shots/fine.png
```

Opzioni di `gioco.gd`: `--seme=N`, `--tempo=SEC` (un tempo), `--vista-finta`, `--veloce=K` (tempo fisso K/60 s a
fotogramma), `--bot`, `--esci-a-fine`, `--scena=area|duello|disegno|angolo|pausa`, `--schermata=… [--dopo=SEC |
--alla-fine]`, `--esci-dopo=SEC` (stampa "FPS medi", come vuole la build su GitHub). Senza schermo i suoni sono
spenti (non si sentono e col driver audio finto resterebbero in memoria all'uscita).

Non ancora fatti (fasi dopo): menu e carriera (la partita parte subito con le squadre di prova), cambi in pausa,
allenamento guidato, salvataggio della scritta "Trascina il campo" (si ricorda solo finché l'app è aperta), musica.

## Build per iPhone (GitHub Actions)

Workflow `.github/workflows/tiro-a-giro-godot-ipa.yml`: parte a ogni push sul ramo `tiro-a-giro` **solo se cambia
`godot/**` o il workflow stesso**, oppure a mano (*Run workflow*). Su un Mac di GitHub:

1. scarica Godot 4.7.2 per macOS e i template di export (controllo SHA-512); tiene in cache solo l'editor e
   `ios.zip` (~400 MB invece di 1,4 GB), così dalla seconda volta non riscarica nulla;
2. importa il progetto e fa girare la scena 3 s senza schermo: se stampa errori di script la build si ferma;
3. esporta il preset **iOS** come progetto Xcode (`export_project_only=true`: Godot non firma e non compila);
4. compila con `xcodebuild` **senza firma** (`CODE_SIGNING_ALLOWED=NO`), poi firma **ad-hoc** (`codesign --sign -`)
   come l'app web, e crea `TiroAGiroGodot.ipa`;
5. pubblica la release **`tiro-a-giro-godot-ipa`** (si installa a mano come l'altra: TrollStore, Sideloadly, AltStore).

Gira su due Mac (`macos-15` e `macos-26`, Xcode diversi); poi un job `pubblica` mette nella release l'IPA di `macos-26`, o quella di `macos-15` se l'altra non c'è.

Scelte del preset iOS (spiegate):
- **Bundle id `it.tiroagiro.godot`**, nome "Tiro a Giro 3D": diverso dall'app web (`it.tiroagiro.game`), le due app
  convivono sul telefono.
- **Team ID `AAAAAAAAAA` finto**: Godot si rifiuta di esportare per iOS senza un Team ID (anche solo il progetto),
  ma la firma la togliamo noi in `xcodebuild` (`DEVELOPMENT_TEAM=""`), quindi il valore non viene mai usato.
- **iOS minimo 15.0**: è il minimo di Godot 4.7 (valore predefinito del preset; il renderer Metal vuole almeno 14).
  Godot aggiunge da solo il requisito **chip A12** (iPhone XS / XR o più nuovi) quando si usa il renderer Mobile.
- Solo iPhone (`targeted_device_family=0`), solo verticale (da `project.godot`), icona da `assets/icons/icon_1024.png`
  (Godot ne ricava tutte le misure).

Il preset si può provare anche da Windows: con i template installati
(`%APPDATA%\Godot\export_templates\4.7.2.stable\ios.zip`) il comando
`$G --headless --path godot --export-release "iOS" ../build/ios/TiroAGiroGodot.ipa` scrive il progetto Xcode in
`build/ios/` (solo la compilazione richiede un Mac).

## Prestazioni sul telefono

- Renderer **Mobile** (Metal su iPhone), MSAA 4×, ombre del sole a 2 fasce fino a 70 m, solo i giocatori e le porte
  fanno ombra, nebbia leggera; 60 fps come obiettivo (`allow_high_refresh_rate=false`: niente 120 Hz, meno calore).
- L'interfaccia segue i **punti** dell'iPhone (390×844 logici, stretch `canvas_items` + `expand`): su schermi più
  alti si vede più campo, non si deforma nulla. Contatore e aiuto stanno dentro l'**area sicura** (tacca, barra home).
- Il 3D si disegna largo al massimo **780 px** (2× la larghezza logica) e si ingrandisce con FSR: su un iPhone a 3×
  (1170 px) vuol dire scala 0,67, cioè metà dei pixel da disegnare. Il contatore mostra la risoluzione usata.
- Memoria: nell'app Godot non conta la propria memoria (vale solo nelle build di debug); il contatore mostra la memoria
  video e la RAM libera del telefono secondo iOS.
