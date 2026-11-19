import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Match, HL, ballPhys } from '../../src/sim.js';
import { mkTeam } from '../lib/harness.mjs';

const setup = (seed) => {
  const m = new Match({ seed, halfLen: 9999, human: [true, false], teams: [mkTeam('A', 60, 1), mkTeam('B', 60, 2)] });
  m.phase = 'play'; m.restart = null;
  for (const q of m.players) if (q !== m.players[9]) { q.x = 30; q.y = q.team ? 40 : -40; }
  const c = m.players[9]; c.x = -4; c.y = 10; c.fx = 0; c.fy = 1; m.ball.owner = c; m.ball.x = c.x; m.ball.y = c.y + 0.6; m.ctrl[0] = c;
  return { m, c };
};

const SPECS = [
  { type: 'ground', tx: 8, ty: 22, curve: 0 },
  { type: 'loft', tx: 15, ty: 35, curve: 3 },
  { type: 'shot', tx: 2.5, ty: HL, th: 1.2, curve: -2 },
  { type: 'auto', tx: -10, ty: 25, curve: 1.5 },
];

for (const spec of SPECS) {
  test(`predictKick (${spec.type}): l'anteprima coincide col volo vero senza errore di mira`, () => {
    // Arrange: due partite identiche; nella seconda il calcio è senza errore (gauss = 0)
    const { m, c } = setup(5);
    const pts = m.predictKick(c, { ...spec });
    const { m: m2, c: c2 } = setup(5);
    m2.gauss = () => 0;
    // Act
    m2.kick(c2, { ...spec });
    const b = m2.ball, s = { x: b.x, y: b.y, h: b.h, vx: b.vx, vy: b.vy, vh: b.vh, cax: b.cax, cay: b.cay, ct: b.ct };
    // Assert: ogni punto dell'anteprima è dove sarà davvero il pallone in quell'istante
    let t = 0;
    for (const p of pts) {
      while (t < p.t - 1e-9) { ballPhys(s, 1 / 60); t += 1 / 60; }
      assert.ok(Math.abs(s.x - p.x) < 1e-6 && Math.abs(s.y - p.y) < 1e-6 && Math.abs(s.h - p.h) < 1e-6, `t=${p.t}`);
    }
    assert.ok(pts.length >= 5);
  });
}

test('predictKick non consuma numeri casuali e non cambia la partita', () => {
  // Arrange
  const { m, c } = setup(9), { m: twin } = setup(9);
  const before = JSON.stringify({ b: m.ball.x, o: m.ball.owner === c });
  // Act
  m.predictKick(c, { ...SPECS[1] });
  // Assert
  assert.equal(m.rnd(), twin.rnd());
  assert.equal(JSON.stringify({ b: m.ball.x, o: m.ball.owner === c }), before);
});

test('offsideY: la linea è il penultimo difensore, ma mai dietro al pallone né nella propria metà', () => {
  // Arrange: squadra 0 attacca verso +y; difensori avversari a y = 20 e 30 (portiere a 49)
  const { m } = setup(3);
  for (const q of m.team(1)) { q.x = 0; q.y = 45; }
  m.gk(1).y = 49; m.players[12].y = 20; m.players[13].y = 30;
  for (const q of m.team(1)) if (q.pos !== 'P' && q !== m.players[12] && q !== m.players[13]) q.y = 35;
  // Act / Assert: penultimo = 35 (dopo il portiere a 49)
  assert.equal(m.offsideY(0), 35);
  // pallone più avanti della linea: conta il pallone
  m.ball.owner = null; m.ball.y = 40; assert.equal(m.offsideY(0), 40);
  // tutto nella metà campo propria: la linea è la metà campo
  for (const q of m.team(1)) q.y = -10; m.ball.y = -20; assert.equal(m.offsideY(0), 0);
  // squadra 1 (attacca verso -y): coordinata negativa
  for (const q of m.team(0)) q.y = -30; m.gk(0).y = -49; m.ball.y = 0; assert.equal(m.offsideY(1), -30);
});
