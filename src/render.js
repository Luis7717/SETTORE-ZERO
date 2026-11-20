// Grafica 3D: stadio, giocatori, palla, linea disegnata. Coordinate three: X = x, Y = altezza, Z = -y.
import { chooseTrick, ballOffset } from './tricks.js';
import * as THREE from 'three';
import { W, HL, GW, GH } from './sim.js';
import { buildStadium, FALLBACK_SKY, stadiumSummary } from './stadium.js';
import { logError } from './diag.js';
import { releaseCanvas, watchRestore } from './canvas-mem.js';
import { loadBestPlayers } from './athlete3d.js';
import { buildPitch, buildLights, setupRenderer, fitSun, playerShadowTexture, shadowYaw, SHADOWS } from './pitch.js';
import { Props, makeRibbon, fillRibbon } from './props.js';
import { saveView, wideView } from './camfit.js';
import { userCamOn, relaxYaw, keepGoal } from './camuser.js';

const _rp = [0, 0, 0]; // punto riusato per i nastri delle linee

const SKIN = [0xf1c9a5, 0xd9a47a, 0xa9744f, 0x6b4630];
const HAIR = [0x1c1410, 0x4a2f1b, 0x8a5a2b, 0xd9b66a, 0x222222, 0x2b2b2b];
const SCALE = 1.25;
const PL_SHADOW = SHADOWS ? 1.5 : 3.4; // lato (m) dell'ombra finta di un giocatore 3D (con le ombre vere solo il contatto ai piedi)
const PREVIEW_COLOR = 0x7dd3ff; // puntini dell'anteprima della traiettoria
const OFFSIDE_COLOR = 0xff5a5a; // linea del fuorigioco
const POSE_K = 5;              // visuali calcolate (parata, rallenty largo): quanto in fretta inseguono l'inquadratura giusta (1/s, tempo vero)
const WIDE_IN = 4;             // rallenty largo: velocità di entrata e uscita (1/s, tempo vero)
const RUN_LINES = 10, RUN_PTS = 64, RUN_COLOR = 0x7dd3ff; // linee di difesa a schermo
const CAM_BACK = 16;           // telecamera di gioco (schermo verticale): distanza dietro il pallone (m)
const NEAR_X0 = 4, NEAR_XW = 8;  // vicino alla porta: da |x| > 4 m la telecamera si avvicina meno, da 12 m per niente
const DEF_BACK = 6, DEF_UP = 6, DEF_LOOK = 12; // difesa: telecamera più indietro e più alta, sguardo verso la propria porta (m)
const CAM_SNAP = 12;           // oltre questo salto del pallone (m) la telecamera non insegue: va subito lì
const CAM_H = 10.5;            // ... e altezza (m); più bassa e vicina = giocatori più grandi
const DUEL_LOW = 0.3;           // quanto si abbassa la telecamera nel duello (0 = niente, 1 = a terra)
const DUEL_BACK = 0.12;         // nel duello la telecamera si allontana di questa frazione della distanza normale
const POSE_K_DRAG = 14;          // mentre il dito gira la visuale (src/camuser.js) l'inquadratura larga insegue più in fretta (1/s)

// insegue l'inquadratura calcolata v ({ pos, look, fov }); la prima volta ci va subito
function smoothPose(s, v, k) {
  if (!s) return { pos: v.pos.slice(), look: v.look.slice(), fov: v.fov };
  return { pos: s.pos.map((x, i) => x + (v.pos[i] - x) * k), look: s.look.map((x, i) => x + (v.look[i] - x) * k), fov: s.fov + (v.fov - s.fov) * k };
}
// mescola la visuale (P, L, fov) con la posa calcolata q, di peso w
function mixPose(P, L, fov, q, w) {
  return { P: P.map((x, i) => x + (q.pos[i] - x) * w), L: L.map((x, i) => x + (q.look[i] - x) * w), fov: fov + (q.fov - fov) * w };
}

function canvasTex(w, h, draw) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8;
  return t;
}

// prato di riserva (un solo colore, niente canvas) se la texture del campo non si può disegnare
function plainPitch(scene) {
  const m = new THREE.Mesh(new THREE.PlaneGeometry(W + 20, 2 * HL + 24), new THREE.MeshLambertMaterial({ color: 0x3f9a37 }));
  m.rotation.x = -Math.PI / 2; m.receiveShadow = true; scene.add(m);
  return { mesh: m, ms: 0, textures: [] };
}

export class View {
  constructor(canvas) {
    this.canvas = canvas;
    this.r = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
    this.r.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    setupRenderer(this.r); // tonemapping, esposizione, ombre: src/pitch.js
    this.scene = new THREE.Scene();
    this.cam = new THREE.PerspectiveCamera(62, 0.5, 0.5, 600);
    this.flip = 1; this.zoom = 0; this.zoomT = 0; this.w = 1; this.h = 1;
    this.cx = 0; this.cy = -20; this.match = null; this.me = 0;
    this.v3 = new THREE.Vector3(); this.figs = []; this.t = 0;
    // contesto WebGL perso e tornato (iOS lo fa sotto pressione di memoria): si registra, e al ritorno si
    // ridisegnano i canvas svuotati delle texture (src/canvas-mem.js) prima che three le ricarichi
    canvas.addEventListener('webglcontextlost', () => logError('webgl', 'contesto perso'));
    watchRestore(this.r, e => logError('webgl/ripristino', e));
    this.buildWorld();
    this.resize();
  }

