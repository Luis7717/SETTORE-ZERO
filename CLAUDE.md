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
- `www/index.html` — tutto il gioco in un solo file (~10 MB):
  - riga ~148: three.js (minificato) · righe ~150-4280: GLTFLoader / SkeletonUtils
  - riga ~4281: `const ASSET={...}` — modelli 3D .glb incorporati in base64 (**non aprirla per intero**: è 9,6 MB su una riga)
  - righe ~4283-fine: codice del gioco (campagna `LV`, nemici `ET`, armi `WT`/`RAR`/`TRAITS`, audio e musica sintetizzati con Web Audio, menu `MENU`/`drawHub`)
  - Salvataggio in `localStorage` (`load()`/`save()`).
- `App/main.swift` — involucro iOS: una WKWebView a schermo intero che carica `index.html`.
- `App/Info.plist`, icone `AppIcon60x60@2x/3x.png`.
- `.github/workflows/settore-zero-ipa.yml` — a ogni push su `main` compila con `swiftc` su macOS,
  firma "ad-hoc", crea `SettoreZero.ipa` e la pubblica nella release `settore-zero-ipa` (non firmata: TrollStore/Sideloadly/AltStore).
- Per leggere il codice del gioco senza gli asset: `sed -n '4283,$p' www/index.html`.
