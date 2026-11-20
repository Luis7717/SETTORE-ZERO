// Testa, viso e collo del calciatore realistico (modello "athlete" di src/athlete3d.js), rifiniti a codice al caricamento
// (il file del modello non si rigenera). Riferimento: PROPORZIONI.md (T = altezza della testa, mento → cima del cranio).
//
// 1) Forma (shapeHead, una volta per modello): cranio più largo e un po' meno profondo dietro, zigomi e mascella più
//    pieni, mento un filo più avanti, testa appena più piccola (-2,4%) e alzata di circa un centimetro con il collo
//    allungato e un po' più pieno ai lati (collo visibile 0,35 T, largo 0,5 T, altezza totale 8 T). L'attaccatura alle spalle
//    (sotto l'osso del collo) non si muove. Le normali seguono la deformazione (inversa trasposta dello jacobiano).
// 2) Pittura (sopra la pittura di src/athlete3d.js, solo sui texel di testa e collo): carnagione con toni (guance, naso,
//    orecchie più caldi, ombra sotto la mascella), labbra del colore giusto per ogni pelle, sopracciglia a peli con
//    bordi morbidi, barba con bordi sfumati che continua sotto la mascella, linea delle ciglia, niente macchie chiare
//    della mappa di dettaglio attorno agli occhi; collo sempre pelle fino allo scollo (prima la parte sotto il mento
//    prendeva il colore del bordino). Tassello degli occhi: iride più piccola e con venature, palpebre per le forme.
// Uso (una riga, nel costruttore del modello, prima delle misure): installHead(this)
import { SKINS, HAIR_COLORS, EYE_COLORS } from '../looks.js';
import { scalpPaint } from '../hair3d.js';
import { FACE, rgb, shade, lumH, cpuCanvas } from '../players3d.js';

// ---------------------------------------------------------------- forma (m e frazioni di T)
const HEAD_LIFT = 0.0095;     // m: di quanto sale la testa (il collo si allunga di altrettanto)
const HEAD_SCALE = 0.976;     // scala della testa attorno al mento (totale = 8 T con la testa alzata)
const SKULL_WIDE = 0.165;     // allargamento del cranio sopra le orecchie
const CHEEK_WIDE = 0.07;      // allargamento degli zigomi (metà davanti del viso)
const JAW_WIDE = 0.06;        // allargamento della mascella verso l'angolo
const FRONT_KEEP = 0.8;       // quanto si risparmia la parte davanti del cranio dall'allargamento
const EAR_X = 0.064, EAR_U = 0.47; // attaccatura delle orecchie: distanza dal centro (m) e altezza (frazione di T)
const EAR_FLAT = 0.12, EAR_TOP = 0.35; // orecchie meno a sventola; la parte alta ancora meno (niente punta)
const BACK_FLAT = 0.07;       // nuca meno sporgente (profondità della testa)
const CHIN_FWD = 0.004;       // m: mento più avanti
const NECK_WIDE = 0.11;       // collo un po' più pieno ai lati a metà altezza (larghezza 0,5 T)
const NECK_KEEP_X = [0.075, 0.12]; // m: oltre questa distanza dal centro il collo non cambia (trapezi e spalle restano)
const EPS = 1e-4;             // m: passo per lo jacobiano numerico delle normali

