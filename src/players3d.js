// Giocatori 3D: un solo modello umanoide animato (Kenney "Animated Characters", CC0) condiviso da tutti.
// Ogni giocatore = 1 SkinnedMesh (1 draw call): corpo + capelli veri (mesh agganciata all'osso della testa, fusa
// nella stessa geometria, costruita a codice in src/hair3d.js) con un materiale Lambert e una texture dipinta al volo (512×512 in partita, 1024 nell'editor):
// viso (occhi, colore degli occhi, sopracciglia, barba), maglia con stile e motivo della squadra, stemma sul petto,
// cognome e numero sulla schiena, pantaloncini, calzettoni, scarpe.
// Clip nel file: idle, run, jump. Calcio, scivolata, tuffo, a terra, esultanza, colpo di testa e posa del
// portiere sono fatti ruotando le ossa sopra il clip (pose procedurali).
//
// Uso (da render.js): const m = await loadPlayers3D(arrayBuffer); f = m.make(kit, look, { num, name }); m.pose(p, f, dt, ctx)
//   kit = { shirt, shorts, socks, style?, crest?, gloves? }  look = oggetto di src/looks.js (o un numero dei salvataggi vecchi)
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { clone as cloneSkinned } from 'three/addons/utils/SkeletonUtils.js';
import { SKINS, HAIR_COLORS, EYE_COLORS, BOOTS, normalizeLook, lookFromSeed, normalizeKitStyle, backName, hash32 } from './looks.js';
import { drawCrest } from './crest.js';
import { makeBase, hairPieces, scalpPaint, paintHairTex } from './hair3d.js';
import { applyMove, canMove } from './move-pose.js';
import { trickMove, MATCH_OPT } from './moves/tricks.js';
import { mirrorFrame } from './moves/core.js';

const TRICK_BLEND = 0.12; // s: entrata e uscita dal movimento calcolato del giochetto (dalla corsa del clip e ritorno)

const MODEL_H = 1.86;          // altezza del modello prima di SCALE (la testa è grande: un po' più alto della figura a box, che arriva a 1,75)
export const TEX = 512;        // lato della texture dipinta per ogni giocatore in partita
const RUN_FULL = 1.6;          // m/s: sopra questa velocità il clip di corsa è a peso pieno
const RUN_REF = 6.0;           // m/s: velocità a cui il clip di corsa gira a velocità 1
const KICK_T = 0.35;           // durata di kickAnim nel motore
const HEAD_H = 1.3;            // palla sopra questa altezza al momento del colpo = colpo di testa
const SOLE = '#e4e4e4';
const FIT_OFF = [-0.012, 0.05]; // maglia aderente / larga: spostamento del busto lungo la normale (in raggi della testa)

// Zone della texture Kenney (coordinate su 1024, origine in alto a sinistra, come le UV glTF)
const R = {
  head: [0, 0, 640, 440], neck: [0, 440, 640, 50],
  torso: [0, 490, 640, 534],               // busto (dietro in alto, capovolto; davanti in basso) e braccia (striscia orizzontale)
  soles: [640, 0, 384, 140], shoes: [640, 140, 190, 390],
  hands: [830, 140, 194, 630], hands2: [640, 530, 190, 240],
  legs: [620, 770, 404, 254],             // gambe: in alto i fianchi (770), in basso le caviglie (1024)
  hair: [16, 496, 160, 120],              // zona libera: tinta dei capelli (la usano le UV della mesh dei capelli, src/hair3d.js)
};
const FACE = { x: 320, eyeY: 222, eyeDX: 36, browY: 196, noseY: 247, mouthY: 274 }; // viso al centro della zona testa
const BACK = { x: 320, top: 762 };        // schiena: centro e attaccatura del collo (verso il basso = v che cala)
const LEG_TOP = 770, KNEE = 905;

const hex = c => '#' + (c >>> 0).toString(16).padStart(6, '0').slice(-6);
const rgb = h => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
const shade = (h, f) => { const c = rgb(h); return '#' + c.map(x => Math.max(0, Math.min(255, Math.round(x * f))).toString(16).padStart(2, '0')).join(''); };
const lumH = h => { const c = rgb(h); return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255; };
const DEG = Math.PI / 180;
// canvas di appoggio in memoria (non sulla GPU): copiarli e rileggerli costa poco
const cpuCanvas = (w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; c.getContext('2d', { willReadFrequently: true }); return c; };
const GETS = ['getX', 'getY', 'getZ', 'getW'];
const SCALP = 2;               // passo (px su 1024) della mappa testa → direzione usata per dipingere la cute

// luce di contorno (riflesso freddo dei fari sui bordi della figura): stacca i giocatori dall'erba e dal pubblico.
// Costa solo qualche istruzione nel fragment shader, lo stesso programma per tutti i giocatori.
const RIM = { color: '0.62, 0.72, 0.95', power: 3.0, k: 0.3 };
function withRim(mat) {
  mat.onBeforeCompile = (sh) => {
    sh.fragmentShader = sh.fragmentShader.replace('#include <opaque_fragment>',
      `outgoingLight += mix(vec3(${RIM.color}), diffuseColor.rgb, 0.35) * ${RIM.k.toFixed(2)} * pow(1.0 - saturate(dot(geometryNormal, geometryViewDir)), ${RIM.power.toFixed(1)});
#include <opaque_fragment>`);
  };
  mat.customProgramCacheKey = () => 'tag-player-rim';
  return mat;
}

export class Players3D {
  constructor(gltf) {
    this.scene = gltf.scene;
    this.setup();
    this.mesh = null; this.scene.traverse(o => { if (o.isSkinnedMesh && !this.mesh) this.mesh = o; });
    if (!this.mesh) throw new Error('nessuna SkinnedMesh nel modello');
    this.clips = {}; for (const c of gltf.animations) this.clips[c.name] = c;
    this.geoCache = new Map();
    this.q = new THREE.Quaternion(); this.q2 = new THREE.Quaternion(); this.e = new THREE.Euler(); this.todo = [];
    this.measure();
    this.headFrame();
  }

  // costanti del modello (la sottoclasse di src/athlete3d.js le cambia)
  setup() { this.modelH = MODEL_H; this.hairRect = R.hair; this.fitRe = /Spine|Chest|Shoulder|^(Left|Right)Arm$/; }

