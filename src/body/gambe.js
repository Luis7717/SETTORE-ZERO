// Bacino, gambe e piedi del calciatore realistico (src/athlete3d.js): correzioni a codice al caricamento, sul modello
// athlete.glb così com'è (niente glb rigenerato, nessun triangolo in più). Riferimento: PROPORZIONI.md.
//
// 1) Ginocchio e caviglia al posto giusto: le ossa calf_* e foot_* scendono (ginocchio a 2,05 T, caviglia a 0,35 T)
//    e i vertici sotto il cavallo seguono con una rimappatura liscia dell'altezza (coscia più lunga, stinco più corto).
// 2) Sagoma: per ogni altezza si misura la sezione della gamba e la si porta alla larghezza voluta (coscia 0,72 T,
//    ginocchio, polpaccio 0,5 T a 1,35 T, caviglia sottile), con rotula e parastinchi appena accennati.
// 3) Pantaloncini veri: dall'orlo (0,6 T sopra il ginocchio) in su la stoffa sta 0,05 T per lato fuori dalla coscia,
//    con uno scalino netto all'orlo. Il gonfiaggio SHORTS_LOOSE di athlete3d.js (0,8 cm lungo la normale) fa parte del
//    conto: qui si aggiunge solo il resto e lo si toglie sotto l'orlo, dove la gamba è nuda.
// 4) Scarpe basse e affusolate: piede lungo 1,15 T e largo 0,42 T, punta stretta e bassa.
// 5) Pittura della zona (pantaloncini con orlo e banda, calzettoni alti/bassi/ripiegati, scarpe con suola e tacchetti)
//    sopra la texture dipinta da athlete3d.js: si ridipingono solo i texel di gambe e piedi.
// La giunzione con la vita resta ferma: tutte le correzioni si spengono prima di 4,3 T (orlo della maglia a ~4,5 T).
import * as THREE from 'three';
import { hex, rgb, shade, lumH, SOLE, cpuCanvas } from '../players3d.js';
import { SKINS, BOOTS, normalizeKitStyle } from '../looks.js';

// misure in T (altezza totale / 8), da terra
export const LEG = {
  knee: 2.05, ankle: 0.35, thighW: 0.72, calfW: 0.5, calfH: 1.35, footL: 1.15, footW: 0.42,
  shortsAbove: 0.6, shortsLongAbove: 0.3, shortsFlare: 0.1, sockBelow: 0.3,
};
// larghezza di una gamba (in T) per altezza (in T), dalla caviglia al cavallo
const WIDTH = [[0.5, 0.27], [0.65, 0.27], [0.85, 0.31], [1.05, 0.38], [1.2, 0.45], [1.35, LEG.calfW], [1.55, 0.48],
  [1.8, 0.42], [2.05, 0.42], [2.25, 0.46], [2.5, 0.53], [2.8, 0.62], [3.1, 0.69], [3.4, LEG.thighW], [3.7, LEG.thighW], [3.9, 0.71]];
