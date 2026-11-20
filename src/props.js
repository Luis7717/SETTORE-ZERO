// Oggetti di scena ed effetti: pallone, porte con rete che si gonfia, bandierine d'angolo, scia del pallone,
// sbuffo d'erba sul calcio forte, coriandoli dopo il gol, nastri delle linee disegnate.
// Solo grafica: legge lo stato della partita, non lo cambia. Coordinate three: X = x, Y = altezza, Z = -y.
import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { HW, HL, GW, GH } from './sim.js';

const BALL_R = 0.21;          // raggio del pallone a schermo (più grande del vero, per leggerlo da lontano)
const POST_R = 0.065;         // raggio di pali e traversa (m)
const NET_D1 = 1.0;           // profondità del tetto della rete (m)
const NET_DROP = 0.12;        // il tetto scende un poco verso il fondo (m)
const NET_D = 2.25;           // profondità della rete a terra (m)
const NET_CELL = 0.19;        // lato di una maglia della rete (m)
const NET_K = 170, NET_C = 7; // molla della rete: rigidezza e smorzamento (oscilla ~2 volte al secondo)
const NET_KICK = 0.14;        // spinta del pallone che arriva in fondo alla rete (per m/s di velocità)
const NET_PUSH_R = 0.6;       // raggio della zona di rete spinta dal pallone (m)
const NET_FAR = 0.78, NET_NEAR = 0.22; // trasparenza della rete: porta di fronte / porta alle spalle
const FLAG_H = 1.5;           // altezza dell'asta della bandierina (m)
const TRAIL_N = 26, TRAIL_LIFE = 0.24, TRAIL_V = 17; // scia: punti, durata (s), velocità minima del pallone (m/s)
const PUFF_N = 60, PUFF_V = 15;  // sbuffo d'erba: particelle in tutto, velocità minima del calcio (m/s)
const CONF_N = 170, CONF_T = 4.2; // coriandoli: quanti e per quanto (s)

function canvasTex(w, h, draw, aniso = 4) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = aniso;
  return t;
}

// ---------------------------------------------------------------- pallone
// Disegno originale a 32 pannelli (12 pentagoni blu notte bordati d'arancio, 20 esagoni bianchi un po' bombati),
// calcolato punto per punto sulla sfera e scritto nella texture equirettangolare usata da SphereGeometry.
export function ballTexture() {
  const W = 512, H = 256, f = (1 + Math.sqrt(5)) / 2, C = [];
  const add = (x, y, z, pent) => { const l = Math.hypot(x, y, z); C.push([x / l, y / l, z / l, pent]); };
  for (const a of [1, -1]) for (const b of [f, -f]) { add(0, a, b, 1); add(a, b, 0, 1); add(b, 0, a, 1); }
  for (const a of [1, -1]) for (const b of [1, -1]) for (const c of [1, -1]) add(a, b, c, 0);
  for (const a of [1 / f, -1 / f]) for (const b of [f, -f]) { add(0, a, b, 0); add(a, b, 0, 0); add(b, 0, a, 0); }
  const c = document.createElement('canvas'); c.width = W; c.height = H;
  const g = c.getContext('2d'), img = g.createImageData(W, H), d = img.data;
  const sm = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
  for (let r = 0; r < H; r++) {
    const th = (r + 0.5) / H * Math.PI, st = Math.sin(th), y = Math.cos(th);
    for (let q = 0; q < W; q++) {
      const ph = (q + 0.5) / W * Math.PI * 2, x = -Math.cos(ph) * st, z = Math.sin(ph) * st;
      let d1 = -2, d2 = -2, i1 = 0;
      for (let i = 0; i < 32; i++) { const k = C[i], v = k[0] * x + k[1] * y + k[2] * z; if (v > d1) { d2 = d1; d1 = v; i1 = i; } else if (v > d2) d2 = v; }
      const e = d1 - d2; // 0 sulla cucitura tra due pannelli
      let R, G, B;
      if (C[i1][3]) {
        const o = sm(0.022, 0.034, e); // bordo arancio dentro il pentagono
        R = 236 + (24 - 236) * o; G = 112 + (36 - 112) * o; B = 30 + (72 - 30) * o;
      } else {
        const sh = 1 - 0.13 * (1 - sm(0, 0.09, e)); // esagono bombato: più scuro verso le cuciture
        R = 246 * sh; G = 246 * sh; B = 240 * sh;
      }
      const s = sm(0.003, 0.009, e); // cucitura
      R = 70 + (R - 70) * s; G = 72 + (G - 72) * s; B = 78 + (B - 78) * s;
      const o = (r * W + q) * 4; d[o] = R; d[o + 1] = G; d[o + 2] = B; d[o + 3] = 255;
    }
  }
  g.putImageData(img, 0, 0);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8;
  return t;
}

