// Stadio serale intorno al campo: tribune a gradoni con pubblico animato, tetto con anello di luci,
// cartelloni LED con marchi inventati, panchine, maxischermo, cielo e terreno.
// Tutto in poche draw call: ogni gruppo è una sola geometria unita, le texture sono disegnate su canvas.
// Coordinate three: x = larghezza, y = altezza, z = -y del motore. La telecamera sta verso +z.
import * as THREE from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { HW, HL } from './sim.js';

// ---------------------------------------------------------------- misure (metri)
const SIDE_GAP = 12;          // dalla linea laterale al muretto della tribuna laterale
const END_GAP = 13;           // dalla linea di porta al muretto della tribuna di fondo lontana
const BACK_EXTRA = 5;         // la tribuna alle spalle della telecamera è un po' più lontana
const FRONT_H = 1.6;          // muretto davanti al primo anello
const T1 = { rows: 14, rise: 0.42, run: 0.8 };   // primo anello
const VIP_H = 3.0;            // fascia delle tribune vip tra i due anelli
const PARAPET_D = 1.0;        // passaggio davanti al secondo anello
const T2 = { rows: 16, rise: 0.5, run: 0.8 };    // secondo anello (più ripido)
const AISLE_EVERY = 12, AISLE_W = 1.2;           // settori e scalette
const ROOF = { front: 5, back: 27, yFront: 25, yBack: 23, thick: 0.9 };
const BOARD = { h: 0.95, panel: 4, side: HW + 4, end: HL + 6, zMax: HL + 4 };
const BENCH_X = -(HW + 2.6);
const SEAT_W = 0.55, CELLS = 32, TILE = SEAT_W * CELLS, CROWD_H = 2.2;
const LIGHT_EVERY = 6, LIGHT_SIZE = 3.4;
const CROWD_SHADE = [0.62, 1.06];   // luminosità del pubblico in basso e in alto di ogni fila
const AD_ROWS = 8, AD_HOLD = 6, AD_SCROLL = 0.45;

const BRANDS = [
  ['TIRO A GIRO', '#0b3d91'], ['CAFFÈ BORGO', '#6b3a1f'], ['GELATERIA STELLA', '#d6336c'], ['FORNO DEL CORSO', '#c77700'],
  ['RADIO CURVA', '#5b2a86'], ['PIZZERIA DA NINO', '#b3122b'], ['OFFICINA ROSSI', '#14606e'], ['PASTA MONTI', '#e0a100'],
  ['BICI LAMPO', '#0f7a55'], ['ACQUA FONTEVIVA', '#1d7fc4'], ['MOBILI GIRARDI', '#7a4e2d'], ['FERRAMENTA BRUNO', '#c44e00'],
  ['LATTERIA ALPINA', '#2b7bb9'], ['TAXI 777', '#d9b300'], ['CARTOLERIA LUNA', '#3a3f9e'], ['AUTO CORTI', '#a11d1d'],
];
const BANNERS = [['FORZA RAGAZZI', '#b3122b', '#fff'], ['CURVA DEL BORGO', '#0b3d91', '#ffd43b'], ['SEMPRE CON VOI', '#111', '#fff'],
  ['TIRO A GIRO', '#0f7a55', '#fff'], ['NOI CI CREDIAMO', '#ffd43b', '#111'], ['GLI AMICI DELLA STELLA', '#5b2a86', '#fff']];

function canvasTex(w, h, draw) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4;
  return t;
}
const rnd = (a, b) => a + Math.random() * (b - a);
const pick = arr => arr[(Math.random() * arr.length) | 0];

