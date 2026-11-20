// Inquadratura calcolata: conti puri (niente three, niente DOM, gira in Node) per mettere dei punti del campo
// dentro il campo visivo della telecamera, con margine. Usata dalla visuale della parata e da quella larga del
// rallenty in attacco (src/render.js).
//
// Spazio "orientato": punti [x, h, y] con x = larghezza, h = altezza, y = lunghezza, già girati in modo che la
// squadra umana attacchi verso +y (la propria porta è a y = −HL). Nel mondo three: X = x, Y = h, Z = −y.
import { HL, GW, GH } from './sim/core.js';

// Parata: telecamera dietro la propria porta, girata in parte verso chi tira; si allontana (e poi allarga il campo
// visivo) quanto serve perché porta intera, portiere e pallone stiano a schermo.
export const SAVE_BACK = 7;        // distanza minima dietro la linea di porta (m)
export const SAVE_H = 2.4;         // altezza di partenza (m); allontanandosi sale un poco (guarda in giù di SAVE_PITCH)
export const SAVE_PITCH = 0.07;    // inclinazione verso il basso (rad, ~4°): porta in basso, campo davanti in alto
export const SAVE_YAW_K = 0.8;     // si gira verso il pallone di questa frazione dell'angolo del tiro...
export const SAVE_YAW_MAX = 0.95;  // ... al massimo di tanto (rad, ~54°)
export const SAVE_MAX_BACK = 15;   // non oltre tanti metri dietro la porta (la tribuna di fondo è a 18 m)
export const SAVE_FOV_MAX = 96;    // campo visivo verticale massimo (gradi)
export const SAVE_PAD = 0.9;       // margine intorno ai pali (m)
export const SAVE_PAD_TOP = 0.7;   // margine sopra la traversa (m)
export const SAVE_MARGIN = { l: 0.06, r: 0.06, t: 0.17, b: 0.2 }; // margini a schermo (frazione di mezzo schermo): punteggio in alto, suggerimento in basso

// Rallenty in attacco (duello, area di tiro, disegno): visuale più alta e più indietro che tiene a schermo i compagni
// davanti e di fianco al portatore; il portatore resta sempre dentro e non troppo piccolo.
export const WIDE_PITCH = 0.66;    // inclinazione verso il basso (rad, ~38°)
export const WIDE_AHEAD = 13;      // la telecamera guarda tanti metri davanti al portatore (portatore in basso, campo davanti in alto)
export const WIDE_MIN_DIST = 22;   // distanza minima dal punto guardato (m)
export const WIDE_MAX_DIST = 36;   // ... massima: oltre il portatore diventa troppo piccolo
export const WIDE_FOV_MAX = 88;    // campo visivo verticale massimo (gradi)
export const WIDE_GOAL_GAP = 6;    // nell'area di tiro guarda al massimo fino a tanti metri prima della porta
export const WIDE_CARRIER_PAD = 2.5; // metri d'aria a destra e a sinistra del portatore
export const WIDE_R = 35;          // compagni entro tanti metri dal portatore...
export const WIDE_BEHIND = 5;      // ... davanti o di fianco (al massimo tanti metri dietro)
export const WIDE_MARGIN = { l: 0.08, r: 0.08, t: 0.2, b: 0.3 }; // punteggio e radar in alto, Dribbling e suggerimento in basso

const DEG = 180 / Math.PI;
const NEAR = 1;  // ogni punto almeno a tanti metri davanti alla telecamera
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

// assi della telecamera girata di yaw (0 = verso +y, + = verso +x) e inclinata in giù di pitch
export function basis(yaw, pitch) {
  const sy = Math.sin(yaw), cy = Math.cos(yaw), sp = Math.sin(pitch), cp = Math.cos(pitch);
  return { f: [sy * cp, -sp, cy * cp], r: [cy, 0, -sy], u: [sy * sp, cp, cy * sp] };
}

// punto p visto dalla telecamera in pos: [x, y] normalizzati (−1..1 = bordo dello schermo) e profondità
export function project(pos, yaw, pitch, tanV, aspect, p) {
  const B = basis(yaw, pitch), d = [p[0] - pos[0], p[1] - pos[1], p[2] - pos[2]], z = dot(d, B.f);
  return [dot(d, B.r) / (z * tanV * aspect), dot(d, B.u) / (z * tanV), z];
}

