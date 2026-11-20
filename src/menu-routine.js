// Allenamento del campione sullo sfondo del menu principale: sequenza che si ripete (palleggi, giochetto, corsa
// palla al piede, tiro, pallone nuovo che arriva rotolando). Funzione pura del tempo, senza grafica: la usa
// src/menu-bg.js e la provano i test in Node. Palleggi, giochetti e tiro sono movimenti calcolati (src/moves/*):
// la posa del corpo (frame) e il pallone con la fisica vera; la corsa resta quella del clip, col pallone che rimbalza.
// Riferimento: x = sinistra del giocatore, y = su, z = avanti (metri veri, prima della scala).
import { TRICKS } from './tricks.js';
import { juggleMove, BALL_R, BASE } from './moves/juggle.js';
import { trickMove, MENU_OPT } from './moves/tricks.js';
import { shotMove, rollInMove, SHOT_BALL } from './moves/shot.js';
import { qAxis } from './moves/vec.js';

export const RUN_T = 2.4;           // corsa sul posto palla al piede (clip)
export const RUN_V = 6.5;           // velocità finta della corsa (solo per l'animazione)
export const BLEND_T = 0.25;        // s: passaggio dalla posa calcolata alla corsa del clip e ritorno
export const FAR = 18;              // m: oltre, il pallone del tiro sparisce (è un puntino)
const RUN_STEP = 9;                 // rad/s: ritmo del pallone nella corsa

let M = null;
const moves = () => M || (M = { juggle: juggleMove(), shot: shotMove(), roll: rollInMove(), tricks: TRICKS.map(T => trickMove(T.id, MENU_OPT)) });
export const juggleTime = () => moves().juggle.T;
export function cycleLength(k) { const m = moves(); return m.juggle.T + m.tricks[k].T + RUN_T + m.shot.T + m.roll.T; }

// pallone nella corsa: parte da dove l'ha lasciato il giochetto, va avanti e rimbalza davanti ai piedi, finisce dove
// parte il tiro; ruota come rotola (angolo = strada / raggio)
function runBall(u) {
  const a = Math.min(1, u / 0.35), b = Math.min(1, (RUN_T - u) / 0.35), k = a * a * (3 - 2 * a), e = b * b * (3 - 2 * b);
  const z0 = BASE[2] + (0.75 - BASE[2]) * k, z = z0 + (SHOT_BALL[2] - z0) * (1 - e) + 0.15 * Math.sin(u * RUN_STEP) * k * e;
  const h = BALL_R + 0.05 * Math.abs(Math.sin(u * RUN_STEP)) * k * e;
  return { p: [0, h, z], q: qAxis([1, 0, 0], (z - BASE[2]) / BALL_R), vis: true };
}

// t = secondi dall'inizio; ogni giro usa il giochetto successivo.
// Ritorna { seg, vx, frame (posa calcolata o null), w (quanto pesa la posa calcolata sul clip), ball {p, q, vis}, cycle, trick }
export function menuRoutine(t) {
  const m = moves();
  let k = 0, u = Math.max(0, t);
  while (u >= cycleLength(k)) { u -= cycleLength(k); k = (k + 1) % TRICKS.length; }
  const out = (seg, mv, tt, extra) => { const fr = mv.at(tt); return { seg, vx: 0, frame: fr, w: 1, ball: fr.ball, cycle: k, trick: null, ...extra }; };
  if (u < m.juggle.T) return out('juggle', m.juggle, u);
  u -= m.juggle.T;
  const tr = m.tricks[k];
  if (u < tr.T) return out('trick', tr, u, { trick: { id: TRICKS[k].id, q: u / tr.T, side: 1 } });
  u -= tr.T;
  if (u < RUN_T) {
    // corsa del clip; all'inizio e alla fine la posa calcolata (fine del giochetto, inizio del tiro) sfuma
    const wIn = Math.max(0, 1 - u / BLEND_T), wOut = Math.max(0, 1 - (RUN_T - u) / BLEND_T);
    const frame = wIn > 0 ? tr.at(tr.T) : wOut > 0 ? m.shot.at(0) : null;
    return { seg: 'run', vx: RUN_V, frame, w: Math.max(wIn, wOut), ball: runBall(u), cycle: k, trick: null };
  }
  u -= RUN_T;
  if (u < m.shot.T) {
    const o = out('shot', m.shot, u);
    o.ball.vis = o.ball.p[2] < FAR;
    return o;
  }
  u -= m.shot.T;
  return out('rest', m.roll, u);
}
