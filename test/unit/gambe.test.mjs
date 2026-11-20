// Bacino, gambe e piedi (src/body/gambe.js) sul modello vero assets/models/athlete.glb: misure di PROPORZIONI.md,
// posa di legame intatta (le ossa spostate non deformano la figura ferma), vita e busto non toccati.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { loadAthlete3D } from '../../src/athlete3d.js';
import { measureLegs, LEG } from '../../src/body/gambe.js';
import { deformBusto } from '../../src/body/busto.js';
import { shapeHead } from '../../src/body/testa.js';

const buf = (() => { const b = readFileSync(new URL('../../assets/models/athlete.glb', import.meta.url)); return b.buffer.slice(b.byteOffset, b.byteOffset + b.length); })();
const m = await loadAthlete3D(buf);
const raw = await new Promise((ok, ko) => new GLTFLoader().parse(buf.slice(0), '', ok, ko));
let rawMesh = null; raw.scene.traverse(o => { if (o.isSkinnedMesh && !rawMesh) rawMesh = o; });
// riferimento: modello originale con testa e busto applicati (sono di altre parti: qui si controlla che le gambe non tocchino altro)
shapeHead(rawMesh); deformBusto(rawMesh); // stesso ordine di src/athlete3d.js
const G = m.legs, T = G.T, gr = G.ground, H = y => (y - gr) / T;
const I = m.mesh.geometry.index.array;
// geometria come in partita (con il gonfiaggio dei pantaloncini di athlete3d.js), solo il corpo
const body = (() => { const g = m.bodyGeo(0, 0), n = m.mesh.geometry.attributes.position.count; return g.attributes.position.array.slice(0, n * 3); })();
const near = (a, b, tol, what) => assert.ok(Math.abs(a - b) <= tol, `${what}: ${a.toFixed(3)} invece di ${b} (±${tol})`);

test('ginocchio, caviglia e cavallo alle altezze di PROPORZIONI.md', () => {
  near(H(m.bp.calf_l.y), LEG.knee, 0.01, 'ginocchio sinistro'); near(H(m.bp.calf_r.y), LEG.knee, 0.01, 'ginocchio destro');
  near(H(m.bp.foot_l.y), LEG.ankle, 0.01, 'caviglia'); near(H(G.crotch), 4, 0.05, 'cavallo');
  near(H(m.L.kneeY), LEG.knee, 0.01, 'L.kneeY'); near(H(m.L.ankleY), LEG.ankle, 0.01, 'L.ankleY');
});

test('larghezze: coscia + pantaloncini, ginocchio, polpaccio, caviglia', () => {
  for (const s of [1, -1]) {
    const hs = []; for (let h = 0.5; h <= 3.85; h += 0.05) hs.push(h);
    const w = measureLegs(body, I, gr, T, s, hs).map(o => o.w), at = h => w[Math.round((h - 0.5) / 0.05)];
    near(at(3.4), LEG.thighW + LEG.shortsFlare, 0.03, 'pantaloncini sulla coscia (coscia 0,72 T + 0,1 T)');
    const calf = Math.max(...w.filter((_, k) => hs[k] > 1 && hs[k] < 1.7)), calfH = hs[w.indexOf(calf)];
    near(calf, LEG.calfW, 0.02, 'polpaccio'); near(calfH, LEG.calfH, 0.1, 'altezza del polpaccio');
    near(at(LEG.knee), 0.42, 0.03, 'ginocchio');
    assert.ok(at(0.6) < 0.3, 'caviglia sottile');
    assert.ok(at(3.4) > calf * 1.4, 'la coscia è il punto più largo della gamba');
  }
});

test('scarpa lunga 1,15 T e larga 0,42 T', () => {
  for (const s of [1, -1]) {
    let za = Infinity, zb = -Infinity, xa = Infinity, xb = -Infinity;
    for (let i = 0; i < body.length / 3; i++) {
      const x = body[i * 3], y = body[i * 3 + 1], z = body[i * 3 + 2]; if (x * s <= 0 || H(y) > 0.3) continue;
      za = Math.min(za, z); zb = Math.max(zb, z); if (H(y) < 0.2) { xa = Math.min(xa, x); xb = Math.max(xb, x); }
    }
    near((zb - za) / T, LEG.footL, 0.02, 'lunghezza del piede'); near((xb - xa) / T, LEG.footW, 0.02, 'larghezza del piede');
  }
});

