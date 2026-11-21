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

**Fase 2, vista della partita** (`scripts/partita/`, `scenes/vista_partita.tscn`): tutto quello che si vede in partita,
porting di `src/render.js`, `camfit.js`, `camuser.js`, `players3d.js`, `athlete3d.js`, `props.js`, `ik.js`,
`move-pose.js`, `tricks.js` e `src/moves/*`. Legge lo stato del motore (`SimMatch`) e non lo cambia mai; il ciclo di
gioco, i gesti e l'interfaccia sono un altro lavoro (`partita.tscn`). Contratto qui sotto.

**Fase 3, carriera, salvataggio e flusso dell'app** (`scripts/carriera/`, `scripts/app.gd`, `scenes/app.tscn`):
porting di `src/career.js` (identico al JS a parità di seme), salvataggio su file, scena principale che passa da
menu a partita a fine partita e ritorno. Dettagli sotto, in "Carriera e flusso dell'app (fase 3)". In parallelo:
interfaccia dei menu, sfondo del menu e allenamento guidato, grafica.

## Aprire il progetto

1. Scarica Godot 4.7.2-stable (https://godotengine.org/download/archive/4.7.2-stable/), versione normale (non .NET).
2. Apri Godot → *Importa* → scegli `godot/project.godot`. La prima volta importa modelli e suoni (cartella
   `godot/.godot/`, fuori dal repo).
3. F5 fa partire l'app (`scenes/app.tscn`: menu, poi partita); la sola partita di prova con `scenes/partita.tscn`
   (F6 sulla scena aperta). Col mouse si gioca come col dito. La scena di prova della fase 1
   (`scenes/prova_campo.tscn`) resta: si apre dall'editor o con `$G --path godot res://scenes/prova_campo.tscn`.

## Struttura

| Cartella / file | Cosa c'è |
|---|---|
| `project.godot` | impostazioni: renderer Mobile, schermo verticale 390×844, compressione ETC2/ASTC (serve a iOS) |
| `export_presets.cfg` | preset **iOS** (usato dalla build su GitHub) e **Windows Desktop** (solo per provare l'export sul PC) |
| `scenes/prova_campo.tscn` | scena di prova: cielo e luce, telecamera, campo, stadio, squadre, contatore |
| `scripts/coord.gd` | misure del campo e passaggio coordinate gioco ↔ Godot |
| `scripts/campo.gd` | erba (col taglio dello stadio, `set_taglio`), righe, porte con rete, bandierine |
| `scripts/righe_campo.gd` | righe bianche del campo come mesh (misure di `sim/core.gd`), `tests/test_campo.gd` |
| `scripts/tagli_campo.gd` | tagli dell'erba (nomi, taglio fisso per seme, `--campo=<nome>`) |
| `scripts/stadio.gd` | cartelloni, tribune col pubblico dipinto, tetti, torri faro |
| `scripts/giocatore.gd` | un giocatore: modello, divisa, animazioni fermo/corsa/scatto |
| `scripts/telecamera.gd` | telecamera verticale come `src/render.js` |
| `scripts/hud.gd` | contatore FPS / memoria / disegni / risoluzione 3D, dentro l'area sicura |
| `scripts/prova_campo.gd` | movimenti finti, pallone, tocchi, opzioni per le prove da riga di comando |
| `shaders/erba.gdshader` | disegno del taglio dell'erba calcolato per pixel (8 tagli, bordi ammorbiditi), grana, fili d'erba |
| `shaders/righe.gdshader` | righe: si allargano da lontano per restare larghe almeno 1,5 pixel |
| `shaders/divisa.gdshader` | colori della divisa per zone del corpo, come `src/athlete3d.js` |
| `scripts/partita/capelli.gd`, `barbe.gd`, `shaders/capelli.gdshader` | capelli e barbe come mesh a parte sull'osso della testa (vedi "Capelli e barbe") |
| `assets/` | modelli, suoni, icona (licenze in `CREDITI.md`) |
| `tools/` | strumenti di sviluppo (icona, ispezione dei modelli): non finiscono nell'app |
| `scenes/app.tscn`, `scripts/app_avvio.gd` | **scena principale**: al primo fotogramma passa la mano all'autoload `App` |
| `scripts/app.gd` | autoload **`App`**: carriera corrente, schermate del menu, partita, fine partita, salvataggio in sottofondo |
| `scripts/app_prove.gd` | prove automatiche del flusso: stagione intera col dito finto, giro di schermate |
| `scripts/carriera/carriera.gd` | **`Carriera`**: porting 1:1 di `src/career.js` (stessi nomi, stato in `c.s`) |
| `scripts/carriera/aspetto.gd`, `stemma_dati.gd` | `src/looks.js` (unico porting, usato da carriera, menu e vista; `parametri_figura` / `stile_figura` = parametri dello shader della figura; `tests/test_aspetto.gd` col JS via `node test/export-aspetto.mjs`) e la parte dati di `src/crest.js` (forme, motivi, simboli, colori) |
| `scripts/carriera/salvataggio.gd`, `js.gd` | file `user://salvataggio.json` (scrittura sicura, ripiego); aiuti per rifare il JS esatto (ordinamento di V8, toFixed, …) |
| `scenes/menu/<nome>.tscn` | **schermate dei menu** (`scripts/menu/<nome>.gd`, sotto "Menu (fase 3)"); `segnaposto.tscn` resta per un nome che non esiste |
| `scripts/menu/` | interfaccia dei menu: tema, stemmi e visi in SVG, carte della Rosa, editor con anteprima 3D |
| `assets/tema/tema.tres` | tema dei menu (generato da `tools/crea_tema.gd`) |
| `scenes/partita.tscn` | **partita**: `scripts/partita/gioco.gd` (dall'app con `avvia(opz)`, da sola con le squadre di prova) |
| `scenes/hud_partita.tscn` | interfaccia della partita: `scripts/partita/hud_partita.gd` |
| `scripts/partita/gioco.gd` | ciclo della partita (`frame()` di `src/main.js`): gesti → motore col tempo scalato → eventi → vista; pausa, intervallo, fine |
| `scripts/partita/gesti.gd` | comandi a un dito, porting di `src/input.js` (logica pura, provata senza schermo) |
| `scripts/partita/visuale_dito.gd` | visuale girata col dito: la parte "gesto" di `src/camuser.js` |
| `scripts/partita/hud_partita.gd` | punteggio, tempo, minimappa, suggerimenti, tasto Dribbling / Scatto, pausa, scritte, frecce, menu, FPS |
| `scripts/partita/minimappa.gd`, `anteprima.gd` | minimappa; anteprima del calcio disegnato (volo, fuorigioco, chi riceve) |
| `scripts/partita/audio_partita.gd` | suoni agganciati agli eventi del motore, pubblico che cresce vicino alla porta |
| `scripts/partita/squadre_prova.gd` | due squadre inventate (Virtus Borgoalto, Aurora Portosole) finché non c'è la carriera |
| `scripts/partita/vista_finta.gd` | vista finta con le firme della vista vera, solo per provare (non va nella scena finale) |
| `scripts/partita/bot_dito.gd` | "dito finto" per le prove: gioca coi gesti veri |
| `shaders/rallenty.gdshader` | bordo scuro del rallenty |
| `sim/`, `tests/` | motore di gioco in GDScript e i suoi test (`tests/test_gesti.gd` = gesti) |
| `scenes/vista_partita.tscn` | vista della partita: cielo, sole, telecamera, campo, stadio, giocatori, linee (`PartitaVista`) |
| `scripts/partita/vista.gd` | `PartitaVista`: giocatori, pallone, anello, reti, giochetti, conversioni schermo ↔ campo |
| `scripts/partita/telecamera_partita.gd` | telecamera come `View.update` del web: normale, vicino alla porta, difesa, duello, rallenty largo, angolo, parata, girata |
| `scripts/partita/camfit.gd`, `camuser.gd` | inquadrature calcolate e visuale girata col dito (conti puri, provati senza schermo) |
| `scripts/partita/figura.gd` | un giocatore in partita: clip fermo/corsa/scatto/salto, pose (calcio, testa, tuffo, scivolata, esultanza), giochetti con la IK |
| `scripts/partita/mosse/` | movimenti calcolati dei giochetti (`mossa.gd`, `corpo.gd`, `giochetti.gd`), palleggi e tiro del menu (`palleggi.gd`, `tiro.gd`) e IK a due ossa (`ik.gd`) |

| `scripts/partita/figura_mocap.gd` | animazioni mocap vere sopra la figura: esultanze, parate, piatto/collo/rigore, rimessa, difesa (vedi "Animazioni mocap") |
| `assets/mocap/mocap.res` | le clip mocap reindirizzate sul nostro scheletro (AnimationLibrary compressa, ~436 KB), fatte da `tools/converti_mocap.gd` |
| `scripts/partita/mosse/` | movimenti calcolati dei giochetti (`mossa.gd`, `corpo.gd`, `giochetti.gd`) e IK a due ossa (`ik.gd`) |
| `scripts/partita/nastri.gd`, `texture_vista.gd` | linee disegnate a nastro, linee di difesa, anteprima, fuorigioco; texture fatte a codice |
| `shaders/rete.gdshader`, `bandierina.gdshader` | rete a molle (legge `scripts/rete_molle.gd`), bandierine col vento a raffiche |
| `scripts/rete_molle.gd` | rete di una porta con una molla per nodo (logica pura, `tests/test_rete.gd`) |
| `scripts/stadio/pubblico.gd`, `shaders/pubblico.gdshader` | pubblico 3D: migliaia di tifosi in MultiMesh, colori delle squadre, animati nello shader |
| `scripts/stadio/cartelloni.gd`, `shaders/led.gdshader` | cartelloni a led con sponsor inventati che scorrono (`src/stadium-ads.js`) |
| `scripts/stadio/maxischermo.gd` | maxischermi col risultato e "GOOOL!" (`src/stadium-screen.js`) |
| `scripts/partita/effetti.gd` | scia del pallone, sbuffi d'erba, coriandoli |
| `scripts/partita/qualita.gd` | livelli grafici automatici (logica pura, `tests/test_qualita.gd`) |
| `scripts/partita/schiene.gd` | atlante di cognomi e numeri sulle schiene |
| `tools/genera_texture.gd` | genera `assets/textures/` (pallone HD e normal map, fili d'erba) |
| `scenes/prova_vista.tscn` | prova: computer contro computer disegnato dalla vista, scene per le schermate e misure |
| `scenes/menu/sfondo_menu.tscn` | sfondo 3D del menu: campione che palleggia, fa giochetti e tira (`scripts/menu/sfondo_menu.gd`, `routine_menu.gd`) |
| `scripts/partita/allenamento.gd` | allenamento guidato (logica pura); `allenamento_hud.gd` riquadro e schede; `bot_allenamento.gd` dito finto |

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

Queste opzioni sono della scena di prova della fase 1: si aggiunge `res://scenes/prova_campo.tscn` dopo `--path godot`.
`--campo=<nome>` (taglio dell'erba, vedi sotto) vale in ogni scena che ha il campo: partita, prova del campo, menu.
Le schermate di prova vanno in `shots/` (ignorata da git).

### Campo: righe e tagli dell'erba (2026-11-21)

- **Righe** = una mesh piatta 1,2 cm sopra l'erba (`righe_campo.gd`, ~1500 vertici, un materiale): linee laterali e di
  fondo, metà campo, cerchio e punto del centro, aree di rigore e di porta, dischetti, lunette, archi d'angolo, larghe
  12 cm, misure di `sim/core.gd`. Lo shader (`righe.gdshader`) sposta i vertici di lato e allarga la riga quando da
  lontano sarebbe più sottile di 1,5 pixel (anche di traverso): non sparisce e non sfarfalla. È illuminata come l'erba
  (le ombre dei giocatori ci passano sopra). Prima le righe erano calcolate per pixel nello shader dell'erba e
  sull'iPhone non si vedevano.
- **Tagli** (`tagli_campo.gd`, uniform `taglio` dello shader dell'erba): `strisce` (classico, 18 di traverso),
  `strette` (30), `verticali` (lungo il campo), `quadrotti`, `cerchi` (concentrici dal centro), `uniforme`, `rombi`
  (diagonali incrociate), `raggi` (strisce + cerchio di centrocampo a spicchi). Ogni squadra ha il suo stadio:
  in campionato il taglio viene dal seme della squadra di casa (`App._partita(..., stadio_seme)` →
  `avvia({stadio_seme})`), in amichevole e allenamento dal seme della partita (`gioco.gd taglio_campo`). Il menu usa
  il classico. Solo grafica: il motore non lo vede.

```sh
$G --path godot -- --seme=3 --campo=quadrotti --schermata=shots/campo_quadrotti.png --dopo=3
$G --path godot res://scenes/prova_campo.tscn -- --vista=alta --scala-3d=0.5 --campo=cerchi --schermata=...   # da lontano, 3D a metà
$G --path godot --rendering-driver vulkan --rendering-method mobile -- ...                                  # renderer Mobile come sul telefono
```

Scena principale = app (fase 3). Le opzioni della partita (`--bot`, `--scena`, `--schermata`, `--veloce`, `--seme`,
`--tempo`, `--vista-finta`, `--esci-a-fine`, `--partita`) senza `--app` fanno partire subito la partita di prova come
prima; con `--app` si passa dal menu:

```sh
$G --headless --path godot -- --esci-dopo=4                                  # menu senza schermo per 4 s: niente errori
$G --headless --path godot -- --app --stagione-bot --bot --veloce=8 --tempo=20 --salvataggio=user://prova.json
#   stagione intera col dito finto (~2 min): 18 partite vere, fine stagione, salva, ricarica e confronta
$G --path godot -- --app --app-schermate=shots/fase3 --bot --veloce=8 --tempo=15 --salvataggio=user://prova2.json
#   schermate: senza carriera, menu, partita, fine partita, dopo partita, menu
$G --headless --path godot -s res://tests/prova_partita.gd
#   partita vera senza schermo: pallone dopo il setup di ogni lezione dell'allenamento, tuffo col tocco vero
#   (InputEventScreenTouch/Drag) che arriva al motore, visuale della parata che resta, figura che si tuffa;
#   con la finestra e `-- --foto=CARTELLA` salva anche le schermate. Esce con 1 se un controllo fallisce
#   schermate: senza carriera, menu, partita, fine partita, dopo partita, menu, hub, classifica, rosa, fine stagione
```

## Partita (fase 2)

Ciclo come `src/main.js`: a ogni fotogramma **gesti** (`gesti.update`) → **motore** a passi di al massimo 1/60 s
col tempo scalato → **eventi** (suoni, scritte) → **vista** (`update_view(dt_game, dt_real)`, con
`dt_game = dt · max(velocità del tempo, 0,25)` e `dt_real = dt`, come `view.update` e `view.rdt` del web).
Rallenty con le costanti di `src/main.js`: duello 0,08, fuga 0,08, area di tiro 0,1, disegno di passaggio o tiro 0,04, di strada
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
mai**), duello (avversario davanti "per linee") col tasto Dribbling, fuga (avversario alla pari o dietro entro 4 m)
col tasto Scatto, e in ogni rallenty (duello, fuga, area di tiro) niente corsa disegnata: ogni linea è un passaggio
(al compagno o nello spazio) o un tiro se finisce in porta (Luis 2026-11-21), linee di
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
fotogramma), `--bot`, `--esci-a-fine`, `--scena=area|duello|fuga|disegno|angolo|pausa`, `--schermata=… [--dopo=SEC |
--alla-fine]`, `--allenamento [--lezione=N --prova=K --scheda]`, `--esci-dopo=SEC` (stampa "FPS medi", come vuole la build su GitHub). Senza schermo i suoni sono
spenti (non si sentono e col driver audio finto resterebbero in memoria all'uscita).

Non ancora fatti (fasi dopo): menu e carriera (la partita parte subito con le squadre di prova), cambi in pausa,
salvataggio della scritta "Trascina il campo" (si ricorda solo finché l'app è aperta). La musica c'è dal 2026-11-21:
solo nei menu (`App`, `assets/audio/music.mp3`), mai in partita, come il web.

## Sfondo del menu e allenamento guidato (fase 3)

**Sfondo 3D del menu** (`scenes/menu/sfondo_menu.tscn`, `scripts/menu/sfondo_menu.gd`): porting di `src/menu-bg.js` e
`src/menu-routine.js`. Un campione in divisa palleggia (suola, collo, coscia, testa), fa i giochetti a turno (finta,
doppio passo, elastico, veronica, sombrero, arcobaleno), corre e tira in porta, poi rientra un pallone nuovo; il ciclo
intero dura 114 s ed è identico al web (stessi movimenti calcolati: `mosse/palleggi.gd` = `src/moves/juggle.js`,
`mosse/tiro.gd` = `shot.js`, `mosse/giochetti.gd` ora fa sia la versione del menu sia quella della partita,
`scripts/menu/routine_menu.gd` = `menu-routine.js`). Dietro: campo e stadio della partita, luce calda del menu,
telecamera che gira piano attorno (fov 30, 7,2 m come il web). Un solo giocatore con la stessa `figura.gd` della
partita: leggero (sul PC ~1500 FPS senza vsync, una posa costa 0,06 ms).

Contratto per il menu (altro lavoro): istanziare `res://scenes/menu/sfondo_menu.tscn` dietro i tasti.

| Cosa | A cosa serve |
|---|---|
| `attivo = false` (o `visible = false`) | ferma tutto: niente `_process`, telecamera non corrente, cielo e sole staccati. Va messo quando parte la partita, sennò la scena resta a disegnare |
| `imposta_giocatore(kit, aspetto)` | divisa del campione (`kit` come nella carriera: `{shirt, shorts, socks}` in colori 0xRRGGBB) e aspetto (`skin`, `hair`...) |
| `hold`, `t` | tempo della routine (per le prove); `istanti_sequenza()` = istanti significativi |

Da solo (`$G --path godot res://scenes/menu/sfondo_menu.tscn`) si apre come scena e accetta `--schermata=… --dopo=SEC`,
`--tempo=SEC` (istante della routine), `--sequenza=cartella` (14 schermate: palleggi, giochetti, corsa, tiro),
`--vicino`, `--senza-vsync --esci-dopo=SEC` (stampa "FPS medi").

**Allenamento guidato** (`scripts/partita/allenamento.gd`, porting di `src/tutorial.js`): sette lezioni (Passaggio,
Tiro, Corsa e scatto, Recupera palla, Dribbling, Scatto, Portiere), per ognuna una scheda di spiegazione a partita ferma
("Prova (3 volte)" / "Salta l'allenamento") e poi tre prove in situazioni diverse; avanza quando il motore manda
l'evento giusto, rimette a posto la prova se il pallone esce, se lo prendono loro o dopo 16 s. Stessi testi e stesse
costanti del web, compresa la correzione del dribbling (ogni prova azzera le attese di duello, dribbling e contrasto,
e il difensore della lezione ha difesa 15). La logica è pura (gira nei test); `allenamento_hud.gd` è il riquadro in
alto (lezione, prova k di 3, testo; verde col "Bravo!") e la scheda; `bot_allenamento.gd` è il dito finto che supera
tutte le lezioni coi gesti veri.

In `gioco.gd` l'allenamento è `tipo == "allenamento"` (per ora si sceglie con `--allenamento`): avversario "Allenamento"
(livello 40), tempo senza fine, niente suggerimenti in basso né aiuto della visuale, `before()` prima dei passi del
motore e `after(dt)` dopo, chiusura 2,6 s dopo l'ultima lezione con "Allenamento finito!". Alla fine (o "Salta" /
"Esci dall'allenamento" in pausa) manda `finita({tipo: "allenamento", completato, abbandonata})` se la scena ha quel
segnale (carriera), sennò ricomincia.

```sh
$G --headless --path godot -s res://tests/run_tests.gd -- allenamento    # 7 test (~7 s)
$G --headless --path godot -s res://tests/run_tests.gd -- sfondo_menu    # 6 test, uguale al JS (fixture menu.json)
$G --headless --path godot -- --allenamento --bot --veloce=4 --esci-a-fine --seme=5    # tutte le lezioni col dito finto (~30 s)
$G --path godot -- --allenamento --lezione=1 --scheda --schermata=shots/scheda.png --dopo=1.5
$G --path godot -- --allenamento --bot --lezione=4 --prova=2 --schermata=shots/recupera.png --dopo=2.2
node test/export-menu.mjs        # rigenera tests/fixtures/menu.json dal JS
```

## Carriera e flusso dell'app (fase 3)

**Carriera** (`scripts/carriera/carriera.gd`, `class_name Carriera`): porting 1:1 di `src/career.js` con gli stessi
nomi di metodi e campi, così i menu si scrivono leggendo `career.js` e `src/ui.js`. Stato in `c.s` (Dictionary con le
stesse chiavi del web: `club`, `kit`, `money`, `season`, `day`, `teams`, `divs`, `squad`, `market`, `lineup`,
`formation`, `fix`, `tab`, `res`, `history`, `last`, `settings`, …). Metodi: `create(name, kit, seme = casuale)`,
`load()`, `save()`, `reset()`, `newSeason`, `table(d)`, `myRating`, `nextMatch`, `autoLineup`, `fixLineup`, `bench`,
`swap(a, b)`, `refreshMarket`, `buy(id)`, `sell(id)`, `sellPrice(p)`, `kitStyle`/`setKitStyle`, `crest`/`setCrest`,
`teamCrest(t)`, `setLook(id, look)`, `addChampion({name, pos, look, num})`, `div`, `team(id)`, `player(id)`,
`skillOf`, `divOf`, `kitOf`, `dress`, `myMatchTeam`, `aiMatchTeam(t)`, `record`, `simScore`, `finishMatch(my, opp,
log)`, `endSeason`. Funzioni e costanti statiche: `Carriera.DIV_NAMES`, `KITS`, `POS_NAME`, `FORMATIONS`,
`overall(p)`, `overallAs(p, pos)`, `value(p)`, `fmtMoney(k)`, `genPlayer(...)`, `randomName(r)`.
Differenze: `buy`/`sell` ritornano `""` se è andata bene (nel JS `null`); `s.settings` ha anche `music` e `vibra`;
gli interi restano `int` anche dopo il caricamento. `Aspetto` (`aspetto.gd`) = `src/looks.js` (`lookFromSeed`,
`normalizeLook`, `lookOf`, `kitStyleFromSeed`, `squadNumbers`, `backName`, elenchi `SKINS`, `HAIR_STYLES`, …, più
`colori(look)` per la grafica); `StemmaDati` (`stemma_dati.gd`) = dati di `src/crest.js` (`CREST_SHAPES`,
`CREST_PATTERNS`, `CREST_ICONS` come tracciati SVG, `crestFromSeed`, `normalizeCrest`, `crestColors`).

**Uguale al JS a parità di seme**: `node test/export-carriera.mjs` scrive `tests/fixtures/carriera.json` (pezzi,
creazione e calendario, mercato, rosa, stemma, campione, 20 giornate con risultati a caso, tre stagioni vinte con
promozioni e titolo) e `tests/test_carriera.gd` lo confronta passo per passo. Va rilanciato quando cambia la carriera
JS. Per avere gli stessi numeri: i mescolamenti `sort(() => r() - 0.5)` rifanno l'ordinamento di V8 (`js.gd`), e
`fmtMoney` rifà `toFixed` esatto (1005 k€ → "1,00 M€" come il JS).

**Salvataggio** (`salvataggio.gd`): `user://salvataggio.json` = `{"versione": 1, "carriera": s}` (nuovo formato,
quello dell'app web non si legge). Si scrive `salvataggio.json.tmp`, lo si rilegge, il file di prima diventa
`salvataggio.json.bak` e il temporaneo prende il suo posto. In lettura vince il primo buono tra principale, temporaneo
e copia; un principale rotto finisce in `salvataggio.json.rotto`; se non c'è niente di buono `load()` ritorna false
(il menu propone una carriera nuova). I campi mancanti si riempiono coi predefiniti (`completa`), il calendario rotto
si rifà. `tests/test_salvataggio.gd` prova tutti i casi.

**Flusso** (`scripts/app.gd`, autoload `App`; scena principale `scenes/app.tscn`):

| API | Cosa fa |
|---|---|
| `App.carriera` | la `Carriera` corrente (`App.carriera.s == null` = nessuna carriera) |
| `App.vai(schermata, arg = null)` | mostra `scenes/menu/<schermata>.tscn` (se manca: `segnaposto.tscn`); chiama `apri(arg)` se la scena ce l'ha; `arg` anche nel meta "arg" |
| `App.gioca_campionato()` | prossima partita di campionato |
| `App.gioca_amichevole(avversario)` | id di una squadra (`"t3"`), un livello (numero, come il web) o `null` (livello della mia squadra) |
| `App.allenamento()` | allenamento (avversario debole, tempo senza fine) |
| `App.ultimo_esito` | `{esito, res, titolo, tipo}` dell'ultima partita |
| `App.schermata_cambiata(nome)` | segnale |

All'avvio `App` mostra `"principale"`. Dopo la partita (risultato registrato al fischio, schermata cambiata con
"Continua"): campionato → `finishMatch` e `"dopo_partita"` con
`arg = App.ultimo_esito` (`res.season` a fine stagione); amichevole → `"dopo_partita"` (`res = null`); amichevole
abbandonata e allenamento → `"principale"`. App in sottofondo o chiusa = salva subito.

**Partita dall'app** (`gioco.gd`): `avvia(opz)` prima di aggiungere la scena (o entro il primo fotogramma) con
`{squadra_a, squadra_b, me, tipo: "campionato"|"amichevole"|"allenamento", durata_tempo, seme, titolo, autoGk}`;
le squadre sono quelle di `myMatchTeam()`/`aiMatchTeam()`, col campo `kit` = `{shirt, shorts, socks, gk, style,
crest, (gloves)}` che arriva alla vista. Al fischio finale emette `finita(esito)` con
`{gol_a, gol_b, marcatori (m.goalsLog), statistiche (m.stats), abbandonata, tipo, me}` (il risultato si registra
subito, anche se l'app viene chiusa sulla schermata di fine), poi il tasto "Continua" emette `continua` e `App`
cambia schermata. "Esci" dalla pausa: in
campionato sconfitta 0-3 a tavolino (come il web), in amichevole si torna al menu senza conseguenze. Senza `avvia`
la partita parte da sola con le squadre di prova (opzioni da riga di comando come prima).
La vista colora pelle e capelli dal `look` della carriera (indici di `Aspetto`) con `Aspetto.colori`.

### Capelli e barbe (2026-11-21)

Tagli e barbe sono **mesh a parte** (prima erano la testa gonfiata dallo shader della divisa: a gradini, "a punte").
- `scripts/partita/capelli.gd`: dal centro della testa (lo stesso di `divisa.gdshader`) misura una volta, per ogni
  direzione, dove esce la pelle del modello (mappa dei raggi, ~70 ms sul PC alla prima figura). Ogni taglio è una
  griglia azimut × elevazione appoggiata su quella pelle ammorbidita più lo spessore del taglio (`LINEA` = attaccatura,
  `SPESSORE`, `RAMPA`, `BORDO_K`, `FINE`/`CADE` per caschetto e lunghi che cadono in verticale, afro = ellissoide);
  pezzi a parte per cresta (pinna), a punte (coni smussati), coda (tubo con elastico), chignon (palla).
- `scripts/partita/barbe.gd`: guscio coi triangoli veri del viso spostati lungo la normale; la forma è un campo con
  segno in metri (pizzetto, baffi, corta, piena). L'"Ombra" resta dipinta.
- Una mesh per coppia taglio + barba, costruita alla prima richiesta (~10 ms sul PC) e condivisa; livelli di
  dettaglio generati da Godot (`ImporterMesh.generate_lods`). 1000-1500 triangoli i capelli, 300-1250 la barba.
- `Figura.metti_aspetto(aspetto)` mette colori e mesh (la chiama `prepara`, e l'anteprima dell'editor quando cambia
  il look); la mesh sta sotto un `BoneAttachment3D` sull'osso `Head` con la trasformazione di legame della pelle.
- `shaders/capelli.gdshader`, un materiale per tutti (colore capelli e pelle per istanza), niente trasparenza:
  l'attaccatura e il bordo della barba li taglia per pixel (pixel scartati con rumore = bordo di peli), striature
  lungo le ciocche, riflesso allungato (`ANISOTROPY`), radici scure, ricci e treccine col rilievo calcolato, due facce.
- `divisa.gdshader` dipinge ancora sotto i capelli (radici scure), i rasati (Rasato, lati della Cresta) e l'Ombra.
- Foto di controllo: `$G --path godot -s res://tests/foto_capelli.gd [-- --cartella=shots/capelli --giro=N]`
  (tutti i tagli e le barbe di fronte, tre quarti, lato, dietro; `--tagli=10,11 --barbe=5` = foto grandi). Test:
  `tests/test_capelli.gd`.

## Carriera, fase B (solo Godot)

Novità che il web non ha. Le funzioni portate da `career.js` (`finishMatch`, `endSeason`, `myMatchTeam`, …) restano
identiche al web (`tests/test_carriera.gd` le confronta ancora col JS, togliendo le chiavi nuove `CHIAVI_GODOT`);
le novità passano da due funzioni nuove che chiama `App`:

- `Carriera.squadraPartita()` al posto di `myMatchTeam()`: niente infortunati (la CPU mette il miglior sostituto
  sano, `schieraSani()`), e chi è giù di forma parte stanco (copie dei giocatori col campo `energy0`).
- `Carriera.dopoPartita(res, esito)` dopo `finishMatch`: premio del derby, crescita del campione, forma e
  infortuni, a fine stagione giudizio della dirigenza e obiettivo nuovo. Aggiunge a `res`: `derby`, `crescita`
  `{nome, righe}`, `infortuni`, `cambi`, `obiettivo` (anche in `res.season`).

| Cosa | File | Stato nel salvataggio |
|---|---|---|
| Campione che cresce giocando (`champ: true`) | `carriera/crescita.gd`, conteggi da `partita/conta_giocatori.gd` | `progressi` {id: {stat: decimali}} |
| Obiettivo della dirigenza | `carriera/dirigenza.gd` | `obiettivo` {stagione, div, tipo, posto} |
| Rivale e derby | `carriera/dirigenza.gd`; `audio_partita.gd` e `stadio/pubblico.gd` (`derby = true`) | `rivale` (id) |
| Forma e infortuni | `carriera/forma.gd` | `forma` {id: 0..100}, `infortuni` {id: giornate}, `semeB` |

- **Conteggi della partita**: `gioco.gd` chiama `conta.leggi(m)` a ogni fotogramma prima di consumare gli eventi;
  l'esito ha `conteggi` = {id: {gol, assist, tiri, in_porta, passaggi, intercetti, contrasti, dribbling, scatti,
  testa, parate, km}} per i giocatori della persona, e `derby`. Il motore non cambia.
- **Derby**: `avvia({... "derby": true})` → scritta "DERBY!" all'inizio, pubblico più forte (×1,3), cori ogni 9-15 s
  invece di 28-45 s, più tifosi in piedi e un coro sugli spalti ogni 11 s.
- **Energia iniziale** (unico cambio al motore, in tutte e due le copie): campo facoltativo `energy0` del giocatore
  sorgente (0,2..1); senza il campo si parte a 1 come sempre. Prove: `test/unit/start-energy.test.mjs`,
  `tests/fixtures/trace_7.json` (`test_traccia_7_energia_iniziale`, bit per bit col JS).
- Menu: obiettivo nell'hub (verde se oggi è raggiunto) e in classifica (linea gialla tratteggiata, "RIV" sulla
  rivale), pillola DERBY sulla prossima partita, crescita/derby/infortuni nella schermata dopo partita, giudizio
  della dirigenza a fine stagione, croce rossa e barretta della forma sulle carte della Rosa (un infortunato non
  entra con uno scambio).
- Prove: `tests/test_carriera_b.gd`; `--stagione-bot` stampa anche derby, crescita, infortuni e obiettivo;
  `--app-schermate` aggiunge hub, classifica, rosa (con un infortunato) e fine stagione.

## Statistiche a fine partita (fase C, punto 14, solo Godot)

Dal "dopo partita" (campionato e amichevole) il tasto **Statistiche e pagelle** apre la schermata `statistiche`
(`scenes/menu/statistiche.tscn`, `scripts/menu/statistiche.gd`); ‹ o "Torna al risultato" riportano al dopo partita
con lo stesso esito. L'allenamento non ha dopo partita (torna al menu) e quindi niente statistiche. Il motore non
cambia: tutto si raccoglie lato grafica dagli eventi.

- **Raccolta**: `partita/conta_giocatori.gd` (lo stesso oggetto dei conteggi della crescita) con `tabellino()`,
  che `gioco.gd` mette nell'esito (`esito.tabellino`, una riga): passaggi tentati e riusciti e km per squadra,
  mappa dei tiri `[{team, x, y, kind, esito, nome}]` (posizione di chi tira, coordinate del motore; esito `gol`,
  `parato`, `respinto` o `fuori`), giocatori della persona scesi in campo (anche i cambi) con `conti` = i conteggi
  di sempre più `perse` (contrasto subito o passaggio preso dall'avversario) e `subiti` (gol subiti mentre era in
  campo, non dopo un'espulsione). `per_giocatore()` per la crescita resta com'era (stesse chiavi).
- **Numeri**: possesso, tiri, tiri in porta, falli, angoli e parate da `m.stats`; passaggi riusciti (%) e km dal
  tabellino. Squadra 0 a sinistra in giallo, squadra 1 a destra in blu, come nel dopo partita (`riga_stat`).
- **Mappa dei tiri** (`partita/mappa_tiri.gd`, conti puri): campo intero verticale, la persona attacca verso
  l'alto; pallino pieno = gol, cerchio vuoto = parato, respinto o fuori.
- **Pagella** (`partita/voti.gd`, logica pura): voto da 4 a 10 a mezzi punti; 6 di base, vittoria +0,5 / sconfitta
  −0,5, gol +1, assist +0,6, dribbling +0,2 (max +1), contrasti +0,25 (max +1,25), intercetti +0,15 (max +0,75),
  passaggi riusciti +0,03 (max +0,6), parate +0,4 (max +2), gol subiti −0,5 portiere / −0,3 difensore / −0,1
  centrocampista, porta inviolata +0,5 portiere / +0,3 difensore, palle perse −0,1 (max −1,5). Migliore in campo
  (più punti prima dell'arrotondamento) con bordo giallo e scritta; il campione col nome in giallo e "★ Campione".
- Prove: `tests/test_voti.gd` (voti, mappa, tabellino da eventi scritti a mano e da una partita vera del motore),
  `tests/controlli_menu.gd` (tasto, pagella con un solo migliore, ritorno), schermate 25-26 di `prova_menu.gd` e
  `--app-schermate` (statistiche, mappa, pagella della partita appena giocata).

## Replay del gol e cronaca scritta (fase C)

Solo grafica: il motore (`sim/*`) non cambia e non vede mai i valori del replay.

| Cosa | File | Aggancio in `gioco.gd` |
|---|---|---|
| Buffer circolare degli ultimi 6 s | `scripts/partita/replay_buffer.gd` | `replay.registra(m)` dopo i passi del motore |
| Replay (stati, telecamera, linea del tiro, scritte, tocco per saltare) | `scripts/partita/replay.gd` | `replay.gol(m)` in `_gol`, `replay.trattieni()` nei passi, `replay.fotogramma()` in `_process` |
| Cronaca: evento → frase (logica pura) | `scripts/partita/cronaca.gd` | `cronaca.leggi(e, ora)` in `_eventi` |
| Cronaca a schermo | `scripts/partita/cronaca_vista.gd` | figlia dell'HUD (sotto i menu) |

- **Sequenza dopo un gol**: festa del motore (fase "goal", 3,2 s) → quando il passo dopo farebbe il calcio d'inizio
  il motore resta fermo → `_fine_festa_gol()` → `dopo_esultanza()` → replay (~5 s) → il motore riparte e fa il
  calcio d'inizio. **Esultanza del campione** (sezione sotto): `_fine_festa_gol()` aspetta anche che sia finita;
  finché non si chiama `dopo_esultanza()` il motore resta fermo (la vista continua).
- **Replay**: per ogni fotogramma `buffer.applica(m, t)` scrive lo stato registrato sugli oggetti della partita,
  `vista.update_view()` lo disegna, `buffer.ripristina(m)` rimette i valori veri (identici). La vista ha `replay = true`:
  non muove la telecamera (la muove `replay.gd`), niente anello, segnalino né linee di corsa. Visuale "porta" (dietro
  la linea di fondo, di fianco al palo) o "lato" (dalla linea laterale), bassa, FOV 48. Un tocco fuori dai tasti
  dell'HUD lo salta; la pausa lo ferma.
- **Cronaca**: frasi brevi per gol, autogol, parata, palo, tiro fuori, occasione, dribbling riuscito, contrasto,
  angolo, fallo, giallo, rosso, rigore, coi nomi; caso della grafica; poche frasi (vedi `PAUSA`, `PAUSA_FORTE`, `PROB`
  in cima al file). Niente replay né cronaca nell'allenamento guidato.
- **Prove**: `-- --scena=gol` (tiro a porta vuota) con `--replay=porta|lato` e `--schermata=... --dopo=SEC`
  (seme 3: gol a ~3 s, replay da ~5 a ~10 s); `--senza-replay`. Test: `tests/test_replay.gd`, `tests/test_cronaca.gd`.

## Esultanze del campione (fase C, punto 12, solo Godot)

Solo grafica: il motore (`sim/*`) non cambia; l'esultanza si fa nella pausa dopo il gol che c'è già.

| Cosa | File |
|---|---|
| Elenco (15 id e nomi), predefinita `aeroplano`, `valida()` | `scripts/partita/esultanze.gd` |
| Pose: una `Coreografia` per esultanza = `Mossa` (bacino, busto, testa, gambe, braccia) + corpo intero (spostamento e rotazioni: salti, capriola, giravolta) + tratti di corsa col clip vero + poli dei gomiti | `scripts/partita/mosse/esultanza.gd` |
| La figura la esegue (`Figura.esultanza = posa`, `applica_mossa` con pesi separati gambe / busto / braccia) | `scripts/partita/figura.gd` |
| Regia in partita (chi esulta, giro verso il centro del campo, telecamera, scritta, tocco per saltare) | `scripts/partita/esultanza_regia.gd` |
| Scelta: scheda **Esultanza** nell'editor (creazione del campione e poi Aspetto del campione), il modellino la fa | `scripts/menu/editor.gd`, `scripts/menu/anteprima_giocatore.gd` |
| Salvataggio: campo `esultanza` del campione, scritto solo da `setEsultanza(id, e)`; letto con `Carriera.esultanza_di(p)` (manca o è sbagliato → predefinita) | `scripts/carriera/carriera.gd` |

Le 15: Aeroplano, In ginocchio (scivolata), Capriola, Pugno al cielo, Indici al cielo, Saluto militare, Cuore con le
mani, Balletto, Mani alle orecchie, Dito sulla bocca, Salto col pugno, Inchino, Braccia conserte, Giravolta, Calcio
alla bandierina. Durano 2,8-3,0 s; solo pose procedurali (niente animazioni scaricate).

- **Sequenza dopo un gol** (`gioco.gd`): all'evento "goal" `_gol` chiama `esultanza.avvia(...)`: parte solo se ha
  segnato il campione (`src.champ`) della mia squadra, non in allenamento. La festa del motore va avanti; quando il
  motore è trattenuto (`_fine_festa_gol`) si aspetta anche la fine dell'esultanza (segnale `finita` della regia →
  `_esultanza_finita`), poi `dopo_esultanza()` → replay → calcio d'inizio. Un tocco fuori dai tasti la salta.
  Gli altri gol: come prima (subito il replay a fine festa).
- **Prove**: `-- --scena=gol --esultanza=ID [--schermata=... --dopo=SEC]` (seme 3: gol a ~3 s, esultanza fino a
  ~6 s, poi replay). Foto di tutte le esultanze, 6 istanti da due lati:
  `$G --path godot -s res://tests/foto_esultanze.gd [-- --solo=capriola,saluto --istanti=...]` → `shots/esultanze/`.
  `--app-schermate` fotografa anche la scheda Esultanza. Test: `tests/test_esultanze.gd` (pose: caviglie mai sotto
  terra, mani mai dentro il busto, durata dentro la festa; salvataggio vecchio senza il campo).

## Meteo e ora del giorno (2026-11-21)

Ogni partita ha un meteo (sereno, nuvoloso, pioggia, neve) e un'ora (pomeriggio, tramonto, notte coi fari accesi).
Tutto in `scripts/partita/meteo.gd`; `gioco.gd` lo chiama in due punti (scelta prima di creare `SimMatch`, grafica
dopo la vista) e mostra "Notte · Pioggia" sotto il titolo all'inizio.

- **Scelta** col seme (`SimRng`, niente `randi`): `Meteo.scegli(seme, giornata)`. Senza giornata (amichevole)
  probabilità fisse: sereno 45%, nuvoloso 30%, pioggia 20%, neve 5%. In campionato secondo la giornata (la stagione va
  da fine estate a primavera): prime e ultime giornate 58/28/14/0, autunno e inizio primavera 44/30/22/4, inverno
  (giornate in mezzo) 30/30/28/12: in media la neve resta intorno al 5%. Ora: pomeriggio 45%, tramonto 25%, notte 30%.
  In campionato la previsione viene da carriera + stagione + giornata (`Meteo.per_giornata`): l'hub la scrive sulla
  carta della prossima partita e `App` la passa alla partita (`avvia({... "meteo", "ora"})`), così è la stessa.
  L'allenamento guidato è sempre sereno di pomeriggio.
- **Prove**: `--meteo=sereno|nuvoloso|pioggia|neve` e `--ora=giorno|tramonto|notte` (vincono anche con `--app`).
- **Motore**: campo facoltativo `meteo` delle opzioni di `SimMatch` (e di `Match` in JS), in tutte e due le copie;
  costanti in cima a `sim/match.gd` / `src/sim/match.js` (`RAIN_ROLL`, `RAIN_SLIDE`, `RAIN_STUN`, `SNOW_ROLL`):
  pioggia = attrito del rotolamento ×0,75 (palla più veloce e più lunga; i passaggi rasoterra si calciano come
  all'asciutto, quindi arrivano più svelti), scivolata ×1,3, chi perde un contrasto fermo ×1,25; neve = attrito ×1,35
  (palla più lenta; i passaggi si calciano più forte per arrivare). Senza campo, sereno o nuvoloso il motore è
  identico: golden e tracce 0-7 uguali. Tracce nuove `trace_8.json` (pioggia, umano simulato) e `trace_9.json`
  (neve, IA contro IA), uguali al JS bit per bit (`test_traccia_8_pioggia`, `test_traccia_9_neve`).
- **Grafica** (niente in `vista.gd` tranne una riga: l'`Environment` della vista ora è una copia sua):
  - cielo (`ProceduralSkyMaterial` nuovo a ogni partita), luce, ombre più leggere col coperto, nebbia;
  - erba: uniform `bagnato` (più scura, lucida, con pozze larghe appena accennate) e `neve` (velo bianco più chiazze
    morbide; le righe restano sopra) in `shaders/erba.gdshader`, da `campo.gd set_meteo()`; a 0 l'erba è come prima;
  - tramonto: sole basso e caldo da ovest, ombre lunghe;
  - notte: nessuna luce in più (le ombre multiple costano sull'iPhone). La luce principale diventa quella dei fari
    (alta, bianca), l'ambiente un colore blu tenue, lo stadio passa su uno strato che la luce non illumina (tribune
    scure, campo illuminato; cartelloni e maxischermi esclusi), lampade delle torri più forti con un alone finto;
  - il pubblico 3D (uniform `luce`) si scurisce di notte, al tramonto e col brutto tempo;
  - pioggia (900 righe) e neve (700 fiocchi): `GPUParticles3D` in una scatola che segue la telecamera (solo la
    posizione, così cadono dritte); nel rallenty rallentano (`ts` di `gioco.gd`);
  - sulla neve il pallone diventa arancione.
- **Prove**: `tests/test_meteo.gd` (stesso seme stesso meteo, neve rara, stagioni, opzioni),
  `test/unit/weather.test.mjs` (motore JS), `test_meteo_moltiplicatori` in `test_equivalence.gd`.
  Equilibrio: `npm run balance -- 60 60 60 1 pioggia` (sesto argomento = meteo).

## Menu (fase 3)

Schermate del web (`src/ui.js`, `ui-squad.js`, `editor.js`) rifatte in Godot, una scena per schermata in
`scenes/menu/<nome>.tscn` con lo script `scripts/menu/<nome>.gd` (tutte estendono `MenuSchermata`, `schermata.gd`).
Il nome della scena è il nome per `App.vai(nome, arg)`:

| schermata | web | arg |
|---|---|---|
| `principale` | title | – (senza carriera va subito a `nuova_carriera`) |
| `nuova_carriera` | title('new') | `{club, kit}` facoltativo |
| `editor` | editor.js | `{flow: "new", club, kit}` · `{flow: "crest"}` · `{flow: "kit"}` · `{flow: "look", id}` |
| `hub` | hub | – |
| `rosa` | squad | `{sel, tgt}` facoltativo (id dei giocatori) |
| `mercato` | market | `{filtro: "T"/"P"/"D"/"C"/"A", aperto}` facoltativo |
| `classifica` | table | `{div}` facoltativo |
| `calendario`, `amichevole`, `uno_contro_uno`, `impostazioni` | calendar, friendly, vsfriend, settings | – |
| `come_si_gioca` | howto | numero della pagina (0..4) |
| `dopo_partita` | post | `App.ultimo_esito` (`{esito, res, titolo, tipo}`) oppure `{m, res, title}` come il web |
| `fine_stagione` | season | risultato di `endSeason` (`{pos, prize, bonus, outcome, div, newDiv}`) |

- **Contratto con `App`**: le schermate chiamano `App.vai`, `App.gioca_campionato()`, `App.gioca_amichevole(livello)`,
  `App.allenamento()` e leggono `App.carriera` (`s == null` = nessuna carriera), più `App.clic()` (suono del tocco:
  triangolo 520 Hz di 0,05 s generato in codice come `Sfx.click` del web, solo con l'audio acceso) e
  `App.impostazioni()` (dopo ogni scelta in Impostazioni; anche all'avvio e a ogni cambio di schermata). Effetto
  delle voci di Impostazioni: **Audio** subito (bus principale muto: menu, tocchi e partita); **Musica** subito
  (sottofondo dei menu, solo con l'audio acceso; in partita si ferma); **Vibrazione** subito (la legge
  `MenuSchermata._tocco` a ogni tocco, solo su telefono); **Durata di un tempo**, **Difficoltà** e **Portiere** dalla
  partita dopo (li leggono `App._partita` e `Carriera.aiMatchTeam`). La qualità grafica non è una voce: scende da
  sola in partita (`qualita.gd`), come nel web. Senza `App`
  (scena aperta da sola) si cambia scena con `change_scene_to_file` e la carriera è `MenuSchermata.carriera_prova`.
- **Dati**: tutto passa da `menu_dati.gd` (`MenuDati`), che gira le chiamate a `Carriera`, `Aspetto`, `StemmaDati`.
- **Tema** (`tema_menu.gd` → `assets/tema/tema.tres`, `tools/crea_tema.gd` lo rigenera): colori, raggi e varianti dei
  pulsanti del CSS del web (`ui-style.js`); carattere di sistema (San Francisco su iPhone, Segoe UI su Windows) come il
  web, niente file di caratteri. Pulsanti alti 48-60 px, entrata a cascata (sale di 12 px e compare), aree sicure
  dell'iPhone da `DisplayServer.get_display_safe_area()` (`--tacca=47,34` le simula sul PC).
- **Stemmi e visi** (`stemma.gd` = `crestSvg`, `faccia.gd` = `faceSvg`): lo stesso testo SVG del web, disegnato da
  ThorVG (`Image.load_svg_from_string`) alla risoluzione dello schermo, con una cache (`svg.gd`).
- **Rosa** (`rosa.gd`, `carta_giocatore.gd`, `rosa_logica.gd` = `squad-layout.js`): carte FUT sul campo, panchina che
  scorre, tocco = scegli, secondo tocco = confronta, terzo = scambia (come il web); confronto delle statistiche e
  variazione della forza.
- **Editor** (`editor.gd`, `anteprima_giocatore.gd`): palco fisso in alto (stemma grande, oppure il giocatore della
  partita in una SubViewport che gira piano e si gira col dito, inquadratura della testa per Viso e Capelli, più il
  viso disegnato in alto a destra), schede, scelte che scorrono, Casuale e Avanti/Salva in fondo. La figura ha gli
  stessi parametri della partita (`Aspetto.parametri_figura`: taglio, barba, sopracciglia, occhi, scarpe; stile della
  divisa, il portiere con maniche lunghe e tinta unita); manca solo numero e cognome sulla schiena.
- **Sfondo 3D** (`sfondo_menu.tscn`, altro lavoro) dietro `principale` e `hub` (con un velo scuro), col campione
  della carriera (`MenuSchermata.giocatore_sfondo()`); `--senza-3d` lo toglie.

Prove:
```
$G --path godot res://tests/prova_menu.tscn -- --tutte=shots/menu          # 24 schermate 390×844 (carriera di prova)
$G --path godot res://tests/prova_menu.tscn -- --schermata=rosa --arg='{"sel":"titolare:9"}' --foto=shots/r.png
$G --path godot res://tests/prova_menu.tscn -- --fps=mercato               # FPS e scorrimento col dito finto
$G --headless --path godot res://tests/prova_menu.tscn -- --controlli      # gesti delle schermate (controlli_menu.gd)
$G --headless --path godot -s res://tests/run_tests.gd -- menu             # visi, stemmi, Rosa uguali al web
node godot/tools/dati_menu_web.mjs   # rigenera tests/fixtures/menu_ui.json e carriera_menu.json dal JS
```
La carriera di prova (`tests/fixtures/carriera_menu.json`, 3 giornate giocate) salva su `user://prova_menu.json`,
mai sul salvataggio vero.

## Animazioni mocap

Clip vere del **"Free mocap pack 05: Soccer"** di Anderson Rohr (licenza in `CREDITI.md`), reindirizzate sul nostro
scheletro (stessi nomi di ossa Unreal, tutti e due in posa a T) e salvate in `assets/mocap/mocap.res`: una
AnimationLibrary compressa con solo le clip usate (25 clip, ~436 KB). Le usa `scripts/partita/figura_mocap.gd`,
agganciato a `figura.gd` con poche righe segnate `[mocap]` (e due in `vista.gd`).

| Clip | Quando | Come |
|---|---|---|
| `esulta1..3` | gol | il marcatore e fino a 3 compagni entro 14 m, clip scelta col seme (stesso gol = stesse esultanze); gli altri compagni restano con l'esultanza calcolata |
| `parata_alta/media/bassa_sx/dx` | tuffo del portiere | se lato, distanza e altezza del tuffo somigliano a quelle della clip (`raggio_x`, `raggio_h` misurati); altrimenti resta il tuffo calcolato. Petto verso il campo; la clip arriva al punto più lontano quando il tuffo del motore è a pieno |
| `piatto_dx/sx` | passaggio a terra | la clip parte **dal fotogramma del contatto** quando il motore calcia (il calcio del motore è istantaneo); il corpo si gira verso dove va il pallone |
| `collo_dx/sx`, `rigore1/2_dx/sx` | passaggio alto, tiro, rigore | come il piatto; il tiro alterna collo e rigore. Destro, mancino un giocatore su cinque (fisso per nome). Colpo di testa = posa calcolata |
| `rimessa` | rimessa laterale | il battitore tiene il pallone sopra la testa (avanti e indietro nel tratto "presa") finché il motore non lancia, poi parte dal rilascio; la vista mette il pallone tra le mani (`pallone_in_mano`) |
| `difesa1/2` | difesa | in loop per chi sta entro 5,5 m dal portatore avversario, lo guarda e va piano (peso che cala sopra 1,2 m/s, nullo a 3 m/s: la clip sta sul posto) |
| `giallo`, `giallo_rosso` | — | **pronte, non usate**: il motore dà i cartellini (evento `foul` con `card`) ma non c'è un arbitro da animare |
| `palleggio1..3` | — | **pronte, non usate** (vedi sotto) |

- Le clip vanno nell'AnimationTree della figura (Blend2 `mocap` in fondo, Transition `mc_clip` → TimeSeek → TimeScale),
  che avanza col tempo di gioco: **rallentano col rallenty**. Entrata 0,12 s (calcio 0,05 s), uscita 0,25 s, tra due
  clip 0,08 s. Con la clip attiva le pose calcolate non si mettono (il corpo lo fa tutto la clip).
- Root motion: il bacino **non si sposta in orizzontale** (lo spostamento lo dà il motore), l'altezza resta (scalata
  sulle nostre gambe). Le clip sono girate in modo che il giocatore guardi avanti: calci verso dove va il piede al
  contatto, rimessa verso dove va la mano al rilascio, il resto verso dove guarda il bacino.
- `FiguraMocap.spento = true` le spegne tutte (pose calcolate); senza `mocap.res` il gioco va come prima.

**Palleggi (per lo sfondo del menu o altro):** la libreria si aggiunge a qualunque AnimationPlayer del modello
`athlete.glb` (le tracce sono `Armature/Skeleton3D:<osso>`, come le clip di base):

```gdscript
const FiguraMocap := preload("res://scripts/partita/figura_mocap.gd")
var lib := FiguraMocap.libreria()          # null se manca il file
if lib != null:
    player.add_animation_library(&"mocap", lib)
    player.play(&"mocap/palleggio1")      # 23 s; palleggio2 20,5 s, palleggio3 20,6 s (non in loop: metterlo se serve)
```

Il pallone non c'è nella clip: va messo a mano sul piede (osso `ball_r`/`ball_l`) o sulla testa nei momenti giusti.

**Rifare la libreria** (i file del pack sono dati: si leggono gli FBX della cartella UE5, non si esegue niente da lì):

```sh
$G --headless --path godot -s res://tools/converti_mocap.gd                         # cartella predefinita
$G --headless --path godot -s res://tools/converti_mocap.gd -- C:/.../mocap/UE5      # altra cartella
$G --headless --path godot -s res://tools/converti_mocap.gd -- --tutte               # anche i dribbling (non usati)
$G --headless --path godot -s res://tools/converti_mocap.gd -- --analizza            # stampa le misure delle clip
```

Tagli, piede, contatto, stacco e raggio delle parate sono nell'elenco `CLIP` in cima allo strumento e nei metadati
della libreria (`FiguraMocap.info("piatto_dx")`). Test: `tests/test_mocap.gd`. Prove a schermo:
`prova_vista.tscn -- --scena=esultanza|tiro|piatto|rimessa|difesa` (e `parata --tuffo=X,ALTEZZA --vicino=0`),
`--senza-mocap` per le stesse scene con le pose calcolate, `--traccia=N|segui` per stampare clip, tempo e peso.

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
#   --scena=rallenty | girata | parata | angolo | giochetto | linea | gol | rete | festa | primo | volti
#           (più --sequenza=N --ogni=SEC)
#   --me=1 (campo capovolto) · --vicino=N (telecamera vicina a m.players[N]) · --senza-vsync --esci-dopo=15
#   --qualita=0..3 (livello grafico fisso) · --senza=pubblico,cartelloni,schermi,tetti,fari,bagliore,dof,ombre,effetti,aspetto
#   --scala3d=2 (tanti pixel 3D quanti sull'iPhone): con --esci-dopo stampa anche GPU e disegno CPU per fotogramma
$G --headless --path godot -s res://tools/genera_texture.gd   # rigenera assets/textures/ (poi --import)

#   mocap: --scena=esultanza | tiro | piatto | rimessa | difesa · --tuffo=X,H · --senza-mocap · --traccia=N|segui
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
| `tifo(tipo: String, squadra: int)` | reazione del pubblico: "gol", "occasione" (tiro), "parata", "palo", "fischio"; squadra = chi segna / tira / para / prende il palo / subisce il fischio. Il gol la vista lo vede da sola dal punteggio (festa una volta per gol: tifosi, maxischermo, coriandoli) |
| `set_rallenty(k: float)` | facoltativa: 0..1 quanto è "rallenty" (profondità di campo); < 0 = la vista lo ricava da `dt_game / dt_real` |
| `set_qualita(l: int)` | livello grafico 3 alto, 2 medio, 1 basso, 0 minimo; `qualita_auto` (vero) lo abbassa da sola sotto 58 fps, `livello_qualita` dice quello in uso |
| `dispose()` | via figure e riferimenti; va bene anche da `_exit_tree` del padre |
| `user_yaw`, `cam_drag`, `drawing` | scritti da chi gestisce il dito |

Le linee di difesa assegnate (`m.runs[me]`) si disegnano da sole a ogni `update_view`.
Aspetto dei giocatori: `src.look` (campi di `src/looks.js`) se c'è, sennò dal seme come `lookOf`; stile della divisa da
`team.kit.style`, sennò dal nome della squadra (`kitStyleFromSeed`); numero `src.num` (sennò posto + 1), cognome da `src.name`.

### Livelli grafici (fase 4)

| Livello | Cosa c'è |
|---|---|
| 3 alto | tutto: profondità di campo nel rallenty e nei primi piani, ombre morbide (filtro "soft low", sfocatura 1,6), bagliore, pubblico pieno, coriandoli pieni |
| 2 medio | niente profondità di campo, ombre con filtro "very low" |
| 1 basso | anche senza bagliore, metà pubblico, metà particelle |
| 0 minimo | niente pubblico 3D (torna quello dipinto), niente scia e sbuffi, coriandoli a un quarto |

Sotto 58 fps per 3 secondi di fila (finestre di 1 s, dopo 4 s dall'inizio) si scende di un livello; non si risale
(meglio stabile che altalenante). Il contatore FPS resta.

## Prestazioni sul telefono

- Renderer **Mobile** (Metal su iPhone), MSAA 4×, ombre del sole a 2 fasce fino a 70 m, solo i giocatori e le porte
  fanno ombra, nebbia leggera; 60 fps come obiettivo (`allow_high_refresh_rate=false`: niente 120 Hz, meno calore).
- L'interfaccia segue i **punti** dell'iPhone (390×844 logici, stretch `canvas_items` + `expand`): su schermi più
  alti si vede più campo, non si deforma nulla. Contatore e aiuto stanno dentro l'**area sicura** (tacca, barra home).
- Il 3D si disegna largo al massimo **780 px** (2× la larghezza logica) e si ingrandisce con FSR: su un iPhone a 3×
  (1170 px) vuol dire scala 0,67, cioè metà dei pixel da disegnare. Il contatore mostra la risoluzione usata.
- Memoria: nell'app Godot non conta la propria memoria (vale solo nelle build di debug); il contatore mostra la memoria
  video e la RAM libera del telefono secondo iOS.
