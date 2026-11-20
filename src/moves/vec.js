// Piccola matematica di vettori [x, y, z] e quaternioni [x, y, z, w] su array, senza three.js: serve ai movimenti
// calcolati (src/moves/*), che sono funzioni pure del tempo e girano nei test in Node.
export const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
export const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
export const mul = (a, k) => [a[0] * k, a[1] * k, a[2] * k];
export const madd = (a, b, k) => [a[0] + b[0] * k, a[1] + b[1] * k, a[2] + b[2] * k];
export const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
export const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
export const len = a => Math.hypot(a[0], a[1], a[2]);
export const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]);
export const norm = a => { const l = len(a) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };
export const lerp = (a, b, k) => [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k];
export const clamp = (x, a, b) => Math.max(a, Math.min(b, x));
export const smooth = x => { const t = clamp(x, 0, 1); return t * t * (3 - 2 * t); };
// gobba 0 → 1 → 0 tra a e b (seno), 0 fuori
export const bump = (x, a, b) => (x <= a || x >= b) ? 0 : Math.sin(Math.PI * (x - a) / (b - a));

export const QI = [0, 0, 0, 1];
export function qAxis(ax, ang) { const s = Math.sin(ang / 2), n = norm(ax); return [n[0] * s, n[1] * s, n[2] * s, Math.cos(ang / 2)]; }
export function qMul(a, b) {
  return [a[3] * b[0] + a[0] * b[3] + a[1] * b[2] - a[2] * b[1], a[3] * b[1] - a[0] * b[2] + a[1] * b[3] + a[2] * b[0],
    a[3] * b[2] + a[0] * b[1] - a[1] * b[0] + a[2] * b[3], a[3] * b[3] - a[0] * b[0] - a[1] * b[1] - a[2] * b[2]];
}
export const qConj = q => [-q[0], -q[1], -q[2], q[3]];
export function qRot(q, v) { // v ruotato da q
  const [x, y, z, w] = q, ix = w * v[0] + y * v[2] - z * v[1], iy = w * v[1] + z * v[0] - x * v[2], iz = w * v[2] + x * v[1] - y * v[0], iw = -x * v[0] - y * v[1] - z * v[2];
  return [ix * w + iw * -x + iy * -z - iz * -y, iy * w + iw * -y + iz * -x - ix * -z, iz * w + iw * -z + ix * -y - iy * -x];
}
export function qNorm(q) { const l = Math.hypot(q[0], q[1], q[2], q[3]) || 1; return [q[0] / l, q[1] / l, q[2] / l, q[3] / l]; }
export function qSlerp(a, b, t) {
  let c = a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3], bb = b;
  if (c < 0) { c = -c; bb = [-b[0], -b[1], -b[2], -b[3]]; }
  if (c > 0.9995) return qNorm([a[0] + (bb[0] - a[0]) * t, a[1] + (bb[1] - a[1]) * t, a[2] + (bb[2] - a[2]) * t, a[3] + (bb[3] - a[3]) * t]);
  const th = Math.acos(c), s = Math.sin(th), ka = Math.sin((1 - t) * th) / s, kb = Math.sin(t * th) / s;
  return [a[0] * ka + bb[0] * kb, a[1] * ka + bb[1] * kb, a[2] * ka + bb[2] * kb, a[3] * ka + bb[3] * kb];
}
// rotazione del corpo: giro (attorno a y), poi inclinazione in avanti (pitch > 0: la testa va verso +z),
// poi inclinazione di lato (roll > 0: la testa va verso +x, il fianco sinistro del giocatore)
export function qBody(yaw, pitch = 0, roll = 0) { return qMul(qAxis([0, 1, 0], yaw), qMul(qAxis([1, 0, 0], pitch), qAxis([0, 0, 1], -roll))); }
// quaternione da una base ortonormale (colonne x, y, z)
export function qBasis(x, y, z) {
  const m00 = x[0], m10 = x[1], m20 = x[2], m01 = y[0], m11 = y[1], m21 = y[2], m02 = z[0], m12 = z[1], m22 = z[2], tr = m00 + m11 + m22;
  let q;
  if (tr > 0) { const s = 0.5 / Math.sqrt(tr + 1); q = [(m21 - m12) * s, (m02 - m20) * s, (m10 - m01) * s, 0.25 / s]; }
  else if (m00 > m11 && m00 > m22) { const s = 2 * Math.sqrt(1 + m00 - m11 - m22); q = [0.25 * s, (m01 + m10) / s, (m02 + m20) / s, (m21 - m12) / s]; }
  else if (m11 > m22) { const s = 2 * Math.sqrt(1 + m11 - m00 - m22); q = [(m01 + m10) / s, 0.25 * s, (m12 + m21) / s, (m02 - m20) / s]; }
  else { const s = 2 * Math.sqrt(1 + m22 - m00 - m11); q = [(m02 + m20) / s, (m12 + m21) / s, 0.25 * s, (m10 - m01) / s]; }
  return qNorm(q);
}
// rotazione che porta la coppia (a1, b1) su (a2, b2): a esatto, b il più vicino possibile (Gram-Schmidt)
export function qAlign(a1, b1, a2, b2) {
  const f = (a, b) => { const x = norm(a), z = norm(cross(x, b)), y = cross(z, x); return [x, y, z]; };
  const [x1, y1, z1] = f(a1, b1), [x2, y2, z2] = f(a2, b2);
  return qMul(qBasis(x2, y2, z2), qConj(qBasis(x1, y1, z1)));
}
