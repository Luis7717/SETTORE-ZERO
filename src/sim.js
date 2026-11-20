// Motore partita: nessuna dipendenza grafica, gira anche in Node per i test.
// Coordinate: x = larghezza (-HW..HW), y = lunghezza (-HL..HL), h = altezza.
// La squadra 0 attacca verso +y, la squadra 1 verso -y.
// Il codice vive in src/sim/: core.js (costanti, fisica), ai.js, motion.js, match.js.
export { W, L, HW, HL, GW, GH, BOX_W, BOX_D, SIX_W, SIX_D, PEN_D, CIRCLE, rng32, FORMATIONS, effStats, headingOf, ballPhys } from './sim/core.js';
export { Match, SPRINT_DIST } from './sim/match.js';
export { DUEL_R, DUEL_GUARD, DUEL_MAX, ZONE_DIST } from './sim/duel.js';