const smooth = (a, b, x) => { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
const bump = (a, m, b, x) => (x < m ? smooth(a, m, x) : 1 - smooth(m, b, x));

// punti di riferimento della testa in posa di legame: cima del cranio, mento, centro (z), base del collo
function headMarks(mesh) {
  const geo = mesh.geometry, P = geo.attributes.position, J = geo.attributes.skinIndex, W = geo.attributes.skinWeight, UV = geo.attributes.uv;
  const bones = mesh.skeleton.bones, names = bones.map(b => b.name), H = names.indexOf('Head');
  const neck = mesh.skeleton.boneInverses[names.indexOf('neck_01')].clone().invert();
  let top = -Infinity, zc = 0, n = 0;
  const hw = new Float32Array(P.count);
  for (let i = 0; i < P.count; i++) {
    for (let k = 0; k < 4; k++) if (J.getComponent(i, k) === H) hw[i] += W.getComponent(i, k);
    if (hw[i] > 0.5 && !(UV.getX(i) >= 0.875 && UV.getY(i) >= 0.875)) { top = Math.max(top, P.getY(i)); zc += P.getZ(i); n++; }
  }
  zc /= n || 1;
  // mento: il punto più basso della linea di mezzo davanti (il collo sotto il mento sta più indietro)
  let chin = Infinity, neckZ = -Infinity;
  for (let i = 0; i < P.count; i++) if (Math.abs(P.getX(i)) < 0.012 && P.getY(i) > top - 0.29 && P.getY(i) < top - 0.25) neckZ = Math.max(neckZ, P.getZ(i));
  for (let i = 0; i < P.count; i++) if (hw[i] > 0.3 && Math.abs(P.getX(i)) < 0.012 && P.getZ(i) > neckZ + 0.025 && P.getY(i) < top - 0.12) chin = Math.min(chin, P.getY(i));
  return { top, chin, zc, T: top - chin, neckY: neck.elements[13] };
}

// la deformazione di un punto (coordinate della mesh in posa di legame)
function makeDeform(mk) {
  const { chin: c0, zc, T, neckY } = mk, yb = neckY + 0.004;
  return (x, y, z, out) => {
    const u = (y - c0) / T, ax = Math.abs(x);
    // cranio, zigomi, mascella: larghezza
    // il cranio si allarga in proporzione alla distanza dal centro; le orecchie (oltre EAR_X) si spostano in blocco,
    // senza allungarsi in alto (altrimenti diventano a punta)
    // (davanti, fronte e occhi, quasi niente: l'attaccatura dei capelli e la distanza degli occhi restano quelle)
    const kS = SKULL_WIDE * smooth(0.38, 0.68, u) * (1 - FRONT_KEEP * smooth(0.0, 0.05, z - zc)), we = smooth(EAR_X - 0.006, EAR_X + 0.002, ax) * bump(0.24, 0.47, 0.74, u);
    const dS = (1 - we) * kS * ax + we * SKULL_WIDE * smooth(0.38, 0.68, EAR_U) * EAR_X;
    // orecchie un po' meno sporgenti, soprattutto in alto (la punta del modello diventa tonda)
    const dE = -we * Math.max(0, ax - EAR_X) * (EAR_FLAT + EAR_TOP * smooth(0.5, 0.64, u));
    let fx = 1 + (dS + dE) / Math.max(ax, 1e-6)
      + CHEEK_WIDE * bump(0.22, 0.38, 0.52, u) * smooth(-0.02, 0.03, z - zc) * smooth(0.03, 0.05, ax)
      + JAW_WIDE * bump(0.02, 0.16, 0.34, u) * smooth(0.11, 0.06, z - zc);
    // collo più pieno ai lati e dietro (davanti restano i muscoli del collo)
    fx *= 1 + NECK_WIDE * smooth(yb + 0.01, yb + 0.04, y) * (1 - smooth(c0 - 0.012, c0 + 0.006, y)) * smooth(0.035, -0.02, z - zc) * smooth(NECK_KEEP_X[1], NECK_KEEP_X[0], ax);
    let nx = x * fx, ny = y, nz = z;
    // nuca meno sporgente
    if (z < zc) nz = zc + (z - zc) * (1 - BACK_FLAT * smooth(0.3, 0.56, u));
    // mento un po' più avanti
    nz += CHIN_FWD * bump(-0.06, 0.05, 0.2, u) * smooth(zc + 0.035, zc + 0.065, z) * (1 - smooth(0.012, 0.035, ax));
    // testa un po' più piccola attorno al mento, poi alzata; il collo si allunga sotto (l'attaccatura resta ferma)
    const ws = smooth(c0 - 0.015, c0 + 0.02, y), s = 1 + (HEAD_SCALE - 1) * ws;
    nx *= s; ny = c0 + (ny - c0) * s; nz = zc + (nz - zc) * s;
    const t = smooth(yb, c0, y), keep = 1 - smooth(NECK_KEEP_X[0], NECK_KEEP_X[1], ax) * (1 - smooth(c0 - 0.02, c0, y));
    ny += HEAD_LIFT * t * keep;
    out[0] = nx; out[1] = ny; out[2] = nz;
    return out;
  };
}

// deforma testa e collo della mesh (posizioni e normali). Restituisce i punti di riferimento prima della modifica.
export function shapeHead(mesh) {
  const geo = mesh.geometry, P = geo.attributes.position, N = geo.attributes.normal;
  const mk = headMarks(mesh), def = makeDeform(mk), yLow = mk.neckY;
  const o = [0, 0, 0], a = [0, 0, 0], b = [0, 0, 0], J = new Float64Array(9);
  for (let i = 0; i < P.count; i++) {
    const x = P.getX(i), y = P.getY(i), z = P.getZ(i);
    if (y < yLow || Math.abs(x) > 0.22) continue;
    def(x, y, z, o);
    // jacobiano numerico (differenze centrate) → normale = inversa trasposta · normale
    for (let k = 0; k < 3; k++) {
      def(x + (k === 0 ? EPS : 0), y + (k === 1 ? EPS : 0), z + (k === 2 ? EPS : 0), a);
      def(x - (k === 0 ? EPS : 0), y - (k === 1 ? EPS : 0), z - (k === 2 ? EPS : 0), b);
      for (let r = 0; r < 3; r++) J[r * 3 + k] = (a[r] - b[r]) / (2 * EPS);
    }
    const n0 = N.getX(i), n1 = N.getY(i), n2 = N.getZ(i);
    // cofattori di J (= det · J^-T): basta la direzione
    const c00 = J[4] * J[8] - J[5] * J[7], c01 = J[5] * J[6] - J[3] * J[8], c02 = J[3] * J[7] - J[4] * J[6];
    const c10 = J[2] * J[7] - J[1] * J[8], c11 = J[0] * J[8] - J[2] * J[6], c12 = J[1] * J[6] - J[0] * J[7];
    const c20 = J[1] * J[5] - J[2] * J[4], c21 = J[2] * J[3] - J[0] * J[5], c22 = J[0] * J[4] - J[1] * J[3];
    let m0 = c00 * n0 + c10 * n1 + c20 * n2, m1 = c01 * n0 + c11 * n1 + c21 * n2, m2 = c02 * n0 + c12 * n1 + c22 * n2;
    const l = Math.hypot(m0, m1, m2) || 1; m0 /= l; m1 /= l; m2 /= l;
    P.setXYZ(i, o[0], o[1], o[2]); N.setXYZ(i, m0, m1, m2);
  }
  P.needsUpdate = true; N.needsUpdate = true;
  geo.computeBoundingBox(); geo.computeBoundingSphere();
  return mk;
}

// ---------------------------------------------------------------- pittura del viso
const C_HEAD = 5, C_NECK = 7;  // classi dei texel (come in src/athlete3d.js)
const AA = 0.005;              // m: bordo morbido dello scollo (come in src/athlete3d.js)
const EYE_PX = [896, 896, 128, 128]; // tassello degli occhi (EYE_PX di src/athlete3d.js)
const DETAIL_SKIN = 0.95;      // quanto si vede la mappa di dettaglio sulla pelle
const DETAIL_CLAMP = [0.62, 1.1]; // limiti della mappa di dettaglio sul viso (via le macchie chiare attorno agli occhi)
const NECK_FRONT = 0.03, NECK_RELAX = 0.75; // gola (davanti all'osso del collo di 3 cm): scollo misurato come se fosse più vicina
const BEARD_UNDER = [0.012, 0.034]; // m: sotto il mento la barba sfuma tra queste distanze
const LASH = { w: 0.0024, k: 0.75 }; // linea delle ciglia: larghezza (m) e intensità
const IRIS_K = 0.85;           // iride rispetto a prima (era grande per l'apertura dell'occhio)
const RING = 3;                // texel di allargamento fuori dalle isole UV (come il dilate di src/athlete3d.js)

const mixc = (c, t, a) => { c[0] += (t[0] - c[0]) * a; c[1] += (t[1] - c[1]) * a; c[2] += (t[2] - c[2]) * a; };
const gauss = (d2, r) => Math.exp(-d2 / (r * r));
const hash01 = (i, k) => (Math.imul(i, k) >>> 0) / 4294967296;

// texel di testa e collo per un lato della texture, con l'anello fuori dalle isole UV (da ricolorare) e il rettangolo
function headTexels(model, S) {
  const key = 'head' + S; if (model.maps.has(key)) return model.maps.get(key);
  const cls = model.texMap(S).cls, list = [];
  for (let i = 0; i < S * S; i++) if (cls[i] === C_HEAD || cls[i] === C_NECK) list.push(i);
  // anello: come il dilate originale (vicino sinistro, destro, sopra, sotto), partendo da tutti i texel pieni
  const filled = new Uint8Array(S * S), mine = new Uint8Array(S * S), ring = [];
  for (let i = 0; i < S * S; i++) filled[i] = cls[i] ? 1 : 0;
  for (const i of list) mine[i] = 1;
  for (let it = 0; it < RING; it++) {
    const add = [];
    for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
      const i = y * S + x; if (filled[i]) continue;
      const nb = x > 0 && filled[i - 1] ? i - 1 : x < S - 1 && filled[i + 1] ? i + 1 : y > 0 && filled[i - S] ? i - S : y < S - 1 && filled[i + S] ? i + S : -1;
      if (nb >= 0) add.push(i, nb);
    }
    for (let k = 0; k < add.length; k += 2) { filled[add[k]] = 1; if (mine[add[k + 1]]) { mine[add[k]] = 1; ring.push(add[k], add[k + 1]); } }
  }
  let x0 = S, y0 = S, x1 = 0, y1 = 0;
  for (let i = 0; i < S * S; i++) if (mine[i]) { const x = i % S, y = (i / S) | 0; x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
  const out = { list: Int32Array.from(list), ring: Int32Array.from(ring), rect: [x0, y0, x1 - x0 + 1, y1 - y0 + 1] };
  model.maps.set(key, out);
  return out;
}

// canvas letto una volta; campionato con filtro bilineare (bordi senza scalini dei pixel)
// si legge solo la zona dei lineamenti (sopracciglia → sotto il mento): meno pixel da copiare e sfumare
const FACE_CROP = [200, 150, 240, 260];
function readCanvas(c) { const [x, y, w, h] = FACE_CROP; return { x, y, w, h, d: c.getContext('2d').getImageData(x, y, w, h).data }; }
function bilinear(cv, u, v, out) {
  const x = u - 0.5 - cv.x, y = v - 0.5 - cv.y, x0 = Math.floor(x), y0 = Math.floor(y), fx = x - x0, fy = y - y0;
  out[0] = out[1] = out[2] = out[3] = 0;
  if (x0 < -1 || y0 < -1 || x0 >= cv.w || y0 >= cv.h) return out;
  for (let k = 0; k < 4; k++) {
    const xx = x0 + (k & 1), yy = y0 + (k >> 1), w = ((k & 1) ? fx : 1 - fx) * ((k >> 1) ? fy : 1 - fy);
    if (xx < 0 || yy < 0 || xx >= cv.w || yy >= cv.h || !w) continue;
    const o = (yy * cv.w + xx) << 2, a = cv.d[o + 3] * w;
    out[0] += cv.d[o] * a; out[1] += cv.d[o + 1] * a; out[2] += cv.d[o + 2] * a; out[3] += a;
  }
  if (out[3] > 0) { out[0] /= out[3]; out[1] /= out[3]; out[2] /= out[3]; }
  out[3] /= 255;
  return out;
}

// sfuma l'alfa (scatola ripetuta): bordi morbidi senza i filtri del canvas (non ovunque disponibili)
function softAlpha(cv, passes) {
  const { w, h, d } = cv, a = new Float32Array(w * h), t = new Float32Array(w * h);
  for (let i = 0; i < w * h; i++) a[i] = d[i * 4 + 3];
  for (let p = 0; p < passes; p++) {
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const i = y * w + x; t[i] = (a[i] * 2 + (x > 0 ? a[i - 1] : a[i]) + (x < w - 1 ? a[i + 1] : a[i])) / 4; }
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const i = y * w + x; a[i] = (t[i] * 2 + (y > 0 ? t[i - w] : t[i]) + (y < h - 1 ? t[i + w] : t[i])) / 4; }
  }
  for (let i = 0; i < w * h; i++) d[i * 4 + 3] = a[i];
  return cv;
}

