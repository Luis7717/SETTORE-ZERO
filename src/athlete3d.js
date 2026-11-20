// Giocatori 3D con proporzioni realistiche: modello "athlete" (Quaternius, Universal Base Characters + Universal
// Animation Library, CC0), preparato da tools/make-athlete.mjs. Stessa interfaccia di src/players3d.js (make, pose,
// dispose) e stesse pose procedurali: le ossa del nuovo scheletro prendono anche i nomi di quello Kenney.
//
// La texture non segue rettangoli fissi come nel modello Kenney: per ogni texel si conosce il punto del corpo in posa
// a T (rasterizzando le UV una volta per modello) e lo si colora in base alla posizione: maglia fino a dove arrivano
// le maniche, pantaloncini fino a metà coscia, calzettoni, scarpe, colletto, motivi della maglia come righe "vere"
// sul corpo. Numero e cognome (schiena), stemma (petto), sopracciglia e barba (viso) sono disegnati su piccoli canvas
// e proiettati sul corpo. Una mappa di dettaglio in grigi (nel file del modello) aggiunge pieghe e lineamenti.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { Players3D, loadPlayers3D, hex, rgb, shade, lumH, FACE, SOLE, cpuCanvas } from './players3d.js';
import { SKINS, HAIR_COLORS, EYE_COLORS, BOOTS, normalizeKitStyle } from './looks.js';
import { drawCrest } from './crest.js';
import { makeRadialBase, scalpAt, paintHairTex } from './hair3d.js';

const MODEL_H = 1.84;                 // altezza prima di SCALE (come il vecchio modello: la scala del gioco resta quella)
const HAIR_RECT = [16, 916, 200, 92]; // zona della tinta dei capelli (coordinate su 1024, fascia libera in basso)
const HAIR_TILT = 10 * Math.PI / 180;                 // inclinazione all'indietro del riferimento dei capelli (rad)
const HAIR_DROP = -0.35;              // centro del riferimento spostato in basso (in raggi; negativo = più in alto)
const EYE_PX = [896, 896, 128, 128];  // tassello degli occhi (deve coincidere con EYE_RECT di tools/make-athlete.mjs)
const DETAIL_K = { skin: 0.95, cloth: 0.4 }; // quanto si vede la mappa di dettaglio su pelle e su stoffa
const SPRINT_FROM = 6.5, SPRINT_FULL = 8.5;  // m/s: da qui il clip di scatto prende il posto della corsa
const IDLE_FIX = { legs: 0.12, arms: 0.28 }; // rad: quanto si chiudono gambe e braccia nel clip "fermo"
const AA = 0.005;                     // m: larghezza dei bordi morbidi (righe, scollo)
const SHORTS_LOOSE = 0.008;           // m: quanto sono larghi i pantaloncini
const NECK_R = 0.072;                 // m: raggio dello scollo attorno al collo
const SIDE_NX = 0.93;                 // banda laterale dei pantaloncini: solo dove il fianco guarda proprio di lato
const RUN_REF = 4.2;                  // m/s: velocità a cui la corsa del nuovo clip gira a velocità 1
const SPRINT_REF = 8.0;
// alias: nomi Kenney (usati dalle pose) → ossa del nuovo scheletro. Il lato è verificato a schermo (pose del calcio).
const ALIAS = {
  Hips: 'pelvis', Spine: 'spine_02', Chest: 'spine_03', Neck: 'neck_01', Head: 'Head',
  LeftShoulder: 'clavicle_l', LeftArm: 'upperarm_l', LeftForeArm: 'lowerarm_l', LeftHand: 'hand_l',
  RightShoulder: 'clavicle_r', RightArm: 'upperarm_r', RightForeArm: 'lowerarm_r', RightHand: 'hand_r',
  LeftUpLeg: 'thigh_l', LeftLeg: 'calf_l', LeftFoot: 'foot_l', LeftToes: 'ball_l',
  RightUpLeg: 'thigh_r', RightLeg: 'calf_r', RightFoot: 'foot_r', RightToes: 'ball_r',
};
// classi dei texel
const C_NONE = 0, C_TORSO = 1, C_ARM = 2, C_HAND = 3, C_LEG = 4, C_HEAD = 5, C_FOOT = 6, C_NECK = 7;
const BONE_CLASS = { pelvis: C_TORSO, spine_01: C_TORSO, spine_02: C_TORSO, spine_03: C_TORSO, clavicle_l: C_TORSO, clavicle_r: C_TORSO,
  neck_01: C_NECK, Head: C_HEAD, upperarm_l: C_ARM, upperarm_r: C_ARM, lowerarm_l: C_ARM, lowerarm_r: C_ARM, hand_l: C_HAND, hand_r: C_HAND,
  thigh_l: C_LEG, thigh_r: C_LEG, calf_l: C_LEG, calf_r: C_LEG, foot_l: C_FOOT, foot_r: C_FOOT, ball_l: C_FOOT, ball_r: C_FOOT };
