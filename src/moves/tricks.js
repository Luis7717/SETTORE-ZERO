// I sei giochetti del dribbling come movimenti calcolati: il pallone lo muove il piede (contatto vero: il punto del
// piede è sul pallone quando lo spinge), a terra rotola, in aria vola con la gravità vera.
// opt = { R raggio del pallone, B pallone fermo all'inizio e alla fine, k lentezza dei gesti (i voli no: quelli li
// decide la gravità), match = in partita (finisce quando il pallone torna giù, niente stop) }.
// Riferimento: x = sinistra del giocatore, y = su, z = avanti, metri del modello. Lato 1 = col destro (si specchia per -1).
import { Move, flightTime, footQ, G } from './core.js';
import { FOOT_PTS, SIDE } from './body.js';
import { add, sub, mul, qRot, qAxis, lerp } from './vec.js';
import { STANCE, PELVIS, BALL_R, BASE, landStop } from './juggle.js';

export const MENU_OPT = { R: BALL_R, B: BASE, k: 1.6, match: false };
// in partita il pallone a schermo è più grande (raggio 0,21 m sul campo = 0,168 nelle misure del modello, scala 1,25)
// e il motore lo tiene 0,6 m davanti al giocatore (0,48 nel modello)
export const MATCH_SCALE = 1.25;
export const MATCH_OPT = { R: 0.21 / MATCH_SCALE, B: [0, 0.21 / MATCH_SCALE, 0.6 / MATCH_SCALE], k: 1, match: true };

const n = (fq, part, side) => { const N = FOOT_PTS[part].n; return qRot(fq, [N[0] * SIDE[side], N[1], N[2]]); };
// punto `part` del piede che tocca il pallone in `ball`
const at = (ball, fq, part, side, R, gap = 0) => sub(ball, mul(n(fq, part, side), R + gap));
// col pallone grande della partita la punta (che è curva) entrerebbe nel pallone: la si tiene appena staccata
const toeGap = R => Math.max(0, R - BALL_R) * 0.35;
const PIVOT_OUT = 0.4; // veronica: il destro (perno del secondo mezzo giro) ha la punta girata via dal pallone
const ARMS_WIDE = [0.42, -0.3, 0.05], ARMS_REST = [0.2, -0.5, 0.05];
const SOMBRERO_H = { menu: 1.9, match: 1.6 }, RAINBOW_H = { menu: 2.3, match: 2.3 }; // punto più alto del volo (m)

function base(opt) {
  const m = new Move(opt.R), plants = { l: [[0, STANCE.l]], r: [[0, STANCE.r]] };
  m.leg('l', { t: 0, plant: STANCE.l }).leg('r', { t: 0, plant: STANCE.r });
  m.pelvis(0, PELVIS).bend(0, [0.16, 0, 0]).arm('l', 0, ARMS_REST).arm('r', 0, ARMS_REST);
  return { m, plants };
}
// fine: piedi di nuovo nella posizione di partenza
// (se un piede è appoggiato altrove fa un passo: si alza e si riappoggia, non striscia)
function finish(m, T, yaw = 0) {
  for (const s of ['l', 'r']) {
    const K = m.legK[s].filter(x => x.t < T - 1e-9).sort((a, b) => a.t - b.t), last = K[K.length - 1];
    if (last && last.plant && Math.hypot(last.p[0] - STANCE[s][0], last.p[2] - STANCE[s][1]) > 0.02 && T - last.t > 0.12) {
      const mid = lerp(last.p, [STANCE[s][0], last.p[1], STANCE[s][1]], 0.5);
      m.leg(s, { t: (last.t + T) / 2, ankle: add(mid, [0, 0.07, -0.1]), fq: qAxis([0, 1, 0], yaw) }); // passa dietro, lontano dal pallone
    }
    m.leg(s, { t: T, plant: STANCE[s], yaw });
  }
  m.pelvis(T, PELVIS, yaw).bend(T, [0.16, 0, 0]);
  m.arm('l', T, ARMS_REST).arm('r', T, ARMS_REST);
  return m.done(T);
}

