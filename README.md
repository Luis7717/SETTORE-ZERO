# Settore Zero

Sparatutto 3D in verticale per iPhone, giocabile con un dito solo.
Questo ramo è indipendente da Forge: contiene solo il gioco e la build dell'IPA.

- `www/` — il gioco (funziona offline): `index.html` carica in ordine
  `css/style.css`, `lib/` (three.js e caricatori), `assets/` (modelli 3D .glb e audio .mp3, caricati a pezzi quando servono) e `js/` (codice del gioco)
- `App/` — involucro iOS (WKWebView a schermo intero con schema `app://`), icona e Info.plist
- `tools/estrai-asset.js` — converte i vecchi modelli/suoni in base64 nei file di `www/assets/`
- `.github/workflows/settore-zero-ipa.yml` — compila l'IPA a ogni push

L'IPA compilata da `main` si trova nella release **Settore Zero (IPA)** del repository
(o tra gli artifact della build); quella di un altro branch nella release
`settore-zero-ipa-<branch>`. Non è firmata: installala con TrollStore,
Sideloadly o AltStore.

Per provarlo sul computer: avvia `python -m http.server` dentro `www/` e apri http://127.0.0.1:8000

## Crediti

L'elenco completo di modelli, texture, suoni e musiche, con autori e licenze, è in [CREDITS.md](CREDITS.md).

- Musica: *Tactical Pursuit* e *Space Boss Battle Theme* di Matthew Pablo (www.matthewpablo.com), CC-BY 3.0
- «Space Ship Hallway» di yeeyeeman (Sketchfab), CC-BY 4.0
- Armi, barile e texture nuovi: Poly Haven e OpenGameArt (CC0); suoni: The Free Firearm Sound Library, Kenney e altri (CC0)

## Scarica

L'IPA più recente è sempre qui: https://github.com/Luis7717/settore-zero/releases/tag/settore-zero-ipa
