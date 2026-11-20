// Costruisce assets/models/athlete.glb (giocatore con proporzioni realistiche) dai pacchetti CC0 di Quaternius:
//   - "Universal Base Characters [Standard]" (Superhero_Male_FullBody, glTF Godot-UE) → corpo e occhi
//   - "Universal Animation Library [Standard]" (UAL1_Standard.glb, Unreal-Godot) → clip idle, run, sprint, jump
// Cosa fa: tiene solo le ossa utili (via le dita), unisce gli occhi al corpo, alleggerisce la mesh (meshoptimizer,
// testa intatta), riporta le UV del corpo nella parte alta dell'atlante (in basso: zona occhi e zona capelli),
// copia solo le rotazioni delle clip (più la traslazione del bacino riscalata) e allega una mappa di "dettaglio"
// in scala di grigi (pieghe di pelle, labbra, palpebre) ricavata dalla texture della pelle chiara; restringe un po'
// spalle, petto e braccia (il modello di partenza ha proporzioni da supereroe).
// Il colore vero (divisa, pelle, viso) lo dipinge il gioco al volo: src/athlete3d.js.
//
// Uso (meshoptimizer serve solo qui; --no-save non tocca package.json):
//   npm i --no-save meshoptimizer@1.3.0
//   node tools/make-athlete.mjs <cartella UBC Standard> <file UAL1_Standard.glb> [assets/models/athlete.glb]
import { readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { inflateSync, deflateSync } from 'node:zlib';
import { MeshoptSimplifier } from 'meshoptimizer';

const [ubcDir, ualFile, outFile = 'assets/models/athlete.glb'] = process.argv.slice(2);
if (!ubcDir || !ualFile) { console.error('uso: node tools/make-athlete.mjs <cartella UBC Standard> <UAL1_Standard.glb> [uscita]'); process.exit(1); }

const BODY_V = 0.875;                 // il corpo occupa la parte alta dell'atlante (v 0..0.875), sotto c'è la fascia libera
const EYE_RECT = [0.875, 0.875, 0.125, 0.125]; // u, v, w, h: tassello degli occhi (in basso a destra)
const TARGET_TRIS = 6200;             // triangoli del corpo dopo l'alleggerimento (la testa resta intatta)
const DETAIL = 512;                   // lato della mappa di dettaglio
const KEEP = ['root', 'pelvis', 'spine_01', 'spine_02', 'spine_03', 'neck_01', 'Head',
  'clavicle_l', 'upperarm_l', 'lowerarm_l', 'hand_l', 'clavicle_r', 'upperarm_r', 'lowerarm_r', 'hand_r',
  'thigh_l', 'calf_l', 'foot_l', 'ball_l', 'thigh_r', 'calf_r', 'foot_r', 'ball_r'];
const CLIPS = { idle: 'Idle_Loop', run: 'Jog_Fwd_Loop', sprint: 'Sprint_Loop', jump: 'Jump_Loop' };

// ---------------------------------------------------------------- lettura glTF
const CT = { 5120: Int8Array, 5121: Uint8Array, 5122: Int16Array, 5123: Uint16Array, 5125: Uint32Array, 5126: Float32Array };
const NC = { SCALAR: 1, VEC2: 2, VEC3: 3, VEC4: 4, MAT4: 16 };
const NORM = { 5120: 127, 5121: 255, 5122: 32767, 5123: 65535 };
function reader(json, bins) {
  return (ai) => {
    const a = json.accessors[ai], bv = json.bufferViews[a.bufferView], T = CT[a.componentType], n = NC[a.type];
    const buf = bins[bv.buffer], es = T.BYTES_PER_ELEMENT, stride = bv.byteStride || es * n;
    const out = new Float32Array(a.count * n), base = buf.byteOffset + (bv.byteOffset || 0) + (a.byteOffset || 0);
    const dv = new DataView(buf.buffer);
    const get = { 5120: 'getInt8', 5121: 'getUint8', 5122: 'getInt16', 5123: 'getUint16', 5125: 'getUint32', 5126: 'getFloat32' }[a.componentType];
    for (let i = 0; i < a.count; i++) for (let k = 0; k < n; k++) {
      let v = dv[get](base + i * stride + k * es, true);
      if (a.normalized) v /= NORM[a.componentType];
      out[i * n + k] = v;
    }
    return out;
  };
}
const ubcGltf = join(ubcDir, 'Base Characters/Godot - UE/Superhero_Male_FullBody.gltf');
const U = JSON.parse(readFileSync(ubcGltf, 'utf8'));
const ubin = [readFileSync(join(ubcDir, 'Base Characters/Godot - UE', U.buffers[0].uri))];
const ur = reader(U, ubin);
const gb = readFileSync(ualFile), jl = gb.readUInt32LE(12), A = JSON.parse(gb.subarray(20, 20 + jl).toString());
const abin = [gb.subarray(20 + jl + 8)];
const ar = reader(A, abin);

// ---------------------------------------------------------------- ossa
const skin = U.skins[0], jn = skin.joints.map(i => U.nodes[i].name);
const parentOf = new Map(); U.nodes.forEach((n, i) => (n.children || []).forEach(c => parentOf.set(c, i)));
const keepIdx = KEEP.map(n => jn.indexOf(n));
if (keepIdx.some(i => i < 0)) throw new Error('ossa mancanti nel modello');
// osso tolto → antenato tenuto più vicino
const remap = jn.map((n, j) => { let node = skin.joints[j]; while (!KEEP.includes(U.nodes[node].name)) node = parentOf.get(node); return KEEP.indexOf(U.nodes[node].name); });
const ibm = ur(skin.inverseBindMatrices);

// ---------------------------------------------------------------- geometria
const meshByName = n => U.meshes[U.nodes.find(x => x.name === n).mesh].primitives[0];
function prim(p, eye) {
  const P = ur(p.attributes.POSITION), N = ur(p.attributes.NORMAL), T = ur(p.attributes.TEXCOORD_0), J = ur(p.attributes.JOINTS_0), W = ur(p.attributes.WEIGHTS_0), I = ur(p.indices);
  const n = P.length / 3, jo = new Uint8Array(n * 4), wo = new Float32Array(n * 4);
  for (let i = 0; i < n; i++) {
    const acc = new Map();
    for (let k = 0; k < 4; k++) { const w = W[i * 4 + k]; if (w > 0) { const j = remap[J[i * 4 + k]]; acc.set(j, (acc.get(j) || 0) + w); } }
    const top = [...acc].sort((a, b) => b[1] - a[1]).slice(0, 4), s = top.reduce((a, b) => a + b[1], 0) || 1;
    top.forEach(([j, w], k) => { jo[i * 4 + k] = j; wo[i * 4 + k] = w / s; });
    // UV: corpo schiacciato in alto, occhi nel loro tassello
    if (eye) { T[i * 2] = EYE_RECT[0] + EYE_RECT[2] * T[i * 2]; T[i * 2 + 1] = EYE_RECT[1] + EYE_RECT[3] * T[i * 2 + 1]; }
    else T[i * 2 + 1] *= BODY_V;
  }
  return { P, N, T, J: jo, W: wo, I: Uint32Array.from(I), n };
}
const body = prim(meshByName('SuperHero_Male'), false), eyes = prim(meshByName('Eyes'), true);
const headJ = KEEP.indexOf('Head');

// ---------------------------------------------------------------- proporzioni da calciatore (il modello è un "supereroe")
// spalle più strette (braccia spostate verso il corpo, ossa comprese), petto un po' più stretto, braccia meno gonfie
const ARM_IN = 0.022;      // m: di quanto le braccia si avvicinano al corpo
const CHEST_K = 0.07;      // restringimento del petto in larghezza (all'altezza delle spalle)
const ARM_DEFLATE = 0.86;  // spessore delle braccia attorno all'osso
const jw = j => { const m = ibm.subarray(j * 16, j * 16 + 16); // posizione dell'osso in posa di legame (inversa rigida)
  return [-(m[0] * m[12] + m[1] * m[13] + m[2] * m[14]), -(m[4] * m[12] + m[5] * m[13] + m[6] * m[14]), -(m[8] * m[12] + m[9] * m[13] + m[10] * m[14])]; };
const JP = KEEP.map(n => jw(jn.indexOf(n)));
const armChain = new Set(['upperarm_l', 'lowerarm_l', 'hand_l', 'upperarm_r', 'lowerarm_r', 'hand_r'].map(n => KEEP.indexOf(n)));
const seg = { [KEEP.indexOf('upperarm_l')]: KEEP.indexOf('lowerarm_l'), [KEEP.indexOf('lowerarm_l')]: KEEP.indexOf('hand_l'), [KEEP.indexOf('upperarm_r')]: KEEP.indexOf('lowerarm_r'), [KEEP.indexOf('lowerarm_r')]: KEEP.indexOf('hand_r') };
const sm = (a, b, x) => { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
const shY = JP[KEEP.indexOf('upperarm_l')][1];
for (let i = 0; i < body.n; i++) {
  let wa = 0, wd = 0;
  for (let k = 0; k < 4; k++) { const j = body.J[i * 4 + k], w = body.W[i * 4 + k]; if (armChain.has(j)) wa += w; if (seg[j] !== undefined) wd += w; }
  const x = body.P[i * 3], y = body.P[i * 3 + 1], z = body.P[i * 3 + 2], sx = Math.sign(x) || 1;
  // braccia meno gonfie: avvicina il punto all'asse dell'osso (braccia lungo x nella posa a T)
  if (wd > 0.5) { const j = [0, 1, 2, 3].map(k => body.J[i * 4 + k]).find(q => seg[q] !== undefined), a = JP[j];
    const f = 1 - (1 - ARM_DEFLATE) * sm(0.5, 1, wd); body.P[i * 3 + 1] = a[1] + (y - a[1]) * f; body.P[i * 3 + 2] = a[2] + (z - a[2]) * f; }
  const chest = CHEST_K * sm(shY - 0.35, shY - 0.05, y) * (1 - wa);
  body.P[i * 3] = x * (1 - chest) - sx * ARM_IN * wa;
}
// ossa delle braccia spostate con la mesh: matrici di legame e traslazione dell'omero rispetto alla clavicola
const ibmFix = new Map(), transFix = new Map();
for (const side of ['l', 'r']) {
  const s = Math.sign(JP[KEEP.indexOf('upperarm_' + side)][0]);
  for (const n of ['upperarm_', 'lowerarm_', 'hand_']) { const j = jn.indexOf(n + side), m = Float32Array.from(ibm.subarray(j * 16, j * 16 + 16)); for (let r = 0; r < 3; r++) m[12 + r] += s * ARM_IN * m[r]; ibmFix.set(j, m); }
  const c = ibm.subarray(jn.indexOf('clavicle_' + side) * 16), d = [-s * ARM_IN, 0, 0];
  // R_clavicola^T · d: le righe della matrice inversa sono le colonne della rotazione del mondo
  const local = [c[0] * d[0] + c[4] * d[1] + c[8] * d[2], c[1] * d[0] + c[5] * d[1] + c[9] * d[2], c[2] * d[0] + c[6] * d[1] + c[10] * d[2]];
  const t = U.nodes.find(x => x.name === 'upperarm_' + side).translation;
  transFix.set('upperarm_' + side, t.map((v, k) => v + local[k]));
}

// alleggerimento: testa (peso sull'osso Head) bloccata, il resto scende a TARGET_TRIS
await MeshoptSimplifier.ready;
const lock = new Uint8Array(body.n);
for (let i = 0; i < body.n; i++) for (let k = 0; k < 4; k++) if (body.J[i * 4 + k] === headJ && body.W[i * 4 + k] > 0.3) lock[i] = 1;
const attr = new Float32Array(body.n * 5);
for (let i = 0; i < body.n; i++) { attr.set(body.N.subarray(i * 3, i * 3 + 3), i * 5); attr[i * 5 + 3] = body.T[i * 2]; attr[i * 5 + 4] = body.T[i * 2 + 1]; }
const [simp] = MeshoptSimplifier.simplifyWithAttributes(body.I, body.P, 3, attr, 5, [0.3, 0.3, 0.3, 1, 1], lock, TARGET_TRIS * 3, 0.02);
console.log('corpo:', body.I.length / 3, '→', simp.length / 3, 'triangoli');

// unione e compattazione dei vertici usati
const used = new Map(), order = [];
const mark = (i, off) => { const k = i + off; if (!used.has(k)) { used.set(k, order.length); order.push(k); } return used.get(k); };
const idx = [];
for (const i of simp) idx.push(mark(i, 0));
for (const i of eyes.I) idx.push(mark(i, body.n));
const nv = order.length, pos = new Float32Array(nv * 3), nrm = new Float32Array(nv * 3), uv = new Float32Array(nv * 2), jnt = new Uint8Array(nv * 4), wgt = new Float32Array(nv * 4);
order.forEach((k, o) => {
  const s = k < body.n ? body : eyes, i = k < body.n ? k : k - body.n;
  pos.set(s.P.subarray(i * 3, i * 3 + 3), o * 3); nrm.set(s.N.subarray(i * 3, i * 3 + 3), o * 3); uv.set(s.T.subarray(i * 2, i * 2 + 2), o * 2);
  jnt.set(s.J.subarray(i * 4, i * 4 + 4), o * 4); wgt.set(s.W.subarray(i * 4, i * 4 + 4), o * 4);
});
const index = nv > 65535 ? Uint32Array.from(idx) : Uint16Array.from(idx);
console.log('vertici', nv, 'triangoli totali', idx.length / 3);

// ---------------------------------------------------------------- PNG (lettura RGB/RGBA 8 bit, scrittura grigio 8 bit)
function readPng(buf) {
  let p = 8, w = 0, h = 0, ct = 0; const idat = [];
  while (p < buf.length) {
    const len = buf.readUInt32BE(p), type = buf.toString('ascii', p + 4, p + 8), d = buf.subarray(p + 8, p + 8 + len);
    if (type === 'IHDR') { w = d.readUInt32BE(0); h = d.readUInt32BE(4); ct = d[9]; if (d[8] !== 8 || d[12]) throw new Error('PNG non gestito'); }
    else if (type === 'IDAT') idat.push(d);
    p += 12 + len;
  }
  const bpp = { 0: 1, 2: 3, 4: 2, 6: 4 }[ct], raw = inflateSync(Buffer.concat(idat)), out = new Uint8Array(w * h * bpp), rl = w * bpp;
  for (let y = 0; y < h; y++) {
    const f = raw[y * (rl + 1)], src = raw.subarray(y * (rl + 1) + 1, (y + 1) * (rl + 1)), o = y * rl;
    for (let x = 0; x < rl; x++) {
      const a = x >= bpp ? out[o + x - bpp] : 0, b = y ? out[o - rl + x] : 0, c = x >= bpp && y ? out[o - rl + x - bpp] : 0;
      let v = src[x];
      if (f === 1) v += a; else if (f === 2) v += b; else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) { const pp = a + b - c, pa = Math.abs(pp - a), pb = Math.abs(pp - b), pc = Math.abs(pp - c); v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }
      out[o + x] = v & 255;
    }
  }
  return { w, h, bpp, data: out };
}
const crcT = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
const crc = b => { let c = -1; for (const x of b) c = crcT[(c ^ x) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; };
function writePngGray(w, h, px) {
  const chunk = (t, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(t), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); };
  const ih = Buffer.alloc(13); ih.writeUInt32BE(w, 0); ih.writeUInt32BE(h, 4); ih[8] = 8; ih[9] = 0;
  // filtro "sub" per riga: comprime meglio i gradienti morbidi
  const raw = Buffer.alloc((w + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w + 1)] = 1; for (let x = 0; x < w; x++) raw[y * (w + 1) + 1 + x] = (px[y * w + x] - (x ? px[y * w + x - 1] : 0)) & 255; }
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ih), chunk('IDAT', deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

// mappa di dettaglio: luminosità / luminosità sfocata (tiene pieghe e lineamenti, toglie le tinte larghe: barba, capelli, slip)
const skinPng = readPng(readFileSync(join(ubcDir, 'Base Characters/Textures/T_Superhero_Male_Ligh.png')));
const SW = skinPng.w, lum = new Float32Array(SW * SW);
for (let i = 0; i < SW * SW; i++) { const o = i * skinPng.bpp; lum[i] = 0.3 * skinPng.data[o] + 0.59 * skinPng.data[o + 1] + 0.11 * skinPng.data[o + 2]; }
const blur = (src, r) => { // sfocatura a scatola separabile, ripetuta 2 volte
  let a = Float32Array.from(src), b = new Float32Array(src.length);
  for (let pass = 0; pass < 2; pass++) for (const horiz of [true, false]) {
    for (let l = 0; l < SW; l++) {
      let s = 0; const at = k => a[horiz ? l * SW + Math.min(SW - 1, Math.max(0, k)) : Math.min(SW - 1, Math.max(0, k)) * SW + l];
      for (let k = -r; k <= r; k++) s += at(k);
      for (let k = 0; k < SW; k++) { b[horiz ? l * SW + k : k * SW + l] = s / (2 * r + 1); s += at(k + r + 1) - at(k - r); }
    }
    [a, b] = [b, a];
  }
  return a;
};
const low = blur(lum, 20);
const det = new Uint8Array(DETAIL * DETAIL).fill(128), BH = Math.round(DETAIL * BODY_V), f = SW / DETAIL;
for (let y = 0; y < BH; y++) for (let x = 0; x < DETAIL; x++) {
  let s = 0, n = 0; const sy = y * SW / BH;
  for (let dy = 0; dy < 4; dy++) for (let dx = 0; dx < 4; dx++) { const i = Math.min(SW - 1, Math.floor(sy + dy * SW / BH / 4)) * SW + Math.floor((x + dx / 4) * f); s += lum[i] / Math.max(8, low[i]); n++; }
  det[y * DETAIL + x] = Math.max(0, Math.min(255, Math.round(128 * s / n)));
}
if (process.env.DETAIL_PNG) writeFileSync(process.env.DETAIL_PNG, writePngGray(DETAIL, DETAIL, det)); // per guardarla

// ---------------------------------------------------------------- clip
const anims = [];
const ualNode = new Map(A.nodes.map((n, i) => [i, n.name]));
const ubPelvis = U.nodes.find(n => n.name === 'pelvis').translation, uaPelvis = A.nodes.find(n => n.name === 'pelvis').translation;
const hipK = Math.hypot(...ubPelvis) / Math.hypot(...uaPelvis);
for (const [name, src] of Object.entries(CLIPS)) {
  const a = A.animations.find(x => x.name === src); if (!a) throw new Error('clip mancante: ' + src);
  const ch = [];
  for (const c of a.channels) {
    const bn = ualNode.get(c.target.node), path = c.target.path;
    if (!KEEP.includes(bn) || bn === 'root') continue;
    if (!(path === 'rotation' || (path === 'translation' && bn === 'pelvis'))) continue;
    const s = a.samplers[c.sampler], t = ar(s.input), v = ar(s.output);
    if (path === 'translation') for (let i = 0; i < v.length; i++) v[i] *= hipK;
    ch.push({ node: KEEP.indexOf(bn), path, t, v, interp: s.interpolation || 'LINEAR' });
  }
  anims.push({ name, ch });
}

// ---------------------------------------------------------------- scrittura GLB
const parts = [], bvs = [], accs = [];
let off = 0;
const addView = (bytes, target) => { const pad = (4 - (off % 4)) % 4; if (pad) { parts.push(Buffer.alloc(pad)); off += pad; } parts.push(Buffer.from(bytes.buffer, bytes.byteOffset, bytes.byteLength)); bvs.push({ buffer: 0, byteOffset: off, byteLength: bytes.byteLength, ...(target ? { target } : {}) }); off += bytes.byteLength; return bvs.length - 1; };
const addAcc = (arr, type, ct, extra = {}, target) => { const n = NC[type]; accs.push({ bufferView: addView(arr, target), componentType: ct, count: arr.length / n, type, ...extra }); return accs.length - 1; };
const mm = (arr, n) => { const mn = Array(n).fill(Infinity), mx = Array(n).fill(-Infinity); for (let i = 0; i < arr.length; i++) { const k = i % n; mn[k] = Math.min(mn[k], arr[i]); mx[k] = Math.max(mx[k], arr[i]); } return { min: mn, max: mx }; };
const aPos = addAcc(pos, 'VEC3', 5126, mm(pos, 3), 34962), aNrm = addAcc(nrm, 'VEC3', 5126, {}, 34962), aUv = addAcc(uv, 'VEC2', 5126, {}, 34962);
const aJ = addAcc(jnt, 'VEC4', 5121, {}, 34962), aW = addAcc(wgt, 'VEC4', 5126, {}, 34962);
const aI = addAcc(index, 'SCALAR', index instanceof Uint32Array ? 5125 : 5123, {}, 34963);
const ibmK = new Float32Array(KEEP.length * 16); keepIdx.forEach((j, k) => ibmK.set(ibmFix.get(j) || ibm.subarray(j * 16, j * 16 + 16), k * 16));
const aIbm = addAcc(ibmK, 'MAT4', 5126);
const detView = addView(det); // grigi grezzi DETAIL×DETAIL: si leggono senza decodifica (veloce all'ingresso in partita)
// nodi: 0 = Armature, 1..K = ossa, K+1 = mesh
const nodes = [{ name: 'Armature', children: [] }];
KEEP.forEach((n) => { const src = U.nodes.find(x => x.name === n), o = { name: n }; for (const k of ['rotation', 'translation', 'scale']) if (src[k]) o[k] = src[k]; if (transFix.has(n)) o.translation = transFix.get(n); nodes.push(o); });
KEEP.forEach((n, k) => {
  const src = U.nodes.findIndex(x => x.name === n), par = parentOf.get(src), pn = U.nodes[par].name;
  if (KEEP.includes(pn)) (nodes[1 + KEEP.indexOf(pn)].children ||= []).push(1 + k); else nodes[0].children.push(1 + k);
});
nodes.push({ name: 'Athlete', mesh: 0, skin: 0 }); nodes[0].children.push(nodes.length - 1);
const animations = anims.map(a => {
  const samplers = [], channels = [];
  for (const c of a.ch) {
    const ti = addAcc(c.t, 'SCALAR', 5126, mm(c.t, 1)), vi = addAcc(c.v, c.path === 'rotation' ? 'VEC4' : 'VEC3', 5126);
    samplers.push({ input: ti, output: vi, interpolation: c.interp });
    channels.push({ sampler: samplers.length - 1, target: { node: 1 + c.node, path: c.path } });
  }
  return { name: a.name, samplers, channels };
});
const json = {
  asset: { version: '2.0', generator: 'tiro-a-giro tools/make-athlete.mjs', copyright: 'Quaternius (CC0 1.0): Universal Base Characters, Universal Animation Library' },
  scene: 0, scenes: [{ nodes: [0] }], nodes,
  meshes: [{ name: 'Athlete', primitives: [{ attributes: { POSITION: aPos, NORMAL: aNrm, TEXCOORD_0: aUv, JOINTS_0: aJ, WEIGHTS_0: aW }, indices: aI, material: 0 }] }],
  skins: [{ joints: KEEP.map((_, k) => 1 + k), inverseBindMatrices: aIbm, skeleton: 1 }],
  materials: [{ name: 'athlete', pbrMetallicRoughness: { metallicFactor: 0 } }],
  animations, accessors: accs, bufferViews: bvs, buffers: [{ byteLength: off }],
  extras: { bodyV: BODY_V, eyeRect: EYE_RECT, detail: { bufferView: detView, size: DETAIL } },
};
const bin = Buffer.concat(parts), binPad = Buffer.concat([bin, Buffer.alloc((4 - bin.length % 4) % 4)]);
let js = Buffer.from(JSON.stringify(json)); js = Buffer.concat([js, Buffer.alloc((4 - js.length % 4) % 4, 0x20)]);
const head = Buffer.alloc(12); head.writeUInt32LE(0x46546c67, 0); head.writeUInt32LE(2, 4); head.writeUInt32LE(12 + 8 + js.length + 8 + binPad.length, 8);
const ch = (len, type) => { const b = Buffer.alloc(8); b.writeUInt32LE(len, 0); b.writeUInt32LE(type, 4); return b; };
writeFileSync(outFile, Buffer.concat([head, ch(js.length, 0x4e4f534a), js, ch(binPad.length, 0x004e4942), binPad]));
console.log('scritto', outFile, (12 + 16 + js.length + binPad.length), 'byte');