  // carica le texture sulla GPU e svuota i loro canvas (memoria dei canvas di Safari iOS)
  freeCanvases(textures) {
    let bytes = 0;
    for (const t of textures) { try { bytes += releaseCanvas(this.r, t); } catch (e) { logError('texture/gpu', e); } }
    return bytes;
  }

  // riga per la diagnostica in pausa
  diagInfo() {
    const gl = this.r.getContext(), webgl2 = typeof WebGL2RenderingContext !== 'undefined' && gl instanceof WebGL2RenderingContext;
    return { stadium: this.stadium ? stadiumSummary(this.stadium) : this.stadiumTried ? 'manca' : 'in costruzione',
      gl: `${webgl2 ? 'WebGL2' : 'WebGL1'}${gl.isContextLost && gl.isContextLost() ? ' PERSO' : ''} · dpr ${this.r.getPixelRatio()}` };
  }

  resize() {
    const w = this.canvas.clientWidth || window.innerWidth, h = this.canvas.clientHeight || window.innerHeight;
    this.w = w; this.h = h; this.r.setSize(w, h, false);
    this.cam.aspect = w / h;
    // in verticale serve un campo visivo più alto, in orizzontale più basso
    this.cam.fov = this.baseFov = w < h ? 70 : 42; // le visuali calcolate lo allargano solo quando serve
    this.cam.updateProjectionMatrix();
  }

