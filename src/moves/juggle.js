// Palleggi del campione sullo sfondo del menu: il pallone parte fermo a terra, il destro lo tira indietro con la
// suola e lo alza con la punta, poi collo del piede (destro e sinistro), coscia e un colpo di testa, infine lo
// stop di suola. Fra un tocco e l'altro il pallone vola con la gravità vera: tempo di volo = salita + discesa fino
// al tocco dopo (flightTime). Il piede va a incontrare il pallone nel punto e nell'istante del contatto.
import { Move, flightTime, footQ, G } from './core.js';
import { thighPoint, trunk, THIGH_L, CALF_L, SIDE, FOOT_PTS } from './body.js';
import { add, sub, mul, norm, qRot, qAxis, qBody, lerp } from './vec.js';

export const BALL_R = 0.11;                           // raggio vero del pallone (m)
export const BASE = [0, BALL_R, 0.3];                 // pallone fermo davanti ai piedi
export const STANCE = { l: [0.14, 0.0], r: [-0.14, -0.02] }; // piedi a terra (x, z)
export const PELVIS = [0, 0.935, -0.045];             // bacino in piedi, ginocchia appena piegate
const BEND = 0.16;                                    // busto in avanti a guardare il pallone (rad)
const INSTEP_Y = 0.31, INSTEP_X = 0.085, INSTEP_Z = 0.5;  // centro del pallone al tocco di collo (destro: x negativa):
                                                      // gamba quasi tesa e piede avanti, così lo stinco resta lontano dal pallone
const INSTEP_FQ = footQ(0, -0.3);                     // caviglia bloccata, punta un po' su: la normale del collo va in alto
const KICK_UP = 0.3, KICK_DOWN = 0.32;                // s: il piede parte da terra prima del tocco e ci torna dopo
const KICK_V = [0, 0.7, 0.15];                        // m/s: il piede sale ancora quando tocca il pallone
const SPIN_HARD = -9, SPIN_SOFT = -3;                 // rad/s attorno a x: effetto all'indietro (collo; coscia e testa)
const SHIFT = 0.055;                                  // m: il bacino va sul piede d'appoggio
const THIGH_EL = 0.2, THIGH_KNEE = 1.75, THIGH_UP = 0.38; // coscia appena sotto l'orizzontale, ginocchio piegato, s di salita
const LIFT_H = 1.05;                                  // m: alzata iniziale con la punta del destro
const SOLE_GAP = 0.012; // la suola della scarpa è più spessa del punto misurato sullo scheletro
const BOUNCE = 0.5, BOUNCE_LOW = 0.16; // rimbalzo sull'erba (velocità in su / in giù); sotto i 16 cm lo stop
                                  // rimbalzo sull'erba: velocità in su / velocità in giù
const STOP_TOE = 0.6;                                 // rad: punta in su nello stop di suola
const HEAD_DOWN = 0.28;                               // rad: nel colpo di testa la testa guarda meno in alto (fronte sul pallone)

// tocchi dopo la prima alzata: chi tocca e punto più alto del volo che segue (m da terra)
export const JUGGLE_SEQ = [
  ['l.instep', 1.0], ['r.instep', 1.1], ['l.instep', 0.95], ['r.instep', 1.4], ['r.thigh', 1.45],
  ['l.instep', 1.0], ['r.instep', 2.55], ['head', 2.25], ['l.thigh', 1.45], ['r.instep', 1.0], ['l.instep', 0.62],
];

const jit = (i, k) => Math.sin(i * 12.9898 + k * 78.233) * 0.5; // variazione fissa per tocco (niente Math.random)
const nrm = (fq, part) => qRot(fq, FOOT_PTS[part].n);          // normale del punto del piede (uguale per i due lati in y, z)