// sopracciglia a peli: forma affusolata (piena verso il naso, sottile in coda) + peli corti; i 6 tipi dell'editor
const BROW_DOWN = 3;           // px della zona viso: sopracciglia un po' più vicine agli occhi
const BROW_SHAPES = [ // semilarghezza, spessore, arco, inclinazione, coda in giù (px della zona viso)
  [16, 6.5, 2.5, 0, 2], [15, 3.4, 2, 0, 1.5], [17, 9.5, 2, 0, 2], [16, 5.5, 7, 0, 3], [17, 6.5, 0.5, 0, 1], [16, 7.5, 2, -0.26, 2]];
function paintBrowsFine(g, L, hairC) {
  const bc = shade(hairC, lumH(hairC) > 0.6 ? 0.58 : 0.8), dark = shade(hairC, 0.55);
  const [w, th, arc, ang, tail] = BROW_SHAPES[L.brows] || BROW_SHAPES[0];
  let seed = 11 + L.brows * 7; const r = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
  // u: −1 naso, 1 tempia; il punto più alto a due terzi verso la tempia, la coda scende
  const cy = u => { const p = (u - 0.3) / (u < 0.3 ? 1.3 : 0.7); return -0.8 * arc * (1 - p * p) + (u > 0.4 ? tail * (u - 0.4) / 0.6 : 0); };
  const tk = u => th * (0.55 + 0.45 * (1 - (u + 1) / 2) ** 0.7) * (u > 0.75 ? 1 - (u - 0.75) * 2.2 : 1);
  for (const s of [-1, 1]) {
    g.save(); g.translate(FACE.x + s * FACE.eyeDX, FACE.browY + BROW_DOWN); g.scale(-s, 1); g.rotate(ang);
    g.beginPath();
    for (let k = 0; k <= 20; k++) { const u = -1 + k / 10; g.lineTo(u * w, cy(u) - tk(u) / 2); }
    for (let k = 20; k >= 0; k--) { const u = -1 + k / 10; g.lineTo(u * w, cy(u) + tk(u) / 2); }
    g.closePath(); g.globalAlpha = 0.86; g.fillStyle = bc; g.fill();
    g.globalAlpha = 0.6; g.strokeStyle = dark; g.lineWidth = 0.9; g.lineCap = 'round';
    for (let k = 0; k < 46; k++) {
      const u = -1 + 2 * r(), x = u * w, y = cy(u) + (r() - 0.5) * tk(u) * 0.9, l = 2.5 + r() * 2.5, a = (u < -0.6 ? -2 : -2.8) + (r() - 0.5) * 0.3;
      g.beginPath(); g.moveTo(x + Math.cos(a) * l, y + Math.sin(a) * l); g.lineTo(x, y); g.stroke();
    }
    g.restore();
  }
  g.globalAlpha = 1;
}

