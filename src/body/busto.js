// Busto, spalle, braccia e mani del calciatore (modello "athlete", src/athlete3d.js), portati alle proporzioni di
// PROPORZIONI.md senza rigenerare il glb. Tutto si fa una volta, al caricamento, nella posa di legame (posa a T:
// y in alto, z in avanti, braccia lungo x):
//   - busto: sezioni ristrette in larghezza e profondità (petto 1,45 × 0,95 T, vita 1,15 × 0,8 T);
//   - spalle: braccia avvicinate al corpo (da deltoide a deltoide 1,9 T), ossa comprese;
//   - braccia: omero e avambraccio allungati (gomito all'altezza della vita), sezioni sgonfiate (bicipite 0,42 T,
//     avambraccio 0,36 T), ossa comprese;
//   - mani: più corte (0,75 T), dita un po' chiuse e piegate (mano a riposo, non ad artiglio);
//   - maglia morbida: la superficie del busto è lisciata (niente addominali e pettorali "dipinti" sotto la stoffa),
//     un filo più gonfia sopra l'orlo; normali ricalcolate nella zona;
//   - pittura: scollo pulito con bordi morbidi, orli e righe senza scalini, stemma, cognome e numero filtrati.
// Le giunzioni con il collo (pesi sull'osso del collo o della testa) e con i pantaloncini (sotto BOT_H) non si muovono.
// Uso (src/athlete3d.js, all'inizio di headFrame): applyBusto(this)
import * as THREE from 'three';

// ---------------------------------------------------------------- misure obiettivo (in T = altezza / 8)
export const TARGET = { shoulders: 1.9, chestW: 1.45, chestD: 0.95, waistW: 1.15, waistD: 0.8, upperArm: 1.29, foreArm: 1.2, hand: 0.75, biceps: 0.42, forearmW: 0.36 };
// L'omero si misura dal centro della spalla (6,44 T): con l'acromion a ~6,6 T dà i 1,45 T di PROPORZIONI.md
// e mette il gomito a ~5,15 T (vita); la punta delle dita a braccia giù cade a ~3,2 T.
const ARM_IN = 0.12;         // T: di quanto le spalle (e le braccia) si avvicinano al corpo
const BOT_H = 4.75;          // T: sotto quest'altezza il busto non si tocca (orlo della maglia, pantaloncini)
// rapporti di larghezza (x) e profondità (z) del busto per altezza (T da terra), misurati sul modello di partenza
const SX = [[4.75, 1], [5.0, 0.97], [5.25, 0.965], [5.5, 0.965], [5.6, 0.96], [5.75, 0.935], [6.0, 0.94], [6.2, 0.94], [6.45, 0.97], [6.7, 1]];
const SZ = [[4.75, 1], [5.1, 0.96], [5.3, 0.9], [5.4, 0.86], [5.5, 0.83], [5.75, 0.81], [6.0, 0.785], [6.15, 0.78], [6.3, 0.8], [6.5, 0.88], [6.75, 1]];
const ARMPIT = [5.85, 6.15]; // T: sopra l'ascella il busto segue lo spostamento delle braccia
const DELT_K = 0.7;          // cupola della spalla (sopra l'asse del braccio, verso l'esterno) abbassata: spalla meno "da supereroe"
const NECK_FREE = 0.32;      // T: entro questa distanza dall'asse il busto alto non si sposta di lato (attaccatura del collo)
// spessore delle braccia (rapporto attorno all'osso) lungo il braccio: 0 = spalla, 1 = gomito, 2 = polso, 3 = punta delle dita
const ARM_K = [[0, 0.6], [0.3, 0.8], [0.5, 0.84], [0.9, 0.78], [1.1, 0.72], [1.5, 0.7], [1.9, 0.78], [2.05, 0.86], [3, 0.86]];
const HAND = { knuckle: 0.5, curl: 0.75, gather: 0.75, thumbZ: [0.045, 0.065] }; // nocche a metà mano, piega (rad), dita più unite
// maglia morbida: lisciatura (Taubin) del busto, e un filo di stoffa che gonfia sopra l'orlo
const SOFT = { iters: 6, lambda: 0.5, mu: -0.53, from: 4.55, to: 6.55, blouse: 0.006 };
const SHIRT_BOT_OFF = 0.035; // m sopra l'anca: orlo della maglia (come in src/athlete3d.js)

