// Allenamento del campione sullo sfondo del menu principale: sequenza che si ripete (palleggi, giochetto, corsa
// palla al piede, tiro). Funzione pura del tempo, senza grafica: la usa src/menu-bg.js e la provano i test in Node.
// Il pallone è dato rispetto al giocatore: f = avanti, s = di lato, h = altezza (metri veri, prima della scala).
import { TRICKS, ballOffset } from './tricks.js';

export const JUGGLE_T = 7;          // secondi di palleggi
export const TOUCH_T = 0.55;        // tempo tra due tocchi
export const TRICK_SLOW = 1.6;      // i giochetti al menu vanno più piano che in partita (si vedono meglio)
export const RUN_T = 2.4;           // corsa sul posto palla al piede
export const RUN_V = 6.5;           // velocità finta della corsa (solo per l'animazione)
export const SHOT_T = 0.35;         // calcio (come kickAnim del motore)
export const REST_T = 1.4;          // pausa dopo il tiro, senza pallone
const PEAKS = [0.75, 0.6, 0.95, 0.7, 0.85, 0.65, 1.05, 0.7, 0.8, 0.6, 0.9, 0.75, 0.7]; // altezze dei palleggi (m)
const FOOT_H = 0.22, FOOT_F = 0.32;

const trickDur = k => TRICKS[k].dur * TRICK_SLOW;
export function cycleLength(k) { return JUGGLE_T + trickDur(k) + RUN_T + SHOT_T + REST_T; }

// t = secondi dall'inizio; ogni giro usa il giochetto successivo
export function menuRoutine(t) {
  let k = 0, u = Math.max(0, t);
  while (u >= cycleLength(k)) { u -= cycleLength(k); k = (k + 1) % TRICKS.length; }
  const out = { seg: '', vx: 0, kickAnim: 0, trick: null, leg: null, ball: { f: FOOT_F, s: 0, h: FOOT_H, visible: true }, cycle: k };
  if (u < JUGGLE_T) {
    // palleggi: il pallone sale e scende tra un tocco e l'altro, piede alternato; la gamba si alza sul tocco
    const n = Math.floor(u / TOUCH_T), q = u / TOUCH_T - n, side = n % 2 ? -1 : 1, peak = PEAKS[n % PEAKS.length];
    out.seg = 'juggle';
    out.ball = { f: FOOT_F, s: 0.1 * side, h: FOOT_H + peak * 4 * q * (1 - q), visible: true };
    const near = Math.min(q, 1 - q) * TOUCH_T; // tempo dal tocco più vicino
    out.leg = { side: q < 0.5 ? side : -side, lift: Math.max(0, 1 - near / 0.16) };
    return out;
  }
  u -= JUGGLE_T;
  if (u < trickDur(k)) {
    const q = u / trickDur(k), o = ballOffset(TRICKS[k].id, q);
    out.seg = 'trick'; out.trick = { id: TRICKS[k].id, q, side: 1 };
    out.ball = { f: FOOT_F + o.f, s: o.s, h: FOOT_H * 0.5 + o.h, visible: true };
    return out;
  }
  u -= trickDur(k);
  if (u < RUN_T) {
    out.seg = 'run'; out.vx = RUN_V;
    out.ball = { f: 0.75 + 0.15 * Math.sin(u * 9), s: 0, h: 0.11 + 0.05 * Math.abs(Math.sin(u * 9)), visible: true };
    return out;
  }
  u -= RUN_T;
  if (u < SHOT_T) {
    out.seg = 'shot'; out.kickAnim = SHOT_T - u;
    out.ball = { f: 0.5, s: 0, h: 0.11, visible: true };
    return out;
  }
  // dopo il tiro: il pallone vola via davanti e sparisce, il giocatore resta fermo
  u -= SHOT_T;
  out.seg = 'rest';
  const fly = u * 22, a = u / REST_T;
  out.ball = { f: 0.5 + fly, s: 0, h: 0.11 + 12 * a * (1 - a), visible: fly < 30 };
  return out;
}