// ombra del pallone: macchia morbida e quattro ombre lunghe tenui verso gli angoli (i quattro fari), come i giocatori
function ballShadowTexture() {
  return canvasTex(128, 128, (g) => {
    for (let k = 0; k < 4; k++) {
      g.save(); g.translate(64, 64); g.rotate(Math.PI / 4 + k * Math.PI / 2); g.translate(26, 0); g.scale(1, 0.32);
      const gr = g.createRadialGradient(0, 0, 0, 0, 0, 28); gr.addColorStop(0, 'rgba(0,0,0,0.22)'); gr.addColorStop(1, 'rgba(0,0,0,0)');
      g.fillStyle = gr; g.fillRect(-28, -28, 56, 56); g.restore();
    }
    const gr = g.createRadialGradient(64, 64, 0, 64, 64, 20); gr.addColorStop(0, 'rgba(0,0,0,0.75)'); gr.addColorStop(0.5, 'rgba(0,0,0,0.45)'); gr.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = gr; g.fillRect(0, 0, 128, 128);
  });
}

// ---------------------------------------------------------------- nastri (linee disegnate)
// Texture di traverso al nastro: bordo scuro morbido, anima chiara (il colore del materiale tinge l'anima).
let ribbonTex = null;
function getRibbonTex() {
  if (ribbonTex) return ribbonTex;
  ribbonTex = canvasTex(64, 4, (g, w, h) => {
    const gr = g.createLinearGradient(0, 0, w, 0);
    const stops = [[0, 'rgba(0,0,0,0)'], [0.06, 'rgba(0,0,0,0.3)'], [0.15, 'rgba(15,20,25,0.55)'], [0.2, 'rgba(255,255,255,1)'], [0.5, 'rgba(255,255,255,1)']];
    for (const [o, c] of stops) { gr.addColorStop(o, c); gr.addColorStop(1 - o, c); }
    g.fillStyle = gr; g.fillRect(0, 0, w, h);
  }, 1);
  return ribbonTex;
}

// nastro piatto con freccia finale: `max` punti più 2 per la punta
export function makeRibbon(max, color, opacity, order) {
  const n = max + 2, g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(n * 2 * 3), 3));
  const uv = new Float32Array(n * 4); for (let i = 0; i < n; i++) { uv[i * 4] = 0; uv[i * 4 + 2] = 1; uv[i * 4 + 1] = uv[i * 4 + 3] = 0.5; }
  g.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
  const idx = []; for (let i = 0; i < n - 1; i++) { const a = i * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
  g.setIndex(idx); g.setDrawRange(0, 0);
  const m = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ map: getRibbonTex(), color, transparent: true, opacity, depthTest: false, depthWrite: false, side: THREE.DoubleSide }));
  m.renderOrder = order; m.frustumCulled = false; m.userData.max = max;
  return m;
}

// riempie il nastro: get(i) → [x, y, h] in coordinate di gioco; wd(i, n) = mezza larghezza (m);
// arrow = lunghezza della punta (0 = senza punta). Ritorna il numero di punti usati.
const _a = [0, 0, 0];
export function fillRibbon(mesh, count, get, wd, flip, arrow = 0) {
  const pos = mesh.geometry.attributes.position.array, n = Math.min(count, mesh.userData.max), s = flip;
  if (n < 2) { mesh.geometry.setDrawRange(0, 0); mesh.visible = false; return 0; }
  let px = 0, py = 0, tx = 0, ty = 1;
  const put = (k, x, y, h, nx, ny) => {
    pos[k * 6] = s * (x + nx); pos[k * 6 + 1] = h; pos[k * 6 + 2] = -s * (y + ny);
    pos[k * 6 + 3] = s * (x - nx); pos[k * 6 + 4] = h; pos[k * 6 + 5] = -s * (y - ny);
  };
  let hh = 0;
  for (let i = 0; i < n; i++) {
    const a = get(Math.max(0, i - 1)), ax = a[0], ay = a[1];
    const c = get(Math.min(n - 1, i + 1)), cx = c[0], cy = c[1];
    const p = get(i);
    let dx = cx - ax, dy = cy - ay; const l = Math.hypot(dx, dy);
    if (l > 1e-6) { tx = dx / l; ty = dy / l; }
    const w = wd(i, n); px = p[0]; py = p[1]; hh = p[2];
    put(i, px, py, hh, -ty * w, tx * w);
  }
  let k = n;
  if (arrow > 0) {
    const w = wd(n - 1, n) * 2.5;
    put(k++, px, py, hh, -ty * w, tx * w);                          // base della punta (giunto di area zero)
    put(k++, px + tx * arrow, py + ty * arrow, hh, 0, 0);           // punta
  }
  mesh.geometry.attributes.position.needsUpdate = true;
  mesh.geometry.setDrawRange(0, (k - 1) * 6); mesh.visible = true;
  return k;
}

