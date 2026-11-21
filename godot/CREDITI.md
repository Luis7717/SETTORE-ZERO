# Crediti dei file in godot/assets/

Copie dei file di `assets/` del gioco web (fonti e lavorazioni descritte in `assets/CREDITI.md`), più l'icona.
Licenze: tutto **CC0 1.0** (pubblico dominio; attribuzione non obbligatoria, la diamo lo stesso).

## Modelli 3D

| File | Origine | Autore | Licenza | Note |
|------|---------|--------|---------|------|
| models/athlete.glb (in uso) | Quaternius "Universal Base Characters" [Standard] (`Superhero_Male_FullBody`), https://quaternius.itch.io/universal-base-characters · Quaternius "Universal Animation Library" [Standard] (clip `idle`, `run`, `sprint`, `jump`), https://quaternius.itch.io/universal-animation-library | Quaternius (https://quaternius.com) | CC0 1.0 | Preparato per il web da `tools/make-athlete.mjs` (vedi `assets/CREDITI.md`). In Godot la divisa la colora `shaders/divisa.gdshader` |
| models/player.glb (riserva, non usato nella fase 1) | Kenney "Animated Characters 1" / "Animated Characters: Protagonists", https://kenney.nl/assets/animated-characters-protagonists | Kenney (www.kenney.nl) | CC0 1.0 | — |
| models/player_skin.png | texture incorporata in `player.glb`, estratta da Godot all'importazione | Kenney | CC0 1.0 | generata dall'importazione: si ricrea da sola |

## Animazioni mocap

| File | Origine | Autore | Licenza | Note |
|------|---------|--------|---------|------|
| mocap/mocap.res | "Free mocap pack 05: Soccer", https://andersonrohr.gumroad.com/l/mocap_pack5 (versione UE5, file FBX 01-21) | Anderson Rohr (https://andersonrohr.gumroad.com) | pack gratuito, uso secondo la pagina Gumroad confermata da Luis (vedi sotto) | Reindirizzate sul nostro scheletro da `tools/converti_mocap.gd`: solo le clip usate, tagliate, bacino senza spostamento orizzontale, compresse |

Licenza: nel pack non c'è un testo di licenza (il PDF `Importing_into_UE5.pdf` spiega solo come importare in Unreal e
finisce coi link alla pagina Gumroad e al LinkedIn dell'autore; nei file nessun LICENSE o README). Anche il testo della
pagina Gumroad letto il 2026-11-20 non riporta condizioni scritte. Vale quindi la licenza della pagina Gumroad del
pack, che Luis ha confermato. Citiamo comunque l'autore, qui e nel README. Se l'autore pubblica condizioni diverse,
valgono quelle.

## Suoni (partita; `music.mp3` nei menu dal 2026-11-21)

Tutti da Freesound, **CC0 1.0**, ritagliati per il web (dettagli e tempi in `assets/CREDITI.md`):

| File | Origine | Autore |
|------|---------|--------|
| audio/crowd.mp3, audio/goal.mp3 | https://freesound.org/people/itmightgetloud/sounds/829456/ | itmightgetloud |
| audio/ooh.mp3 | https://freesound.org/people/Sandermotions/sounds/494362/ | Sandermotions |
| audio/whistle.mp3 | https://freesound.org/people/Rosa-Orenes256/sounds/538422/ | Rosa-Orenes256 |
| audio/whistle_long.mp3 | https://freesound.org/people/SpliceSound/sounds/218318/ | SpliceSound |
| audio/kick.mp3 | https://freesound.org/people/bittermelonheart/sounds/555042/ | bittermelonheart |
| audio/music.mp3 | https://freesound.org/people/neko_4444/sounds/739064/ | neko_4444 |

## Icona

`icons/icon_1024.png`: l'icona dell'app web (`App/AppIcon60x60@3x.png`, 180×180, disegno originale del progetto)
ingrandita a 1024×1024 da `tools/genera_icona.gd`. È un po' morbida: un'icona disegnata a 1024 sarà meglio.

## Texture HD (fase 4)

| File | Origine | Licenza |
|------|---------|---------|
| textures/pallone.png, textures/pallone_n.png | disegno originale del progetto, generato da `tools/genera_texture.gd` (32 spicchi su un icosaedro troncato, cuciture in rilievo) | CC0 1.0 |
| textures/erba_n.png | disegno originale del progetto, generato da `tools/genera_texture.gd` (fili d'erba casuali con seme fisso, rumore di Godot) | CC0 1.0 |

Nessuna texture scaricata: tutte si rigenerano con `$G --headless --path godot -s res://tools/genera_texture.gd`.

## Fatto nel codice (niente file esterni)

Fase 4: pubblico 3D (figurine disegnate a codice in `scripts/stadio/pubblico.gd`), cartelloni a led con 16 sponsor
inventati (`scripts/stadio/cartelloni.gd`), maxischermi, tettoie, coriandoli, scia, capelli, barbe, numeri e cognomi
sulle maglie (font predefinito di Godot): tutto disegnato dal codice, niente copiato da altri giochi.

Erba, righe, porte, rete, bandierine, tribune, pubblico dipinto, cartelloni, torri faro, pallone, colori delle divise:
li genera il codice (`scripts/campo.gd`, `scripts/stadio.gd`, `scripts/prova_campo.gd`, `shaders/`), disegni originali.
