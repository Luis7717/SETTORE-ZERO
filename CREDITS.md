# Crediti — Settore Zero

Tutte le risorse esterne usate nel gioco, con autore, fonte e licenza.
Sono ammesse solo licenze CC0 o CC-BY (con attribuzione). Nessuna risorsa NC, ND o SA.

## Attribuzioni obbligatorie (CC-BY)

- Musica: *Tactical Pursuit* e *Space Boss Battle Theme* di Matthew Pablo (www.matthewpablo.com), licenza [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/).
- «Space Ship Hallway» di yeeyeeman (Sketchfab), licenza [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) — modello della sala.
- Barile: dagli asset di Babylon.js, licenza CC-BY 4.0 (resta solo come ripiego se manca il barile nuovo).

## Modelli che erano già nel gioco

- Soldato e androide «Xbot»: personaggi Mixamo presi dagli esempi di three.js (uso libero nei progetti, non è una licenza CC).
- Robot «RobotExpressive» di Tomás Laulhé / Quaternius, CC0, dagli esempi di three.js.
- Armi e granata: pacchetto «Guns & Explosives» di 3DModelsCC0, CC0.
- three.js (libreria grafica): licenza MIT.

## Crediti modelli 3D e texture — armi e oggetti di scena

File del gioco: `www/models/n_*.js` (GLB in base64: `ASSET.n_nome="..."`), usati da `www/js/armi-ambienti.js`.
Se un file manca, il gioco usa la grafica vecchia.

Licenze: tutti gli asset qui sotto sono **CC0 1.0** (pubblico dominio, nessun obbligo di attribuzione;
li citiamo comunque per correttezza): https://creativecommons.org/publicdomain/zero/1.0/
Poly Haven: licenza di tutti gli asset https://polyhaven.com/license (CC0).
OpenGameArt: la licenza è indicata nella pagina dell'asset.

| Nome nel gioco | Titolo originale | Autore | Fonte | Licenza | Modifiche |
|---|---|---|---|---|---|
| `n_pistola` (pistola) | Service Pistol | Mateusz Sadek (Poly Haven) | https://polyhaven.com/a/service_pistol | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | tenuta solo la variante "a" (fusto, carrello, cane, grilletto: 7.556 triangoli), tolti caricatori/proiettile/variante "b"; ruotata (canna verso -z); texture da 1k: colore 1024 px, normal e metal/rough 512 px (JPG); tolte tangenti; geometria quantizzata (KHR_mesh_quantization) |
| `n_cecchino` (cecchino) | Bolt Action Rifle 7.62 | Mateusz Sadek (Poly Haven) | https://polyhaven.com/a/bolt_action_rifle_7_62 | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | tenuti fucile, ottica, fasciatura, otturatore "a", grilletto; tolti proiettile e otturatore "b"; semplificato da 18.276 a 9.462 triangoli (meshoptimizer); ruotato; texture 512 px JPG; tolte tangenti; quantizzato |
| `n_rpg` (lanciarazzi) | Low poly RPG7 | GeorgeTheCyan (OpenGameArt) | https://opengameart.org/content/low-poly-rpg7 | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | convertito da FBX a GLB, raddrizzato (asse principale allineato), scalato a ~1,5 m, ruotato (avanti = -z); texture 512 px JPG; 1.014 triangoli |
| `n_barile` (barile esplosivo, sostituisce il barile Babylon.js) | Barrel_01 (variante "explosive") | Jorge Camacho (Poly Haven) | https://polyhaven.com/a/Barrel_01 | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | texture 512 px JPG; tolte tangenti; quantizzato; 2.682 triangoli; nel gioco scalato per stare nello stesso cilindro di collisione (raggio 0,32, alto 0,95) |
| `n_texture` → `legno` (assi delle casse di legno) | Brown Planks 04 | Rob Tuytel (Poly Haven) | https://polyhaven.com/a/brown_planks_04 | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | solo colore e normal map, ridotte a 1024 px JPG, impacchettate in un GLB |
| `n_texture` → `lamiera` (pannelli delle casse metalliche e dei container) | Corrugated Iron 02 | Jenelle van Heerden, Sergej Majboroda (Poly Haven) | https://polyhaven.com/a/corrugated_iron_02 | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | solo colore e normal map, ridotte a 1024 px JPG, impacchettate in un GLB; nel gioco tinte di verde/blu/rosso |

Fatti nel codice (nessun asset esterno): la geometria delle casse (telaio, assi, diagonali), la mano col guanto
e la manica (forme e texture procedurali in `armi-ambienti.js`).

