# Lavoro in parallelo

Coordinatore: sessione principale (Opus), che integra i risultati nei file comuni
(`main.js`, `render.js`, `build.mjs`, `index.tpl.html`) uno alla volta.
Massimo quattro subagenti insieme. Nel repo entra solo il materiale scelto dal coordinatore.
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