// t minimo (arretramento lungo l'asse) perché i punti Q = [[x, y, z]] stiano dentro con le pendenze date
function needT(Q, a, b, c, d) {
  let t = -Infinity;
  for (const p of Q) t = Math.max(t, NEAR - p[2]);
  for (const p of Q) for (const q of Q) {
    if (p === q) continue;
    t = Math.max(t, (p[0] - q[0] - b * p[2] - a * q[2]) / (a + b), (p[1] - q[1] - d * p[2] - c * q[2]) / (c + d));
  }
  return t;
}
// tangente verticale minima perché i punti stiano dentro con l'arretramento t fissato
function needTan(Q, t, aspect, m) {
  let k = 0;
  for (const p of Q) {
    if (p[2] + t < NEAR) return Infinity;
    for (const q of Q) {
      if (p === q) continue;
      const zp = p[2] + t, zq = q[2] + t;
      k = Math.max(k, (p[0] - q[0]) / (aspect * ((1 - m.r) * zp + (1 - m.l) * zq)), (p[1] - q[1]) / ((1 - m.t) * zp + (1 - m.b) * zq));
    }
  }
  return k;
}
// spostamento laterale (o verticale) ammesso: [min, max] con pendenze a (sinistra/giù) e b (destra/su)
function range(Q, t, i, a, b) {
  let lo = -Infinity, hi = Infinity;
  for (const p of Q) { lo = Math.max(lo, p[i] - b * (p[2] + t)); hi = Math.min(hi, p[i] + a * (p[2] + t)); }
  return [lo, hi];
}

/**
 * Telecamera con orientamento fisso (yaw, pitch) che parte da c0 e si sposta di lato, in alto e all'indietro lungo
 * l'asse (t tra tMin e tMax) finché tutti i punti stanno nel riquadro coi margini m; se non basta allarga il campo
 * visivo fino a fovMax; se nemmeno così, toglie i gruppi di punti dal fondo (i primi `keep` restano sempre).
 * @param {{ c0: number[], yaw: number, pitch: number, groups: number[][][], keep?: number, aspect: number,
 *   fov: number, fovMax: number, tMin?: number, tMax: number, m: {l:number,r:number,t:number,b:number},
 *   centerX?: boolean }} o  centerX: centra di lato (se no resta il più vicino a c0); in verticale resta il più vicino a c0
 * @returns {{ pos: number[], look: number[], fov: number, t: number, used: number, ok: boolean }}
 */
export function fitView(o) {
  const B = basis(o.yaw, o.pitch), m = o.m, keep = o.keep || 1, tMin = o.tMin || 0;
  const tan0 = Math.tan(o.fov / 2 / DEG), tanMax = Math.tan(o.fovMax / 2 / DEG);
  const G = o.groups.map(g => g.map(p => { const d = [p[0] - o.c0[0], p[1] - o.c0[1], p[2] - o.c0[2]]; return [dot(d, B.r), dot(d, B.u), dot(d, B.f)]; }));
  // prima arretra, poi allarga il campo visivo; ok = ci stanno tutti
  const solve = (Q) => {
    const th = tan0 * o.aspect;
    let t = Math.max(tMin, needT(Q, th * (1 - m.l), th * (1 - m.r), tan0 * (1 - m.b), tan0 * (1 - m.t))), tan = tan0;
    if (t > o.tMax) { t = o.tMax; tan = Math.max(tan0, needTan(Q, t, o.aspect, m)); }
    return { Q, t, tan, ok: tan <= tanMax + 1e-9 };
  };
  // i primi `keep` gruppi sempre; gli altri uno alla volta, in ordine, solo se ci stanno ancora tutti
  let used = Math.min(keep, G.length), S = solve(G.slice(0, used).flat());
  for (let i = used; i < G.length && S.ok; i++) {
    const T = solve(S.Q.concat(G[i]));
    if (T.ok) { S = T; used++; }
  }
  const Q = S.Q, t = S.t, n = used, ok = S.ok, tan = Math.min(S.tan, tanMax);
  const th = tan * o.aspect;
  const [xl, xh] = range(Q, t, 0, th * (1 - m.l), th * (1 - m.r)), [yl, yh] = range(Q, t, 1, tan * (1 - m.b), tan * (1 - m.t));
  const pick = (lo, hi, center) => (lo > hi || center ? (lo + hi) / 2 : clamp(0, lo, hi));
  const ox = Q.length ? pick(xl, xh, o.centerX !== false) : 0;
  const oy = Q.length ? pick(yl, yh, false) : 0;
  const pos = [0, 1, 2].map(i => o.c0[i] + B.r[i] * ox + B.u[i] * oy - B.f[i] * t);
  const z0 = Q.length ? Math.max(NEAR, G[0][0][2] + t) : 10;
  return { pos, look: pos.map((v, i) => v + B.f[i] * z0), fov: 2 * Math.atan(tan) * DEG, t, used: n, ok, yaw: o.yaw, pitch: o.pitch };
}

