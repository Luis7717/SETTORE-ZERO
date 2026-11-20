// Movimenti calcolati (src/moves/*, src/ik.js, src/move-pose.js): cinematica inversa, contatti col pallone sul
// modello vero, voli con la gravità vera, palleggio e giochetti senza compenetrazioni.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import { twoBone, posIn } from '../../src/ik.js';
import { G, flightTime, mirrorFrame } from '../../src/moves/core.js';
import { REST } from '../../src/moves/body.js';
import { juggleMove, STANCE, BASE } from '../../src/moves/juggle.js';
import { trickMove, MENU_OPT, MATCH_OPT, TRICK_IDS } from '../../src/moves/tricks.js';
import { shotMove } from '../../src/moves/shot.js';
import { add, mul, dist, len, sub } from '../../src/moves/vec.js';
import { athleteRig, effector, skinDist } from '../lib/athlete-rig.mjs';

const CM = 0.01;
let rig = null;
const getRig = async () => rig || (rig = await athleteRig());

test('IK a due ossa: la fine della catena arriva sul bersaglio (entro 1 cm), lunghezze rispettate', () => {
  const A = [0.1, 1, 0], a = 0.52, b = 0.39;
  for (let i = 0; i < 200; i++) {
    const r = 0.25 + 0.6 * ((i * 37) % 100) / 100, th = i * 0.7, ph = i * 1.3;
    const C = add(A, mul([Math.sin(th) * Math.cos(ph), -Math.abs(Math.cos(th)), Math.sin(th) * Math.sin(ph)], r));
    const s = twoBone(A, C, a, b, [0, 0.15, 1]);
    assert.ok(Math.abs(dist(A, s.knee) - a) < 1e-6 && Math.abs(dist(s.knee, s.end) - b) < 1e-6);
    if (s.reach) assert.ok(dist(s.end, C) < CM, `bersaglio mancato di ${dist(s.end, C)}`);
  }
});

test('IK sulle ossa three del modello: la caviglia va dove la vuole il movimento (entro 1 cm)', async () => {
  const { f, pose } = await getRig();
  const all = [['palleggio', juggleMove()], ['tiro', shotMove()], ...TRICK_IDS.flatMap(id => [[id, trickMove(id, MENU_OPT)], [id + ' partita', trickMove(id, MATCH_OPT)]])];
  for (const [name, m] of all) for (let t = 0; t <= m.T; t += 0.05) {
    const fr = m.at(t); pose(fr, t);
    for (const s of ['l', 'r']) { const d = dist(posIn(f.g, f.bones['foot_' + s]), fr.legs[s].ankle); assert.ok(d < CM, `${name} t=${t.toFixed(2)} caviglia ${s}: ${(d * 100).toFixed(1)} cm`); }
  }
});

test('le posizioni di riposo usate dai movimenti sono quelle del modello', async () => {
  const { f } = await getRig(), sk = f.mesh.skeleton, F = f.g;
  sk.pose(); F.updateMatrixWorld(true);
  for (const n of ['pelvis', 'Head', 'thigh_l', 'calf_l', 'foot_l', 'foot_r', 'upperarm_r', 'hand_l']) {
    const d = dist(posIn(F, f.bones[n]), REST[n]); assert.ok(d < CM, `${n}: ${(d * 100).toFixed(1)} cm`);
  }
});

test('tempo di volo fisico: 2·sqrt(2h/g) e accelerazione -g nei voli', () => {
  assert.ok(Math.abs(flightTime(0.3, 1.3, 0.3) - 2 * Math.sqrt(2 * 1.0 / 9.81)) < 1e-9);
  for (const m of [juggleMove(), trickMove('sombrero', MENU_OPT), trickMove('arcobaleno', MATCH_OPT), shotMove()]) {
    for (const s of m.segs.filter(x => x.k === 'fly')) {
      const h = 0.01, t = (s.t0 + s.t1) / 2;
      const a = (m.ballAt(t + h)[1] - 2 * m.ballAt(t)[1] + m.ballAt(t - h)[1]) / (h * h);
      assert.ok(Math.abs(a + G) < 0.05, `accelerazione ${a.toFixed(2)} invece di -${G}`);
    }
  }
});