export function juggleMove(R = BALL_R) {
  const m = new Move(R), B0 = [0, R, BASE[2]];
  const plants = { l: [[0, STANCE.l]], r: [[0, STANCE.r]] };
  m.leg('l', { t: 0, plant: STANCE.l }).leg('r', { t: 0, plant: STANCE.r });
  m.bend(0, [BEND, 0, 0]).arm('l', 0, [0.2, -0.5, 0.05]).arm('r', 0, [0.2, -0.5, 0.05]);
  // ---- prima alzata: suola sul pallone, lo tira indietro; lasciato, rotola sulla punta che lo alza
  const tOn = 0.35, tRel = 0.62, tToe = 0.9, tUp = 1.06;
  const back = [0, R, B0[2] - 0.1], toeBall = [-0.02, R, B0[2] - 0.17], relBall = [-0.04, 0.28, B0[2] + 0.2];
  const fqToe = footQ(0, 0.18), fqRel = footQ(0, -0.15);
  m.ballRest(0, tOn, B0);
  m.leg('r', { t: 0.08, plant: STANCE.r });
  m.leg('r', { t: 0.22, part: 'sole', at: add(B0, [-0.04, 2 * R + 0.07, -0.16]), fq: footQ(0, -0.1) }); // su e dietro, poi sopra
  m.leg('r', { t: tOn, part: 'sole', at: add(B0, [0, R, 0]), fq: footQ(0, 0.05), v: [0, -0.3, 0.2] });
  m.leg('r', { t: tRel, part: 'sole', at: add(back, [0, R, 0]), fq: footQ(0, 0.05) });
  m.ballCarry(tOn, tRel, 'r', 'sole').touch(tOn, 'r.sole', 'carry');
  m.ballRoll(tRel, tToe, back, toeBall, [0, 0, (back[2] - B0[2]) / (tRel - tOn)], [0, 0, -0.2]);
  // il piede si alza (la punta passa sopra il pallone), va dietro e appoggia la punta sulla strada del pallone
  m.leg('r', { t: tRel + 0.1, ankle: [-0.03, 0.34, back[2] - 0.32], fq: footQ(0, 0) });
  m.leg('r', { t: tRel + 0.19, ankle: [-0.03, 0.1, back[2] - 0.37], fq: footQ(0, 0.25) });
  m.leg('r', { t: tToe, part: 'toe', at: sub(toeBall, mul(nrm(fqToe, 'toe'), R)), fq: fqToe });
  m.leg('r', { t: tUp, part: 'toe', at: sub(relBall, mul(nrm(fqRel, 'toe'), R)), fq: fqRel, v: [0, 0.8, 0.6] });
  m.leg('r', { t: tUp + 0.12, ankle: [-0.07, 0.13, 0.06], fq: footQ(0, 0.2) });  // giù e indietro, via dal pallone
  m.ballCarry(tToe, tUp, 'r', 'toe').touch(tToe, 'r.toe', 'carry');
  m.leg('r', { t: tUp + KICK_DOWN, plant: STANCE.r }); plants.r.push([tUp + KICK_DOWN, STANCE.r]);
  m.pelvis(0, PELVIS).pelvis(tOn, add(PELVIS, [SHIFT, -0.02, 0]), 0, 0, 0.03).pelvis(tUp, add(PELVIS, [SHIFT * 0.8, -0.01, 0]));
  let t = tUp, from = relBall, H = LIFT_H, soft = false, last = 'r';

  // ---- tocchi
  for (let i = 0; i < JUGGLE_SEQ.length; i++) {
    const [who, nextH] = JUGGLE_SEQ[i], head = who === 'head', s = head ? null : who[0], part = head ? 'head' : who.slice(2);
    let tc, ball;
    if (part === 'instep') {
      ball = [SIDE[s] * (INSTEP_X + 0.012 * jit(i, 1)), INSTEP_Y + 0.02 * jit(i, 2), INSTEP_Z + 0.03 * jit(i, 3)];
      tc = t + flightTime(from[1], H, ball[1]);
      kick(m, s, tc, { part: 'instep', at: sub(ball, mul(nrm(INSTEP_FQ, 'instep'), R)), fq: INSTEP_FQ, v: KICK_V }, plants, last, KICK_UP);
      m.pelvis(tc, add(PELVIS, [-SIDE[s] * SHIFT, -0.025, 0]), 0, 0, -SIDE[s] * 0.03);
    } else if (part === 'thigh') {
      // coscia alzata: il pallone cade sul davanti della coscia; la gamba è data da anca e angoli (nessuna stima)
      const pel = add(PELVIS, [-SIDE[s] * SHIFT, -0.01, -0.02]), pq = qBody(0, -0.06, -SIDE[s] * 0.04);
      const hip = trunk(pel, pq).hip(s), d = [0, -Math.sin(THIGH_EL), Math.cos(THIGH_EL)], h = [1, 0, 0];
      const knee = add(hip, mul(d, THIGH_L)), ankle = add(knee, mul(qRot(qAxis(h, THIGH_KNEE), d), CALF_L));
      const tp = thighPoint(hip, d, h); ball = add(tp.p, mul(tp.n, R));
      tc = t + flightTime(from[1], H, ball[1]);
      m.pelvis(tc, pel, 0, -0.06, -SIDE[s] * 0.04);
      kick(m, s, tc, { ankle, fq: footQ(0, 0.55), pole: norm(sub(knee, lerp(hip, ankle, 0.5))), v: [0, 1.0, 0.25] }, plants, last, THIGH_UP);
      m.bend(tc - 0.25, [BEND, 0, 0]).bend(tc, [0.05, 0, 0]).bend(tc + 0.3, [BEND, 0, 0]);
    } else {
      // testa: sotto il pallone, le gambe si distendono, busto dritto e sguardo in alto. La testa al contatto dipende
      // dallo sguardo (che segue il pallone): si cerca il punto due o tre volte
      let guess = [0, 1.97, 0.1]; tc = t + flightTime(from[1], H, guess[1]);
      const K = [m.pelvisK.length, m.bendK.length, m.headK.length];
      for (let k = 0; k < 8; k++) {
        m.pelvisK.length = K[0]; m.bendK.length = K[1]; m.headK.length = K[2];
        m.pelvis(tc - 0.28, add(PELVIS, [0, -0.045, 0.02])).pelvis(tc, add(PELVIS, [0, 0.012, 0.04])).pelvis(tc + 0.28, add(PELVIS, [0, -0.02, 0]));
        m.bend(tc - 0.3, [BEND, 0, 0]).bend(tc, [0.02, 0, 0]).bend(tc + 0.4, [BEND, 0, 0]);
        m.head(tc - 0.3, [0, 0]).head(tc, [HEAD_DOWN, 0]).head(tc + 0.3, [0, 0]);
        m.prep(tc + 1);
        const hp = m.trunkLook(tc, guess).tr.headPt(); guess = add(hp.p, mul(hp.n, R));
        tc = t + flightTime(from[1], H, guess[1]);
      }
      ball = guess;
      m.arm('l', tc, [0.38, -0.25, 0.1]).arm('r', tc, [0.38, -0.25, 0.1]);
    }
    m.touch(tc, head ? 'head' : who);
    m.ballFly(t, tc, from, ball, [soft ? SPIN_SOFT : SPIN_HARD, 0, 0]);
    if (s) m.arm(s, tc, [0.28, -0.42, 0.14]).arm(s === 'l' ? 'r' : 'l', tc, [0.46, -0.3, 0.02]);
    t = tc; from = ball; H = Math.max(nextH, ball[1] + 0.15); soft = part !== 'instep'; last = s || 'head';
    // a metà volo: bacino al centro, braccia rilassate
    const tn = t + flightTime(ball[1], H, INSTEP_Y) * 0.5;
    if (part !== 'head') m.pelvis(tn, add(PELVIS, [0, 0.005, 0]));
    m.arm('l', tn, [0.3, -0.42, 0.06]).arm('r', tn, [0.3, -0.42, 0.06]);
  }
  const tEnd = landStop(m, t, from, H, [0, R, BASE[2]], plants, last);
  m.pelvis(tEnd, PELVIS);
  m.arm('l', tEnd, [0.2, -0.5, 0.05]).arm('r', tEnd, [0.2, -0.5, 0.05]);
  return m.done(tEnd);
}

