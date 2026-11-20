// Sfondo del menu principale (schermata iniziale e hub): il campione della carriera, in trasparenza, che si allena
// (palleggi, giochetti, corsa palla al piede, tiro: sequenza in src/menu-routine.js). Piccolo renderer three.js
// dedicato in un canvas fisso dietro al menu, acceso solo su quelle schermate (al posto della partita dimostrativa).
// Il corpo va nella posa dei movimenti calcolati (src/move-pose.js) sopra il clip; giocatore e pallone stanno nello
// stesso gruppo (girato di tre quarti e in scala), così il pallone è nelle stesse misure del corpo.
import * as THREE from 'three';
import { loadBestPlayers } from './athlete3d.js';
import { normalizeLook } from './looks.js';
import { ballTexture } from './props.js';
import { menuRoutine } from './menu-routine.js';
import { applyMove } from './move-pose.js';

const FIG_S = 1.25;                 // scala della figura (come l'anteprima dell'editor)
const BALL_R = 0.11;                // raggio vero del pallone (m)
const YAW = 0.55;                   // tre quarti: si vedono viso, gambe e pallone
const CAM = { y: 1.45, z: 7.2, look: 1.2, fov: 30 };
const TEX = 512;
const MAX_DT = 0.05;

export class MenuBg {
  constructor(host, assets) {
    this.host = host; this.assets = assets; this.view = null; this.key = ''; this.want = null;
    if (typeof window !== 'undefined') window.__menuBg = this; // per le prove a schermo (test/menu-anim-shot.mjs)
  }

  // who = { kit, look, num, name } o null; acceso = canvas visibile e animato
  show(who) {
    this.want = who;
    this.host.style.display = 'block';
    if (!this.view) {
      // canvas sempre nuovo: quello vecchio ha il contesto WebGL perso apposta (forceContextLoss) e non si riusa
      const old = this.host.querySelector('canvas'), cv = document.createElement('canvas');
      cv.setAttribute('aria-hidden', 'true');
      if (old) old.replaceWith(cv); else this.host.appendChild(cv);
      this.view = new Stage(cv);
    }
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
    // gruppo del giocatore: tre quarti e scala; dentro, la figura e il pallone (misure del corpo)
    this.root = new THREE.Group(); this.root.rotation.y = YAW; this.root.scale.setScalar(FIG_S); this.scene.add(this.root);
    this.ball = new THREE.Mesh(new THREE.SphereGeometry(BALL_R, 20, 14), new THREE.MeshPhongMaterial({ map: ballTexture(), specular: 0x5a5a5a, shininess: 70 }));
    this.ball.visible = false; this.root.add(this.ball);
    // ombra del pallone: più piccola e chiara quando sale (si legge l'altezza)
    this.bsh = new THREE.Mesh(new THREE.CircleGeometry(BALL_R * 1.1, 20), new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.35, depthWrite: false }));
    this.bsh.rotation.x = -Math.PI / 2; this.bsh.position.y = 0.004; this.root.add(this.bsh);
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
    if (this.fig) { this.root.remove(this.fig.g); this.p3d.dispose(this.fig); }
    this.fig = this.p3d.make(who.kit, normalizeLook(who.look), { num: who.num, name: who.name, tex: TEX });
    this.root.add(this.fig.g);
    this.t = 0;
  }
  tick(dt) {
    const w = this.cv.clientWidth, h = this.cv.clientHeight; if (!w || !h) return;
    if (this.cv.width !== Math.round(w * this.r.getPixelRatio())) { this.r.setSize(w, h, false); this.cam.aspect = w / h; this.cam.updateProjectionMatrix(); }
    this.t = this.hold != null ? this.hold : this.t + dt; // hold: tempo fermo per le prove a schermo
    const R = menuRoutine(this.t);
    if (this.fig) {
      const st = this.st; st.vx = R.vx; st.kickAnim = 0;
      this.p3d.pose(st, this.fig, dt, { t: this.t, phase: 'menu', flip: 1, yaw: 0, ball: null, scale: FIG_S, trick: null });
      // posa calcolata sopra il clip (si annulla da sola alla posa successiva)
      if (R.frame && R.w > 0) applyMove(this.p3d, this.fig, R.frame, { w: R.w });
      const b = R.ball; this.ball.visible = b.vis; this.bsh.visible = b.vis;
      this.ball.position.set(b.p[0], b.p[1], b.p[2]); this.ball.quaternion.set(b.q[0], b.q[1], b.q[2], b.q[3]);
      const hk = Math.max(0, b.p[1] - BALL_R);
      this.bsh.position.set(b.p[0], 0.004, b.p[2]); this.bsh.scale.setScalar(1 + hk * 0.5); this.bsh.material.opacity = 0.35 / (1 + hk * 1.5);
    }
    const dc = this.dbgCam; // telecamera di prova (primo piano), altrimenti quella del menu
    if (dc) { this.cam.position.set(...dc.pos); this.cam.lookAt(...dc.look); } else { this.cam.position.set(0, CAM.y, CAM.z); this.cam.lookAt(0, CAM.look, 0); }
    this.r.render(this.scene, this.cam);
  }
  dispose() {
    cancelAnimationFrame(this.raf);
    if (this.fig && this.p3d) this.p3d.dispose(this.fig);
    if (this.r) { this.r.dispose(); if (this.r.forceContextLoss) this.r.forceContextLoss(); this.r = null; }
  }
}