// ---------------------------------------------------------------- costruttore di geometrie a quadrilateri
// Ogni quadrilatero: angoli a,b,c,d (in basso a sinistra, in basso a destra, in alto a destra, in alto a sinistra
// visti da chi guarda), un colore (o 4) e un rettangolo uv [u0, v0, u1, v1]. `face` indica da che parte si guarda:
// se l'ordine dei vertici è al contrario lo si gira, così le facce posteriori si possono scartare.
const WHITE_UV = [0.01, 0.99, 0.02, 0.995];
const V = new THREE.Vector3(), V2 = new THREE.Vector3(), V3 = new THREE.Vector3();
class QuadBuilder {
  constructor() { this.pos = []; this.col = []; this.uv = []; }
  quad(a, b, c, d, color, uv = WHITE_UV, face = null) {
    const cols = Array.isArray(color) ? color : [color, color, color, color];
    const uvs = [[uv[0], uv[1]], [uv[2], uv[1]], [uv[2], uv[3]], [uv[0], uv[3]]];
    let p = [a, b, c, d], q = [0, 1, 2, 3];
    if (face) {
      V.set(b[0] - a[0], b[1] - a[1], b[2] - a[2]); V2.set(c[0] - a[0], c[1] - a[1], c[2] - a[2]);
      if (V3.crossVectors(V, V2).dot(V.set(face[0], face[1], face[2])) < 0) { p = [a, d, c, b]; q = [0, 3, 2, 1]; }
    }
    for (const k of [0, 1, 2, 0, 2, 3]) {
      this.pos.push(p[k][0], p[k][1], p[k][2]);
      const cc = cols[q[k]]; this.col.push(cc.r, cc.g, cc.b);
      this.uv.push(uvs[q[k]][0], uvs[q[k]][1]);
    }
  }
  tri(a, b, c, color, face) {
    V.set(b[0] - a[0], b[1] - a[1], b[2] - a[2]); V2.set(c[0] - a[0], c[1] - a[1], c[2] - a[2]);
    const pts = V3.crossVectors(V, V2).dot(V.set(face[0], face[1], face[2])) < 0 ? [a, c, b] : [a, b, c];
    for (const p of pts) { this.pos.push(p[0], p[1], p[2]); this.col.push(color.r, color.g, color.b); this.uv.push(WHITE_UV[0], WHITE_UV[1]); }
  }
  // parete verticale rivolta verso -z (il campo, nel sistema locale della tribuna): xl è il bordo sinistro visto dal campo
  wall(xl, xr, z, y0, y1, color, uv) { this.quad([xl, y0, z], [xr, y0, z], [xr, y1, z], [xl, y1, z], color, uv, [0, 0, -1]); }
  floor(x0, x1, z0, z1, y, color, uv) { this.quad([x0, y, z0], [x1, y, z0], [x1, y, z1], [x0, y, z1], color, uv, [0, 1, 0]); }
  box(cx, cy, cz, sx, sy, sz, color, top = color) {
    const x0 = cx - sx / 2, x1 = cx + sx / 2, y0 = cy - sy / 2, y1 = cy + sy / 2, z0 = cz - sz / 2, z1 = cz + sz / 2;
    this.quad([x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1], top, WHITE_UV, [0, 1, 0]);
    this.quad([x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0], color, WHITE_UV, [0, 0, -1]);
    this.quad([x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1], color, WHITE_UV, [0, 0, 1]);
    this.quad([x0, y0, z0], [x0, y0, z1], [x0, y1, z1], [x0, y1, z0], color, WHITE_UV, [-1, 0, 0]);
    this.quad([x1, y0, z0], [x1, y0, z1], [x1, y1, z1], [x1, y1, z0], color, WHITE_UV, [1, 0, 0]);
  }
  geometry(matrix) {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(this.pos, 3));
    g.setAttribute('color', new THREE.Float32BufferAttribute(this.col, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(this.uv, 2));
    if (matrix) g.applyMatrix4(matrix);
    return g;
  }
}
const C = (hex, k = 1) => new THREE.Color(hex).multiplyScalar(k);
const placeMatrix = (rotY, x, z) => new THREE.Matrix4().makeRotationY(rotY).setPosition(x, 0, z);

// ---------------------------------------------------------------- texture
const ATLAS = 1024;
const region = (x, y, w, h, pad = 2) => [(x + pad) / ATLAS, 1 - (y + h - pad) / ATLAS, (x + w - pad) / ATLAS, 1 - (y + pad) / ATLAS];
const R = { vip: region(0, 64, 512, 128), fascia: region(512, 64, 512, 64), screen: region(0, 576, 1024, 384) };
R.banners = BANNERS.map((_, i) => region((i % 2) * 512, 256 + ((i / 2) | 0) * 96, 512, 96));

function fitText(g, text, x, y, maxW, size, weight = 900) {
  g.font = `${weight} ${size}px system-ui, Arial, sans-serif`;
  g.fillText(text, x, y, maxW);
}