const ZONE_TOP = 4.3;          // T: sopra qui nessuna correzione (vita e maglia sono di altri)
const SHAPE_FADE = [3.85, 4.25]; // T: la sagoma voluta si spegne verso il bacino
const MID_FADE = 0.02;         // m: vicino alla linea di mezzo (cavallo) le correzioni si spengono, niente strappi
const FOOT_BLEND = [0.4, 0.62];  // T: sotto si usa la trasformazione del piede, sopra quella della gamba
// tomaia della scarpa sulla parte davanti del piede (u: 0 tallone → 1 punta): altezza e larghezza in T.
// Le dita scolpite del piede nudo spariscono: i vertici vanno sulla superficie liscia di una scarpa bassa.
const SHOE_H = [[0.35, 0.5], [0.5, 0.42], [0.6, 0.34], [0.7, 0.275], [0.8, 0.22], [0.9, 0.175], [0.97, 0.13], [1, 0.09]];
const SHOE_W = [[0.35, 0.35], [0.5, 0.39], [0.65, LEG.footW], [0.8, 0.4], [0.9, 0.33], [0.97, 0.22], [1, 0.12]];
const SHOE_IN = 0.05;          // T: la punta piega un poco verso l'interno (alluce)
const SHOE_SQ = 3;             // esponente della sezione (2 = ellisse, più alto = più squadrata)
const KNEECAP = 0.004, SHIN_GUARD = 0.003; // m: rotula e parastinchi in avanti
const SHORTS_LOOSE = 0.008;    // m: deve coincidere con SHORTS_LOOSE di src/athlete3d.js
const HEM_DROP = 0.035;        // T: altezza dello scalino all'orlo dei pantaloncini
const HEM_LIP = 0.0015;        // m: l'orlo sta appena più fuori della stoffa sopra
const C_LEG = 4, C_FOOT = 6;   // classi dei texel di athlete3d.js (gamba, piede)
const DETAIL_K = { skin: 0.95, cloth: 0.4 }; // come in athlete3d.js
const COLLAR = [[0, 0.42], [0.3, 0.38], [0.45, 0.31], [0.62, 0.55]]; // T: bordo della scarpa (u: 0 tallone → 1 punta)
const AA = 0.004;              // m: bordi morbidi della pittura