const smooth = (a, b, x) => { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
const frac = x => x - Math.floor(x);

export class Athlete3D extends Players3D {
  setup() {
    this.modelH = MODEL_H; this.hairRect = HAIR_RECT; this.fitRe = /^(spine_0[123]|clavicle_[lr]|upperarm_[lr])$/;
    this.maps = new Map();
  }

  aliasBones(bones) { for (const k in ALIAS) if (bones[ALIAS[k]]) bones[k] = bones[ALIAS[k]]; }

  // scala e verso (come nel modello Kenney, con i nomi delle ossa nuovi)
  measure() {
    const s = this.scene; s.updateMatrixWorld(true);
    const bones = {}; s.traverse(o => { if (o.isBone) bones[o.name] = o; });
    const v = new THREE.Vector3(), w = new THREE.Vector3();
    let yaw = 0;
    if (bones.foot_r && bones.ball_r) { bones.foot_r.getWorldPosition(v); bones.ball_r.getWorldPosition(w); yaw = Math.atan2(w.x - v.x, w.z - v.z); }
    const box = new THREE.Box3().setFromObject(s, true), h = box.max.y - box.min.y || 1;
    this.fixScale = this.modelH / h; this.fixYaw = -yaw; this.fixY = -box.min.y * this.fixScale;
    this.fixQ = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), this.fixYaw);
    // le braccia aperte della posa a T allargano la scatola: il raggio per il taglio fuori schermo lo dà l'altezza
    this.radius = this.modelH * 0.75;
  }

  // testa, punti di riferimento del corpo in posa a T, occhi (tutto nello spazio della mesh)
  headFrame() {
    const geo = this.mesh.geometry, P = geo.attributes.position, UV = geo.attributes.uv, J = geo.attributes.skinIndex, W = geo.attributes.skinWeight;
    const names = this.mesh.skeleton.bones.map(b => b.name), H = names.indexOf('Head');
    this.headJoint = H; this.boneOf = []; this.boneIdx = new Uint8Array(P.count);
    const v = new THREE.Vector3(), c = new THREE.Vector3(), eyeL = new THREE.Vector3(), eyeR = new THREE.Vector3(), pts = [];
    let nh = 0, nl = 0, nr = 0;
    const eu = EYE_PX[0] / 1024, ev = EYE_PX[1] / 1024;
    this.isEye = new Uint8Array(P.count);
    for (let i = 0; i < P.count; i++) {
      let best = 0, bw = -1, hw = 0;
      for (let k = 0; k < 4; k++) { const j = J.getComponent(i, k), w = W.getComponent(i, k); if (w > bw) { bw = w; best = j; } if (j === H) hw += w; }
      this.boneOf[i] = names[best]; this.boneIdx[i] = best;
      v.fromBufferAttribute(P, i);
      if (UV.getX(i) >= eu && UV.getY(i) >= ev) { this.isEye[i] = 1; if (v.x > 0) { eyeL.add(v); nl++; } else { eyeR.add(v); nr++; } continue; }
      if (hw > 0.5) { c.add(v); nh++; pts.push(v.clone()); }
    }
    c.divideScalar(nh || 1); eyeL.divideScalar(nl || 1); eyeR.divideScalar(nr || 1);
    // posizioni delle ossa in posa di legame (inversa della matrice di legame)
    const m = new THREE.Matrix4(); this.bp = {};
    this.mesh.skeleton.bones.forEach((b, j) => { m.copy(this.mesh.skeleton.boneInverses[j]).invert(); this.bp[b.name] = new THREE.Vector3().setFromMatrixPosition(m); });
    const bp = this.bp, eyes = eyeL.clone().add(eyeR).multiplyScalar(0.5);
    const fwd0 = eyes.clone().sub(c); fwd0.y = 0; fwd0.normalize();
    const right = new THREE.Vector3().crossVectors(new THREE.Vector3(0, 1, 0), fwd0).normalize();
    // riferimento dei capelli: centro all'altezza delle sopracciglia, così le attaccature dei tagli
    // (pensate per la fronte alta del modello Kenney) cadono sulla fronte e sulla nuca giuste di una testa vera
    const up = new THREE.Vector3(0, 1, 0).applyAxisAngle(right, -HAIR_TILT), fwd = new THREE.Vector3().crossVectors(right, up).normalize();
    const R0m = pts.map(p => p.distanceTo(c)).sort((a, b) => a - b)[pts.length >> 1] || 0.1;
    const hc = c.clone().addScaledVector(up, -HAIR_DROP * R0m).addScaledVector(fwd, -0.006);
    const dist = pts.map(p => p.distanceTo(hc)).sort((a, b) => a - b);
    this.head = { c: hc, up, fwd, right, R: dist[dist.length >> 1] || 0.1 };
    // base dei capelli: testa tonda, senza orecchie (sporgono di lato e gonfierebbero tutti i tagli)
    const R0 = this.head.R, earFree = pts.filter(p => { const d = p.clone().sub(hc), lx = Math.abs(d.dot(right)) / R0, ly = d.dot(up) / R0, lz = d.dot(fwd) / R0; return !(lx > 0.72 && ly < 0.3 && ly > -0.75 && lz < 0.35 && lz > -0.45) && !(ly < -0.1 && lz > 0.2) && !(ly < -0.3 && lz > -0.25); });
    this.hairBase = makeRadialBase({ ...this.head, pts: earFree });
    this.headY = hc.y * this.fixScale + this.fixY; // altezza del centro della testa sul campo (prima di SCALE): la usa l'editor
    this.eyeL = eyeL; this.eyeR = eyeR; this.leftSign = Math.sign(bp.upperarm_l.x) || 1;
    // punti di riferimento (y verso l'alto, braccia lungo x)
    const chinY = pts.reduce((a, p) => (p.z > c.z ? Math.min(a, p.y) : a), Infinity);
    this.L = {
      neckY: bp.neck_01.y, headY: bp.Head.y, hipY: (bp.thigh_l.y + bp.thigh_r.y) / 2, kneeY: (bp.calf_l.y + bp.calf_r.y) / 2,
      ankleY: (bp.foot_l.y + bp.foot_r.y) / 2, neckZ: bp.neck_01.z, shX: Math.abs(bp.upperarm_l.x), elX: Math.abs(bp.lowerarm_l.x), wrX: Math.abs(bp.hand_l.x),
      eyeY: eyes.y, eyeDX: Math.abs(eyeL.x - eyeR.x) / 2, chinY, faceZ: eyes.z, spine3Y: bp.spine_03.y,
    };
  }

  // pantaloncini un po' larghi: fianchi e cosce gonfiati lungo la normale fin sotto l'orlo (una volta per geometria)
  bodyGeo(hair, fit) {
    const g = super.bodyGeo(hair, fit);
    this.loose = this.loose || new WeakSet();
    if (this.loose.has(g)) return g;
    this.loose.add(g);
    const P = g.attributes.position.array, N = this.mesh.geometry.attributes.normal, LM = this.L, nb = N.count;
    const lo = LM.hipY - 0.5 * (LM.hipY - LM.ankleY), hi = LM.hipY + 0.07;
    for (let i = 0; i < nb; i++) {
      if (!/^(pelvis|thigh_[lr])$/.test(this.boneOf[i])) continue;
      const y = P[i * 3 + 1], k = SHORTS_LOOSE * smooth(lo - 0.02, lo + 0.06, y) * smooth(hi + 0.03, hi - 0.03, y);
      if (k > 0) for (let c = 0; c < 3; c++) P[i * 3 + c] += N.getComponent(i, c) * k;
    }
    g.attributes.position.needsUpdate = true;
    return g;
  }

  // ---------------------------------------------------------------- mappa texel → punto del corpo (una volta per lato della texture)
  texMap(S) {
    if (this.maps.has(S)) return this.maps.get(S);
    const geo = this.mesh.geometry, I = geo.index.array;
    // copie piatte degli attributi (gli accessi getX/getY nei cicli per texel sono lenti)
    const flat = (at, n) => { const o = new Float32Array(at.count * n); for (let i = 0; i < at.count; i++) for (let k = 0; k < n; k++) o[i * n + k] = at.getComponent(i, k); return o; };
    const PA = flat(geo.attributes.position, 3), NA = flat(geo.attributes.normal, 3), UA = flat(geo.attributes.uv, 2);
    const pos = new Float32Array(S * S * 3), nrm = new Float32Array(S * S * 3), cls = new Uint8Array(S * S);
    const bones = this.mesh.skeleton.bones.map(b => BONE_CLASS[b.name] || C_TORSO);
    const bodyMax = Math.floor(S * EYE_PX[1] / 1024);
    for (let t = 0; t < I.length; t += 3) {
      const a = I[t], b = I[t + 1], d = I[t + 2];
      if (this.isEye[a]) continue;
      const ax = UA[a * 2] * S, ay = UA[a * 2 + 1] * S, bx = UA[b * 2] * S, by = UA[b * 2 + 1] * S, dx = UA[d * 2] * S, dy = UA[d * 2 + 1] * S;
      const det = (by - dy) * (ax - dx) + (dx - bx) * (ay - dy); if (Math.abs(det) < 1e-9) continue;
      const x0 = Math.max(0, Math.floor(Math.min(ax, bx, dx) - 1)), x1 = Math.min(S - 1, Math.ceil(Math.max(ax, bx, dx) + 1));
      const y0 = Math.max(0, Math.floor(Math.min(ay, by, dy) - 1)), y1 = Math.min(bodyMax - 1, Math.ceil(Math.max(ay, by, dy) + 1));
      for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
        const px = x + 0.5, py = y + 0.5;
        const l1 = ((by - dy) * (px - dx) + (dx - bx) * (py - dy)) / det, l2 = ((dy - ay) * (px - dx) + (ax - dx) * (py - dy)) / det, l3 = 1 - l1 - l2;
        // dentro il triangolo, o appena fuori (mezzo texel) per non lasciare buchi sulle cuciture
        const e = -0.6 / Math.max(1, Math.sqrt(Math.abs(det)));
        if (l1 < e || l2 < e || l3 < e) continue;
        const i = y * S + x; if (cls[i] && (l1 < 0 || l2 < 0 || l3 < 0)) continue;
        for (let k = 0; k < 3; k++) {
          pos[i * 3 + k] = PA[a * 3 + k] * l1 + PA[b * 3 + k] * l2 + PA[d * 3 + k] * l3;
          nrm[i * 3 + k] = NA[a * 3 + k] * l1 + NA[b * 3 + k] * l2 + NA[d * 3 + k] * l3;
        }
        const top = l1 >= l2 && l1 >= l3 ? a : l2 >= l3 ? b : d;
        cls[i] = bones[this.boneIdx[top]];
      }
    }
    const map = { S, pos, nrm, cls };
    this.maps.set(S, map);
    return map;
  }

  // mappa di dettaglio (grigi grezzi nel file del modello, 128 = neutro) portata al lato S della texture
  detailAt(S) {
    const key = 'd' + S; if (this.maps.has(key)) return this.maps.get(key);
    const src = this.detail; let out = null;
    if (src && src.data.length >= src.size * src.size) {
      const n = src.size; out = new Float32Array(S * S);
      for (let y = 0; y < S; y++) { const sy = Math.min(n - 1, Math.floor(y * n / S)) * n; for (let x = 0; x < S; x++) out[y * S + x] = src.data[sy + Math.min(n - 1, Math.floor(x * n / S))] / 128; }
    }
    this.maps.set(key, out);
    return out;
  }

  // ---------------------------------------------------------------- texture del giocatore
  paint(kit, look, opt, size) {
    const S = size, M = this.texMap(S), D = this.detailAt(S), L = look, LM = this.L;
    const st = normalizeKitStyle(kit.style), skinH = SKINS[L.skin][1], hairC = HAIR_COLORS[L.hairColor][1];
    const shirtH = hex(kit.shirt), altH = hex(kit.shorts === kit.shirt ? (lumH(hex(kit.shirt)) > 0.5 ? 0x1b1b1b : 0xffffff) : kit.shorts);
    const skin = rgb(skinH), shirt = rgb(shirtH), alt = rgb(altH), shorts = rgb(hex(kit.shorts)), socks = rgb(hex(kit.socks));
    const stripeC = rgb(hex(kit.shirt === kit.shorts ? 0xffffff : kit.shirt)), sockTrim = rgb(lumH(hex(kit.socks)) > 0.5 ? shade(hex(kit.socks), 0.75) : altH);
    const bootH = BOOTS[L.boots][1], boot = rgb(bootH), bootAcc = rgb(lumH(bootH) > 0.6 ? '#1b1b1f' : (L.boots === 0 ? '#e9e9e9' : '#ffffff'));
    const sole = rgb(SOLE), glove = kit.gloves ? [244, 244, 244] : skin, gloveBand = rgb(shade(shirtH, 0.8));
    const hairS = rgb(shade(hairC, 0.85));
    // misure lungo le gambe (frazioni dall'anca alla caviglia, come nel modello vecchio) e lungo le braccia
    const legY = f => LM.hipY - f * (LM.hipY - LM.ankleY);
    const shirtBot = LM.hipY + 0.035, shortsEnd = legY(st.shorts === 1 ? 0.5 : 0.36);
    const sockTop = legY(st.socks === 1 ? 0.84 : st.socks === 2 ? 0.66 : 0.58), bootTop = LM.ankleY + 0.035;
    const sleeveEnd = st.sleeves === 1 ? LM.wrX - 0.015 : st.sleeves === 0 ? LM.shX + 0.55 * (LM.elX - LM.shX) : LM.shX - 0.035;
    const ls = this.leftSign, chestY = LM.spine3Y + 0.07;
    // canvas proiettati: viso (coordinate Kenney della zona viso), schiena, stemma
    const face = this.faceCanvas(L, skinH, hairC), back = this.backCanvas(shirtH, altH, st, opt), crest = kit.crest ? this.crestCanvas(kit.crest) : null;
    const fx = 36 / LM.eyeDX, fy = 52 / Math.max(0.03, (LM.eyeY - LM.chinY) * 0.58);   // m → px della zona viso
    const hc = this.head.c, hu = this.head.up, hf = this.head.fwd, hrt = this.head.right;
    const scalpOn = L.hair > 0, midX = (this.eyeL.x + this.eyeR.x) / 2, hem = rgb(shade(shirtH, 0.82)), shortsHem = rgb(shade(hex(kit.shorts), 0.8));

    const cv = document.createElement('canvas'); cv.width = cv.height = S;
    const g = cv.getContext('2d'), img = g.createImageData(S, S), px = img.data;
    const col = [0, 0, 0];
    const set = (c) => { col[0] = c[0]; col[1] = c[1]; col[2] = c[2]; };
    const mix = (c, a) => { col[0] += (c[0] - col[0]) * a; col[1] += (c[1] - col[1]) * a; col[2] += (c[2] - col[2]) * a; };
    const sample = (cnv, u, v) => { const x = u | 0, y = v | 0; if (x < 0 || y < 0 || x >= cnv.w || y >= cnv.h) return 0; return ((y * cnv.w + x) << 2); };
    for (let i = 0; i < S * S; i++) {
      let c = M.cls[i]; if (!c) continue;
      const x = M.pos[i * 3], y = M.pos[i * 3 + 1], z = M.pos[i * 3 + 2], nx = M.nrm[i * 3], nz = M.nrm[i * 3 + 2];
      // base del collo vicino allo scollo: si dipinge come il busto (motivo e bordino continuano senza scalini)
      if (c === C_NECK && this.neckline(st.collar, x, y, z, LM) < AA) c = C_TORSO;
      let cloth = true;
      const ax = Math.abs(x);
      if (c === C_HEAD || c === C_NECK) {
        set(skin); cloth = false;
        if (c === C_HEAD) {
          const dx = x - hc.x, dy = y - hc.y, dz = z - hc.z;
          const ly = dx * hu.x + dy * hu.y + dz * hu.z, lx = dx * hrt.x + dy * hrt.y + dz * hrt.z, lz = dx * hf.x + dy * hf.y + dz * hf.z;
          // viso: sopracciglia, barba, labbra (proiettate da davanti)
          const nf = M.nrm[i * 3] * hf.x + M.nrm[i * 3 + 1] * hf.y + nz * hf.z;
          if (nf > -0.15 && lz > -0.02) {
            const o = sample(face, FACE.x + (x - midX) * fx, FACE.eyeY + (LM.eyeY - y) * fy);
            const a = face.d[o + 3] / 255 * smooth(-0.15, 0.25, nf); if (a > 0) mix([face.d[o], face.d[o + 1], face.d[o + 2]], a);
          }
        }
        // cute sotto i capelli anche sul collo (nuca): niente scalino dove finisce l'osso della testa
        if (scalpOn) { const a = scalpAt(this.head, L.hair, x, y, z, i); if (a > 0) mix(hairS, a); }
      } else if (c === C_HAND) {
        set(glove); cloth = !!kit.gloves;
        if (kit.gloves && Math.abs(ax - LM.wrX - 0.04) < 0.012) set(gloveBand);
        if (!kit.gloves && st.sleeves === 1 && ax < LM.wrX + 0.005) set(alt);
      } else if (c === C_ARM || (c === C_TORSO && ax > LM.shX - 0.02 && y > shirtBot)) {
        if (ax < Math.min(LM.shX - 0.02, sleeveEnd)) { set(shirt); this.pattern(st.pattern, x, y, z, ls, chestY, alt, mix, false); } // ascella: ancora busto
        else if (ax < sleeveEnd) { set(shirt); this.pattern(st.pattern, x, y, z, ls, chestY, alt, mix, true); if (ax > sleeveEnd - 0.014) set(alt); }
        else { set(skin); cloth = false; }
      } else if (c === C_TORSO) {
        if (y >= shirtBot) {
          set(shirt);
          this.pattern(st.pattern, x, y, z, ls, chestY, alt, mix, false);
          if (y < shirtBot + 0.012) mix(hem, 0.8);
          // scollo e colletto
          const nl = this.neckline(st.collar, x, y, z, LM);
          if (nl > -0.012) { mix(alt, Math.min(1, (nl + 0.012) / AA + 0.5)); if (nl > -AA) { mix(skin, Math.min(1, nl / AA + 0.5)); if (nl > 0) cloth = false; } }
          if (st.collar === 2 && z > 0 && ax < 0.008 && y > LM.neckY - 0.13 && y < LM.neckY - 0.05) set(alt); // abbottonatura della polo
          // stemma sul petto (lato sinistro del giocatore)
          if (crest && z > 0.02) { const o = sample(crest, (x * ls - 0.085) / 0.075 * 64 + 32, (chestY + 0.04 - y) / 0.075 * 64 + 32); const a = crest.d[o + 3] / 255; if (a > 0) mix([crest.d[o], crest.d[o + 1], crest.d[o + 2]], a); }
          // cognome e numero sulla schiena (letti da dietro: il lato sinistro del giocatore è a sinistra)
          if (z < -0.01 && back) { const o = sample(back, 128 - x * ls * 640, (LM.neckY - 0.02 - y) * 640); const a = back.d[o + 3] / 255; if (a > 0) mix([back.d[o], back.d[o + 1], back.d[o + 2]], a); }
        } else { set(shorts); if (Math.abs(nx) > SIDE_NX && x * nx > 0) set(stripeC); }
      } else if (c === C_LEG || c === C_FOOT) {
        if (y > shortsEnd) { set(shorts); if (y < shortsEnd + 0.012) set(shortsHem); else if (Math.abs(nx) > SIDE_NX && x * nx > 0) set(stripeC); }
        else if (y > sockTop) { set(skin); cloth = false; }
        else if (y > bootTop && c === C_LEG) {
          set(socks);
          if (st.socks === 2) { if (y > sockTop - 0.045) set(rgb(shade(hex(kit.socks), 0.82))); else if (y > sockTop - 0.055) set(alt); }
          else if (y < sockTop - 0.012 && y > sockTop - 0.026) set(sockTrim);
        } else {
          set(boot); if (y < 0.022) set(sole);
          else if (Math.abs(nx) > 0.5 && Math.abs(frac((z * 1.6 + y * 3) * 6) - 0.5) < 0.12 && y < bootTop - 0.01) set(bootAcc);
        }
      }
      let r = col[0], gg = col[1], b = col[2];
      if (D) { const k = cloth ? DETAIL_K.cloth : DETAIL_K.skin, f = 1 + k * (D[i] - 1); r *= f; gg *= f; b *= f; }
      const o = i * 4; px[o] = r; px[o + 1] = gg; px[o + 2] = b; px[o + 3] = 255;
    }
    this.dilate(px, S, M.cls, 3);
    g.putImageData(img, 0, 0);
    g.save(); g.scale(S / 1024, S / 1024);
    paintHairTex(g, L.hair, hairC, skinH, HAIR_RECT);
    this.paintEyes(g, L, skinH);
    g.restore();
    return cv;
  }

  // motivo della maglia come forma sul corpo (righe verticali, a cerchi, fascia, metà)
  pattern(p, x, y, z, ls, chestY, alt, mix, arm) {
    // bordi morbidi (mezzo centimetro): niente scalini dei texel sulle righe
    const band = (d, half) => Math.max(0, Math.min(1, 0.5 + (half - Math.abs(d)) / AA));
    if (p === 1 && !arm) { const u = frac((x + 0.0175) / 0.07) * 0.07; mix(alt, band(u - 0.0175, 0.0175)); }
    else if (p === 2) { const u = frac((y - chestY) / 0.085) * 0.085; mix(alt, band(u - 0.0204, 0.0204)); }
    else if (p === 3 && !arm) { const d = x * ls * (z > 0 ? 1 : -1) + (y - chestY) * 0.9; mix(alt, band(d + 0.02, 0.04)); }
    else if (p === 4) { const d = x * ls * (z < 0 ? -1 : 1); mix(alt, Math.max(0, Math.min(1, 0.5 - d / AA))); }
  }

  // scollo: > 0 dentro lo scollo (pelle), vicino a 0 il bordino (colore secondario)
  neckline(collar, x, y, z, LM) {
    const ax = Math.abs(x), base = LM.neckY - 0.012;
    // vicino al collo (cilindro attorno all'osso): taglia lo scollo sulle spalle, dove la superficie è quasi piana
    const radial = NECK_R - Math.hypot(x, (z - LM.neckZ) * 1.15);
    let yTerm;
    if (z <= LM.neckZ) yTerm = y - (base + 0.004 + 4 * ax * ax);
    else if (collar === 1) { const vy = base - 0.075 + Math.min(1, ax / 0.05) * 0.06; yTerm = y - Math.max(vy, base - 0.02 + 3 * ax * ax - (ax < 0.05 ? 1 : 0)); }
    else yTerm = y - (base - 0.028 + 5 * ax * ax);
    return Math.min(yTerm, radial);
  }

  // sopracciglia, barba e labbra nella zona viso Kenney (640×440): poi proiettate sul viso vero
  faceCanvas(L, skinH, hairC) {
    const c = this.faceCv || (this.faceCv = cpuCanvas(640, 440)), g = c.getContext('2d');
    g.clearRect(0, 0, 640, 440);
    // labbra: appena più rosate
    g.fillStyle = 'rgba(170,70,70,0.16)'; g.beginPath(); g.ellipse(FACE.x, FACE.mouthY + 2, 16, 6, 0, 0, Math.PI * 2); g.fill();
    this.paintBeard(g, L, skinH, hairC);
    this.paintBrows(g, L, hairC);
    return { w: 640, h: 440, d: g.getImageData(0, 0, 640, 440).data };
  }

  // cognome e numero: canvas 256×256 = 0,4 m × 0,4 m di schiena a partire dall'attaccatura del collo
  backCanvas(shirt, alt, st, opt) {
    if (!opt.name && !opt.num) return null;
    const c = this.backCv || (this.backCv = cpuCanvas(256, 256)), g = c.getContext('2d'), ink = this.inkFor(shirt, alt, st.pattern);
    g.clearRect(0, 0, 256, 256); g.textAlign = 'center'; g.textBaseline = 'middle'; g.lineJoin = 'round';
    if (opt.name) { let fs = 30; g.font = `800 ${fs}px "Arial Narrow",Arial,sans-serif`; const w = g.measureText(opt.name).width; if (w > 150) { fs = Math.floor(fs * 150 / w); g.font = `800 ${fs}px "Arial Narrow",Arial,sans-serif`; } g.lineWidth = 5; g.strokeStyle = ink.line; g.strokeText(opt.name, 128, 50); g.fillStyle = ink.fill; g.fillText(opt.name, 128, 50); }
    if (opt.num) { const n = String(opt.num); g.font = `900 ${n.length > 1 ? 112 : 120}px "Arial Narrow",Arial,sans-serif`; g.save(); g.translate(128, 0); g.scale(n.length > 1 ? 0.78 : 1, 1); g.lineWidth = 9; g.strokeStyle = ink.line; g.strokeText(n, 0, 132); g.fillStyle = ink.fill; g.fillText(n, 0, 132); g.restore(); }
    return { w: 256, h: 256, d: g.getImageData(0, 0, 256, 256).data };
  }

  crestCanvas(cr) {
    const c = this.crestCv || (this.crestCv = cpuCanvas(64, 64)), g = c.getContext('2d'); g.clearRect(0, 0, 64, 64); drawCrest(g, cr, cr.c1, cr.c2, 32, 32, 26);
    return { w: 64, h: 64, d: g.getImageData(0, 0, 64, 64).data };
  }

  // tassello degli occhi: sclera, iride del colore scelto, pupilla, riflesso; palpebra per gli occhi "assonnati"
  paintEyes(g, L, skinH) {
    const [x, y, w, h] = EYE_PX, cx = x + w / 2, cy = y + h / 2, iris = EYE_COLORS[L.eyeColor][1];
    g.save(); g.beginPath(); g.rect(x, y, w, h); g.clip();
    g.fillStyle = shade(skinH, 0.9); g.fillRect(x, y, w, h);
    const sc = g.createRadialGradient(cx, cy, 4, cx, cy, w * 0.42); sc.addColorStop(0, '#f6f3ee'); sc.addColorStop(0.7, '#ece4dc'); sc.addColorStop(1, shade(skinH, 0.95));
    g.fillStyle = sc; g.beginPath(); g.ellipse(cx, cy, w * 0.42, h * 0.3, 0, 0, Math.PI * 2); g.fill();
    const ir = w * [0.105, 0.1, 0.095, 0.115, 0.1, 0.105][L.eyes];
    g.fillStyle = iris; g.beginPath(); g.arc(cx, cy, ir, 0, Math.PI * 2); g.fill();
    g.strokeStyle = shade(iris, 0.5); g.lineWidth = 1.5; g.stroke();
    g.fillStyle = '#0d0907'; g.beginPath(); g.arc(cx, cy, ir * 0.45, 0, Math.PI * 2); g.fill();
    g.fillStyle = 'rgba(255,255,255,0.9)'; g.beginPath(); g.arc(cx - ir * 0.35, cy - ir * 0.35, ir * 0.22, 0, Math.PI * 2); g.fill();
    const lid = [0, 0.1, 0.25, 0, 0.18, 0.4][L.eyes];
    if (lid) { g.fillStyle = shade(skinH, 0.88); g.fillRect(x, y, w, h * (0.5 - 0.3 + 0.3 * lid * 2) - ir * 0.2); }
    g.restore();
  }

  // allarga i colori di qualche texel fuori dalle isole UV (niente cuciture scure con le mipmap)
  dilate(px, S, cls, n) {
    const filled = new Uint8Array(S * S); for (let i = 0; i < S * S; i++) filled[i] = cls[i] ? 1 : 0;
    for (let it = 0; it < n; it++) {
      const add = [];
      for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
        const i = y * S + x; if (filled[i]) continue;
        const nb = x > 0 && filled[i - 1] ? i - 1 : x < S - 1 && filled[i + 1] ? i + 1 : y > 0 && filled[i - S] ? i - S : y < S - 1 && filled[i + S] ? i + S : -1;
        if (nb >= 0) add.push(i, nb);
      }
      for (let k = 0; k < add.length; k += 2) { const i = add[k], j = add[k + 1]; px[i * 4] = px[j * 4]; px[i * 4 + 1] = px[j * 4 + 1]; px[i * 4 + 2] = px[j * 4 + 2]; px[i * 4 + 3] = 255; filled[i] = 1; }
    }
  }

  // il clip "fermo" ha gambe larghe e gomiti fuori (guardia): a riposo il calciatore li chiude un po'.
  // Solo quando non c'è un'altra posa procedurale (calcio, tuffo, giochetti...), in proporzione al peso del clip.
  flush(f) {
    const w = this.wIdle || 0;
    if (!this.todo.length && w > 0.05) {
      this.rot(f, 'LeftUpLeg', 2, -IDLE_FIX.legs * w); this.rot(f, 'RightUpLeg', 2, IDLE_FIX.legs * w);
      this.rot(f, 'LeftArm', 2, -IDLE_FIX.arms * w); this.rot(f, 'RightArm', 2, IDLE_FIX.arms * w);
    }
    if (this.todo.length) super.flush(f);
  }

  // corsa e scatto: sopra SPRINT_FROM il clip di scatto prende il posto di quello di corsa
  blend(A, wIdle, wRun, wJump, v, cele) {
    this.wIdle = wJump > 0 ? 0 : wIdle;
    const sp = A.sprint ? smooth(SPRINT_FROM, SPRINT_FULL, v) : 0;
    if (A.idle) A.idle.setEffectiveWeight(wIdle);
    if (A.run) { A.run.setEffectiveWeight(wRun * (1 - sp)); A.run.timeScale = Math.min(1.6, Math.max(0.6, v / RUN_REF)); }
    if (A.sprint) { A.sprint.setEffectiveWeight(wRun * sp); A.sprint.timeScale = Math.min(1.3, Math.max(0.8, v / SPRINT_REF)); }
    if (A.jump) { A.jump.setEffectiveWeight(wJump); A.jump.timeScale = cele ? 1.3 : 1.6; }
  }
}

