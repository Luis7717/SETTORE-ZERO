// Misure del corpo del modello atleta in posa di legame (posa a T, braccia lungo x), in unità T = altezza / 8
// (PROPORZIONI.md). Sezioni vere: i triangoli sono tagliati con piani (y costante per il busto, x costante per le braccia).
// Gira in Node (GLTFLoader.parse non ha bisogno del DOM se il modello non ha immagini).
import { readFileSync } from 'node:fs';
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

export function loadAthleteMesh(path = 'assets/models/athlete.glb') {
  const b = readFileSync(path), ab = b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength);
  return new Promise((ok, ko) => new GLTFLoader().parse(ab, '', (g) => { let mesh = null; g.scene.traverse(o => { if (o.isSkinnedMesh && !mesh) mesh = o; }); ok({ gltf: g, mesh }); }, ko));
}

export function bindPositions(mesh) {
  const m = new THREE.Matrix4(), bp = {};
  mesh.skeleton.bones.forEach((b, j) => { m.copy(mesh.skeleton.boneInverses[j]).invert(); bp[b.name] = new THREE.Vector3().setFromMatrixPosition(m); });
  return bp;
}

// tagli: punti d'incrocio dei lati dei triangoli con il piano coord[ax] = v, con l'osso prevalente del lato
function slice(mesh, ax, v, keep) {
  const geo = mesh.geometry, P = geo.attributes.position, I = geo.index.array, J = geo.attributes.skinIndex, W = geo.attributes.skinWeight;
  const names = mesh.skeleton.bones.map(b => b.name), bone = [];
  for (let i = 0; i < P.count; i++) { let best = 0, bw = -1; for (let k = 0; k < 4; k++) { const w = W.getComponent(i, k); if (w > bw) { bw = w; best = J.getComponent(i, k); } } bone[i] = names[best]; }
  const out = [], a = new THREE.Vector3(), b = new THREE.Vector3();
  for (let t = 0; t < I.length; t += 3) for (let e = 0; e < 3; e++) {
    const i = I[t + e], j = I[t + (e + 1) % 3];
    a.fromBufferAttribute(P, i); b.fromBufferAttribute(P, j);
    const da = a.getComponent(ax) - v, db = b.getComponent(ax) - v;
    if ((da < 0) === (db < 0) || da === db) continue;
    if (!keep(bone[i]) || !keep(bone[j])) continue;
    out.push(a.clone().lerp(b, da / (da - db)));
  }
  return out;
}
const ext = (pts, k) => pts.length ? Math.max(...pts.map(p => p[k])) - Math.min(...pts.map(p => p[k])) : 0;

export function measureBody(mesh) {
  const P = mesh.geometry.attributes.position, bp = bindPositions(mesh);
  let y0 = Infinity, y1 = -Infinity; for (let i = 0; i < P.count; i++) { const y = P.getY(i); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
  const T = (y1 - y0) / 8, u = x => Math.round(x / T * 1000) / 1000, Y = h => y0 + h * T;
  const trunk = n => /^(pelvis|spine_0[123]|clavicle_[lr])$/.test(n);
  const sec = h => { const s = slice(mesh, 1, Y(h), trunk); return { w: u(ext(s, 'x')), d: u(ext(s, 'z')) }; };
  // petto: la sezione più larga tra 5,8 e 6,15 T (sotto le ascelle); vita: la più stretta tra 4,8 e 5,4 T
  let chest = { w: 0 }, waist = { w: Infinity };
  for (let h = 5.8; h <= 6.151; h += 0.025) { const s = sec(h); if (s.w > chest.w) chest = { ...s, h: u(Y(h) - y0) }; }
  for (let h = 4.8; h <= 5.401; h += 0.025) { const s = sec(h); if (s.w < waist.w) waist = { ...s, h: u(Y(h) - y0) }; }
  const L = 'l', sh = bp['upperarm_' + L], el = bp['lowerarm_' + L], wr = bp['hand_' + L], sx = Math.sign(sh.x) || 1;
  const armKeep = n => /^(upperarm|lowerarm|hand|clavicle)_l$/.test(n);
  const armSec = x => { const s = slice(mesh, 0, sx * x, armKeep).filter(p => Math.abs(p.y - sh.y) < 0.12 && Math.abs(p.z - sh.z) < 0.12); return { w: ext(s, 'y'), d: ext(s, 'z'), top: s.length ? Math.max(...s.map(p => p.y)) - sh.y : 0 }; };
  const up = sh.distanceTo(el), fo = el.distanceTo(wr);
  let biceps = 0, fore = 0, delt = 0;
  for (let f = 0.3; f <= 0.75; f += 0.05) biceps = Math.max(biceps, armSec(Math.abs(sh.x) + f * up).w);
  for (let f = 0.1; f <= 0.5; f += 0.05) fore = Math.max(fore, armSec(Math.abs(el.x) + f * fo).w);
  for (let f = 0.0; f <= 0.3; f += 0.025) delt = Math.max(delt, armSec(Math.abs(sh.x) + f * up).top);
  let tip = 0; for (let i = 0; i < P.count; i++) tip = Math.max(tip, P.getX(i) * sx);
  const hand = tip - Math.abs(wr.x), shY = sh.y - y0;
  return {
    T, height: y1 - y0,
    shoulders: u(2 * (Math.abs(sh.x) + delt)),               // da deltoide a deltoide con le braccia lungo i fianchi
    chestW: chest.w, chestD: chest.d, chestH: chest.h,
    waistW: waist.w, waistD: waist.d, waistH: waist.h,
    upperArm: u(up), foreArm: u(fo), hand: u(hand),
    shoulderJointY: u(shY), elbowDownY: u(shY - up), fingerDownY: u(shY - up - fo - hand),
    biceps: u(biceps), forearmW: u(fore), shoulderX: u(Math.abs(sh.x)),
    neckBaseY: u(bp.neck_01.y - y0),
  };
}