// Fine di un volo alto: il pallone scende, rimbalza una volta (il terreno gli toglie metà della velocità) e il destro
// lo ferma con la suola quando ritocca terra in `stop`. La suola è inclinata (punta in su): arriva da dietro e chiude il
// pallone contro il terreno sul quarto alto di dietro. Ritorna il tempo in cui il destro è di nuovo a terra.
export function landStop(m, t, from, H, stop, plants, last) {
  // rimbalzi finché il pallone non sale meno di BOUNCE_LOW: poi lo stop
  const R = m.R, tB = t + flightTime(from[1], H, R);
  let p = [stop[0] + from[0] * 0.2, R, stop[2] + 0.1], v = BOUNCE * Math.sqrt(2 * G * (H - R)), tt = tB;
  m.ballFly(t, tB, from, p, [SPIN_HARD, 0, 0]).touch(tB, 'ground', 'bounce');
  while (v * v / (2 * G) > BOUNCE_LOW) {
    const q = lerp(p, stop, 0.5), tn = tt + 2 * v / G;
    m.ballFly(tt, tn, p, q, [SPIN_SOFT, 0, 0]).touch(tn, 'ground', 'bounce');
    p = q; tt = tn; v *= BOUNCE;
  }
  const tLand = tt + 2 * v / G;
  m.ballFly(tt, tLand, p, stop, [SPIN_SOFT, 0, 0]);
  const fqStop = footQ(0, -STOP_TOE), sAt = sub(stop, mul(qRot(fqStop, FOOT_PTS.sole.n), R + SOLE_GAP));
  kick(m, 'r', tLand, { part: 'sole', at: sAt, fq: fqStop, v: [0, -0.3, 0.6] }, plants, last, 0.36, true);
  m.leg('r', { t: tLand - 0.15, part: 'sole', at: add(sAt, [-0.02, 0.05, -0.2]), fq: fqStop });
  m.leg('r', { t: tLand + 0.28, part: 'sole', at: sAt, fq: fqStop });
  m.touch(tLand, 'r.sole', 'stop');
  m.leg('r', { t: tLand + 0.42, part: 'sole', at: add(sAt, [-0.04, 0.06, -0.2]), fq: fqStop }); // su e indietro, via dal pallone
  const tEnd = tLand + 0.28 + KICK_DOWN + 0.08;
  m.leg('r', { t: tEnd, plant: STANCE.r });
  m.leg('l', { t: tEnd, plant: lastPlant(plants.l, tEnd) });
  m.ballRest(tLand, tEnd, stop);
  m.pelvis(tLand, add(PELVIS, [SHIFT, -0.03, 0]), 0, 0, 0.03);
  return tEnd;
}

