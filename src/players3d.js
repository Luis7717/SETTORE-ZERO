// Giocatori 3D: un solo modello umanoide animato (Kenney "Animated Characters", CC0) condiviso da tutti.
// Ogni giocatore = 1 SkinnedMesh (1 draw call) con il proprio scheletro clonato, un mixer e un materiale
// Lambert con una texture 256×256 dipinta al volo coi colori della maglia (cache per maglia + aspetto).
// Clip nel file: idle, run, jump. Calcio, scivolata, tuffo, a terra, esultanza, colpo di testa e posa del
// portiere sono fatti ruotando le ossa sopra il clip (pose procedurali), come faceva la figura a box.
//
// Uso (da render.js): const m = await loadPlayers3D(arrayBuffer); f = m.make(kit, look); m.pose(p, f, dt, ctx)
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { clone as cloneSkinned } from 'three/addons/utils/SkeletonUtils.js';

const MODEL_H = 1.86;          // altezza del modello prima di SCALE (la testa è grande: un po' più alto della figura a box, che arriva a 1,75)
const TEX = 256;               // lato della texture dipinta per ogni maglia
const RUN_FULL = 1.6;          // m/s: sopra questa velocità il clip di corsa è a peso pieno
const RUN_REF = 6.0;           // m/s: velocità a cui il clip di corsa gira a velocità 1
const KICK_T = 0.35;           // durata di kickAnim nel motore
const HEAD_H = 1.3;            // palla sopra questa altezza al momento del colpo = colpo di testa
const BOOT = '#17171b', SOLE = '#e9e9e9';
const SKIN = ['#f1c9a5', '#d9a47a', '#a9744f', '#6b4630'];
const HAIR = ['#1c1410', '#4a2f1b', '#8a5a2b', '#d9b66a', '#222222', '#2b2b2b'];

// Zone della texture Kenney (coordinate su 1024, origine in alto a sinistra, come le UV glTF)
const R = {
  head: [0, 0, 640, 440], neck: [0, 440, 640, 50],
  torso: [0, 490, 640, 534],               // busto e braccia (croce)
  forearmL: [0, 640, 125, 200], forearmR: [515, 640, 125, 200],
  soles: [640, 0, 384, 140], shoes: [640, 140, 190, 390],
  hands: [830, 140, 194, 630], hands2: [640, 530, 190, 240],
  legs: [620, 770, 404, 254],             // pantaloni: in alto fianchi, in basso caviglie
};
const SHORTS_END = 885, SOCKS_START = 925; // su 1024, dentro la zona legs

const hex = c => '#' + (c >>> 0).toString(16).padStart(6, '0').slice(-6);
const rgb = h => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];