// barba di un giorno: zona della mascella e del labbro di sopra, piena e sfumata (la grana la mette il texel)
function paintStubble(g, hairC) {
  const x = FACE.x, y = FACE.mouthY, e = FACE.eyeY;
  g.save(); g.fillStyle = hairC; g.globalAlpha = 0.48;
  g.beginPath(); g.moveTo(x - 88, e + 44); g.lineTo(x - 80, y + 32); g.quadraticCurveTo(x, y + 80, x + 80, y + 32); g.lineTo(x + 88, e + 44);
  g.lineTo(x + 58, e + 50); g.quadraticCurveTo(x + 40, y - 12, x + 22, y - 10); g.quadraticCurveTo(x, y - 20, x - 22, y - 10); g.quadraticCurveTo(x - 40, y - 12, x - 58, e + 50); g.closePath(); g.fill();
  g.globalCompositeOperation = 'destination-out'; g.globalAlpha = 1; g.beginPath(); g.ellipse(x, y + 2, 16, 6.5, 0, 0, Math.PI * 2); g.fill();
  g.restore();
}

// i due strati del viso: barba (si proietta anche sotto la mascella) e lineamenti (labbra, sopracciglia)
const LAYER_CACHE = 24;         // strati del viso tenuti pronti (le stesse combinazioni tornano spesso)
function faceLayers(model, L, skinH, hairC) {
  const key = [L.skin, L.hairColor, L.brows, L.beard].join(','), cache = model._faceLayers || (model._faceLayers = new Map());
  if (cache.has(key)) return cache.get(key);
  const out = drawFaceLayers(model, L, skinH, hairC);
  if (cache.size >= LAYER_CACHE) cache.delete(cache.keys().next().value);
  cache.set(key, out);
  return out;
}
function drawFaceLayers(model, L, skinH, hairC) {
  const bc = model._beardCv || (model._beardCv = cpuCanvas(640, 440)), fc = model._faceCv || (model._faceCv = cpuCanvas(640, 440));
  const gb = bc.getContext('2d'); gb.clearRect(0, 0, 640, 440);
  if (L.beard === 1) paintStubble(gb, hairC); else model.paintBeard(gb, L, skinH, hairC);
  const beard = L.beard ? softAlpha(readCanvas(bc), L.beard === 1 ? 4 : 2) : null;
  const g = fc.getContext('2d'); g.clearRect(0, 0, 640, 440);
  // labbra: la pelle verso il rosso scuro (va bene per ogni carnagione), con la linea della bocca
  const sk = rgb(skinH), lip = `rgb(${sk[0] * 0.86 | 0},${sk[1] * 0.6 | 0},${sk[2] * 0.6 | 0})`, lipD = `rgb(${sk[0] * 0.6 | 0},${sk[1] * 0.38 | 0},${sk[2] * 0.38 | 0})`;
  const mx = FACE.x, my = FACE.mouthY;
  g.globalAlpha = 0.5; g.fillStyle = lip; g.beginPath(); g.ellipse(mx, my + 3, 17, 7.5, 0, 0, Math.PI * 2); g.fill();
  g.globalAlpha = 0.35; g.strokeStyle = lipD; g.lineWidth = 2; g.lineCap = 'round';
  g.beginPath(); g.moveTo(mx - 15, my + 1); g.quadraticCurveTo(mx, my + 4, mx + 15, my + 1); g.stroke();
  g.globalAlpha = 1;
  paintBrowsFine(g, L, hairC);
  return { beard, face: softAlpha(readCanvas(fc), 2) };
}