// ---------------------------------------------------------------- porte
function netTexture() {
  // maglie a rombo (tessuto annodato): fili chiari con un leggero alone, nodi un po' più spessi
  const t = canvasTex(64, 64, (g, w, h) => {
    g.clearRect(0, 0, w, h); g.lineCap = 'round';
    const lines = (lw, col) => { g.strokeStyle = col; g.lineWidth = lw; g.beginPath(); g.moveTo(0, 0); g.lineTo(w, h); g.moveTo(w, 0); g.lineTo(0, h); g.moveTo(-w / 2, h / 2); g.lineTo(w / 2, -h / 2); g.moveTo(w / 2, h * 1.5); g.lineTo(w * 1.5, h / 2); g.moveTo(w / 2, -h / 2); g.lineTo(w * 1.5, h / 2); g.moveTo(-w / 2, h / 2); g.lineTo(w / 2, h * 1.5); g.stroke(); };
    lines(9, 'rgba(255,255,255,0.3)'); lines(4.5, 'rgba(255,255,255,1)');
    g.fillStyle = '#fff'; for (const [x, y] of [[0, 0], [w, 0], [0, h], [w, h], [w / 2, h / 2]]) { g.beginPath(); g.arc(x, y, 2.6, 0, 7); g.fill(); }
  }, 4);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  return t;
}

// profilo laterale della rete (z dietro la linea, y altezza): tetto fino a NET_D1, poi giù fino a NET_D a terra
const roofY = z => GH - NET_DROP * (z / NET_D1);
const backZ = y => NET_D - (NET_D - NET_D1) * (y / (GH - NET_DROP)); // z del fondo a quota y

// rete di una porta: tetto, fondo, due fianchi in una sola geometria; per ogni vertice la normale verso fuori
// e il peso (0 sui bordi fissati al telaio, 1 in mezzo al telo) per abbassamento, gonfiaggio e tremolio
function buildNet() {
  const P = [], N = [], UV = [], Wt = [], I = [];
  // loose = il bordo in basso è fissato solo a picchetti: cede un poco anche lì
  const grid = (nu, nv, at, nrm, loose) => {
    const o = P.length / 3;
    for (let j = 0; j <= nv; j++) for (let i = 0; i <= nu; i++) {
      const u = i / nu, v = j / nv, [x, y, z, uu, vv] = at(u, v);
      P.push(x, y, z); N.push(...nrm); UV.push(uu / NET_CELL, vv / NET_CELL); const sv = Math.sin(Math.PI * v); Wt.push(Math.pow(Math.sin(Math.PI * u), 0.6) * (loose && v > 0.5 ? 0.4 + 0.6 * sv : sv));
    }
    for (let j = 0; j < nv; j++) for (let i = 0; i < nu; i++) { const a = o + j * (nu + 1) + i, b = a + 1, c = a + nu + 1, d = c + 1; I.push(a, c, b, b, c, d); }
  };
  const hw = GW / 2, bh = GH - NET_DROP, bl = Math.hypot(NET_D - NET_D1, bh);
  grid(24, 6, (u, v) => { const z = v * NET_D1; return [-hw + u * GW, roofY(z), z, u * GW, v * NET_D1]; }, [0, 1, 0]);                  // tetto
  grid(24, 12, (u, v) => { const y = bh * (1 - v); return [-hw + u * GW, y, backZ(y), u * GW, v * bl]; }, [0, bh / bl, (NET_D - NET_D1) / bl], true); // fondo
  for (const sx of [-1, 1]) grid(10, 12, (u, v) => { const y = v * GH, zm = y > bh ? NET_D1 * (GH - y) / NET_DROP : backZ(y); return [sx * hw, y, u * zm, u * zm, y]; }, [sx, 0, 0]); // fianchi
  const g = new THREE.BufferGeometry();
  const pos = new Float32Array(P);
  // telo un po' cedevole: il tetto si abbassa al centro, il fondo e i fianchi si gonfiano appena verso fuori
  for (let i = 0; i < Wt.length; i++) { const w = Wt[i], ny = N[i * 3 + 1], sag = ny > 0.9 ? -0.07 : 0.045; pos[i * 3] += N[i * 3] * sag * w; pos[i * 3 + 1] += (ny > 0.9 ? sag : N[i * 3 + 1] * sag) * w; pos[i * 3 + 2] += N[i * 3 + 2] * sag * w; }
  g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  g.setAttribute('normal', new THREE.BufferAttribute(new Float32Array(N), 3));
  g.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(UV), 2));
  g.setIndex(I);
  g.boundingSphere = new THREE.Sphere(new THREE.Vector3(0, GH / 2, NET_D / 2), GW / 2 + 1.6);
  return { g, base: pos.slice(), nrm: new Float32Array(N), wt: new Float32Array(Wt) };
}