export function lastPlant(list, t) { let P = list[0][1]; for (const [ti, p] of list) if (ti <= t) P = p; return P; }

// gamba che tocca: parte da terra `up` secondi prima, arriva al contatto `hit` (con la sua velocità), torna a terra
// KICK_DOWN dopo vicino a dove era. Se la stessa gamba ha appena toccato, non torna a terra in mezzo (resta su).
// hold = dopo il contatto il piede resta lì (lo stop): niente ritorno a terra qui
export function kick(m, s, tc, hit, plants, last, up, hold = false) {
  const K = m.legK[s];
  if (last === s && K.length && K[K.length - 1].t > tc - up) {
    K.pop(); plants[s].pop(); // toglie il ritorno a terra appena messo: la gamba passa da un tocco all'altro
    const prev = K[K.length - 1], mid = (prev.t + tc) / 2;
    m.leg(s, { t: mid, ankle: [STANCE[s][0], 0.16, 0.12], fq: footQ(0, 0.3), pole: [0, 0.2, 1] });
  } else m.leg(s, { t: tc - up, plant: lastPlant(plants[s], tc - up) });
  m.leg(s, { t: tc, ...hit });
  if (hold) return;
  // dopo il tocco il piede scende e torna indietro: la gamba si distende e il ginocchio resta fuori dalla strada del pallone
  if (hit.part === 'instep') m.leg(s, { t: tc + 0.1, ankle: add(m.legK[s][m.legK[s].length - 1].p, [0, -0.1, -0.12]), fq: footQ(0, 0) });
  const n = plants[s].length, P1 = [STANCE[s][0] + 0.02 * jit(n, 5), STANCE[s][1] + 0.03 * jit(n, 6)];
  m.leg(s, { t: tc + KICK_DOWN, plant: P1 });
  plants[s].push([tc + KICK_DOWN, P1]);
}