// ---------------------------------------------------------------- finta di corpo: peso a sinistra, poi via a destra
function finta(opt) {
  const { m } = base(opt), k = opt.k, B = opt.B, T = 0.55 * k;
  m.ballRest(0, T, B);
  m.leg('l', { t: 0.06 * k, plant: STANCE.l }).leg('l', { t: 0.15 * k, ankle: [0.24, 0.16, 0.06], fq: footQ(-0.2, 0.2) });
  m.leg('l', { t: 0.24 * k, plant: [0.33, 0.06], yaw: -0.3 }).leg('l', { t: 0.36 * k, plant: [0.33, 0.06], yaw: -0.3 });
  m.leg('l', { t: 0.46 * k, ankle: [0.22, 0.15, 0.04], fq: footQ(0, 0.2) });
  m.leg('r', { t: 0.3 * k, plant: STANCE.r }).leg('r', { t: 0.4 * k, ankle: [-0.24, 0.15, 0.08], fq: footQ(0.1, 0.2) });
  m.leg('r', { t: 0.48 * k, plant: [-0.3, 0.1], yaw: 0.2 });
  m.active('l', 0.05 * k, 0.3 * k).active('r', 0.32 * k, 0.5 * k);
  // bacino e busto: giù e a sinistra (spalla che "cade"), poi spinta a destra
  m.pelvis(0.24 * k, [0.13, 0.88, 0.0], 0.25, 0.08, 0.14).pelvis(0.36 * k, [0.1, 0.875, 0.0], 0.2, 0.08, 0.12);
  m.pelvis(0.48 * k, [-0.1, 0.9, 0.05], -0.2, 0.06, -0.1);
  m.bend(0.24 * k, [0.25, 0.22, 0.25]).bend(0.36 * k, [0.25, 0.2, 0.2]).bend(0.48 * k, [0.2, -0.15, -0.2]);
  m.arm('l', 0.24 * k, [0.25, -0.5, 0.1]).arm('r', 0.24 * k, [0.5, -0.15, 0.05]).arm('l', 0.48 * k, [0.5, -0.15, 0.0]).arm('r', 0.48 * k, [0.2, -0.45, 0.15]);
  return finish(m, T);
}

// ---------------------------------------------------------------- doppio passo: il destro gira sopra il pallone fermo
// da dentro a fuori e si appoggia alla sua destra, poi il sinistro fa lo stesso dall'altra parte
function doppiopasso(opt) {
  const { m } = base(opt), k = opt.k, B = opt.B, R = opt.R, T = 0.85 * k, over = 2 * R + 0.15;
  m.ballRest(0, T, B);
  const step = (s, t0) => {
    const x = SIDE[s];  // il piede passa da dentro (verso il centro) a fuori, sopra il davanti del pallone
    m.leg(s, { t: t0, plant: STANCE[s] });
    m.leg(s, { t: t0 + 0.09 * k, ankle: [B[0] + 0.12 * x * -1, over, B[2] - 0.3], fq: footQ(0.5 * x, 0.2) });
    m.leg(s, { t: t0 + 0.17 * k, ankle: [B[0] + 0.0, over + 0.03, B[2] - 0.02], fq: footQ(0.9 * x, 0.15) });
    m.leg(s, { t: t0 + 0.25 * k, ankle: [B[0] + x * (R + 0.13), over * 0.6, B[2] - 0.1], fq: footQ(0.4 * x, 0.2) });
    m.leg(s, { t: t0 + 0.33 * k, plant: [B[0] + x * (R + 0.15), B[2] - 0.22], yaw: 0.3 * x });
    m.active(s, t0 + 0.02 * k, t0 + 0.33 * k);
    // il peso va sul piede che sta per atterrare, il busto si gira da quella parte
    m.pelvis(t0 + 0.17 * k, [x * 0.04, 0.9, 0.0], 0.25 * x, 0.08, -0.08 * x).pelvis(t0 + 0.33 * k, [x * 0.1, 0.88, 0.02], 0.2 * x, 0.08, 0.1 * x);
    m.bend(t0 + 0.2 * k, [0.25, 0.12 * x, 0.2 * x]);
    m.arm(s, t0 + 0.2 * k, [0.45, -0.25, 0.1]).arm(s === 'l' ? 'r' : 'l', t0 + 0.2 * k, [0.4, -0.3, -0.05]);
  };
  step('r', 0.02 * k);
  m.leg('r', { t: 0.5 * k, plant: [B[0] - (R + 0.15), B[2] - 0.22], yaw: -0.3 });
  step('l', 0.4 * k);
  m.leg('r', { t: 0.75 * k, plant: [B[0] - (R + 0.15), B[2] - 0.22], yaw: -0.3 });
  m.leg('l', { t: 0.75 * k, plant: [B[0] + (R + 0.15), B[2] - 0.22], yaw: 0.3 });
  return finish(m, T);
}

