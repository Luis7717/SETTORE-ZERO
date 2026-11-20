// Stadio serale intorno al campo: tribune a due anelli con scalette, vomitori, corrimano e parapetti, pubblico
// animato (salti, braccia alzate, ola), bandiere che sventolano, tetto a sbalzo con travi, reticolare e anello di
// luci, cartelloni LED e fascia LED con sponsor inventati, maxischermo col risultato, steward, fotografi, panchine.
// Tutto in poche draw call: ogni gruppo è una sola geometria unita, le texture sono disegnate su canvas.
// Coordinate three: x = larghezza, y = altezza, z = -y del motore. La telecamera sta verso +z.
import * as THREE from 'three';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { HW, HL } from './sim.js';
import { canvasTex, rnd, pick, C, placeMatrix, fitText, fanColors, QuadBuilder, WHITE_UV } from './stadium-kit.js';
import { CELLS, TILE, CROWD_H, CROWD_VARIANTS, crowdTexture, crowdMaterial, flagTexture, flagMaterial, FlagBuilder } from './stadium-crowd.js';
import { adsTexture, adsMaterial, adsTicker, ledStrip } from './stadium-ads.js';
import { makeScreen, SCREEN_ASPECT } from './stadium-screen.js';

// ---------------------------------------------------------------- misure (metri)
const SIDE_GAP = 12;          // dalla linea laterale al muretto della tribuna laterale
const END_GAP = 13;           // dalla linea di porta al muretto della tribuna di fondo lontana
const BACK_EXTRA = 5;         // la tribuna alle spalle della telecamera è un po' più lontana
const FRONT_H = 1.6;          // muretto davanti al primo anello
const T1 = { rows: 14, rise: 0.42, run: 0.8 };   // primo anello
const VIP_H = 3.0;            // fascia delle tribune vip tra i due anelli (in alto la fascia LED)
const RIBBON = { y0: 1.0, y1: 0.1 };             // fascia LED: da VIP_H - 1.0 a VIP_H - 0.1 sopra il primo anello
const PARAPET_D = 1.0;        // passaggio davanti al secondo anello
const T2 = { rows: 16, rise: 0.5, run: 0.8 };    // secondo anello (più ripido)
const AISLE_EVERY = 12, AISLE_W = 1.2;           // settori e scalette
const VOM = { from: 5, to: 9, w: 2.4 };          // vomitori del primo anello: file 5..8, larghi 2.4 m
const RAIL_H = 0.95;                             // corrimano e parapetti
const ROOF = { front: 5, back: 27, yFront: 25, yBack: 23, thick: 0.9, beamEvery: 8, truss: 1.9 };
const BOARD = { h: 0.95, side: HW + 4, end: HL + 6, zMax: HL + 4 };
const BENCH_X = -(HW + 2.6);
const LIGHT_EVERY = 6, LIGHT_SIZE = 3.4;
const CROWD_SHADE = [0.6, 1.04];   // luminosità del pubblico in basso e in alto di ogni fila
const AWAY_GAP = 5;            // metri di posti vuoti accanto al settore ospiti
const OLA_EVERY = 38, OLA_LAPS = 1.6, OLA_SPEED = 0.55; // secondi di calma prima di un'ola, giri, radianti al secondo

const BANNERS = [['FORZA RAGAZZI', '#b3122b', '#fff'], ['CURVA DEL BORGO', '#0b3d91', '#ffd43b'], ['SEMPRE CON VOI', '#111', '#fff'],
  ['TIRO A GIRO', '#0f7a55', '#fff'], ['NOI CI CREDIAMO', '#ffd43b', '#111'], ['GLI AMICI DELLA STELLA', '#5b2a86', '#fff']];

// ---------------------------------------------------------------- atlante della struttura
const ATLAS = 1024;
const region = (x, y, w, h, pad = 2) => [(x + pad) / ATLAS, 1 - (y + h - pad) / ATLAS, (x + w - pad) / ATLAS, 1 - (y + pad) / ATLAS];
const R = { vip: region(0, 64, 512, 128), fascia: region(512, 64, 512, 64), truss: region(512, 128, 512, 96), sky: region(0, 576, 1024, 384) };
R.banners = BANNERS.map((_, i) => region((i % 2) * 512, 256 + ((i / 2) | 0) * 96, 512, 96));

