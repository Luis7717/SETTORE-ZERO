// Busto, spalle, braccia e mani (src/body/busto.js): misure del modello atleta rispetto a PROPORZIONI.md,
// giunzioni ferme (collo, pantaloncini), ossa delle braccia coerenti con la mesh.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import { loadAthleteMesh, measureBody } from '../lib/body-measure.mjs';
import { deformBusto, TARGET } from '../../src/body/busto.js';

const near = (got, want, tol, what) => assert.ok(Math.abs(got - want) <= tol, `${what}: ${got} invece di ${want} ± ${tol}`);

test('proporzioni di busto e braccia vicine a PROPORZIONI.md', async () => {
  const { mesh } = await loadAthleteMesh();
  deformBusto(mesh);
  const m = measureBody(mesh);
  near(m.shoulders, TARGET.shoulders, 0.08, 'spalle');
  near(m.chestW, TARGET.chestW, 0.06, 'petto largo');
  near(m.chestD, TARGET.chestD, 0.06, 'petto profondo');
  near(m.waistW, TARGET.waistW, 0.05, 'vita larga');
  near(m.waistD, TARGET.waistD, 0.05, 'vita profonda');
  near(m.upperArm, TARGET.upperArm, 0.02, 'omero');
  near(m.foreArm, TARGET.foreArm, 0.02, 'avambraccio');
  near(m.biceps, TARGET.biceps, 0.04, 'bicipite');
  near(m.forearmW, TARGET.forearmW, 0.04, 'avambraccio largo');
  near(m.elbowDownY, 5.15, 0.1, 'gomito (vita)');
  near(m.fingerDownY, 3.3, 0.12, 'punta delle dita a braccia giù');
  assert.ok(m.hand >= 0.65 && m.hand <= 0.78, `mano ${m.hand}`);
  near(m.height / m.T, 8, 1e-6, 'altezza invariata');
});

test('giunzioni ferme: collo, testa, pantaloncini e gambe non si muovono', async () => {
  const { mesh } = await loadAthleteMesh(), P0 = Float32Array.from(mesh.geometry.attributes.position.array);
  const geo = mesh.geometry, J = geo.attributes.skinIndex, W = geo.attributes.skinWeight, names = mesh.skeleton.bones.map(b => b.name);
  let y0 = Infinity; for (let i = 1; i < P0.length; i += 3) y0 = Math.min(y0, P0[i]);
  const { T } = deformBusto(mesh), P = geo.attributes.position;
  let moved = 0, n = 0, nan = 0;
  for (let i = 0; i < P.count; i++) {
    for (let k = 0; k < 3; k++) if (!Number.isFinite(P.getComponent(i, k))) nan++;
    let fixed = (P0[i * 3 + 1] - y0) / T < 4.46;                      // sotto l'orlo della maglia (4,47 T)
    for (let k = 0; k < 4; k++) if (/^(neck_01|Head|thigh_[lr]|calf_[lr]|foot_[lr]|ball_[lr])$/.test(names[J.getComponent(i, k)]) && W.getComponent(i, k) > 0.5) fixed = true;
    if (!fixed) continue;
    n++; if (Math.hypot(P.getX(i) - P0[i * 3], P.getY(i) - P0[i * 3 + 1], P.getZ(i) - P0[i * 3 + 2]) > 1e-4) moved++;
  }
  assert.equal(nan, 0);
  assert.ok(n > 1000);
  assert.equal(moved, 0, `${moved} vertici di giunzione spostati`);
});

test('ossa delle braccia spostate con la mesh: posa di legame ancora identità', async () => {
  const { gltf, mesh } = await loadAthleteMesh();
  deformBusto(mesh);
  gltf.scene.updateMatrixWorld(true);
  const m = new THREE.Matrix4();
  mesh.skeleton.bones.forEach((b, j) => {
    m.multiplyMatrices(b.matrixWorld, mesh.skeleton.boneInverses[j]);
    const e = m.elements, id = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1];
    assert.ok(e.every((v, k) => Math.abs(v - id[k]) < 1e-4), `osso ${b.name} non coerente`);
  });
});