// telaio: pali e traversa tondi con giunti, sostegni grigi dietro (aste del tetto, aste inclinate, tubi a terra)
function buildFrame() {
  const parts = [], white = new THREE.Color(0xf4f5f2), grey = new THREE.Color(0x8a8f96);
  const tube = (a, b, r, col, seg = 16) => {
    const va = new THREE.Vector3(...a), vb = new THREE.Vector3(...b), d = vb.clone().sub(va), l = d.length();
    const g = new THREE.CylinderGeometry(r, r, l, seg, 1, true);
    g.applyQuaternion(new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), d.normalize()));
    g.translate((va.x + vb.x) / 2, (va.y + vb.y) / 2, (va.z + vb.z) / 2); parts.push([g, col]);
  };
  const ball = (p, r, col) => { const g = new THREE.SphereGeometry(r, 16, 10); g.translate(...p); parts.push([g, col]); };
  const hw = GW / 2, bh = GH - NET_DROP;
  for (const sx of [-1, 1]) {
    tube([sx * hw, 0, 0], [sx * hw, GH, 0], POST_R, white);
    ball([sx * hw, GH, 0], POST_R, white);                                    // giunto palo-traversa arrotondato
    tube([sx * hw, GH - 0.05, 0.02], [sx * hw, bh, NET_D1], 0.024, grey, 8);   // asta del tetto
    tube([sx * hw, bh, NET_D1], [sx * hw, 0.02, NET_D], 0.024, grey, 8);       // asta inclinata
    tube([sx * hw, 0.02, 0], [sx * hw, 0.02, NET_D], 0.022, grey, 6);          // tubo a terra laterale
    ball([sx * hw, bh, NET_D1], 0.034, grey);
  }
  tube([-hw, GH, 0], [hw, GH, 0], POST_R, white);
  tube([-hw, bh, NET_D1], [hw, bh, NET_D1], 0.022, grey, 8);                  // asta di fondo in alto
  tube([-hw, 0.02, NET_D], [hw, 0.02, NET_D], 0.022, grey, 6);                // tubo a terra di fondo
  const gs = parts.map(([g, col]) => {
    const n = g.attributes.position.count, c = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) { c[i * 3] = col.r; c[i * 3 + 1] = col.g; c[i * 3 + 2] = col.b; }
    g.setAttribute('color', new THREE.BufferAttribute(c, 3)); return g.index ? g.toNonIndexed() : g;
  });
  return mergeGeometries(gs);
}

// ---------------------------------------------------------------- bandierine
const FLAG_W = 0.5, FLAG_HH = 0.36, FLAG_SU = 7, FLAG_SV = 4;
function flagTexture() {
  // a due colori in diagonale, con orlo scuro: si legge bene contro il pubblico
  return canvasTex(64, 48, (g, w, h) => {
    g.fillStyle = '#ffd21f'; g.fillRect(0, 0, w, h);
    g.fillStyle = '#e8352b'; g.beginPath(); g.moveTo(w, 0); g.lineTo(w, h); g.lineTo(0, h); g.fill();
    g.strokeStyle = 'rgba(0,0,0,0.35)'; g.lineWidth = 3; g.strokeRect(1.5, 1.5, w - 3, h - 3);
  });
}

export class Props {
  constructor(scene) {
    this.scene = scene; this.t = 0; this.m = null;
    this.v = new THREE.Vector3(); this.v2 = new THREE.Vector3();
    // pallone: leggermente lucido (riflesso dei fari)
    this.ball = new THREE.Mesh(new THREE.SphereGeometry(BALL_R, 24, 16), new THREE.MeshPhongMaterial({ map: ballTexture(), specular: 0x5a5a5a, shininess: 70 }));
    scene.add(this.ball);
    this.shMat = new THREE.MeshBasicMaterial({ map: ballShadowTexture(), transparent: true, depthWrite: false });
    const sg = new THREE.PlaneGeometry(1, 1); sg.rotateX(-Math.PI / 2);
    this.ballSh = new THREE.Mesh(sg, this.shMat); this.ballSh.renderOrder = 1; scene.add(this.ballSh);
    this.buildGoals(); this.buildFlags(); this.buildTrail(); this.buildPuff(); this.buildConfetti();
  }