function drawVip(g) {
  g.fillStyle = '#121722'; g.fillRect(0, 64, 512, 128);
  for (let i = 0; i < 8; i++) {
    const x = i * 64 + 4, gr = g.createLinearGradient(0, 74, 0, 182);
    gr.addColorStop(0, '#ffe2ae'); gr.addColorStop(1, '#b8743c'); g.fillStyle = gr; g.fillRect(x, 74, 56, 104);
    g.fillStyle = 'rgba(20,16,24,0.85)';
    for (let k = 0; k < 4; k++) { const hx = x + 6 + k * 13 + rnd(-2, 2); g.beginPath(); g.arc(hx, 150, 5, 0, 7); g.fill(); g.fillRect(hx - 6, 154, 12, 24); }
  }
  g.fillStyle = '#d7dde8'; g.fillRect(0, 64, 512, 5); g.fillRect(0, 186, 512, 6);
}
function drawFascia(g) {
  const gr = g.createLinearGradient(0, 64, 0, 128); gr.addColorStop(0, '#e9eef6'); gr.addColorStop(0.6, '#aab3c2'); gr.addColorStop(1, '#5d6676');
  g.fillStyle = gr; g.fillRect(512, 64, 512, 64);
  g.fillStyle = 'rgba(30,36,48,0.5)'; for (let x = 512; x < 1024; x += 64) g.fillRect(x, 64, 2, 64);
  g.fillStyle = '#2b3242'; g.fillRect(512, 120, 512, 8);
}
// reticolare d'acciaio sotto il bordo del tetto: correnti, montanti e diagonali su fondo scuro
function drawTruss(g) {
  const x0 = 512, y0 = 128, w = 512, h = 96;
  g.fillStyle = '#0d1119'; g.fillRect(x0, y0, w, h);
  g.strokeStyle = '#59627a'; g.lineWidth = 6; g.strokeRect(x0 + 3, y0 + 6, w - 6, h - 12);
  g.lineWidth = 4; g.strokeStyle = '#4a5368';
  for (let x = 0; x < w; x += 64) {
    g.beginPath(); g.moveTo(x0 + x, y0 + 6); g.lineTo(x0 + x, y0 + h - 6); g.stroke();
    g.beginPath(); g.moveTo(x0 + x, y0 + h - 6); g.lineTo(x0 + x + 32, y0 + 6); g.lineTo(x0 + x + 64, y0 + h - 6); g.stroke();
  }
}
function drawBanner(g, i) {
  const [text, bg, fg] = BANNERS[i], x = (i % 2) * 512, y = 256 + ((i / 2) | 0) * 96;
  g.fillStyle = bg; g.fillRect(x, y, 512, 96);
  g.fillStyle = fg; g.fillRect(x, y + 6, 512, 5); g.fillRect(x, y + 85, 512, 5);
  g.textAlign = 'center'; g.textBaseline = 'middle'; fitText(g, text, x + 256, y + 50, 470, 54);
}
function structureTexture() {
  return canvasTex(ATLAS, ATLAS, (g) => {
    g.fillStyle = '#fff'; g.fillRect(0, 0, 64, 64);
    drawVip(g); drawFascia(g); drawTruss(g); BANNERS.forEach((_, i) => drawBanner(g, i));
  });
}

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
  for (let i = 0; i < T1.rows; i++) t1.push({ z: i * T1.run, y: FRONT_H + i * T1.rise, rise: T1.rise, run: T1.run, light: 1 - 0.15 * i / T1.rows, tier: 0, i });
  const z1 = T1.rows * T1.run, y1 = FRONT_H + T1.rows * T1.rise, y2 = y1 + VIP_H, z2 = z1 + PARAPET_D;
  for (let i = 0; i < T2.rows; i++) t2.push({ z: z2 + i * T2.run, y: y2 + i * T2.rise, rise: T2.rise, run: T2.run, light: 0.8 - 0.28 * i / T2.rows, tier: 1, i });
  return { rows: [...t1, ...t2], t1, t2, z1, y1, y2, z2, zb: z2 + T2.rows * T2.run, yb: y2 + T2.rows * T2.rise };
}
const PROFILE = standProfile();