// contatti: a ogni tocco il punto del corpo vero (dopo l'IK) è sul pallone; mai la pelle dentro il pallone
async function checkMove(m, name, maxIn) {
  const { A, f, pose } = await getRig();
  for (const T of m.touches) {
    if (T.part === 'ground') continue;
    const fr = m.at(T.t); pose(fr, T.t);
    const gap = ((m.segs || []).find(x => x.k === 'carry' && Math.abs(x.t0 - T.t) < 1e-9) || {}).gap || 0; // distacco voluto
    const e = effector(A, f, T.part), err = dist(add(e.p, mul(e.n, m.R + gap)), fr.ball.p);
    assert.ok(err < 2 * CM, `${name} ${T.part} a ${T.t.toFixed(2)} s: contatto a ${(err * 100).toFixed(1)} cm`);
  }
  let worst = 1, at = 0, who = '';
  for (let t = 0; t <= m.T; t += 0.04) { const fr = m.at(t); pose(fr, t); const s = skinDist(f, fr.ball.p); if (s.d - m.R < worst) { worst = s.d - m.R; at = t; who = s.who; } }
  assert.ok(worst > -maxIn, `${name}: pelle ${(worst * 100).toFixed(1)} cm dentro il pallone a ${at.toFixed(2)} s (${who})`);
}

test('palleggio: contatto a ogni tocco (piede, coscia, testa), niente compenetrazioni', async () => {
  const m = juggleMove();
  assert.ok(m.touches.filter(x => x.part !== 'ground').length >= 12);
  assert.ok(m.touches.some(x => x.part === 'head') && m.touches.some(x => x.part.endsWith('thigh')));
  await checkMove(m, 'palleggio', 1.5 * CM);
});

for (const id of TRICK_IDS) {
  test(`giochetto ${id} (menu): contatti veri, niente compenetrazioni, parte e finisce fermo`, async () => {
    const m = trickMove(id, MENU_OPT);
    await checkMove(m, id, 1.5 * CM);
    for (const t of [0, m.T]) {
      const fr = m.at(t);
      assert.ok(dist(fr.ball.p, BASE) < CM, `${id} a ${t}: pallone in ${fr.ball.p.map(x => x.toFixed(2))}`);
      for (const s of ['l', 'r']) assert.ok(Math.hypot(fr.legs[s].ankle[0] - STANCE[s][0], fr.legs[s].ankle[2] - STANCE[s][1] + 0.0) < 0.12, `${id} piede ${s} a ${t}`);
    }
  });
  test(`giochetto ${id} (partita): contatti veri col pallone grande`, async () => {
    const m = trickMove(id, MATCH_OPT);
    await checkMove(m, id + ' partita', 2.5 * CM);
    assert.ok(dist(m.at(0).ball.p, MATCH_OPT.B) < CM && dist(m.at(m.T).ball.p, MATCH_OPT.B) < CM);
  });
}

test('posa specchiata: due volte è la stessa, gambe scambiate', () => {
  const fr = trickMove('elastico', MATCH_OPT).at(0.3), mm = mirrorFrame(mirrorFrame(fr)), m1 = mirrorFrame(fr);
  assert.ok(dist(mm.legs.r.ankle, fr.legs.r.ankle) < 1e-12 && dist(mm.ball.p, fr.ball.p) < 1e-12);
  assert.ok(Math.abs(m1.legs.l.ankle[0] + fr.legs.r.ankle[0]) < 1e-12);
});

test('tiro: il collo del piede colpisce il pallone fermo, poi il pallone parte veloce', async () => {
  const m = shotMove(), hit = m.touches.find(x => x.part === 'r.instep');
  await checkMove({ ...m, touches: [hit], T: hit.t, at: t => m.at(t), R: m.R }, 'tiro', 1.5 * CM);
  const v = len(sub(m.ballAt(hit.t + 0.05), m.ballAt(hit.t))) / 0.05;
  assert.ok(v > 15, `pallone a ${v.toFixed(1)} m/s`);
});