// il collo resta pelle fin sotto il mento; vicino allo scollo decide la pittura della maglia (src/athlete3d.js)
// (il cilindro attorno all'osso che taglia lo scollo sulle spalle prendeva anche la gola sotto il mento: lì, e solo lì,
// lo si allarga; ai lati davanti fa il bordino e resta com'è)
function neckSkin(model, collar, x, y, z, LM) {
  const k = 1 - (1 - NECK_RELAX) * smooth(NECK_FRONT - 0.01, NECK_FRONT + 0.01, z - LM.neckZ) * smooth(LM.neckY + 0.005, LM.neckY + 0.025, y) * smooth(0.055, 0.035, Math.abs(x));
  return smooth(0, 2 * AA, model.neckline(collar, x * k, y, LM.neckZ + (z - LM.neckZ) * k, LM));
}

// tabella per texel di testa e collo, uguale per tutti i giocatori (calcolata una volta per lato della texture):
// pesi dei toni della pelle e delle ciglia, coordinate nella zona viso, direzione per la cute, mappa di dettaglio
function headTable(model, S) {
  const key = 'headT' + S; if (model.maps.has(key)) return model.maps.get(key);
  const M = model.texMap(S), D = model.detailAt(S), LM = model.L, F = model.face, H = headTexels(model, S), h = model.head, n = H.list.length;
  const fx = 36 / LM.eyeDX, fy = 52 / Math.max(0.03, (LM.eyeY - LM.chinY) * 0.58), midX = (model.eyeL.x + model.eyeR.x) / 2;
  const T = { n, idx: H.list, warm: new Float32Array(n), cool: new Float32Array(n), deep: new Float32Array(n), lash: new Float32Array(n),
    u: new Float32Array(n), v: new Float32Array(n), beardK: new Float32Array(n), faceK: new Float32Array(n), el: new Float32Array(n), az: new Float32Array(n),
    det: new Float32Array(n), head: new Uint8Array(n), neck: [], out: new Int32Array(n) };
  const [rx, ry, rw] = H.rect;
  for (let k = 0; k < n; k++) {
    const i = H.list[k], x = M.pos[i * 3], y = M.pos[i * 3 + 1], z = M.pos[i * 3 + 2], ny = M.nrm[i * 3 + 1], isHead = M.cls[i] === C_HEAD;
    const dx = x - h.c.x, dy = y - h.c.y, dz = z - h.c.z;
    const ly = dx * h.up.x + dy * h.up.y + dz * h.up.z, lx = dx * h.right.x + dy * h.right.y + dz * h.right.z, lz = dx * h.fwd.x + dy * h.fwd.y + dz * h.fwd.z;
    const nf = M.nrm[i * 3] * h.fwd.x + ny * h.fwd.y + M.nrm[i * 3 + 2] * h.fwd.z, ex = Math.abs(x - midX), ey = y - LM.eyeY, front = Math.max(0, Math.min(1, nf * 2 + 0.2));
    // toni: guance, naso e orecchie più caldi; occhiaie un filo più fredde; ombra sotto la mascella
    let w = gauss((ex - F.cheekX) ** 2 + (ey - F.cheekY) ** 2, F.cheekR) * front + gauss(ex * ex * 4 + (ey - F.noseY) ** 2, F.noseR) * 0.8 * front;
    if (isHead && Math.abs(x) > F.earX && Math.abs(ey) < 0.05 && z < F.earZ) w += 0.35;
    T.warm[k] = w;
    T.cool[k] = 0.35 * gauss((ex - LM.eyeDX) ** 2 * 0.6 + (ey + 0.016) ** 2, 0.011) * front;
    T.deep[k] = y < F.chin + 0.02 ? 0.45 * smooth(-0.15, -0.65, ny) * smooth(F.chin - 0.06, F.chin - 0.01, y) * smooth(F.chin + 0.03, F.chin, y) : 0;
    // linea delle ciglia sopra l'apertura degli occhi
    let lash = 0;
    if (isHead) for (const e of F.eyes) {
      const d = Math.hypot(x - e.x, y - e.y, z - e.z) - e.r;
      if (d > -0.001 && d < LASH.w * 2 && y > e.y - 0.0015 && z > e.z - 0.004) lash = Math.max(lash, LASH.k * (1 - smooth(LASH.w * 0.6, LASH.w * 1.6, d)) * smooth(e.y - 0.0015, e.y + 0.002, y));
    }
    T.lash[k] = lash;
    // zona viso: barba anche sotto la mascella (sfumata), lineamenti solo davanti
    T.u[k] = FACE.x + (x - midX) * fx; T.v[k] = FACE.eyeY + (LM.eyeY - y) * fy;
    T.beardK[k] = lz > -0.03 ? smooth(-0.55, -0.2, nf) * (y < F.chin ? 1 - smooth(BEARD_UNDER[0], BEARD_UNDER[1], F.chin - y) : 1) : 0;
    T.faceK[k] = isHead && nf > -0.15 && lz > -0.02 ? smooth(-0.15, 0.25, nf) : 0;
    T.el[k] = isHead ? Math.atan2(ly, Math.hypot(lx, lz)) * 57.2958 : 999; T.az[k] = Math.atan2(lx, lz) * 57.2958;
    T.det[k] = D ? Math.max(DETAIL_CLAMP[0], Math.min(DETAIL_CLAMP[1], 1 + DETAIL_SKIN * (D[i] - 1))) : 1;
    T.head[k] = isHead ? 1 : 0;
    T.out[k] = (((i / S) | 0) - ry) * rw * 4 + ((i % S) - rx) * 4;
  }
  model.maps.set(key, T);
  return T;
}

