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
