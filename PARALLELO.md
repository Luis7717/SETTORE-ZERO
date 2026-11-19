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
| 5 | Fase 1B motore: scatto, finta, testa/volée, barriera, vantaggio, difficoltà | Opus | in corso (worktree `TAG-wt-1b`, ramo `wt-1b`) | `src/sim/*`, `src/input.js`, `src/career.js`, `test/**` |
| 6 | Modelli 3D dei giocatori (Kenney/KayKit), animazioni e pose | Opus | in corso (worktree `TAG-wt-modelli`, ramo `wt-modelli`) | `src/players3d.js`, `assets/models/`, poche righe di `src/render.js` |