const smooth = (a, b, x) => { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
const knots = (K, x) => { if (x <= K[0][0]) return K[0][1]; for (let i = 1; i < K.length; i++) if (x <= K[i][0]) { const [a, va] = K[i - 1], [b, vb] = K[i]; return va + (vb - va) * (x - a) / (b - a); } return K[K.length - 1][1]; };

// posizioni delle ossa in posa di legame
function bindPos(mesh) {
  const m = new THREE.Matrix4(), bp = {};
  mesh.skeleton.bones.forEach((b, j) => { m.copy(mesh.skeleton.boneInverses[j]).invert(); bp[b.name] = new THREE.Vector3().setFromMatrixPosition(m); });
  return bp;
}

// vertici con la stessa posizione (cuciture delle UV) → un solo nodo: lisciatura e normali uguali sui due lati
function weld(P) {
  const map = new Map(), id = new Int32Array(P.length / 3); let n = 0;
  for (let i = 0; i < id.length; i++) {
    const k = Math.round(P[i * 3] * 1e4) + ',' + Math.round(P[i * 3 + 1] * 1e4) + ',' + Math.round(P[i * 3 + 2] * 1e4);
    let v = map.get(k); if (v === undefined) { v = n++; map.set(k, v); } id[i] = v;
  }
  return { id, n };
}

// ---------------------------------------------------------------- geometria (e ossa delle braccia)
export function deformBusto(mesh) {
  const geo = mesh.geometry, PA = geo.attributes.position, NA = geo.attributes.normal, JA = geo.attributes.skinIndex, WA = geo.attributes.skinWeight;
  const names = mesh.skeleton.bones.map(b => b.name), bp = bindPos(mesh), nv = PA.count;
  const P = new Float32Array(nv * 3); for (let i = 0; i < nv; i++) { P[i * 3] = PA.getX(i); P[i * 3 + 1] = PA.getY(i); P[i * 3 + 2] = PA.getZ(i); }
  let y0 = Infinity, y1 = -Infinity; for (let i = 0; i < nv; i++) { y0 = Math.min(y0, P[i * 3 + 1]); y1 = Math.max(y1, P[i * 3 + 1]); }
  const T = (y1 - y0) / 8, H = y => (y - y0) / T;
  const sh = bp.upperarm_l, el = bp.lowerarm_l, wr = bp.hand_l, shX = Math.abs(sh.x), elX = Math.abs(el.x), wrX = Math.abs(wr.x), shY = sh.y;
  const up = elX - shX, fo = wrX - elX, D = ARM_IN * T, up2 = TARGET.upperArm * T, fo2 = TARGET.foreArm * T;
  // lunghezza della mano (dal polso alla punta delle dita) e scala per arrivare a TARGET.hand
  let tip = 0; for (let i = 0; i < nv; i++) tip = Math.max(tip, Math.abs(P[i * 3]));
  const handL = tip - wrX, kH = TARGET.hand * T / handL;
  // pesi per vertice: braccia, collo/testa, cosce
  const arm = new Set(['upperarm_l', 'lowerarm_l', 'hand_l', 'upperarm_r', 'lowerarm_r', 'hand_r'].map(n => names.indexOf(n)));
  const neck = new Set(['neck_01', 'Head'].map(n => names.indexOf(n))), thigh = new Set(['thigh_l', 'thigh_r'].map(n => names.indexOf(n)));
  const wA = new Float32Array(nv), wN = new Float32Array(nv), wL = new Float32Array(nv);
  for (let i = 0; i < nv; i++) for (let k = 0; k < 4; k++) {
    const j = JA.getComponent(i, k), w = WA.getComponent(i, k);
    if (arm.has(j)) wA[i] += w; if (neck.has(j)) wN[i] += w; if (thigh.has(j)) wL[i] += w;
  }
  // centro della sezione del busto (z) per fasce di 0,1 T
  const NB = 90, zlo = new Float32Array(NB).fill(Infinity), zhi = new Float32Array(NB).fill(-Infinity);
  for (let i = 0; i < nv; i++) { if (wA[i] > 0.3 || wN[i] > 0.3) continue; const b = Math.round(H(P[i * 3 + 1]) * 10); if (b < 0 || b >= NB) continue; zlo[b] = Math.min(zlo[b], P[i * 3 + 2]); zhi[b] = Math.max(zhi[b], P[i * 3 + 2]); }
  const zc0 = new Float32Array(NB); let last = 0;
  for (let b = 0; b < NB; b++) { if (zhi[b] > zlo[b]) last = (zlo[b] + zhi[b]) / 2; zc0[b] = last; }
  const zcAt = h => { const f = Math.max(0, Math.min(NB - 1.001, h * 10)), b = Math.floor(f), t = f - b; let a = 0, n = 0; for (let k = -2; k <= 2; k++) { const q = Math.max(0, Math.min(NB - 1, b + k)); a += zc0[q] * (1 - t) + zc0[Math.min(NB - 1, q + 1)] * t; n++; } return a / n; };
  // asse del braccio (y, z) e mappa lungo il braccio (|x| di partenza → |x| nuovo, prima dello spostamento verso il corpo)
  const along = a => a < shX ? a : a < elX ? shX + (a - shX) * up2 / up : a < wrX ? shX + up2 + (a - elX) * fo2 / fo : shX + up2 + fo2 + (a - wrX) * kH;
  const segOf = a => a < shX ? 0 : a < elX ? (a - shX) / up : a < wrX ? 1 + (a - elX) / fo : 2 + Math.min(1, (a - wrX) / handL);
  const axisZ = s => s < 1 ? sh.z + (el.z - sh.z) * Math.max(0, s) : s < 2 ? el.z + (wr.z - el.z) * (s - 1) : wr.z;

  // mano (coordinate relative al polso, di partenza: x lungo il braccio verso le dita, y su, z avanti):
  // più corta (kH), più sottile, dita un po' più unite e piegate attorno alla linea delle nocche verso il palmo (-y)
  const kn = HAND.knuckle * handL, kc = knots(ARM_K, 3);
  const handFix = (rx, ry, rz) => {
    const thumb = smooth(HAND.thumbZ[0], HAND.thumbZ[1], rz) * (1 - smooth(0.6 * handL, 0.75 * handL, rx));
    const fing = smooth(kn * 0.85, kn * 1.15, rx) * (1 - thumb), fz = 0.005;
    let x = rx, y = ry, z = fz + (rz - fz) * (1 - (1 - HAND.gather) * fing);
    const ang = HAND.curl * Math.min(1, Math.max(0, x - kn) / (handL - kn)) * fing, py = -0.006;
    if (ang > 0) { const dx = x - kn, dy = y - py, c = Math.cos(ang), si = Math.sin(ang); x = kn + dx * c + dy * si; y = py - dx * si + dy * c; }
    return [x * kH, y * kc, z * kc];
  };

  const map = (i, x, y, z) => {
    const a = Math.abs(x), s = Math.sign(x) || 1, h = H(y), wa = wA[i];
    const keep = (1 - smooth(0.05, 0.5, wN[i])) * (1 - smooth(0.05, 0.5, wL[i])) * smooth(BOT_H - 0.05, BOT_H + 0.15, h);
    // busto
    const sx = knots(SX, h), sz = knots(SZ, h), band = smooth(ARMPIT[0], ARMPIT[1], h);
    const lat = smooth(NECK_FREE * T, shX, a), E = (D - shX * (1 - sx)) * band;
    const at = Math.min(a, shX) * sx + Math.max(0, a - shX) - E * lat;
    const zc = zcAt(h), zt = zc + (z - zc) * sz;
    const ty = y > shY ? y - (y - shY) * (1 - DELT_K) * smooth(0.45 * T, shX, a) * keep : y;
    const tx = s * (a + (at - a) * keep), tz = z + (zt - z) * keep * (1 - wa);
    if (wa <= 0) return [tx, ty, tz];
    // braccio
    const sg = segOf(a), k = knots(ARM_K, sg), ax = axisZ(sg);
    let q = [along(a) - (a < shX ? D * lat : D), shY + (y - shY) * k, ax + (z - ax) * k];
    if (a > wrX) { const o = handFix(a - wrX, y - wr.y, z - wr.z); q = [shX + up2 + fo2 - D + o[0], wr.y + o[1], wr.z + o[2]]; }
    // mescolati con i pesi dello scheletro (lisci tra spalla e busto): nessun buco all'ascella
    return [tx + (s * q[0] - tx) * wa, ty + (q[1] - ty) * wa, tz + (q[2] - tz) * wa];
  };

  const out = new Float32Array(nv * 3);
  for (let i = 0; i < nv; i++) { const r = map(i, P[i * 3], P[i * 3 + 1], P[i * 3 + 2]); out[i * 3] = r[0]; out[i * 3 + 1] = r[1]; out[i * 3 + 2] = r[2]; }

  softShirt(geo, P, out, { wA, wN, wL, H, botH: H((bp.thigh_l.y + bp.thigh_r.y) / 2 + SHIRT_BOT_OFF) });
  moveArmBones(mesh, bp, { D, du: up2 - up, df: fo2 - fo });
  return { T, D, kH };
}

// maglia morbida: lisciatura (Taubin) del busto su nodi saldati, solo dove la maglia c'è e lontano dalle giunzioni;
// normali ricalcolate dalla superficie nuova nella zona; stoffa un filo gonfia sopra l'orlo. Scrive posizioni e normali.
function softShirt(geo, P, out, { wA, wN, wL, H, botH }) {
  // maglia morbida: lisciatura del busto (nodi saldati), solo dove la maglia c'è e lontano dalle giunzioni
  const PA = geo.attributes.position, NA = geo.attributes.normal, nv = PA.count;
  const W = weld(P), nbr = Array.from({ length: W.n }, () => new Set()), I = geo.index.array;
  for (let t = 0; t < I.length; t += 3) for (let e = 0; e < 3; e++) { const a = W.id[I[t + e]], b = W.id[I[t + (e + 1) % 3]]; if (a !== b) { nbr[a].add(b); nbr[b].add(a); } }
  const NP = new Float64Array(W.n * 3), cnt = new Uint16Array(W.n), mk = new Float32Array(W.n), zone = new Float32Array(W.n);
  for (let i = 0; i < nv; i++) {
    const w = W.id[i]; if (cnt[w]++) continue;
    NP[w * 3] = out[i * 3]; NP[w * 3 + 1] = out[i * 3 + 1]; NP[w * 3 + 2] = out[i * 3 + 2];
    const h = H(P[i * 3 + 1]), free = (1 - smooth(0.02, 0.3, wN[i])) * (1 - smooth(0.02, 0.3, wL[i]));
    mk[w] = free * (1 - smooth(0.2, 0.6, wA[i])) * smooth(SOFT.from, SOFT.from + 0.3, h) * (1 - smooth(SOFT.to - 0.25, SOFT.to, h));
    zone[w] = free * smooth(botH - 0.15, botH + 0.1, h) * (1 - smooth(6.6, 6.85, h));
  }
  const tmp = new Float64Array(W.n * 3);
  for (let it = 0; it < SOFT.iters * 2; it++) {
    const f = it % 2 ? SOFT.mu : SOFT.lambda;
    for (let v = 0; v < W.n; v++) {
      if (!mk[v] || !nbr[v].size) { tmp[v * 3] = NP[v * 3]; tmp[v * 3 + 1] = NP[v * 3 + 1]; tmp[v * 3 + 2] = NP[v * 3 + 2]; continue; }
      let ax = 0, ay = 0, az = 0; for (const u of nbr[v]) { ax += NP[u * 3]; ay += NP[u * 3 + 1]; az += NP[u * 3 + 2]; }
      const n = nbr[v].size, k = f * mk[v];
      tmp[v * 3] = NP[v * 3] + (ax / n - NP[v * 3]) * k; tmp[v * 3 + 1] = NP[v * 3 + 1] + (ay / n - NP[v * 3 + 1]) * k; tmp[v * 3 + 2] = NP[v * 3 + 2] + (az / n - NP[v * 3 + 2]) * k;
    }
    NP.set(tmp);
  }
  // normali saldate dalla superficie nuova (pesate per area), mescolate alle vecchie fuori dalla zona
  const FN = new Float64Array(W.n * 3);
  for (let t = 0; t < I.length; t += 3) {
    const a = W.id[I[t]], b = W.id[I[t + 1]], c = W.id[I[t + 2]];
    const ux = NP[b * 3] - NP[a * 3], uy = NP[b * 3 + 1] - NP[a * 3 + 1], uz = NP[b * 3 + 2] - NP[a * 3 + 2];
    const vx = NP[c * 3] - NP[a * 3], vy = NP[c * 3 + 1] - NP[a * 3 + 1], vz = NP[c * 3 + 2] - NP[a * 3 + 2];
    const nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
    for (const q of [a, b, c]) { FN[q * 3] += nx; FN[q * 3 + 1] += ny; FN[q * 3 + 2] += nz; }
  }
  // stoffa un filo gonfia appena sopra l'orlo (si appoggia sui pantaloncini)
  const blouse = h => SOFT.blouse * smooth(botH, botH + 0.12, h) * (1 - smooth(botH + 0.15, botH + 0.55, h));
  for (let i = 0; i < nv; i++) {
    const w = W.id[i], h = H(P[i * 3 + 1]);
    let nx = FN[w * 3], ny = FN[w * 3 + 1], nz = FN[w * 3 + 2]; const l = Math.hypot(nx, ny, nz) || 1; nx /= l; ny /= l; nz /= l;
    // zona del busto e delle braccia: normali nuove; giunzioni: quelle del modello
    const zn = Math.max(zone[w], wA[i] * (1 - smooth(0.02, 0.3, wN[i])) * smooth(5.6, 5.9, h));
    let mx = NA.getX(i) + (nx - NA.getX(i)) * zn, my = NA.getY(i) + (ny - NA.getY(i)) * zn, mz = NA.getZ(i) + (nz - NA.getZ(i)) * zn;
    const ml = Math.hypot(mx, my, mz) || 1; mx /= ml; my /= ml; mz /= ml;
    const bl = blouse(h) * (1 - smooth(0.02, 0.3, wL[i])) * (1 - wA[i]);
    PA.setXYZ(i, NP[w * 3] + nx * bl, NP[w * 3 + 1] + ny * bl, NP[w * 3 + 2] + nz * bl);
    NA.setXYZ(i, mx, my, mz);
  }
  PA.needsUpdate = true; NA.needsUpdate = true;
  geo.computeBoundingBox(); geo.computeBoundingSphere();

}

// ossa delle braccia spostate come la mesh: traslazioni locali e matrici di legame (posa a T = posa di legame)
function moveArmBones(mesh, bp, { D, du, df }) {
  // ossa delle braccia: stesse posizioni della mesh (matrici di legame e traslazioni locali)
  const moves = {};
  for (const sd of ['l', 'r']) {
    const s = Math.sign(bp['upperarm_' + sd].x) || 1;
    moves['upperarm_' + sd] = new THREE.Vector3(-s * D, 0, 0);
    moves['lowerarm_' + sd] = new THREE.Vector3(s * (du - D), 0, 0);
    moves['hand_' + sd] = new THREE.Vector3(s * (du + df - D), 0, 0);
  }
  const names = mesh.skeleton.bones.map(b => b.name), bones = mesh.skeleton.bones, inv = mesh.skeleton.boneInverses, q = new THREE.Quaternion(), tmpV = new THREE.Vector3(), sc = new THREE.Vector3(), mt = new THREE.Matrix4();
  for (const n in moves) {
    const j = names.indexOf(n); if (j < 0) continue;
    const b = bones[j], d = moves[n], pd = moves[b.parent && b.parent.name] || new THREE.Vector3();
    const pj = names.indexOf(b.parent.name);
    mt.copy(inv[pj]).invert().decompose(tmpV, q, sc);
    b.position.add(d.clone().sub(pd).applyQuaternion(q.invert()).divide(sc));
  }
  for (const n in moves) { const j = names.indexOf(n); if (j >= 0) inv[j].multiply(mt.makeTranslation(-moves[n].x, -moves[n].y, -moves[n].z)); }
  let root = mesh; while (root.parent) root = root.parent; root.updateMatrixWorld(true);
}

// ---------------------------------------------------------------- pittura della maglia
// scollo: la funzione di src/athlete3d.js dà > 0 dentro lo scollo (pelle), il bordino vicino a 0, con soglie fisse
// (bordino da -0,012 m, bordi larghi AA = 5 mm: poco più di un texel sulla texture da 512, da qui i denti), e passa
// di colpo dalla forma davanti a quella dietro (scalino sui fianchi del collo). Qui la forma è continua (davanti e
// dietro si raccordano, V senza salti, più profonda) e la distanza vera è rimappata sulle soglie fisse in modo che
// i bordi del bordino siano morbidi su COLLAR.soft e il bordino largo COLLAR.w.
const AA_PAINT = 0.005, COLLAR = { w: 0.013, soft: 0.007, r: 0.074, vDepth: 0.06, vHalf: 0.05 };
function neckMap(d) {
  const h = AA_PAINT / 2, s = COLLAR.soft / 2;
  return knots([[-1, -1], [-COLLAR.w - s, -0.012 - h], [-COLLAR.w + s, -0.012 + h], [-s, -h], [s, h], [1, 1]], d);
}
function neckline(collar, x, y, z, LM) {
  const ax = Math.abs(x), base = LM.neckY - 0.012, dz = z - LM.neckZ;
  const back = base + 0.004 + 4 * ax * ax;
  let front = base - 0.026 + 5 * ax * ax;
  const t = smooth(-0.035, 0.035, dz);
  let d = Math.min(y - (back + (front - back) * t), COLLAR.r - Math.hypot(x, Math.max(0, dz) * 1.15)); // dietro conta solo la x: la nuca del modello ha un incavo al centro
  if (collar === 1 && dz > 0) { // V sul petto: la pelle scende al centro, punta appena arrotondata
    const vy = front - COLLAR.vDepth * Math.max(0, 1 - ax / COLLAR.vHalf) ** 1.2;
    d = Math.max(d, Math.min(y - vy, (COLLAR.vHalf - ax) * 0.8));
  }
  return neckMap(d);
}

// sfocatura leggera (premoltiplicata) di un canvas proiettato: niente scalini quando cade su pochi texel
function soften(cv, r) {
  if (!cv || r <= 0) return cv;
  const { w, h, d } = cv, src = new Float32Array(w * h * 4), out = new Uint8ClampedArray(d.length);
  for (let i = 0; i < w * h; i++) { const a = d[i * 4 + 3] / 255; src[i * 4] = d[i * 4] * a; src[i * 4 + 1] = d[i * 4 + 1] * a; src[i * 4 + 2] = d[i * 4 + 2] * a; src[i * 4 + 3] = d[i * 4 + 3]; }
  const k = [r, 1, r];
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    let c0 = 0, c1 = 0, c2 = 0, c3 = 0, n = 0;
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
      const xx = x + dx, yy = y + dy; if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
      const f = k[dx + 1] * k[dy + 1], o = (yy * w + xx) * 4; c0 += src[o] * f; c1 += src[o + 1] * f; c2 += src[o + 2] * f; c3 += src[o + 3] * f; n += f;
    }
    const o = (y * w + x) * 4, a = c3 / n;
    out[o + 3] = a; if (a > 0) { const m = 255 / a; out[o] = c0 / n * m; out[o + 1] = c1 / n * m; out[o + 2] = c2 / n * m; }
  }
  return { w, h, d: out };
}