Testo di attribuzione facoltativo (es. nel README):
"Modelli e texture CC0 da Poly Haven (Mateusz Sadek, Jorge Camacho, Rob Tuytel, Jenelle van Heerden, Sergej Majboroda)
e OpenGameArt (GeorgeTheCyan)."


## Crediti personaggi — Settore Zero

Per la rifinitura dei personaggi **non è stato aggiunto nessun modello scaricato**: tutto l'equipaggiamento nuovo
(elmetti, visori, giubbotti, spallacci, zaini, ginocchiere, lame, corazze del robot, decorazioni dello scudo,
dettagli di torretta e drone) è **geometria procedurale** creata dal codice in `www/js/personaggi.js` e
`www/js/modelli.js` (cubi smussati, cilindri, sfere, tori di three.js). Nessun file `www/models/p_*.js` è stato creato.

È stata cercata un'alternativa CC0 al robot «RobotExpressive» (androide militare animato) su poly.pizza /
quaternius.com: i candidati trovati («Mech» con piloti animali, «Robot Enemy» non umanoidi, «LowPoly Robot» stesso
stile cartone dello stesso autore) non erano adatti, quindi il robot esistente è stato rifinito invece che sostituito.
I file di prova scaricati sono stati cancellati e non sono nel gioco.

### Modelli già presenti nel gioco, modificati in esecuzione (i file originali non sono stati toccati)

| Nome nel gioco | Titolo originale | Autore | Fonte | Licenza | Modifiche |
|---|---|---|---|---|---|
| `sol` (Soldato, Granatiere, Bruto) | Soldier.glb | personaggio Mixamo (Adobe), dagli esempi di three.js | https://github.com/mrdoob/three.js/tree/r128/examples/models/gltf | modello d'esempio di three.js (Mixamo, uso libero nei progetti; non è una licenza CC) | aggiunti in esecuzione pezzi agganciati alle ossa (zaini, radio, tasche, spallacci, ginocchiere, corazza del Bruto), visore più luminoso, luce di contorno (rim) nel colore della minaccia |
| `xbot` (Cecchino, Assaltatore, Scudiero) | Xbot.glb | personaggio Mixamo (Adobe), dagli esempi di three.js | https://github.com/mrdoob/three.js/tree/r128/examples/models/gltf | modello d'esempio di three.js (Mixamo, uso libero nei progetti; non è una licenza CC) | colore della tuta più scuro/metallico, corazza da androide agganciata alle ossa, cappuccio e monocolo (Cecchino), elmo con cresta e lame (Assaltatore), elmo a T e batteria (Scudiero), luce di contorno |
| `robot` (Automa) | RobotExpressive.glb | Tomás Laulhé (Quaternius), modifiche di Don McCurdy | https://github.com/mrdoob/three.js/tree/r128/examples/models/gltf/RobotExpressive | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) | materiali nuovi (corazza oliva con piastre, acciaio scuro, lenti scure rosse al posto degli occhioni arancioni), testa ridotta all'85% (dentro la hitbox invariata), corazze/zaino/antenna/spallacci agganciati alle ossa, materiale "con pelle" separato per le mani (in r128 restavano in posa a T) |

Tutte le dimensioni, le hitbox e i punti di mira (`aimBone`, `cy`, `hy`) sono rimasti uguali.

### Elementi procedurali (nessuna licenza esterna)

- Torretta, drone, scudo dello Scudiero, boss «Colosso»: dettagli aggiunti con geometria e materiali di three.js
  (`www/js/modelli.js`, `www/js/personaggi.js`). Le texture a piastre (`plateTex`) sono generate dal codice.


## Crediti audio — Settore Zero

Tutti i suoni e le musiche registrati del gioco stanno in `www/suoni/` (MP3 in base64 dentro file `.js`,
perché nella WKWebView non si possono leggere file locali con fetch). Il codice che li usa è `www/js/audio.js`.
Se un suono registrato manca o non si decodifica, il gioco usa la versione sintetizzata (Web Audio).