// punti della propria porta (a y = −HL) coi margini: i quattro angoli dello specchio allargato
export function goalCorners(gy = -HL, pad = SAVE_PAD, top = SAVE_PAD_TOP) {
  const x = GW / 2 + pad, h = GH + top;
  return [[-x, 0, gy], [x, 0, gy], [-x, h, gy], [x, h, gy]];
}

/**
 * Visuale della parata (spazio orientato, propria porta a y = −HL): porta intera sempre, poi portiere, poi pallone.
 * @param {{ ball: number[], keeper: number[], aspect: number, fov: number }} o  ball [x, h, y], keeper [x, y]
 */
export function saveView(o) {
  const gy = -HL, [bx, bh, by] = o.ball;
  const ang = Math.atan2(bx, Math.max(0.5, by - gy));
  const yaw = clamp(ang * SAVE_YAW_K, -SAVE_YAW_MAX, SAVE_YAW_MAX);
  const c0 = [-Math.sin(yaw) * SAVE_BACK, SAVE_H, gy - Math.cos(yaw) * SAVE_BACK];
  const k = o.keeper;
  return fitView({
    c0, yaw, pitch: SAVE_PITCH, aspect: o.aspect, fov: o.fov, fovMax: Math.max(o.fov, SAVE_FOV_MAX), m: SAVE_MARGIN,
    tMin: 0, tMax: (SAVE_MAX_BACK - SAVE_BACK) / Math.cos(SAVE_PITCH), keep: 2, centerX: true,
    groups: [goalCorners(gy), [[k[0], 0, k[1]], [k[0], 2, k[1]]], [[bx, Math.max(0, bh), by], [bx, 0, by]]],
  });
}

/**
 * Visuale larga del rallenty in attacco (spazio orientato, si attacca verso +y).
 * @param {{ carrier: number[], yaw?: number, mates: number[][], goal?: boolean, aspect: number, fov: number }} o
 *   carrier [x, y]; mates [[x, y]] (tutti i compagni: qui si tengono quelli entro WIDE_R davanti o di fianco);
 *   goal = tiene a schermo anche la porta avversaria (area di tiro)
 */
export function wideView(o) {
  const [cx, cy] = o.carrier, yaw = o.yaw || 0, hx = Math.sin(yaw), hy = Math.cos(yaw), B = basis(yaw, WIDE_PITCH);
  // nell'area di tiro non guarda oltre la porta (sopra resterebbero solo le tribune)
  const ahead = o.goal ? Math.max(0, Math.min(WIDE_AHEAD, (HL - WIDE_GOAL_GAP - cy) / Math.max(0.3, hy))) : WIDE_AHEAD;
  const look = [cx + hx * ahead, 0, cy + hy * ahead];
  const c0 = look.map((v, i) => v - B.f[i] * WIDE_MIN_DIST);
  // portatore con un po' d'aria ai lati (non resta incollato al bordo)
  const px = hy * WIDE_CARRIER_PAD, py = -hx * WIDE_CARRIER_PAD;
  const groups = [[[cx, 0, cy], [cx, 2.3, cy], [cx - px, 0, cy - py], [cx + px, 0, cy + py]]];
  if (o.goal) groups.push(goalCorners(HL, 0.5, 0.3));
  const near = o.mates
    .map(p => ({ p, d: Math.hypot(p[0] - cx, p[1] - cy), a: (p[0] - cx) * hx + (p[1] - cy) * hy }))
    .filter(q => q.d > 0.5 && q.d <= WIDE_R && q.a >= -WIDE_BEHIND)
    .sort((a, b) => a.d - b.d);
  for (const q of near) groups.push([[q.p[0], 0, q.p[1]], [q.p[0], 1.9, q.p[1]]]);
  return fitView({
    c0, yaw, pitch: WIDE_PITCH, aspect: o.aspect, fov: o.fov, fovMax: Math.max(o.fov, WIDE_FOV_MAX), m: WIDE_MARGIN,
    tMin: 0, tMax: WIDE_MAX_DIST - WIDE_MIN_DIST, keep: o.goal ? 2 : 1, centerX: true, groups,
  });
}
