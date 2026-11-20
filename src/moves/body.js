// Misure del corpo per i movimenti calcolati: posizioni delle ossa del modello atleta in posa di legame nel riferimento
// del corpo (x = sinistra del giocatore, y = su, z = avanti; metri del modello, prima della scala del gioco), punti di
// contatto col pallone su piede, coscia e testa, e la catena bacino → busto → testa (cinematica diretta).
// Valori misurati su assets/models/athlete.glb (test/unit/moves-rig.test.mjs controlla che coincidano col modello).
import { add, sub, mul, norm, cross, qRot, qMul, qAxis, QI } from './vec.js';

// posa di legame (posa a T) nel riferimento del corpo: [x, y, z]
export const REST = {
  pelvis: [0, 0.9673, -0.0434], spine_01: [0, 1.0913, -0.007], spine_02: [0, 1.1981, 0.0039], spine_03: [0, 1.3324, 0.007],
  neck_01: [0, 1.5439, -0.0418], Head: [0, 1.6239, -0.0176],
  clavicle_l: [0.0317, 1.5184, 0.0338], upperarm_l: [0.1641, 1.4783, -0.066], lowerarm_l: [0.4608, 1.4783, -0.0737], hand_l: [0.7368, 1.4783, -0.066],
  clavicle_r: [-0.0317, 1.5184, 0.0338], upperarm_r: [-0.1641, 1.4783, -0.066], lowerarm_r: [-0.4608, 1.4783, -0.0737], hand_r: [-0.7368, 1.4783, -0.066],
  thigh_l: [0.1153, 0.9896, -0.0363], calf_l: [0.1153, 0.4715, -0.0364], foot_l: [0.1153, 0.0805, -0.0883], ball_l: [0.1153, 0.0207, 0.0497],
  thigh_r: [-0.1153, 0.9896, -0.0363], calf_r: [-0.1153, 0.4715, -0.0364], foot_r: [-0.1153, 0.0805, -0.0883], ball_r: [-0.1153, 0.0207, 0.0497],
};
export const THIGH_L = 0.5181, CALF_L = 0.3944;   // lunghezze di coscia e gamba (anca → ginocchio → caviglia)
export const ANKLE_H = 0.0805;                     // altezza della caviglia col piede piatto a terra
export const SIDE = { l: 1, r: -1 };               // da che parte sta ogni lato (x)

// punti del piede rispetto alla caviglia, nel riferimento del piede piatto (lat = verso l'esterno del piede, su, avanti),
// con la normale uscente della superficie: il pallone tocca il piede in p + n·R
export const FOOT_PTS = {
  instep: { p: [0.017, -0.01, 0.125], n: [0, 0.876, 0.482] },  // collo del piede (lacci, verso la punta)
  sole: { p: [0.017, -0.081, 0.07], n: [0, -1, 0] },            // pianta, sotto l'arco
  toe: { p: [0.017, -0.035, 0.205], n: [0, 0.45, 0.89] },       // punta, sopra
  inside: { p: [-0.028, -0.045, 0.1], n: [-1, 0, 0] },          // interno
  outside: { p: [0.062, -0.045, 0.11], n: [1, 0, 0] },          // esterno
  heel: { p: [0.015, -0.05, -0.056], n: [0, 0, -1] },           // tallone, dietro
};
// coscia: punto davanti a 2/3 della coscia (riferimento della coscia a riposo: asse lungo −y, davanti +z)
export const THIGH_PT = { along: 0.33, front: 0.092, n: [0, 0, 1] };
// testa: fronte alta, rispetto all'osso della testa a riposo (capelli compresi)
export const HEAD_PT = { p: [0, 0.205, 0.1], n: [0, 0.866, 0.5] };

// punto del piede (x lato) nel riferimento del corpo: caviglia + rotazione del piede · punto (lat → ±x)
export function footPoint(side, ankle, fq, part) {
  const P = FOOT_PTS[part], s = SIDE[side];
  return { p: add(ankle, qRot(fq, [P.p[0] * s, P.p[1], P.p[2]])), n: qRot(fq, [P.n[0] * s, P.n[1], P.n[2]]) };
}
// caviglia che mette il punto `part` del piede in `at`
export function ankleFor(side, at, fq, part) { const P = FOOT_PTS[part], s = SIDE[side]; return sub(at, qRot(fq, [P.p[0] * s, P.p[1], P.p[2]])); }

// catena del busto: bacino in `pp` con rotazione `pq`, curva del busto (avanti, lato, giro) divisa sulle tre vertebre,
// collo e testa. Restituisce rotazioni (rispetto alla posa di legame) e posizioni di ogni osso.
const off = (a, b) => sub(REST[b], REST[a]);
export function trunk(pp, pq, bend = [0, 0, 0], neck = QI, head = QI) {
  const part = k => qMul(qAxis([0, 1, 0], bend[2] * k), qMul(qAxis([1, 0, 0], bend[0] * k), qAxis([0, 0, 1], -bend[1] * k)));
  const q1 = qMul(pq, part(0.3)), q2 = qMul(q1, part(0.35)), q3 = qMul(q2, part(0.35)), qn = qMul(q3, neck), qh = qMul(qn, head);
  const p1 = add(pp, qRot(pq, off('pelvis', 'spine_01'))), p2 = add(p1, qRot(q1, off('spine_01', 'spine_02'))), p3 = add(p2, qRot(q2, off('spine_02', 'spine_03')));
  const pn = add(p3, qRot(q3, off('spine_03', 'neck_01'))), ph = add(pn, qRot(qn, off('neck_01', 'Head')));
  const sh = s => add(add(p3, qRot(q3, off('spine_03', 'clavicle_' + s))), qRot(q3, off('clavicle_' + s, 'upperarm_' + s)));
  return {
    q: { pelvis: pq, spine_01: q1, spine_02: q2, spine_03: q3, neck_01: qn, Head: qh },
    p: { pelvis: pp, spine_01: p1, spine_02: p2, spine_03: p3, neck_01: pn, Head: ph },
    hip: s => add(pp, qRot(pq, off('pelvis', 'thigh_' + s))), shoulder: sh,
    headPt: () => ({ p: add(ph, qRot(qh, HEAD_PT.p)), n: qRot(qh, HEAD_PT.n) }),
  };
}

// coscia in direzione `d` con cerniera del ginocchio `h` (x a riposo): punto davanti alla coscia e sua normale
export function thighPoint(hip, d, h) {
  const front = norm(cross(d, h)); // a riposo: d = −y, h = +x → davanti = +z
  return { p: add(add(hip, mul(d, THIGH_PT.along)), mul(front, THIGH_PT.front)), n: front };
}
