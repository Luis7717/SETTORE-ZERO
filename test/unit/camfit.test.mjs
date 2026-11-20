// Inquadratura calcolata (src/camfit.js): con la telecamera three messa come fa render.js (posizione, lookAt, fov),
// pali, traversa, portiere, pallone e compagni stanno dentro lo schermo coi margini.
import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import { saveView, wideView, fitView, goalCorners, cornerView, SAVE_MARGIN, WIDE_MARGIN, CORNER_MARGIN, SAVE_MAX_BACK, WIDE_R } from '../../src/camfit.js';
import { HL, GW, GH } from '../../src/sim/core.js';

const ASPECT = 390 / 844, FOV = 70;

// telecamera three come in render.js: spazio orientato [x, h, y] → mondo (x, h, −y)
function cam(v) {
  const c = new THREE.PerspectiveCamera(v.fov, ASPECT, 0.5, 600);
  c.position.set(v.pos[0], v.pos[1], -v.pos[2]);
  c.lookAt(v.look[0], v.look[1], -v.look[2]);
  c.updateMatrixWorld(); c.updateProjectionMatrix();
  return c;
}
// punto [x, h, y] a schermo: dentro il riquadro coi margini (tolleranza piccola per gli arrotondamenti)
function inFrame(c, p, m, eps = 0.01) {
  const v = new THREE.Vector3(p[0], p[1], -p[2]).project(c);
  return v.z < 1 && v.x >= -1 + m.l - eps && v.x <= 1 - m.r + eps && v.y >= -1 + m.b - eps && v.y <= 1 - m.t + eps;
}

const SHOTS = {
  'centrale vicino': [0, 0.4, -39], 'centrale da 25 m': [0, 0.4, -25], 'angolato sinistra': [-14, 0.6, -33],
  'angolato destra': [14, 0.6, -33], 'molto laterale': [27, 0.3, -44], 'dal fondo': [30, 0.2, -48.5], 'pallonetto': [5, 6, -30],
};

for (const [name, ball] of Object.entries(SHOTS)) {
  test(`parata, tiro ${name}: porta intera, portiere e pallone a schermo`, () => {
    const keeper = [ball[0] * 0.15, -HL + 0.6];
    const v = saveView({ ball, keeper, aspect: ASPECT, fov: FOV });
    const c = cam(v);
    for (const p of goalCorners()) assert.ok(inFrame(c, p, SAVE_MARGIN), `angolo della porta ${p} fuori`);
    for (const p of [[-GW / 2, 0, -HL], [GW / 2, 0, -HL], [-GW / 2, GH, -HL], [GW / 2, GH, -HL]]) assert.ok(inFrame(c, p, SAVE_MARGIN), `palo/traversa ${p} fuori`);
    assert.ok(inFrame(c, [keeper[0], 0, keeper[1]], SAVE_MARGIN) && inFrame(c, [keeper[0], 2, keeper[1]], SAVE_MARGIN), 'portiere fuori');
    assert.ok(inFrame(c, ball, SAVE_MARGIN), 'pallone fuori');
    assert.equal(v.used, 3);
    // dietro la porta, non oltre il limite (tribuna), sopra l'erba
    assert.ok(v.pos[2] < -HL - 1 && v.pos[2] >= -HL - SAVE_MAX_BACK - 0.01, `telecamera a y ${v.pos[2]}`);
    assert.ok(v.pos[1] > 1);
  });
}

test('parata: la telecamera si gira verso il lato del tiro', () => {
  const l = saveView({ ball: [-14, 0.5, -33], keeper: [0, -49.4], aspect: ASPECT, fov: FOV });
  const r = saveView({ ball: [14, 0.5, -33], keeper: [0, -49.4], aspect: ASPECT, fov: FOV });
  assert.ok(l.yaw < 0 && r.yaw > 0);
  assert.ok(Math.abs(l.pos[0] + r.pos[0]) < 1e-6, 'simmetrica');
});