// bordi netti (orli delle maniche, righe, bordino, numero) ammorbiditi sulla texture finita: solo texel di busto,
// braccia e mani, solo dove c'è un salto di colore, solo con vicini della stessa isola (niente colori da altre parti)
const EDGE = { cls: [1, 2, 3], min: 40, k: 0.45 };
function softenEdges(cv, M) {
  const S = cv.width, g = cv.getContext('2d'), img = g.getImageData(0, 0, S, S), px = img.data, src = new Uint8ClampedArray(px), cls = M.cls;
  const mine = new Uint8Array(8); for (const c of EDGE.cls) mine[c] = 1;
  for (let y = 1; y < S - 1; y++) for (let x = 1; x < S - 1; x++) {
    const i = y * S + x; if (!mine[cls[i]]) continue;
    let r = 0, gg = 0, b = 0, n = 0, hi = 0;
    for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
      const j = i + dy * S + dx; if (!mine[cls[j]]) continue;
      const o = j * 4; r += src[o]; gg += src[o + 1]; b += src[o + 2]; n++;
      hi = Math.max(hi, Math.abs(src[o] - src[i * 4]) + Math.abs(src[o + 1] - src[i * 4 + 1]) + Math.abs(src[o + 2] - src[i * 4 + 2]));
    }
    if (hi < EDGE.min || n < 4) continue;
    const o = i * 4; px[o] += (r / n - px[o]) * EDGE.k; px[o + 1] += (gg / n - px[o + 1]) * EDGE.k; px[o + 2] += (b / n - px[o + 2]) * EDGE.k;
  }
  g.putImageData(img, 0, 0);
}

