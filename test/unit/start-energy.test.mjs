import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Match, startEnergy } from '../../src/sim.js';
import { mkTeam } from '../lib/harness.mjs';

// Energia iniziale facoltativa (carriera Godot: giocatori stanchi dalle partite prima): campo `energy0` del giocatore
// sorgente. Senza il campo tutto resta come prima (le partite a seme fisso non cambiano: golden.test.mjs).

function partita(tocca) {
  const a = mkTeam('A', 60, 11), b = mkTeam('B', 60, 22);
  if (tocca) tocca(a, b);
  return new Match({ seed: 5, halfLen: 60, human: [false, false], teams: [a, b] });
}

test('energia iniziale: senza energy0 tutti partono a 1', () => {
  // Arrange / Act
  const m = partita();
  // Assert
  assert.ok(m.players.every(p => p.energy === 1));
});

test('energia iniziale: energy0 vale per quel giocatore, gli altri restano a 1', () => {
  // Arrange / Act
  const m = partita(a => { a.players[9].energy0 = 0.7; });
  // Assert
  assert.equal(m.players[9].energy, 0.7);
  assert.ok(m.players.filter((p, k) => k !== 9).every(p => p.energy === 1));
});

test('energia iniziale: fuori misura si tiene tra 0,2 e 1, valori sbagliati = 1', () => {
  // Arrange / Act / Assert
  assert.equal(startEnergy({ energy0: 0.05 }), 0.2);
  assert.equal(startEnergy({ energy0: 3 }), 1);
  assert.equal(startEnergy({ energy0: 'stanco' }), 1);
  assert.equal(startEnergy({ energy0: NaN }), 1);
  assert.equal(startEnergy({}), 1);
  assert.equal(startEnergy(null), 1);
});

test('energia iniziale: chi parte stanco è più lento', () => {
  // Arrange
  const m = partita(a => { a.players[9].energy0 = 0.4; });
  const stanco = m.players[9], fresco = m.players[10];
  // Act
  const vs = m.vmax(stanco) / (5 + stanco.st.vel * 0.036), vf = m.vmax(fresco) / (5 + fresco.st.vel * 0.036);
  // Assert
  assert.ok(vs < vf, `stanco ${vs}, fresco ${vf}`);
});

test('energia iniziale: un campo energy0 = 1 non cambia la partita', () => {
  // Arrange
  const m1 = partita(), m2 = partita(a => { a.players.forEach(p => { p.energy0 = 1; }); });
  // Act
  for (let i = 0; i < 600; i++) { m1.step(1 / 60); m2.step(1 / 60); }
  // Assert
  assert.deepEqual(m2.score, m1.score);
  assert.equal(m2.ball.x, m1.ball.x);
  assert.equal(m2.ball.y, m1.ball.y);
});