function drawVip(g) {
  g.fillStyle = '#121722'; g.fillRect(0, 64, 512, 128);
  for (let i = 0; i < 8; i++) {
    const x = i * 64 + 4, gr = g.createLinearGradient(0, 74, 0, 182);
    gr.addColorStop(0, '#ffe2ae'); gr.addColorStop(1, '#b8743c'); g.fillStyle = gr; g.fillRect(x, 74, 56, 104);
    g.fillStyle = 'rgba(20,16,24,0.85)';
    for (let k = 0; k < 4; k++) { const hx = x + 6 + k * 13 + rnd(-2, 2); g.beginPath(); g.arc(hx, 150, 5, 0, 7); g.fill(); g.fillRect(hx - 6, 154, 12, 24); }
  }
  g.fillStyle = '#d7dde8'; g.fillRect(0, 64, 512, 6);
}
function drawFascia(g) {
  g.fillStyle = '#2b3242'; g.fillRect(512, 64, 512, 64);
  g.fillStyle = '#f4f8ff'; g.fillRect(512, 70, 512, 8); g.fillRect(512, 112, 512, 6);
  g.fillStyle = '#3d4658'; for (let x = 512; x < 1024; x += 32) g.fillRect(x, 80, 3, 30);
}
function drawBanner(g, i) {
  const [text, bg, fg] = BANNERS[i], x = (i % 2) * 512, y = 256 + ((i / 2) | 0) * 96;
  g.fillStyle = bg; g.fillRect(x, y, 512, 96);
  g.fillStyle = fg; g.fillRect(x, y + 6, 512, 5); g.fillRect(x, y + 85, 512, 5);
  g.textAlign = 'center'; g.textBaseline = 'middle'; fitText(g, text, x + 256, y + 50, 470, 54);
}
function drawScreen(g) {
  const x = 0, y = 576, w = 1024, h = 384;
  g.fillStyle = '#0c0f16'; g.fillRect(x, y, w, h);
  const gr = g.createLinearGradient(0, y + 20, 0, y + h - 20); gr.addColorStop(0, '#0f2b5c'); gr.addColorStop(1, '#06142e');
  g.fillStyle = gr; g.fillRect(x + 18, y + 18, w - 36, h - 36);
  // pallone con la scia a giro
  g.strokeStyle = '#ffd43b'; g.lineWidth = 14; g.beginPath(); g.arc(x + 210, y + 250, 120, Math.PI * 1.05, Math.PI * 1.75); g.stroke();
  g.fillStyle = '#fff'; g.beginPath(); g.arc(x + 300, y + 150, 46, 0, 7); g.fill();
  g.fillStyle = '#111'; g.beginPath(); for (let k = 0; k < 5; k++) { const a = k * 1.2566 - 1.57; g.lineTo(x + 300 + Math.cos(a) * 18, y + 150 + Math.sin(a) * 18); } g.fill();
  g.fillStyle = '#fff'; g.textAlign = 'left'; g.textBaseline = 'middle'; fitText(g, 'TIRO A GIRO', x + 380, y + 160, 600, 110);
  g.fillStyle = '#ffd43b'; fitText(g, 'STADIO DEI TIGLI', x + 384, y + 268, 580, 56, 800);
  g.fillStyle = 'rgba(255,255,255,0.06)'; for (let k = y + 18; k < y + h - 18; k += 4) g.fillRect(x + 18, k, w - 36, 1);
}
function structureTexture() {
  return canvasTex(ATLAS, ATLAS, (g) => {
    g.fillStyle = '#fff'; g.fillRect(0, 0, 64, 64);
    drawVip(g); drawFascia(g); BANNERS.forEach((_, i) => drawBanner(g, i)); drawScreen(g);
  });
}

// Pubblico: 32 persone per riga, 2 righe di varianti calme (in alto) e le stesse persone a braccia alzate (in basso).
function personLook(home, away) {
  const r = Math.random(), misc = ['#2a2d36', '#3b4252', '#6b7280', '#e5e7eb', '#1f3a5f', '#5b3b2a', '#7a1f2b', '#355e3b', '#c2b280'];
  const shirt = r < 0.4 ? home[0] : r < 0.55 ? home[1] : r < 0.68 ? away[0] : pick(misc);
  return {
    empty: Math.random() < 0.07, shirt, w: (rnd(17, 24)) | 0, h: (rnd(40, 50)) | 0,
    skin: pick(['#f1c9a5', '#e0b48c', '#c68f63', '#8d5a3b', '#5e3b26']),
    hair: pick(['#1c1410', '#3a2414', '#6b4423', '#c9a45c', '#9a9a9a', '#111']),
    cap: Math.random() < 0.15 ? pick([home[0], away[0], '#111', '#fff']) : null,
    scarf: Math.random() < 0.35 ? (Math.random() < 0.75 ? home : away) : null,
    flag: Math.random() < 0.03 ? (Math.random() < 0.8 ? home : away) : null,
  };
}
function drawPerson(g, x, y, p, up) {
  const cx = x + 16, base = y + 127, top = base - p.h, l = cx - p.w / 2, hy = top - 6;
  if (p.flag) { g.fillStyle = '#ddd'; g.fillRect(cx + 7, y + 4, 2, top - y); g.fillStyle = p.flag[0]; g.fillRect(cx - 14, y + 4, 21, 9); g.fillStyle = p.flag[1]; g.fillRect(cx - 14, y + 13, 21, 8); }
  g.fillStyle = p.shirt;
  if (up) { g.fillRect(l - 2, top - 30, 5, 36); g.fillRect(l + p.w - 3, top - 30, 5, 36); }
  g.beginPath(); g.roundRect(l, top, p.w, base - top + 1, [7, 7, 0, 0]); g.fill();
  const sg = g.createLinearGradient(0, top, 0, base); sg.addColorStop(0, 'rgba(255,255,255,0.14)'); sg.addColorStop(0.35, 'rgba(0,0,0,0)'); sg.addColorStop(1, 'rgba(0,0,0,0.3)');
  g.fillStyle = sg; g.beginPath(); g.roundRect(l, top, p.w, base - top + 1, [7, 7, 0, 0]); g.fill();
  g.fillStyle = 'rgba(0,0,0,0.22)'; if (!up) { g.fillRect(l + 1, top + 8, 3, 28); g.fillRect(l + p.w - 4, top + 8, 3, 28); }
  if (p.scarf && !up) { g.fillStyle = p.scarf[0]; g.fillRect(l + 2, top + 1, p.w - 4, 5); g.fillStyle = p.scarf[1]; g.fillRect(cx - 2, top + 6, 4, 14); }
  g.fillStyle = p.skin; g.beginPath(); g.arc(cx, hy, 7, 0, 7); g.fill();
  if (up) { g.beginPath(); g.arc(l + 0.5, top - 32, 3, 0, 7); g.arc(l + p.w - 0.5, top - 32, 3, 0, 7); g.fill(); }
  g.fillStyle = p.cap || p.hair; g.beginPath(); g.arc(cx, hy - 1, 7.5, Math.PI, 0); g.fill();
  if (p.cap) g.fillRect(cx - 9, hy - 2, 18, 2);
  if (up && p.scarf) { g.fillStyle = p.scarf[0]; g.fillRect(x, top - 34, 32, 7); g.fillStyle = p.scarf[1]; for (let k = 2; k < 32; k += 8) g.fillRect(x + k, top - 34, 4, 7); }
}
function crowdTexture(home, away) {
  const t = canvasTex(1024, 512, (g) => {
    g.clearRect(0, 0, 1024, 512);
    for (let v = 0; v < 2; v++) for (let j = 0; j < CELLS; j++) {
      const p = personLook(home, away); if (p.empty) continue;
      drawPerson(g, j * 32, v * 128, p, false); drawPerson(g, j * 32, 256 + v * 128, p, true);
    }
  });
  t.wrapS = THREE.RepeatWrapping;
  return t;
}