  buildGoals() {
    const frameG = buildFrame(), netTex = netTexture();
    const frameM = new THREE.MeshPhongMaterial({ vertexColors: true, specular: 0x666666, shininess: 50 });
    // ombra morbida della porta sull'erba (dentro la rete e sotto la traversa)
    const aoT = canvasTex(64, 64, (g, w, h) => {
      const gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, 'rgba(0,0,0,0.05)'); gr.addColorStop(0.35, 'rgba(0,0,0,0.3)'); gr.addColorStop(1, 'rgba(0,0,0,0.12)');
      g.fillStyle = gr; g.fillRect(0, 0, w, h);
      const sx = g.createLinearGradient(0, 0, w, 0); sx.addColorStop(0, 'rgba(0,0,0,1)'); sx.addColorStop(0.1, 'rgba(0,0,0,0)'); sx.addColorStop(0.9, 'rgba(0,0,0,0)'); sx.addColorStop(1, 'rgba(0,0,0,1)');
      g.globalCompositeOperation = 'destination-out'; g.fillStyle = sx; g.fillRect(0, 0, w, h);
    }, 1);
    const aoG = new THREE.PlaneGeometry(GW + 0.6, NET_D + 0.5); aoG.rotateX(-Math.PI / 2); aoG.translate(0, 0.012, NET_D / 2 + 0.05);
    const aoM = new THREE.MeshBasicMaterial({ map: aoT, transparent: true, depthWrite: false });
    this.goals = [];
    for (const d of [1, -1]) {
      const g = new THREE.Group(); g.position.z = -d * HL; g.rotation.y = d > 0 ? Math.PI : 0; this.scene.add(g);
      const frame = new THREE.Mesh(frameG, frameM); g.add(frame);
      const ao = new THREE.Mesh(aoG, aoM); ao.renderOrder = 1; g.add(ao);
      const net = buildNet();
      const nm = new THREE.MeshLambertMaterial({ map: netTex, emissive: 0x3a3d42, transparent: true, opacity: NET_FAR, side: THREE.DoubleSide, depthWrite: false });
      const mesh = new THREE.Mesh(net.g, nm); mesh.renderOrder = 2; g.add(mesh);
      const n = net.wt.length;
      this.goals.push({ d, g, frame, mesh, nm, base: net.base, nrm: net.nrm, wt: net.wt, disp: new Float32Array(n), vel: new Float32Array(n), active: false, shake: 0, shakeT: 0, inside: false });
    }
  }

  buildFlags() {
    const poles = [];
    for (const sx of [-1, 1]) for (const sy of [-1, 1]) {
      const p = new THREE.CylinderGeometry(0.022, 0.026, FLAG_H, 8); p.translate(sx * HW, FLAG_H / 2, -sy * HL); poles.push(p);
      const tip = new THREE.SphereGeometry(0.03, 8, 6); tip.translate(sx * HW, FLAG_H, -sy * HL); poles.push(tip);
    }
    const pg = mergeGeometries(poles.map(g => g.toNonIndexed()));
    this.scene.add(new THREE.Mesh(pg, new THREE.MeshLambertMaterial({ color: 0xf1f1ee })));
    // teli: 4 griglie in una sola geometria, mosse a ogni fotogramma (onda che corre dall'asta alla punta)
    const per = (FLAG_SU + 1) * (FLAG_SV + 1), P = new Float32Array(per * 4 * 3), UV = [], I = [];
    for (let f = 0; f < 4; f++) {
      for (let j = 0; j <= FLAG_SV; j++) for (let i = 0; i <= FLAG_SU; i++) UV.push(i / FLAG_SU, 1 - j / FLAG_SV);
      for (let j = 0; j < FLAG_SV; j++) for (let i = 0; i < FLAG_SU; i++) { const a = f * per + j * (FLAG_SU + 1) + i, b = a + 1, c = a + FLAG_SU + 1, e = c + 1; I.push(a, c, b, b, c, e); }
    }
    const fg = new THREE.BufferGeometry(); fg.setAttribute('position', new THREE.BufferAttribute(P, 3)); fg.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(UV), 2)); fg.setIndex(I);
    fg.boundingSphere = new THREE.Sphere(new THREE.Vector3(0, 1, 0), Math.hypot(HW, HL) + 2);
    this.flags = new THREE.Mesh(fg, new THREE.MeshLambertMaterial({ map: flagTexture(), side: THREE.DoubleSide }));
    this.flagPer = per; this.scene.add(this.flags);
    this.waveFlags(0);
  }

  waveFlags(t) {
    const P = this.flags.geometry.attributes.position.array, per = this.flagPer;
    let f = 0;
    for (const sx of [-1, 1]) for (const sy of [-1, 1]) {
      const x0 = sx * HW, z0 = -sy * HL, ph = f * 1.7;
      // il vento soffia verso +x e un poco verso il campo: il telo si allunga sempre da quella parte
      const wx = 0.86, wz = sy * 0.5, wl = Math.hypot(wx, wz), dx = wx / wl, dz = wz / wl;
      for (let j = 0; j <= FLAG_SV; j++) for (let i = 0; i <= FLAG_SU; i++) {
        const u = i / FLAG_SU, v = j / FLAG_SV, k = (f * per + j * (FLAG_SU + 1) + i) * 3;
        const wave = Math.sin(t * 7.5 - u * 4.2 + ph + v * 0.6) * 0.075 * u + Math.sin(t * 13 - u * 7 + ph) * 0.02 * u;
        const along = u * FLAG_W * (1 - 0.06 * Math.abs(wave) / 0.075);
        P[k] = x0 + dx * along - dz * wave; P[k + 1] = FLAG_H - 0.02 - v * FLAG_HH - u * u * 0.05; P[k + 2] = z0 + dz * along + dx * wave;
      }
      f++;
    }
    this.flags.geometry.attributes.position.needsUpdate = true;
    this.flags.geometry.computeVertexNormals();
  }

  buildTrail() {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(TRAIL_N * 2 * 3), 3));
    g.setAttribute('color', new THREE.BufferAttribute(new Float32Array(TRAIL_N * 2 * 4), 4));
    const idx = []; for (let i = 0; i < TRAIL_N - 1; i++) { const a = i * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
    g.setIndex(idx); g.setDrawRange(0, 0);
    this.trail = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ vertexColors: true, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide }));
    this.trail.frustumCulled = false; this.trail.visible = false; this.trail.renderOrder = 3; this.scene.add(this.trail);
    this.trailPts = [];
  }

  buildPuff() {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(PUFF_N * 3), 3));
    g.setAttribute('color', new THREE.BufferAttribute(new Float32Array(PUFF_N * 4), 4));
    g.setDrawRange(0, 0);
    const dot = canvasTex(32, 32, (c) => { const gr = c.createRadialGradient(16, 16, 0, 16, 16, 15); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.5, 'rgba(255,255,255,0.8)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); c.fillStyle = gr; c.fillRect(0, 0, 32, 32); }, 1);
    this.puff = new THREE.Points(g, new THREE.PointsMaterial({ map: dot, size: 0.15, vertexColors: true, transparent: true, depthWrite: false }));
    this.puff.frustumCulled = false; this.puff.visible = false; this.puff.renderOrder = 3; this.scene.add(this.puff);
    this.parts = [];
  }

  buildConfetti() {
    const g = new THREE.PlaneGeometry(0.16, 0.1);
    this.conf = new THREE.InstancedMesh(g, new THREE.MeshBasicMaterial({ side: THREE.DoubleSide }), CONF_N);
    this.conf.frustumCulled = false; this.conf.visible = false; this.scene.add(this.conf);
    this.confT = 0; this.confP = [];
    this.q = new THREE.Quaternion(); this.e = new THREE.Euler(); this.mx = new THREE.Matrix4(); this.one = new THREE.Vector3(1, 1, 1); this.col = new THREE.Color();
  }

  // nuova partita: via gli effetti rimasti dalla precedente
  reset(m) {
    this.m = m; this.lastKick = m ? m.ball.kick : null; this.score = m ? m.score.slice() : [0, 0]; this.prevVy = 0;
    this.trailPts.length = 0; this.trail.visible = false; this.parts.length = 0; this.puff.visible = false; this.confT = 0; this.conf.visible = false;
    for (const G of this.goals) { G.disp.fill(0); G.vel.fill(0); G.active = true; G.shake = 0; }
  }

  // bx, by, bh = posizione del pallone a schermo (già spostata dai giochetti); cam = telecamera già sistemata
  update(dt, m, flip, cam, me, bx, by, bh) {
    if (m !== this.m) this.reset(m);
    const s = flip, b = m.ball; this.t += dt;
    // pallone: rotola nel verso giusto (asse = su × velocità)
    this.ball.position.set(s * bx, bh + BALL_R, -s * by);
    const sp = Math.hypot(b.vx, b.vy);
    if (sp > 0.2 && dt > 0) { this.v.set(-s * b.vy, 0, -s * b.vx).normalize(); this.ball.rotateOnWorldAxis(this.v, sp * dt / BALL_R); }
    // ombra: più larga e più chiara quando il pallone è alto
    const hk = Math.min(bh, 8), hs = 0.8 + hk * 0.13;
    this.ballSh.position.set(s * bx, 0.03, -s * by); this.ballSh.scale.set(hs, 1, hs);
    this.shMat.opacity = 1 / (1 + hk * 0.45);
    if (dt <= 0) return;
    this.updateGoals(dt, m, s, me);
    this.waveFlags(this.t);
    this.updateEffects(dt, m, s, cam, me);
  }

  updateGoals(dt, m, s, me) {
    const b = m.ball, bp = this.ball.position;
    // pallone che torna indietro vicino alla linea di porta dopo aver colpito palo o traversa: la porta trema
    const dirY = Math.sign(b.y) || 1;
    if (!b.owner && this.prevVy * dirY > 4 && b.vy * dirY < 0 && Math.abs(b.y) > HL - 0.8 && Math.abs(b.x) < GW / 2 + 0.6 && b.h < GH + 0.6) {
      const G = this.goals.find(G => G.d === dirY * s); if (G) { G.shake = Math.min(1, Math.abs(this.prevVy) / 25); G.shakeT = 0; G.active = true; G.hitX = b.x * s * -G.d; }
    }
    this.prevVy = b.vy;
    for (const G of this.goals) {
      G.nm.opacity = G.d * s < 0 ? NET_NEAR : NET_FAR;
      // tremolio del telaio (pochi millimetri, smorzato)
      if (G.shake > 0.01) {
        G.shakeT += dt; const a = G.shake * Math.exp(-G.shakeT * 5);
        G.frame.position.set(Math.sin(G.shakeT * 62) * 0.02 * a, 0, Math.sin(G.shakeT * 47) * 0.012 * a);
        if (G.shakeT < dt * 1.5) for (let i = 0; i < G.vel.length; i++) { const x = G.base[i * 3]; G.vel[i] += G.wt[i] * G.shake * 1.6 * (0.4 + 0.6 * Math.max(0, 1 - Math.abs(x - G.hitX) / GW)) * (i % 2 ? 1 : -1); }
        if (a < 0.01) { G.shake = 0; G.frame.position.set(0, 0, 0); }
      }
      // pallone dentro questa porta (in coordinate della porta: z dietro la linea)
      const L = G.g.worldToLocal(this.v2.copy(bp));
      const inside = (m.phase === 'goal' || m.phase === 'play') && L.z > -0.2 && L.z < NET_D + 0.8 && Math.abs(L.x) < GW / 2 + 0.25 && L.y < GH + 0.8 && Math.abs(b.y) > HL - 0.3;
      if (inside) G.active = true;
      // il pallone arriva in fondo: il telo si gonfia di colpo intorno al punto d'impatto e poi ondeggia
      if (inside && !G.entered) { G.entered = true; G.entrySp = Math.hypot(b.vx, b.vy, b.vh); }
      if (inside && L.z > NET_D1 * 0.9 && !G.hit) { G.hit = true; this.kickNet(G, L, G.entrySp); }
      if (!inside) G.hit = G.entered = false;
      if (!G.active) continue;
      this.springNet(G, dt, inside ? L : null);
    }
  }

  kickNet(G, L, sp) {
    const B = G.base, Nn = G.nrm, v0 = Math.min(5, 1 + sp * NET_KICK);
    for (let i = 0; i < G.wt.length; i++) {
      const k = i * 3, dx = B[k] - L.x, dy = B[k + 1] - L.y, back = Nn[k + 2] > 0.3 ? 1 : Nn[k + 1] > 0.9 ? 0.6 : 0.35;
      G.vel[i] += v0 * back * G.wt[i] * Math.exp(-(dx * dx + dy * dy) / 1.1);
    }
  }

  // ogni vertice della rete è una molla lungo la sua normale: il pallone la spinge fuori, poi torna con un'oscillazione
  springNet(G, dt, L) {
    const pos = G.mesh.geometry.attributes.position.array, B = G.base, Nn = G.nrm, Wt = G.wt, D = G.disp, V = G.vel;
    const steps = Math.max(1, Math.ceil(dt / (1 / 60))), h = dt / steps;
    let energy = 0;
    for (let i = 0; i < Wt.length; i++) {
      const w = Wt[i]; if (w < 1e-3) continue;
      const k = i * 3, nx = Nn[k], ny = Nn[k + 1], nz = Nn[k + 2];
      let target = 0;
      if (L) {
        const rx = L.x - B[k], ry = L.y - B[k + 1], rz = L.z - B[k + 2], along = rx * nx + ry * ny + rz * nz;
        const lx = rx - along * nx, ly = ry - along * ny, lz = rz - along * nz, l2 = lx * lx + ly * ly + lz * lz;
        const pen = along + BALL_R; // quanto il pallone passa oltre il telo
        if (pen > 0) target = pen * Math.exp(-l2 / (NET_PUSH_R * NET_PUSH_R)) * Math.min(1, w * 3);
      }
      let d = D[i], v = V[i];
      if (target > d) { d += (target - d) * Math.min(1, dt * 30); v = Math.max(v, 0); } // il pallone spinge subito
      else for (let n = 0; n < steps; n++) { v += (NET_K * (target - d) - NET_C * v) * h; d += v * h; }
      D[i] = d; V[i] = v; energy += Math.abs(d) + Math.abs(v) * 0.05;
      pos[k] = B[k] + nx * d; pos[k + 1] = B[k + 1] + ny * d; pos[k + 2] = B[k + 2] + nz * d;
    }
    G.mesh.geometry.attributes.position.needsUpdate = true;
    if (!L && energy < 1e-3) { G.active = false; D.fill(0); V.fill(0); for (let i = 0; i < B.length; i++) pos[i] = B[i]; }
  }

  updateEffects(dt, m, s, cam, me) {
    const b = m.ball, bp = this.ball.position;
    // calcio nuovo e forte da terra: sbuffo d'erba
    const sp3 = Math.hypot(b.vx, b.vy, b.vh);
    if (b.kick && b.kick !== this.lastKick && sp3 > PUFF_V && b.h < 0.6) this.spawnPuff(bp.x, bp.z, Math.min(1, (sp3 - PUFF_V) / 15 + 0.4));
    this.lastKick = b.kick;
    // scia sui tiri forti
    const fast = !b.owner && sp3 > TRAIL_V && (m.phase === 'play' || m.phase === 'goal');
    const P = this.trailPts;
    for (const p of P) p.a += dt;
    while (P.length && P[0].a > TRAIL_LIFE) P.shift();
    if (fast) { P.push({ x: bp.x, y: bp.y, z: bp.z, a: 0, k: Math.min(1, (sp3 - TRAIL_V) / 12 + 0.35) }); if (P.length > TRAIL_N) P.shift(); }
    this.drawTrail(cam);
    this.updatePuff(dt);
    // gol della propria squadra: coriandoli coi colori della maglia
    if (m.score[me] > this.score[me]) this.spawnConfetti(m, s, me);
    this.score = m.score.slice();
    this.updateConfetti(dt);
  }

  drawTrail(cam) {
    const P = this.trailPts, n = P.length;
    if (n < 2) { this.trail.visible = false; return; }
    const pos = this.trail.geometry.attributes.position.array, col = this.trail.geometry.attributes.color.array, v = this.v, t = this.v2;
    for (let i = 0; i < n; i++) {
      const a = P[Math.max(0, i - 1)], c = P[Math.min(n - 1, i + 1)], p = P[i];
      t.set(c.x - a.x, c.y - a.y, c.z - a.z);
      v.set(cam.position.x - p.x, cam.position.y - p.y, cam.position.z - p.z).cross(t).normalize();
      const q = i / (n - 1), life = 1 - p.a / TRAIL_LIFE, w = BALL_R * 0.85 * (0.15 + 0.85 * q) * (0.5 + 0.5 * life);
      pos[i * 6] = p.x + v.x * w; pos[i * 6 + 1] = p.y + v.y * w; pos[i * 6 + 2] = p.z + v.z * w;
      pos[i * 6 + 3] = p.x - v.x * w; pos[i * 6 + 4] = p.y - v.y * w; pos[i * 6 + 5] = p.z - v.z * w;
      const al = q * q * life * 0.55 * p.k;
      for (const o of [0, 4]) { col[i * 8 + o] = 0.85; col[i * 8 + o + 1] = 0.93; col[i * 8 + o + 2] = 1; col[i * 8 + o + 3] = al; }
    }
    this.trail.geometry.attributes.position.needsUpdate = true; this.trail.geometry.attributes.color.needsUpdate = true;
    this.trail.geometry.setDrawRange(0, (n - 1) * 6); this.trail.visible = true;
  }

  spawnPuff(x, z, k) {
    const n = Math.round(10 + 10 * k);
    for (let i = 0; i < n && this.parts.length < PUFF_N; i++) {
      const a = Math.random() * Math.PI * 2, r = 0.6 + Math.random() * 2.2 * k, dust = i % 4 === 0;
      const c = dust ? [0.62, 0.62, 0.45] : Math.random() < 0.5 ? [0.2, 0.45, 0.16] : [0.32, 0.6, 0.22];
      this.parts.push({ x: x + Math.cos(a) * 0.12, y: 0.05, z: z + Math.sin(a) * 0.12, vx: Math.cos(a) * r, vy: 1.6 + Math.random() * 2.6 * k, vz: Math.sin(a) * r, t: 0, life: 0.45 + Math.random() * 0.35, c, dust });
    }
  }

  updatePuff(dt) {
    const A = this.parts; if (!A.length) { this.puff.visible = false; return; }
    const pos = this.puff.geometry.attributes.position.array, col = this.puff.geometry.attributes.color.array;
    let n = 0;
    for (let i = A.length - 1; i >= 0; i--) { const p = A[i]; p.t += dt; if (p.t >= p.life) A.splice(i, 1); }
    for (const p of A) {
      const drag = p.dust ? 3 : 1.2;
      p.vy -= (p.dust ? 2 : 9.8) * dt; p.vx -= p.vx * drag * dt; p.vz -= p.vz * drag * dt; p.vy -= p.vy * (p.dust ? 2 : 0) * dt;
      p.x += p.vx * dt; p.y = Math.max(0.03, p.y + p.vy * dt); p.z += p.vz * dt;
      pos[n * 3] = p.x; pos[n * 3 + 1] = p.y; pos[n * 3 + 2] = p.z;
      const f = 1 - p.t / p.life;
      col[n * 4] = p.c[0]; col[n * 4 + 1] = p.c[1]; col[n * 4 + 2] = p.c[2]; col[n * 4 + 3] = f * (p.dust ? 0.45 : 0.95); n++;
    }
    this.puff.geometry.attributes.position.needsUpdate = true; this.puff.geometry.attributes.color.needsUpdate = true;
    this.puff.geometry.setDrawRange(0, n); this.puff.visible = n > 0;
  }

  spawnConfetti(m, s, me) {
    const kit = m.teams[me] && m.teams[me].kit, cols = [kit ? kit.shirt : 0xffffff, kit ? kit.shorts : 0xffd21f, 0xffffff, 0xffd21f, kit && kit.stripe !== undefined ? kit.stripe : 0x4fc3ff];
    const gz = -s * (me === 0 ? HL : -HL), toward = Math.sign(-gz); // davanti alla porta dove è entrato il pallone
    this.confP.length = 0;
    for (let i = 0; i < CONF_N; i++) {
      this.confP.push({ x: (Math.random() - 0.5) * 26, y: 4 + Math.random() * 9, z: gz + toward * (Math.random() * 16 - 2), vy: -(0.8 + Math.random() * 0.9), sw: Math.random() * 6, sp: 2 + Math.random() * 4, rx: Math.random() * 6, ry: Math.random() * 6, rz: Math.random() * 6 });
      this.conf.setColorAt(i, this.col.setHex(cols[i % cols.length]));
    }
    this.conf.instanceColor.needsUpdate = true;
    this.confT = CONF_T; this.conf.visible = true;
  }

  updateConfetti(dt) {
    if (this.confT <= 0) return;
    this.confT -= dt;
    if (this.confT <= 0) { this.conf.visible = false; return; }
    const sc = Math.min(1, this.confT / 0.6);
    for (let i = 0; i < CONF_N; i++) {
      const p = this.confP[i];
      p.y = Math.max(0.02, p.y + p.vy * dt); p.sw += dt * p.sp;
      const fall = p.y > 0.03;
      const x = p.x + (fall ? Math.sin(p.sw) * 0.35 : 0), z = p.z + (fall ? Math.cos(p.sw * 0.8) * 0.25 : 0);
      if (fall) { p.rx += dt * p.sp; p.ry += dt * p.sp * 0.7; }
      this.e.set(fall ? p.rx : -Math.PI / 2, p.ry, fall ? p.rz : 0); this.q.setFromEuler(this.e);
      this.v.set(x, p.y, z); this.one.setScalar(sc);
      this.mx.compose(this.v, this.q, this.one); this.conf.setMatrixAt(i, this.mx);
    }
    this.conf.instanceMatrix.needsUpdate = true;
  }
}