Licenze usate: solo **CC0** (pubblico dominio, nessun obbligo) e **CC-BY 3.0** (obbligo di citare l'autore).

- CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/
- CC-BY 3.0: https://creativecommons.org/licenses/by/3.0/

Modifiche comuni a tutti gli effetti: convertiti in mono 44,1 kHz, tagliati, normalizzati a -1 dBFS,
dissolvenza in chiusura, codificati in MP3 96 kbps.

### Musiche (CC-BY 3.0, attribuzione obbligatoria)

| Nome nel gioco | Titolo originale | Autore | Fonte | Licenza | Modifiche |
|---|---|---|---|---|---|
| `mus_level` (musica dei livelli) | Tactical Pursuit | Matthew Pablo (http://www.matthewpablo.com) | https://opengameart.org/content/tactical-pursuit | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) | estratto un loop di 61,9 s (da 46,3 s a 108,2 s del brano), giunzione con dissolvenza incrociata di 60 ms, 0,3 s di margine prima/dopo per il loop, normalizzato, MP3 stereo 96 kbps |
| `mus_boss` (musica dei boss) | Space Boss Battle Theme ("Orbital Colossus") | Matthew Pablo (http://www.matthewpablo.com) | https://opengameart.org/content/space-boss-battle-theme | [CC-BY 3.0](https://creativecommons.org/licenses/by/3.0/) | estratto un loop di 64,4 s (da 17,7 s a 82,1 s del brano), giunzione con dissolvenza incrociata di 60 ms, 0,3 s di margine prima/dopo per il loop, normalizzato, MP3 stereo 96 kbps |

Testo di attribuzione da mostrare (es. nel README o nei crediti del gioco):
"Musica: *Tactical Pursuit* e *Space Boss Battle Theme* di Matthew Pablo (www.matthewpablo.com), licenza CC-BY 3.0."

### Effetti sonori (tutti CC0)

| Nome nel gioco | File originale | Titolo originale (raccolta) | Autore | Fonte | Licenza | Modifiche |
|---|---|---|---|---|---|---|
| `w_pistol` (pistola) | Walther PPQ/X_39P.wav | The Free Firearm Sound Library | The Free Firearm Sound Library (freefirearmsfx.com), caricato da bart | https://opengameart.org/content/the-free-firearm-sound-library | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | primo sparo, 0,75 s |
| `w_revolver` (revolver) | Smith & Wesson 642/V_27P.wav | The Free Firearm Sound Library | come sopra | come sopra | CC0 | primo sparo, 0,95 s |
| `w_smg` (mitraglietta) | Carl Gustav M45/G_31P.wav | The Free Firearm Sound Library | come sopra | come sopra | CC0 | primo sparo, 0,34 s |
| `w_shotgun` (fucile a pompa) | Nova/O_21P.wav | The Free Firearm Sound Library | come sopra | come sopra | CC0 | primo sparo, 1,25 s |
| `w_rifle` (fucile d'assalto) | AR-15/D_32P.wav | The Free Firearm Sound Library | come sopra | come sopra | CC0 | primo sparo, 0,55 s |
| `w_sniper` (cecchino) | Tikka/W_29P.wav | The Free Firearm Sound Library | come sopra | come sopra | CC0 | primo sparo, 1,7 s |
| `w_minigun` (minigun) | AK-47/C_28P.wav | The Free Firearm Sound Library | come sopra | come sopra | CC0 | primo sparo, 0,26 s, intonazione +8% |
| `eshot` (sparo nemico) | AK-47/C_31P.wav (media distanza) | The Free Firearm Sound Library | come sopra | come sopra | CC0 | primo sparo, 0,85 s |
| `esnipe` (cecchino nemico) | Mosin Nagant/M_26P.wav (media distanza) | The Free Firearm Sound Library | come sopra | come sopra | CC0 | primo sparo, 1,5 s |
| `pump` (pompa del fucile) | shotguncock_0.wav | Gun reload sounds | SpringySpringo | https://opengameart.org/content/gun-reload-sounds | CC0 | 0,47 s |
| `rel` (ricarica / cambio arma / otturatore) | gun_reload_lock_or_click_sound.mp3 | Gun reload, lock or click sound | pauliuw | https://opengameart.org/content/gun-reload-lock-or-click-sound | CC0 | 0,34 s |
| `boom` (esplosione) | Chunky Explosion.mp3 + lowFrequency_explosion_001.ogg | Chunky Explosion + Sci-Fi Sounds | Joth + Kenney | https://opengameart.org/content/chunky-explosion e https://opengameart.org/content/sci-fi-sounds | CC0 | esplosione tagliata a 2,6 s mescolata con un colpo basso (-5 dB) |
| `rocket` (lancio razzo, anche arma lanciarazzi) | launch.wav | Rocket launch | qubodup | https://opengameart.org/content/rocket-launch | CC0 | 1,3 s |
| `plasma` (lanciaplasma) | laserLarge_001.ogg | Sci-Fi Sounds | Kenney | https://opengameart.org/content/sci-fi-sounds | CC0 | 0,62 s |
| `zap` (laser / scarica) | laserSmall_001.ogg | Sci-Fi Sounds | Kenney | https://opengameart.org/content/sci-fi-sounds | CC0 | 0,24 s |
| `metal` (porte, saracinesche, robot) | metal_slam_01.ogg | 100 CC0 metal and wood SFX | rubberduck | https://opengameart.org/content/100-cc0-metal-and-wood-sfx | CC0 | 0,55 s |
| `crash` (cassa distrutta, urto) | wood_breaking_01.ogg | 100 CC0 metal and wood SFX | rubberduck | come sopra | CC0 | 0,55 s |
| `cover1`, `cover2` (colpi sul riparo) | metal_hit_01.ogg, metal_hit_03.ogg | 100 CC0 metal and wood SFX | rubberduck | come sopra | CC0 | 0,27 s e 0,36 s |
| `chest` (apertura baule) | lock_open_01.ogg | 100 CC0 metal and wood SFX | rubberduck | come sopra | CC0 | 0,72 s (suona insieme al jingle sintetizzato) |
| `ric1`, `ric2` (rimbalzo) | clink1_0.wav, clink3.wav | Metal Impact Sounds | BMacZero | https://opengameart.org/content/metal-impact-sounds | CC0 | 0,3 s (insieme al fischio sintetizzato) |
| `head` (colpo alla testa) | bing1.wav | Metal Impact Sounds | BMacZero | come sopra | CC0 | 0,45 s |
| colpo sordo dentro `hurt1`, `hurt2` | thud3.wav | Metal Impact Sounds | BMacZero | come sopra | CC0 | -7 dB, mescolato sotto il lamento |
| `step1..3` (passi) | metal_steps_01/04/05.wav | Metal footsteps on concrete | Thimras | https://opengameart.org/content/metal-footsteps-on-concrete | CC0 | 0,14 s ciascuno |
| `hurt1`, `hurt2` (giocatore ferito) | death pain grunts.wav (6,9 s e 29,8 s) | grunts of male death and pain | thebardofblasphemy | https://opengameart.org/content/grunts-male-death-and-pain | CC0 | due lamenti brevi estratti, con colpo sordo |
| `kill1`, `kill2` (nemico ucciso) | death pain grunts.wav (0,5 s e 36,0 s) | grunts of male death and pain | thebardofblasphemy | come sopra | CC0 | due rantoli estratti, 1,4 s |
| `pick` (raccolta, conferma) | confirmation_003.ogg | Interface Sounds | Kenney | https://opengameart.org/content/interface-sounds | CC0 | 0,32 s |
| `lose0` (QTE fallito) | error_003.ogg | Interface Sounds | Kenney | come sopra | CC0 | 0,45 s |
| `tele` (avviso di attacco) | beep_01.ogg | 50 CC0 Sci-Fi SFX | rubberduck | https://opengameart.org/content/50-cc0-sci-fi-sfx | CC0 | 0,3 s |
| `throw` (lancio granata, schivata) | swish-9.wav | Swishes Sound Pack | artisticdude | https://opengameart.org/content/swishes-sound-pack | CC0 | 0,2 s |
| `slow` (rallentamento) | phaserDown3.mp3 | 63 Digital sound effects | Kenney | https://opengameart.org/content/63-digital-sound-effects-lasers-phasers-space-etc | CC0 | 0,45 s |
| `win` (vittoria, arma mitica) | jingles_HIT01.ogg | 85 Short music jingles | Kenney | https://opengameart.org/content/85-short-music-jingles | CC0 | 0,6 s (insieme all'accordo sintetizzato) |
| `v_win` (voce a fine livello vinto) | Male/mission_completed.ogg | Voiceover Pack (40+ lines) | Kenney | https://opengameart.org/content/voiceover-pack-40-lines | CC0 | 1,3 s |
| `v_lose` (voce a fine livello perso) | Male/mission_failed.ogg | Voiceover Pack (40+ lines) | Kenney | come sopra | CC0 | 1,15 s |

### Suoni ancora sintetizzati
- `whiz` (proiettile che passa vicino): nessuna registrazione CC0/CC-BY adatta trovata.
- `secret` (nascondiglio scoperto): jingle sintetizzato.
- Strati sintetizzati aggiunti a `ric`, `chest`, `win`, `lose`.