// collo: quanto è pelle (1) o maglia (0) per uno scollo, una volta per scollo
function neckTable(model, S, T, collar) {
  if (T.neck[collar]) return T.neck[collar];
  const M = model.texMap(S), LM = model.L, a = new Float32Array(T.n);
  for (let k = 0; k < T.n; k++) { const i = T.idx[k]; a[k] = T.head[k] ? 1 : neckSkin(model, collar, M.pos[i * 3], M.pos[i * 3 + 1], M.pos[i * 3 + 2], LM); }
  return (T.neck[collar] = a);
}

// ripittura di testa e collo sopra la texture di src/athlete3d.js
function repaintHead(model, cv, kit, L, S) {
  const H = headTexels(model, S), T = headTable(model, S), A = neckTable(model, S, T, (kit.style && kit.style.collar) | 0);
  const skinH = SKINS[L.skin][1], hairC = HAIR_COLORS[L.hairColor][1], sk = rgb(skinH), hs = rgb(shade(hairC, 0.85)), warmK = 0.22 + 0.22 * lumH(skinH);
  const warm = [sk[0] * 1.03 + 6, sk[1] * 0.9, sk[2] * 0.88], cool = [sk[0] * 0.86, sk[1] * 0.84, sk[2] * 0.9], deep = [sk[0] * 0.7, sk[1] * 0.64, sk[2] * 0.66], lashC = [24, 16, 12];
  const { beard, face } = faceLayers(model, L, skinH, hairC), stubble = L.beard === 1, hair = L.hair;
  // strato a parte con l'alfa (1 = pelle piena, meno sul bordo dello scollo) disegnato sopra: niente rilettura della texture
  const [rx, ry, rw, rh] = H.rect, lay = model._headLay && model._headLay.width === rw && model._headLay.height === rh ? model._headLay : (model._headLay = cpuCanvas(rw, rh));
  const lg = lay.getContext('2d'), img = lg.createImageData(rw, rh), px = img.data, col = [0, 0, 0], s4 = [0, 0, 0, 0];
  for (let k = 0; k < T.n; k++) {
    const a = A[k]; if (a <= 0) continue;
    col[0] = sk[0]; col[1] = sk[1]; col[2] = sk[2];
    if (T.warm[k] > 0.01) mixc(col, warm, Math.min(0.6, T.warm[k] * warmK));
    if (T.cool[k] > 0.007) mixc(col, cool, T.cool[k]);
    if (T.deep[k] > 0) mixc(col, deep, T.deep[k]);
    if (T.lash[k] > 0) mixc(col, lashC, T.lash[k]);
    if (beard && T.beardK[k] > 0) {
      bilinear(beard, T.u[k], T.v[k], s4);
      if (s4[3] > 0) { const n = hash01(T.idx[k], 2246822519); mixc(col, s4, s4[3] * T.beardK[k] * (stubble ? 0.25 + 0.75 * n * n : 0.72 + 0.28 * n)); } // grana della barba
    }
    if (T.faceK[k] > 0) { bilinear(face, T.u[k], T.v[k], s4); if (s4[3] > 0) mixc(col, s4, s4[3] * T.faceK[k]); }
    if (hair > 0 && T.el[k] < 900) { const h = scalpPaint(hair, T.el[k], T.az[k], hash01(T.idx[k], 2654435761)); if (h > 0) mixc(col, hs, h); } // cute (come in src/athlete3d.js)
    const o = T.out[k], f = T.det[k];
    px[o] = col[0] * f; px[o + 1] = col[1] * f; px[o + 2] = col[2] * f; px[o + 3] = a * 255;
  }
  // anello fuori dalle isole: ricopiato dal vicino, nello stesso ordine del dilate
  const at = i => (((i / S) | 0) - ry) * rw * 4 + ((i % S) - rx) * 4;
  for (let k = 0; k < H.ring.length; k += 2) { const a = at(H.ring[k]), b = at(H.ring[k + 1]); px[a] = px[b]; px[a + 1] = px[b + 1]; px[a + 2] = px[b + 2]; px[a + 3] = px[b + 3]; }
  lg.putImageData(img, 0, 0);
  const g = cv.getContext('2d'); g.save(); g.setTransform(1, 0, 0, 1, 0, 0); g.globalAlpha = 1; g.globalCompositeOperation = 'source-over'; g.drawImage(lay, rx, ry); g.restore();
}