  buildWorld() {
    const s = this.scene;
    // luci (sole caldo con ombre vere, cielo, controluce), campo (erba e linee): src/pitch.js
    this.lights = buildLights(s);
    let pitch;
    try { pitch = buildPitch(s, this.r); } catch (e) { logError('campo', e); pitch = plainPitch(s); } // senza canvas: prato verde semplice
    this.pitchMs = pitch.ms; this.freeCanvases(pitch.textures);
    // stadio intorno al campo (tribune, pubblico, tetto, cartelloni, cielo): src/stadium.js
    // costruito subito dopo il primo disegno del menu, così il menu compare prima
    // se lo stadio (o il suo cielo) non si costruisce, sopra il campo resta questo blu di sera invece del nero
    this.stadium = null; this.crowdMats = []; this.backStand = null; s.background = new THREE.Color(FALLBACK_SKY);
    setTimeout(() => {
      this.stadiumTried = true;
      try {
        const st = buildStadium(s); this.stadium = st; this.crowdMats = st.crowdMats; this.backStand = st.backStand;
        this.stadiumTeams(); this.freeCanvases(st.textures);
      } catch (e) { logError('stadio', e); }
    }, 0);

    // porte, pallone, bandierine ed effetti: src/props.js
    this.props = new Props(s); this.ballM = this.props.ball;
    const shT = canvasTex(64, 64, (g) => { const gr = g.createRadialGradient(32, 32, 2, 32, 32, 30); gr.addColorStop(0, 'rgba(0,0,0,0.55)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, 64, 64); });
    this.shMat = new THREE.MeshBasicMaterial({ map: shT, transparent: true, depthWrite: false });
    this.shGeo = new THREE.PlaneGeometry(1, 1); this.shGeo.rotateX(-Math.PI / 2);
    // ombra finta dei giocatori: contatto ai piedi (e, senza ombre vere, ombra allungata dalla parte opposta al sole)
    const plT = playerShadowTexture(this.r.capabilities.getMaxAnisotropy());
    this.plShMat = new THREE.MeshBasicMaterial({ map: plT, transparent: true, depthWrite: false });

    // anello del giocatore controllato e bersagli
    const ringT = canvasTex(128, 128, (g) => { g.strokeStyle = '#ffe14a'; g.lineWidth = 12; g.beginPath(); g.arc(64, 64, 52, 0, 7); g.stroke(); });
    this.ring = new THREE.Mesh(this.shGeo, new THREE.MeshBasicMaterial({ map: ringT, transparent: true, depthWrite: false }));
    this.ring.scale.set(1.9, 1, 1.9); this.ring.position.y = 0.04; s.add(this.ring);
    const mk = canvasTex(64, 64, (g) => { g.fillStyle = '#ffe14a'; g.beginPath(); g.moveTo(8, 10); g.lineTo(56, 10); g.lineTo(32, 54); g.fill(); g.strokeStyle = '#000'; g.lineWidth = 3; g.stroke(); });
    this.marker = new THREE.Sprite(new THREE.SpriteMaterial({ map: mk, depthTest: false })); this.marker.scale.set(0.8, 0.8, 1); this.marker.renderOrder = 20; s.add(this.marker);
    const wt = canvasTex(64, 64, (g) => { g.fillStyle = '#ff3b30'; g.beginPath(); g.arc(32, 32, 28, 0, 7); g.fill(); g.fillStyle = '#fff'; g.font = 'bold 46px sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText('!', 32, 35); });
    this.warnMat = new THREE.SpriteMaterial({ map: wt, depthTest: false });
    const tg = canvasTex(128, 128, (g) => { g.strokeStyle = '#ffe14a'; g.lineWidth = 9; g.beginPath(); g.arc(64, 64, 46, 0, 7); g.stroke(); g.beginPath(); g.moveTo(64, 4); g.lineTo(64, 40); g.moveTo(64, 88); g.lineTo(64, 124); g.moveTo(4, 64); g.lineTo(40, 64); g.moveTo(88, 64); g.lineTo(124, 64); g.stroke(); });
    this.target = new THREE.Sprite(new THREE.SpriteMaterial({ map: tg, depthTest: false })); this.target.scale.set(1.7, 1.7, 1); this.target.renderOrder = 21; this.target.visible = false; s.add(this.target);
    this.recv = new THREE.Mesh(this.shGeo, new THREE.MeshBasicMaterial({ map: ringT, transparent: true, depthWrite: false, color: 0x7dffb0 }));
    this.recv.scale.set(1.6, 1, 1.6); this.recv.position.y = 0.04; this.recv.visible = false; s.add(this.recv);
    // difesa: linee disegnate che i giocatori stanno seguendo (resta solo il tratto ancora da fare)
    this.runLines = [];
    for (let i = 0; i < RUN_LINES; i++) { const l = makeRibbon(RUN_PTS, RUN_COLOR, 0.92, 13); l.visible = false; s.add(l); this.runLines.push(l); }

    // linea disegnata
    this.pathMax = 160;
    this.path = makeRibbon(this.pathMax, 0xffffff, 0.95, 15); this.path.visible = false; s.add(this.path);

    // anteprima della traiettoria vera (puntini azzurri) e linea del fuorigioco (rossa), solo mentre si disegna
    this.prevMax = 80;
    const pvg = new THREE.BufferGeometry();
    pvg.setAttribute('position', new THREE.BufferAttribute(new Float32Array(this.prevMax * 3), 3));
    // puntino: anima chiara con bordo scuro morbido (si legge sull'erba e sul pubblico)
    const dot = canvasTex(64, 64, (g) => { const gr = g.createRadialGradient(32, 32, 0, 32, 32, 31); gr.addColorStop(0, '#fff'); gr.addColorStop(0.5, '#fff'); gr.addColorStop(0.62, 'rgba(10,25,40,0.75)'); gr.addColorStop(1, 'rgba(10,25,40,0)'); g.fillStyle = gr; g.fillRect(0, 0, 64, 64); });
    this.preview = new THREE.Points(pvg, new THREE.PointsMaterial({ map: dot, color: PREVIEW_COLOR, size: 0.62, sizeAttenuation: true, depthTest: false, depthWrite: false, transparent: true }));
    this.preview.renderOrder = 17; this.preview.frustumCulled = false; this.preview.visible = false; s.add(this.preview);
    // ombra dell'anteprima sull'erba: fa capire quanto si alza il pallone
    const psg = new THREE.BufferGeometry(); psg.setAttribute('position', new THREE.BufferAttribute(new Float32Array(this.prevMax * 3), 3));
    const sdot = canvasTex(32, 32, (g) => { const gr = g.createRadialGradient(16, 16, 0, 16, 16, 15); gr.addColorStop(0, 'rgba(0,0,0,0.55)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, 32, 32); });
    this.prevSh = new THREE.Points(psg, new THREE.PointsMaterial({ map: sdot, size: 0.5, sizeAttenuation: true, depthTest: false, depthWrite: false, transparent: true }));
    this.prevSh.renderOrder = 12; this.prevSh.frustumCulled = false; this.prevSh.visible = false; s.add(this.prevSh);
    const og = new THREE.PlaneGeometry(W, 0.4); og.rotateX(-Math.PI / 2);
    this.offside = new THREE.Mesh(og, new THREE.MeshBasicMaterial({ color: OFFSIDE_COLOR, transparent: true, opacity: 0.85, depthTest: false }));
    this.offside.renderOrder = 14; this.offside.visible = false; s.add(this.offside);
  }

  // modello 3D dei giocatori: 'athlete' (realistico), se manca o non si legge 'player' (Kenney), altrimenti figure a box
  useAssets(assets) {
    if (this.p3d || this.p3dLoading || !(assets.has('athlete') || assets.has('player'))) return this.p3dLoading || Promise.resolve(null);
    this.p3dLoading = loadBestPlayers(assets).then((m) => {
      this.p3d = m; this.p3dLoading = null;
      if (m && this.match) this.setMatch(this.match, this.me);
      return m;
    });
    return this.p3dLoading;
  }

  makeFig(kit, look, num, name) {
    if (this.p3d) {
      const f = this.p3d.make(kit, look, { num, name }); f.g.scale.setScalar(SCALE); this.freeCanvases([f.tex]);
      f.sh = new THREE.Mesh(this.shGeo, this.plShMat); f.sh.position.y = 0.025; f.sh.scale.set(PL_SHADOW, 1, PL_SHADOW); f.sh.rotation.y = shadowYaw(this.flip);
      f.g.traverse(o => { if (o.isMesh) o.castShadow = SHADOWS; });
      f.warn = new THREE.Sprite(this.warnMat); f.warn.scale.set(0.7, 0.7, 1); f.warn.position.y = 2.25; f.warn.visible = false; f.warn.renderOrder = 22; f.g.add(f.warn);
      this.scene.add(f.g); this.scene.add(f.sh);
      return f;
    }
    const g = new THREE.Group(), body = new THREE.Group(); g.add(body);
    const M = c => new THREE.MeshLambertMaterial({ color: c });
    if (typeof look === 'object') look = (look.skin >> 1) + 4 * look.hairColor; // aspetto di src/looks.js → colori della figura a box
    const skin = M(SKIN[look % 4]), hair = M(HAIR[(look >> 2) % HAIR.length]), shirt = M(kit.shirt), shorts = M(kit.shorts), socks = M(kit.socks), boot = M(0x16161a);
    const box = (w, h, d, m, x, y, z, parent) => { const o = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m); o.position.set(x, y, z); (parent || body).add(o); return o; };
    const torso = box(0.44, 0.54, 0.25, shirt, 0, 1.2, 0);
    if (kit.stripe !== undefined) { const st = M(kit.stripe); box(0.1, 0.545, 0.256, st, -0.11, 1.2, 0); box(0.1, 0.545, 0.256, st, 0.11, 1.2, 0); }
    box(0.43, 0.22, 0.26, shorts, 0, 0.86, 0);
    const head = new THREE.Mesh(new THREE.SphereGeometry(0.125, 12, 10), skin); head.position.set(0, 1.62, 0); body.add(head);
    const hr = new THREE.Mesh(new THREE.SphereGeometry(0.133, 12, 8, 0, Math.PI * 2, 0, Math.PI * 0.55), hair); hr.position.set(0, 1.635, -0.015); hr.rotation.x = -0.25; body.add(hr);
    const arm = (sx) => { const a = new THREE.Group(); a.position.set(sx * 0.275, 1.42, 0); body.add(a); box(0.115, 0.3, 0.12, shirt, 0, -0.14, 0, a); box(0.09, 0.3, 0.09, skin, 0, -0.43, 0, a); return a; };
    const leg = (sx) => { const t = new THREE.Group(); t.position.set(sx * 0.12, 0.8, 0); body.add(t); box(0.155, 0.4, 0.17, skin, 0, -0.2, 0, t); const k = new THREE.Group(); k.position.y = -0.4; t.add(k); box(0.125, 0.36, 0.14, socks, 0, -0.18, 0, k); box(0.125, 0.09, 0.27, boot, 0, -0.37, 0.06, k); return [t, k]; };
    const aL = arm(-1), aR = arm(1), [tL, kL] = leg(-1), [tR, kR] = leg(1);
    g.scale.setScalar(SCALE);
    const sh = new THREE.Mesh(this.shGeo, this.shMat); sh.position.y = 0.025; sh.scale.set(1.3, 1, 1.3);
    const warn = new THREE.Sprite(this.warnMat); warn.scale.set(0.7, 0.7, 1); warn.position.y = 2.25; warn.visible = false; warn.renderOrder = 22; g.add(warn);
    g.traverse(o => { if (o.isMesh) o.castShadow = SHADOWS; });
    this.scene.add(g); this.scene.add(sh);
    return { g, body, aL, aR, tL, kL, tR, kR, sh, warn, mats: { shirt, shorts, socks, skin, hair } };
  }

  setMatch(match, me = 0) {
    for (const f of this.figs) { this.scene.remove(f.g); this.scene.remove(f.sh); if (f.m3d) this.p3d.dispose(f); }
    this.figs = []; this.match = match; this.me = me; this.flip = me === 1 ? -1 : 1;
    if (!match) return;
    for (const p of match.players) {
      const kit = match.teams[p.team].kit;
      this.figs.push(this.figFor(p));
    }
    const b = match.ball; this.cx = b.x; this.cy = b.y;
    if (this.backStand) this.backStand.visible = true;
    this.stadiumTeams();
  }

  // tifosi, bandiere e maxischermo coi colori e i nomi delle squadre in campo (la squadra 0 gioca in casa)
  stadiumTeams() { const m = this.match; if (this.stadium && m) this.stadium.setTeams(m.teams[0].kit, m.teams[1].kit, [m.teams[0].short, m.teams[1].short]); }

  // figura di un giocatore della partita: divisa (portiere a parte), aspetto, numero e cognome
  figFor(p) { const kit = this.match.teams[p.team].kit, f = this.makeFig(p.pos === 'P' ? kit.gk : kit, p.look, p.src && p.src.num || p.i + 1, p.src && p.src.name); f.src = p.src; return f; }

  setZoom(z) { this.zoomT = z; }

  // dribbling tentato da p: parte un giochetto, più bello se il dribbling di p è alto (solo grafica)
  trick(p, r = Math.random()) {
    const T = chooseTrick(p.st ? p.st.dri : 50, r);
    this.tricks = this.tricks || new Map();
    this.tricks.set(p.i, { id: T.id, name: T.name, dur: T.dur, t: 0, side: r * 1000 % 2 < 1 ? 1 : -1 });
    return T;
  }
  trickOf(p) { const k = this.tricks && this.tricks.get(p.i); return k ? { id: k.id, q: Math.min(1, k.t / k.dur), side: k.side } : null; }

  update(dt) {
    const m = this.match; if (!m) return;
    const s = this.flip, b = m.ball; this.t += dt;
    // pubblico: si anima quando il pallone si avvicina a una porta e soprattutto dopo un gol
    if (this.stadium) this.stadium.update(dt, m.phase === 'goal' ? 1 : Math.max(0, (Math.abs(b.y) - 25) / 25) * 0.4, m);
    this.zoom += (this.zoomT - this.zoom) * Math.min(1, (this.rdt != null ? this.rdt : dt) * 7);
    for (let i = 0; i < 22; i++) {
      const p = m.players[i]; let f = this.figs[i];
      if (f.src !== p.src) { this.scene.remove(f.g); this.scene.remove(f.sh); if (f.m3d) this.p3d.dispose(f); f = this.figs[i] = this.figFor(p); } // cambio: entra un altro giocatore
      this.pose(p, f, dt);
    }
    // giochetti del dribbling in corso
    if (this.tricks) for (const [i, k] of this.tricks) { k.t += dt; if (k.t >= k.dur) this.tricks.delete(i); }
    // palla (durante un giochetto di chi la porta, spostata per farlo vedere)
    let bx = b.x, by = b.y, bh = b.h;
    const tk = b.owner && this.trickOf(b.owner);
    if (tk) {
      const o = ballOffset(tk.id, tk.q), c = b.owner, fx = c.fx, fy = c.fy;
      bx += fx * o.f - fy * o.s * tk.side; by += fy * o.f + fx * o.s * tk.side; bh += o.h;
    }
    // anello
    const c = m.ctrl[this.me];
    if (c && !c.off) {
      this.ring.visible = true; this.ring.position.set(s * c.x, 0.04, -s * c.y);
      const k = 1.9 + Math.sin(this.t * 6) * 0.12; this.ring.scale.set(k, 1, k);
      this.marker.visible = true; this.marker.position.set(s * c.x, 2.75 + Math.sin(this.t * 5) * 0.08, -s * c.y);
    } else { this.ring.visible = false; this.marker.visible = false; }
    // duello col difensore: telecamera più bassa e più avanti (si passa a qualunque compagno)
    const duel = !!(m.duelFor && m.duelFor(this.me));
    this.duelK = (this.duelK || 0) + ((duel ? 1 : 0) - (this.duelK || 0)) * Math.min(1, dt * 5);
    this.showRuns(m);
    // telecamera dietro l'azione
    const dir = this.me === 1 ? -1 : 1;
    let fx = b.x, fy = b.y;
    if (m.phase === 'restart' && m.restart) { fx = m.restart.x; fy = m.restart.y; }
    const rdt = this.rdt != null ? this.rdt : dt; // tempo vero: la telecamera non rallenta col rallenty
    // visuale girata dalla persona (trascinando il dito, src/input.js): resta finché dura il rallenty in attacco con lo
    // stesso portatore e mentre si disegna una linea; poi torna dolcemente dritta (src/camuser.js). Con un portatore
    // nuovo (passaggio ricevuto) si riparte dritti anche se si è di nuovo nel rallenty.
    if (this.camDrag) this.yawOwner = m.ball.owner;
    const holdYaw = (userCamOn(m, this.me) && m.ball.owner === this.yawOwner) || this.drawing;
    this.userYaw = relaxYaw(this.userYaw || 0, holdYaw, rdt);
    const k = Math.min(1, rdt * 4.5);
    // salto lungo del pallone (nuova prova del tutorial, ripartenza spostata): la telecamera ci va subito
    if (Math.hypot(fx - this.cx, fy - this.cy) > CAM_SNAP) { this.cx = fx; this.cy = fy; this.near = 0; }
    else { this.cx += (fx - this.cx) * k; this.cy += (fy - this.cy) * k; }
    // vicino alla porta avversaria la telecamera scende e si avvicina: la porta diventa grande
    const mine = b.owner && b.owner.team === this.me && m.phase !== 'goal';
    // ... ma solo con la palla verso il centro: sulla fascia la telecamera vicina lascerebbe fuori il portatore
    const wide = Math.max(0, Math.min(1, 1 - (Math.abs(this.cx) - NEAR_X0) / NEAR_XW));
    const nearT = mine ? Math.max(0, Math.min(1, (this.cy * dir - 14) / 18)) * wide : 0;
    this.near = (this.near || 0) + (nearT - (this.near || 0)) * Math.min(1, rdt * 3);
    const a = this.near, z = this.zoom * (1 - 0.75 * a), port = this.w < this.h;
    const back = ((port ? CAM_BACK : 26) + z * 6) * (1 - 0.3 * a), hgt = ((port ? CAM_H : 13) + z * 5) * (1 - 0.4 * a), ahead = 9 + z * 4 + a * 9;
    // difesa vicino alla propria porta: inquadratura da dietro la porta, bassa, per leggere i tiri
    const defT = 0; // in difesa la telecamera non si avvicina (inquadratura larga per muovere più difensori)
    this.defk = (this.defk || 0) + (defT - (this.defk || 0)) * Math.min(1, dt * 3);
    const dk = this.defk, minY = -HL - 15.5;
    // senza palla: inquadratura più alta e più indietro, che guarda verso la propria porta dove stanno i difensori
    const defW = !mine && m.phase === 'play' ? 1 : 0;
    this.defW = (this.defW || 0) + (defW - (this.defW || 0)) * Math.min(1, rdt * 2.5);
    const dw = this.defW;
    let camY = this.cy * dir - back - DEF_BACK * dw, hh = hgt + DEF_UP * dw, lookY = this.cy * dir + ahead - DEF_LOOK * dw;
    if (camY < minY) { hh += Math.min(6, (minY - camY) * 0.35); camY = minY; }
    camY += (-HL - 12.5 - camY) * dk; hh += (10.5 - hh) * dk; lookY += ((this.cy * dir - HL) / 2 + 3 - lookY) * dk;
    const du = this.duelK; hh *= 1 - DUEL_LOW * du; camY += back * (0.3 - DUEL_BACK) * du; lookY += 8 * du;
    const camX = this.cx * dir * (0.82 - 0.3 * a) * (1 - 0.55 * dk);
    let px = camX, py = camY, lx = this.cx * dir * (0.9 - 0.45 * a) * (1 - 0.45 * dk), ly = lookY;
    const phi = this.userYaw; // la visuale gira intorno al portatore dell'angolo scelto dalla persona
    if (Math.abs(phi) > 1e-3) {
      const ox = this.cx * dir, oy = this.cy * dir, cs = Math.cos(phi), sn = Math.sin(phi);
      const rot = (x, y) => [ox + (x - ox) * cs + (y - oy) * sn, oy - (x - ox) * sn + (y - oy) * cs];
      [px, py] = rot(px, py); [lx, ly] = rot(lx, ly);
    }
    // visuali calcolate (src/camfit.js), nello spazio "orientato" (si attacca verso +y): rallenty largo, poi parata
    let P = [px, hh, py], L = [lx, 0, ly], fov = this.baseFov || this.cam.fov;
    const pk = Math.min(1, rdt * POSE_K);
    const wk = this.wideStep(m, mine, duel, rdt, this.camDrag ? Math.min(1, rdt * POSE_K_DRAG) : pk);
    if (wk > 1e-3) ({ P, L, fov } = mixPose(P, L, fov, this.wideP, wk));
    const gk = this.saveStep(m, dir, rdt, pk);
    if (gk > 1e-3) ({ P, L, fov } = mixPose(P, L, fov, this.saveP, gk));
    this.cam.position.set(P[0], P[1], -P[2]);
    this.cam.lookAt(L[0], L[1], -L[2]);
    if (Math.abs(this.cam.fov - fov) > 0.01) { this.cam.fov = fov; this.cam.updateProjectionMatrix(); }
    // pallone (dove lo mettono il motore e i giochetti), rete, bandierine, effetti
    this.props.update(dt, m, s, this.cam, this.me, bx, by, bh);
  }

  // rallenty in attacco (duello, area di tiro, disegno col pallone): visuale larga che tiene a schermo i compagni
  // davanti e di fianco al portatore; restituisce quanto pesa (0..1, entra ed esce col tempo vero)
  wideStep(m, mine, duel, rdt, pk) {
    const c = m.ball.owner, zone = !duel && !!(m.inZone && m.inZone(this.me));
    const on = !!(mine && c && m.phase === 'play' && (duel || zone || this.drawing));
    this.wideK = (this.wideK || 0) + ((on ? 1 : 0) - (this.wideK || 0)) * Math.min(1, rdt * WIDE_IN);
    if (this.wideK < 1e-3 && !on) { this.wideK = 0; this.wideP = null; return 0; }
    if (on) {
      const dir = this.me === 1 ? -1 : 1, mates = [];
      for (const p of m.players) if (p.team === this.me && !p.off && p !== c && p.pos !== 'P') mates.push([p.x * dir, p.y * dir]);
      // girata dell'angolo scelto dalla persona; nell'area di tiro anche la porta a schermo (se la visuale guarda verso di lei)
      const yaw = this.userYaw || 0;
      const v = wideView({ carrier: [c.x * dir, c.y * dir], yaw, mates, goal: keepGoal(zone, yaw), aspect: this.cam.aspect, fov: this.baseFov || 70 });
      this.wideP = smoothPose(this.wideP, v, pk);
    }
    return this.wideP ? this.wideK : 0;
  }
  // parata: dietro la propria porta, porta intera + portiere + pallone sempre a schermo; restituisce quanto pesa
  saveStep(m, dir, rdt, pk) {
    const on = !!(m.diveWin && m.diveWin(this.me) && !(m.autoGk && m.autoGk[this.me]));
    this.gkK = (this.gkK || 0) + ((on ? 1 : 0) - (this.gkK || 0)) * Math.min(1, rdt * 6);
    if (this.gkK < 1e-3 && !on) { this.gkK = 0; this.saveP = null; return 0; }
    if (on) {
      const b = m.ball, g = m.gk(this.me);
      const v = saveView({ ball: [b.x * dir, b.h, b.y * dir], keeper: [g.x * dir, g.y * dir], aspect: this.cam.aspect, fov: this.baseFov || 70 });
      this.saveP = smoothPose(this.saveP, v, pk);
    }
    return this.saveP ? this.gkK : 0;
  }

  pose(p, f, dt) {
    const s = this.flip, g = f.g, body = f.body;
    if (p.off) { g.visible = false; f.sh.visible = false; return; }
    g.visible = true; f.sh.visible = true;
    const wx = s * p.fx, wz = -s * p.fy, yaw = Math.atan2(wx, wz);
    g.position.set(s * p.x, 0, -s * p.y); g.rotation.y = yaw;
    f.sh.position.set(s * p.x, 0.025, -s * p.y);
    if (f.m3d) { f.warn.visible = !!p.warn; this.p3d.pose(p, f, dt, { t: this.t, phase: this.match.phase, flip: s, yaw, ball: this.match.ball, scale: SCALE, trick: this.trickOf(p) }); return; }
    const v = Math.hypot(p.vx, p.vy), A = Math.min(1, v / 6.5), ph = p.phase;
    body.rotation.set(0, 0, 0); body.position.set(0, 0, 0);
    let tl = -A * 0.95 * Math.sin(ph), tr = A * 0.95 * Math.sin(ph);
    let kl = A * (0.55 + 0.75 * Math.cos(ph - 0.6)), kr = A * (0.55 - 0.75 * Math.cos(ph - 0.6));
    let al = A * 0.8 * Math.sin(ph), ar = -A * 0.8 * Math.sin(ph), az = 0;
    body.rotation.x = A * 0.16; body.position.y = Math.abs(Math.sin(ph)) * 0.05 * A;
    f.warn.visible = !!p.warn;
    if (p.state === 'slide') {
      body.rotation.x = -1.2; body.position.y = 0.38 / SCALE; body.position.z = -0.3;
      tl = -0.25; tr = -1.0; kl = 0.1; kr = 0; al = 0.9; ar = 0.9;
    } else if (p.state === 'down') {
      body.rotation.x = -1.42; body.position.y = 0.3 / SCALE; body.position.z = -0.4; tl = -0.2; tr = -0.35; kl = 0.5; kr = 0.2; al = 0.4; ar = 0.4;
    } else if (p.state === 'dive' && p.dive) {
      const d = p.dive, pr = Math.min(1, p.t / 0.35);
      const lx = s * d.dirx * Math.cos(yaw) >= 0 ? 1 : -1;
      const reach = Math.abs(d.tx - d.x0) > 0.9 ? 1 : 0.35;
      body.rotation.z = -lx * pr * 1.35 * reach;
      body.position.y = (Math.max(0.25, d.hh - 0.6) * pr * reach + Math.sin(pr * 3.14) * 0.3) / SCALE;
      al = ar = -2.9; tl = 0.15; tr = -0.15; kl = 0.3; kr = 0.3;
    } else if (p.cele > 0 && this.match.phase === 'goal') {
      const j = Math.abs(Math.sin(this.t * 7 + p.i)); body.position.y = j * 0.35; al = ar = -2.8; az = 0.4; tl = tr = 0; kl = kr = j * 0.5;
    } else if (p.kickAnim > 0) {
      const q = 1 - p.kickAnim / 0.35; tr = -1.4 * Math.sin(q * Math.PI); kr = 0.9 * (1 - q); tl = 0.25; al = -0.6; ar = 0.7;
    } else if (p.pos === 'P' && v < 1.2) { al = -0.5; ar = -0.5; az = 0.5; tl = -0.15; tr = -0.15; kl = 0.3; kr = 0.3; body.position.y = -0.04; }
    f.tL.rotation.x = tl; f.tR.rotation.x = tr; f.kL.rotation.x = Math.max(0, kl); f.kR.rotation.x = Math.max(0, kr);
    f.aL.rotation.x = al; f.aR.rotation.x = ar; f.aL.rotation.z = -az; f.aR.rotation.z = az;
  }

  showRuns(m) {
    const runs = (m.runs && m.runs[this.me]) || [], s = this.flip;
    this.runLines.forEach((l, k) => {
      const r = runs[k]; l.visible = !!r; if (!r) return;
      const n = Math.min(RUN_PTS, 1 + Math.max(0, r.path.length - r.i));
      const get = i => { _rp[0] = i ? r.path[r.i + i - 1].x : r.p.x; _rp[1] = i ? r.path[r.i + i - 1].y : r.p.y; _rp[2] = 0.08; return _rp; };
      fillRibbon(l, n, get, (i, n) => 0.2 * Math.min(1, 0.45 + i * 0.25), s, 0.75);
    });
  }
  render() { fitSun(this.lights, this.cam, this.flip); this.r.render(this.scene, this.cam); }

  // ---------------------------------------------------- conversioni schermo/campo
  ray(px, py) {
    const v = this.v3.set((px / this.w) * 2 - 1, -((py / this.h) * 2 - 1), 0.5).unproject(this.cam);
    const o = this.cam.position; return [o.x, o.y, o.z, v.x - o.x, v.y - o.y, v.z - o.z];
  }
  screenToGround(px, py) {
    const [ox, oy, oz, dx, dy, dz] = this.ray(px, py);
    if (dy > -1e-4) return null;
    const t = -oy / dy; if (t > 400 / Math.hypot(dx, dy, dz) * 1) { /* troppo lontano */ }
    const s = this.flip; return { x: s * (ox + dx * t), y: -s * (oz + dz * t) };
  }
  // intersezione con il piano della porta a y = gy (coordinate di gioco)
  screenToGoal(px, py, gy) {
    const [ox, oy, oz, dx, dy, dz] = this.ray(px, py), s = this.flip, zp = -s * gy;
    if (Math.abs(dz) < 1e-6) return null;
    const t = (zp - oz) / dz; if (t <= 0) return null;
    return { x: s * (ox + dx * t), h: oy + dy * t };
  }
  worldToScreen(x, y, h) {
    const s = this.flip, v = this.v3.set(s * x, h || 0, -s * y).project(this.cam);
    return { x: (v.x + 1) / 2 * this.w, y: (1 - v.y) / 2 * this.h, vis: v.z < 1 };
  }

  setPath(pts, shot, recv) {
    const s = this.flip, n = Math.min(pts.length, this.pathMax);
    if (n < 2) { this.clearPath(); return; }
    // nastro con bordo scuro morbido: sottile all'inizio, più largo verso la fine, freccia finale (non nel tiro)
    const get = i => { const p = pts[i]; _rp[0] = p.x; _rp[1] = p.y; _rp[2] = (p.h || 0) + 0.08; return _rp; };
    fillRibbon(this.path, n, get, (i, n) => (0.3 + 0.16 * (i / n)) * Math.min(1, 0.4 + i * 0.2), s, shot ? 0 : 1.5);
    const e = pts[n - 1];
    this.target.visible = !!shot; if (shot) this.target.position.set(s * e.x, e.h, -s * e.y);
    this.path.material.color.setHex(shot ? 0xffe14a : 0xffffff);
    if (recv) { this.recv.visible = true; this.recv.position.set(s * recv.x, 0.04, -s * recv.y); } else this.recv.visible = false;
  }
  // pts: punti del volo vero { x, y, h } (da Match.predictKick); offY: y della linea del fuorigioco o null
  setPreview(pts, offY) {
    const s = this.flip, pos = this.preview.geometry.attributes.position.array, n = Math.min(pts.length, this.prevMax);
    for (let i = 0; i < n; i++) { pos[i * 3] = s * pts[i].x; pos[i * 3 + 1] = pts[i].h + 0.12; pos[i * 3 + 2] = -s * pts[i].y; }
    this.preview.geometry.attributes.position.needsUpdate = true;
    this.preview.geometry.setDrawRange(0, n); this.preview.visible = n > 1;
    const sh = this.prevSh.geometry.attributes.position.array;
    for (let i = 0; i < n; i++) { sh[i * 3] = pos[i * 3]; sh[i * 3 + 1] = 0.03; sh[i * 3 + 2] = pos[i * 3 + 2]; }
    this.prevSh.geometry.attributes.position.needsUpdate = true; this.prevSh.geometry.setDrawRange(0, n); this.prevSh.visible = n > 1;
    this.offside.visible = offY !== null;
    if (offY !== null) this.offside.position.set(0, 0.05, -s * offY);
  }
  clearPath() { this.path.visible = false; this.prevSh.visible = false; this.target.visible = false; this.recv.visible = false; this.preview.visible = false; this.offside.visible = false; }
}
