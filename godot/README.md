# Tiro a Giro 3D — versione Godot (in costruzione)

App vera del gioco fatta con **Godot 4.7.2-stable** (GDScript). Si costruisce a fasi; la versione web
(`src/`, `www/`, `App/`) resta intatta e continua a funzionare finché questa non la supera.

**Fase 1 (fondamenta)**: progetto, build IPA su GitHub Actions e una scena di prova da guardare: campo con le stesse
misure del gioco, stadio semplice, 22 giocatori in 4-4-2 che corrono avanti e indietro, pallone che passa tra i
giocatori di casa, telecamera verticale come nel web, contatore FPS e memoria, tocchi col dito.
Non c'è ancora il gioco: il motore (`src/sim/*`) lo sta portando in GDScript un altro lavoro, in `sim/` e `tests/`.

**Fase 2, vista della partita** (`scripts/partita/`, `scenes/vista_partita.tscn`): tutto quello che si vede in partita,
porting di `src/render.js`, `camfit.js`, `camuser.js`, `players3d.js`, `athlete3d.js`, `props.js`, `ik.js`,
`move-pose.js`, `tricks.js` e `src/moves/*`. Legge lo stato del motore (`SimMatch`) e non lo cambia mai; il ciclo di
gioco, i gesti e l'interfaccia sono un altro lavoro (`partita.tscn`). Contratto qui sotto.

## Aprire il progetto

1. Scarica Godot 4.7.2-stable (https://godotengine.org/download/archive/4.7.2-stable/), versione normale (non .NET).
2. Apri Godot → *Importa* → scegli `godot/project.godot`. La prima volta importa modelli e suoni (cartella
   `godot/.godot/`, fuori dal repo).
3. F5 fa partire la scena di prova (`scenes/prova_campo.tscn`). Col mouse si prova come col dito.

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
| `sim/`, `tests/` | motore di gioco in GDScript e i suoi test (altro lavoro in parallelo) |
| `scenes/vista_partita.tscn` | vista della partita: cielo, sole, telecamera, campo, stadio, giocatori, linee (`PartitaVista`) |
| `scripts/partita/vista.gd` | `PartitaVista`: giocatori, pallone, anello, reti, giochetti, conversioni schermo ↔ campo |
| `scripts/partita/telecamera_partita.gd` | telecamera come `View.update` del web: normale, vicino alla porta, difesa, duello, rallenty largo, angolo, parata, girata |
| `scripts/partita/camfit.gd`, `camuser.gd` | inquadrature calcolate e visuale girata col dito (conti puri, provati senza schermo) |
| `scripts/partita/figura.gd` | un giocatore in partita: clip fermo/corsa/scatto/salto, pose (calcio, testa, tuffo, scivolata, esultanza), giochetti con la IK |
| `scripts/partita/mosse/` | movimenti calcolati dei giochetti (`mossa.gd`, `corpo.gd`, `giochetti.gd`) e IK a due ossa (`ik.gd`) |
| `scripts/partita/nastri.gd`, `texture_vista.gd` | linee disegnate a nastro, linee di difesa, anteprima, fuorigioco; texture fatte a codice |
| `shaders/rete.gdshader`, `bandierina.gdshader` | rete che si gonfia sul gol, bandierine che sventolano |
| `scenes/prova_vista.tscn` | prova: computer contro computer disegnato dalla vista, scene per le schermate e misure |

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

Le schermate di prova vanno in `shots/` (ignorata da git).

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

### Vista della partita (fase 2)

```sh
$G --path godot res://scenes/prova_vista.tscn -- --schermata=shots/vista/partita.png --dopo=6
#   --scena=rallenty | girata | parata | angolo | giochetto | linea | gol    (più --sequenza=N --ogni=SEC)
#   --me=1 (campo capovolto) · --vicino=N (telecamera vicina a m.players[N]) · --senza-vsync --esci-dopo=15
$G --headless --path godot res://scenes/prova_vista.tscn -- --controlla --me=1   # conversioni schermo/campo/porta
$G --headless --path godot -s res://tests/run_tests.gd -- test_camfit    # anche test_camuser, test_mosse, test_figura
node test/export-vista.mjs     # rigenera tests/fixtures/vista.json dal JS (camfit, camuser, giochetti, IK)
```

Contratto di `PartitaVista` (`scripts/partita/vista.gd`, radice di `scenes/vista_partita.tscn`):

| Chiamata | Cosa fa |
|---|---|
| `setup(m: SimMatch, me: int)` | 22 giocatori con le divise (`team.kit` {shirt, shorts, socks, gk} se c'è, sennò rosso/blu e portieri arancio/verde), telecamera sul pallone |
| `update_view(dt_game, dt_real)` | dopo il passo del motore: animazioni col tempo di gioco, telecamera col tempo vero; riporta piano `user_yaw` a 0 (relaxYaw) |
| `world_to_screen(x, y, h) -> Vector3` | (x_px, y_px, 1 davanti alla telecamera / 0 dietro) — il terzo valore non dice "dentro lo schermo" |
| `screen_to_field(p) -> Vector2` | punto del campo sotto il dito, con la telecamera vera anche girata; `Vector2(INF, INF)` sul cielo |
| `screen_to_goal(p, gy) -> Vector3` | (x, h, 1 valido / 0 no) sul piano della porta a y = gy, per tiro e tuffo |
| `set_zoom(z)` | zoom come `setZoom` del web (senza chiamarla lo calcola la vista con le stesse regole) |
| `show_path(points, kind, end_h := 0.0, recv := null)` / `clear_path()` | linea a nastro: "run", "pass" (anello verde sul compagno entro 5 m), "shot" (gialla col mirino), "def" |
| `show_preview(points, offside_y := NAN)` | puntini del volo e linea del fuorigioco (facoltativo: nel gioco li fa l'interfaccia) |
| `trick(p, r := -1.0) -> Dictionary` | giochetto del dribbling per p (solo grafica): {id, name, dur} |
| `dispose()` | via figure e riferimenti; va bene anche da `_exit_tree` del padre |
| `user_yaw`, `cam_drag`, `drawing` | scritti da chi gestisce il dito |

Le linee di difesa assegnate (`m.runs[me]`) si disegnano da sole a ogni `update_view`.

## Prestazioni sul telefono

- Renderer **Mobile** (Metal su iPhone), MSAA 4×, ombre del sole a 2 fasce fino a 70 m, solo i giocatori e le porte
  fanno ombra, nebbia leggera; 60 fps come obiettivo (`allow_high_refresh_rate=false`: niente 120 Hz, meno calore).
- L'interfaccia segue i **punti** dell'iPhone (390×844 logici, stretch `canvas_items` + `expand`): su schermi più
  alti si vede più campo, non si deforma nulla. Contatore e aiuto stanno dentro l'**area sicura** (tacca, barra home).
- Il 3D si disegna largo al massimo **780 px** (2× la larghezza logica) e si ingrandisce con FSR: su un iPhone a 3×
  (1170 px) vuol dire scala 0,67, cioè metà dei pixel da disegnare. Il contatore mostra la risoluzione usata.
- Memoria: nell'app Godot non conta la propria memoria (vale solo nelle build di debug); il contatore mostra la memoria
  video e la RAM libera del telefono secondo iOS.
