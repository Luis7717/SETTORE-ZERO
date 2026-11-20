// Occhi del calciatore realistico (tassello EYE_PX della texture): le 6 forme dell'editor (EYE_SHAPES di src/looks.js).
//
// Perché si dipinge così: le UV del bulbo nel tassello sono ruotate di circa 35° e allargate, e del bulbo si vede solo
// una striscia stretta (la "finestra" dell'orbita, circa 27 × 10 mm). Le palpebre dipinte a righe orizzontali nel
// tassello cadevano quasi tutte nella parte nascosta, per cui le 6 forme sembravano uguali.
// Qui, una volta per modello, si rasterizzano le UV del bulbo (occhio sinistro; il destro ha le stesse UV specchiate):
// ogni cella del tassello sa a che punto del bulbo corrisponde, in millimetri sul viso visto di fronte
// (lx verso la tempia, ly verso l'alto). Con un raggio verso la camera si trova la finestra davvero visibile, e le forme
// (apertura, angoli, palpebre, iride) si disegnano dentro quella finestra, in millimetri: tutto quello che cambia si vede.
// La geometria non cambia (nessuna geometria in più in partita); il salvataggio resta look.eyes 0-5.
import { SKINS, EYE_COLORS } from '../looks.js';
import { rgb, cpuCanvas } from '../players3d.js';

export const EYE_PX = [896, 896, 128, 128]; // tassello degli occhi (EYE_PX di src/athlete3d.js), coordinate su 1024
export const EYE_RES = 256;                 // celle per lato del tassello dipinto (2× il tassello a 1024: bordi morbidi)
const VIS_STEP = 4;                         // passo (celle) della prova di visibilità della finestra
const VIEW_DIR = [0, -0.1, 1];              // direzione verso la camera (dall'alto di poco, come l'editor e la partita)
const NEAR_EYE = 0.03;                      // m: triangoli della testa che possono coprire il bulbo
const AA_MM = 0.35;                         // mm: bordo morbido delle palpebre
// tono della palpebra dipinta sul bulbo rispetto alla pelle: più scuro, perché il bulbo (in fondo all'orbita) guarda in
// alto e prende più luce del viso; con la pelle piena sembrava un alone grigio attorno all'occhio
export const LID_TONE = [0.74, 0.7, 0.7];

// forme: angoli (frazioni della semilarghezza W della finestra, verso il naso e verso la tempia), altezza degli angoli
// (frazioni della semialtezza H), palpebra sopra e sotto (frazioni di H), pienezza (< 1 tonda, ≥ 1 affusolata),
// punto più alto della palpebra sopra (0 naso … 1 tempia), raggio dell'iride (frazioni di H), piega della palpebra
export const EYE_FORMS = [
  { name: 'Tondi', ci: 0.8, co: 0.82, yi: -0.12, yo: 0.02, hu: 1.35, hl: 1.3, a: 0.42, pu: 0.5, iris: 0.92, crease: 0 },
  { name: 'A mandorla', ci: 0.95, co: 1.0, yi: -0.42, yo: 0.5, hu: 0.78, hl: 0.62, a: 1.05, pu: 0.4, iris: 0.86, crease: 0 },
  { name: 'Sottili', ci: 0.78, co: 0.8, yi: -0.05, yo: 0.05, hu: 0.4, hl: 0.34, a: 0.8, pu: 0.5, iris: 0.86, crease: 0.25 },
  { name: 'Grandi', ci: 1.08, co: 1.08, yi: -0.12, yo: 0, hu: 1.45, hl: 1.45, a: 0.5, pu: 0.5, iris: 1.2, crease: 0 },
  { name: 'Allungati', ci: 1.12, co: 1.15, yi: -0.05, yo: 0.08, hu: 0.56, hl: 0.5, a: 0.5, pu: 0.5, iris: 0.86, crease: 0 },
  { name: 'Assonnati', ci: 0.95, co: 0.95, yi: -0.3, yo: -0.36, hu: 0.28, hl: 0.95, a: 0.55, pu: 0.55, iris: 0.92, crease: 0.4 },
];

const clamp01 = x => (x < 0 ? 0 : x > 1 ? 1 : x);
const mix = (c, t, a) => { c[0] += (t[0] - c[0]) * a; c[1] += (t[1] - c[1]) * a; c[2] += (t[2] - c[2]) * a; };