test('posa di legame intatta: la figura ferma coincide con la geometria (ossa spostate senza deformare)', () => {
  m.scene.updateMatrixWorld(true); m.mesh.skeleton.update();
  const P = m.mesh.geometry.attributes.position, v = new THREE.Vector3(); let worst = 0;
  for (let i = 0; i < P.count; i++) { m.mesh.getVertexPosition(i, v); worst = Math.max(worst, v.distanceTo(new THREE.Vector3().fromBufferAttribute(P, i))); }
  assert.ok(worst < 1e-4, `scarto massimo ${worst}`);
});

test('vita, busto, braccia e testa non toccati; la mesh resta chiusa e senza numeri sbagliati', () => {
  const P = m.mesh.geometry.attributes.position, R = rawMesh.geometry.attributes.position;
  assert.equal(P.count, R.count); assert.equal(m.mesh.geometry.index.count, rawMesh.geometry.index.count); // nessun triangolo in più
  let moved = 0;
  for (let i = 0; i < P.count; i++) {
    for (let k = 0; k < 3; k++) assert.ok(Number.isFinite(P.getComponent(i, k)));
    if (H(R.getY(i)) > 4.3 && Math.hypot(P.getX(i) - R.getX(i), P.getY(i) - R.getY(i), P.getZ(i) - R.getZ(i)) > 1e-6) moved++;
  }
  assert.equal(moved, 0, 'vertici spostati sopra 4,3 T');
  // ossa fuori dalla zona: stesse matrici di legame del modello originale
  const inv = rawMesh.skeleton.boneInverses;
  m.mesh.skeleton.bones.forEach((b, j) => { if (!/^(calf|foot|ball)_/.test(b.name)) assert.ok(m.mesh.skeleton.boneInverses[j].equals(inv[j]), b.name); });
});

// Macchia color pelle sui pantaloncini (davanti alla coscia): era la punta delle dita che attraversava la stoffa,
// perché nella posa "fermo" (partita ed editor) le braccia si chiudevano verso le cosce. Si posa una figura vera
// lungo tutto il clip e si controlla che nessun vertice della mano stia dentro la coscia (pantaloncini gonfiati compresi).
const STILL = { vx: 0, vy: 0, state: 'play', cele: 0, kickAnim: 0, pos: 'A', i: 0, x: 0, y: 0 };
function handInThigh(fig, steps = 48) {
  const P = fig.mesh.geometry.attributes.position, v = new THREE.Vector3(), dur = m.clips.idle.duration;
  const hand = [], thigh = [];
  for (let i = 0; i < P.count; i++) { const bn = m.boneOf[i]; if (/^hand_[lr]$/.test(bn)) hand.push(i); else if (/^thigh_[lr]$/.test(bn)) thigh.push(i); }
  let worst = -Infinity;
  for (let k = 0; k < steps; k++) {
    m.pose(STILL, fig, k ? dur / steps : 0, { t: k / 30, phase: 'menu', flip: 1, yaw: 0, ball: null, scale: 1.25, trick: null });
    fig.g.updateMatrixWorld(true); fig.mesh.skeleton.update();
    const at = idx => idx.map(i => { fig.mesh.getVertexPosition(i, v); return [m.boneOf[i].slice(-1), v.x, v.y, v.z]; });
    const th = at(thigh), hd = at(hand);
    for (const h of hd) {
      // fetta orizzontale della coscia dello stesso lato all'altezza del vertice: raggio nella direzione della mano
      const sl = th.filter(q => q[0] === h[0] && Math.abs(q[2] - h[2]) < 0.04 * T); if (sl.length < 6) continue;
      const cx = sl.reduce((a, q) => a + q[1], 0) / sl.length, cz = sl.reduce((a, q) => a + q[3], 0) / sl.length;
      const ang = Math.atan2(h[3] - cz, h[1] - cx), dh = Math.hypot(h[3] - cz, h[1] - cx);
      let r = 0; for (const q of sl) { let d = Math.abs(Math.atan2(q[3] - cz, q[1] - cx) - ang); d = Math.min(d, 2 * Math.PI - d); if (d < 0.3) r = Math.max(r, Math.hypot(q[3] - cz, q[1] - cx)); }
      if (r) worst = Math.max(worst, (r - dh) / T); // > 0: vertice della mano dentro la coscia
    }
  }
  return worst;
}

test('posa "fermo": le dita non attraversano i pantaloncini (niente macchia color pelle sulla coscia)', () => {
  const paint = m.paint; m.paint = () => ({ width: 1, height: 1 }); // la texture qui non serve (niente canvas in Node)
  const fig = m.make({ shirt: 0xc8102e, shorts: 0xffffff, socks: 0xc8102e, style: {} }, 0, {});
  m.paint = paint;
  const worst = handInThigh(fig);
  assert.ok(worst < -0.02, `la mano entra nella coscia di ${worst.toFixed(3)} T (serve almeno 0,02 T di aria)`);
});