const smooth = (a, b, x) => { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
const lerp = (a, b, t) => a + (b - a) * t;
function interp(tab, x) { // tabella [[x, y], ...] crescente, estremi tenuti
  if (x <= tab[0][0]) return tab[0][1];
  for (let i = 1; i < tab.length; i++) if (x <= tab[i][0]) { const [x0, y0] = tab[i - 1], [x1, y1] = tab[i]; return y0 + (y1 - y0) * (x - x0) / (x1 - x0); }
  return tab[tab.length - 1][1];
}

// rimappatura dell'altezza (vecchia → nuova): Hermite cubica monotona per i punti dati, identità sopra l'ultimo
export function makeRemap(pts) {
  const n = pts.length, sec = [], m = [];
  for (let i = 0; i < n - 1; i++) sec.push((pts[i + 1][1] - pts[i][1]) / (pts[i + 1][0] - pts[i][0]));
  for (let i = 0; i < n; i++) m.push(i === 0 ? sec[0] : i === n - 1 ? 1 : (sec[i - 1] + sec[i]) / 2);
  return (y) => {
    if (y >= pts[n - 1][0]) return y;
    if (y <= pts[0][0]) return pts[0][1] + (y - pts[0][0]) * m[0];
    let i = 0; while (y > pts[i + 1][0]) i++;
    const h = pts[i + 1][0] - pts[i][0], t = (y - pts[i][0]) / h, t2 = t * t, t3 = t2 * t;
    return (2 * t3 - 3 * t2 + 1) * pts[i][1] + (t3 - 2 * t2 + t) * h * m[i] + (-2 * t3 + 3 * t2) * pts[i + 1][1] + (t3 - t2) * h * m[i + 1];
  };
}

// sezioni orizzontali della mesh (una gamba: lato s) a varie altezze: centro e semiassi in x e z
export function legSections(P, I, s, ys) {
  const out = ys.map(() => ({ xa: Infinity, xb: -Infinity, za: Infinity, zb: -Infinity, n: 0 }));
  const y0 = ys[0], dy = ys[1] - ys[0];
  for (let t = 0; t < I.length; t += 3) for (let e = 0; e < 3; e++) {
    const a = I[t + e], b = I[t + (e + 1) % 3], ya = P[a * 3 + 1], yb = P[b * 3 + 1];
    if (ya === yb) continue;
    const lo = Math.min(ya, yb), hi = Math.max(ya, yb);
    for (let k = Math.max(0, Math.ceil((lo - y0) / dy)); k < ys.length && ys[k] < hi; k++) {
      const u = (ys[k] - ya) / (yb - ya), x = P[a * 3] + u * (P[b * 3] - P[a * 3]);
      if (x * s <= 0) continue;
      const z = P[a * 3 + 2] + u * (P[b * 3 + 2] - P[a * 3 + 2]), o = out[k];
      if (x < o.xa) o.xa = x; if (x > o.xb) o.xb = x; if (z < o.za) o.za = z; if (z > o.zb) o.zb = z; o.n++;
    }
  }
  return out.map(o => o.n ? { cx: (o.xa + o.xb) / 2, hx: (o.xb - o.xa) / 2, cz: (o.za + o.zb) / 2, hz: (o.zb - o.za) / 2 } : null);
}

// misure della gamba (lato s) sulla mesh: larghezza e profondità a un'altezza, in T
export function measureLegs(P, I, ground, T, s, hs) {
  const sec = legSections(P, I, s, hs.map(h => ground + h * T));
  return sec.map(o => (o ? { w: 2 * o.hx / T, d: 2 * o.hz / T } : null));
}

// ---------------------------------------------------------------- deformazione dei vertici (array puri)
// P posizioni (Float32Array, modificata), I indici, bone(i) nome dell'osso principale, bp posizioni delle ossa
// Ritorna le nuove posizioni delle ossa di gamba e piede e le misure per la pittura.
export function deformLegs(P, I, bone, bp) {
  const nv = P.length / 3;
  let ground = Infinity, top = -Infinity;
  for (let i = 0; i < nv; i++) { ground = Math.min(ground, P[i * 3 + 1]); top = Math.max(top, P[i * 3 + 1]); }
  const T = (top - ground) / 8, H = y => (y - ground) / T, Y = h => ground + h * T;
  let crotch = Infinity; // punto più basso della linea di mezzo fra le gambe
  for (let i = 0; i < nv; i++) { const y = P[i * 3 + 1]; if (Math.abs(P[i * 3]) < 0.004 && H(y) > 2.5 && H(y) < 4.6) crotch = Math.min(crotch, y); }
  if (!isFinite(crotch)) crotch = Y(4);
  const kneeOld = (bp.calf_l.y + bp.calf_r.y) / 2, ankleOld = (bp.foot_l.y + bp.foot_r.y) / 2;
  const kneeNew = Y(LEG.knee), ankleNew = Y(LEG.ankle);
  const remap = makeRemap([[ground, ground], [ankleOld, ankleNew], [kneeOld, kneeNew], [crotch, crotch]]);
  const orig = P.slice();
  // 1) altezze
  for (let i = 0; i < nv; i++) P[i * 3 + 1] = remap(orig[i * 3 + 1]);

  // 2) sezioni dopo la rimappatura (passo 0,05 T), lisciate
  const STEP = 0.05, hs = []; for (let h = 0; h <= ZONE_TOP + 1e-6; h += STEP) hs.push(h);
  const ys = hs.map(Y), secs = {};
  for (const s of [1, -1]) {
    const raw = legSections(P, I, s, ys);
    for (let k = 0; k < raw.length; k++) if (!raw[k]) raw[k] = raw[k - 1] || { cx: 0.1 * s, hx: 0.05, cz: 0, hz: 0.05 };
    secs[s] = raw.map((o, k) => { // media mobile a 3
      const a = raw[Math.max(0, k - 1)], c = raw[Math.min(raw.length - 1, k + 1)];
      return { cx: (a.cx + 2 * o.cx + c.cx) / 4, hx: (a.hx + 2 * o.hx + c.hx) / 4, cz: (a.cz + 2 * o.cz + c.cz) / 4, hz: (a.hz + 2 * o.hz + c.hz) / 4 };
    });
  }
  const secAt = (s, h) => { const f = Math.max(0, Math.min(hs.length - 1.001, h / STEP)), k = Math.floor(f), t = f - k, a = secs[s][k], b = secs[s][k + 1];
    return { cx: lerp(a.cx, b.cx, t), hx: lerp(a.hx, b.hx, t), cz: lerp(a.cz, b.cz, t), hz: lerp(a.hz, b.hz, t) }; };

  // piede: estremi per lato
  const foot = {};
  for (const s of [1, -1]) {
    let zH = Infinity, zT = -Infinity, xa = Infinity, xb = -Infinity;
    for (let i = 0; i < nv; i++) {
      const x = P[i * 3], y = P[i * 3 + 1], z = P[i * 3 + 2]; if (x * s <= 0 || H(y) > 0.3) continue;
      zH = Math.min(zH, z); zT = Math.max(zT, z); if (H(y) < 0.2) { xa = Math.min(xa, x); xb = Math.max(xb, x); }
    }
    const ball = s * Math.sign(bp.ball_l.x) > 0 ? bp.ball_l : bp.ball_r;
    foot[s] = { zH, zT, cx: (xa + xb) / 2, kx: LEG.footW * T / (xb - xa), kz: LEG.footL * T / (zT - zH), zBall: ball.z };
  }

  // 3) sagoma, rotula, parastinchi, pantaloncini, piede
  const hemH = LEG.knee + LEG.shortsAbove, flare = LEG.shortsFlare / 2 * T;
  const flareOff = new Float32Array(nv); // spostamento dei pantaloncini lungo la normale (applicato dopo le normali)
  for (let i = 0; i < nv; i++) {
    const x0 = P[i * 3], y = P[i * 3 + 1], z0 = P[i * 3 + 2], h = H(y);
    if (h >= ZONE_TOP || /arm|hand/.test(bone(i))) continue;
    const s = x0 >= 0 ? 1 : -1, sec = secAt(s, Math.max(h, FOOT_BLEND[0] + 0.1));
    const wMid = lerp(1, smooth(0.003, MID_FADE, Math.abs(x0)), smooth(3.55, 3.8, h));
    const wShape = (1 - smooth(SHAPE_FADE[0], SHAPE_FADE[1], h)) * wMid;
    // gamba: larghezza voluta attorno al centro della sezione; in alto il lato interno della coscia resta dov'è
    const k = Math.max(0.75, Math.min(1.15, interp(WIDTH, h) * T / (2 * sec.hx)));
    const shift = s * (1 - k) * sec.hx * smooth(2.5, 3.2, h);
    const dx = x0 - sec.cx, dz = z0 - sec.cz;
    let lx = sec.cx - shift + dx * k, lz = sec.cz + dz * k;
    // rotula e parastinchi (davanti)
    const front = Math.max(0, dz / Math.max(1e-4, Math.hypot(dx, dz)));
    lz += KNEECAP * Math.sin(Math.PI * smooth(1.95, 2.25, h)) * front * front;
    lz += SHIN_GUARD * smooth(0.8, 0.95, h) * (1 - smooth(1.5, 1.65, h)) * Math.sqrt(front);
    // piede: più stretto, punta affusolata e bassa, lunghezza giusta
    const F = foot[s], wf = 1 - smooth(FOOT_BLEND[0], FOOT_BLEND[1], h);
    let fx = x0, fy = y, fz = z0;
    if (wf > 0) {
      fx = F.cx + (x0 - F.cx) * F.kx;
      fz = F.zH + (z0 - F.zH) * F.kz;
      const u = Math.min(1, Math.max(0, (z0 - F.zH) / (F.zT - F.zH)));
      const wS = smooth(0.3, 0.5, u) * (1 - smooth(0.5, 0.62, h));
      if (wS > 0) {
        const W = interp(SHOE_W, u) * T / 2, Hs = interp(SHOE_H, u) * T, c = 0.35 * Hs;
        const cx = F.cx - s * SHOE_IN * T * smooth(0.65, 1, u), ry = y - ground;
        const px = (x0 - cx) / W, py = (ry - c) / (ry > c ? Hs - c : c), ph = Math.atan2(py, px);
        const ex = Math.sign(Math.cos(ph)) * Math.abs(Math.cos(ph)) ** (2 / SHOE_SQ), ey = Math.sign(Math.sin(ph)) * Math.abs(Math.sin(ph)) ** (2 / SHOE_SQ);
        fx = lerp(fx, cx + W * ex, wS);
        fy = lerp(y, ground + Math.max(0, c + (ey > 0 ? Hs - c : c) * ey), wS);
      }
    }
    P[i * 3] = lerp(x0, lerp(lx, fx, wf), wShape); P[i * 3 + 2] = lerp(z0, lerp(lz, fz, wf), wShape); P[i * 3 + 1] = lerp(y, fy, wf);
    // pantaloncini: dall'orlo in su la stoffa sta flare fuori dalla coscia (contando il gonfiaggio di athlete3d.js),
    // sotto l'orlo quel gonfiaggio si toglie (gamba nuda); verso la vita tutto si spegne
    const b0 = /^(pelvis|thigh_[lr])$/.test(bone(i)) ? looseAt(y) : 0;
    const cHem = smooth(hemH - HEM_DROP, hemH, h), fade = (1 - smooth(3.95, 4.25, h)) * wMid;
    const lip = HEM_LIP * Math.sin(Math.PI * smooth(hemH - HEM_DROP, hemH + 0.08, h));
    flareOff[i] = cHem * fade * (flare + lip - b0) - (1 - cHem) * b0;
  }
  function looseAt(y) { // gonfiaggio di athlete3d.js (con la caviglia nuova)
    const hip = (bp.thigh_l.y + bp.thigh_r.y) / 2, lo = hip - 0.5 * (hip - ankleNew);
    return SHORTS_LOOSE * smooth(lo - 0.02, lo + 0.06, y);
  }

  for (const s of [1, -1]) foot[s].zTip = foot[s].zH + (foot[s].zT - foot[s].zH) * foot[s].kz; // punta dopo l'accorciamento
  // ossa: ginocchio e caviglia alle altezze nuove; la palla del piede segue la lunghezza nuova del piede
  const bones = {};
  for (const n of ['calf_l', 'calf_r', 'foot_l', 'foot_r', 'ball_l', 'ball_r']) {
    const p = bp[n].clone(); p.y = remap(p.y);
    if (n.startsWith('ball')) { const F = foot[Math.sign(p.x) || 1]; p.z = F.zH + (p.z - F.zH) * F.kz; }
    bones[n] = p;
  }
  return { ground, T, crotch, kneeY: kneeNew, ankleY: ankleNew, hemY: Y(hemH), bones, foot, flareOff, orig };
}

// normali lisce ricalcolate (vertici uguali saldati per posizione originale) per i vertici sotto yTop
function legNormals(P, I, N, orig, yTop, yFade) {
  const nv = P.length / 3, key = new Map(), id = new Int32Array(nv);
  for (let i = 0; i < nv; i++) { const k = `${Math.round(orig[i * 3] * 1e5)},${Math.round(orig[i * 3 + 1] * 1e5)},${Math.round(orig[i * 3 + 2] * 1e5)}`; if (!key.has(k)) key.set(k, key.size); id[i] = key.get(k); }
  const acc = new Float32Array(key.size * 3);
  for (let t = 0; t < I.length; t += 3) {
    const a = I[t], b = I[t + 1], c = I[t + 2];
    const ux = P[b * 3] - P[a * 3], uy = P[b * 3 + 1] - P[a * 3 + 1], uz = P[b * 3 + 2] - P[a * 3 + 2];
    const vx = P[c * 3] - P[a * 3], vy = P[c * 3 + 1] - P[a * 3 + 1], vz = P[c * 3 + 2] - P[a * 3 + 2];
    const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
    for (const v of [a, b, c]) { const j = id[v] * 3; acc[j] += nx; acc[j + 1] += ny; acc[j + 2] += nz; }
  }
  const out = new Float32Array(nv * 3);
  for (let i = 0; i < nv; i++) {
    const j = id[i] * 3, l = Math.hypot(acc[j], acc[j + 1], acc[j + 2]) || 1, w = 1 - smooth(yFade, yTop, P[i * 3 + 1]);
    let x = N.getX(i), y = N.getY(i), z = N.getZ(i);
    if (w > 0) { x = lerp(x, acc[j] / l, w); y = lerp(y, acc[j + 1] / l, w); z = lerp(z, acc[j + 2] / l, w); const m = Math.hypot(x, y, z) || 1; x /= m; y /= m; z /= m; }
    out[i * 3] = x; out[i * 3 + 1] = y; out[i * 3 + 2] = z;
  }
  return out;
}

// ---------------------------------------------------------------- collegamento al modello (una riga in athlete3d.js)
export function shapeLegs(m) {
  const geo = m.mesh.geometry, PA = geo.attributes.position, NA = geo.attributes.normal, nv = PA.count;
  const P = new Float32Array(nv * 3); for (let i = 0; i < nv; i++) { P[i * 3] = PA.getX(i); P[i * 3 + 1] = PA.getY(i); P[i * 3 + 2] = PA.getZ(i); }
  const I = geo.index.array, r = deformLegs(P, I, i => m.boneOf[i], m.bp);
  const N = legNormals(P, I, NA, r.orig, r.ground + ZONE_TOP * r.T, r.ground + (ZONE_TOP - 0.2) * r.T);
  for (let i = 0; i < nv; i++) {
    const o = r.flareOff[i];
    PA.setXYZ(i, P[i * 3] + N[i * 3] * o, P[i * 3 + 1] + N[i * 3 + 1] * o, P[i * 3 + 2] + N[i * 3 + 2] * o);
    NA.setXYZ(i, N[i * 3], N[i * 3 + 1], N[i * 3 + 2]);
  }
  PA.needsUpdate = NA.needsUpdate = true; geo.computeBoundingBox(); geo.computeBoundingSphere();
  moveBones(m, r.bones);
  m.L.kneeY = r.kneeY; m.L.ankleY = r.ankleY;
  m.legs = r; delete r.orig; delete r.flareOff;
  const prev = m.paint;
  m.paint = function (kit, look, opt, size) { const cv = prev.call(this, kit, look, opt, size); paintLegs(this, cv, kit, look, size); return cv; };
}

// sposta le ossa (posizione nello spazio della mesh) e ricalcola le matrici di legame: le clip toccano solo le rotazioni
function moveBones(m, target) {
  const sk = m.mesh.skeleton, bind = m.mesh.bindMatrix, inv = new THREE.Matrix4(), w = new THREE.Vector3();
  m.scene.updateMatrixWorld(true);
  const order = ['calf_l', 'calf_r', 'foot_l', 'foot_r', 'ball_l', 'ball_r']; // padri prima dei figli
  const idx = order.map(n => sk.bones.findIndex(b => b.name === n));
  // legame di ogni osso (posa di riposo · inversa) preso prima di spostare qualcosa: i figli seguono i padri
  const rest = idx.map(j => (j < 0 ? null : new THREE.Matrix4().multiplyMatrices(sk.bones[j].matrixWorld, sk.boneInverses[j])));
  for (let k = 0; k < order.length; k++) {
    const n = order[k], j = idx[k]; if (j < 0) continue;
    const b = sk.bones[j];
    w.copy(target[n]).applyMatrix4(bind);
    b.position.copy(w.applyMatrix4(inv.copy(b.parent.matrixWorld).invert()));
    b.updateMatrixWorld(true);
    sk.boneInverses[j].copy(b.matrixWorld).invert().multiply(rest[k]);
    m.bp[n].copy(target[n]);
  }
}

// ---------------------------------------------------------------- pittura di gambe e piedi
const legTexels = new WeakMap(), layers = new WeakMap();
function layerOf(m, S) { // canvas di appoggio in memoria, uno per lato della texture
  let per = layers.get(m); if (!per) layers.set(m, per = new Map());
  if (!per.has(S)) per.set(S, cpuCanvas(S, S));
  return per.get(S);
}
function texelsOf(m, M) { // indici dei texel di gamba e piede (una volta per lato della texture)
  let per = legTexels.get(m); if (!per) legTexels.set(m, per = new Map());
  if (per.has(M.S)) return per.get(M.S);
  const list = []; for (let i = 0; i < M.cls.length; i++) if (M.cls[i] === C_LEG || M.cls[i] === C_FOOT) list.push(i);
  const out = Uint32Array.from(list); per.set(M.S, out); return out;
}

export function paintLegs(m, cv, kit, look, S) {
  const M = m.texMap(S), D = m.detailAt(S), G = m.legs, T = G.T, gr = G.ground, st = normalizeKitStyle(kit.style);
  // si dipinge su uno strato a parte (trasparente fuori da gambe e piedi) poi sovrapposto: niente rilettura della texture
  const lay = layerOf(m, S), lg = lay.getContext('2d'), img = lg.createImageData(S, S), px = img.data, list = texelsOf(m, M);
  const skin = rgb(SKINS[look.skin][1]), shorts = rgb(hex(kit.shorts)), socksH = hex(kit.socks), socks = rgb(socksH);
  const altH = hex(kit.shorts === kit.shirt ? (lumH(hex(kit.shirt)) > 0.5 ? 0x1b1b1b : 0xffffff) : kit.shorts), alt = rgb(altH);
  const stripe = rgb(hex(kit.shirt === kit.shorts ? 0xffffff : kit.shirt)), hem = rgb(shade(hex(kit.shorts), 0.78));
  const trim = rgb(lumH(socksH) > 0.5 ? shade(socksH, 0.75) : altH), cuff = rgb(shade(socksH, 0.84));
  const bootH = BOOTS[look.boots][1], boot = rgb(bootH), heel = rgb(shade(bootH, lumH(bootH) > 0.5 ? 0.9 : 1.25));
  const acc = rgb(lumH(bootH) > 0.6 ? '#1b1b1f' : (look.boots === 0 ? '#e9e9e9' : '#ffffff')), sole = rgb(SOLE), stud = rgb(shade(SOLE, 0.62));
  const hemY = G.kneeY + (st.shorts === 1 ? LEG.shortsLongAbove : LEG.shortsAbove) * T;
  const sockTop = st.socks === 1 ? gr + 1.0 * T : st.socks === 2 ? G.kneeY - 0.55 * T : G.kneeY - LEG.sockBelow * T;
  const soleY = gr + 0.065 * T, col = [0, 0, 0];
  const set = c => { col[0] = c[0]; col[1] = c[1]; col[2] = c[2]; };
  const mix = (c, a) => { if (a <= 0) return; a = Math.min(1, a); col[0] += (c[0] - col[0]) * a; col[1] += (c[1] - col[1]) * a; col[2] += (c[2] - col[2]) * a; };
  const edge = d => Math.max(0, Math.min(1, 0.5 + d / AA)); // 1 sopra la linea, 0 sotto, bordo morbido
  const band = (d, half) => Math.max(0, Math.min(1, 0.5 + (half - Math.abs(d)) / AA)); // fascia di semialtezza half
  for (let n = 0; n < list.length; n++) {
    const i = list[n], x = M.pos[i * 3], y = M.pos[i * 3 + 1], z = M.pos[i * 3 + 2], nx = M.nrm[i * 3], ny = M.nrm[i * 3 + 1];
    const s = x >= 0 ? 1 : -1, F = G.foot[s], u = Math.max(0, Math.min(1, (z - F.zH) / (F.zTip - F.zH))); // 0 tallone → 1 punta
    // bordo della scarpa: alto dietro, più basso sul collo del piede; la parte davanti è tutta scarpa
    const collar = gr + interp(COLLAR, u) * T;
    let cloth = true;
    // gamba: pelle, calzettone, pantaloncini
    set(skin); cloth = false;
    if (y < sockTop + AA) {
      set(socks); cloth = true;
      if (st.socks === 2) { mix(cuff, edge(y - (sockTop - 0.2 * T))); mix(alt, band(y - (sockTop - 0.2 * T), 0.004)); } // risvolto
      else mix(trim, band(y - (sockTop - 0.02), 0.008));
      const a = edge(y - sockTop); if (a > 0) { mix(skin, a); if (a > 0.5) cloth = false; }
    }
    if (y > hemY - AA) {
      const a = edge(y - hemY); mix(shorts, a);
      if (a > 0.5) {
        cloth = true;
        if (x * nx > 0) mix(stripe, smooth(0.95, 0.975, Math.abs(nx)) * edge(y - hemY - 0.05 * T)); // banda laterale
        mix(hem, 0.7 * edge(hemY + 0.045 * T - y));                                               // orlo
      }
    }
    // scarpa
    if (y < collar + AA) {
      const a = 1 - edge(y - collar); const keep = [col[0], col[1], col[2]];
      set(boot);
      if (u < 0.13 && y > soleY) mix(heel, 0.6);                                     // contrafforte del tallone
      const line = gr + (0.1 + 0.16 * smooth(0.15, 0.7, u)) * T;                     // banda laterale (lato esterno)
      if (x * nx > 0) mix(acc, band(y - line, 0.02 * T) * smooth(0.4, 0.55, Math.abs(nx)) * smooth(0.1, 0.16, u) * (1 - smooth(0.72, 0.8, u)));
      mix(sole, edge(soleY - y));
      if (ny < -0.6) { // sotto la suola: tacchetti accennati (4 sotto la pianta, 2 sotto il tallone)
        const lx = (x - F.cx) / (LEG.footW * T / 2);
        const studs = [[0.3, -0.45], [0.3, 0.45], [0.58, -0.5], [0.58, 0.5], [0.8, 0], [0.08, -0.4], [0.08, 0.4]];
        for (const [su, sx] of studs) if (Math.hypot((u - su) * (LEG.footL / 0.11), (lx - sx) * (LEG.footW / 2 / 0.11)) < 1) set(stud);
      }
      cloth = true;
      col[0] = lerp(keep[0], col[0], a); col[1] = lerp(keep[1], col[1], a); col[2] = lerp(keep[2], col[2], a);
    }
    let rr = col[0], gg = col[1], bb = col[2];
    if (D) { const f = 1 + (cloth ? DETAIL_K.cloth : DETAIL_K.skin) * (D[i] - 1); rr *= f; gg *= f; bb *= f; }
    const o = i * 4; px[o] = rr; px[o + 1] = gg; px[o + 2] = bb; px[o + 3] = 255;
  }
  dilateFrom(px, S, M.cls, list, 3);
  lg.putImageData(img, 0, 0);
  cv.getContext('2d').drawImage(lay, 0, 0);
}

// allarga di qualche texel i colori nuovi fuori dalle isole UV di gambe e piedi (solo texel vuoti della zona del corpo)
function dilateFrom(px, S, cls, list, n) {
  const bodyMax = Math.floor(S * 896 / 1024); // sotto: tassello degli occhi e capelli, non si tocca
  let front = list; const done = new Uint8Array(S * S);
  for (let i = 0; i < list.length; i++) done[list[i]] = 1;
  for (let it = 0; it < n; it++) {
    const next = [];
    for (let k = 0; k < front.length; k++) {
      const j = front[k], x = j % S, y = (j / S) | 0;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const xx = x + dx, yy = y + dy; if (xx < 0 || yy < 0 || xx >= S || yy >= bodyMax) continue;
        const i = yy * S + xx; if (cls[i] || done[i]) continue;
        done[i] = 1; px[i * 4] = px[j * 4]; px[i * 4 + 1] = px[j * 4 + 1]; px[i * 4 + 2] = px[j * 4 + 2]; px[i * 4 + 3] = 255; next.push(i);
      }
    }
    front = next;
  }
}
