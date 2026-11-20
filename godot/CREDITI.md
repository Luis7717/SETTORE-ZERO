# Crediti dei file in godot/assets/

Copie dei file di `assets/` del gioco web (fonti e lavorazioni descritte in `assets/CREDITI.md`), più l'icona.
Licenze: tutto **CC0 1.0** (pubblico dominio; attribuzione non obbligatoria, la diamo lo stesso).

## Modelli 3D

| File | Origine | Autore | Licenza | Note |
|------|---------|--------|---------|------|
| models/athlete.glb (in uso) | Quaternius "Universal Base Characters" [Standard] (`Superhero_Male_FullBody`), https://quaternius.itch.io/universal-base-characters · Quaternius "Universal Animation Library" [Standard] (clip `idle`, `run`, `sprint`, `jump`), https://quaternius.itch.io/universal-animation-library | Quaternius (https://quaternius.com) | CC0 1.0 | Preparato per il web da `tools/make-athlete.mjs` (vedi `assets/CREDITI.md`). In Godot la divisa la colora `shaders/divisa.gdshader` |
| models/player.glb (riserva, non usato nella fase 1) | Kenney "Animated Characters 1" / "Animated Characters: Protagonists", https://kenney.nl/assets/animated-characters-protagonists | Kenney (www.kenney.nl) | CC0 1.0 | — |
| models/player_skin.png | texture incorporata in `player.glb`, estratta da Godot all'importazione | Kenney | CC0 1.0 | generata dall'importazione: si ricrea da sola |

## Suoni (non ancora usati nella fase 1)

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

## Fatto nel codice (niente file esterni)

Erba, righe, porte, rete, bandierine, tribune, pubblico dipinto, cartelloni, torri faro, pallone, colori delle divise:
li genera il codice (`scripts/campo.gd`, `scripts/stadio.gd`, `scripts/prova_campo.gd`, `shaders/`), disegni originali.
