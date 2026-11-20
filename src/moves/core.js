// Movimenti calcolati: un movimento (palleggi, giochetto, tiro...) è una funzione pura del tempo che dà, nel
// riferimento del giocatore fermo (x = sua sinistra, y = su, z = avanti; metri del modello), dove vanno bacino, busto,
// testa, mani e caviglie e dove sta il pallone. Il pallone segue la fisica: a terra rotola (rotazione = strada / raggio),
// in aria vola con la gravità vera, quando è a contatto viaggia col punto del piede che lo spinge.
// Chi disegna (src/move-pose.js) mette le ossa in quella posa con la cinematica inversa (src/ik.js).
import { add, sub, mul, cross, norm, len, clamp, smooth, qAxis, qMul, qRot, qConj, qSlerp, qBody, qNorm, QI } from './vec.js';
import { trunk, footPoint, ankleFor, ANKLE_H, SIDE } from './body.js';

export const G = 9.81;            // gravità (m/s²), nelle misure del corpo: la fisica è giusta rispetto al giocatore
const SPIN_DT = 1 / 240;          // passo con cui si integra la rotazione del pallone
const ACT_EASE = 0.08;            // s: entrata e uscita della gamba "attiva" (in partita)
const LOOK_UP = 0.7;              // rad: quanto in alto può guardare (collo + testa)

// tempo di volo da un'altezza y0 a una y1 passando per il punto più alto H
export const flightTime = (y0, H, y1) => Math.sqrt(2 * Math.max(0, H - y0) / G) + Math.sqrt(2 * Math.max(0, H - y1) / G);

// ---------------------------------------------------------------- curve per punti (Hermite, tangenti alle differenze)
const h00 = s => 2 * s * s * s - 3 * s * s + 1, h10 = s => s * s * s - 2 * s * s + s, h01 = s => -2 * s * s * s + 3 * s * s, h11 = s => s * s * s - s * s;
const same = (a, b) => a && b && Math.abs(a[0] - b[0]) + Math.abs(a[1] - b[1]) + Math.abs(a[2] - b[2]) < 1e-6;
// keys: [{ t, p: [x,y,z], v?: velocità imposta }] in ordine di tempo; chiavi uguali in fila = fermo (tangente nulla)
export function curve(keys) {
  const n = keys.length, m = keys.map((k, i) => {
    if (k.v) return k.v;
    const a = keys[i - 1], b = keys[i + 1];
    if (!a || !b || same(k.p, a.p) || same(k.p, b.p)) return [0, 0, 0];
    return mul(sub(b.p, a.p), 1 / (b.t - a.t));
  });
  return t => {
    if (t <= keys[0].t) return keys[0].p.slice();
    if (t >= keys[n - 1].t) return keys[n - 1].p.slice();
    let i = 0; while (keys[i + 1].t < t) i++;
    const a = keys[i], b = keys[i + 1], dt = b.t - a.t, s = (t - a.t) / dt;
    return [0, 1, 2].map(c => h00(s) * a.p[c] + h10(s) * dt * m[i][c] + h01(s) * b.p[c] + h11(s) * dt * m[i + 1][c]);
  };
}
// quaternioni: slerp addolcito tra una chiave e l'altra
export function qcurve(keys) {
  const n = keys.length;
  return t => {
    if (t <= keys[0].t) return keys[0].q;
    if (t >= keys[n - 1].t) return keys[n - 1].q;
    let i = 0; while (keys[i + 1].t < t) i++;
    const a = keys[i], b = keys[i + 1];
    return qSlerp(a.q, b.q, smooth((t - a.t) / (b.t - a.t)));
  };
}
// numeri: come curve() su una sola componente
export function scurve(keys) { const c = curve(keys.map(k => ({ t: k.t, p: [k.v, 0, 0] }))); return t => c(t)[0]; }

