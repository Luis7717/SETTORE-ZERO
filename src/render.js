// Grafica 3D: stadio, giocatori, palla, linea disegnata. Coordinate three: X = x, Y = altezza, Z = -y.
import * as THREE from 'three';
import { W, L, HW, HL, GW, GH, BOX_W, BOX_D, SIX_W, SIX_D, PEN_D, CIRCLE } from './sim.js';
import { buildStadium } from './stadium.js';
import { loadPlayers3D } from './players3d.js';

const SKIN = [0xf1c9a5, 0xd9a47a, 0xa9744f, 0x6b4630];
const HAIR = [0x1c1410, 0x4a2f1b, 0x8a5a2b, 0xd9b66a, 0x222222, 0x2b2b2b];
const SCALE = 1.25;
const PREVIEW_COLOR = 0x7dd3ff; // puntini dell'anteprima della traiettoria
const OFFSIDE_COLOR = 0xff5a5a; // linea del fuorigioco
const GK_CAM_BACK = 6.5;       // parata: telecamera dietro la propria linea di porta (m)
const GK_CAM_H = 2.6;          // parata: altezza della telecamera (m)
const RUN_LINES = 10, RUN_PTS = 64, RUN_COLOR = 0x7dd3ff; // linee di difesa a schermo
const DUEL_MATES = 3;           // compagni liberi evidenziati durante un duello
const DUEL_LOW = 0.42;          // quanto si abbassa la telecamera nel duello (0 = niente, 1 = a terra)

function canvasTex(w, h, draw) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8;
  return t;
}

export class View {
  constructor(canvas) {
    this.canvas = canvas;
    this.r = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
    this.r.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.scene = new THREE.Scene();
    this.cam = new THREE.PerspectiveCamera(62, 0.5, 0.5, 600);
    this.flip = 1; this.zoom = 0; this.zoomT = 0; this.w = 1; this.h = 1;
    this.cx = 0; this.cy = -20; this.match = null; this.me = 0;
    this.v3 = new THREE.Vector3(); this.figs = []; this.t = 0;
    this.buildWorld();
    this.resize();
  }

  resize() {
    const w = this.canvas.clientWidth || window.innerWidth, h = this.canvas.clientHeight || window.innerHeight;
    this.w = w; this.h = h; this.r.setSize(w, h, false);
    this.cam.aspect = w / h;
    // in verticale serve un campo visivo più alto, in orizzontale più basso
    this.cam.fov = w < h ? 70 : 42;
    this.cam.updateProjectionMatrix();
  }