// ---------------------------------------------------------------- elastico: esterno del destro fuori, poi lo stesso
// piede gira davanti al pallone e con l'interno lo riporta dentro; il pallone rotola e si ferma da solo
function elastico(opt) {
  const { m } = base(opt), k = opt.k, B = opt.B, R = opt.R, T = 0.75 * k, out = 0.18 + (R - BALL_R);
  const fqOut = footQ(0.35, 0.05), fqIn = footQ(-0.25, 0.05);
  const t1 = 0.12 * k, t2 = 0.3 * k, t3 = 0.42 * k, t4 = 0.5 * k, tStop = 0.72 * k;
  const bOut = [B[0] - out, R, B[2]], bRel = [B[0] - out * 0.55, R, B[2]];
  const vRel = 2 * (B[0] - bRel[0]) / (tStop - t4);       // rotola libero fino a fermarsi in B
  m.ballRest(0, t1, B);
  m.leg('r', { t: 0.03 * k, plant: STANCE.r });
  // il destro passa dietro il pallone (la punta non lo tocca) e si mette alla sua sinistra
  m.leg('r', { t: 0.06 * k, ankle: [B[0] + 0.06, 0.16, B[2] - R - 0.25], fq: fqOut });
  m.leg('r', { t: t1, part: 'outside', at: at(B, fqOut, 'outside', 'r', R), fq: fqOut });
  m.leg('r', { t: t2, part: 'outside', at: at(bOut, fqOut, 'outside', 'r', R), fq: fqOut, v: [0.5, 0.6, 0] }); // si stacca dal pallone
  m.ballCarry(t1, t2, 'r', 'outside').touch(t1, 'r.outside', 'carry');
  m.ballRest(t2, t3, bOut);
  // attorno al pallone, davanti, basso
  m.leg('r', { t: t2 + (t3 - t2) * 0.35, ankle: [bOut[0] + 0.1, 2 * R + 0.12, bOut[2] + 0.02], fq: footQ(-0.2, 0.1) });
  m.leg('r', { t: t2 + (t3 - t2) * 0.7, ankle: [bOut[0] - R - 0.12, 2 * R + 0.06, bOut[2] - 0.05], fq: footQ(-0.25, 0.05) });
  m.leg('r', { t: t3, part: 'inside', at: at(bOut, fqIn, 'inside', 'r', R), fq: fqIn });
  m.leg('r', { t: t4, part: 'inside', at: at(bRel, fqIn, 'inside', 'r', R), fq: fqIn, v: [vRel, 0, 0] });
  m.ballCarry(t3, t4, 'r', 'inside').touch(t3, 'r.inside', 'carry');
  m.ballRoll(t4, tStop, bRel, B, [vRel, 0, 0], [0, 0, 0]);
  m.leg('r', { t: t4 + 0.08 * k, ankle: [bRel[0] - R - 0.1, 0.15, B[2] - 0.2], fq: footQ(-0.1, 0.1) }); // via dal pallone che rotola
  m.leg('r', { t: tStop, plant: STANCE.r });
  m.ballRest(tStop, T, B);
  m.active('r', 0.04 * k, t4 + 0.1 * k);
  m.pelvis(t2, [0.07, 0.9, 0.0], -0.15, 0.08, 0.06).pelvis(t4, [0.06, 0.9, 0.02], 0.2, 0.08, 0.06);
  m.bend(t2, [0.24, 0.1, -0.15]).bend(t4, [0.24, 0.08, 0.15]);
  m.arm('l', t2, ARMS_WIDE).arm('r', t2, [0.35, -0.3, -0.1]).arm('r', t4, ARMS_WIDE);
  return finish(m, T);
}