function sections(len) {
  const n = Math.max(1, Math.round(len / (AISLE_EVERY + AISLE_W))), sw = len / n, out = [];
  for (let k = 0; k < n; k++) { const xs = -len / 2 + k * sw; out.push([xs + AISLE_W / 2, xs + sw - AISLE_W / 2]); }
  return out;
}
const inVom = (r, opts) => opts.vom && r.tier === 0 && r.i >= VOM.from && r.i < VOM.to;
// tratti di una fila in un settore, saltando il vomitorio al centro
function rowSpans(r, s0, s1, opts) {
  if (!inVom(r, opts)) return [[s0, s1]];
  const c = (s0 + s1) / 2;
  return [[s0, c - VOM.w / 2], [c + VOM.w / 2, s1]];
}

function addSteps(sb, len, opts) {
  const secs = sections(len), concrete = 0x8a8f99;
  for (const r of PROFILE.rows) {
    const top = r.y + r.rise, k = r.light, seat = opts.seats[r.tier];
    for (const [a0, a1] of secs) for (const [s0, s1] of rowSpans(r, a0, a1, opts)) {
      sb.wall(s1, s0, r.z, r.y, top, C(seat, 0.62 * k));
      sb.floor(s0, s1, r.z, r.z + r.run, top, C(seat, 0.95 * k));
    }
    for (let i = 0; i <= secs.length; i++) { // scalette tra i settori
      const a = i === 0 ? -len / 2 : secs[i - 1][1], b = i === secs.length ? len / 2 : secs[i][0];
      sb.wall(b, a, r.z, r.y, top, C(concrete, 0.55 * k)); sb.floor(a, b, r.z, r.z + r.run, top, C(concrete, 0.85 * k));
    }
  }
  // corrimano al centro di ogni scaletta, dal basso all'alto di ogni anello
  const rail = C(0xc9ced6, 0.9);
  for (let i = 1; i < secs.length; i++) {
    const x = (secs[i - 1][1] + secs[i][0]) / 2;
    for (const tier of [PROFILE.t1, PROFILE.t2]) {
      const f = tier[0], l = tier[tier.length - 1];
      sb.bar([x, f.y + f.rise + RAIL_H, f.z + 0.2], [x, l.y + l.rise + RAIL_H, l.z + l.run * 0.5], 0.035, rail);
    }
  }
  if (opts.vom) for (const [s0, s1] of secs) addVomitory(sb, (s0 + s1) / 2);
}

// vomitorio: apertura nel primo anello con pavimento, pareti di cemento, fondo buio e corrimano attorno
function addVomitory(sb, c) {
  const rows = PROFILE.t1.slice(VOM.from, VOM.to), f = rows[0], l = rows[rows.length - 1];
  const x0 = c - VOM.w / 2, x1 = c + VOM.w / 2, fy = f.y, zf = f.z, zb = l.z + l.run, wallC = C(0x6d727c);
  sb.floor(x0, x1, zf, zb, fy, C(0x3a3f48));
  sb.wall(x1, x0, zb, fy, l.y + l.rise, [C(0x0a0b0e), C(0x0a0b0e), C(0x2a2219), C(0x2a2219)]);
  for (const r of rows) {
    sb.side(x0, r.z, r.z + r.run, fy, r.y + r.rise, C(wallC, r.light), 1);
    sb.side(x1, r.z, r.z + r.run, fy, r.y + r.rise, C(wallC, r.light * 0.8), -1);
  }
  const rail = C(0xd5dae2);
  sb.hbar(x0, x1, fy + RAIL_H, zf - 0.02, 0.06, rail);
  for (const x of [x0, x1]) sb.bar([x, f.y + f.rise + RAIL_H * 0.8, zf], [x, l.y + l.rise + RAIL_H * 0.8, zb], 0.03, rail);
}

