# Lavoro in parallelo

Coordinatore: sessione principale (Opus), che integra i risultati nei file comuni
(`main.js`, `render.js`, `build.mjs`, `index.tpl.html`) uno alla volta.
Nessun limite fisso al numero di subagenti insieme (Luis, 2026-11-20): se ne usano quanti servono, uno per pezzo indipendente. Nel repo entra solo il materiale scelto dal coordinatore.
I subagenti che modificano file lavorano in un worktree proprio, creato dal ramo `gioco2`
(l'isolamento automatico creava i worktree dal repo principale, cioè da Settore Zero: non va usato).

## Blocco 1 — preparazione Fase 2 (iniziato 2026-11-19)

Il 2026-11-19 Luis ha chiesto di fare **prima e da solo** il caricamento a pezzi: niente integrazioni di contenuti
nuovi finché quel blocco non è finito e la build su GitHub non è riuscita. La Fase 1B (motore) è in pausa fino ad allora.

| # | Compito | Modello | Stato | File toccati |
|---|---------|---------|-------|--------------|
| 0 | Caricamento a pezzi (www/assets, schema app://, recupero salvataggio, build a file unico) | Opus (coordinatore) + revisione code-reviewer | fatto, build GitHub riuscita su 896134b (entrambi i Mac) | `build.mjs`, `src/assets.js`, `src/legacy-save.js`, `src/main.js`, `src/audio.js`, `src/index.tpl.html`, `App/main.swift`, `App/legacy.html`, workflow, test |
| 1 | Ricerca modelli 3D (giocatore animato, palla) CC0/CC-BY | Sonnet | finita: 3 candidati (Kenney Character Assets, KayKit, Sketchfab KidBi-Gaming), da scegliere | nessuno |
| 2 | Ricerca musiche ed effetti sonori CC0/CC-BY | Sonnet | finita: 3 candidati Freesound CC0 (pubblico Millerntor, fischi/calcio, musica "Race song loop"), scelti 7 suoni, integrati (`assets/audio/`, crediti in `assets/CREDITI.md`) | nessuno |
| 3 | Grafica dello stadio | Opus | finita, commit `46f6441` sul ramo `stadio-grafica` (7-9 draw call, ~15.500 triangoli), integrato | `src/stadium.js`, `test/stadium-shot.mjs` |
| 4 | Grafica dei menu | Sonnet | finita, commit `a1e4df8` sul ramo `wt-menu` (worktree `TAG-wt-menu`), integrato | `src/ui.js`, `src/ui-style.js` |
| 5 | Fase 1B motore: scatto, finta, testa/volée, barriera, vantaggio, difficoltà | Opus | finita e unita (8 commit, 60 test verdi); eventi a schermo e testi integrati dal coordinatore | `src/sim/*`, `src/input.js`, `src/career.js`, `test/**` |
| 6 | Modelli 3D dei giocatori (Kenney/KayKit), animazioni e pose | Opus | finita e integrata (commit 2472f9d: Kenney CC0, 720 triangoli, draw call da ~180 a ~55) | `src/players3d.js`, `assets/models/`, poche righe di `src/render.js` |
| 7 | Allenamento guidato (tutorial in campo, 5 prove) | Opus (coordinatore) | fatto | `src/tutorial.js`, `src/main.js`, `src/ui.js`, `src/index.tpl.html`, `test/unit/tutorial.test.mjs`, `test/tutorial-shot.mjs` |
| 8 | Duello col difensore, dribbling, colpi di testa (`tes`), cali durante la partita (motore) | Opus | finita e unita (commit 0414df7, 13 test nuovi) | `src/sim/duel.js`, `src/sim/*`, `src/career.js`, `test/**` |
| 9 | Duello lato schermo, allenamento a schede con 3 prove, statistiche RES/TES nelle schede | Opus (coordinatore) | fatto | `src/render.js`, `src/main.js`, `src/tutorial.js`, `src/ui.js`, `src/ui-style.js`, `src/index.tpl.html`, test a schermo |
| 10 | Corsa a strada, parata con linea, difesa a linee per tutti, raggio di intercetto | Opus (coordinatore) | fatto | `src/sim/*`, `src/input.js`, `src/render.js`, `src/main.js`, `src/tutorial.js`, `src/ui.js`, test |
| 11 | Giocatori molto più dettagliati + editor "Crea il tuo campione" (occhi, capelli, divisa, calzettoni) | Opus | finita e unita (commit a70e15a: 17 tagli, stemmi 10×10×20, nome e numero sulla schiena, 92 test) | `src/players3d.js`, `src/career.js`, `src/ui.js`, `src/ui-style.js`, file nuovi, `assets/**` |

## 12 — Capelli e grafica (2026-11-20) · Opus · FATTO, unito
- Worktree `TAG-wt-gfx`, ramo `wt-gfx`, commit `0aa1784`. File: `src/hair3d.js` (nuovo), `src/players3d.js`, `src/render.js`
  (campo, luci, tonemapping, ombre), `src/stadium.js`, `test/unit/hair.test.mjs`, `test/hair-shot.mjs`.
- 17 tagli rifatti come calotte lisce dipinte (stessi indici: salvataggi validi). Triangoli scena circa 41k → 50k, draw call invariati (57).

## 13-16 — Grafica in stile più realistico, a pezzi (2026-11-20) · tutti Opus · FATTO, tutti uniti
| # | Pezzo | Worktree / ramo | File |
|---|---|---|---|
| 13 | Giocatori: modello con proporzioni realistiche, divise, capelli, pose, editor | `TAG-wt-gfx2` / `wt-gfx2` | `players3d.js`, `hair3d.js`, `editor.js`, `assets/models` |
| 14 | Campo: erba, luci, tonemapping, ombre vere — FATTO, unito (`ad4cffa`) | `TAG-wt-campo` / `wt-campo` | nuovo `pitch.js`, `render.js` |
| 15 | Stadio, pubblico, bandiere, cartelloni | `TAG-wt-stadio` / `wt-stadio` | `stadium.js` |
| 16 | Pallone, porte e rete, bandierine, effetti, linee disegnate | `TAG-wt-effetti` / `wt-effetti` | nuovo `props.js`, chiamate in `render.js` |
Telecamera: la tengo io. L'unione in `gioco2` la faccio io, un pezzo alla volta, con test e schermate dopo ognuno.
- Uniti in `gioco2`: 14 campo `ad4cffa`, 13 giocatori `9661147` (Quaternius Universal Base Characters, CC0, `assets/models/athlete.glb` 656 KB, ripiego sul Kenney),
  16 pallone/porte/effetti `9ccc115` (`src/props.js`), 15 stadio `dcb131d` (`stadium*.js`). Conflitti solo negli import e nella telecamera di `render.js`, risolti a mano.

## 17-20 — Rifinitura del corpo a parti, sulle proporzioni di `PROPORZIONI.md` (2026-11-20) · tutti Opus
Il terminale si è chiuso a metà (un'altra sessione ha chiuso processi per nome). Recupero del 2026-11-20:
| # | Parte | Worktree / ramo | Stato | File |
|---|---|---|---|---|
| 17 | Busto, spalle, braccia, mani | `TAG-wt-busto` / `wt-busto` | unito (`bc6e6ff`) | `src/body/busto.js`, `test/unit/busto.test.mjs`, `test/busto-shot.mjs` |
| 18 | Bacino, gambe, piedi | `TAG-wt-gambe` / `wt-gambe` | lavoro non salvato ma finito e verde: salvato (`781d30f`) e unito; test aggiornato per confrontare col modello con busto e testa | `src/body/gambe.js`, `test/unit/gambe.test.mjs`, `test/legs-shot.mjs` |
| 19 | Testa, viso, collo | `TAG-wt-testa` / `wt-testa` | come sopra (`68e50ed`), unito (`f50795a`) | `src/body/testa.js`, `test/unit/head.test.mjs`, `test/head-measure.mjs` |
| 20a | Braccia nascoste dietro il busto da fermo (difetto del 17) | `TAG-wt-braccia` / `wt-braccia` | fatto: stessa causa del 20b, resta solo il test della posa (`827c427`), unito | `src/body/busto.js` |
| 20b | Macchia color pelle sui pantaloncini (difetto del 18) | `TAG-wt-macchia` / `wt-macchia` | fatto (`a739d31`, unito `f9f41e2`): erano le dita che bucavano i pantaloncini; corretto `IDLE_FIX.arms` in `src/athlete3d.js` | `src/body/gambe.js` |
Limite di 2 subagenti insieme tolto più tardi lo stesso giorno (richiesta di Luis): vedi in cima.

## 21-24 — Prove di Luis sull'iPhone (2026-11-20) · Opus
| # | Compito | Worktree / ramo | Stato |
|---|---|---|---|
| 21 | Forme degli occhi visibili | `TAG-wt-occhi` / `wt-occhi` | fatto (`3ac24cf`), unito |
| 22 | Telecamera: porta intera in parata, visuale larga nel rallenty (`src/camfit.js`) | `TAG-wt-camera` / `wt-camera` | fatto (`5ce3685`), unito |
| 23 | Motore: difesa che rientra e pressa, attacco largo, linee di difesa corte, contrasto magnetico, intercetto, scatto | `TAG-wt-tattica` / `wt-tattica` | fatto (`6564220`), unito |
| 25 | Schermata Rosa sul campo con carte, panchina e confronto | `TAG-wt-rosa` / `wt-rosa` | fatto (`5056553`), unito |
| 26 | Palleggio e giochetti con fisica e IK | `TAG-wt-anim` / `wt-anim` | in corso |
| 27 | Ricerca animazioni CC0/CC-BY | nessuno (solo ricerca) | fatto: UAL2 senza calcio; pack Soccer di Anderson Rohr confermato da Luis |
| 28 | three.js in un file separato (index.html sotto 1 MB) | `TAG-wt-split` / `wt-split` | fatto (`824c3b8`), unito |
| 24 | Menu principale col campione che si allena; menu opachi senza color-mix | coordinatore, in `gioco2` | fatto |
