// Cinematica inversa a due ossa (coscia-gamba-piede, braccio-avambraccio-mano) e orientamento delle ossa di three.js.
// La parte di calcolo (twoBone) lavora su array [x, y, z] ed è pura; setBoneQuat/setBonePos mettono un osso in una
// posa data nel riferimento di un oggetto (di solito il gruppo del giocatore) e ricordano la posa del clip in `saved`,
// così il fotogramma dopo (Players3D.pose) la rimette e le correzioni non si sommano.
import * as THREE from 'three';
import { add, sub, mul, dot, cross, norm, len, clamp } from './moves/vec.js';

// A = radice (anca), C = bersaglio (caviglia), a e b = lunghezze delle due ossa, pole = verso cui punta il ginocchio.
// Ritorna il ginocchio, la fine della catena (il bersaglio, o il punto più vicino raggiungibile), la cerniera del
// ginocchio (asse di piegatura: +x per una gamba dritta col ginocchio in avanti) e se il bersaglio era raggiungibile.
export function twoBone(A, C, a, b, pole) {
  const v = sub(C, A), d0 = len(v), u = d0 > 1e-9 ? mul(v, 1 / d0) : [0, -1, 0];
  const d = clamp(d0, Math.abs(a - b) + 1e-4, (a + b) * 0.9999);
  let w = sub(pole, mul(u, dot(pole, u)));
  if (len(w) < 1e-6) w = Math.abs(u[1]) < 0.9 ? cross(u, [0, 1, 0]) : cross(u, [1, 0, 0]);
  w = norm(w);
  const ca = clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1), sa = Math.sqrt(1 - ca * ca);
  return { knee: add(A, add(mul(u, a * ca), mul(w, a * sa))), end: add(A, mul(u, d)), hinge: norm(cross(w, u)), reach: d0 <= (a + b) * 0.9999 + 1e-9 };
}

const _q = new THREE.Quaternion(), _q2 = new THREE.Quaternion(), _q3 = new THREE.Quaternion(), _v = new THREE.Vector3(), _m = new THREE.Matrix4();
const arrQ = (q, a) => q.set(a[0], a[1], a[2], a[3]);

// posizione di un osso nel riferimento di F
export function posIn(F, bone) { bone.getWorldPosition(_v); F.worldToLocal(_v); return [_v.x, _v.y, _v.z]; }

// osso con orientamento qF (array, nel riferimento di F); w < 1 = mescolato con la posa che ha già
export function setBoneQuat(bone, F, qF, saved, w = 1) {
  if (w <= 0) return;
  F.getWorldQuaternion(_q); _q.multiply(arrQ(_q2, qF));           // orientamento voluto nel mondo
  bone.parent.getWorldQuaternion(_q3); _q3.invert().multiply(_q); // ... nel riferimento del padre
  if (saved) saved.push(bone, bone.quaternion.clone());
  if (w < 1) bone.quaternion.slerp(_q3, w); else bone.quaternion.copy(_q3);
  bone.updateMatrixWorld(true);
}
// osso nel punto p (array, nel riferimento di F)
export function setBonePos(bone, F, p, saved, w = 1) {
  if (w <= 0) return;
  _v.set(p[0], p[1], p[2]); F.localToWorld(_v);
  bone.parent.updateWorldMatrix(true, false); _m.copy(bone.parent.matrixWorld).invert(); _v.applyMatrix4(_m);
  if (saved) saved.push(bone, bone.position.clone());
  if (w < 1) bone.position.lerp(_v, w); else bone.position.copy(_v);
  bone.updateMatrixWorld(true);
}