// Carica il modello realistico. null se manca o non si legge.
const loaded = new WeakMap();
export function loadAthlete3D(buf) {
  if (!buf) return Promise.resolve(null);
  if (loaded.has(buf)) return loaded.get(buf);
  const pr = new Promise((ok) => {
    try {
      new GLTFLoader().parse(buf.slice(0), '', (gltf) => {
        try {
          const m = new Athlete3D(gltf), ex = (gltf.parser.json.extras || {}).detail;
          if (!ex) { ok(m); return; }
          // mappa di dettaglio: se manca il giocatore resta senza pieghe, ma si gioca lo stesso
          gltf.parser.getDependency('bufferView', ex.bufferView)
            .then((ab) => { m.detail = { size: ex.size, data: new Uint8Array(ab) }; ok(m); })
            .catch((e) => { console.warn('dettaglio del modello atleta non leggibile:', e); ok(m); });
        } catch (e) { console.warn('modello atleta non usabile:', e); ok(null); }
      }, (e) => { console.warn('modello atleta non leggibile:', e); ok(null); });
    } catch (e) { console.warn('modello atleta non leggibile:', e); ok(null); }
  });
  loaded.set(buf, pr);
  return pr;
}

// Il modello migliore disponibile: prima l'atleta realistico, poi il vecchio Kenney, altrimenti null (figure a box).
export async function loadBestPlayers(assets) {
  if (!assets) return null;
  const a = assets.has('athlete') ? await loadAthlete3D(assets.get('athlete')) : null;
  if (a) return a;
  return assets.has('player') ? loadPlayers3D(assets.get('player')) : null;
}
