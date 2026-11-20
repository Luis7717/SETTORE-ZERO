# Tiro a Giro

Gioco di calcio 3D in verticale per iPhone, giocabile con un dito solo.
Disegni col dito passaggi e tiri (anche a giro), difendi a mano e fai carriera
con la tua squadra: campionato a tre divisioni, rosa, mercato.

- `www/index.html` — codice e menu del gioco (offline); `www/assets/` — modelli, texture e audio caricati a pezzi
- `src/` — sorgenti: `sim.js` motore partita, `render.js` grafica 3D, `input.js` comandi,
  `career.js` campionato e mercato, `ui.js` menu, `editor.js` editor di stemma e campione,
  `looks.js` aspetto dei giocatori e stile della divisa, `crest.js` stemmi, `main.js` collegamento
- `build.mjs` — ricostruisce `www/` dai sorgenti (`npm install` e poi `npm run build`);
  `npm run build:single` crea `dist/tiro-a-giro.html`, una versione a file unico solo per provarla nel browser
- `App/` — involucro iOS (WKWebView a schermo intero che serve `www/` su `app://`), icona e Info.plist
- `.github/workflows/tiro-a-giro-ipa.yml` — compila l'IPA a ogni push sul ramo `tiro-a-giro`
- `test/` — partite automatiche e prove su schermo a misura iPhone

L'IPA compilata si trova nella release **Tiro a Giro (IPA)** del repository
(o tra gli artifact della build). Non è firmata: installala con TrollStore,
Sideloadly o AltStore.

## Comandi

- **Passaggi e tiri**: appoggia il dito sul giocatore con la palla e disegna la traiettoria.
  Il tempo rallenta mentre disegni. Linea curva = palla a giro. Linea che finisce in porta = tiro.
- **Correre**: tieni premuto un punto del campo. Tocco su un compagno = passaggio diretto.
- **Difesa**: tieni premuto per muovere il difensore con l'anello giallo; tocca un compagno per cambiare.
- **Scivolata**: scorri veloce. Palla presa = pulita; uomo preso prima = fallo; da dietro = cartellino.
- **Portiere**: quando tirano, scorri verso il lato del tiro (verso l'alto per i tiri alti).

## Note

Squadre, giocatori e sponsor sono inventati. Grafica 3D con three.js (licenza MIT).
Modello dei giocatori: Quaternius, "Universal Base Characters" (corpo e occhi) e "Universal Animation Library"
(animazioni), entrambi CC0 (https://quaternius.com), adattati con `tools/make-athlete.mjs`. Modello di riserva se il primo
non si carica: Kenney, "Animated Characters: Protagonists" (CC0, https://kenney.nl). Capelli, viso, maglie, numeri e
stemmi sono disegnati dal codice del gioco (`src/athlete3d.js`, `src/players3d.js`, `src/hair3d.js`, `src/crest.js`).
All'inizio di una carriera si sceglie lo stemma della squadra e si crea il proprio campione (viso, occhi, capelli, divisa);
l'aspetto di ogni giocatore si cambia dalla Rosa ("Aspetto"), stile della divisa e stemma dalle Impostazioni.
Suoni: Freesound, tutti CC0 (autori e link in `assets/CREDITI.md`).

## Scarica

L'IPA più recente è sempre qui: https://github.com/Luis7717/settore-zero/releases/tag/tiro-a-giro-ipa

Questo ramo è provvisorio e indipendente da Settore Zero: contiene solo Tiro a Giro.
