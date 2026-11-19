# Settore Zero

Sparatutto 3D in verticale per iPhone, giocabile con un dito solo.
Questo ramo è indipendente da Forge: contiene solo il gioco e la build dell'IPA.

- `www/` — il gioco (funziona offline): `index.html` carica in ordine
  `css/style.css`, `lib/` (three.js e caricatori), `models/` (modelli 3D) e `js/` (codice del gioco)
- `App/` — involucro iOS (WKWebView a schermo intero), icona e Info.plist
- `.github/workflows/settore-zero-ipa.yml` — compila l'IPA a ogni push

L'IPA compilata da `main` si trova nella release **Settore Zero (IPA)** del repository
(o tra gli artifact della build); quella di un altro branch nella release
`settore-zero-ipa-<branch>`. Non è firmata: installala con TrollStore,
Sideloadly o AltStore.

Per provarlo sul computer: avvia `python -m http.server` dentro `www/` e apri http://127.0.0.1:8000

## Crediti dei modelli 3D

- Soldato: personaggio Mixamo, dagli esempi di three.js
- «Space Ship Hallway» di yeeyeeman (Sketchfab), licenza CC-BY 4.0
- Barile: dagli asset di Babylon.js, licenza CC-BY 4.0
- Armi e granata: pacchetto «Guns & Explosives» di 3DModelsCC0, licenza CC0
- Androide «Xbot» (Mixamo) e robot «RobotExpressive» di Tomás Laulhé / Quaternius (CC0), dagli esempi three.js

## Scarica

L'IPA più recente è sempre qui: https://github.com/Luis7717/settore-zero/releases/tag/settore-zero-ipa
