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
| models/athlete.glb (modello in uso) | Quaternius "Universal Base Characters" [Standard] (`Superhero_Male_FullBody`, corpo e occhi), https://quaternius.itch.io/universal-base-characters · Quaternius "Universal Animation Library" [Standard] (`UAL1_Standard.glb`, clip `Idle_Loop`, `Jog_Fwd_Loop`, `Sprint_Loop`, `Jump_Loop`), https://quaternius.itch.io/universal-animation-library | Quaternius (https://quaternius.com) | **CC0 1.0** (pubblico dominio; licenza nei file `License_Standard.txt` e `License.txt` dei pacchetti) | `tools/make-athlete.mjs`: tolte le ossa delle dita (65 → 23), occhi uniti al corpo, corpo semplificato da 12 566 a 6 200 triangoli (meshoptimizer, testa intatta), spalle, petto e braccia un po' più stretti, UV del corpo nella parte alta dell'atlante, solo rotazioni delle clip (+ bacino riscalato), mappa di dettaglio in grigi 512×512 ricavata dalla texture della pelle chiara. Niente sopracciglia, capelli o texture originali: colori, viso e divisa li dipinge `src/athlete3d.js` |
| models/player.glb (riserva) | Kenney "Animated Characters 1" (ora "Animated Characters: Protagonists"), https://kenney.nl/assets/animated-characters-protagonists | Kenney (www.kenney.nl) | **CC0 1.0** (pubblico dominio) | `characterMedium.fbx` + clip `idle`, `run`, `jump` convertiti in glTF con FBX2glTF (pacchetto npm `fbx2gltf`), uniti in un solo file con gltf-transform, semplificati da 1604 a 720 triangoli (meshoptimizer); texture di partenza `skaterMaleA.png` (il gioco ne usa la testa e ridipinge maglia, pantaloncini, calzettoni e scarpe coi colori delle squadre, `src/players3d.js`) |

Capelli (mesh agganciata all'osso della testa), viso, maglie, numeri e stemmi non vengono da file esterni: li genera e
li dipinge il codice del gioco (`src/athlete3d.js`, `src/players3d.js`, `src/hair3d.js`, `src/crest.js`), disegni originali.