// posa da fermo come in partita: Athlete3D vero (busto, gambe, testa), clip "fermo" + correzioni di flush()
test('posa da fermo: mani lungo i fianchi, fuori da cosce e bacino, non dietro la schiena', async () => {
  const { readFileSync } = await import('node:fs');
  const { GLTFLoader } = await import('three/addons/loaders/GLTFLoader.js');
  const { clone } = await import('three/addons/utils/SkeletonUtils.js');
  const { Athlete3D } = await import('../../src/athlete3d.js');
  const raw = readFileSync(new URL('../../assets/models/athlete.glb', import.meta.url));
  const gltf = await new Promise((ok, ko) => new GLTFLoader().parse(raw.buffer.slice(raw.byteOffset, raw.byteOffset + raw.length), '', ok, ko));
  const A = new Athlete3D(gltf);
  // figura come make() (senza texture): gruppo, corpo, correzione di verso e scala, mixer con le clip
  const g = new THREE.Group(), body = new THREE.Group(), fix = new THREE.Group(); g.add(body); body.add(fix);
  const model = clone(A.scene); fix.add(model);
  fix.rotation.y = A.fixYaw; fix.scale.setScalar(A.fixScale); fix.position.y = A.fixY;
  let mesh = null; const bones = {};
  model.traverse(o => { if (o.isSkinnedMesh) mesh = o; if (o.isBone) bones[o.name] = o; });
  A.aliasBones(bones);
  const mixer = new THREE.AnimationMixer(model), act = {};
  for (const n of ['idle', 'run', 'sprint', 'jump']) if (A.clips[n]) { act[n] = mixer.clipAction(A.clips[n]); act[n].play(); act[n].setEffectiveWeight(n === 'idle' ? 1 : 0); }
  const f = { g, body, fix, model, mesh, mixer, act, bones, saved: [] };
  const p = { vx: 0, vy: 0, state: 'play', cele: 0, kickAnim: 0, pos: 'C', i: 9, x: 0, y: 0 };
  for (let i = 0; i < 30; i++) A.pose(p, f, 1 / 60, { t: i / 60, phase: 'play', flip: 1, yaw: 0, ball: null, scale: 1.25, trick: null });
  g.updateMatrixWorld(true);
  // vertici a skinning applicato nel riferimento del corpo (x di lato, y su, z avanti), per osso prevalente
  const inv = body.matrixWorld.clone().invert(), geo = mesh.geometry, J = geo.attributes.skinIndex, W = geo.attributes.skinWeight;
  const names = mesh.skeleton.bones.map(b => b.name), by = {}, v = new THREE.Vector3();
  for (let i = 0; i < geo.attributes.position.count; i++) {
    if (W.getX(i) < 0.5) continue;
    mesh.getVertexPosition(i, v); v.applyMatrix4(mesh.matrixWorld).applyMatrix4(inv);
    (by[names[J.getX(i)]] = by[names[J.getX(i)]] || []).push(v.clone());
  }
  const T = A.modelH / 8, trunk = ['pelvis', 'spine_01', 'spine_02', 'thigh_l', 'thigh_r'].flatMap(n => by[n] || []);
  const torsoZ = [...by.pelvis, ...by.spine_02].map(q => q.z), backZ = Math.min(...torsoZ), midZ = (backZ + Math.max(...torsoZ)) / 2;
  for (const s of ['l', 'r']) {
    const H = by['hand_' + s];
    let inside = 0;
    for (const h of H) {
      const near = trunk.filter(b => Math.abs(b.y - h.y) < 0.02 && Math.abs(b.z - h.z) < 0.04 && Math.sign(b.x) === Math.sign(h.x));
      if (near.length && Math.abs(h.x) < Math.max(...near.map(b => Math.abs(b.x))) + 0.01) inside++;
    }
    assert.equal(inside, 0, `mano ${s}: ${inside} vertici dentro (o incollati a) cosce e bacino`);
    const cz = H.reduce((a, q) => a + q.z, 0) / H.length, tip = Math.min(...H.map(q => q.y)) / T;
    assert.ok(cz > midZ, `mano ${s} dietro il busto (z ${cz.toFixed(3)}, centro del busto ${midZ.toFixed(3)})`);
    assert.ok(Math.min(...H.map(q => q.z)) > backZ, `mano ${s} oltre il piano della schiena`);
    near(tip, 3.3, 0.18, `punta delle dita della mano ${s} (T da terra)`);
  }
});