function adsTexture() {
  const t = canvasTex(1024, 512, (g) => {
    g.textAlign = 'center'; g.textBaseline = 'middle';
    for (let r = 0; r < AD_ROWS; r++) for (let c = 0; c < 4; c++) {
      const [text, col] = BRANDS[(r * 4 + c + r) % BRANDS.length], x = c * 256, y = r * 64, dark = (r + c) % 2 === 1;
      g.fillStyle = dark ? '#0d1117' : col; g.fillRect(x, y, 256, 64);
      g.fillStyle = dark ? col : 'rgba(255,255,255,0.18)'; g.fillRect(x, y + 4, 10, 56); g.fillRect(x + 246, y + 4, 10, 56);
      g.fillStyle = dark ? '#ffffff' : '#ffffff'; if (dark) g.fillStyle = lighten(col);
      fitText(g, text, x + 128, y + 34, 220, 34);
      g.fillStyle = '#05070a'; g.fillRect(x, y, 256, 3); g.fillRect(x, y + 61, 256, 3);
    }
  });
  t.wrapT = THREE.RepeatWrapping;
  return t;
}
function lighten(hex) { const c = new THREE.Color(hex); c.lerp(new THREE.Color('#ffffff'), 0.35); return '#' + c.getHexString(); }

function glowTexture() {
  return canvasTex(64, 64, (g) => {
    const gr = g.createRadialGradient(32, 32, 1, 32, 32, 31);
    gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.12, 'rgba(255,250,235,0.95)');
    gr.addColorStop(0.35, 'rgba(255,240,210,0.28)'); gr.addColorStop(1, 'rgba(255,230,200,0)');
    g.fillStyle = gr; g.fillRect(0, 0, 64, 64);
  });
}

function skyTexture() {
  return canvasTex(1024, 512, (g, w, h) => {
    const hz = h * 0.9; // orizzonte (equatore della cupola)
    const gr = g.createLinearGradient(0, 0, 0, h);
    gr.addColorStop(0, '#050a1c'); gr.addColorStop(0.45, '#101c42'); gr.addColorStop(0.75, '#2a3266'); gr.addColorStop(0.9, '#5a4a7a'); gr.addColorStop(1, '#141626');
    g.fillStyle = gr; g.fillRect(0, 0, w, h);
    for (let x = 0; x < w; x += 2) { // ultimo chiarore del tramonto, più forte da un lato
      const k = Math.pow(Math.max(0, Math.cos((x / w) * Math.PI * 2 - 0.6)), 2);
      const gg = g.createLinearGradient(0, hz - 140, 0, hz);
      gg.addColorStop(0, 'rgba(255,140,90,0)'); gg.addColorStop(1, `rgba(255,140,90,${0.15 + 0.55 * k})`);
      g.fillStyle = gg; g.fillRect(x, hz - 140, 2, 140);
    }
    for (let i = 0; i < 500; i++) { g.fillStyle = `rgba(255,255,255,${rnd(0.2, 0.9) * (Math.random() < 0.9 ? 0.6 : 1)})`; const y = Math.pow(Math.random(), 1.6) * hz * 0.8; g.fillRect(Math.random() * w, y, Math.random() < 0.1 ? 2 : 1, 1); }
    // città lontana all'orizzonte
    for (let x = 0; x < w;) {
      const bw = rnd(6, 22), bh = rnd(3, 16); g.fillStyle = '#0b0d1a'; g.fillRect(x, hz - bh, bw, bh + 3);
      g.fillStyle = 'rgba(255,214,140,0.8)'; for (let k = 0; k < bw * bh / 30; k++) g.fillRect(x + rnd(1, bw - 1), hz - rnd(1, bh), 1, 1);
      x += bw + rnd(0, 6);
    }
    g.fillStyle = '#0b0d1a'; g.fillRect(0, hz, w, h - hz);
  });
}

