// Visuale girata col dito nel rallenty in attacco (src/camuser.js) e gesti collegati (src/input.js):
// angolo che segue il dito, limiti, ritorno dolce, nessun passaggio col tocco su un compagno.
import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import {
  userCamOn, dragYaw, isCamDrag, relaxYaw, keepGoal,
  CAM_USER_DEG_PER_SCREEN, CAM_USER_MAX, CAM_USER_START, CAM_USER_GOAL_YAW,
} from '../../src/camuser.js';
import { wideView, WIDE_MARGIN } from '../../src/camfit.js';
import { Input } from '../../src/input.js';

const DEG = Math.PI / 180, W = 390, H = 844;

test('trascinando per tutto lo schermo la visuale gira di CAM_USER_DEG_PER_SCREEN gradi', () => {
  // 150° per schermo: con il limite a 100° basta 2/3 di schermo per arrivare in fondo
  assert.equal(dragYaw(0, -W, W), Math.min(CAM_USER_MAX, CAM_USER_DEG_PER_SCREEN * DEG));
  // mezzo schermo = metà angolo (75°), dentro il limite
  assert.ok(Math.abs(dragYaw(0, -W / 2, W) - CAM_USER_DEG_PER_SCREEN / 2 * DEG) < 1e-9);
});

test('si afferra il campo: dito verso destra = la visuale guarda più a sinistra, e viceversa', () => {
  assert.ok(dragYaw(0, 80, W) < 0);
  assert.ok(dragYaw(0, -80, W) > 0);
  assert.equal(dragYaw(0, 0, W), 0);
});

test('angolo entro ±CAM_USER_MAX, partendo da quello già scelto', () => {
  assert.equal(dragYaw(0, -5 * W, W), CAM_USER_MAX);
  assert.equal(dragYaw(0, 5 * W, W), -CAM_USER_MAX);
  const y0 = 30 * DEG;
  assert.ok(Math.abs(dragYaw(y0, -W / 10, W) - (y0 + CAM_USER_DEG_PER_SCREEN / 10 * DEG)) < 1e-9);
  assert.ok(Math.abs(CAM_USER_MAX - 100 * DEG) < 1e-9);
});

test('il gesto parte solo con uno spostamento di lato abbastanza lungo', () => {
  assert.equal(isCamDrag(CAM_USER_START - 1, 0), false); // tocco
  assert.equal(isCamDrag(CAM_USER_START, 0), true);
  assert.equal(isCamDrag(-40, 10), true);
  assert.equal(isCamDrag(20, 40), false); // più in verticale che di lato
});

test('nel rallenty l\'angolo resta; finito torna dolcemente a 0 in circa un secondo e mezzo', () => {
  assert.equal(relaxYaw(0.8, true, 0.1), 0.8);
  assert.equal(relaxYaw(5, true, 0.1), CAM_USER_MAX);
  let y = 1.2, prev = y, t = 0;
  while (y !== 0 && t < 5) { y = relaxYaw(y, false, 1 / 60); assert.ok(Math.abs(y) <= Math.abs(prev)); prev = y; t += 1 / 60; }
  assert.equal(y, 0);
  assert.ok(t > 0.8 && t < 3.5, `ritorno in ${t.toFixed(2)} s`);
  // a metà strada è ancora girata (niente scatto)
  assert.ok(relaxYaw(1.2, false, 0.1) > 0.8);
});

test('rallenty con visuale girabile: solo in gioco, col pallone nostro, nel duello o nell\'area di tiro', () => {
  const c = { team: 0 };
  const m = (o) => ({ phase: 'play', ball: { owner: c }, duelFor: () => false, inZone: () => false, ...o });
  assert.equal(userCamOn(m({ duelFor: T => T === 0 }), 0), true);
  assert.equal(userCamOn(m({ inZone: T => T === 0 }), 0), true);
  assert.equal(userCamOn(m({}), 0), false);
  assert.equal(userCamOn(m({ duelFor: () => true, phase: 'restart' }), 0), false);
  assert.equal(userCamOn(m({ duelFor: () => true, ball: { owner: { team: 1 } } }), 0), false);
  assert.equal(userCamOn(m({ duelFor: () => true, ball: { owner: null } }), 0), false);
  assert.equal(userCamOn(null, 0), false);
});

test('area di tiro: la porta si tiene a schermo solo con la visuale poco girata', () => {
  assert.equal(keepGoal(true, 0), true);
  assert.equal(keepGoal(true, CAM_USER_GOAL_YAW * 0.9), true);
  assert.equal(keepGoal(true, -CAM_USER_GOAL_YAW * 1.1), false);
  assert.equal(keepGoal(false, 0), false);
});

// telecamera three come in render.js: spazio orientato [x, h, y] → mondo (x, h, −y)
function inFrame(v, p, m) {
  const c = new THREE.PerspectiveCamera(v.fov, W / H, 0.5, 600);
  c.position.set(v.pos[0], v.pos[1], -v.pos[2]); c.lookAt(v.look[0], v.look[1], -v.look[2]);
  c.updateMatrixWorld(); c.updateProjectionMatrix();
  const q = new THREE.Vector3(p[0], p[1], -p[2]).project(c);
  return q.z < 1 && q.x >= -1 + m.l - 0.01 && q.x <= 1 - m.r + 0.01 && q.y >= -1 + m.b - 0.01 && q.y <= 1 - m.t + 0.01;
}