// ---------------------------------------------------------------- veronica: suola del destro sul pallone e giro sul
// sinistro (mezzo giro), poi i piedi si scambiano: suola del sinistro e giro sul destro (l'altro mezzo giro)
function veronica(opt) {
  const { m } = base(opt), k = opt.k, B = opt.B, R = opt.R, T = 1.0 * k;
  const tOn = 0.12 * k, tMid = 0.42 * k, tSw = 0.5 * k, tEnd2 = 0.8 * k;
  const K1 = [STANCE.l[0], 0, STANCE.l[1]], top = add(B, [0, R, 0]), fq0 = footQ(0, 0.02);
  // rotazione attorno a un perno verticale: punto e giro
  const rot = (p, K, a) => { const d = sub(p, K), c = Math.cos(a), s = Math.sin(a); return [K[0] + d[0] * c + d[2] * s, p[1], K[2] - d[0] * s + d[2] * c]; };
  const turn = (t0, t1, K, from, side, sole, onBall, other) => {
    for (let i = 0; i <= 6; i++) {
      const u = i / 6, e = u * u * (3 - 2 * u), a = from - Math.PI * e, t = t0 + (t1 - t0) * u;
      m.pelvis(t, rot(add(PELVIS, [K[0] * 0.5, -0.03, 0.02]), K, a - from + 0), a, 0.06, 0.06 * SIDE[other]);
      m.leg(side, { t, part: 'sole', at: rot(onBall, K, a - from), fq: qAxis([0, 1, 0], a) });
      m.leg(other, { t, plant: [K[0], K[2]], yaw: a });
    }
  };
  m.ballRest(0, tOn, B);
  m.leg('r', { t: 0.03 * k, plant: STANCE.r }).leg('r', { t: 0.08 * k, ankle: [B[0] - 0.06, 2 * R + 0.15, B[2] - 0.15], fq: fq0 });
  turn(tOn, tMid, K1, 0, 'r', true, top, 'l');
  m.ballCarry(tOn, tMid, 'r', 'sole').touch(tOn, 'r.sole', 'carry');
  // scambio: il destro scende accanto al sinistro, il sinistro sale sul pallone
  const ballMid = rot(B, K1, -Math.PI), K2 = [K1[0] + 0.02, 0, K1[2] + 0.02];
  m.ballRest(tMid, tSw, ballMid);
  m.leg('r', { t: (tMid + tSw) / 2, ankle: [K2[0] - 0.05, 0.22, K2[2] + 0.06], fq: qAxis([0, 1, 0], -Math.PI + PIVOT_OUT) }); // su, lontano dal pallone
  m.leg('r', { t: tSw, plant: [K2[0], K2[2]], yaw: -Math.PI + PIVOT_OUT });
  m.leg('l', { t: (tMid + tSw) / 2, ankle: lerp([K1[0], 0.2, K1[2]], add(ballMid, [0, R + 0.2, 0]), 0.5), fq: qAxis([0, 1, 0], -Math.PI) });
  const top2 = add(ballMid, [0, R, 0]);
  // secondo mezzo giro, sul destro
  for (let i = 0; i <= 6; i++) {
    const u = i / 6, e = u * u * (3 - 2 * u), a = -Math.PI - Math.PI * e, t = tSw + (tEnd2 - tSw) * u, da = a + Math.PI;
    const pc = rot(rot(add(PELVIS, [K1[0] * 0.5, -0.03, 0.02]), K1, -Math.PI), K2, da);
    m.pelvis(t, pc, a, 0.06, -0.06);
    m.leg('l', { t, part: 'sole', at: rot(top2, K2, da), fq: qAxis([0, 1, 0], a) });
    m.leg('r', { t, plant: [K2[0], K2[2]], yaw: a + PIVOT_OUT }); // punta girata via dal pallone
  }
  m.ballCarry(tSw, tEnd2, 'l', 'sole').touch(tSw, 'l.sole', 'carry');
  // il sinistro lascia il pallone: si rimette dov'era all'inizio (il pallone, tirato appena dalla suola, torna in B)
  const tBack = tEnd2 + 0.08 * k;
  m.leg('l', { t: tBack, part: 'sole', at: top, fq: qAxis([0, 1, 0], -2 * Math.PI) });
  m.ballCarry(tEnd2, tBack, 'l', 'sole');
  m.ballRest(tBack, T, B);
  m.leg('l', { t: tBack + 0.07 * k, ankle: add(top, [0.08, 0.1, -0.12]), fq: qAxis([0, 1, 0], -2 * Math.PI) });
  m.active('r', 0.02 * k, tSw).active('l', tMid, tBack + 0.05 * k);
  m.bend(tOn, [0.2, 0, 0]).bend(tEnd2, [0.2, 0, 0]);
  m.arm('l', tMid, ARMS_WIDE).arm('r', tMid, ARMS_WIDE);
  return finish(m, T, -2 * Math.PI);
}