// ---------------------------------------------------------------- tribuna (sistema locale: x lungo, z verso l'esterno, fronte a z=0)
function standProfile() {
  const t1 = [], t2 = [];
  for (let i = 0; i < T1.rows; i++) t1.push({ z: i * T1.run, y: FRONT_H + i * T1.rise, rise: T1.rise, run: T1.run, light: 1 - 0.15 * i / T1.rows });
  const z1 = T1.rows * T1.run, y1 = FRONT_H + T1.rows * T1.rise, y2 = y1 + VIP_H, z2 = z1 + PARAPET_D;
  for (let i = 0; i < T2.rows; i++) t2.push({ z: z2 + i * T2.run, y: y2 + i * T2.rise, rise: T2.rise, run: T2.run, light: 0.8 - 0.28 * i / T2.rows });
  return { rows: [...t1, ...t2], t1, t2, z1, y1, y2, z2, zb: z2 + T2.rows * T2.run, yb: y2 + T2.rows * T2.rise };
}
const PROFILE = standProfile();

function sections(len) {
  const n = Math.max(1, Math.round(len / (AISLE_EVERY + AISLE_W))), sw = len / n, out = [];
  for (let k = 0; k < n; k++) { const xs = -len / 2 + k * sw; out.push([xs + AISLE_W / 2, xs + sw - AISLE_W / 2]); }
  return out;
}

function addSteps(sb, len, seats) {
  const secs = sections(len), concrete = 0x8a8f99;
  for (const [ti, tier] of [PROFILE.t1, PROFILE.t2].entries()) {
    const seat = seats[ti];
    for (const r of tier) {
      const top = r.y + r.rise, k = r.light;
      for (const [s0, s1] of secs) {
        sb.wall(s1, s0, r.z, r.y, top, C(seat, 0.62 * k));
        sb.floor(s0, s1, r.z, r.z + r.run, top, C(seat, 0.95 * k));
      }
      for (let i = 0; i <= secs.length; i++) { // scalette tra i settori
        const a = i === 0 ? -len / 2 : secs[i - 1][1], b = i === secs.length ? len / 2 : secs[i][0];
        sb.wall(b, a, r.z, r.y, top, C(concrete, 0.55 * k)); sb.floor(a, b, r.z, r.z + r.run, top, C(concrete, 0.85 * k));
      }
    }
  }
}

function addCrowd(cb, len) {
  for (const r of PROFILE.rows) {
    const z = r.z + r.run * 0.35, y0 = r.y + r.rise - 0.12, y1 = y0 + CROWD_H;
    for (const [s0, s1] of sections(len)) {
      const variant = Math.random() < 0.5 ? 0 : 1, v0 = 0.5 + (1 - variant) * 0.25, u0 = ((Math.random() * CELLS) | 0) / CELLS + ((Math.random() * 8) | 0);
      const b = r.light * rnd(0.88, 1.05);
      // in basso più scuro (la fila davanti fa ombra), in alto più chiaro (i fari): il pubblico prende volume
      const lo = C(0xffffff, b * CROWD_SHADE[0]), hi = C(0xffffff, b * CROWD_SHADE[1]);
      cb.wall(s1, s0, z, y0, y1, [lo, lo, hi, hi], [u0, v0 + 0.002, u0 + (s1 - s0) / TILE, v0 + 0.248]);
    }
  }
}