class Players3D {
  constructor(gltf) {
    this.scene = gltf.scene;
    this.mesh = null; this.scene.traverse(o => { if (o.isSkinnedMesh && !this.mesh) this.mesh = o; });
    if (!this.mesh) throw new Error('nessuna SkinnedMesh nel modello');
    this.clips = {}; for (const c of gltf.animations) this.clips[c.name] = c;
    this.base = this.mesh.material.map ? this.mesh.material.map.image : null;
    this.texCache = new Map(); this.headCache = new Map();
    this.q = new THREE.Quaternion(); this.q2 = new THREE.Quaternion(); this.e = new THREE.Euler(); this.todo = [];
    this.measure();
  }

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
    this.fixScale = MODEL_H / h; this.fixYaw = -yaw;
    this.fixY = -box.min.y * this.fixScale;
    this.fixQ = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), this.fixYaw);
    const sph = new THREE.Sphere(); box.getBoundingSphere(sph); this.radius = sph.radius / h * MODEL_H * 1.6;
  }

  // ---------------------------------------------------------------- texture della maglia
  headTex(look) {
    const key = look & 0xff;
    if (this.headCache.has(key)) return this.headCache.get(key);
    const k = TEX / 1024, [hx, hy, hw, hh] = R.head.map(x => Math.round(x * k)), hn = Math.round((R.head[3] + R.neck[3]) * k);
    const c = document.createElement('canvas'); c.width = hw; c.height = hn;
    const g = c.getContext('2d', { willReadFrequently: true });
    g.drawImage(this.base, 0, 0, 640, 490, 0, 0, hw, hn);
    const img = g.getImageData(0, 0, hw, hn), d = img.data;
    // colori di partenza campionati sulla pelle (collo) e sui capelli (in alto a sinistra)
    const at = (x, y) => { const i = (Math.round(y * k) * hw + Math.round(x * k)) * 4; return [d[i], d[i + 1], d[i + 2]]; };
    const bSkin = at(320, 470), bHair = at(60, 40), tSkin = rgb(SKIN[look % 4]), tHair = rgb(HAIR[(look >> 2) % HAIR.length]);
    const lum = c => 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2] + 1, ls = lum(bSkin), lh = lum(bHair);
    const dist = (r, g2, b, c) => Math.abs(r - c[0]) + Math.abs(g2 - c[1]) + Math.abs(b - c[2]);
    for (let i = 0; i < d.length; i += 4) {
      const r = d[i], g2 = d[i + 1], b = d[i + 2], l = 0.3 * r + 0.59 * g2 + 0.11 * b + 1;
      const ds = dist(r, g2, b, bSkin), dh = dist(r, g2, b, bHair);
      let t = null, f = 1;
      // occhi e sopracciglia (centro del viso) restano scuri: lì i capelli si riconoscono solo se molto vicini
      const px = (i >> 2) % hw, py = (i >> 2) / hw | 0, eyes = px > 250 * k && px < 400 * k && py > 185 * k && py < 300 * k;
      if (ds < 90 && ds <= dh) { t = tSkin; f = l / ls; } else if (dh < (eyes ? 40 : 120) && l < ls) { t = tHair; f = Math.min(1.6, l / lh); }
      if (t) { d[i] = Math.min(255, t[0] * f); d[i + 1] = Math.min(255, t[1] * f); d[i + 2] = Math.min(255, t[2] * f); }
    }
    g.putImageData(img, 0, 0);
    this.headCache.set(key, c);
    return c;
  }

  kitTex(kit, look) {
    const key = [kit.shirt, kit.shorts, kit.socks, kit.stripe, look & 0xff].join(',');
    let t = this.texCache.get(key); if (t) return t;
    const c = document.createElement('canvas'); c.width = c.height = TEX;
    const g = c.getContext('2d'), k = TEX / 1024, skin = SKIN[look % 4];
    const rect = (r, col) => { g.fillStyle = col; g.fillRect(r[0] * k, r[1] * k, r[2] * k, r[3] * k); };
    rect([0, 0, 1024, 1024], skin);
    if (this.base) g.drawImage(this.headTex(look), 0, 0);
    // maglia (busto + maniche corte), avambracci nudi, righe verticali se la maglia le ha
    rect(R.torso, hex(kit.shirt));
    if (kit.stripe !== undefined) for (const x of [262, 372]) rect([x, 490, 48, 534], hex(kit.stripe));
    rect(R.forearmL, skin); rect(R.forearmR, skin);
    // colletto e bordo delle maniche più scuri: si legge meglio da lontano
    g.globalAlpha = 0.25; rect([125, 640, 10, 200], '#000'); rect([505, 640, 10, 200], '#000'); g.globalAlpha = 1;
    // pantaloncini, ginocchia, calzettoni
    const [lx, ly, lw] = R.legs;
    rect([lx, ly, lw, SHORTS_END - ly], hex(kit.shorts));
    rect([lx, SOCKS_START, lw, 1024 - SOCKS_START], hex(kit.socks));
    // scarpe e mani
    rect(R.soles, SOLE); rect(R.shoes, BOOT); rect(R.hands, skin); rect(R.hands2, skin);
    t = new THREE.CanvasTexture(c); t.flipY = false; t.colorSpace = THREE.SRGBColorSpace;
    t.anisotropy = 4; t.generateMipmaps = true;
    this.texCache.set(key, t);
    return t;
  }

  // ---------------------------------------------------------------- un giocatore
  make(kit, look) {
    const g = new THREE.Group(), body = new THREE.Group(), fix = new THREE.Group(); g.add(body); body.add(fix);
    const model = cloneSkinned(this.scene); fix.add(model);
    fix.rotation.y = this.fixYaw; fix.scale.setScalar(this.fixScale); fix.position.y = this.fixY;
    let mesh = null; const bones = {};
    model.traverse(o => { if (o.isSkinnedMesh) mesh = o; if (o.isBone) bones[o.name] = o; });
    const mat = new THREE.MeshLambertMaterial({ map: this.kitTex(kit, look) });
    mesh.material = mat; mesh.frustumCulled = true;
    mesh.boundingSphere = new THREE.Sphere(new THREE.Vector3(0, MODEL_H / 2 / this.fixScale, 0), this.radius / this.fixScale);
    const mixer = new THREE.AnimationMixer(model), act = {};
    for (const n of ['idle', 'run', 'jump']) {
      if (!this.clips[n]) continue;
      const a = mixer.clipAction(this.clips[n]); a.play(); a.setEffectiveWeight(n === 'idle' ? 1 : 0);
      a.time = ((look * 0.37) % 1) * this.clips[n].duration; act[n] = a;
    }
    return { g, body, fix, model, mesh, mixer, act, bones, mat, saved: [], m3d: true };
  }

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

  // ctx: { t, phase, flip, yaw, ball, scale }
  pose(p, f, dt, ctx) {
    const body = f.body, A = f.act, X = 0, Z = 2, sv = f.saved;
    for (let i = sv.length - 2; i >= 0; i -= 2) sv[i].quaternion.copy(sv[i + 1]);
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
    if (A.idle) A.idle.setEffectiveWeight(wIdle);
    if (A.run) { A.run.setEffectiveWeight(wRun); A.run.timeScale = Math.min(1.5, Math.max(0.55, v / RUN_REF)); }
    if (A.jump) { A.jump.setEffectiveWeight(wJump); A.jump.timeScale = cele ? 1.3 : 1.6; }
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
    if (this.todo.length) this.flush(f);
  }
}

// Carica il modello da un ArrayBuffer (assets.get('player')). Ritorna null se manca o non si legge.
export function loadPlayers3D(buf) {
  if (!buf) return Promise.resolve(null);
  return new Promise((ok) => {
    try {
      new GLTFLoader().parse(buf, '', (gltf) => {
        try { ok(new Players3D(gltf)); } catch (e) { console.warn('modello giocatori non usabile:', e); ok(null); }
      }, (e) => { console.warn('modello giocatori non leggibile:', e); ok(null); });
    } catch (e) { console.warn('modello giocatori non leggibile:', e); ok(null); }
  });
}