  buildWorld() {
    const s = this.scene;
    s.add(new THREE.HemisphereLight(0xdfeaff, 0x30502a, 1.15));
    const sun = new THREE.DirectionalLight(0xffffff, 1.5); sun.position.set(30, 60, 20); s.add(sun);

    // campo
    const PX = 16, MX = 10, MY = 12;
    const tex = canvasTex((W + MX * 2) * PX, (L + MY * 2) * PX, (g, w, h) => {
      const stripes = 12, sh = (L * PX) / stripes;
      g.fillStyle = '#2c7a33'; g.fillRect(0, 0, w, h);
      for (let i = -2; i < stripes + 2; i++) { g.fillStyle = i % 2 ? '#2f8337' : '#297430'; g.fillRect(0, MY * PX + i * sh, w, sh); }
      // grana dell'erba
      for (let i = 0; i < 26000; i++) { g.fillStyle = Math.random() < 0.5 ? 'rgba(255,255,255,0.035)' : 'rgba(0,0,0,0.05)'; g.fillRect(Math.random() * w, Math.random() * h, 2, 5); }
      g.strokeStyle = 'rgba(255,255,255,0.92)'; g.lineWidth = 0.14 * PX * 1.4; g.lineJoin = 'miter';
      const X = x => (x + HW + MX) * PX, Y = y => (HL - y + MY) * PX;
      g.strokeRect(X(-HW), Y(HL), W * PX, L * PX);
      g.beginPath(); g.moveTo(X(-HW), Y(0)); g.lineTo(X(HW), Y(0)); g.stroke();
      g.beginPath(); g.arc(X(0), Y(0), CIRCLE * PX, 0, 7); g.stroke();
      g.fillStyle = '#fff'; g.beginPath(); g.arc(X(0), Y(0), 0.25 * PX, 0, 7); g.fill();
      for (const d of [1, -1]) {
        const gy = d * HL;
        g.strokeRect(X(-BOX_W / 2), Math.min(Y(gy), Y(gy - d * BOX_D)), BOX_W * PX, BOX_D * PX);
        g.strokeRect(X(-SIX_W / 2), Math.min(Y(gy), Y(gy - d * SIX_D)), SIX_W * PX, SIX_D * PX);
        g.beginPath(); g.arc(X(0), Y(gy - d * PEN_D), 0.25 * PX, 0, 7); g.fill();
        g.beginPath(); const a = Math.acos((BOX_D - PEN_D) / CIRCLE);
        if (d > 0) g.arc(X(0), Y(gy - d * PEN_D), CIRCLE * PX, Math.PI / 2 - a, Math.PI / 2 + a); else g.arc(X(0), Y(gy - d * PEN_D), CIRCLE * PX, -Math.PI / 2 - a, -Math.PI / 2 + a);
        g.stroke();
        for (const sx of [1, -1]) { g.beginPath(); g.arc(X(sx * HW), Y(gy), 1 * PX, 0, 7); g.stroke(); }
      }
    });
    const pitch = new THREE.Mesh(new THREE.PlaneGeometry(W + MX * 2, L + MY * 2), new THREE.MeshLambertMaterial({ map: tex }));
    pitch.rotation.x = -Math.PI / 2; s.add(pitch);
    // stadio intorno al campo (tribune, pubblico, tetto, cartelloni, cielo): src/stadium.js
    // costruito subito dopo il primo disegno del menu, così il menu compare prima
    this.stadium = null; this.crowdMats = []; this.backStand = null;
    setTimeout(() => { const st = buildStadium(s); this.stadium = st; this.crowdMats = st.crowdMats; this.backStand = st.backStand; }, 0);

    // porte
    const postM = new THREE.MeshLambertMaterial({ color: 0xffffff });
    const netTex = canvasTex(128, 128, (g, w, h) => { g.clearRect(0, 0, w, h); g.strokeStyle = 'rgba(255,255,255,0.85)'; g.lineWidth = 3; for (let i = 0; i <= 8; i++) { g.beginPath(); g.moveTo(i * 16, 0); g.lineTo(i * 16, h); g.stroke(); g.beginPath(); g.moveTo(0, i * 16); g.lineTo(w, i * 16); g.stroke(); } });
    netTex.wrapS = netTex.wrapT = THREE.RepeatWrapping;
    this.netMats = [];
    for (const d of [1, -1]) {
      const g = new THREE.Group(); g.position.z = -d * HL; s.add(g);
      const post = (x) => { const m = new THREE.Mesh(new THREE.CylinderGeometry(0.075, 0.075, GH + 0.07), postM); m.position.set(x, GH / 2, 0); g.add(m); };
      post(-GW / 2); post(GW / 2);
      const bar = new THREE.Mesh(new THREE.CylinderGeometry(0.075, 0.075, GW + 0.15), postM); bar.rotation.z = Math.PI / 2; bar.position.y = GH; g.add(bar);
      const nm = new THREE.MeshBasicMaterial({ map: netTex, transparent: true, opacity: 0.55, side: THREE.DoubleSide, depthWrite: false });
      this.netMats.push(nm);
      const pl = (w, h, x, y, z, rx, ry, rep) => { const t = netTex.clone(); t.repeat.set(rep[0], rep[1]); t.needsUpdate = true; const m2 = nm.clone(); m2.map = t; const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), m2); m.position.set(x, y, z); m.rotation.set(rx, ry, 0); g.add(m); this.netMats.push(m2); m2.userData.d = d; };
      const dz = -d * 1.9;
      pl(GW, GH, 0, GH / 2, dz, 0, 0, [6, 2]);
      pl(GW, 1.9, 0, GH, dz / 2, Math.PI / 2, 0, [6, 1.5]);
      pl(1.9, GH, -GW / 2, GH / 2, dz / 2, 0, Math.PI / 2, [1.5, 2]);
      pl(1.9, GH, GW / 2, GH / 2, dz / 2, 0, Math.PI / 2, [1.5, 2]);
    }

    // palla
    const bt = canvasTex(128, 64, (g, w, h) => { g.fillStyle = '#f6f6f6'; g.fillRect(0, 0, w, h); g.fillStyle = '#1b1b1f'; for (const [x, y] of [[16, 16], [48, 44], [80, 14], [112, 40], [34, 58], [96, 60], [64, 30], [0, 44], [128, 44]]) { g.beginPath(); for (let k = 0; k < 5; k++) { const a = k * 1.2566 - 1.57; g.lineTo(x + Math.cos(a) * 8, y + Math.sin(a) * 7); } g.fill(); } });
    this.ballM = new THREE.Mesh(new THREE.SphereGeometry(0.21, 20, 14), new THREE.MeshLambertMaterial({ map: bt }));
    s.add(this.ballM);
    const shT = canvasTex(64, 64, (g) => { const gr = g.createRadialGradient(32, 32, 2, 32, 32, 30); gr.addColorStop(0, 'rgba(0,0,0,0.55)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, 64, 64); });
    this.shMat = new THREE.MeshBasicMaterial({ map: shT, transparent: true, depthWrite: false });
    this.shGeo = new THREE.PlaneGeometry(1, 1); this.shGeo.rotateX(-Math.PI / 2);
    this.ballSh = new THREE.Mesh(this.shGeo, this.shMat); this.ballSh.position.y = 0.02; s.add(this.ballSh);

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
    for (let i = 0; i < RUN_LINES; i++) {
      const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(RUN_PTS * 3), 3)); g.setDrawRange(0, 0);
      const l = new THREE.Line(g, new THREE.LineBasicMaterial({ color: RUN_COLOR, transparent: true, opacity: 0.85, depthTest: false }));
      l.renderOrder = 13; l.frustumCulled = false; l.visible = false; s.add(l); this.runLines.push(l);
    }
    // duello: anelli verdi sotto i compagni liberi a cui passare
    this.mateRings = [];
    for (let i = 0; i < DUEL_MATES; i++) { const r = this.recv.clone(); r.material = this.recv.material; r.visible = false; s.add(r); this.mateRings.push(r); }

    // linea disegnata
    this.pathMax = 160;
    const pg = new THREE.BufferGeometry();
    pg.setAttribute('position', new THREE.BufferAttribute(new Float32Array(this.pathMax * 2 * 3), 3));
    const idx = []; for (let i = 0; i < this.pathMax - 1; i++) { const a = i * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
    pg.setIndex(idx); pg.setDrawRange(0, 0);
    this.path = new THREE.Mesh(pg, new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.9, depthTest: false, side: THREE.DoubleSide }));
    this.path.renderOrder = 15; this.path.frustumCulled = false; s.add(this.path);
    this.arrow = new THREE.Mesh(new THREE.ConeGeometry(0.55, 1.1, 12), new THREE.MeshBasicMaterial({ color: 0xffffff, depthTest: false })); this.arrow.renderOrder = 16; this.arrow.visible = false; s.add(this.arrow);

    // anteprima della traiettoria vera (puntini azzurri) e linea del fuorigioco (rossa), solo mentre si disegna
    this.prevMax = 80;
    const pvg = new THREE.BufferGeometry();
    pvg.setAttribute('position', new THREE.BufferAttribute(new Float32Array(this.prevMax * 3), 3));
    const dot = canvasTex(32, 32, (g) => { g.fillStyle = '#fff'; g.beginPath(); g.arc(16, 16, 13, 0, 7); g.fill(); });
    this.preview = new THREE.Points(pvg, new THREE.PointsMaterial({ map: dot, color: PREVIEW_COLOR, size: 0.7, sizeAttenuation: true, depthTest: false, transparent: true, alphaTest: 0.3 }));
    this.preview.renderOrder = 17; this.preview.frustumCulled = false; this.preview.visible = false; s.add(this.preview);
    const og = new THREE.PlaneGeometry(W, 0.4); og.rotateX(-Math.PI / 2);
    this.offside = new THREE.Mesh(og, new THREE.MeshBasicMaterial({ color: OFFSIDE_COLOR, transparent: true, opacity: 0.85, depthTest: false }));
    this.offside.renderOrder = 14; this.offside.visible = false; s.add(this.offside);
  }

  // modello 3D dei giocatori (assets 'player'): se manca o non si legge restano le figure a box
  useAssets(assets) {
    if (this.p3d || this.p3dLoading || !assets.has('player')) return this.p3dLoading || Promise.resolve(null);
    this.p3dLoading = loadPlayers3D(assets.get('player')).then((m) => {
      this.p3d = m; this.p3dLoading = null;
      if (m && this.match) this.setMatch(this.match, this.me);
      return m;
    });
    return this.p3dLoading;
  }

  makeFig(kit, look, num, name) {
    if (this.p3d) {
      const f = this.p3d.make(kit, look, { num, name }); f.g.scale.setScalar(SCALE);
      f.sh = new THREE.Mesh(this.shGeo, this.shMat); f.sh.position.y = 0.025; f.sh.scale.set(1.3, 1, 1.3);
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
  }

  // figura di un giocatore della partita: divisa (portiere a parte), aspetto, numero e cognome
  figFor(p) { const kit = this.match.teams[p.team].kit, f = this.makeFig(p.pos === 'P' ? kit.gk : kit, p.look, p.src && p.src.num || p.i + 1, p.src && p.src.name); f.src = p.src; return f; }

  setZoom(z) { this.zoomT = z; }

  update(dt) {
    const m = this.match; if (!m) return;
    const s = this.flip, b = m.ball; this.t += dt;
    // pubblico: si anima quando il pallone si avvicina a una porta e soprattutto dopo un gol
    if (this.stadium) this.stadium.update(dt, m.phase === 'goal' ? 1 : Math.max(0, (Math.abs(b.y) - 25) / 25) * 0.4);
    this.zoom += (this.zoomT - this.zoom) * Math.min(1, dt * 7);
    for (let i = 0; i < 22; i++) {
      const p = m.players[i]; let f = this.figs[i];
      if (f.src !== p.src) { this.scene.remove(f.g); this.scene.remove(f.sh); if (f.m3d) this.p3d.dispose(f); f = this.figs[i] = this.figFor(p); } // cambio: entra un altro giocatore
      this.pose(p, f, dt);
    }
    // palla
    this.ballM.position.set(s * b.x, b.h + 0.21, -s * b.y);
    const sp = Math.hypot(b.vx, b.vy);
    if (sp > 0.2) { this.v3.set(-s * b.vy, 0, -s * b.vx).normalize(); this.ballM.rotateOnWorldAxis(this.v3, -sp * dt / 0.21); }
    const hs = 0.75 + Math.min(b.h, 8) * 0.12; this.ballSh.position.set(s * b.x, 0.03, -s * b.y); this.ballSh.scale.set(hs, 1, hs);
    // anello
    const c = m.ctrl[this.me];
    if (c && !c.off) {
      this.ring.visible = true; this.ring.position.set(s * c.x, 0.04, -s * c.y);
      const k = 1.9 + Math.sin(this.t * 6) * 0.12; this.ring.scale.set(k, 1, k);
      this.marker.visible = true; this.marker.position.set(s * c.x, 2.75 + Math.sin(this.t * 5) * 0.08, -s * c.y);
    } else { this.ring.visible = false; this.marker.visible = false; }
    // duello col difensore: telecamera più bassa e più avanti, compagni liberi evidenziati
    const duel = !!(m.duelFor && m.duelFor(this.me));
    this.duelK = (this.duelK || 0) + ((duel ? 1 : 0) - (this.duelK || 0)) * Math.min(1, dt * 5);
    this.showFreeMates(m, duel);
    this.showRuns(m);
    // telecamera dietro l'azione
    const dir = this.me === 1 ? -1 : 1;
    let fx = b.x, fy = b.y;
    if (m.phase === 'restart' && m.restart) { fx = m.restart.x; fy = m.restart.y; }
    const k = Math.min(1, dt * 4.5);
    this.cx += (fx - this.cx) * k; this.cy += (fy - this.cy) * k;
    // vicino alla porta avversaria la telecamera scende e si avvicina: la porta diventa grande
    const mine = b.owner && b.owner.team === this.me && m.phase !== 'goal';
    const nearT = mine ? Math.max(0, Math.min(1, (this.cy * dir - 14) / 18)) : 0;
    this.near = (this.near || 0) + (nearT - (this.near || 0)) * Math.min(1, dt * 3);
    const a = this.near, z = this.zoom * (1 - 0.75 * a), port = this.w < this.h;
    const back = ((port ? 22 : 26) + z * 10) * (1 - 0.34 * a), hgt = ((port ? 16.5 : 13) + z * 11) * (1 - 0.46 * a), ahead = 9 + z * 4 + a * 9;
    // difesa vicino alla propria porta: inquadratura da dietro la porta, bassa, per leggere i tiri
    const defT = !mine ? Math.max(0, Math.min(1, (-this.cy * dir - 14) / 16)) : 0;
    this.defk = (this.defk || 0) + (defT - (this.defk || 0)) * Math.min(1, dt * 3);
    const dk = this.defk, minY = -HL - 15.5;
    let camY = this.cy * dir - back, hh = hgt, lookY = this.cy * dir + ahead;
    if (camY < minY) { hh += Math.min(6, (minY - camY) * 0.35); camY = minY; }
    camY += (-HL - 12.5 - camY) * dk; hh += (10.5 - hh) * dk; lookY += ((this.cy * dir - HL) / 2 + 3 - lookY) * dk;
    const du = this.duelK; hh *= 1 - DUEL_LOW * du; camY += back * 0.3 * du; lookY += 8 * du;
    // parata: telecamera bassa dietro la propria porta, guarda verso chi tira
    const gkOn = !!(m.diveWin && m.diveWin(this.me) && !(m.autoGk && m.autoGk[this.me]));
    this.gkK = (this.gkK || 0) + ((gkOn ? 1 : 0) - (this.gkK || 0)) * Math.min(1, dt * 6);
    const gk = this.gkK;
    camY += (-HL - GK_CAM_BACK - camY) * gk; hh += (GK_CAM_H - hh) * gk; lookY += (b.y * dir - lookY) * gk;
    const camX = this.cx * dir * (0.82 - 0.3 * a) * (1 - 0.55 * dk) * (1 - 0.8 * gk);
    this.cam.position.set(camX, hh, -camY);
    this.cam.lookAt(this.cx * dir * (0.9 - 0.45 * a) * (1 - 0.45 * dk), 0, -lookY);
    // rete della porta vicina più trasparente
    for (const nm of this.netMats) if (nm.userData.d !== undefined) nm.opacity = (nm.userData.d * s < 0) ? 0.22 : 0.6;
  }

  pose(p, f, dt) {
    const s = this.flip, g = f.g, body = f.body;
    if (p.off) { g.visible = false; f.sh.visible = false; return; }
    g.visible = true; f.sh.visible = true;
    const wx = s * p.fx, wz = -s * p.fy, yaw = Math.atan2(wx, wz);
    g.position.set(s * p.x, 0, -s * p.y); g.rotation.y = yaw;
    f.sh.position.set(s * p.x, 0.025, -s * p.y);
    if (f.m3d) { f.warn.visible = !!p.warn; this.p3d.pose(p, f, dt, { t: this.t, phase: this.match.phase, flip: s, yaw, ball: this.match.ball, scale: SCALE }); return; }
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
      const a = l.geometry.attributes.position.array; let n = 0;
      const put = (x, y) => { a[n * 3] = s * x; a[n * 3 + 1] = 0.08; a[n * 3 + 2] = -s * y; n++; };
      put(r.p.x, r.p.y);
      for (let i = r.i; i < r.path.length && n < RUN_PTS; i++) put(r.path[i].x, r.path[i].y);
      l.geometry.attributes.position.needsUpdate = true; l.geometry.setDrawRange(0, n);
    });
  }
  // i compagni più liberi (lontani dagli avversari) e raggiungibili, sotto un anello verde
  showFreeMates(m, on) {
    const rings = this.mateRings; if (!rings) return;
    let list = [];
    if (on) {
      const c = m.ctrl[this.me];
      for (const p of m.players) {
        if (p.team !== this.me || p.off || p === c || p.pos === 'P') continue;
        const d = Math.hypot(p.x - c.x, p.y - c.y); if (d > 32) continue;
        list.push({ p, free: m.nearOpp(p.x, p.y, p.team) - d * 0.05 });
      }
      list.sort((u, v) => v.free - u.free); list = list.slice(0, DUEL_MATES);
    }
    const s = this.flip;
    rings.forEach((r, i) => { const it = list[i]; r.visible = !!it; if (it) r.position.set(s * it.p.x, 0.05, -s * it.p.y); });
  }

  render() { this.r.render(this.scene, this.cam); }

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
    const s = this.flip, n = Math.min(pts.length, this.pathMax), pos = this.path.geometry.attributes.position.array;
    if (n < 2) { this.clearPath(); return; }
    for (let i = 0; i < n; i++) {
      const a = pts[Math.max(0, i - 1)], c = pts[Math.min(n - 1, i + 1)], p = pts[i];
      let tx = c.x - a.x, ty = c.y - a.y; const l = Math.hypot(tx, ty) || 1; tx /= l; ty /= l;
      const wd = 0.22 + 0.2 * (i / n);
      const nx = -ty * wd, ny = tx * wd, hh = (p.h || 0) + 0.08;
      pos[i * 6] = s * (p.x + nx); pos[i * 6 + 1] = hh; pos[i * 6 + 2] = -s * (p.y + ny);
      pos[i * 6 + 3] = s * (p.x - nx); pos[i * 6 + 4] = hh; pos[i * 6 + 5] = -s * (p.y - ny);
    }
    this.path.geometry.attributes.position.needsUpdate = true;
    this.path.geometry.setDrawRange(0, (n - 1) * 6);
    this.path.visible = true;
    const e = pts[n - 1], q = pts[Math.max(0, n - 3)];
    this.arrow.visible = !shot;
    if (!shot) { this.arrow.position.set(s * e.x, 0.1, -s * e.y); this.v3.set(s * (e.x - q.x), 0, -s * (e.y - q.y)).normalize(); this.arrow.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), this.v3); }
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
    this.offside.visible = offY !== null;
    if (offY !== null) this.offside.position.set(0, 0.05, -s * offY);
  }
  clearPath() { this.path.visible = false; this.arrow.visible = false; this.target.visible = false; this.recv.visible = false; this.preview.visible = false; this.offside.visible = false; }
}