// raggio contro triangolo (Möller–Trumbore): vero se colpisce davanti all'origine
function rayHits(o, d, tris, P) {
  for (let k = 0; k < tris.length; k += 3) {
    const a = tris[k] * 3, b = tris[k + 1] * 3, c = tris[k + 2] * 3;
    const e1x = P[b] - P[a], e1y = P[b + 1] - P[a + 1], e1z = P[b + 2] - P[a + 2], e2x = P[c] - P[a], e2y = P[c + 1] - P[a + 1], e2z = P[c + 2] - P[a + 2];
    const hx = d[1] * e2z - d[2] * e2y, hy = d[2] * e2x - d[0] * e2z, hz = d[0] * e2y - d[1] * e2x, det = e1x * hx + e1y * hy + e1z * hz;
    if (Math.abs(det) < 1e-14) continue;
    const f = 1 / det, sx = o[0] - P[a], sy = o[1] - P[a + 1], sz = o[2] - P[a + 2], u = f * (sx * hx + sy * hy + sz * hz);
    if (u < 0 || u > 1) continue;
    const qx = sy * e1z - sz * e1y, qy = sz * e1x - sx * e1z, qz = sx * e1y - sy * e1x, v = f * (d[0] * qx + d[1] * qy + d[2] * qz);
    if (v < 0 || u + v > 1) continue;
    if (f * (e2x * qx + e2y * qy + e2z * qz) > 1e-5) return true;
  }
  return false;
}

// tabella del tassello (una volta per modello): per ogni cella lx, ly in mm dal centro della finestra visibile;
// la finestra (semilarghezza W, semialtezza H) e le celle viste dalla camera (per le prove)
export function buildEyeTable(geo, isEye) {
  const P = geo.attributes.position, UV = geo.attributes.uv, I = geo.index.array, R = EYE_RES;
  const PA = new Float32Array(P.count * 3); for (let i = 0; i < P.count; i++) { PA[i * 3] = P.getX(i); PA[i * 3 + 1] = P.getY(i); PA[i * 3 + 2] = P.getZ(i); }
  // occhio sinistro (x > 0): punto più avanti del bulbo = riferimento provvisorio
  let front = -1;
  for (let i = 0; i < P.count; i++) if (isEye[i] && PA[i * 3] > 0 && (front < 0 || PA[i * 3 + 2] > PA[front * 3 + 2])) front = i;
  const F = [PA[front * 3], PA[front * 3 + 1], PA[front * 3 + 2]];
  const pos = new Float32Array(R * R * 3), has = new Uint8Array(R * R), sc = R / EYE_PX[2];
  for (let t = 0; t < I.length; t += 3) {
    const a = I[t], b = I[t + 1], d = I[t + 2];
    if (!isEye[a] || !isEye[b] || !isEye[d] || PA[a * 3] <= 0) continue;
    const ax = (UV.getX(a) * 1024 - EYE_PX[0]) * sc, ay = (UV.getY(a) * 1024 - EYE_PX[1]) * sc, bx = (UV.getX(b) * 1024 - EYE_PX[0]) * sc, by = (UV.getY(b) * 1024 - EYE_PX[1]) * sc;
    const dx = (UV.getX(d) * 1024 - EYE_PX[0]) * sc, dy = (UV.getY(d) * 1024 - EYE_PX[1]) * sc;
    const det = (by - dy) * (ax - dx) + (dx - bx) * (ay - dy); if (Math.abs(det) < 1e-9) continue;
    const x0 = Math.max(0, Math.floor(Math.min(ax, bx, dx))), x1 = Math.min(R - 1, Math.ceil(Math.max(ax, bx, dx)));
    const y0 = Math.max(0, Math.floor(Math.min(ay, by, dy))), y1 = Math.min(R - 1, Math.ceil(Math.max(ay, by, dy)));
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
      const px = x + 0.5, py = y + 0.5, l1 = ((by - dy) * (px - dx) + (dx - bx) * (py - dy)) / det, l2 = ((dy - ay) * (px - dx) + (ax - dx) * (py - dy)) / det, l3 = 1 - l1 - l2;
      if (l1 < -0.02 || l2 < -0.02 || l3 < -0.02) continue;
      const i = y * R + x; has[i] = 1;
      for (let k = 0; k < 3; k++) pos[i * 3 + k] = PA[a * 3 + k] * l1 + PA[b * 3 + k] * l2 + PA[d * 3 + k] * l3;
    }
  }
  // triangoli della testa vicino all'occhio (palpebre, orbita)
  const tris = [];
  for (let t = 0; t < I.length; t += 3) {
    const v = [I[t], I[t + 1], I[t + 2]]; if (v.some(k => isEye[k])) continue;
    if (v.every(k => Math.hypot(PA[k * 3] - F[0], PA[k * 3 + 1] - F[1], PA[k * 3 + 2] - F[2]) < NEAR_EYE)) tris.push(...v);
  }
  const dl = Math.hypot(...VIEW_DIR), dir = VIEW_DIR.map(v => v / dl), o = [0, 0, 0];
  const vis = []; // celle viste: [indice, lx, ly] (mm dal punto più avanti del bulbo)
  for (let y = 0; y < R; y += VIS_STEP) for (let x = 0; x < R; x += VIS_STEP) {
    const i = y * R + x; if (!has[i] || pos[i * 3 + 2] < F[2] - 0.008) continue;
    o[0] = pos[i * 3]; o[1] = pos[i * 3 + 1]; o[2] = pos[i * 3 + 2];
    if (!rayHits(o, dir, tris, PA)) vis.push(i, (o[0] - F[0]) * 1000, (o[1] - F[1]) * 1000);
  }
  // finestra: larghezza dagli estremi, altezza dalla parte centrale (bordo sopra e sotto per fasce di lx)
  let x0 = Infinity, x1 = -Infinity;
  for (let k = 0; k < vis.length; k += 3) { x0 = Math.min(x0, vis[k + 1]); x1 = Math.max(x1, vis[k + 1]); }
  const cx = (x0 + x1) / 2, W = (x1 - x0) / 2, tops = [], bots = [];
  for (let s = -0.5; s <= 0.5; s += 0.125) {
    let top = -Infinity, bot = Infinity;
    for (let k = 0; k < vis.length; k += 3) if (Math.abs(vis[k + 1] - (cx + s * W)) < W * 0.07) { top = Math.max(top, vis[k + 2]); bot = Math.min(bot, vis[k + 2]); }
    if (top > bot) { tops.push(top); bots.push(bot); }
  }
  const med = a => a.sort((p, q) => p - q)[a.length >> 1] || 0, top = med(tops), bot = med(bots), cy = (top + bot) / 2, H = Math.max(2, (top - bot) / 2);
  // coordinate di ogni cella rispetto al centro della finestra
  const lx = new Float32Array(R * R), ly = new Float32Array(R * R);
  for (let i = 0; i < R * R; i++) if (has[i]) { lx[i] = (pos[i * 3] - F[0]) * 1000 - cx; ly[i] = (pos[i * 3 + 1] - F[1]) * 1000 - cy; }
  const visible = [];
  for (let k = 0; k < vis.length; k += 3) visible.push(vis[k]);
  return { R, has, lx, ly, W, H, visible: Int32Array.from(visible) };
}