  // scala e verso: il modello deve guardare +z ed essere alto MODEL_H con i piedi a y = 0
  measure() {
    const s = this.scene; s.updateMatrixWorld(true);
    const bones = {}; s.traverse(o => { if (o.isBone) bones[o.name] = o; });
    const v = new THREE.Vector3(), w = new THREE.Vector3();
    const f = bones.RightFoot || bones.LeftFoot, t = bones.RightToes || bones.LeftToes;
    let yaw = 0;
    if (f && t) { f.getWorldPosition(v); t.getWorldPosition(w); yaw = Math.atan2(w.x - v.x, w.z - v.z); }
    const box = new THREE.Box3().setFromObject(s, true);
    const h = box.max.y - box.min.y || 1;
    this.fixScale = this.modelH / h; this.fixYaw = -yaw;
    this.fixY = -box.min.y * this.fixScale;
    this.fixQ = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), this.fixYaw);
    const sph = new THREE.Sphere(); box.getBoundingSphere(sph); this.radius = sph.radius / h * this.modelH * 1.6;
  }

  // testa nello spazio della mesh: centro, assi (su, avanti, destra), raggio, triangoli (per i raggi e per dipingere la cute)
  headFrame() {
    const geo = this.mesh.geometry, P = geo.attributes.position, UV = geo.attributes.uv, J = geo.attributes.skinIndex, W = geo.attributes.skinWeight;
    const names = this.mesh.skeleton.bones.map(b => b.name), H = names.indexOf('Head'), Hip = names.indexOf('Hips');
    this.headJoint = H; this.boneOf = [];
    const isHead = [], c = new THREE.Vector3(), hip = new THREE.Vector3(), face = new THREE.Vector3(), v = new THREE.Vector3();
    let nh = 0, np = 0, nf = 0;
    for (let i = 0; i < P.count; i++) {
      let best = 0, bw = -1, hw = 0;
      for (let k = 0; k < 4; k++) { const j = J[GETS[k]](i), w = W[GETS[k]](i); if (w > bw) { bw = w; best = j; } if (j === H) hw += w; }
      this.boneOf[i] = names[best];
      isHead[i] = hw > 0.5; v.fromBufferAttribute(P, i);
      if (isHead[i]) { c.add(v); nh++; const du = UV.getX(i) * 1024 - FACE.x, dv = UV.getY(i) * 1024 - FACE.eyeY; if (du * du + dv * dv < 70 * 70) { face.add(v); nf++; } }
      if (best === Hip) { hip.add(v); np++; }
    }
    c.divideScalar(nh || 1); hip.divideScalar(np || 1); face.divideScalar(nf || 1);
    const up = c.clone().sub(hip).normalize(), fwd = face.clone().sub(c); fwd.addScaledVector(up, -fwd.dot(up)).normalize();
    const right = new THREE.Vector3().crossVectors(up, fwd).normalize();
    // il centro "geometrico" della testa sta un po' sotto la media dei vertici (la calotta ha più vertici)
    const dist = []; for (let i = 0; i < P.count; i++) if (isHead[i]) dist.push(v.fromBufferAttribute(P, i).distanceTo(c));
    dist.sort((a, b) => a - b);
    this.head = { c, up, fwd, right, R: dist[dist.length >> 1] || 1 };
    // triangoli della testa
    const idx = geo.index.array, tris = [];
    for (let t = 0; t < idx.length; t += 3) {
      const a = idx[t], b = idx[t + 1], d = idx[t + 2];
      if (isHead[a] + isHead[b] + isHead[d] < 2) continue;
      tris.push({ p: [a, b, d].map(i => new THREE.Vector3().fromBufferAttribute(P, i)), uv: [a, b, d].map(i => [UV.getX(i) * 1024, UV.getY(i) * 1024]) });
    }
    this.headTris = tris;
    const pts = []; for (let i = 0; i < P.count; i++) if (isHead[i]) pts.push(new THREE.Vector3().fromBufferAttribute(P, i));
    this.hairBase = makeBase({ ...this.head, pts });
    this.scalpMap();
  }
  // per ogni quadretto della zona testa della texture (passo SCALP px) la direzione dal centro della testa:
  // serve a dipingere la cute sotto i capelli con un'attaccatura morbida che segue il taglio scelto
  scalpMap() {
    const cw = 640 / SCALP, ch = 440 / SCALP, map = new Float32Array(cw * ch * 2).fill(NaN), h = this.head;
    const v = new THREE.Vector3();
    for (const t of this.headTris) {
      const [a, b, c] = t.uv, dv = t.p.map(p => p.clone().sub(h.c).normalize());
      const x0 = Math.max(0, Math.floor(Math.min(a[0], b[0], c[0]) / SCALP)), x1 = Math.min(cw - 1, Math.ceil(Math.max(a[0], b[0], c[0]) / SCALP));
      const y0 = Math.max(0, Math.floor(Math.min(a[1], b[1], c[1]) / SCALP)), y1 = Math.min(ch - 1, Math.ceil(Math.max(a[1], b[1], c[1]) / SCALP));
      const det = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1]); if (Math.abs(det) < 1e-6) continue;
      for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
        const px = (x + 0.5) * SCALP, py = (y + 0.5) * SCALP;
        const l1 = ((b[1] - c[1]) * (px - c[0]) + (c[0] - b[0]) * (py - c[1])) / det, l2 = ((c[1] - a[1]) * (px - c[0]) + (a[0] - c[0]) * (py - c[1])) / det, l3 = 1 - l1 - l2;
        if (l1 < -0.02 || l2 < -0.02 || l3 < -0.02) continue;
        v.set(0, 0, 0).addScaledVector(dv[0], l1).addScaledVector(dv[1], l2).addScaledVector(dv[2], l3);
        const [el, az] = this.toDir(v.add(h.c)), i = (y * cw + x) * 2; map[i] = el; map[i + 1] = az;
      }
    }
    this.scalp = { map, cw, ch };
  }
  toDir(p) { const h = this.head, d = p.clone().sub(h.c); const y = d.dot(h.up), x = d.dot(h.right), z = d.dot(h.fwd); return [Math.atan2(y, Math.hypot(x, z)) / DEG, Math.atan2(x, z) / DEG]; }
  // ---------------------------------------------------------------- geometria: capelli fusi col corpo, maglia larga o aderente
  // capelli: pezzi lisci costruiti in coordinate locali della testa (src/hair3d.js), portati nello spazio della mesh
  hairGeo(style) {
    const h = this.head, hr = h.R, pc = hairPieces(style, this.hairBase.base), [sx, sy, sw, sh] = this.hairRect;
    const n = pc.pos.length / 3, pos = new Float32Array(n * 3), nrm = new Float32Array(n * 3), uv = new Float32Array(n * 2);
    for (let i = 0; i < n; i++) {
      const x = pc.pos[i * 3], y = pc.pos[i * 3 + 1], z = pc.pos[i * 3 + 2], a = pc.nrm[i * 3], b = pc.nrm[i * 3 + 1], c = pc.nrm[i * 3 + 2];
      for (let k = 0, K = ['x', 'y', 'z']; k < 3; k++) {
        pos[i * 3 + k] = h.c[K[k]] + hr * (h.right[K[k]] * x + h.up[K[k]] * y + h.fwd[K[k]] * z);
        nrm[i * 3 + k] = h.right[K[k]] * a + h.up[K[k]] * b + h.fwd[K[k]] * c;
      }
      uv[i * 2] = (sx + sw * pc.uv[i * 2]) / 1024; uv[i * 2 + 1] = (sy + sh * pc.uv[i * 2 + 1]) / 1024;
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(pos, 3)); g.setAttribute('normal', new THREE.BufferAttribute(nrm, 3)); g.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
    g.setIndex(pc.ind);
    return g;
  }

  bodyGeo(hair, fit) {
    const key = hair + ':' + fit;
    if (this.geoCache.has(key)) return this.geoCache.get(key);
    const base = this.mesh.geometry, hg = this.hairGeo(hair), nb = base.attributes.position.count, nh = hg.attributes.position.count;
    const out = new THREE.BufferGeometry(), A = base.attributes;
    // copia componente per componente: gli attributi del glTF possono essere interlacciati o normalizzati
    const GET = ['getX', 'getY', 'getZ', 'getW'];
    const cat = (name, size, hairVal) => {
      const src = A[name], arr = name === 'skinIndex' ? new Uint16Array((nb + nh) * size) : new Float32Array((nb + nh) * size);
      for (let i = 0; i < nb; i++) for (let k = 0; k < size; k++) arr[i * size + k] = src[GET[k]](i);
      for (let i = 0; i < nh; i++) for (let k = 0; k < size; k++) arr[(nb + i) * size + k] = hairVal(i, k);
      out.setAttribute(name, new THREE.BufferAttribute(arr, size));
    };
    const HP = hg.attributes.position.array, HN = hg.attributes.normal ? hg.attributes.normal.array : [], HU = hg.attributes.uv.array;
    cat('position', 3, (i, k) => HP[i * 3 + k]); cat('normal', 3, (i, k) => HN[i * 3 + k]); cat('uv', 2, (i, k) => HU[i * 2 + k]);
    cat('skinIndex', 4, (i, k) => (k === 0 ? this.headJoint : 0)); cat('skinWeight', 4, (i, k) => (k === 0 ? 1 : 0));
    // maglia aderente o larga: il busto e le spalle si gonfiano un poco lungo la normale
    const off = FIT_OFF[fit] * this.head.R, P = out.attributes.position.array, N = A.normal;
    for (let i = 0; i < nb; i++) if (this.fitRe.test(this.boneOf[i])) for (let k = 0; k < 3; k++) P[i * 3 + k] += N[GET[k]](i) * off;
    const bi = base.index.array, hi = hg.index ? hg.index.array : [], idx = new (nb + nh > 65535 ? Uint32Array : Uint16Array)(bi.length + hi.length);
    idx.set(bi); for (let i = 0; i < hi.length; i++) idx[bi.length + i] = hi[i] + nb;
    out.setIndex(new THREE.BufferAttribute(idx, 1));
    out.boundingSphere = base.boundingSphere; out.boundingBox = base.boundingBox;
    this.geoCache.set(key, out);
    return out;
  }

  // ---------------------------------------------------------------- texture del giocatore
  paint(kit, look, opt, size) {
    const c = document.createElement('canvas'); c.width = c.height = size;
    const g = c.getContext('2d'); g.scale(size / 1024, size / 1024);
    const L = look, st = normalizeKitStyle(kit.style), skin = SKINS[L.skin][1], hairC = HAIR_COLORS[L.hairColor][1];
    const shirt = hex(kit.shirt), alt = hex(kit.shorts === kit.shirt ? (lumH(hex(kit.shirt)) > 0.5 ? 0x1b1b1b : 0xffffff) : kit.shorts);
    const rect = (x, y, w, h, col) => { g.fillStyle = col; g.fillRect(x, y, w, h); };
    rect(0, 0, 1024, 1024, skin);
    this.paintHead(g, L, skin, hairC);
    this.paintShirt(g, kit, st, shirt, alt, skin, opt);
    this.paintHair(g, L, hairC, skin); // dopo la maglia: la tinta dei capelli sta in una zona libera dentro il rettangolo del busto
    this.paintLegs(g, kit, st, alt, skin);
    // mani (guanti per il portiere), scarpe con suola e una fascia di contrasto
    const glove = kit.gloves ? '#f4f4f4' : skin;
    rect(...R.hands, glove); rect(...R.hands2, glove);
    if (kit.gloves) { g.fillStyle = shade(shirt, 0.8); for (const [x, y, w, h] of [R.hands, R.hands2]) g.fillRect(x, y + h * 0.4, w, h * 0.12); }
    const boot = BOOTS[L.boots][1], acc = lumH(boot) > 0.6 ? '#1b1b1f' : (L.boots === 0 ? '#e9e9e9' : '#ffffff');
    rect(...R.soles, SOLE); rect(...R.shoes, boot);
    g.save(); g.beginPath(); g.rect(...R.shoes); g.clip(); g.strokeStyle = acc; g.lineWidth = 14;
    for (let y = 140; y < 600; y += 175) { g.beginPath(); g.moveTo(640, y + 70); g.lineTo(830, y); g.stroke(); }
    g.restore();
    return c;
  }

  paintHead(g, L, skin, hairC) {
    const F = FACE, dark = shade(skin, 0.82), deep = shade(skin, 0.62);
    // ombra sotto il mento e sul collo, orecchie, naso, bocca
    const grd = g.createLinearGradient(0, 300, 0, 470); grd.addColorStop(0, skin); grd.addColorStop(1, shade(skin, 0.86));
    g.fillStyle = grd; g.fillRect(0, 300, 640, 190);
    g.strokeStyle = dark; g.lineWidth = 7; g.lineCap = 'round';
    for (const ex of [F.x - 136, F.x + 136]) { g.beginPath(); g.ellipse(ex, F.eyeY + 18, 13, 22, 0, 0, Math.PI * 2); g.fillStyle = shade(skin, 0.93); g.fill(); g.beginPath(); g.arc(ex, F.eyeY + 18, 8, -1.2, 1.2); g.stroke(); }
    g.strokeStyle = deep; g.lineWidth = 5; g.beginPath(); g.arc(F.x, F.noseY - 6, 9, 0.35, Math.PI - 0.35); g.stroke();
    g.strokeStyle = shade(skin, 0.55); g.lineWidth = 6; g.beginPath(); g.moveTo(F.x - 15, F.mouthY); g.quadraticCurveTo(F.x, F.mouthY + 7, F.x + 15, F.mouthY); g.stroke();
    g.fillStyle = shade(skin, 0.9); g.beginPath(); g.ellipse(F.x, F.mouthY + 12, 9, 3, 0, 0, Math.PI * 2); g.fill();
    this.paintBeard(g, L, skin, hairC);
    // occhi
    const iris = EYE_COLORS[L.eyeColor][1];
    for (const s of [-1, 1]) {
      const x = F.x + s * F.eyeDX, y = F.eyeY;
      const [rx, ry, tilt, lid] = [[12, 11, 0, 0], [14, 9, 0.12, 0], [14, 6, 0.05, 0], [15, 13, 0, 0], [17, 8, 0.2, 0], [13, 10, 0, 0.45]][L.eyes];
      g.save(); g.translate(x, y); g.rotate(-s * tilt);
      g.beginPath();
      if (L.eyes === 1 || L.eyes === 4) { g.moveTo(-rx, 0); g.quadraticCurveTo(0, -ry * 2, rx, 0); g.quadraticCurveTo(0, ry * 1.6, -rx, 0); } else g.ellipse(0, 0, rx, ry, 0, 0, Math.PI * 2);
      g.fillStyle = '#fbfbf8'; g.fill(); g.save(); g.clip();
      const ir = Math.min(ry * 1.05 + 2, 10.5);
      g.fillStyle = iris; g.beginPath(); g.arc(s * 1.5, 1, ir, 0, Math.PI * 2); g.fill();
      g.fillStyle = shade(iris, 0.55); g.lineWidth = 2; g.strokeStyle = shade(iris, 0.5); g.stroke();
      g.fillStyle = '#0d0907'; g.beginPath(); g.arc(s * 1.5, 1, ir * 0.48, 0, Math.PI * 2); g.fill();
      g.fillStyle = '#fff'; g.beginPath(); g.arc(s * 1.5 - 3, -3, Math.max(2, ir * 0.25), 0, Math.PI * 2); g.fill();
      if (lid) { g.fillStyle = shade(skin, 0.9); g.fillRect(-rx - 2, -ry - 2, rx * 2 + 4, ry * 2 * lid + 2); }
      g.restore();
      // ciglia: linea scura sopra
      g.strokeStyle = '#1a120d'; g.lineWidth = 3.5; g.beginPath();
      if (lid) { g.moveTo(-rx, -ry + ry * 2 * lid); g.lineTo(rx, -ry + ry * 2 * lid); } else if (L.eyes === 1 || L.eyes === 4) { g.moveTo(-rx, 0); g.quadraticCurveTo(0, -ry * 2, rx, 0); } else g.ellipse(0, 0, rx, ry, 0, Math.PI * 1.05, Math.PI * 1.95);
      g.stroke(); g.restore();
    }
    this.paintBrows(g, L, hairC);
  }

  // sopracciglia (colore dei capelli, un po' più scuro), in coordinate della zona viso Kenney (FACE)
  paintBrows(g, L, hairC) {
    const F = FACE, bc = shade(hairC, lumH(hairC) > 0.6 ? 0.7 : 0.85);
    g.strokeStyle = bc; g.lineCap = 'round';
    for (const s of [-1, 1]) {
      const x = F.x + s * F.eyeDX, y = F.browY;
      const [w, th, arc, ang] = [[15, 6, 4, 0], [14, 3, 3, 0], [16, 10, 3, 0], [15, 5.5, 9, 0], [16, 6.5, 0, 0], [15, 7, 1, -0.28]][L.brows];
      g.lineWidth = th; g.save(); g.translate(x, y); g.rotate(s * ang);
      g.beginPath(); g.moveTo(-w, 2); g.quadraticCurveTo(0, -arc - 1, w, 2); g.stroke(); g.restore();
    }
  }

  paintBeard(g0, L, skin, hairC) {
    let g = g0;
    if (!L.beard) return;
    const F = FACE, x = F.x, y = F.mouthY, col = hairC, out = g;
    const lay = cpuCanvas(640, 440); g = lay.getContext('2d');
    g.save(); g.fillStyle = col;
    const jaw = () => { g.beginPath(); g.moveTo(x - 92, F.eyeY + 42); g.lineTo(x - 82, y + 34); g.quadraticCurveTo(x, y + 78, x + 82, y + 34); g.lineTo(x + 92, F.eyeY + 42); g.lineTo(x + 62, F.eyeY + 48); g.quadraticCurveTo(x + 40, y - 10, x + 24, y - 8); g.quadraticCurveTo(x, y - 18, x - 24, y - 8); g.quadraticCurveTo(x - 40, y - 10, x - 62, F.eyeY + 48); g.closePath(); };
    const mouth = () => { g.globalCompositeOperation = 'destination-out'; g.beginPath(); g.ellipse(x, y + 2, 17, 7, 0, 0, Math.PI * 2); g.fill(); g.globalCompositeOperation = 'source-over'; };
    if (L.beard === 1) { // ombra: puntinato leggero
      const sl = cpuCanvas(300, 200); const q = sl.getContext('2d');
      q.translate(150 - x, 100 - y - 10); q.fillStyle = col;
      q.beginPath(); q.moveTo(x - 92, F.eyeY + 42); q.lineTo(x - 82, y + 34); q.quadraticCurveTo(x, y + 78, x + 82, y + 34); q.lineTo(x + 92, F.eyeY + 42); q.lineTo(x + 50, y - 2); q.lineTo(x - 50, y - 2); q.closePath(); q.clip();
      const r = (() => { let a = 7; return () => { a = (a * 16807) % 2147483647; return a / 2147483647; }; })();
      for (let i = 0; i < 900; i++) q.fillRect(x - 100 + r() * 200, y - 70 + r() * 150, 2.2, 2.2);
      g.globalAlpha = 0.5; g.drawImage(q.canvas, x - 150, y + 10 - 100); g.globalAlpha = 1;
    } else if (L.beard === 2 || L.beard === 4) { // pizzetto (+ baffi)
      g.beginPath(); g.moveTo(x - 16, y + 12); g.quadraticCurveTo(x, y + 8, x + 16, y + 12); g.lineTo(x + 12, y + 40); g.quadraticCurveTo(x, y + 48, x - 12, y + 40); g.closePath(); g.fill();
    }
    if (L.beard === 3 || L.beard === 4 || L.beard === 6) { // baffi
      g.beginPath(); g.moveTo(x - 24, y + 4); g.quadraticCurveTo(x - 20, y - 12, x, y - 9); g.quadraticCurveTo(x + 20, y - 12, x + 24, y + 4); g.quadraticCurveTo(x, y - 3, x - 24, y + 4); g.fill();
    }
    if (L.beard === 5) { g.globalAlpha = 0.85; jaw(); g.fill(); g.globalAlpha = 1; mouth(); }
    if (L.beard === 6) { jaw(); g.fill(); g.fillRect(x - 80, y + 30, 160, 70); mouth(); }
    g.restore();
    out.drawImage(lay, 0, 0);
  }

  // cute sotto i capelli (attaccatura morbida o nuca rasata a puntini) e tinta dei capelli per le UV della mesh
  paintHair(g, L, hairC, skin) {
    if (L.hair > 0 && this.scalp) {
      const { map, cw, ch } = this.scalp, lay = document.createElement('canvas'); lay.width = cw; lay.height = ch;
      const q = lay.getContext('2d'), img = q.createImageData(cw, ch), d = img.data, col = rgb(shade(hairC, 0.85));
      for (let i = 0; i < cw * ch; i++) {
        const el = map[i * 2], az = map[i * 2 + 1]; if (el !== el) continue;
        const a = scalpPaint(L.hair, el, az, (Math.imul(i, 2654435761) >>> 0) / 4294967296);
        d[i * 4] = col[0]; d[i * 4 + 1] = col[1]; d[i * 4 + 2] = col[2]; d[i * 4 + 3] = a * 255;
      }
      q.putImageData(img, 0, 0);
      g.save(); g.imageSmoothingEnabled = true; g.drawImage(lay, 0, 0, 640, 440); g.restore();
    }
    paintHairTex(g, L.hair, hairC, skin, R.hair);
  }

  paintShirt(g, kit, st, shirt, alt, skin, opt) {
    const [tx, ty, tw, th] = R.torso, rect = (x, y, w, h, col) => { g.fillStyle = col; g.fillRect(x, y, w, h); };
    rect(tx, ty, tw, th, shirt);
    // motivo, nei colori della squadra (righe sul busto e sulle maniche come verrebbero su una maglia vera)
    g.save(); g.beginPath(); g.rect(tx, ty, tw, th); g.clip(); g.fillStyle = alt;
    if (st.pattern === 1) for (let x = 262; x < 400; x += 44) { g.fillRect(x, 490, 20, 534); }
    else if (st.pattern === 2) { for (let y = 790; y < 1024; y += 52) g.fillRect(240, y, 160, 22); for (let y = 740; y > 490; y -= 52) g.fillRect(240, y - 22, 160, 22); }
    else if (st.pattern === 3) { g.beginPath(); g.moveTo(240, 790); g.lineTo(400, 900); g.lineTo(400, 950); g.lineTo(240, 840); g.fill(); g.beginPath(); g.moveTo(400, 740); g.lineTo(240, 630); g.lineTo(240, 580); g.lineTo(400, 690); g.fill(); }
    else if (st.pattern === 4) { g.fillRect(320, 768, 80, 256); g.fillRect(240, 490, 80, 278); g.fillRect(384, 640, 256, 200); }
    g.restore();
    // maniche: corte (a metà braccio), lunghe (fino al polso, polsino colorato), senza (spalla scoperta con bordino)
    const armY = 640, armH = 200;
    if (st.sleeves === 0) { rect(0, armY, 165, armH, skin); rect(475, armY, 165, armH, skin); rect(165, armY, 10, armH, alt); rect(465, armY, 10, armH, alt); }
    else if (st.sleeves === 1) { rect(0, armY, 14, armH, alt); rect(626, armY, 14, armH, alt); }
    else { rect(0, armY, 238, armH, skin); rect(402, armY, 238, armH, skin); rect(236, armY, 6, armH, alt); rect(398, armY, 6, armH, alt); }
    // colletto: girocollo, a V, polo con bottoni (davanti scende da v 768)
    const top = 768;
    g.fillStyle = alt; g.strokeStyle = alt; g.lineWidth = 9;
    if (st.collar === 0) { g.beginPath(); g.ellipse(320, top, 34, 18, 0, 0, Math.PI); g.stroke(); }
    else if (st.collar === 1) { g.lineWidth = 8; g.beginPath(); g.moveTo(288, top); g.lineTo(320, top + 44); g.lineTo(352, top); g.stroke(); }
    else { g.beginPath(); g.moveTo(278, top); g.lineTo(312, top + 26); g.lineTo(306, top); g.fill(); g.beginPath(); g.moveTo(362, top); g.lineTo(328, top + 26); g.lineTo(334, top); g.fill(); g.fillRect(314, top, 12, 46); g.fillStyle = shirt; for (const y of [top + 14, top + 32]) { g.beginPath(); g.arc(320, y, 3.5, 0, 7); g.fill(); } }
    rect(270, top - 8, 100, 8, alt); rect(270, top - 2, 100, 4, shade(alt, 0.85)); // bordo del collo dietro
    // stemma sul petto (lato sinistro del giocatore) e numero piccolo
    if (kit.crest) drawCrest(g, kit.crest, kit.crest.c1, kit.crest.c2, 343, 790, 30);
    // cognome e numero sulla schiena (capovolti: sulla schiena le UV vanno dal collo verso il basso con v che cala)
    const ink = this.inkFor(shirt, alt, st.pattern);
    g.save(); g.translate(BACK.x, BACK.top); g.rotate(Math.PI); g.textAlign = 'center'; g.textBaseline = 'middle';
    g.lineJoin = 'round';
    if (opt.name) { let fs = 26; g.font = `800 ${fs}px "Arial Narrow",Arial,sans-serif`; const w = g.measureText(opt.name).width; if (w > 96) { fs = Math.floor(fs * 96 / w); g.font = `800 ${fs}px "Arial Narrow",Arial,sans-serif`; } g.lineWidth = 5; g.strokeStyle = ink.line; g.strokeText(opt.name, 0, 64); g.fillStyle = ink.fill; g.fillText(opt.name, 0, 64); }
    if (opt.num) { const n = String(opt.num); g.font = `900 ${n.length > 1 ? 96 : 104}px "Arial Narrow",Arial,sans-serif`; g.save(); g.scale(n.length > 1 ? 0.78 : 1, 1); g.lineWidth = 9; g.strokeStyle = ink.line; g.strokeText(n, 0, 140); g.fillStyle = ink.fill; g.fillText(n, 0, 140); g.restore(); }
    g.restore();
  }
  // colore di cognome e numero: il secondario della squadra se si legge sulla maglia, altrimenti bianco o nero
  inkFor(shirt, alt, pattern) {
    const ls = lumH(shirt), la = lumH(alt);
    const fill = pattern === 0 && Math.abs(ls - la) > 0.3 ? alt : (ls > 0.55 ? '#14161c' : '#ffffff');
    return { fill, line: lumH(fill) > 0.5 ? 'rgba(0,0,0,0.45)' : 'rgba(255,255,255,0.45)' };
  }

  paintLegs(g, kit, st, alt, skin) {
    const [lx, , lw] = R.legs, shorts = hex(kit.shorts), socks = hex(kit.socks), rect = (y0, y1, col) => { g.fillStyle = col; g.fillRect(lx, y0, lw, y1 - y0); };
    const sEnd = st.shorts === 1 ? 918 : 878;
    rect(LEG_TOP, 1024, skin);
    // ginocchio: leggera ombra
    g.fillStyle = shade(skin, 0.9); g.fillRect(lx, KNEE - 4, lw, 8);
    rect(LEG_TOP, sEnd, shorts); rect(sEnd - 7, sEnd, shade(shorts, 0.8));
    // banda laterale dei pantaloncini nel colore della maglia
    g.fillStyle = hex(kit.shirt === kit.shorts ? 0xffffff : kit.shirt); for (const x of [lx + 6, 832 - 8, 832 + 4, 1024 - 10]) g.fillRect(x, LEG_TOP, 6, sEnd - LEG_TOP - 8);
    const sStart = st.socks === 1 ? 992 : st.socks === 2 ? 948 : 922;
    rect(sStart, 1024, socks);
    if (st.socks === 2) { rect(sStart, sStart + 20, shade(socks, 0.82)); rect(sStart + 20, sStart + 24, alt); }
    else rect(sStart + 6, sStart + 12, lumH(socks) > 0.5 ? shade(socks, 0.75) : alt);
  }

  // ---------------------------------------------------------------- un giocatore
  make(kit, look, opt = {}) {
    const L = typeof look === 'number' ? lookFromSeed(look) : normalizeLook(look);
    const st = normalizeKitStyle(kit.style);
    const g = new THREE.Group(), body = new THREE.Group(), fix = new THREE.Group(); g.add(body); body.add(fix);
    const model = cloneSkinned(this.scene); fix.add(model);
    fix.rotation.y = this.fixYaw; fix.scale.setScalar(this.fixScale); fix.position.y = this.fixY;
    let mesh = null; const bones = {};
    model.traverse(o => { if (o.isSkinnedMesh) mesh = o; if (o.isBone) bones[o.name] = o; });
    this.aliasBones(bones);
    const size = opt.tex || TEX, canvas = this.paint(kit, L, { num: opt.num, name: opt.name ? backName(opt.name) : '' }, size);
    const tex = new THREE.CanvasTexture(canvas); tex.flipY = false; tex.colorSpace = THREE.SRGBColorSpace; tex.anisotropy = 4; tex.generateMipmaps = true;
    const mat = new THREE.MeshLambertMaterial({ map: tex }); withRim(mat);
    mesh.geometry = this.bodyGeo(L.hair, st.fit);
    mesh.material = mat; mesh.frustumCulled = true;
    mesh.boundingSphere = new THREE.Sphere(new THREE.Vector3(0, this.modelH / 2 / this.fixScale, 0), this.radius / this.fixScale);
    const mixer = new THREE.AnimationMixer(model), act = {}, ph = (hash32(L.hair, L.skin, opt.num || 0) % 1000) / 1000;
    for (const n of ['idle', 'run', 'sprint', 'jump']) {
      if (!this.clips[n]) continue;
      const a = mixer.clipAction(this.clips[n]); a.play(); a.setEffectiveWeight(n === 'idle' ? 1 : 0);
      a.time = ph * this.clips[n].duration; act[n] = a;
    }
    return { g, body, fix, model, mesh, mixer, act, bones, mat, tex, saved: [], m3d: true, tris: mesh.geometry.index.count / 3 };
  }
  // nomi delle ossa usati dalle pose (quelli del modello Kenney): la sottoclasse aggiunge i suoi
  aliasBones(bones) { }
  // libera la texture di un giocatore tolto dalla scena (la geometria è condivisa e resta in cache)
  dispose(f) { if (f && f.tex) { f.tex.dispose(); f.mat.dispose(); } }

  // rotazione di un osso attorno a un asse del corpo (x = di lato, y = su, z = avanti), sopra la posa del clip
  rot(f, name, ax, ang) {
    const b = f.bones[name]; if (!b || !ang) return;
    this.todo.push(b, ax, ang);
  }
  flush(f) {
    const L = this.todo, q = this.q, p = this.q2;
    // tutte le correzioni calcolate sulla posa del clip, poi applicate: i figli "seguono" il padre
    const out = [];
    for (let i = 0; i < L.length; i += 3) {
      const b = L[i];
      p.identity(); const chain = []; let n = b.parent; while (n && n !== f.fix) { chain.push(n); n = n.parent; }
      for (let j = chain.length - 1; j >= 0; j--) p.multiply(chain[j].quaternion);
      this.e.set(L[i + 1] === 0 ? L[i + 2] : 0, L[i + 1] === 1 ? L[i + 2] : 0, L[i + 1] === 2 ? L[i + 2] : 0);
      q.setFromEuler(this.e);
      // D = P^-1 · R · P  (P = orientamento del padre nello spazio del corpo, compresa la correzione di verso)
      const P = this.fixQ.clone().multiply(p);
      out.push(b, P.clone().invert().multiply(q).multiply(P));
    }
    // il mixer riscrive un osso solo se il valore del clip cambia: salviamo la posa del clip per rimetterla
    // al fotogramma dopo, altrimenti le correzioni si sommerebbero (a gioco fermo o su ossa senza clip)
    for (let i = 0; i < out.length; i += 2) { f.saved.push(out[i], out[i].quaternion.clone()); out[i].quaternion.premultiply(out[i + 1]); }
    L.length = 0;
  }

  // giochetto del dribbling (tr = { id, q 0..1, side ±1 }): rotazioni delle ossa sopra il clip
  trickPose(f, body, tr, S) {
    const X = 0, Y = 1, Z = 2, q = tr.q, sd = tr.side, PI = Math.PI;
    const bump = u => Math.sin(PI * Math.min(1, Math.max(0, u)));
    const R = sd > 0 ? 'Right' : 'Left', Lf = sd > 0 ? 'Left' : 'Right', zs = sd > 0 ? -1 : 1;
    switch (tr.id) {
      case 'finta': { // spalla da una parte, via dall'altra
        const w = Math.sin(2 * PI * q);
        body.rotation.z = -0.32 * w * sd; this.rot(f, 'Spine', Y, 0.55 * w * sd);
        this.rot(f, 'LeftUpLeg', X, -0.25 * Math.abs(w)); this.rot(f, 'RightUpLeg', X, -0.25 * Math.abs(w));
        this.rot(f, 'LeftLeg', X, 0.4 * Math.abs(w)); this.rot(f, 'RightLeg', X, 0.4 * Math.abs(w));
        this.rot(f, 'LeftArm', Z, 0.6 + 0.3 * w); this.rot(f, 'RightArm', Z, -0.6 + 0.3 * w);
        break;
      }
      case 'doppiopasso': { // due giri della gamba sopra il pallone, prima una poi l'altra
        const h = q < 0.5 ? 0 : 1, u = q < 0.5 ? q * 2 : q * 2 - 1, leg = h ? Lf : R, z = h ? -zs : zs;
        this.rot(f, leg + 'UpLeg', X, -0.95 * bump(u)); this.rot(f, leg + 'UpLeg', Z, z * 0.75 * Math.sin(2 * PI * u - 0.6));
        this.rot(f, leg + 'Leg', X, 0.8 * bump(u));
        body.rotation.z = -z * 0.22 * bump(u); this.rot(f, 'Spine', Y, z * 0.35 * bump(u));
        this.rot(f, 'LeftArm', Z, 0.75); this.rot(f, 'RightArm', Z, -0.75);
        break;
      }
      case 'elastico': { // esterno fuori, poi interno dentro
        const out = q < 0.45 ? bump(q / 0.9) : Math.cos(PI * (q - 0.45) / 0.55 * 1.5) * (1 - (q - 0.45) / 0.55);
        this.rot(f, R + 'UpLeg', Z, zs * 0.7 * out); this.rot(f, R + 'UpLeg', X, -0.45 * Math.abs(out));
        this.rot(f, R + 'Leg', X, 0.5 * Math.abs(out));
        body.rotation.z = zs * 0.18 * out; this.rot(f, 'Spine', Y, -zs * 0.3 * out);
        this.rot(f, 'LeftArm', Z, 0.8); this.rot(f, 'RightArm', Z, -0.8);
        break;
      }
      case 'veronica': { // giro completo sul pallone
        const e = q * q * (3 - 2 * q);
        body.rotation.y = -sd * 2 * PI * e;
        this.rot(f, R + 'UpLeg', X, -0.5 * bump(q * 2)); this.rot(f, Lf + 'UpLeg', X, -0.5 * bump(q * 2 - 1));
        this.rot(f, 'LeftArm', Z, 1.0); this.rot(f, 'RightArm', Z, -1.0);
        this.rot(f, 'Spine', X, 0.15);
        break;
      }
      case 'sombrero': { // punta sotto il pallone, su e oltre, poi saltello per andarlo a prendere
        const k = bump(q / 0.4);
        this.rot(f, R + 'UpLeg', X, -1.1 * k); this.rot(f, R + 'Leg', X, 0.3 * k);
        this.rot(f, 'Spine', X, -0.2 * k);
        body.position.y = 0.25 * bump((q - 0.55) / 0.45) / S;
        this.rot(f, 'LeftArm', Z, 0.9); this.rot(f, 'RightArm', Z, -0.9);
        break;
      }
      case 'arcobaleno': { // tallone dietro che alza il pallone sopra la testa
        const k = bump(q / 0.5);
        this.rot(f, R + 'Leg', X, 1.7 * k); this.rot(f, R + 'UpLeg', X, 0.35 * k);
        this.rot(f, Lf + 'Leg', X, 0.4 * k);
        this.rot(f, 'Spine', X, -0.3 * k);
        body.position.y = (0.18 * k + 0.2 * bump((q - 0.6) / 0.4)) / S;
        this.rot(f, 'LeftArm', Z, 1.1 * k + 0.3); this.rot(f, 'RightArm', Z, -1.1 * k - 0.3);
        break;
      }
    }
  }

  // pesi delle clip (la sottoclasse aggiunge lo scatto)
  blend(A, wIdle, wRun, wJump, v, cele) { // (sprinting: solo la sottoclasse ha il clip di scatto)
    if (A.idle) A.idle.setEffectiveWeight(wIdle);
    if (A.run) { A.run.setEffectiveWeight(wRun); A.run.timeScale = Math.min(1.5, Math.max(0.55, v / RUN_REF)); }
    if (A.sprint) A.sprint.setEffectiveWeight(0);
    if (A.jump) { A.jump.setEffectiveWeight(wJump); A.jump.timeScale = cele ? 1.3 : 1.6; }
  }

  // ctx: { t, phase, flip, yaw, ball, scale, trick }
  pose(p, f, dt, ctx) {
    const body = f.body, A = f.act, X = 0, Z = 2, sv = f.saved;
    for (let i = sv.length - 2; i >= 0; i -= 2) { const o = sv[i + 1]; if (o.isVector3) sv[i].position.copy(o); else sv[i].quaternion.copy(o); } // anche le posizioni (src/move-pose.js)
    sv.length = 0;
    const v = Math.hypot(p.vx, p.vy), run = Math.min(1, Math.max(0, (v - 0.25) / RUN_FULL));
    body.rotation.set(0, 0, 0); body.position.set(0, 0, 0);
    let wIdle = 1 - run, wRun = run, wJump = 0;
    const S = ctx.scale;
    const st = p.state, cele = p.cele > 0 && ctx.phase === 'goal';
    const b = ctx.ball, nearBall = b && Math.hypot(b.x - p.x, b.y - p.y) < 2.2;
    const header = p.kickAnim > 0 && nearBall && b.h > HEAD_H;
    if (st === 'slide' || st === 'down' || (st === 'dive' && p.dive)) { wIdle = 1; wRun = 0; }
    else if (cele || header) { wIdle = 0; wRun = 0; wJump = 1; }
    this.blend(A, wIdle, wRun, wJump, v, cele, !!p.sprint);
    f.mixer.update(dt);

    if (st === 'slide') {
      body.rotation.x = -1.2; body.position.y = 0.36 / S; body.position.z = -0.3;
      this.rot(f, 'LeftUpLeg', X, -0.3); this.rot(f, 'RightUpLeg', X, -1.05);
      this.rot(f, 'LeftLeg', X, 0.5);
      this.rot(f, 'LeftArm', Z, 0.9); this.rot(f, 'RightArm', Z, -0.9);
    } else if (st === 'down') {
      body.rotation.x = -1.42; body.position.y = 0.26 / S; body.position.z = -0.4;
      this.rot(f, 'LeftUpLeg', X, -0.25); this.rot(f, 'RightUpLeg', X, -0.45); this.rot(f, 'LeftLeg', X, 0.6); this.rot(f, 'RightLeg', X, 0.25);
      this.rot(f, 'LeftArm', Z, 0.7); this.rot(f, 'RightArm', Z, -0.7);
    } else if (st === 'dive' && p.dive) {
      const d = p.dive, pr = Math.min(1, p.t / 0.35), s = ctx.flip;
      const lx = s * d.dirx * Math.cos(ctx.yaw) >= 0 ? 1 : -1;
      const reach = Math.abs(d.tx - d.x0) > 0.9 ? 1 : 0.35;
      body.rotation.z = -lx * pr * 1.35 * reach;
      body.position.y = (Math.max(0.25, d.hh - 0.6) * pr * reach + Math.sin(pr * 3.14) * 0.3) / S;
      this.rot(f, 'LeftArm', Z, 2.7 * pr + 0.2); this.rot(f, 'RightArm', Z, -2.7 * pr - 0.2);
      this.rot(f, 'LeftUpLeg', Z, 0.2 * pr); this.rot(f, 'RightUpLeg', Z, -0.2 * pr);
      this.rot(f, 'LeftLeg', X, 0.3); this.rot(f, 'RightLeg', X, 0.4);
    } else if (cele) {
      const j = Math.abs(Math.sin(ctx.t * 7 + p.i)); body.position.y = j * 0.3;
      // braccia a V larghe (il clip di salto le tiene già aperte): dritte in alto sparirebbero dietro la testa grande
      const w = 0.2 * Math.sin(ctx.t * 9 + p.i);
      this.rot(f, 'LeftArm', Z, 1.05 + w); this.rot(f, 'RightArm', Z, -1.05 - w);
      this.rot(f, 'LeftForeArm', Z, 0.4); this.rot(f, 'RightForeArm', Z, -0.4);
    } else if (ctx.trick && st === 'play') {
      if (!canMove(f)) this.trickPose(f, body, ctx.trick, S); // l'atleta: movimento calcolato, dopo flush
    } else if (header) {
      const q = 1 - p.kickAnim / KICK_T;
      body.position.y = Math.sin(q * Math.PI) * 0.35;
      this.rot(f, 'Spine', X, 0.5 * Math.sin(q * Math.PI * 2 - 0.6));
      this.rot(f, 'LeftArm', Z, 1.0); this.rot(f, 'RightArm', Z, -1.0);
    } else if (p.kickAnim > 0) {
      const q = 1 - p.kickAnim / KICK_T;
      this.rot(f, 'RightUpLeg', X, 0.5 - 1.9 * Math.sin(q * Math.PI));
      this.rot(f, 'RightLeg', X, 1.1 * (1 - q));
      this.rot(f, 'Spine', X, -0.18);
      this.rot(f, 'LeftArm', Z, 0.8); this.rot(f, 'RightArm', X, -0.7);
    } else if (p.pos === 'P' && v < 1.2) {
      // portiere pronto: gambe piegate, braccia avanti e aperte
      body.position.y = -0.06;
      this.rot(f, 'Spine', X, 0.25);
      this.rot(f, 'LeftUpLeg', X, -0.45); this.rot(f, 'RightUpLeg', X, -0.45);
      this.rot(f, 'LeftLeg', X, 0.75); this.rot(f, 'RightLeg', X, 0.75);
      this.rot(f, 'LeftArm', Z, 0.7); this.rot(f, 'RightArm', Z, -0.7);
      this.rot(f, 'LeftArm', X, -0.6); this.rot(f, 'RightArm', X, -0.6);
    } else if (run > 0.3) {
      body.rotation.x = 0.08 * run;
    }
    this.flush(f);
    if (ctx.trick && st === 'play' && !cele && canMove(f)) this.trickMove(f, ctx.trick);
  }

  // giochetto dell'atleta (tr = { id, q 0..1, side ±1 }): tutto il corpo nella posa del movimento calcolato per la
  // partita (src/moves/tricks.js, lo stesso che muove il pallone in render.js); col sinistro (side -1) specchiato.
  // Entra ed esce sfumando dal clip. Si annulla da solo al fotogramma dopo (f.saved).
  trickMove(f, tr) {
    const mv = trickMove(tr.id, MATCH_OPT), u = Math.min(1, Math.max(0, tr.q)) * mv.T;
    const fr = tr.side < 0 ? mirrorFrame(mv.at(u)) : mv.at(u);
    applyMove(this, f, fr, { w: Math.max(0, Math.min(1, u / TRICK_BLEND, (mv.T - u) / TRICK_BLEND)) });
  }
}

// Carica il modello da un ArrayBuffer (assets.get('player')). Ritorna null se manca o non si legge.
// Lo stesso buffer dà sempre lo stesso oggetto (la partita e l'editor lo condividono).
const loaded = new WeakMap();
export function loadPlayers3D(buf) {
  if (!buf) return Promise.resolve(null);
  if (loaded.has(buf)) return loaded.get(buf);
  const pr = new Promise((ok) => {
    try {
      new GLTFLoader().parse(buf.slice(0), '', (gltf) => {
        try { ok(new Players3D(gltf)); } catch (e) { console.warn('modello giocatori non usabile:', e); ok(null); }
      }, (e) => { console.warn('modello giocatori non leggibile:', e); ok(null); });
    } catch (e) { console.warn('modello giocatori non leggibile:', e); ok(null); }
  });
  loaded.set(buf, pr);
  return pr;
}

// per il modello realistico (src/athlete3d.js): stessi colori, stesso viso, stessa luce di contorno
export { hex, rgb, shade, lumH, FACE, SOLE, withRim, cpuCanvas };
