import { test } from 'node:test';
import assert from 'node:assert/strict';
import { scene, wake, give, run } from '../lib/scene.mjs';

// portatore della squadra 0 che corre in avanti per 2 s tenendo il dito 20 m davanti
function runFor(sprint, energy) {
  const m = scene({ seed: 3 }), p = m.players[9];
  wake(p, 0, -30); p.fx = 0; p.fy = 1; p.energy = energy; give(m, p);
  const y0 = p.y, e0 = p.energy;
  run(m, 2, mm => mm.userMove(0, p.x, p.y + 20, true, sprint));
  return { dist: p.y - y0, used: e0 - p.energy };
}

test('scatto: più veloce della corsa e consuma più energia', () => {
  // Arrange / Act
  const corsa = runFor(false, 1), scatto = runFor(true, 1);
  // Assert
  assert.ok(scatto.dist > corsa.dist * 1.08, `scatto ${scatto.dist.toFixed(2)} m, corsa ${corsa.dist.toFixed(2)} m`);
  assert.ok(scatto.used > corsa.used * 2, `energia scatto ${scatto.used}, corsa ${corsa.used}`);
});

test('scatto: a energia bassa rende meno', () => {
  // Arrange / Act
  const pieno = runFor(true, 1).dist / runFor(false, 1).dist;
  const stanco = runFor(true, 0.3).dist / runFor(false, 0.3).dist;
  // Assert
  assert.ok(pieno > stanco + 0.02, `guadagno a energia piena ${pieno.toFixed(3)}, stanco ${stanco.toFixed(3)}`);
});

test('scatto: camminando o da fermi l\'energia si recupera', () => {
  // Arrange
  const m = scene({ seed: 4 }), p = m.players[9];
  wake(p, 0, -30); p.energy = 0.5; give(m, p);
  // Act: dito sul giocatore (fermo)
  run(m, 3, mm => mm.userMove(0, p.x, p.y, true));
  // Assert
  assert.ok(p.energy > 0.505, `energia ${p.energy}`);
});

test('scatto: senza flag esplicito scatta solo se il dito è lontano dal giocatore', () => {
  // Arrange
  const m = scene({ seed: 5 }), p = m.players[9];
  wake(p, 0, -30); give(m, p); m.updateCtrl(0);
  // Act / Assert
  m.userMove(0, p.x + 2, p.y + 3, true); assert.equal(m.move[0].sprint, false);
  m.userMove(0, p.x, p.y + 15, true); assert.equal(m.move[0].sprint, true);
  m.userMove(0, p.x, p.y + 15, false); assert.equal(m.move[0].sprint, false, 'un tocco singolo non è uno scatto');
});