// ---------------------------------------------------------------- movimento
// verso del ginocchio se non è dato: davanti al piede (avanti + su del piede, in orizzontale), così gira col corpo
const kneeDir = fq => { const f = qRot(fq, [0, 0, 1]), u = qRot(fq, [0, 1, 0]), x = f[0] + u[0], z = f[2] + u[2], h = Math.hypot(x, z) || 1; return [x / h, 0.15, z / h]; };
// una chiave nuova allo stesso istante di una vecchia la sostituisce
const put = (list, k) => { const i = list.findIndex(x => Math.abs(x.t - k.t) < 1e-9); if (i >= 0) list.splice(i, 1); list.push(k); };
// Costruzione: m = new Move(R), poi bacino, busto, gambe, pallone, braccia; infine m.done(T).
export class Move {
  constructor(R) {
    this.R = R; this.T = 0; this.touches = []; this.segs = [];
    this.pelvisK = []; this.bendK = []; this.headK = [];
    this.legK = { l: [], r: [] }; this.armK = { l: [], r: [] }; this.actK = { l: [], r: [] };
  }
  // bacino: posizione e rotazione (giro, avanti, lato)
  pelvis(t, p, yaw = 0, pitch = 0, roll = 0) { put(this.pelvisK, { t, p, yaw, pitch, roll }); return this; }
  // curva del busto [avanti, lato, giro] (rad)
  bend(t, b) { put(this.bendK, { t, b }); return this; }
  // testa: [in giù, giro] in più rispetto allo sguardo verso il pallone
  head(t, h) { put(this.headK, { t, h }); return this; }
  // caviglia: { t, ankle, fq, pole } oppure { t, part, at, fq, pole } (il punto `part` del piede in `at`)
  // oppure { t, plant: [x, z], yaw } (piede piatto a terra)
  leg(side, k) {
    const fq = k.plant ? qAxis([0, 1, 0], k.yaw || 0) : (k.fq || QI);
    const ankle = k.plant ? [k.plant[0], ANKLE_H, k.plant[1]] : k.part ? ankleFor(side, k.at, fq, k.part) : k.ankle;
    put(this.legK[side], { t: k.t, p: ankle, q: fq, pole: k.pole || kneeDir(fq), v: k.v, plant: !!k.plant });
    return this;
  }
  // gamba "attiva" (in partita solo questa segue il movimento calcolato; l'altra resta nella corsa)
  active(side, t0, t1) { this.actK[side].push([t0, t1]); return this; }
  // mano rispetto alla spalla, nel riferimento del petto (x verso l'esterno, y su, z avanti)
  arm(side, t, off) { put(this.armK[side], { t, p: off }); return this; }

  // pallone: fermo, rotola, vola, portato dal piede
  ballRest(t0, t1, p, spin) { this.segs.push({ k: 'rest', t0, t1, p, spin }); return this; }
  ballRoll(t0, t1, p0, p1, v0, v1) { this.segs.push({ k: 'roll', t0, t1, p0, p1, v0, v1 }); return this; }
  ballFly(t0, t1, p0, p1, spin = [0, 0, 0]) {
    const T = t1 - t0, vy = (p1[1] - p0[1] + G * T * T / 2) / T;
    this.segs.push({ k: 'fly', t0, t1, p0, p1, vy, spin }); return this;
  }
  // pallone portato dal piede: punto `part` + normale·(R + gap); gap = piccolo distacco (punta curva col pallone grande)
  ballCarry(t0, t1, side, part, gap = 0) { this.segs.push({ k: 'carry', t0, t1, side, part, gap }); return this; }
  touch(t, part, kind = 'hit') { this.touches.push({ t, part, kind }); return this; }