// ---------------------------------------------------------------- sombrero: suola indietro, il pallone sale sulla punta
// che lo alza alto (sopra la testa di chi difende) e ricade avanti
function sombrero(opt) {
  const { m, plants } = base(opt), k = opt.k, B = opt.B, R = opt.R, H = opt.match ? SOMBRERO_H.match : SOMBRERO_H.menu;
  const tOn = 0.12 * k, tRel = 0.26 * k, tToe = 0.36 * k, tUp = 0.46 * k;
  const back = add(B, [0, 0, -0.1]), toeBall = add(B, [-0.02, 0, -0.16]), rel = [B[0] - 0.03, R + 0.13, B[2] + 0.27];
  const fqToe = footQ(0, 0.15), fqRel = footQ(0, -0.25);
  m.ballRest(0, tOn, B);
  m.leg('r', { t: 0.03 * k, plant: STANCE.r });
  m.leg('r', { t: 0.08 * k, part: 'sole', at: add(B, [-0.04, 2 * R + 0.06, -0.16]), fq: footQ(0, -0.1) });
  m.leg('r', { t: tOn, part: 'sole', at: add(B, [0, R, 0]), fq: footQ(0, 0.05) });
  m.leg('r', { t: tRel, part: 'sole', at: add(back, [0, R, 0]), fq: footQ(0, 0.05) });
  m.ballCarry(tOn, tRel, 'r', 'sole').touch(tOn, 'r.sole', 'carry');
  m.ballRoll(tRel, tToe, back, toeBall, [0, 0, (back[2] - B[2]) / (tRel - tOn)], [0, 0, -0.15]);
  m.leg('r', { t: tRel + 0.05 * k, ankle: [B[0] - 0.03, 2 * R + 0.12, back[2] - 0.32], fq: footQ(0, 0) });
  m.leg('r', { t: tToe, part: 'toe', at: at(toeBall, fqToe, 'toe', 'r', R), fq: fqToe });
  m.leg('r', { t: tUp, part: 'toe', at: at(rel, fqRel, 'toe', 'r', R), fq: fqRel, v: [0, 0.5, 0.4] });
  m.ballCarry(tToe, tUp, 'r', 'toe').touch(tToe, 'r.toe', 'carry');
  m.leg('r', { t: tUp + 0.14 * k, ankle: [-0.09, 0.12, 0.08], fq: footQ(0, 0.2) }); // giù, gamba distesa: il ginocchio resta fuori
  m.active('r', 0.02 * k, tUp + 0.1 * k);
  m.pelvis(tOn, [0.06, 0.92, -0.04], 0, 0.05, 0.04).pelvis(tUp, [0.04, 0.9, 0.0], 0, -0.02, 0.04);
  m.arm('l', tUp, ARMS_WIDE).arm('r', tUp, ARMS_WIDE);
  const t = tUp;
  if (opt.match) { // in partita il pallone ricade davanti (dove il motore lo porta) e lì finisce il giochetto
    const tL = t + flightTime(rel[1], H, R);
    m.ballFly(t, tL, rel, B, [-8, 0, 0]);
    m.leg('r', { t: tL, plant: STANCE.r });
    return finish(m, tL);
  }
  plants.r.push([tUp + 0.3 * k, STANCE.r]); m.leg('r', { t: tUp + 0.3 * k, plant: STANCE.r });
  m.pelvis(t + 0.5, add(PELVIS, [0, 0.01, 0])).bend(t + 0.4, [0.0, 0, 0]);
  const tEnd = landStop(m, t, rel, H, B, plants, 'l');
  m.pelvis(tEnd, PELVIS).arm('l', tEnd, ARMS_REST).arm('r', tEnd, ARMS_REST);
  return finish(m, tEnd);
}