function crowdVariant(r, sec, opts) {
  if (opts.away && r.tier === 1 && sec === opts.away.sec) return CROWD_VARIANTS.away;
  if (opts.curva && r.tier === 0) return CROWD_VARIANTS.curva;
  return CROWD_VARIANTS.home[(Math.random() * 2) | 0];
}
function addCrowd(cb, len, opts) {
  const secs = sections(len);
  for (const r of PROFILE.rows) {
    const z = r.z + r.run * 0.35, y0 = r.y + r.rise - 0.12, y1 = y0 + CROWD_H;
    secs.forEach(([s0, s1], sec) => {
      // settore ospiti: nel settore accanto restano liberi 5 m di posti (separazione)
      const gap = opts.away && r.tier === 1 && sec === opts.away.gap;
      const a0 = gap ? s0 + AWAY_GAP : s0, a1 = s1;
      const variant = crowdVariant(r, sec, opts), v0 = 1 - (variant + 1) / 8 + 0.002, v1 = 1 - variant / 8 - 0.002;
      const b = r.light * rnd(0.9, 1.04);
      // in basso più scuro (la fila davanti fa ombra), in alto più chiaro (i fari): il pubblico prende volume
      const lo = C(0xffffff, b * CROWD_SHADE[0]), hi = C(0xffffff, b * CROWD_SHADE[1]);
      for (const [s0, s1] of rowSpans(r, a0, a1, opts)) {
        const u0 = ((Math.random() * CELLS) | 0) / CELLS + ((Math.random() * 8) | 0);
        cb.wall(s1, s0, z, y0, y1, [lo, lo, hi, hi], [u0, v0, u0 + (s1 - s0) / TILE, v1]);
      }
    });
  }
}

function addShell(sb, len, opts) {
  const { z1, y1, y2, z2, zb, yb } = PROFILE, L2 = len / 2;
  // muretto con striscioni dei tifosi e corrimano sopra
  for (let x = L2; x > -L2; x -= 8) {
    const x1 = Math.max(-L2, x - 8), bi = opts.banners && Math.random() < 0.45 ? (Math.random() * BANNERS.length) | 0 : -1;
    sb.wall(x, x1, 0, 0, FRONT_H, C(0x1b2638));
    if (bi >= 0 && x - x1 > 7) sb.wall(x - 0.3, x1 + 0.3, -0.05, 0.15, FRONT_H - 0.1, C(0xffffff, 0.92), R.banners[bi]);
  }
  sb.floor(-L2, L2, -0.25, 0, FRONT_H, C(0xb8bec8));
  // fascia vip (la parte alta è la fascia LED, nella mesh dei cartelloni) e parapetto del secondo anello
  const vipTop = opts.ribbon ? y2 - RIBBON.y0 : y2;
  for (let x = L2; x > -L2; x -= 9) sb.wall(x, Math.max(-L2, x - 9), z1, y1, vipTop, C(0xffffff, 0.95), R.vip);
  if (opts.ribbon) sb.wall(L2, -L2, z1 + 0.01, vipTop, y2, C(0x0b0e14));
  sb.floor(-L2, L2, z1, z2, y2, C(0x9aa0aa, 0.8));
  sb.wall(L2, -L2, z1 - 0.02, y2 - RIBBON.y1, y2, C(0xdfe4ec));
  const rail = C(0xd5dae2);
  sb.hbar(-L2, L2, y2 + RAIL_H, z1 + 0.08, 0.07, rail);
  for (let x = -L2 + 1; x < L2; x += 2.5) sb.wall(x + 0.03, x - 0.03, z1 + 0.08, y2, y2 + RAIL_H, rail);
  // muro di fondo fino al tetto
  sb.wall(L2, -L2, zb, yb, ROOF.yBack, [C(0x161c28), C(0x161c28), C(0x0d1119), C(0x0d1119)]);
  // ali: nelle tribune di fondo muro e tetto continuano dietro gli angoli, così l'angolo dello stadio resta chiuso
  const RL = L2 + (opts.wing || 0);
  if (opts.wing) for (const sx of [-1, 1]) sb.wall(sx > 0 ? RL : -L2, sx > 0 ? L2 : -RL, zb, 0, ROOF.yBack, [C(0x2a3346), C(0x2a3346), C(0x1a2030), C(0x1a2030)]);
  addRoof(sb, L2, RL, opts);
  addEndFaces(sb, L2);
}