const WIDE = {
  'duello, compagni davanti e di fianco': [[-6, -10], [[4, 18], [-6, 22], [-18, 6], [20, 8]], false],
  'duello sulla fascia': [[-22, 5], [[14, 0], [30, 20], [8, 26], [0, -14]], false],
  'area di tiro': [[6, 34], [[-14, 8], [6, -8], [-6, 10]], true],
  'corsa da centrocampo': [[4, -14], [[8, 22], [-10, 18], [-16, 10]], false],
};
for (const [name, [carrier, rel, goal]] of Object.entries(WIDE)) {
  test(`rallenty largo, ${name}: portatore sempre dentro, compagni tenuti dentro, porta nell'area di tiro`, () => {
    const mates = rel.map(q => [carrier[0] + q[0], carrier[1] + q[1]]);
    const v = wideView({ carrier, mates, goal, aspect: ASPECT, fov: FOV });
    const c = cam(v);
    assert.ok(inFrame(c, [carrier[0], 0, carrier[1]], WIDE_MARGIN) && inFrame(c, [carrier[0], 2.3, carrier[1]], WIDE_MARGIN), 'portatore fuori');
    if (goal) for (const p of goalCorners(HL, 0.5, 0.3)) assert.ok(inFrame(c, p, WIDE_MARGIN), 'porta avversaria fuori');
    // quanti compagni (entro 35 m, davanti o di fianco) sono a schermo: devono essere tutti quelli tenuti dal calcolo
    const cand = mates.filter(q => Math.hypot(q[0] - carrier[0], q[1] - carrier[1]) <= WIDE_R && q[1] - carrier[1] >= -5);
    const seen = cand.filter(q => inFrame(c, [q[0], 0, q[1]], WIDE_MARGIN) && inFrame(c, [q[0], 1.9, q[1]], WIDE_MARGIN));
    assert.equal(seen.length, v.used - 1 - (goal ? 1 : 0), 'compagni tenuti = compagni a schermo');
    assert.ok(seen.length >= Math.min(3, cand.length), `solo ${seen.length} compagni a schermo su ${cand.length}`);
  });
}

test('rallenty largo: un compagno 25 m di fianco sulla stessa linea resta fuori (il portatore diventerebbe minuscolo)', () => {
  const v = wideView({ carrier: [0, 0], mates: [[25, 2], [6, 18]], aspect: ASPECT, fov: FOV });
  assert.equal(v.used, 2); // portatore + il compagno davanti
  const c = cam(v);
  assert.ok(inFrame(c, [0, 0, 0], WIDE_MARGIN) && inFrame(c, [6, 0, 18], WIDE_MARGIN));
});

test('rallenty largo: compagni più larghi = telecamera più lontana o campo visivo più largo', () => {
  const near = wideView({ carrier: [0, 0], mates: [[2, 10]], aspect: ASPECT, fov: FOV });
  const far = wideView({ carrier: [0, 0], mates: [[2, 10], [-14, 16], [15, 20]], aspect: ASPECT, fov: FOV });
  assert.equal(far.used, 4);
  assert.ok(far.t > near.t || far.fov > near.fov);
});

test('fitView: un gruppo impossibile si salta, quelli dopo si tengono', () => {
  const v = fitView({
    c0: [0, 10, -20], yaw: 0, pitch: 0.5, aspect: ASPECT, fov: FOV, fovMax: 80, tMax: 5, m: WIDE_MARGIN,
    groups: [[[0, 0, 0]], [[200, 0, 0]], [[3, 0, 10]]],
  });
  assert.equal(v.used, 2);
  const c = cam(v);
  assert.ok(inFrame(c, [0, 0, 0], WIDE_MARGIN) && inFrame(c, [3, 0, 10], WIDE_MARGIN));
  assert.ok(!inFrame(c, [200, 0, 0], WIDE_MARGIN));
});

// calcio d'angolo: telecamera alle spalle del battitore (fuori dal campo, oltre la bandierina), guarda verso l'area;
// battitore e porta intera a schermo, da tutte e quattro le bandierine
for (const [bx, by] of [[32, 50], [-32, 50], [32, -50], [-32, -50]]) {
  test(`calcio d'angolo da (${bx}, ${by}): dietro il battitore, battitore e porta a schermo`, () => {
    const v = cornerView({ ball: [bx, by], aspect: ASPECT, fov: FOV });
    const c = cam(v), gy = Math.sign(by) * HL;
    // dietro la bandierina: più lontano dal centro dell'area del battitore, e fuori dal campo
    const aim = [0, gy - Math.sign(by) * 9];
    assert.ok(Math.hypot(v.pos[0] - aim[0], v.pos[2] - aim[1]) > Math.hypot(bx - aim[0], by - aim[1]) + 3);
    assert.ok(Math.abs(v.pos[0]) > 32 || Math.abs(v.pos[2]) > 50, 'fuori dal campo');
    // guarda verso l'area: il punto guardato è più vicino al centro dell'area del battitore
    assert.ok(Math.hypot(v.look[0] - aim[0], v.look[2] - aim[1]) < Math.hypot(bx - aim[0], by - aim[1]));
    assert.ok(inFrame(c, [bx, 0, by], CORNER_MARGIN) && inFrame(c, [bx, 2, by], CORNER_MARGIN));
    for (const p of goalCorners(gy, 0, 0)) assert.ok(inFrame(c, p, CORNER_MARGIN), `palo ${p}`);
  });
}
