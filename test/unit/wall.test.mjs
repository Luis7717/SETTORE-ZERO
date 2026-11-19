import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Match, HL, GW } from '../../src/sim.js';
import { mkTeam } from '../lib/harness.mjs';

const newMatch = (seed = 1) => new Match({ seed, halfLen: 9999, human: [false, false], teams: [mkTeam('A', 60, 1), mkTeam('B', 60, 2)] });
const wallOf = m => m.team(1).filter(p => p.wall);

test('barriera: su punizione vicina 2-5 difensori a 9,15 m tra palla e porta', () => {
  for (const [x, y] of [[0, HL - 20], [-8, HL - 24], [12, HL - 27], [-22, HL - 12]]) {
    // Arrange / Act
    const m = newMatch(); m.setRestart('freekick', 0, x, y);
    const b = m.ball, w = wallOf(m);
    // Assert
    assert.ok(w.length >= 2 && w.length <= 5, `(${x}, ${y}): ${w.length} in barriera`);
    for (const p of w) {
      const d = Math.hypot(p.x - b.x, p.y - b.y);
      assert.ok(Math.abs(d - 9.15) < 1.2, `distanza ${d.toFixed(2)}`);
      assert.ok(p.y > b.y, 'tra palla e porta');
      assert.notEqual(p.pos, 'P');
    }
  }
});

test('barriera: punizione lontana, nessuna barriera', () => {
  const m = newMatch(); m.setRestart('freekick', 0, 0, 0);
  assert.equal(wallOf(m).length, 0);
});

test('barriera: resta ferma finché non si batte, poi si scioglie', () => {
  // Arrange
  const m = newMatch(3); m.setRestart('freekick', 0, 0, HL - 22);
  const w = wallOf(m), pos = w.map(p => [p.x, p.y]);
  // Act: 0,8 s di attesa (il computer batte dopo almeno 1,1 s)
  for (let i = 0; i < 48; i++) { m.step(1 / 60); m.events.length = 0; }
  // Assert
  assert.equal(m.phase, 'restart');
  w.forEach((p, k) => assert.ok(Math.hypot(p.x - pos[k][0], p.y - pos[k][1]) < 0.3, 'si è mosso'));
  // la punizione nuova (o qualsiasi altra ripartenza) toglie la barriera
  m.setRestart('throw', 1, 32, 0);
  assert.equal(wallOf(m).length, 0);
});

test('barriera: un tiro basso addosso alla barriera viene respinto', () => {
  let blocked = 0;
  for (let s = 0; s < 10; s++) {
    // Arrange
    const m = newMatch(10 + s); m.setRestart('freekick', 0, 0, HL - 22);
    const taker = m.restart.taker, w = wallOf(m), mid = w[Math.floor(w.length / 2)];
    // Act: tiro basso dritto sul giocatore centrale della barriera
    const k = (HL - m.ball.y) / (mid.y - m.ball.y);
    m.kick(taker, { type: 'shot', tx: m.ball.x + (mid.x - m.ball.x) * k, ty: HL, th: 0.3 });
    let ev = [];
    for (let i = 0; i < 60; i++) { m.step(1 / 60); ev.push(...m.events); m.events.length = 0; }
    if (ev.some(e => e.type === 'block')) blocked++;
  }
  // Assert
  assert.ok(blocked >= 7, `respinti ${blocked}/10`);
});

test('barriera: il computer tira dal lato non coperto', () => {
  // Arrange
  const m = newMatch(5); m.setRestart('freekick', 0, 6, HL - 21);
  const side = m.restart.wallSide;
  // Act
  m.aiRestart();
  // Assert: il pallone va verso il palo opposto a quello coperto
  assert.ok(side !== 0);
  const t = (HL - m.ball.y) / m.ball.vy, xg = m.ball.x + m.ball.vx * t;
  assert.ok(Math.sign(xg) === -side || Math.abs(xg) < GW / 4, `lato coperto ${side}, palla verso x=${xg.toFixed(2)}`);
});