// palpebre di una forma alla colonna lx: bordo sopra e sotto (mm), null fuori dagli angoli
function lidsAt(f, W, H, lx) {
  const xi = -f.ci * W, xo = f.co * W, t = (lx - xi) / (xo - xi);
  if (t <= 0 || t >= 1) return null;
  const base = (f.yi + (f.yo - f.yi) * t) * H;
  const tu = t < f.pu ? 0.5 * t / f.pu : 0.5 + 0.5 * (t - f.pu) / (1 - f.pu); // punto più alto spostato verso pu
  return { up: base + f.hu * H * (4 * tu * (1 - tu)) ** f.a, lo: base - f.hl * H * (4 * t * (1 - t)) ** f.a };
}

// quanto la cella (lx, ly) è dentro l'apertura (1) o sotto la palpebra (0), con il bordo morbido; dU = mm dal bordo sopra
export function eyeOpenAt(shape, tab, lx, ly) {
  const f = EYE_FORMS[shape] || EYE_FORMS[0], L = lidsAt(f, tab.W, tab.H, lx);
  if (!L) return { open: 0, dU: -9, dL: -9 };
  const dU = L.up - ly, dL = ly - L.lo;
  return { open: clamp01(Math.min(dU, dL) / AA_MM + 0.5), dU, dL };
}

