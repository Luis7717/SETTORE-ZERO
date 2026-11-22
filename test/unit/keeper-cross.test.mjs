import { test } from 'node:test';
import assert from 'node:assert/strict';
import { HL, HW } from '../../src/sim.js';
import { scene, wake, give, run } from '../lib/scene.mjs';

// Portiere sui cross e sulle parate (Luis 2026-11-22). Stessi casi di godot/tests/test_angoli.gd.

// nostro portiere, battitore della CPU sulla bandierina e (facoltativo) un attaccante; cross verso (tx, ty)
function cross(seed, tx, ty, att) {
  const m = scene({ seed, human: [true, false] }), g = m.gk(0), k = m.players[11 + 7];
  wake(g, 0, -HL + 0.6); wake(k, HW - 0.5, -HL + 0.5); k.fx = -1; k.fy = 0;
  if (att) wake(m.players[11 + 9], att[0], att[1]);
  give(m, k);
  m.kick(k, { type: 'loft', tx, ty });
  let far = 0;
  const ev = run(m, 4, mm => { if (mm.ball.kick && mm.ball.kick.type === 'loft') far = Math.max(far, g.y + HL); });
  return { m, g, ev, far };
}

test('cross in area piccola senza attaccanti: il portiere esce e lo blocca', () => {
  let prese = 0;
  for (let s = 1; s <= 10; s++) {
    const r = cross(s, -1, -HL + 5);
    if (r.ev.some(e => e.type === 'control' && e.p === r.g)) prese++;
    assert.ok(!r.ev.some(e => e.type === 'goal'), `seme ${s}: gol`);
  }
  assert.ok(prese >= 9, `prese ${prese} su 10`);
});

test("cross con l'attaccante già sotto il pallone: il portiere resta tra i pali", () => {
  for (let s = 1; s <= 10; s++) {
    const r = cross(s, 0, -HL + 10, [0.5, -HL + 10]);
    assert.ok(r.far <= 2, `seme ${s}: uscito di ${r.far.toFixed(1)} m`);
  }
});

test('parata: tiri lenti e centrali bloccati, forti, angolati e alti respinti più spesso; portiere bravo blocca di più', () => {
  const m = scene({ seed: 1 }), g = m.gk(0);
  const lento = m.catchChance(g, 14, true, 1), forte = m.catchChance(g, 30, true, 1);
  const angolato = m.catchChance(g, 30, false, 1), alto = m.catchChance(g, 30, false, 2.3);
  assert.ok(lento >= 0.9 && forte > angolato && angolato > alto && angolato < 0.5);
  g.st.por += 20;
  assert.ok(m.catchChance(g, 30, false, 1) > angolato);
});

test('respinta in campo: lontano dalla porta e verso l\'esterno', () => {
  for (let s = 1; s <= 30; s++) {
    const m = scene({ seed: s }), g = m.gk(0), b = m.ball;
    wake(g, 1, -HL + 0.6);
    b.x = 2.5; b.y = -HL + 0.8; b.h = 1; b.vx = 0; b.vy = -30; b.vh = 0;
    m.save(g, false);
    if (b.owner || m.events.some(e => e.type === 'save' && e.out)) continue;
    assert.ok(b.vx > 0 && b.vy > 0 && Math.hypot(b.vx, b.vy) >= 8, `seme ${s}: (${b.vx}, ${b.vy})`);
  }
});