function addShell(sb, len, opts) {
  const { z1, y1, y2, z2, zb, yb } = PROFILE, L2 = len / 2;
  // muretto con striscioni dei tifosi
  for (let x = L2; x > -L2; x -= 8) {
    const x1 = Math.max(-L2, x - 8), bi = opts.banners && Math.random() < 0.45 ? (Math.random() * BANNERS.length) | 0 : -1;
    sb.wall(x, x1, 0, 0, FRONT_H, C(0x1b2638));
    if (bi >= 0 && x - x1 > 7) sb.wall(x - 0.3, x1 + 0.3, -0.05, 0.15, FRONT_H - 0.1, C(0xffffff, 0.92), R.banners[bi]);
  }
  sb.floor(-L2, L2, -0.25, 0, FRONT_H, C(0xb8bec8));
  // fascia vip e parapetto del secondo anello
  for (let x = L2; x > -L2; x -= 9) sb.wall(x, Math.max(-L2, x - 9), z1, y1, y2, C(0xffffff, 0.95), R.vip);
  sb.floor(-L2, L2, z1, z2, y2, C(0x9aa0aa, 0.8));
  sb.wall(L2, -L2, z1 - 0.02, y2 - 0.35, y2, C(0xdfe4ec));
  // muro di fondo fino al tetto
  sb.wall(L2, -L2, zb, yb, ROOF.yBack, [C(0x161c28), C(0x161c28), C(0x0d1119), C(0x0d1119)]);
  // ali: nelle tribune di fondo muro e tetto continuano dietro gli angoli, così l'angolo dello stadio resta chiuso
  const RL = L2 + (opts.wing || 0);
  if (opts.wing) for (const sx of [-1, 1]) sb.wall(sx > 0 ? RL : -L2, sx > 0 ? L2 : -RL, zb, 0, ROOF.yBack, [C(0x2a3346), C(0x2a3346), C(0x1a2030), C(0x1a2030)]);
  // tetto: sotto scuro (più chiaro verso il bordo illuminato), sopra grigio, bordo frontale con la fascia luminosa
  const yb0 = ROOF.yBack - ROOF.thick, yf0 = ROOF.yFront - ROOF.thick;
  sb.quad([RL, yf0, ROOF.front], [-RL, yf0, ROOF.front], [-RL, yb0, ROOF.back], [RL, yb0, ROOF.back],
    [C(0x3a4254), C(0x3a4254), C(0x10141d), C(0x10141d)], WHITE_UV, [0, -1, 0]);
  sb.quad([-RL, ROOF.yFront, ROOF.front], [RL, ROOF.yFront, ROOF.front], [RL, ROOF.yBack, ROOF.back], [-RL, ROOF.yBack, ROOF.back], C(0x4d5566), WHITE_UV, [0, 1, 0]);
  const FL = opts.wing ? L2 + ROOF.front + 1 : L2;
  for (let x = FL; x > -FL; x -= 8) sb.wall(x, Math.max(-FL, x - 8), ROOF.front, yf0 - 0.5, ROOF.yFront + 0.1, C(0xffffff), R.fascia);
  // travi sotto il tetto
  for (let x = -L2 + 4; x < L2; x += 16) sb.box(x, (yb0 + yf0) / 2 - 0.6, (ROOF.front + ROOF.back) / 2, 0.5, 1.2, ROOF.back - ROOF.front, C(0x232a38));
  addEndFaces(sb, L2);
}

function addEndFaces(sb, L2) {
  const { rows, z1, y2, zb } = PROFILE, pts = [[0, 0], [0, FRONT_H]];
  for (const r of rows) { if (r === PROFILE.t2[0]) pts.push([z1, y2], [r.z, r.y]); pts.push([r.z, r.y + r.rise], [r.z + r.run, r.y + r.rise]); }
  pts.push([zb, ROOF.yBack], [zb, 0]);
  const tris = THREE.ShapeUtils.triangulateShape(pts.map(p => new THREE.Vector2(p[0], p[1])), []), col = C(0x1a2130);
  for (const sx of [-1, 1]) for (const t of tris) {
    const [a, b, c] = t.map(i => [sx * L2, pts[i][1], pts[i][0]]);
    sb.tri(a, b, c, col, [sx, 0, 0]);
  }
}

function addScreen(sb, len) {
  const y0 = ROOF.yBack + 0.6, h = 7, w = h * (1024 / 384), z = ROOF.back - 3;
  sb.box(0, y0 + h / 2, z + 0.4, w + 1, h + 1, 0.6, C(0x111520));
  sb.wall(w / 2, -w / 2, z, y0, y0 + h, C(0xffffff), R.screen);
  for (const sx of [-1, 1]) sb.box(sx * w * 0.35, (ROOF.yBack + y0) / 2, z + 0.4, 0.4, y0 - ROOF.yBack + 0.2, 0.4, C(0x2a3140));
}

function addLights(lb, len) {
  const L2 = len / 2, y = ROOF.yFront - ROOF.thick - 0.7, z = ROOF.front - 0.4, s = LIGHT_SIZE / 2, warm = C(0xfff1d6);
  for (let x = -L2 + LIGHT_EVERY / 2; x < L2; x += LIGHT_EVERY) lb.wall(x + s, x - s, z, y - s, y + s, warm, [0, 0, 1, 1]);
}

// una tribuna completa: struttura, pubblico, luci (tre geometrie già nel sistema del mondo)
function buildStand(len, matrix, opts) {
  const sb = new QuadBuilder(), cb = new QuadBuilder(), lb = new QuadBuilder();
  addSteps(sb, len, opts.seats); addShell(sb, len, opts); addCrowd(cb, len); addLights(lb, len);
  if (opts.screen) addScreen(sb, len);
  return { struct: sb.geometry(matrix), crowd: cb.geometry(matrix), lights: lb.geometry(matrix) };
}