// mappa di dettaglio sul busto: viene dalla pelle (pori, muscoli) e sotto la maglia la faceva sembrare dipinta sul
// corpo (e sfilacciava il bordino chiaro). Sul busto e sulla parte di braccio coperta dalla manica corta resta solo
// una traccia, sfocata: pieghe morbide della stoffa.
const DETAIL_TORSO = 0.3;
function softDetail(D, M, sleeveX) {
  if (!D) return D;
  const S = M.S, out = Float32Array.from(D);
  for (let y = 1; y < S - 1; y++) for (let x = 1; x < S - 1; x++) {
    const i = y * S + x, c = M.cls[i]; if (c !== 1 && !(c === 2 && Math.abs(M.pos[i * 3]) < sleeveX)) continue;
    let a = 0, n = 0; for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) { const j = i + dy * S + dx; if (M.cls[j]) { a += D[j]; n++; } }
    out[i] = 1 + (a / n - 1) * DETAIL_TORSO;
  }
  return out;
}

// ---------------------------------------------------------------- tutto insieme (chiamata da src/athlete3d.js)
// Deforma la geometria (prima che athlete3d misuri ossa e punti di riferimento) e sostituisce, solo su questa istanza,
// i pezzi di pittura della maglia: scollo, stemma, cognome e numero, e una passata sui bordi dopo paint().
export function applyBusto(model) {
  deformBusto(model.mesh);
  model.neckline = neckline;
  const crest = model.crestCanvas, back = model.backCanvas, paint = model.paint;
  let texS = 512;
  const blur = () => (texS <= 512 ? 0.6 : 0.3);   // texture da 512 in partita, 1024 nell'editor
  model.crestCanvas = function (cr) { return soften(crest.call(this, cr), blur()); };
  model.backCanvas = function (...a) { return soften(back.apply(this, a), blur()); };
  const detailAt = model.detailAt;
  model.detailAt = function (S) {
    const key = 'busto' + S; if (this.maps.has(key)) return this.maps.get(key);
    const LM = this.L, d = softDetail(detailAt.call(this, S), this.texMap(S), LM.shX + 0.6 * (LM.elX - LM.shX)); this.maps.set(key, d); return d;
  };
  model.paint = function (kit, look, opt, size) {
    texS = size;
    const cv = paint.call(this, kit, look, opt, size);
    softenEdges(cv, this.texMap(size));
    return cv;
  };
}
