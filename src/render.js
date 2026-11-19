// Grafica 3D: stadio, giocatori, palla, linea disegnata. Coordinate three: X = x, Y = altezza, Z = -y.
import * as THREE from 'three';
import { W, L, HW, HL, GW, GH, BOX_W, BOX_D, SIX_W, SIX_D, PEN_D, CIRCLE } from './sim.js';

const SKIN = [0xf1c9a5, 0xd9a47a, 0xa9744f, 0x6b4630];
const HAIR = [0x1c1410, 0x4a2f1b, 0x8a5a2b, 0xd9b66a, 0x222222, 0x2b2b2b];
const SCALE = 1.25;

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
    s.background = canvasTex(8, 256, (g, w, h) => { const gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, '#0a1630'); gr.addColorStop(0.55, '#20406e'); gr.addColorStop(1, '#6f95c4'); g.fillStyle = gr; g.fillRect(0, 0, w, h); });
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
    const ground = new THREE.Mesh(new THREE.PlaneGeometry(400, 400), new THREE.MeshLambertMaterial({ color: 0x1d3a22 }));
    ground.rotation.x = -Math.PI / 2; ground.position.y = -0.05; s.add(ground);

    // cartelloni (marchi inventati)
    const words = ['TIRO A GIRO', 'CAFFÈ BORGO', 'GELATERIA STELLA', 'FORNO DEL CORSO', 'RADIO CURVA', 'PIZZERIA DA NINO', 'OFFICINA ROSSI'];
    const cols = ['#0b3d91', '#b3122b', '#0f7a55', '#e0a100', '#5b2a86', '#c44e00', '#14606e'];
    const adTex = canvasTex(2048, 64, (g, w, h) => {
      let x = 0, i = 0; g.font = 'bold 40px system-ui, sans-serif'; g.textBaseline = 'middle';
      while (x < w) { const tw = 292; g.fillStyle = cols[i % cols.length]; g.fillRect(x, 0, tw, h); g.fillStyle = '#fff'; g.textAlign = 'center'; g.fillText(words[i % words.length], x + tw / 2, h / 2 + 2, tw - 20); x += tw; i++; }
    });
    adTex.wrapS = THREE.RepeatWrapping;
    const adMat = new THREE.MeshBasicMaterial({ map: adTex });
    const ad = (len, x, z, ry) => { const t = adTex.clone(); t.repeat.x = len / 70; t.needsUpdate = true; const m = new THREE.Mesh(new THREE.PlaneGeometry(len, 1.1), new THREE.MeshBasicMaterial({ map: t })); m.position.set(x, 0.55, z); m.rotation.y = ry; s.add(m); };
    ad(L + 10, -HW - 5, 0, Math.PI / 2); ad(L + 10, HW + 5, 0, -Math.PI / 2);
    ad(W + 10, 0, -HL - 6.5, 0);

    // tribune
    const crowd = canvasTex(512, 256, (g, w, h) => {
      g.fillStyle = '#1a2233'; g.fillRect(0, 0, w, h);
      const cc = ['#d94b4b', '#e8e8e8', '#3d7bd9', '#f0c23c', '#2f2f38', '#58b368', '#e88a3c', '#c9c9d4', '#8a5ad6'];
      for (let y = 0; y < h; y += 8) for (let x = (y / 8) % 2 * 3; x < w; x += 6) {
        if (Math.random() < 0.12) continue;
        g.fillStyle = cc[(Math.random() * cc.length) | 0]; g.fillRect(x, y + 3, 4, 5);
        g.fillStyle = SKINC[(Math.random() * 4) | 0]; g.fillRect(x + 1, y, 2, 3);
      }
    });
    crowd.wrapS = crowd.wrapT = THREE.RepeatWrapping;
    this.crowdMats = [];
    const stand = (len, x, z, ry, far) => {
      const t = crowd.clone(); t.repeat.set(len / 26, 1.6); t.needsUpdate = true;
      const mat = new THREE.MeshBasicMaterial({ map: t, color: 0xb8c0cc });
      const m = new THREE.Mesh(new THREE.PlaneGeometry(len, 24), mat);
      m.rotation.order = 'YXZ'; m.rotation.y = ry; m.rotation.x = -0.62;
      m.position.set(x, 8.5, z); s.add(m);
      const roof = new THREE.Mesh(new THREE.BoxGeometry(len, 0.6, 12), new THREE.MeshLambertMaterial({ color: 0x1b2433 }));
      roof.rotation.y = ry; const k = far ? 1 : 1;
      roof.position.set(x + Math.sin(ry) * -9 * k, 19.5, z + Math.cos(ry) * -9 * k); s.add(roof);
      const base = new THREE.Mesh(new THREE.PlaneGeometry(len, 3), new THREE.MeshLambertMaterial({ color: 0x232c3d }));
      base.rotation.y = ry; base.position.set(x + Math.sin(ry) * 8.6, 1.2, z + Math.cos(ry) * 8.6); s.add(base);
      this.crowdMats.push(mat);
      return m;
    };
    stand(L + 50, -HW - 17, 0, Math.PI / 2); stand(L + 50, HW + 17, 0, -Math.PI / 2);
    stand(W + 60, 0, -HL - 19, 0);
    this.backStand = stand(W + 60, 0, HL + 30, Math.PI);
    // torri faro
    for (const [x, z] of [[-HW - 26, -HL - 26], [HW + 26, -HL - 26]]) {
      const p = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.7, 34), new THREE.MeshLambertMaterial({ color: 0x556070 })); p.position.set(x, 17, z); s.add(p);
      const l = new THREE.Mesh(new THREE.BoxGeometry(7, 4, 0.6), new THREE.MeshBasicMaterial({ color: 0xfff6d8 })); l.position.set(x, 35, z); l.lookAt(0, 0, 0); s.add(l);
    }

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

    // linea disegnata
    this.pathMax = 160;
    const pg = new THREE.BufferGeometry();
    pg.setAttribute('position', new THREE.BufferAttribute(new Float32Array(this.pathMax * 2 * 3), 3));
    const idx = []; for (let i = 0; i < this.pathMax - 1; i++) { const a = i * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
    pg.setIndex(idx); pg.setDrawRange(0, 0);
    this.path = new THREE.Mesh(pg, new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.9, depthTest: false, side: THREE.DoubleSide }));
    this.path.renderOrder = 15; this.path.frustumCulled = false; s.add(this.path);
    this.arrow = new THREE.Mesh(new THREE.ConeGeometry(0.55, 1.1, 12), new THREE.MeshBasicMaterial({ color: 0xffffff, depthTest: false })); this.arrow.renderOrder = 16; this.arrow.visible = false; s.add(this.arrow);
  }

  makeFig(kit, look) {
    const g = new THREE.Group(), body = new THREE.Group(); g.add(body);
    const M = c => new THREE.MeshLambertMaterial({ color: c });
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
    for (const f of this.figs) { this.scene.remove(f.g); this.scene.remove(f.sh); }
    this.figs = []; this.match = match; this.me = me; this.flip = me === 1 ? -1 : 1;
    if (!match) return;
    for (const p of match.players) {
      const kit = match.teams[p.team].kit;
      this.figs.push(this.makeFig(p.pos === 'P' ? kit.gk : kit, p.look));
    }
    const b = match.ball; this.cx = b.x; this.cy = b.y;
    this.backStand.visible = true;
  }

  setZoom(z) { this.zoomT = z; }

  update(dt) {
    const m = this.match; if (!m) return;
    const s = this.flip, b = m.ball; this.t += dt;
    this.zoom += (this.zoomT - this.zoom) * Math.min(1, dt * 7);
    for (let i = 0; i < 22; i++) this.pose(m.players[i], this.figs[i], dt);
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
    const camX = this.cx * dir * (0.82 - 0.3 * a) * (1 - 0.55 * dk);
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
  clearPath() { this.path.visible = false; this.arrow.visible = false; this.target.visible = false; this.recv.visible = false; }
}
const SKINC = ['#f1c9a5', '#d9a47a', '#a9744f', '#6b4630'];
