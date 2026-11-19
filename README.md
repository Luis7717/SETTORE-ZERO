# Tiro a Giro

Gioco di calcio 3D in verticale per iPhone, giocabile con un dito solo.
Disegni col dito passaggi e tiri (anche a giro), difendi a mano e fai carriera
con la tua squadra: campionato a tre divisioni, rosa, mercato.

- `www/index.html` — codice e menu del gioco (offline); `www/assets/` — modelli, texture e audio caricati a pezzi
- `src/` — sorgenti: `sim.js` motore partita, `render.js` grafica 3D, `input.js` comandi,
  `career.js` campionato e mercato, `ui.js` menu, `main.js` collegamento
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
Modello dei giocatori: Kenney, "Animated Characters: Protagonists" (CC0, https://kenney.nl).
Suoni: Freesound, tutti CC0 (autori e link in `assets/CREDITI.md`).

## Scarica

L'IPA più recente è sempre qui: https://github.com/Luis7717/settore-zero/releases/tag/tiro-a-giro-ipa

Questo ramo è provvisorio e indipendente da Settore Zero: contiene solo Tiro a Giro.