// tassello degli occhi: sclera sfumata, iride più piccola con venature e anello scuro, pupilla, due riflessi;
// palpebre (pelle) per le forme dell'editor: tondi, a mandorla, sottili, grandi, allungati, assonnati
const EYE_SHAPE = [ // iride (frazione del tassello), palpebra sopra, palpebra sotto (frazioni dell'apertura)
  [0.105, 0, 0], [0.1, 0.12, 0.08], [0.095, 0.2, 0.12], [0.115, 0, 0], [0.1, 0.1, 0.12], [0.105, 0.34, 0.04]];
function paintEyesFine(g, L, skinH) {
  const [x, y, w, h] = EYE_PX, cx = x + w / 2, cy = y + h / 2, iris = EYE_COLORS[L.eyeColor][1], [ik, top, bot] = EYE_SHAPE[L.eyes] || EYE_SHAPE[0];
  g.save(); g.beginPath(); g.rect(x, y, w, h); g.clip();
  g.fillStyle = shade(skinH, 0.85); g.fillRect(x, y, w, h);
  const sc = g.createRadialGradient(cx, cy, 4, cx, cy, w * 0.44);
  sc.addColorStop(0, '#f4f0ea'); sc.addColorStop(0.6, '#ebe3da'); sc.addColorStop(0.9, '#d9c9bf'); sc.addColorStop(1, shade(skinH, 0.9));
  g.fillStyle = sc; g.beginPath(); g.ellipse(cx, cy, w * 0.44, h * 0.32, 0, 0, Math.PI * 2); g.fill();
  const ir = w * ik * IRIS_K, ig = g.createRadialGradient(cx, cy, ir * 0.3, cx, cy, ir);
  ig.addColorStop(0, shade(iris, 1.25)); ig.addColorStop(0.7, iris); ig.addColorStop(1, shade(iris, 0.6));
  g.fillStyle = ig; g.beginPath(); g.arc(cx, cy, ir, 0, Math.PI * 2); g.fill();
  g.strokeStyle = shade(iris, 0.7); g.lineWidth = 0.8; g.globalAlpha = 0.6;
  for (let k = 0; k < 28; k++) { const a = k / 28 * Math.PI * 2; g.beginPath(); g.moveTo(cx + Math.cos(a) * ir * 0.45, cy + Math.sin(a) * ir * 0.45); g.lineTo(cx + Math.cos(a + 0.08) * ir * 0.95, cy + Math.sin(a + 0.08) * ir * 0.95); g.stroke(); }
  g.globalAlpha = 1; g.strokeStyle = 'rgba(20,14,10,0.75)'; g.lineWidth = 1.6; g.beginPath(); g.arc(cx, cy, ir, 0, Math.PI * 2); g.stroke();
  g.fillStyle = '#0b0806'; g.beginPath(); g.arc(cx, cy, ir * 0.42, 0, Math.PI * 2); g.fill();
  g.fillStyle = 'rgba(255,255,255,0.92)'; g.beginPath(); g.arc(cx - ir * 0.38, cy - ir * 0.38, ir * 0.2, 0, Math.PI * 2); g.fill();
  g.fillStyle = 'rgba(255,255,255,0.45)'; g.beginPath(); g.arc(cx + ir * 0.35, cy + ir * 0.3, ir * 0.09, 0, Math.PI * 2); g.fill();
  // ombra della palpebra in alto, poi le palpebre della forma scelta con il bordo delle ciglia
  const sh = g.createLinearGradient(0, y + h * 0.18, 0, cy); sh.addColorStop(0, 'rgba(40,25,20,0.45)'); sh.addColorStop(1, 'rgba(40,25,20,0)');
  g.fillStyle = sh; g.fillRect(x, y, w, h / 2);
  const lidC = shade(skinH, 0.9);
  if (top > 0) {
    const ly = cy - h * 0.32 + h * 0.64 * top;
    g.fillStyle = lidC; g.beginPath(); g.moveTo(x, y); g.lineTo(x + w, y); g.lineTo(x + w, ly - h * 0.06); g.quadraticCurveTo(cx, ly + h * 0.05, x, ly - h * 0.06); g.fill();
    g.strokeStyle = 'rgba(25,16,12,0.85)'; g.lineWidth = 2.2; g.beginPath(); g.moveTo(x + w * 0.08, ly - h * 0.05); g.quadraticCurveTo(cx, ly + h * 0.05, x + w * 0.92, ly - h * 0.05); g.stroke();
  }
  if (bot > 0) {
    const ly = cy + h * 0.32 - h * 0.64 * bot;
    g.fillStyle = lidC; g.beginPath(); g.moveTo(x, y + h); g.lineTo(x + w, y + h); g.lineTo(x + w, ly + h * 0.04); g.quadraticCurveTo(cx, ly - h * 0.04, x, ly + h * 0.04); g.fill();
  }
  g.restore();
}

