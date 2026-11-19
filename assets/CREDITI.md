# Crediti dei file in assets/

Tutti i suoni vengono da Freesound con licenza **CC0 1.0** (pubblico dominio, attribuzione non obbligatoria:
li citiamo lo stesso). Sono le anteprime MP3 di Freesound, ritagliate senza ricodifica con `tools/cut-mp3.mjs`.

| File | Origine | Autore | Ritaglio |
|------|---------|--------|----------|
| audio/crowd.mp3 | https://freesound.org/people/itmightgetloud/sounds/829456/ | itmightgetloud | 195–220 s (tifo costante, in loop) |
| audio/goal.mp3 | stessa registrazione (829456) | itmightgetloud | 109,6–116 s (boato) |
| audio/ooh.mp3 | https://freesound.org/people/Sandermotions/sounds/494362/ | Sandermotions | 2,8–6,2 s |
| audio/whistle.mp3 | https://freesound.org/people/Rosa-Orenes256/sounds/538422/ | Rosa-Orenes256 | intero |
| audio/whistle_long.mp3 | https://freesound.org/people/SpliceSound/sounds/218318/ | SpliceSound | 0–1,5 s |
| audio/kick.mp3 | https://freesound.org/people/bittermelonheart/sounds/555042/ | bittermelonheart | intero |
| audio/music.mp3 | https://freesound.org/people/neko_4444/sounds/739064/ | neko_4444 | intero (loop) |

## Modelli 3D

| File | Origine | Autore | Licenza | Lavorazione |
|------|---------|--------|---------|-------------|
| models/player.glb | Kenney "Animated Characters 1" (ora "Animated Characters: Protagonists"), https://kenney.nl/assets/animated-characters-protagonists | Kenney (www.kenney.nl) | **CC0 1.0** (pubblico dominio) | `characterMedium.fbx` + clip `idle`, `run`, `jump` convertiti in glTF con FBX2glTF (pacchetto npm `fbx2gltf`), uniti in un solo file con gltf-transform, semplificati da 1604 a 720 triangoli (meshoptimizer); texture di partenza `skaterMaleA.png` (il gioco ne usa la testa e ridipinge maglia, pantaloncini, calzettoni e scarpe coi colori delle squadre, `src/players3d.js`) |

Capelli (mesh agganciata all'osso della testa), viso, maglie, numeri e stemmi non vengono da file esterni: li genera e
li dipinge il codice del gioco (`src/players3d.js`, `src/crest.js`), disegni originali.
