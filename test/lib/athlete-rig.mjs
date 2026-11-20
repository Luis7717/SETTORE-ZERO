// Figura dell'atleta in Node (come Players3D.makeFig, senza texture) per provare i movimenti calcolati sul modello
// vero: punto del corpo che tocca il pallone (dopo la cinematica inversa sulle ossa three) e distanza della pelle.
import { readFileSync } from 'node:fs';
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { clone } from 'three/addons/utils/SkeletonUtils.js';
import { Athlete3D } from '../../src/athlete3d.js';
import { applyMove, restOf } from '../../src/move-pose.js';
import { posIn } from '../../src/ik.js';
import { footPoint, thighPoint, HEAD_PT } from '../../src/moves/body.js';
import { qMul, qConj, qRot, add, norm, sub } from '../../src/moves/vec.js';

export async function athleteRig() {
  const raw = readFileSync(new URL('../../assets/models/athlete.glb', import.meta.url));
  const gltf = await new Promise((ok, ko) => new GLTFLoader().parse(raw.buffer.slice(raw.byteOffset, raw.byteOffset + raw.length), '', ok, ko));
  const A = new Athlete3D(gltf);
  const g = new THREE.Group(), body = new THREE.Group(), fix = new THREE.Group(); g.add(body); body.add(fix);
  const model = clone(A.scene); fix.add(model);
  fix.rotation.y = A.fixYaw; fix.scale.setScalar(A.fixScale); fix.position.y = A.fixY;
  let mesh = null; const bones = {};
  model.traverse(o => { if (o.isSkinnedMesh) mesh = o; if (o.isBone) bones[o.name] = o; });
  A.aliasBones(bones);
  const mixer = new THREE.AnimationMixer(model), act = {};
  for (const n of ['idle', 'run', 'sprint', 'jump']) if (A.clips[n]) { act[n] = mixer.clipAction(A.clips[n]); act[n].play(); act[n].setEffectiveWeight(n === 'idle' ? 1 : 0); }
  const f = { g, body, fix, model, mesh, mixer, act, bones, saved: [] };
  const st = { vx: 0, vy: 0, state: 'play', cele: 0, kickAnim: 0, pos: 'C', i: 9, x: 0, y: 0 };
  // posa del clip (fermo) e sopra la posa calcolata, come nel menu
  const pose = (fr, t = 0) => {
    A.pose(st, f, 1 / 60, { t, phase: 'menu', flip: 1, yaw: 0, ball: null, scale: 1.25, trick: null });
    applyMove(A, f, fr); f.g.updateMatrixWorld(true);
  };
  return { A, f, pose };
}

const gq = (F, b) => { const q = new THREE.Quaternion(), r = new THREE.Quaternion(); F.getWorldQuaternion(r); b.getWorldQuaternion(q); q.premultiply(r.invert()); return [q.x, q.y, q.z, q.w]; };
// punto del corpo `part` ('l.instep', 'r.sole', 'head', 'l.thigh' ...) e normale, dalle ossa vere
export function effector(A, f, part) {
  const F = f.g, R = restOf(A), B = f.bones;
  if (part === 'head') { const q = gq(F, B.Head), p = posIn(F, B.Head), rel = qMul(q, qConj(R.Head)); return { p: add(p, qRot(rel, HEAD_PT.p)), n: qRot(rel, HEAD_PT.n) }; }
  const [s, k] = part.split('.');
  if (k === 'thigh') { const A0 = posIn(F, B['thigh_' + s]), K = posIn(F, B['calf_' + s]), rel = qMul(gq(F, B['thigh_' + s]), qConj(R['thigh_' + s])); return thighPoint(A0, norm(sub(K, A0)), qRot(rel, [1, 0, 0])); }
  const fq = qMul(gq(F, B['foot_' + s]), qConj(R['foot_' + s]));
  return footPoint(s, posIn(F, B['foot_' + s]), fq, k);
}
// distanza minima dei vertici della pelle dal centro del pallone (e osso del vertice più vicino)
export function skinDist(f, ball) {
  const mesh = f.mesh, geo = mesh.geometry, J = geo.attributes.skinIndex, names = mesh.skeleton.bones.map(b => b.name);
  const inv = f.g.matrixWorld.clone().invert(), v = new THREE.Vector3(); let best = 1e9, who = '';
  for (let i = 0; i < geo.attributes.position.count; i++) {
    mesh.getVertexPosition(i, v); v.applyMatrix4(mesh.matrixWorld).applyMatrix4(inv);
    const d = Math.hypot(v.x - ball[0], v.y - ball[1], v.z - ball[2]); if (d < best) { best = d; who = names[J.getX(i)]; }
  }
  return { d: best, who };
}
