import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Match } from '../../src/sim.js';
import { mkTeam } from '../lib/harness.mjs';

const DT = 1 / 60;
// portatore della squadra umana a centrocampo, avversari lontani e fermi
function scene() {
  const m = new Match({ seed: 3, halfLen: 99999, human: [true, false], teams: [mkTeam('A', 60, 1), mkTeam('B', 60, 2)] });
  m.phase = 'play'; m.restart = null;
  const c = m.players[7]; m.place(c, 0, -10); c.fx = 0; c.fy = 1; m.ball.owner = c; m.ctrl[0] = c; m.att = 0;
  for (const o of m.team(1)) m.place(o, o.pos === 'P' ? 0 : -28 + o.i, o.pos === 'P' ? 49 : 45);
  return { m, c };
}
const freeze = m => { for (const o of m.team(1)) o.stun = 0.2; };

test('il portatore segue la strada disegnata, curva compresa, tenendo il pallone', () => {
  // Arrange: strada a "L": avanti 10 m, poi a destra 10 m
  const { m, c } = scene();
  const pts = []; for (let k = 0; k <= 10; k++) pts.push({ x: 0, y: -10 + k }); for (let k = 1; k <= 10; k++) pts.push({ x: k, y: 0 });
  // Act
  assert.equal(m.userPath(0, pts), true);
  let nearCorner = false;
  for (let k = 0; k < 8 * 60 && m.move[0]; k++) { freeze(m); m.step(DT); m.events.length = 0; if (Math.hypot(c.x, c.y) < 2) nearCorner = true; }
  // Assert
  assert.ok(nearCorner, 'è passato dall\'angolo della strada');
  assert.ok(Math.hypot(c.x - 10, c.y) < 2, `arrivato in fondo (${c.x.toFixed(1)}, ${c.y.toFixed(1)})`);
  assert.equal(m.ball.owner, c);
  assert.equal(m.move[0], null, 'strada finita');
});

test('con tanta strada davanti scatta, sull\'ultimo tratto no', () => {
  const { m, c } = scene();
  const pts = []; for (let k = 0; k <= 30; k++) pts.push({ x: 0, y: -10 + k });
  m.userPath(0, pts);
  freeze(m); m.step(DT);
  assert.equal(c.sprint, true);
  for (let k = 0; k < 10 * 60 && m.move[0]; k++) { freeze(m); m.step(DT); if (m.move[0] && Math.abs(c.y - 20) < 4) { assert.equal(c.sprint, false); break; } }
});

test('senza pallone la strada non vale, e si cancella se il portatore lo perde', () => {
  const { m, c } = scene();
  m.ball.owner = null;
  assert.equal(m.userPath(0, [{ x: 0, y: 0 }]), false);
  m.ball.owner = c; m.userPath(0, [{ x: 0, y: 10 }]);
  m.ball.owner = m.players[15]; // palla persa
  freeze(m); m.step(DT);
  assert.equal(m.move[0], null);
});