// ---------------------------------------------------------------- cartelloni e panchine
function addBoardLine(ab, sb, len, matrix, start) {
  const n = Math.floor(len / BOARD.panel), x0 = (n * BOARD.panel) / 2, rowH = 1 / AD_ROWS, a = new QuadBuilder(), s = new QuadBuilder();
  for (let i = 0; i < n; i++) {
    const xl = x0 - i * BOARD.panel, xr = xl - BOARD.panel, k = start + i, c = k % 4, r = ((k / 4) | 0) % AD_ROWS;
    a.wall(xl, xr, 0, 0.05, BOARD.h, C(0xffffff), [c / 4 + 0.002, 1 - (r + 1) * rowH + 0.004, (c + 1) / 4 - 0.002, 1 - r * rowH - 0.004]);
  }
  s.floor(-x0, x0, 0, 0.35, BOARD.h, C(0x1a1f29)); s.wall(x0, -x0, 0.35, 0, BOARD.h, C(0x11151d));
  s.quad([x0, 0, 0.35], [-x0, 0, 0.35], [-x0, BOARD.h, 0.35], [x0, BOARD.h, 0.35], C(0x11151d), WHITE_UV, [0, 0, 1]);
  ab.push(a.geometry(matrix)); sb.push(s.geometry(matrix));
}

function benchGeometry() {
  const b = new QuadBuilder();
  for (const z of [-8, 8]) {
    const x = BENCH_X, len = 6.5, d = 1.9, h = 2.1, back = x - d / 2;
    b.box(back, h / 2, z, 0.12, h, len, C(0x1b2a44));                         // parete di fondo
    b.box(x, h, z, d, 0.08, len, C(0x8fb4d4, 0.85), C(0x9cc3e2));            // tetto trasparente (finto)
    for (const e of [-1, 1]) b.box(x, h / 2, z + e * len / 2, d, h, 0.08, C(0x6f8fae, 0.8));
    b.box(back + 0.45, 0.45, z, 0.5, 0.12, len - 0.3, C(0x2a3550));          // seduta
    for (let i = 0; i < 6; i++) {                                            // panchinari seduti
      const pz = z - len / 2 + 0.7 + i * 1.0, kit = i % 3 === 0 ? 0x2d3a8c : 0x1f2633;
      b.box(back + 0.5, 0.85, pz, 0.32, 0.6, 0.42, C(kit));
      b.box(back + 0.5, 1.28, pz, 0.2, 0.22, 0.2, C(pick([0xf1c9a5, 0xc68f63, 0x8d5a3b])));
    }
  }
  return b.geometry();
}

// ---------------------------------------------------------------- cielo, terreno, materiali
function skyMesh() {
  const g = new THREE.SphereGeometry(330, 32, 12, 0, Math.PI * 2, 0, Math.PI * 0.555);
  const m = new THREE.MeshBasicMaterial({ map: skyTexture(), side: THREE.BackSide, depthWrite: false, fog: false });
  const mesh = new THREE.Mesh(g, m); mesh.renderOrder = -10; mesh.frustumCulled = false;
  return mesh;
}
function groundMesh() {
  const g = new THREE.PlaneGeometry(700, 700); g.rotateX(-Math.PI / 2);
  const mesh = new THREE.Mesh(g, new THREE.MeshLambertMaterial({ color: 0x24502b }));
  mesh.position.y = -0.05;
  return mesh;
}

// materiale del pubblico: salti e braccia alzate decisi nel fragment shader (per persona, con una funzione hash)
function crowdMaterial(map, uniforms) {
  const m = new THREE.MeshBasicMaterial({ map, vertexColors: true, alphaTest: 0.4 });
  m.onBeforeCompile = (sh) => {
    sh.uniforms.uTime = uniforms.uTime; sh.uniforms.uExcite = uniforms.uExcite;
    sh.fragmentShader = 'uniform float uTime;\nuniform float uExcite;\n' + sh.fragmentShader.replace('#include <map_fragment>', CROWD_FRAG);
  };
  m.customProgramCacheKey = () => 'tag-crowd';
  return m;
}
const CROWD_FRAG = /* glsl */`
#ifdef USE_MAP
  vec2 uv0 = vMapUv;
  float cell = floor(uv0.x * ${CELLS}.0);
  float rowId = floor(uv0.y * 4.0);
  float h = fract(sin(cell * 12.9898 + rowId * 78.233) * 43758.5453);
  float local = fract(uv0.y * 4.0);
  float up = step(h, uExcite * 0.95 - 0.08);
  float idle = (0.5 + 0.5 * sin(uTime * (1.2 + h) + h * 40.0)) * 0.012;
  float hop = uExcite * max(0.0, sin(uTime * (7.0 + 5.0 * h) + h * 60.0)) * 0.12 * step(0.2, h);
  local = clamp(local - idle - hop, 0.004, 0.996);
  vec2 suv = vec2(uv0.x, (rowId + local) * 0.25 - up * 0.5);
  vec4 sampledDiffuseColor = textureGrad(map, suv, dFdx(uv0), dFdy(uv0));
  diffuseColor *= sampledDiffuseColor;
#endif
`;