  done(T) { this.prep(T); this.spinTab(); return this; }
  // curve pronte (senza la rotazione del pallone): si può già valutare bacino, busto e piedi mentre si costruisce
  prep(T) {
    this.T = T;
    const byT = a => a.sort((x, y) => x.t - y.t);
    byT(this.pelvisK); byT(this.bendK); byT(this.headK); this.segs.sort((a, b) => a.t0 - b.t0);
    this.pelvisP = curve(this.pelvisK);
    this.pelvisA = ['yaw', 'pitch', 'roll'].map(n => scurve(this.pelvisK.map(k => ({ t: k.t, v: k[n] }))));
    this.bendC = this.bendK.length ? curve(this.bendK.map(k => ({ t: k.t, p: k.b }))) : () => [0, 0, 0];
    this.headC = this.headK.length ? curve(this.headK.map(k => ({ t: k.t, p: [k.h[0], k.h[1], 0] }))) : () => [0, 0, 0];
    this.legC = {}; this.armC = {};
    for (const s of ['l', 'r']) {
      const K = byT(this.legK[s]);
      this.legC[s] = K.length ? { p: curve(K), q: qcurve(K), pole: curve(K.map(k => ({ t: k.t, p: k.pole }))) } : null;
      const A = byT(this.armK[s]); this.armC[s] = A.length ? curve(A) : null;
    }
    return this;
  }

  // ---- valutazione
  pelvisAt(t) { const [yaw, pitch, roll] = this.pelvisA.map(f => f(t)); return { p: this.pelvisP(t), q: qBody(yaw, pitch, roll), yaw }; }
  trunkAt(t) { const P = this.pelvisAt(t); return trunk(P.p, P.q, this.bendC(t)); }
  hipAt(side, t) { return this.trunkAt(t).hip(side); }
  footAt(side, t) { const C = this.legC[side]; return { ankle: C.p(t), fq: C.q(t), pole: norm(C.pole(t)) }; }
  footPt(side, t, part) { const F = this.footAt(side, t); return footPoint(side, F.ankle, F.fq, part); }
  seg(t) { let s = this.segs[0]; for (const x of this.segs) if (x.t0 <= t) s = x; return s; }
  ballAt(t) {
    const s = this.seg(t), T = s.t1 - s.t0, u = clamp(t - s.t0, 0, T);
    switch (s.k) {
      case 'rest': return s.p.slice();
      case 'roll': return curve([{ t: 0, p: s.p0, v: s.v0 || [0, 0, 0] }, { t: T, p: s.p1, v: s.v1 || [0, 0, 0] }])(u);
      case 'fly': { const k = u / T; return [s.p0[0] + (s.p1[0] - s.p0[0]) * k, s.p0[1] + s.vy * u - G * u * u / 2, s.p0[2] + (s.p1[2] - s.p0[2]) * k]; }
      case 'carry': { // il piede che preme non porta il pallone sotto terra
        const F = this.footPt(s.side, s.t0 + u, s.part), p = add(F.p, mul(F.n, this.R + (s.gap || 0)));
        p[1] = Math.max(p[1], this.R); return p;
      }
    }
    return [0, this.R, 0];
  }
  // rotazione del pallone, integrata una volta: rotola senza strisciare quando è a terra o portato, giro costante in volo
  spinTab() {
    const n = Math.ceil(this.T / SPIN_DT) + 2, tab = new Array(n);
    let q = QI, prev = this.ballAt(0);
    for (let i = 0; i < n; i++) {
      tab[i] = q;
      const t = (i + 1) * SPIN_DT, p = this.ballAt(t), s = this.seg(t - SPIN_DT / 2);
      let w;
      if (s.k === 'fly' || s.k === 'rest') w = s.spin || [0, 0, 0];
      else w = mul(cross([0, 1, 0], mul(sub(p, prev), 1 / SPIN_DT)), 1 / this.R); // asse = su × velocità
      const a = len(w) * SPIN_DT; if (a > 1e-9) q = qNorm(qMul(qAxis(w, a), q));
      prev = p;
    }
    this.spin = tab;
  }
  ballQ(t) {
    const x = clamp(t, 0, this.T) / SPIN_DT, i = Math.floor(x), a = this.spin[i], b = this.spin[Math.min(this.spin.length - 1, i + 1)];
    return qSlerp(a, b, x - i);
  }
  activeW(side, t) {
    let w = 0;
    for (const [a, b] of this.actK[side]) w = Math.max(w, smooth((t - a + ACT_EASE) / ACT_EASE) * smooth((b + ACT_EASE - t) / ACT_EASE));
    return w;
  }

