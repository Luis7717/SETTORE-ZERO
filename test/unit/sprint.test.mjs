// Scatto (Luis 2026-11-20): nel duello il tasto in basso è Scatto (era Dribbling): il portatore brucia il difensore
// in velocità e prosegue dritto.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { BURST_T, BURST_RUN } from '../../src/sim.js';
import { scene, wake, give, run } from '../lib/scene.mjs';
const hyp = Math.hypot;

// portatore umano (squadra 0) a centrocampo che guarda verso +y, difensore della squadra 1 davanti a `dist` m
function setup(seed, { dist = 4, vel = 70, dif = 50, ox = 0.6 } = {}) {
  const m = scene({ seed }), p = m.players[9], o = m.players[11 + 3];
  wake(p, 0, 0); p.fx = 0; p.fy = 1; p.st.vel = vel; give(m, p); m.updateCtrl(0);
  wake(o, ox, dist); o.st.dif = dif; o.fx = 0; o.fy = -1;
  return { m, p, o };
}
const hold = (m, p) => () => m.userMove(0, p.x, p.y, true);

test('Scatto: fuori dal duello non fa niente', () => {
  const { m, p } = setup(1, { dist: 20 });
  run(m, 1 / 60, hold(m, p));
  assert.equal(m.duelFor(0), false);
  assert.equal(m.userSprint(0), false);
});

test('Scatto riuscito: il portatore prosegue dritto, più veloce, oltre il difensore che non lo contrasta', () => {
  let ok = 0;
  for (let seed = 1; seed <= 20; seed++) {
    // Arrange
    const { m, p, o } = setup(seed);
    run(m, 1 / 60, hold(m, p));
    assert.equal(m.duelFor(0), true);
    let res = null; const orig = m.ev.bind(m); m.ev = (t, d) => { if (t === 'dribble') res = d; return orig(t, d); };
    // Act
    assert.equal(m.userSprint(0), true);
    const ev = run(m, BURST_T, () => {});
    // Assert
    assert.ok(res && res.sprint === true, 'evento dribble con sprint');
    assert.equal(m.duelFor(0), false, 'il duello si chiude');
    if (!res.ok) continue;
    ok++;
    assert.equal(p.burst > 0 || m.time > 0, true);
    assert.equal(m.ball.owner, p, 'ha ancora il pallone');
    assert.ok(!ev.some(e => e.type === 'tackle'), 'nessun contrasto');
    assert.ok(p.y > o.y + 1, `è passato oltre il difensore (${p.y.toFixed(1)} contro ${o.y.toFixed(1)})`);
    assert.ok(Math.abs(p.x) < 2, `dritto, non di lato (x ${p.x.toFixed(1)})`);
    assert.ok(p.x * o.x <= 0, 'passa dalla parte opposta al difensore');
    const mv = m.move[0];
    assert.ok(!mv || mv.y > BURST_RUN - 2, 'prosegue dritto verso la meta davanti');
  }
  assert.ok(ok >= 10, `riusciti ${ok} su 20 (veloce contro difesa scarsa)`);
});

test('Scatto: riesce più spesso col portatore veloce e il difensore scarso', () => {
  const rate = (vel, dif) => {
    let ok = 0;
    for (let seed = 1; seed <= 40; seed++) {
      const { m, p } = setup(seed + 100, { vel, dif });
      run(m, 1 / 60, hold(m, p));
      let r = null; const orig = m.ev.bind(m); m.ev = (t, d) => { if (t === 'dribble') r = d; return orig(t, d); };
      m.userSprint(0); if (r && r.ok) ok++;
    }
    return ok;
  };
  assert.ok(rate(85, 40) > rate(45, 80), 'veloce contro difesa scarsa > lento contro difesa forte');
});