// ---------------------------------------------------------------- stadio
/**
 * Aggiunge lo stadio alla scena.
 * @param {THREE.Scene} scene
 * @param {{ home?: [string,string], away?: [string,string], sky?: boolean }} opts colori dei tifosi; sky:false lascia lo sfondo com'è
 * @returns {{ crowdMats: THREE.Material[], backStand: THREE.Object3D, root: THREE.Group, buildMs: number, update(dt:number, excitement?:number):void }}
 */
export function buildStadium(scene, opts = {}) {
  const t0 = performance.now();
  const home = opts.home || ['#d23b3b', '#f4f4f4'], away = opts.away || ['#2f6fd6', '#f2c230'];
  const root = new THREE.Group(); root.name = 'stadium';
  const uniforms = { uTime: { value: 0 }, uExcite: { value: 0 } };
  const atlas = structureTexture(), crowdTex = crowdTexture(home, away), adTex = adsTexture(), glowTex = glowTexture();
  const structMat = () => new THREE.MeshBasicMaterial({ map: atlas, vertexColors: true });
  const lightMat = () => new THREE.MeshBasicMaterial({ map: glowTex, vertexColors: true, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending });

  const sx = HW + SIDE_GAP, ez = HL + END_GAP, bz = HL + END_GAP + BACK_EXTRA;
  const sideLen = 2 * (bz + PROFILE.zb), endLen = 2 * sx;
  const lower = 0x2c64a8, upper = 0x9aa3b0;
  const stands = [
    buildStand(sideLen, placeMatrix(Math.PI / 2, sx, 0), { seats: [lower, upper], banners: true }),
    buildStand(sideLen, placeMatrix(-Math.PI / 2, -sx, 0), { seats: [lower, upper], banners: true }),
    buildStand(endLen, placeMatrix(Math.PI, 0, -ez), { seats: [0xb3263a, upper], banners: true, screen: true, wing: PROFILE.zb + 2 }),
  ];
  const back = buildStand(endLen, placeMatrix(0, 0, bz), { seats: [0xb3263a, upper], banners: false, wing: PROFILE.zb + 2 });

  // gruppo principale: 1 draw call per struttura, pubblico, luci, cartelloni
  const adGeos = [], boardGeos = [];
  addBoardLine(adGeos, boardGeos, 2 * BOARD.zMax, placeMatrix(Math.PI / 2, BOARD.side, 0), 0);
  addBoardLine(adGeos, boardGeos, 2 * BOARD.zMax, placeMatrix(-Math.PI / 2, -BOARD.side, 0), 7);
  addBoardLine(adGeos, boardGeos, 2 * BOARD.side, placeMatrix(Math.PI, 0, -BOARD.end), 13);
  const structGeo = mergeGeometries([...stands.map(s => s.struct), ...boardGeos, benchGeometry()]);
  const crowdMain = crowdMaterial(crowdTex, uniforms), crowdBack = crowdMaterial(crowdTex, uniforms);
  root.add(new THREE.Mesh(structGeo, structMat()));
  root.add(new THREE.Mesh(mergeGeometries(stands.map(s => s.crowd)), crowdMain));
  const lights = new THREE.Mesh(mergeGeometries(stands.map(s => s.lights)), lightMat()); lights.renderOrder = 5; root.add(lights);
  root.add(new THREE.Mesh(mergeGeometries(adGeos), new THREE.MeshBasicMaterial({ map: adTex, vertexColors: true })));

  // tribuna alle spalle della telecamera: oggetto unico con materiali propri (si può nascondere o dissolvere)
  const backStand = new THREE.Group(); backStand.name = 'backStand';
  backStand.add(new THREE.Mesh(back.struct, structMat()));
  backStand.add(new THREE.Mesh(back.crowd, crowdBack));
  const backLights = new THREE.Mesh(back.lights, lightMat()); backLights.renderOrder = 5; backStand.add(backLights);
  root.add(backStand);

  root.add(groundMesh());
  if (opts.sky !== false) { root.add(skyMesh()); scene.background = new THREE.Color(0x0b1028); }
  scene.add(root);

  let adT = 0;
  const update = (dt, excitement = 0) => {
    uniforms.uTime.value += dt;
    const e = Math.max(0, Math.min(1, excitement || 0));
    uniforms.uExcite.value += (e - uniforms.uExcite.value) * Math.min(1, dt * 3);
    adT += dt; const cyc = AD_HOLD + AD_SCROLL, step = Math.floor(adT / cyc), f = Math.min(1, (adT % cyc) / AD_SCROLL);
    adTex.offset.y = -((step + f * f * (3 - 2 * f)) % AD_ROWS) / AD_ROWS;
  };
  return { crowdMats: [crowdMain, crowdBack], backStand, root, update, buildMs: performance.now() - t0 };
}
