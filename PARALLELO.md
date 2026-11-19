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
| 0 | Caricamento a pezzi (www/assets, schema app://, recupero salvataggio, build a file unico) | Opus (coordinatore) | fatto, in attesa della build GitHub | `build.mjs`, `src/assets.js`, `src/legacy-save.js`, `src/main.js`, `src/audio.js`, `src/index.tpl.html`, `App/main.swift`, `App/legacy.html`, workflow, test |
| 1 | Ricerca modelli 3D (giocatore animato, palla) CC0/CC-BY | Sonnet | finita: 3 candidati (Kenney Character Assets, KayKit, Sketchfab KidBi-Gaming), da scegliere | nessuno |
| 2 | Ricerca musiche ed effetti sonori CC0/CC-BY | Sonnet | finita: 3 candidati Freesound CC0 (pubblico Millerntor, fischi/calcio, musica "Race song loop"), da scegliere | nessuno |
| 3 | Grafica dello stadio | Opus | in corso, worktree `stadio-grafica` | `src/stadium.js`, `test/stadium-shot.mjs` |
| 4 | Grafica dei menu | Sonnet | finita, commit `a1e4df8` sul ramo `wt-menu` (worktree `TAG-wt-menu`), da integrare dopo la build | `src/ui.js`, `src/ui-style.js` |
| 5 | Fase 1B motore: scatto, finta, testa/volée, barriera, vantaggio, difficoltà | Opus | in pausa | — |
