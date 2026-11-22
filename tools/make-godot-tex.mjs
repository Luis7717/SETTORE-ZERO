// Texture dei capelli e del viso per la versione Godot, disegnate col canvas di Chrome con lo STESSO codice del web,
// così i capelli e le barbe di Godot hanno la stessa pittura del gioco web.
//
// 1) godot/assets/textures/capelli_tinta.png: la tinta dei 17 tagli (paintHairTex di src/hair3d.js), una cella per
//    taglio. Il colore non è fisso: ogni pixel dice "quanto" di tre colori ci va, e lo shader li mescola per giocatore:
//      R = colore dei capelli, G = lucentezza (shine del web), B = pelle; il resto è nero.
//    Funziona perché tutte le tinte di paintHairTex sono miscele di questi tre (scuro = capelli verso il nero, ecc.)
//    e il canvas mescola i colori in modo lineare. L'elastico di coda e chignon lo colora lo shader (dipende dalla tinta).
// 2) godot/assets/textures/viso_maschere.png: barbe (ridisegnate il 2026-11-22, non più come il web: lì erano
//    maschere dure e corta e piena quasi uguali), sopracciglia (paintBrowsFine del web) e labbra nella zona viso del
//    web (FACE_CROP), già sfumate come softAlpha del web.
//    Celle k = 0..5: R = barba k + 1, G = sopracciglia k, B = quanto è scuro il pelo delle sopracciglia; cella 6: labbra
//    (R = labbra, G = linea della bocca).
// Uso: node tools/make-godot-tex.mjs   (poi $G --headless --path godot --import)
// Le funzioni di disegno (tranne le barbe) sono copie di quelle del web (stesse forme e numeri): se cambiano lì, vanno ricopiate qui.
import { readFileSync, writeFileSync } from 'node:fs';
import puppeteer from 'puppeteer-core';

export const HAIR_SCALE = 2;          // pixel per unità della zona capelli del web (200 × 92 su 1024)
export const HAIR_PAD = 8;            // margine attorno a ogni cella (unità del web)
export const HAIR_COLS = 4;
export const FACE_CROP = [200, 150, 240, 260];

const hairSrc = readFileSync(new URL('../src/hair3d.js', import.meta.url), 'utf8');