// tetto a sbalzo: sotto scuro (più chiaro verso il bordo illuminato), sopra grigio, bordo frontale chiaro,
// reticolare d'acciaio sotto il bordo (le luci ci stanno davanti), travi a sbalzo ogni ROOF.beamEvery metri
function addRoof(sb, L2, RL, opts) {
  const yb0 = ROOF.yBack - ROOF.thick, yf0 = ROOF.yFront - ROOF.thick;
  sb.quad([RL, yf0, ROOF.front], [-RL, yf0, ROOF.front], [-RL, yb0, ROOF.back], [RL, yb0, ROOF.back],
    [C(0x3a4254), C(0x3a4254), C(0x10141d), C(0x10141d)], WHITE_UV, [0, -1, 0]);
  sb.quad([-RL, ROOF.yFront, ROOF.front], [RL, ROOF.yFront, ROOF.front], [RL, ROOF.yBack, ROOF.back], [-RL, ROOF.yBack, ROOF.back], C(0x4d5566), WHITE_UV, [0, 1, 0]);
  const FL = opts.wing ? L2 + ROOF.front + 1 : L2;
  for (let x = FL; x > -FL; x -= 8) {
    const x1 = Math.max(-FL, x - 8);
    sb.wall(x, x1, ROOF.front, yf0 - 0.3, ROOF.yFront + 0.1, C(0xffffff), R.fascia);
    sb.wall(x, x1, ROOF.front + 0.25, yf0 - 0.3 - ROOF.truss, yf0 - 0.3, C(0xffffff), R.truss);
  }
  const beam = C(0x2a3242), zm = (ROOF.front + ROOF.back) / 2;
  for (let x = -L2 + 2; x < L2; x += ROOF.beamEvery) {
    sb.box(x, (yb0 + yf0) / 2 - 0.55, zm, 0.35, 1.1, ROOF.back - ROOF.front, beam);
    // tirante dal fondo della tribuna alla trave
    sb.bar([x, PROFILE.yb, PROFILE.zb - 0.2], [x, (yb0 + yf0) / 2 - 1.0, zm], 0.12, C(0x1d2330));
  }
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

// maxischermo: cornice e sostegni nella struttura, schermo (texture viva) in una geometria a parte
function screenGeo(sb) {
  const y0 = ROOF.yBack + 0.6, h = 7, w = h * SCREEN_ASPECT, z = ROOF.back - 3;
  sb.box(0, y0 + h / 2, z + 0.4, w + 1, h + 1, 0.6, C(0x111520));
  for (const sx of [-1, 1]) sb.box(sx * w * 0.35, (ROOF.yBack + y0) / 2, z + 0.4, 0.4, y0 - ROOF.yBack + 0.2, 0.4, C(0x2a3140));
  const q = new QuadBuilder(); q.quad([w / 2, y0, z], [-w / 2, y0, z], [-w / 2, y0 + h, z], [w / 2, y0 + h, z], C(0xffffff), [0, 0, 1, 1], [0, 0, -1]);
  return q;
}

function addLights(lb, len) {
  const L2 = len / 2, y = ROOF.yFront - ROOF.thick - 0.9, z = ROOF.front - 0.4, s = LIGHT_SIZE / 2, warm = C(0xfff1d6);
  for (let x = -L2 + LIGHT_EVERY / 2; x < L2; x += LIGHT_EVERY) lb.wall(x + s, x - s, z, y - s, y + s, warm, [0, 0, 1, 1]);
}

// steward seduti davanti al muretto, rivolti verso il pubblico (giubbotto ad alta visibilità)
function addStewards(sb, len) {
  for (let x = -len / 2 + 7; x < len / 2 - 4; x += 14 + rnd(-2, 2)) {
    const z = -2.2, vest = C(pick([0xf2c230, 0xff8a1f]));
    sb.box(x, 0.45, z, 0.45, 0.06, 0.45, C(0x22262e));
    sb.box(x, 0.85, z, 0.42, 0.62, 0.28, vest);
    sb.box(x, 1.28, z, 0.2, 0.22, 0.2, C(pick([0xf1c9a5, 0xc68f63, 0x8d5a3b])));
    sb.box(x, 0.25, z - 0.12, 0.36, 0.5, 0.22, C(0x1b1e26));
  }
}

// una tribuna completa: struttura, pubblico, luci, fascia LED (geometrie già nel sistema del mondo) e bandiere
function buildStand(len, matrix, opts, fb) {
  const sb = new QuadBuilder(), cb = new QuadBuilder(), lb = new QuadBuilder(), ab = new QuadBuilder();
  addSteps(sb, len, opts); addShell(sb, len, opts); addCrowd(cb, len, opts); addLights(lb, len); addStewards(sb, len);
  if (opts.ribbon) ledStrip(ab, len / 2, -len / 2, PROFILE.z1 - 0.03, PROFILE.y2 - RIBBON.y0, PROFILE.y2 - RIBBON.y1, opts.ribbonStart || 0);
  const screen = opts.screen ? screenGeo(sb) : null;
  const out = { struct: sb.geometry(matrix), crowd: cb.geometry(matrix), lights: lb.geometry(matrix),
    ads: ab.pos.length ? ab.geometry(matrix) : null, screen: screen && screen.geometry(matrix) };
  if (fb) addFlags(fb, len, matrix, opts);
  return out;
}

// bandiere: a mano tra il pubblico (più fitte in curva) e grandi sul bordo del tetto, mosse dal vento
function addFlags(fb, len, matrix, opts) {
  const P = new THREE.Vector3(), rot = new THREE.Matrix3().setFromMatrix4(matrix);
  const w = (x, y, z) => P.set(x, y, z).applyMatrix4(matrix).toArray();
  const d = (x, y, z) => P.set(x, y, z).applyMatrix3(rot).normalize().toArray();
  const toField = d(0, 0, -1), secs = sections(len);
  const nHand = opts.curva ? 32 : 11;
  for (let i = 0; i < nHand; i++) {
    const tierRows = opts.curva && i < 22 ? PROFILE.t1 : PROFILE.rows, r = pick(tierRows.slice(1));
    const [s0, s1] = pick(secs), x = rnd(s0 + 1.5, s1 - 1.5);
    if (inVom(r, opts) && Math.abs(x - (s0 + s1) / 2) < VOM.w) continue;
    const away = opts.away && r.tier === 1 && secs[opts.away.sec][0] <= x && x <= secs[opts.away.sec][1];
    const design = away ? 12 + ((Math.random() * 4) | 0) : (Math.random() * 12) | 0;
    const big = Math.random() < (opts.curva ? 0.4 : 0.25);
    fb.flag(w(x, r.y + r.rise + 1.1, r.z + r.run * 0.35), toField, d(Math.random() < 0.5 ? 1 : -1, 0, 0),
      big ? 2.2 : 1.5, big ? 2.2 : 1.4, big ? 1.4 : 0.9, design, rnd(0.35, 0.6), rnd(0, 100));
  }
  // bandiere sul tetto (tutte sventolano dalla stessa parte: c'è vento)
  const wind = d(1, 0, 0), n = Math.max(2, Math.round(len / 26));
  for (let k = 0; k < n; k++) {
    let x = -len / 2 + (k + 0.5) * len / n;
    if (opts.screen && Math.abs(x) < 16) x = (x < 0 ? -1 : 1) * 16 || 16; // non davanti al maxischermo
    fb.flag(w(x, ROOF.yFront, ROOF.front + 1.2), toField, wind, 4.2, 3.0, 1.9, k % 2 ? 0 : 2, 0, k * 1.7);
  }
}

// ---------------------------------------------------------------- cartelloni, panchine, fotografi
function addBoardLine(ab, sb, len, matrix, startM) {
  const x0 = len / 2, a = new QuadBuilder(), s = new QuadBuilder();
  ledStrip(a, x0, -x0, 0, 0.05, BOARD.h, startM);
  s.floor(-x0, x0, 0, 0.35, BOARD.h, C(0x1a1f29)); s.wall(x0, -x0, 0.35, 0, BOARD.h, C(0x11151d));
  s.quad([x0, 0, 0.35], [-x0, 0, 0.35], [-x0, BOARD.h, 0.35], [x0, BOARD.h, 0.35], C(0x11151d), WHITE_UV, [0, 0, 1]);
  s.wall(x0, -x0, -0.01, 0, 0.05, C(0x05070a));
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
  // fotografi accovacciati dietro la linea di fondo lontana, ai lati della porta
  for (const sx of [-1, 1]) for (let k = 0; k < 4; k++) {
    const x = sx * (8 + k * 3.2 + rnd(-0.5, 0.5)), z = -(HL + 3.2 + rnd(-0.3, 0.3));
    b.box(x, 0.45, z, 0.5, 0.7, 0.45, C(pick([0x2a2f3a, 0x3b4252, 0x1e2a44])));
    b.box(x, 0.95, z + 0.05, 0.22, 0.24, 0.22, C(pick([0xf1c9a5, 0xc68f63, 0x8d5a3b])));
    b.box(x, 0.85, z + 0.3, 0.18, 0.16, 0.36, C(0x111111));
  }
  return b.geometry();
}

// ---------------------------------------------------------------- cielo, terreno
function skyMesh() {
  const g = new THREE.SphereGeometry(330, 32, 12, 0, Math.PI * 2, 0, Math.PI * 0.555);
  const m = new THREE.MeshBasicMaterial({ map: skyTexture(), side: THREE.BackSide, depthWrite: false, fog: false });
  const mesh = new THREE.Mesh(g, m); mesh.renderOrder = -10; mesh.frustumCulled = false;
  return mesh;
}
// terreno attorno al campo: quattro rettangoli attorno a un buco sotto il prato (il prato lo copre già:
// niente pixel disegnati due volte)
const GROUND = { holeX: HW + 8, holeZ: HL + 10, size: 350 };
function groundMesh() {
  const q = new QuadBuilder(), { holeX: x, holeZ: z, size: S } = GROUND, col = C(0xffffff);
  for (const [x0, x1, z0, z1] of [[-S, S, -S, -z], [-S, S, z, S], [-S, -x, -z, z], [x, S, -z, z]]) q.floor(x0, x1, z0, z1, -0.05, col);
  const g = q.geometry(); g.deleteAttribute('color'); g.computeVertexNormals();
  return new THREE.Mesh(g, new THREE.MeshLambertMaterial({ color: 0x24502b }));
}

// settore ospiti: nell'anello alto della tribuna laterale sinistra, il settore più vicino alla porta lontana
function awaySector(len) {
  const secs = sections(len), target = -(HL + 2);
  let best = 0; secs.forEach(([a, b], i) => { if (Math.abs((a + b) / 2 - target) < Math.abs((secs[best][0] + secs[best][1]) / 2 - target)) best = i; });
  return { sec: best, gap: best + 1 };
}

// ---------------------------------------------------------------- stadio
/**
 * Aggiunge lo stadio alla scena.
 * @param {THREE.Scene} scene
 * @param {{ home?: {shirt:number, shorts?:number}, away?: {shirt:number, shorts?:number}, sky?: boolean }} opts
 *   divise delle due squadre (colori dei tifosi); sky:false lascia lo sfondo com'è
 * @returns {{ crowdMats: THREE.Material[], backStand: THREE.Object3D, root: THREE.Group, buildMs: number,
 *   update(dt:number, excitement?:number, match?:object):void, setTeams(home:object, away:object):void }}
 */
export function buildStadium(scene, opts = {}) {
  const t0 = performance.now();
  let home = opts.home ? fanColors(opts.home) : ['#d23b3b', '#f4f4f4'], away = opts.away ? fanColors(opts.away) : ['#2f6fd6', '#f2c230'];
  const root = new THREE.Group(); root.name = 'stadium';
  const uniforms = { uTime: { value: 0 }, uExcite: { value: 0 }, uOla: { value: 0 }, uOlaAmp: { value: 0 },
    uAdA: { value: 0 }, uAdB: { value: 0 }, uAdFlip: { value: 0 }, uAdMosA: { value: 0 }, uAdMosB: { value: 0 } };
  const atlas = structureTexture(), crowdTex = crowdTexture(home, away), adTex = adsTexture(), glowTex = glowTexture(), flagTex = flagTexture(home, away);
  const structMat = () => new THREE.MeshBasicMaterial({ map: atlas, vertexColors: true });
  const lightMat = () => new THREE.MeshBasicMaterial({ map: glowTex, vertexColors: true, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending });

  const sx = HW + SIDE_GAP, ez = HL + END_GAP, bz = HL + END_GAP + BACK_EXTRA;
  const sideLen = 2 * (bz + PROFILE.zb), endLen = 2 * sx;
  const lower = 0x2c64a8, upper = 0x9aa3b0, fb = new FlagBuilder();
  const stands = [
    buildStand(sideLen, placeMatrix(Math.PI / 2, sx, 0), { seats: [lower, upper], banners: true, vom: true, ribbon: true }, fb),
    buildStand(sideLen, placeMatrix(-Math.PI / 2, -sx, 0), { seats: [lower, upper], banners: true, vom: true, ribbon: true, ribbonStart: 40, away: awaySector(sideLen) }, fb),
    buildStand(endLen, placeMatrix(Math.PI, 0, -ez), { seats: [0xb3263a, upper], banners: true, screen: true, curva: true, vom: true, ribbon: true, ribbonStart: 20, wing: PROFILE.zb + 2 }, fb),
  ];
  const back = buildStand(endLen, placeMatrix(0, 0, bz), { seats: [0xb3263a, upper], banners: false, vom: true, wing: PROFILE.zb + 2 }, null);

  // gruppo principale: 1 draw call ciascuno per struttura, pubblico, luci, cartelloni+fascia LED, bandiere, maxischermo
  const adGeos = stands.map(s => s.ads).filter(Boolean), boardGeos = [];
  addBoardLine(adGeos, boardGeos, 2 * BOARD.zMax, placeMatrix(Math.PI / 2, BOARD.side, 0), 0);
  addBoardLine(adGeos, boardGeos, 2 * BOARD.zMax, placeMatrix(-Math.PI / 2, -BOARD.side, 0), 31);
  addBoardLine(adGeos, boardGeos, 2 * BOARD.side, placeMatrix(Math.PI, 0, -BOARD.end), 57);
  const structGeo = mergeGeometries([...stands.map(s => s.struct), ...boardGeos, benchGeometry()]);
  const crowdMain = crowdMaterial(crowdTex, uniforms), crowdBack = crowdMaterial(crowdTex, uniforms);
  root.add(new THREE.Mesh(structGeo, structMat()));
  // il pubblico si disegna prima della struttura: i gradini nascosti dalle persone non vengono colorati
  const crowdMesh = new THREE.Mesh(mergeGeometries(stands.map(s => s.crowd)), crowdMain); crowdMesh.renderOrder = -1; root.add(crowdMesh);
  const lights = new THREE.Mesh(mergeGeometries(stands.map(s => s.lights)), lightMat()); lights.renderOrder = 5; root.add(lights);
  root.add(new THREE.Mesh(mergeGeometries(adGeos), adsMaterial(adTex, uniforms)));
  const flags = new THREE.Mesh(fb.geometry(), flagMaterial(flagTex, uniforms)); flags.frustumCulled = false; root.add(flags);
  const screen = makeScreen(); root.add(new THREE.Mesh(stands[2].screen, screen.material));

  // tribuna alle spalle della telecamera: oggetto unico con materiali propri (si può nascondere o dissolvere)
  const backStand = new THREE.Group(); backStand.name = 'backStand';
  backStand.add(new THREE.Mesh(back.struct, structMat()));
  const backCrowd = new THREE.Mesh(back.crowd, crowdBack); backCrowd.renderOrder = -1; backStand.add(backCrowd);
  const backLights = new THREE.Mesh(back.lights, lightMat()); backLights.renderOrder = 5; backStand.add(backLights);
  root.add(backStand);

  root.add(groundMesh());
  if (opts.sky !== false) { root.add(skyMesh()); scene.background = new THREE.Color(0x0b1028); }
  scene.add(root);

  const tickAds = adsTicker(uniforms);
  let calm = 0, ola = -1, goalT = 0;
  const update = (dt, excitement = 0, match = null) => {
    uniforms.uTime.value += dt;
    const e = Math.max(0, Math.min(1, excitement || 0));
    uniforms.uExcite.value += (e - uniforms.uExcite.value) * Math.min(1, dt * 3);
    tickAds(dt);
    // ola: dopo un po' di calma parte un'onda che fa il giro dello stadio
    calm = e < 0.15 ? calm + dt : 0;
    if (ola < 0 && calm > OLA_EVERY) { ola = 0; calm = 0; }
    if (ola >= 0) {
      ola += dt * OLA_SPEED; uniforms.uOla.value = ola - Math.PI;
      uniforms.uOlaAmp.value = Math.min(1, ola * 2, (OLA_LAPS * 2 * Math.PI - ola) * 2);
      if (ola > OLA_LAPS * 2 * Math.PI || e > 0.5) { ola = -1; uniforms.uOlaAmp.value = 0; }
    }
    if (match) {
      goalT = match.phase === 'goal' ? goalT + dt : 0;
      screen.set({ score: [match.score[0], match.score[1]], goal: goalT > 0 && goalT < 4 });
    }
  };
  const setTeams = (homeKit, awayKit, names) => {
    if (!homeKit || !awayKit) return;
    const h = fanColors(homeKit), a = fanColors(awayKit);
    if (names) screen.set({ names: names.map(n => String(n || '').slice(0, 4).toUpperCase()) });
    screen.set({ colors: [h, a] });
    if (h.join() === home.join() && a.join() === away.join()) return;
    home = h; away = a; crowdTex.redraw(h, a); flagTex.redraw(h, a);
  };
  return { crowdMats: [crowdMain, crowdBack], backStand, root, update, setTeams, buildMs: performance.now() - t0 };
}
