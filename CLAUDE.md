# Settore Zero — regole del progetto

## Come lavorare con Luis
- Parla sempre in **italiano**, in modo semplice.
- Prima di modifiche grosse spiega il piano in breve e aspetta l'ok.
- Dopo ogni modifica che funziona: **commit e push su GitHub** (ramo `main`), così parte la compilazione dell'IPA.

## Il gioco
- FPS a **schermo verticale per iPhone**, stile Time Crisis, distribuito come **IPA compilato con GitHub Actions**.
- **Una mano sola, a tocco**: si spara dove si tocca, il mirino sta leggermente sopra il dito.
  Senza tocco il personaggio resta **al riparo**; quando tocco esce e spara.
  Deve esserci un **avviso danni** (es. laser di mira, suono) per ripararsi in tempo.
- **Schivate con slider**: toccare lo slider **non** deve far uscire dal riparo né sparare.
- **40-50 livelli fissi** (non casuali), una sola trama, scene tipo mini-video (fughe da esplosioni, inseguimenti).
  Percorsi poco lineari, mappe e corridoi articolati, gameplay tattico.
- **Solo due armi principali** tra cui scegliere. **Rarità colorate**: più è alta più l'arma è "figa",
  con abilità assurde al grado **mitico**. Crediti, potenziamenti permanenti, casse e bauli segreti.
- Grafica il più realistica possibile: modelli 3D realistici da fonti gratuite con **licenza adatta**
  (CC0 / CC-BY, da citare nel README), fisica credibile (niente oggetti attraversati), tanti tipi di nemici,
  tempi di sparo credibili, suoni realistici, una musica per i livelli e una speciale per i boss, menu accattivante.

## Bug noti da controllare sempre
- Nemici incastrati nei ripari che vibrano senza sparare.
- Nemici dietro i muri che non si possono colpire.

## Struttura tecnica
- `www/` — il gioco (three.js, JavaScript), caricato nell'ordine scritto in `www/index.html`:
  - `index.html` — solo struttura della pagina e lista degli script (l'**ordine conta**)
  - `css/style.css` — stile di menu e HUD
  - `lib/three.min.js` (three.js), `lib/loaders.js` (GLTFLoader, SkeletonUtils)
  - `models/*.js` — un modello 3D per file: `ASSET.nome="<glb in base64>";` (**non aprirli**: sono enormi)
  - `js/*.js` — codice del gioco, script classici (niente moduli) che condividono le variabili globali:
    `dati` (trama, 45 livelli `LV`, armi `WT`/`RAR`/`TRAITS`, salvataggio `localStorage`), `audio` (suoni e musica sintetizzati),
    `grafica`, `definizioni` (nemici `ET`, armi), `livelli`, `nemici` (IA), `combattimento`, `comandi` (tocco, slider),
    `aggiornamento` (ciclo di gioco), `hud`, `colossi` (boss), `modelli`, `corridoi`, `sale`, `menu` (avvio del gioco, va per ultimo)
  - Attenzione: alcune funzioni sono ridefinite in file successivi (es. `buildRun`, `runHaz`, `escFx` in `corridoi.js`): vale l'ultima.
- `App/main.swift` — involucro iOS: una WKWebView a schermo intero che carica `index.html` (può leggere tutta la cartella).
- `App/Info.plist`, icone `AppIcon60x60@2x/3x.png`.
- `.github/workflows/settore-zero-ipa.yml` — a ogni push compila con `swiftc` su macOS, copia tutta `www/` nell'app,
  firma "ad-hoc" e crea `SettoreZero.ipa` (non firmata: TrollStore/Sideloadly/AltStore).
  Release: da `main` → `settore-zero-ipa`; da un altro branch → `settore-zero-ipa-<branch>` (non tocca quella di main).
- Per provare in locale: `python -m http.server` dentro `www/` e apri `http://127.0.0.1:8000`.
