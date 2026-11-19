import { test } from 'node:test';
import assert from 'node:assert/strict';
import { scene, wake, give, run } from '../lib/scene.mjs';

// fallo da dietro (scivolata) della squadra 1 sul portatore della squadra 0 nel punto (x, y)
function foulAt(x, y, { extra = false, seed = 1 } = {}) {
  const m = scene({ seed, human: [false, false] }), on = m.players[9], by = m.players[11 + 6];
  wake(on, x, y); on.fx = 0; on.fy = 1; give(m, on);
  wake(by, x, y - 0.5); by.sdx = 0; by.sdy = 1; by.state = 'slide';
  if (extra) wake(m.players[11 + 7], x + 1.5, y + 1);
  m.foul(by, on);
  return { m, on, by };
}

test('vantaggio: fallo in attacco con il pallone ancora tenuto, il gioco continua', () => {
  // Arrange / Act
  const { m, on } = foulAt(0, 12);
  // Assert
  assert.equal(m.phase, 'play');
  assert.ok(m.events.some(e => e.type === 'advantage' && e.team === 0 && e.p === on));
  assert.ok(m.events.some(e => e.type === 'foul'), 'il fallo resta segnato');
  assert.equal(m.stats.fouls[1], 1);
});

test('vantaggio: se entro 2,5 s la squadra perde palla si torna alla punizione nel punto del fallo', () => {
  // Arrange
  const { m } = foulAt(-4, 12);
  const thief = m.players[11 + 8]; wake(thief, 10, 20);
  run(m, 1);
  // Act: l'avversario prende il pallone
  give(m, thief);
  const ev = run(m, 1 / 60);
  // Assert
  assert.ok(ev.some(e => e.type === 'advantage_back'));
  assert.equal(m.phase, 'restart'); assert.equal(m.restart.type, 'freekick'); assert.equal(m.restart.team, 0);
  assert.ok(Math.hypot(m.restart.x + 4, m.restart.y - 12) < 1.5, `punizione in (${m.restart.x.toFixed(1)}, ${m.restart.y.toFixed(1)})`);
});

test('vantaggio: tenuto il pallone per 2,5 s il vantaggio finisce e non si torna indietro', () => {
  // Arrange
  const { m } = foulAt(0, 12);
  // Act
  const ev = run(m, 2.7);
  // Assert
  assert.ok(ev.some(e => e.type === 'advantage_over'));
  assert.equal(m.advantage, null); assert.equal(m.phase, 'play');
});

test('vantaggio: nella propria metà o con un altro avversario addosso, punizione subito', () => {
  for (const [x, y, extra] of [[0, -20, false], [0, 15, true]]) {
    // Arrange / Act
    const { m } = foulAt(x, y, { extra });
    // Assert
    assert.equal(m.phase, 'restart', `(${x}, ${y})`); assert.equal(m.restart.type, 'freekick');
    assert.ok(!m.events.some(e => e.type === 'advantage'));
  }
});

test('vantaggio: un tiro lo chiude (sfruttato)', () => {
  // Arrange
  const { m, on } = foulAt(0, 25);
  // Act
  m.aiShoot(on);
  // Assert
  assert.equal(m.advantage, null);
  assert.ok(m.events.some(e => e.type === 'advantage_over'));
});
