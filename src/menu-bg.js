// Sfondo del menu principale (schermata iniziale e hub): il campione della carriera, in trasparenza, che si allena
// (palleggi, giochetti, corsa palla al piede, tiro: sequenza in src/menu-routine.js). Piccolo renderer three.js
// dedicato in un canvas fisso dietro al menu, acceso solo su quelle schermate (al posto della partita dimostrativa).
import * as THREE from 'three';
import { loadBestPlayers } from './athlete3d.js';
import { normalizeLook } from './looks.js';
import { ballTexture } from './props.js';
import { menuRoutine } from './menu-routine.js';

const FIG_S = 1.25;                 // scala della figura (come l'anteprima dell'editor)
const BALL_R = 0.11;                // raggio vero del pallone (m)
const YAW = 0.55;                   // tre quarti: si vedono viso, gambe e pallone
const CAM = { y: 1.45, z: 7.2, look: 1.2, fov: 30 };
const TEX = 512;
const MAX_DT = 0.05;

export class MenuBg {
  constructor(host, assets) { this.host = host; this.assets = assets; this.view = null; this.key = ''; this.want = null; }

  // who = { kit, look, num, name } o null; acceso = canvas visibile e animato
  show(who) {
    this.want = who;
    this.host.style.display = 'block';
    if (!this.view) this.view = new Stage(this.host.querySelector('canvas'));
    const view = this.view;
    // il modello sta nella tappa 'match': si scarica in sottofondo, il menu intanto è già usabile
    const a = this.assets;
    if (!this.ready) this.ready = (a && a.loadStage ? a.loadStage('match').then(() => loadBestPlayers(a)) : Promise.resolve(null)).catch(() => null);
    this.ready.then(p3d => { if (this.view === view && p3d) { view.p3d = p3d; view.setPlayer(this.want); } });
  }
  hide() {
    this.host.style.display = 'none';
    if (this.view) { this.view.dispose(); this.view = null; }
  }
}

class Stage {
  constructor(canvas) {
    this.cv = canvas;
    this.r = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
    this.r.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.scene = new THREE.Scene();
    this.scene.add(new THREE.HemisphereLight(0xeef4ff, 0x40506a, 1.6));
    const sun = new THREE.DirectionalLight(0xffffff, 1.7); sun.position.set(2, 4, 3); this.scene.add(sun);
    const back = new THREE.DirectionalLight(0x9ec5ff, 0.8); back.position.set(-3, 2, -3); this.scene.add(back);
    const disc = new THREE.Mesh(new THREE.CircleGeometry(1.0, 40), new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.3 }));
    disc.rotation.x = -Math.PI / 2; disc.position.y = 0.002; this.scene.add(disc);
    this.ball = new THREE.Mesh(new THREE.SphereGeometry(BALL_R * FIG_S, 20, 14), new THREE.MeshPhongMaterial({ map: ballTexture(), specular: 0x5a5a5a, shininess: 70 }));
    this.ball.visible = false; this.scene.add(this.ball);
    this.cam = new THREE.PerspectiveCamera(CAM.fov, 1, 0.05, 80);
    this.st = { vx: 0, vy: 0, state: 'play', cele: 0, kickAnim: 0, pos: 'A', i: 0, x: 0, y: 0 };
    this.t = 0; this.fig = null; this.key = '';
    this.last = performance.now();
    const loop = now => { if (!this.r) return; this.raf = requestAnimationFrame(loop); this.tick(Math.min(MAX_DT, (now - this.last) / 1000)); this.last = now; };
    this.raf = requestAnimationFrame(loop);
  }
  setPlayer(who) {
    if (!this.p3d || !who) return;
    const key = JSON.stringify(who); if (key === this.key) return; this.key = key;
    if (this.fig) { this.scene.remove(this.fig.g); this.p3d.dispose(this.fig); }
    this.fig = this.p3d.make(who.kit, normalizeLook(who.look), { num: who.num, name: who.name, tex: TEX });
    this.fig.g.scale.setScalar(FIG_S); this.fig.g.rotation.y = YAW; this.scene.add(this.fig.g);
    this.t = 0;
  }
  tick(dt) {
    const w = this.cv.clientWidth, h = this.cv.clientHeight; if (!w || !h) return;
    if (this.cv.width !== Math.round(w * this.r.getPixelRatio())) { this.r.setSize(w, h, false); this.cam.aspect = w / h; this.cam.updateProjectionMatrix(); }
    this.t += dt;
    const R = menuRoutine(this.t), fx = Math.sin(YAW), fz = Math.cos(YAW);
    if (this.fig) {
      const st = this.st; st.vx = R.vx; st.kickAnim = R.kickAnim;
      this.p3d.pose(st, this.fig, dt, { t: this.t, phase: 'menu', flip: 1, yaw: 0, ball: null, scale: FIG_S, trick: R.trick });
      // palleggio: coscia su e ginocchio piegato sul tocco (dopo la posa: si annulla da solo alla posa successiva)
      if (R.leg && R.leg.lift > 0) {
        const L = R.leg.side > 0 ? 'Right' : 'Left';
        this.p3d.rot(this.fig, L + 'UpLeg', 0, -0.95 * R.leg.lift); this.p3d.rot(this.fig, L + 'Leg', 0, 0.7 * R.leg.lift);
      }
      const b = R.ball; this.ball.visible = b.visible;
      this.ball.position.set((fx * b.f + fz * b.s) * FIG_S, (b.h + BALL_R) * FIG_S, (fz * b.f - fx * b.s) * FIG_S);
      this.ball.rotation.x += dt * (R.seg === 'run' ? 9 : 3);
    }
    this.cam.position.set(0, CAM.y, CAM.z); this.cam.lookAt(0, CAM.look, 0);
    this.r.render(this.scene, this.cam);
  }
  dispose() {
    cancelAnimationFrame(this.raf);
    if (this.fig && this.p3d) this.p3d.dispose(this.fig);
    if (this.r) { this.r.dispose(); if (this.r.forceContextLoss) this.r.forceContextLoss(); this.r = null; }
  }
}