for (const deg of [-100, -60, -30, 0, 30, 60, 100]) {
  for (const zone of [false, true]) {
    test(`visuale larga girata di ${deg}° (${zone ? 'area di tiro' : 'duello'}): il portatore resta a schermo`, () => {
      const yaw = deg * DEG, carrier = zone ? [6, 34] : [-10, 0];
      const mates = [[carrier[0] - 20, carrier[1] + 4], [carrier[0] + 18, carrier[1] + 2], [carrier[0] + 4, carrier[1] + 12]];
      const v = wideView({ carrier, yaw, mates, goal: keepGoal(zone, yaw), aspect: W / H, fov: 70 });
      assert.ok(v.ok, 'inquadratura impossibile');
      assert.ok(inFrame(v, [carrier[0], 0, carrier[1]], WIDE_MARGIN) && inFrame(v, [carrier[0], 2.3, carrier[1]], WIDE_MARGIN), 'portatore fuori');
    });
  }
}

// ---------------------------------------------------------------- gesti (src/input.js) con una visuale finta
// schermo: x = 195 + 6·x, y = 600 − 6·y (portatore in basso, campo davanti in alto)
function fakeView() {
  return {
    w: W, h: H, flip: 1, userYaw: 0, camDrag: false, path: null,
    worldToScreen: (x, y) => ({ x: 195 + 6 * x, y: 600 - 6 * y, vis: true }),
    screenToGround: (px, py) => ({ x: (px - 195) / 6, y: (600 - py) / 6 }),
    screenToGoal: () => null,
    setPath(p) { this.path = p; }, clearPath() { this.path = null; }, setPreview() { },
  };
}
function fakeMatch({ duel = true, phase = 'play', hint = 'attack' } = {}) {
  const c = { i: 7, team: 0, x: 0, y: 0, vx: 0, vy: 0 }, mate = { i: 9, team: 0, x: 15, y: 20, vx: 0, vy: 0 };
  return {
    c, mate, phase, ball: { owner: c, x: 0, y: 0.4, h: 0 }, ctrl: [c, null], players: [c, mate], restart: phase === 'restart' ? { type: 'throw' } : null,
    hint: () => hint, duelFor: T => duel && T === 0, inZone: () => false, passFor: T => duel && T === 0,
    predictKick: () => [], offsideY: () => 0,
  };
}
function setup(o) {
  const calls = [], view = fakeView(), m = fakeMatch(o);
  const el = { addEventListener() { }, getBoundingClientRect: () => ({ left: 0, top: 0 }), setPointerCapture() { } };
  const out = {};
  for (const k of ['kick', 'move', 'stop', 'dive', 'sw', 'path', 'run']) out[k] = (...a) => calls.push([k, ...a]);
  const inp = new Input(el, view, out); inp.set(m, 0); inp.enabled = true;
  const ev = (x, y) => ({ clientX: x, clientY: y, pointerId: 1, preventDefault() { } });
  const drag = (pts) => { inp.down(ev(...pts[0])); for (const p of pts.slice(1)) inp.moveEv(ev(...p)); inp.up(ev(...pts[pts.length - 1])); };
  return { inp, view, m, calls, drag, ev };
}
const line = (a, b, n = 10) => Array.from({ length: n + 1 }, (_, i) => [a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n]);

test('duello: trascinando di lato lontano dal portatore la visuale gira e il giocatore non riceve ordini', () => {
  const { view, calls, drag } = setup();
  drag(line([100, 250], [300, 250]));
  assert.ok(view.userYaw < -0.5, `angolo ${view.userYaw}`);
  assert.equal(view.camDrag, false); // dito alzato
  assert.deepEqual(calls, []);
});

test('duello: tocco breve su un compagno o sul campo non fa niente (il passaggio si disegna)', () => {
  const { view, calls, drag, m } = setup();
  const s = view.worldToScreen(m.mate.x, m.mate.y);
  drag([[s.x, s.y]]);
  drag([[60, 200]]);
  assert.deepEqual(calls, []);
  assert.equal(view.userYaw, 0);
});

test('duello: la linea disegnata dal portatore fino al compagno è un passaggio, e non gira mai la visuale', () => {
  const { view, calls, drag, m } = setup();
  const a = view.worldToScreen(0, 0), e = view.worldToScreen(m.mate.x, m.mate.y);
  drag(line([a.x, a.y], [e.x, e.y], 20));
  assert.equal(calls.length, 1);
  assert.equal(calls[0][0], 'kick');
  assert.ok(Math.hypot(calls[0][1].tx - m.mate.x, calls[0][1].ty - m.mate.y) < 0.5);
  assert.equal(view.userYaw, 0);
});

test('rimessa: tocco breve su un compagno non passa (nessun ordine); la linea sì', () => {
  const { view, calls, drag, m } = setup({ duel: false, phase: 'restart', hint: 'restart' });
  const s = view.worldToScreen(m.mate.x, m.mate.y);
  drag([[s.x, s.y]]);
  assert.deepEqual(calls, []);
  const a = view.worldToScreen(0, 0);
  drag(line([a.x, a.y], [s.x, s.y], 20));
  assert.equal(calls.length, 1);
  assert.equal(calls[0][0], 'kick');
});

test('fuori dal rallenty il trascinamento resta "muovi il giocatore" (nessuna rotazione)', () => {
  const { inp, view, ev } = setup({ duel: false });
  inp.down(ev(100, 250)); for (const p of line([100, 250], [300, 250])) inp.moveEv(ev(...p));
  assert.equal(inp.mode, 'move');
  assert.equal(view.userYaw, 0);
  inp.up(ev(300, 250));
});

test('in difesa il tocco su un compagno lo fa ancora comandare', () => {
  const { view, calls, drag, m } = setup({ duel: false, hint: 'defend' });
  m.ball.owner = { team: 1 };
  m.mate.pos = 'P'; // il portiere non ha linee: il tocco passa dal ramo "move"
  const s = view.worldToScreen(m.mate.x, m.mate.y);
  drag([[s.x, s.y]]);
  assert.deepEqual(calls.map(c => c[0]), ['sw']);
});