  // posa completa al tempo t (0..T), nel riferimento del giocatore
  // busto con lo sguardo verso il pallone `ball`: giro e inclinazione rispetto al petto, metà al collo e metà alla
  // testa (col pallone quasi sopra la testa il giro si spegne, lo sguardo va in alto)
  trunkLook(t, ball) {
    const P = this.pelvisAt(t), bend = this.bendC(t), tr0 = trunk(P.p, P.q, bend);
    const toB = qRot(qConj(tr0.q.spine_03), sub(ball, add(tr0.p.Head, [0, 0.08, 0]))), hx = this.headC(t), hz = Math.hypot(toB[0], toB[2]);
    const yaw = clamp(Math.atan2(toB[0], toB[2]), -0.9, 0.9) * smooth(hz / 0.25) + hx[1];
    const pitch = clamp(Math.atan2(-toB[1], hz), -LOOK_UP, 0.9) + hx[0];
    const half = qMul(qAxis([0, 1, 0], yaw / 2), qAxis([1, 0, 0], pitch / 2));
    return { P, tr: trunk(P.p, P.q, bend, half, half) };
  }
  at(t) {
    t = clamp(t, 0, this.T);
    const ball = this.ballAt(t), { P, tr } = this.trunkLook(t, ball);
    const legs = {}, arms = {};
    for (const s of ['l', 'r']) {
      if (this.legC[s]) { const F = this.footAt(s, t); legs[s] = { ankle: F.ankle, fq: F.fq, pole: F.pole, w: this.activeW(s, t) }; }
      const off = this.armC[s] ? this.armC[s](t) : [0.2, -0.5, 0.05], x = SIDE[s], q3 = tr.q.spine_03;
      arms[s] = { hand: add(tr.shoulder(s), qRot(q3, [off[0] * x, off[1], off[2]])), pole: qRot(q3, [0.35 * x, -0.25, -1]) };
    }
    return { t, pelvis: { p: P.p, q: P.q }, yaw: P.yaw, rot: tr.q, legs, arms, ball: { p: ball, q: this.ballQ(t), vis: true } };
  }
}

// rotazione del piede: giro (punta verso +x), punta in giù (> 0), piede inclinato (> 0: il collo guarda verso +x)
export const footQ = (yaw = 0, down = 0, roll = 0) => qBody(yaw, down, roll);

// posa specchiata (sinistra <-> destra): lo stesso giochetto fatto con l'altro piede.
// Punti: x cambia segno; rotazioni: (x, -y, -z, w); le due gambe e le due braccia si scambiano.
const mP = p => [-p[0], p[1], p[2]], mQ = q => [q[0], -q[1], -q[2], q[3]];
export function mirrorFrame(fr) {
  const rot = {}, legs = {}, arms = {}, o = { l: 'r', r: 'l' };
  for (const k in fr.rot) rot[k] = mQ(fr.rot[k]);
  for (const s of ['l', 'r']) {
    const L = fr.legs[o[s]], A = fr.arms[o[s]];
    if (L) legs[s] = { ankle: mP(L.ankle), fq: mQ(L.fq), pole: mP(L.pole), w: L.w };
    if (A) arms[s] = { hand: mP(A.hand), pole: mP(A.pole) };
  }
  return { t: fr.t, pelvis: { p: mP(fr.pelvis.p), q: mQ(fr.pelvis.q) }, yaw: -fr.yaw, rot, legs, arms, ball: { p: mP(fr.ball.p), q: mQ(fr.ball.q), vis: fr.ball.vis } };
}
