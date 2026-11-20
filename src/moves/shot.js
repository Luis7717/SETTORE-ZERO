// Tiro del campione sullo sfondo del menu, e pallone nuovo che arriva rotolando per i palleggi del giro dopo.
// Tiro: passo col sinistro accanto al pallone, destro indietro, collo pieno (piede disteso) sul dietro del pallone,
// accompagnamento. Il pallone parte con la velocità del tiro e vola con la gravità vera (ed effetto all'indietro).
import { Move, footQ, G } from './core.js';
import { FOOT_PTS } from './body.js';
import { add, sub, mul, qRot } from './vec.js';
import { BALL_R, BASE, STANCE, PELVIS } from './juggle.js';

export const SHOT_BALL = [0, BALL_R, 0.62];    // dove la corsa lascia il pallone prima del tiro
const SHOT_V = [0.4, 5.2, 21];                 // m/s: velocità del pallone appena calciato
const SHOT_SPIN = [-14, 0, 0];                 // rad/s: effetto all'indietro
const T_HIT = 0.56, T_END = 1.05;              // s: contatto, fine del gesto
const FLY_T = 2 * SHOT_V[1] / G;               // s: volo fino a ritoccare terra (lontano, ormai invisibile)
const DRIVE_FQ = footQ(0, 1.07);               // piede disteso: la normale del collo guarda avanti

export function shotMove(R = BALL_R) {
  const m = new Move(R), B = SHOT_BALL, pl = [0.2, B[2] - 0.12];
  // gambe: sinistro a terra accanto al pallone, destro indietro e poi a colpire
  m.leg('l', { t: 0, plant: STANCE.l }).leg('l', { t: 0.08, plant: STANCE.l });
  m.leg('l', { t: 0.22, ankle: [0.18, 0.2, 0.25], fq: footQ(0, 0.2) });
  m.leg('l', { t: 0.38, plant: pl, yaw: -0.15 }).leg('l', { t: T_END, plant: pl, yaw: -0.15 });
  const hitAt = sub(B, mul(qRot(DRIVE_FQ, FOOT_PTS.instep.n), R));
  m.leg('r', { t: 0, plant: STANCE.r }).leg('r', { t: 0.2, plant: STANCE.r });
  m.leg('r', { t: 0.4, ankle: [-0.13, 0.5, -0.32], fq: footQ(0, 0.9), pole: [0, -0.2, 1] });
  m.leg('r', { t: T_HIT, part: 'instep', at: hitAt, fq: DRIVE_FQ, v: [0.1, 1.2, 6.5] });
  m.leg('r', { t: T_HIT + 0.16, ankle: [-0.02, 0.62, 0.95], fq: footQ(0, 0.6) });
  m.leg('r', { t: T_END, plant: [-0.12, 0.52] });
  m.touch(T_HIT, 'r.instep');
  // bacino: avanti sopra il piede d'appoggio, giro col destro indietro e poi avanti
  m.pelvis(0, PELVIS).pelvis(0.38, [0.06, 0.91, 0.18], 0.3, 0.05, 0.08).pelvis(T_HIT, [0.06, 0.9, 0.26], -0.1, 0.08, 0.1);
  m.pelvis(T_HIT + 0.2, [0.03, 0.93, 0.38], -0.3, 0.02, 0.02).pelvis(T_END, [0, 0.93, 0.3], -0.1);
  m.bend(0, [0.16, 0, 0]).bend(T_HIT, [0.22, 0.12, -0.1]).bend(T_END, [0.05, 0, 0]);
  m.arm('l', 0, [0.2, -0.5, 0.05]).arm('l', T_HIT, [0.55, -0.1, 0.15]).arm('l', T_END, [0.3, -0.4, 0.05]);
  m.arm('r', 0, [0.2, -0.5, 0.05]).arm('r', T_HIT, [0.3, -0.35, -0.2]).arm('r', T_END, [0.3, -0.4, 0.05]);
  // pallone: fermo, poi il volo del tiro
  m.ballRest(0, T_HIT, B);
  const T = FLY_T, p1 = [B[0] + SHOT_V[0] * T, B[1] + SHOT_V[1] * T - G * T * T / 2, B[2] + SHOT_V[2] * T];
  m.ballFly(T_HIT, T_HIT + T, B, p1, SHOT_SPIN);
  return m.done(Math.max(T_END, T_HIT + T));
}
export const SHOT_END = T_END;

// pallone nuovo che arriva rotolando da dietro a destra e si ferma davanti ai piedi (decelerazione costante);
// intanto il giocatore torna fermo nella posizione dei palleggi
const ROLL_FROM = [-2.6, BALL_R, -1.2], ROLL_T = 1.7;
export function rollInMove(R = BALL_R, from = { l: [0.2, 0.5], r: [-0.12, 0.52], pelvis: [0, 0.93, 0.3] }) {
  const m = new Move(R), T = ROLL_T, B = [0, R, BASE[2]];
  m.leg('l', { t: 0, plant: from.l }).leg('l', { t: 0.15, plant: from.l }).leg('l', { t: 0.45, ankle: [0.16, 0.18, 0.25], fq: footQ(0, 0.2) }).leg('l', { t: 0.7, plant: STANCE.l });
  m.leg('r', { t: 0, plant: from.r }).leg('r', { t: 0.55, plant: from.r }).leg('r', { t: 0.8, ankle: [-0.13, 0.18, 0.3], fq: footQ(0, 0.2) }).leg('r', { t: 1.05, plant: STANCE.r });
  m.leg('l', { t: T, plant: STANCE.l }).leg('r', { t: T, plant: STANCE.r });
  m.pelvis(0, from.pelvis, -0.1).pelvis(0.7, [0.03, 0.93, 0.1]).pelvis(1.1, PELVIS).pelvis(T, PELVIS);
  m.bend(0, [0.05, 0, 0]).bend(T, [0.16, 0, 0]);
  m.arm('l', 0, [0.3, -0.4, 0.05]).arm('r', 0, [0.3, -0.4, 0.05]).arm('l', T, [0.2, -0.5, 0.05]).arm('r', T, [0.2, -0.5, 0.05]); // braccia come alla fine del tiro
  m.ballRoll(0, T, ROLL_FROM, B, mul(sub(B, ROLL_FROM), 2 / T), [0, 0, 0]);
  return m.done(T);
}