const page = String.raw`
<canvas id=c></canvas>
<script type=module>
${hairSrc}
const FACE = { x: 320, eyeY: 222, eyeDX: 36, browY: 196, noseY: 247, mouthY: 274 };
const cpu = (w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; };
// colori "a coefficienti": [capelli, lucentezza, pelle] → rgb
const K = (a, b = 0, c = 0) => 'rgb(' + Math.round(a * 255) + ',' + Math.round(b * 255) + ',' + Math.round(c * 255) + ')';

// ---- copia di paintHairTex (src/hair3d.js) con le tinte a coefficienti; l'elastico lo fa lo shader
function paintHairCoef(g, style, rect) {
  const [x, y, w, h] = rect, st = HAIR[style] || {}, kind = st.paint || 'fine';
  const hairC = K(1), dark = K(1 - 0.38), deep = K(1 - 0.62), shine = K(0, 1);
  const hs = t => K(1 - t, t);   // mixHex(hairC, shine, t)
  const X = u => x + w * u, Y = v => y + h * v;
  g.save();
  g.fillStyle = hairC; g.fillRect(x - 16, y - 16, w + 32, h + 32);
  g.beginPath(); g.rect(x - 16, y - 16, w + 32, h + 32); g.clip();
  const sx = X(0), sw = X(0.8) - sx, top = Y(0), edge = Y(TEX_EDGE + 0.04);
  const gr = g.createLinearGradient(0, Y(TEX_TOP), 0, Y(TEX_EDGE));
  gr.addColorStop(0, K(1 - 0.06)); gr.addColorStop(0.42, hs(0.35)); gr.addColorStop(0.72, hairC); gr.addColorStop(1, K(1 - 0.18));
  g.fillStyle = gr; g.fillRect(sx, top, sw, edge - top);
  const rand = s => { let a = s; return () => { a = (a * 16807) % 2147483647; return a / 2147483647; }; };
  const r = rand(97 + style * 31);
  const shellH = Y(TEX_EDGE) - Y(TEX_TOP);
  if (kind === 'curly' || kind === 'afro') {
    const n = kind === 'afro' ? 1400 : 900, rr = kind === 'afro' ? 1.1 : 1.6;
    for (let i = 0; i < n; i++) { const px = sx + r() * sw, py = Y(TEX_TOP) + r() * shellH, s = r(), a0 = r() * 6.3; g.strokeStyle = s < 0.5 ? dark : s < 0.85 ? hs(0.6) : shine; g.lineWidth = 0.7 + 0.5 * r(); g.globalAlpha = 0.45 + 0.35 * r(); g.beginPath(); g.arc(px, py, rr * (0.8 + r()), a0, a0 + 3.6); g.stroke(); }
    g.globalAlpha = 1;
  } else if (kind === 'braids') {
    const nb = 12, bw = sw / nb;
    for (let k = 0; k < nb; k++) {
      const cx = sx + bw * (k + 0.5);
      g.fillStyle = deep; g.globalAlpha = 0.55; g.fillRect(sx + bw * k - 0.6, top, 1.2, edge - top); g.globalAlpha = 1;
      g.strokeStyle = dark; g.lineWidth = 0.9;
      for (let py = Y(0.3); py < edge; py += 3.2) { g.beginPath(); g.moveTo(cx - bw * 0.42, py); g.lineTo(cx, py + 1.8); g.lineTo(cx + bw * 0.42, py); g.stroke(); }
      g.strokeStyle = shine; g.globalAlpha = 0.5; g.beginPath(); g.moveTo(cx - bw * 0.15, Y(0.3)); g.lineTo(cx - bw * 0.15, edge); g.stroke(); g.globalAlpha = 1;
    }
  } else if (kind !== 'none') {
    const n = kind === 'slick' ? 160 : kind === 'brush' ? 60 : 110, a = kind === 'slick' ? 0.3 : 0.18;
    g.lineCap = 'round';
    for (let i = 0; i < n; i++) {
      const px = sx + r() * sw, y0 = Y(TEX_TOP) + r() * shellH * 0.5, len = shellH * (0.3 + r() * 0.6);
      g.strokeStyle = r() < 0.55 ? dark : shine; g.globalAlpha = a * (0.5 + r() * 0.5); g.lineWidth = 0.6 + r() * 0.8;
      g.beginPath(); g.moveTo(px, y0); g.lineTo(px + (r() - 0.5) * 2, Math.min(edge, y0 + len)); g.stroke();
    }
    g.globalAlpha = 1;
    if (kind === 'brush') for (let i = 0; i < 500; i++) { g.fillStyle = r() < 0.5 ? dark : shine; g.globalAlpha = 0.3; g.fillRect(sx + r() * sw, Y(TEX_TOP) + r() * shellH * 0.6, 0.9, 0.9); }
    g.globalAlpha = 1;
  }
  if (kind !== 'none') {
    const by = Y(kind === 'slick' ? 0.3 : 0.36), bh = shellH * (kind === 'slick' ? 0.2 : 0.14);
    for (let i = 0; i < 70; i++) { g.fillStyle = shine; g.globalAlpha = 0.18 + 0.25 * r(); g.fillRect(sx + r() * sw, by + (r() - 0.5) * bh * 0.6, 0.8 + r() * 1.6, bh * (0.4 + r() * 0.6)); }
    g.globalAlpha = 1;
  }
  if (kind === 'fade' || kind === 'brush') {
    const fg = g.createLinearGradient(0, Y(0.55), 0, Y(TEX_EDGE)); fg.addColorStop(0, 'rgba(0,0,0,0)'); fg.addColorStop(1, K(0.5, 0, 0.5));
    g.fillStyle = fg; g.fillRect(sx, Y(0.55), sw, Y(TEX_EDGE + 0.04) - Y(0.55));
  }
  if (kind === 'fringe') { g.fillStyle = dark; g.globalAlpha = 0.5; g.fillRect(sx, Y(TEX_EDGE - 0.08), sw, Y(TEX_EDGE + 0.04) - Y(TEX_EDGE - 0.08)); g.globalAlpha = 1; }
  if (kind === 'part' && st.part != null) {
    const ln = prof(st.part, st.line), C = st.cols || HAIR_SHELL_COLS, vOf = e => (e - ln) / (90 - ln);
    const u = TEX_SHELL[0] + (TEX_SHELL[1] - TEX_SHELL[0]) * Math.round((st.part + 180) / 360 * C) / C;
    g.strokeStyle = K(0.55, 0, 0.45); g.lineWidth = 1.1; g.beginPath(); g.moveTo(X(u), Y(TEX_EDGE + (TEX_TOP - TEX_EDGE) * vOf(ln + 2))); g.lineTo(X(u), Y(TEX_EDGE + (TEX_TOP - TEX_EDGE) * vOf(80))); g.stroke();
  }
  g.fillStyle = K(0.62 * 0.6 + 0.38 * 0.4); g.fillRect(sx, Y(TEX_UNDER - 0.03), sw, Y(1) + 16 - Y(TEX_UNDER - 0.03));
  const ex = X(TEX_EXTRA[0] - 0.03), ew = X(TEX_EXTRA[1] + 0.03) - ex;
  const eg = g.createLinearGradient(0, Y(0), 0, Y(1)); eg.addColorStop(0, dark); eg.addColorStop(0.3, hs(0.4)); eg.addColorStop(0.6, hairC); eg.addColorStop(1, hs(0.3));
  g.fillStyle = eg; g.fillRect(ex, Y(0) - 16, ew, h + 32);
  for (let i = 0; i < 40; i++) { g.strokeStyle = r() < 0.5 ? dark : shine; g.globalAlpha = 0.25; g.lineWidth = 0.7; const px = ex + r() * ew; g.beginPath(); g.moveTo(px, Y(r() * 0.5)); g.lineTo(px, Y(0.5 + r() * 0.5)); g.stroke(); }
  g.globalAlpha = 1;
  g.restore();
}

// ---- barbe (2026-11-22, ridisegnate: non più copie del web). In bianco: conta solo l'alfa; lo shader mette il
// colore e i peli (più radi verso il bordo). Bordi morbidi: si sfuma molto di più del web (SOFT_BARBA), niente
// righe dritte sulla guancia. Corta = bassa sulla guancia e rada; piena = alta, basette fino ai capelli, sotto il mento.
const SOFT_BARBA = [7, 7, 6, 7, 7, 7];   // passate di sfumatura per barba 1..6
function moustache(g, x, y, thick) {
  g.beginPath(); g.moveTo(x - 27, y + 5);
  g.quadraticCurveTo(x - 22, y - 9 - thick * 0.3, x - 4, y - 9 - thick * 0.5); g.quadraticCurveTo(x, y - 7 - thick * 0.5, x + 4, y - 9 - thick * 0.5);
  g.quadraticCurveTo(x + 22, y - 9 - thick * 0.3, x + 27, y + 5);
  g.quadraticCurveTo(x + 14, y - 4, x, y - 4); g.quadraticCurveTo(x - 14, y - 4, x - 27, y + 5); g.closePath(); g.fill();
}
function goatee(g, x, y, w) {
  g.beginPath(); g.moveTo(x - w, y + 11); g.quadraticCurveTo(x, y + 8, x + w, y + 11);
  g.quadraticCurveTo(x + w + 2, y + 34, x + w * 0.6, y + 44); g.quadraticCurveTo(x, y + 52, x - w * 0.6, y + 44);
  g.quadraticCurveTo(x - w - 2, y + 34, x - w, y + 11); g.closePath(); g.fill();
}
// barba sulle guance: top = altezza dell'attaccatura sulla guancia (y), side = basetta (y dove comincia), alpha
function fullBeard(g, x, y, e, top, side, alpha) {
  g.globalAlpha = alpha; g.beginPath();
  g.moveTo(x - 86, side); g.lineTo(x - 72, side);
  g.quadraticCurveTo(x - 68, top, x - 50, top + 8); g.quadraticCurveTo(x - 36, top + 14, x - 30, y - 6);
  g.quadraticCurveTo(x - 14, y - 16, x, y - 14); g.quadraticCurveTo(x + 14, y - 16, x + 30, y - 6);
  g.quadraticCurveTo(x + 36, top + 14, x + 50, top + 8); g.quadraticCurveTo(x + 68, top, x + 72, side);
  g.lineTo(x + 86, side); g.lineTo(x + 86, y + 30); g.quadraticCurveTo(x + 60, y + 100, x, y + 104);
  g.quadraticCurveTo(x - 60, y + 100, x - 86, y + 30); g.closePath(); g.fill();
  g.globalAlpha = 1;
}
function mouthHole(g, x, y) {
  g.globalCompositeOperation = 'destination-out'; g.globalAlpha = 1; g.beginPath(); g.ellipse(x, y + 2, 17, 6.5, 0, 0, Math.PI * 2); g.fill();
  g.globalCompositeOperation = 'source-over';
}
function paintBeardNew(g, beard) {
  const x = FACE.x, y = FACE.mouthY, e = FACE.eyeY;
  g.save(); g.fillStyle = '#ffffff';
  if (beard === 1) { fullBeard(g, x, y, e, e + 40, e + 30, 0.55); mouthHole(g, x, y); }
  if (beard === 2) { goatee(g, x, y, 14); }
  if (beard === 3) { moustache(g, x, y, 4); }
  if (beard === 4) {
    moustache(g, x, y, 3); goatee(g, x, y, 13);
    g.lineWidth = 5; g.strokeStyle = '#ffffff'; g.lineCap = 'round';   // anello attorno alla bocca
    for (const s of [-1, 1]) { g.beginPath(); g.moveTo(x + s * 25, y + 4); g.quadraticCurveTo(x + s * 22, y + 20, x + s * 12, y + 30); g.stroke(); }
  }
  if (beard === 5) { fullBeard(g, x, y, e, e + 44, e + 22, 0.75); moustache(g, x, y, 2); mouthHole(g, x, y); }
  if (beard === 6) { fullBeard(g, x, y, e, e + 24, e - 26, 1); moustache(g, x, y, 6); mouthHole(g, x, y); }
  g.restore();
}
// ---- copia di paintBrowsFine (src/body/testa.js): riempimento rosso, peli scuri verdi
const BROW_DOWN = 3;
const BROW_SHAPES = [[16, 6.5, 2.5, 0, 2], [15, 3.4, 2, 0, 1.5], [17, 9.5, 2, 0, 2], [16, 5.5, 7, 0, 3], [17, 6.5, 0.5, 0, 1], [16, 7.5, 2, -0.26, 2]];
function paintBrows(g, brows) {
  const bc = '#ff0000', dark = '#00ff00';
  const [w, th, arc, ang, tail] = BROW_SHAPES[brows] || BROW_SHAPES[0];
  let seed = 11 + brows * 7; const r = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
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
// labbra (drawFaceLayers di src/body/testa.js): riempimento in rosso, linea della bocca in verde (canvas separati)
function paintLips(g, which) {
  const mx = FACE.x, my = FACE.mouthY;
  if (which === 0) { g.globalAlpha = 0.5; g.fillStyle = '#ffffff'; g.beginPath(); g.ellipse(mx, my + 3, 17, 7.5, 0, 0, Math.PI * 2); g.fill(); }
  else { g.globalAlpha = 0.35; g.strokeStyle = '#ffffff'; g.lineWidth = 2; g.lineCap = 'round'; g.beginPath(); g.moveTo(mx - 15, my + 1); g.quadraticCurveTo(mx, my + 4, mx + 15, my + 1); g.stroke(); }
  g.globalAlpha = 1;
}
// ---- copia di softAlpha (src/body/testa.js) su un canale (Float32Array w*h)
function soft(a, w, h, passes) {
  const t = new Float32Array(w * h);
  for (let p = 0; p < passes; p++) {
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const i = y * w + x; t[i] = (a[i] * 2 + (x > 0 ? a[i - 1] : a[i]) + (x < w - 1 ? a[i + 1] : a[i])) / 4; }
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const i = y * w + x; a[i] = (t[i] * 2 + (y > 0 ? t[i - w] : t[i]) + (y < h - 1 ? t[i + w] : t[i])) / 4; }
  }
  return a;
}
const [CX, CY, CW, CH] = [${FACE_CROP.join(',')}];
// disegna con f su un canvas 640×440 e torna alfa (e, se serve, la quota di verde) della zona FACE_CROP
function layer(f) {
  const c = cpu(640, 440), g = c.getContext('2d'); f(g);
  const d = g.getImageData(CX, CY, CW, CH).data, a = new Float32Array(CW * CH), gr = new Float32Array(CW * CH);
  for (let i = 0; i < CW * CH; i++) { a[i] = d[i * 4 + 3]; const s = d[i * 4] + d[i * 4 + 1]; gr[i] = s > 0 ? d[i * 4 + 1] / s : 0; }
  return { a, gr };
}

window.makeFace = () => {
  const cols = 4, rows = 2, out = cpu(CW * cols, CH * rows), og = out.getContext('2d'), img = og.createImageData(CW * cols, CH * rows), px = img.data;
  const put = (cell, ch, arr, k = 1) => { const ox = (cell % cols) * CW, oy = Math.floor(cell / cols) * CH; for (let y = 0; y < CH; y++) for (let x = 0; x < CW; x++) px[((oy + y) * CW * cols + ox + x) * 4 + ch] = Math.round(arr[y * CW + x] * k); };
  for (let i = 3; i < px.length; i += 4) px[i] = 255;
  for (let k = 0; k < 6; k++) {
    const b = k + 1, L = layer(g => paintBeardNew(g, b));
    put(k, 0, soft(L.a, CW, CH, SOFT_BARBA[k]));
    const B = layer(g => paintBrows(g, k));
    put(k, 1, soft(B.a, CW, CH, 2)); put(k, 2, B.gr, 255);
  }
  put(6, 0, soft(layer(g => paintLips(g, 0)).a, CW, CH, 2)); put(6, 1, soft(layer(g => paintLips(g, 1)).a, CW, CH, 2));
  og.putImageData(img, 0, 0);
  return out.toDataURL('image/png');
};

window.makeHair = (S, PAD, COLS) => {
  const cw = (200 + 2 * PAD) * S, ch = (92 + 2 * PAD) * S, rows = Math.ceil(HAIR.length / COLS);
  const out = cpu(cw * COLS, ch * rows), g = out.getContext('2d');
  g.fillStyle = K(1); g.fillRect(0, 0, out.width, out.height);
  for (let s = 0; s < HAIR.length; s++) {
    g.save(); g.translate((s % COLS) * cw, Math.floor(s / COLS) * ch); g.scale(S, S);
    g.beginPath(); g.rect(0, 0, 200 + 2 * PAD, 92 + 2 * PAD); g.clip();
    paintHairCoef(g, s, [PAD, PAD, 200, 92]);
    g.restore();
  }
  return out.toDataURL('image/png');
};
window.ready = true;
</script>`;

const b = await puppeteer.launch({ executablePath: process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: 'new' });
const p = await b.newPage();
const errs = [];
p.on('pageerror', e => errs.push(e.message));
await p.setContent(page);
await p.waitForFunction('window.ready === true', { timeout: 10000 }).catch(() => {});
if (errs.length) { console.error(errs.join('\n')); process.exit(1); }
const save = (name, url) => { writeFileSync(new URL('../godot/assets/textures/' + name, import.meta.url), Buffer.from(url.split(',')[1], 'base64')); console.log('scritto godot/assets/textures/' + name); };
save('capelli_tinta.png', await p.evaluate((S, P, C) => window.makeHair(S, P, C), HAIR_SCALE, HAIR_PAD, HAIR_COLS));
save('viso_maschere.png', await p.evaluate(() => window.makeFace()));
await b.close();