// pixel RGBA del tassello (EYE_RES × EYE_RES) per un aspetto: bulbo, iride, palpebre della forma con ciglia
export function paintEyeTile(tab, L) {
  const { R, has, lx, ly, H } = tab, f = EYE_FORMS[L.eyes] || EYE_FORMS[0];
  const sk = rgb(SKINS[L.skin][1]), ir = rgb(EYE_COLORS[L.eyeColor][1]);
  const lid = sk.map((v, k) => v * LID_TONE[k]), lidDark = [sk[0] * 0.66, sk[1] * 0.6, sk[2] * 0.6], lash = [22, 15, 11];
  const sclera = [242, 237, 230], scleraEdge = [204, 190, 182], irisDark = ir.map(v => v * 0.55), irisLight = ir.map(v => Math.min(255, v * 1.3 + 12));
  const rI = f.iris * H, out = new Uint8ClampedArray(R * R * 4), c = [0, 0, 0];
  for (let i = 0; i < R * R; i++) {
    const o = i * 4;
    if (!has[i]) { out[o] = lid[0]; out[o + 1] = lid[1]; out[o + 2] = lid[2]; out[o + 3] = 255; continue; }
    const x = lx[i], y = ly[i], { open, dU, dL } = eyeOpenAt(L.eyes, tab, x, y);
    c[0] = lid[0]; c[1] = lid[1]; c[2] = lid[2];
    if (open > 0) {
      // bulbo: sclera più grigia verso gli angoli, iride con venature e anello scuro, pupilla, riflesso
      const e = [0, 0, 0], q = clamp01((x / (tab.W * 1.05)) ** 2 + (y / (H * 1.6)) ** 2);
      e[0] = sclera[0]; e[1] = sclera[1]; e[2] = sclera[2]; mix(e, scleraEdge, q);
      const d = Math.hypot(x, y);
      if (d < rI + 0.3) {
        const k = d / rI, ang = Math.atan2(y, x), vein = 0.5 + 0.5 * Math.sin(ang * 23 + k * 3), ic = [0, 0, 0];
        ic[0] = ir[0]; ic[1] = ir[1]; ic[2] = ir[2];
        mix(ic, irisLight, clamp01(0.7 - k) * 0.8); mix(ic, irisDark, clamp01((k - 0.72) / 0.28) * 0.9 + vein * 0.18);
        if (k < 0.42) { ic[0] = 11; ic[1] = 8; ic[2] = 6; } else if (k < 0.48) mix(ic, [11, 8, 6], (0.48 - k) / 0.06);
        mix(e, ic, clamp01((rI - d) / 0.3 + 0.5));
      }
      // ombra della palpebra sopra sul bulbo
      mix(e, [70, 50, 42], 0.42 * clamp01(1 - dU / (H * 0.45)));
      const hx = x + rI * 0.3, hy = y - rI * 0.38; // riflesso in alto (verso il naso)
      if (hx * hx + hy * hy < (rI * 0.2) ** 2) mix(e, [255, 255, 255], 0.9);
      mix(c, e, open);
    }
    // ciglia sul bordo sopra (spesse), riga sottile sotto, piega della palpebra (forme che la chiedono)
    if (dU > -9) {
      if (dU < 0.25 && dU > -0.95) mix(c, lash, 0.92 * clamp01((dU + 0.95) / 0.3) * clamp01((0.25 - dU) / 0.3));
      if (dL < 0.15 && dL > -0.5) mix(c, lidDark, 0.6 * clamp01((dL + 0.5) / 0.25) * clamp01((0.15 - dL) / 0.2));
      if (f.crease && dU < -1.3 && dU > -2.6) mix(c, lidDark, f.crease * Math.sin(Math.PI * (-dU - 1.3) / 1.3));
    }
    out[o] = c[0]; out[o + 1] = c[1]; out[o + 2] = c[2]; out[o + 3] = 255;
  }
  return out;
}

// aggancio: model.paintEyes = paintEyesFine (chiamata come metodo del modello, con g già scalato a coordinate su 1024)
export function paintEyesFine(g, L) {
  const tab = this.maps.get('eyeT') || this.maps.set('eyeT', buildEyeTable(this.mesh.geometry, this.isEye)).get('eyeT');
  const R = tab.R, cv = this._eyeCv || (this._eyeCv = cpuCanvas(R, R)), cg = cv.getContext('2d'), img = cg.createImageData(R, R);
  img.data.set(paintEyeTile(tab, L));
  cg.putImageData(img, 0, 0);
  const [x, y, w, h] = EYE_PX;
  g.save(); g.imageSmoothingEnabled = true; g.drawImage(cv, x, y, w, h); g.restore();
}
