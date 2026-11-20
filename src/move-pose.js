// Mette il modello atleta nella posa di un movimento calcolato (src/moves/*): bacino, busto, collo e testa con la
// rotazione voluta rispetto alla posa di legame, braccia e gambe con la cinematica inversa (src/ik.js), piede orientato.
// Va chiamato dopo Players3D.pose (clip e pose procedurali): ogni osso toccato viene ricordato in f.saved e rimesso
// com'era all'inizio del fotogramma dopo, quindi la correzione si annulla da sola.
import * as THREE from 'three';
import { twoBone, setBoneQuat, setBonePos, posIn } from './ik.js';
import { qAlign, qMul, norm, sub, dist } from './moves/vec.js';
import { REST } from './moves/body.js';

const TRUNK = ['pelvis', 'spine_01', 'spine_02', 'spine_03', 'neck_01', 'Head'];
const dirOf = (a, b) => norm(sub(REST[b], REST[a]));
// direzioni delle ossa a riposo e asse di piegatura (ginocchio: +x; gomito: verso il basso per il braccio sinistro)
const LIMB = {
  leg: s => ({ up: 'thigh_' + s, mid: 'calf_' + s, end: 'foot_' + s, dU: dirOf('thigh_' + s, 'calf_' + s), dL: dirOf('calf_' + s, 'foot_' + s), h: [1, 0, 0] }),
  arm: s => ({ up: 'upperarm_' + s, mid: 'lowerarm_' + s, end: 'hand_' + s, dU: dirOf('upperarm_' + s, 'lowerarm_' + s), dL: dirOf('lowerarm_' + s, 'hand_' + s), h: [0, s === 'l' ? -1 : 1, 0] }),
};
const LIMBS = { l: { leg: LIMB.leg('l'), arm: LIMB.arm('l') }, r: { leg: LIMB.leg('r'), arm: LIMB.arm('r') } };

// orientamento di ogni osso in posa di legame nel riferimento del corpo (correzione di verso del modello compresa)
const rests = new WeakMap();
export function restOf(p3d) {
  if (rests.has(p3d)) return rests.get(p3d);
  const sk = p3d.mesh.skeleton, m = new THREE.Matrix4(), p = new THREE.Vector3(), q = new THREE.Quaternion(), s = new THREE.Vector3(), out = {};
  sk.bones.forEach((b, j) => { m.copy(sk.boneInverses[j]).invert().decompose(p, q, s); q.premultiply(p3d.fixQ); out[b.name] = [q.x, q.y, q.z, q.w]; });
  rests.set(p3d, out);
  return out;
}
// il movimento calcolato vale solo per lo scheletro dell'atleta (il vecchio modello Kenney ha altre ossa)
export const canMove = f => !!(f && f.bones && f.bones.thigh_l && f.bones.foot_r && f.bones.spine_03);

// due ossa verso il bersaglio: radice, metà e fine (L = LIMBS[lato].leg o .arm)
function limb(f, F, R, L, target, pole, fq, sv, w) {
  const B = f.bones, A = posIn(F, B[L.up]), K = posIn(F, B[L.mid]), E = posIn(F, B[L.end]);
  const s = twoBone(A, target, dist(A, K), dist(K, E), pole);
  setBoneQuat(B[L.up], F, qMul(qAlign(L.dU, L.h, norm(sub(s.knee, A)), s.hinge), R[L.up]), sv, w);
  setBoneQuat(B[L.mid], F, qMul(qAlign(L.dL, L.h, norm(sub(s.end, s.knee)), s.hinge), R[L.mid]), sv, w);
  if (fq) setBoneQuat(B[L.end], F, qMul(fq, R[L.end]), sv, w);
  return s;
}

// fr = posa di Move.at(t). opt.w = quanto pesa (0..1, per entrare e uscire dalla corsa del clip);
// opt.legsOnly = solo le gambe, ognuna col suo peso fr.legs[lato].w (in partita: la gamba che tocca il pallone)
export function applyMove(p3d, f, fr, opt = {}) {
  if (!canMove(f)) return;
  const F = f.g, R = restOf(p3d), B = f.bones, sv = f.saved, W = opt.w == null ? 1 : opt.w;
  F.updateMatrixWorld(true);
  if (!opt.legsOnly) {
    if (W <= 0) return;
    setBonePos(B.pelvis, F, fr.pelvis.p, sv, W);
    for (const n of TRUNK) setBoneQuat(B[n], F, qMul(fr.rot[n], R[n]), sv, W);
    for (const s of ['l', 'r']) {
      setBoneQuat(B['clavicle_' + s], F, qMul(fr.rot.spine_03, R['clavicle_' + s]), sv, W);
      const a = fr.arms[s]; if (a) limb(f, F, R, LIMBS[s].arm, a.hand, a.pole, null, sv, W);
    }
  }
  for (const s of ['l', 'r']) {
    const L = fr.legs[s]; if (!L) continue;
    const w = opt.legsOnly ? L.w * W : W; if (w <= 0) continue;
    limb(f, F, R, LIMBS[s].leg, L.ankle, L.pole, L.fq, sv, w);
  }
}