// ---------------------------------------------------------------- arcobaleno: suola del destro che porta il pallone dietro
// il tallone sinistro, punta del destro sotto, il pallone sale sul polpaccio sinistro, tacco sinistro che lo lancia
// sopra la testa: ricade davanti
function arcobaleno(opt) {
  const { m, plants } = base(opt), k = opt.k, B = opt.B, R = opt.R, H = opt.match ? RAINBOW_H.match : RAINBOW_H.menu;
  const tOn = 0.12 * k, tA = 0.28 * k, tB = 0.4 * k, tToe = 0.5 * k, tLift = 0.62 * k, tFlick = 0.7 * k;
  const L = STANCE.l, heelZ = L[1] - 0.056;
  const pA = [B[0] - 0.02, R, L[1] - 0.04 - 1.5 * (R - BALL_R)], pB = [L[0] - 0.01, R, heelZ - R - 0.03]; // indietro, poi dietro il tallone
  m.ballRest(0, tOn, B);
  m.leg('r', { t: 0.03 * k, plant: STANCE.r });
  m.leg('r', { t: 0.08 * k, part: 'sole', at: add(B, [-0.04, 2 * R + 0.06, -0.14]), fq: footQ(0, -0.1) });
  m.leg('r', { t: tOn, part: 'sole', at: add(B, [0, R, 0]), fq: footQ(0, 0.05) });
  m.leg('r', { t: tA, part: 'sole', at: add(pA, [0, R, 0]), fq: footQ(0.1, 0.05) });
  m.leg('r', { t: tB, part: 'sole', at: add(pB, [0, R, 0]), fq: footQ(0.5, 0.05) });
  m.ballCarry(tOn, tB, 'r', 'sole').touch(tOn, 'r.sole', 'carry');
  m.ballRest(tB, tToe, pB);
  // il destro scende dietro il pallone con la punta sotto
  const fqToe = footQ(0.3, 0.35), rise = [pB[0] + 0.02, R + 0.18, pB[2] - 0.02], fqRise = footQ(0.3, -0.2);
  m.leg('r', { t: (tB + tToe) / 2, ankle: [pB[0] - 0.08, 2 * R + 0.1, pB[2] - 0.25], fq: footQ(0.4, 0.2) });
  m.leg('r', { t: tToe, part: 'toe', at: at(pB, fqToe, 'toe', 'r', R, toeGap(R)), fq: fqToe });
  m.leg('r', { t: tLift, part: 'toe', at: at(rise, fqRise, 'toe', 'r', R, toeGap(R)), fq: fqRise });
  m.leg('r', { t: tLift + 0.05 * k, ankle: [pB[0] - R - 0.1, 0.13, pB[2] - 0.2], fq: footQ(0.2, 0.1) }); // via di lato, lontano dal pallone
  m.ballCarry(tToe, tLift, 'r', 'toe', toeGap(R)).touch(tToe, 'r.toe', 'carry');
  m.leg('r', { t: tLift + 0.12 * k, plant: [STANCE.r[0] + 0.05, STANCE.r[1] - 0.05] });
  // tacco sinistro: la gamba si piega dietro, il tallone sale sotto il pallone e lo lancia
  const fqHeel = footQ(0, 1.3), heelBall = [rise[0], rise[1] + 0.06, rise[2] + 0.01], hAt = at(heelBall, fqHeel, 'heel', 'l', R);
  m.leg('l', { t: tB, plant: L }).leg('l', { t: tToe + 0.04 * k, plant: L });
  m.leg('l', { t: tFlick, part: 'heel', at: hAt, fq: fqHeel, pole: [0, -0.3, 1], v: [0, 1.6, -0.4] });
  m.ballRoll(tLift, tFlick, rise, heelBall, [0, 0.9, 0], [0, 0.9, 0.05]);
  m.touch(tFlick, 'l.heel');
  m.leg('l', { t: tFlick + 0.18 * k, plant: [L[0], L[1] + 0.12] });
  plants.l.push([tFlick + 0.18 * k, [L[0], L[1] + 0.12]]); plants.r.push([tLift + 0.12 * k, STANCE.r]);
  m.active('r', 0.02 * k, tLift + 0.06 * k).active('l', tToe, tFlick + 0.1 * k);
  // busto in avanti mentre il tacco sale: la schiena si toglie dalla strada del pallone che sale dietro
  m.pelvis(tToe, [0.05, 0.9, -0.1 - (R - BALL_R)], 0.2, 0.1, 0.05); // bacino indietro: il destro arriva dietro il pallone
  m.pelvis(tB, [0.05, 0.92, -0.06], 0.15, 0.08, 0.05).pelvis(tFlick, [-0.04, 0.88, 0.02], 0, 0.25, -0.08);
  // poi indietro a guardarlo scendere: la testa si toglie dalla strada del pallone che ricade davanti
  m.bend(tToe, [0.25, 0, 0]).bend(tFlick, [0.4, -0.05, 0]).bend(tFlick + 0.45, [-0.12, 0, 0]);
  m.pelvis(tFlick + 0.6, [-0.01, 0.91, -0.09], 0, -0.08, 0);
  m.arm('l', tFlick, [0.45, -0.2, 0.3]).arm('r', tFlick, [0.45, -0.2, 0.3]);
  if (opt.match) {
    const tL = tFlick + flightTime(heelBall[1], H, R);
    m.ballFly(tFlick, tL, heelBall, B, [-10, 0, 0]);
    return finish(m, tL);
  }
  const tEnd = landStop(m, tFlick, heelBall, H, B, plants, 'l');
  m.pelvis(tEnd, PELVIS);
  return finish(m, tEnd);
}

const MOVES = { finta, doppiopasso, elastico, veronica, sombrero, arcobaleno };
export const TRICK_IDS = Object.keys(MOVES);
const cache = new Map();
// movimento del giochetto `id` (in cache: è sempre lo stesso per le stesse opzioni)
export function trickMove(id, opt = MATCH_OPT) {
  const key = id + JSON.stringify(opt);
  if (!cache.has(key)) cache.set(key, (MOVES[id] || finta)(opt));
  return cache.get(key);
}
// durata del giochetto (s)
export const trickDuration = (id, opt = MATCH_OPT) => trickMove(id, opt).T;