// punti del viso dopo la deformazione (toni della pelle, ciglia, fine della barba)
function faceMarks(model) {
  const P = model.mesh.geometry.attributes.position, isEye = model.isEye, LM = model.L;
  const eyes = [model.eyeL, model.eyeR].map(c => {
    // raggio dell'apertura: distanza dal centro dell'occhio dei vertici della testa più vicini
    const ds = []; for (let i = 0; i < P.count; i++) if (!isEye[i]) { const d = Math.hypot(P.getX(i) - c.x, P.getY(i) - c.y, P.getZ(i) - c.z); if (d < 0.03) ds.push(d); }
    ds.sort((a, b) => a - b);
    return { x: c.x, y: c.y, z: c.z, r: ds[Math.min(ds.length - 1, 3)] || 0.012 };
  });
  return { chin: headMarks(model.mesh).chin, eyes, cheekX: LM.eyeDX * 1.15, cheekY: -0.032, cheekR: 0.018, noseY: -0.03, noseR: 0.012, earX: EAR_X + 0.006, earZ: LM.faceZ - 0.06 };
}

// ---------------------------------------------------------------- aggancio al modello (src/athlete3d.js)
// installHead(model): forma subito (prima delle misure del modello); pittura agganciata a paint() e paintEyes()
export function installHead(model) {
  model.headMarks = shapeHead(model.mesh);
  const paint = model.paint;
  model.paint = function (kit, look, opt, size) {
    const cv = paint.call(this, kit, look, opt, size);
    if (!this.face) this.face = faceMarks(this);
    repaintHead(this, cv, kit, look, size);
    return cv;
  };
  model.paintEyes = paintEyesFine;
}
