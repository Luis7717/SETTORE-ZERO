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

// strada disegnata lunga davanti (gesto del telefono): prima il punto da raggiungere era sempre a 1-2 m e frenava
// il portatore (circa 5-6,8 m/s invece di 7,6), così lo scatto non si vedeva (2026-11-20)
test('scatto lungo una strada disegnata: raggiunge la stessa velocità dello scatto col dito', () => {
  // Arrange
  const speed = path => {
    const m = scene({ seed: 3 }), p = m.players[9];
    wake(p, 0, -30); p.fx = 0; p.fy = 1; give(m, p); m.updateCtrl(0);
    if (path) { const pts = []; for (let k = 1; k <= 40; k++) pts.push({ x: 0, y: -30 + k }); m.userPath(0, pts); }
    run(m, 2.5, mm => { if (!path) mm.userMove(0, p.x, p.y + 20, true, true); });
    return { v: Math.hypot(p.vx, p.vy), sprint: p.sprint };
  };
  // Act
  const strada = speed(true), dito = speed(false);
  // Assert
  assert.equal(strada.sprint, true, 'con tanta strada davanti scatta');
  assert.ok(strada.v > dito.v * 0.97, `strada ${strada.v.toFixed(2)} m/s, scatto col dito ${dito.v.toFixed(2)} m/s`);
});

test('scatto: la differenza con la corsa è chiara (in 2 s almeno il 17% di strada in più)', () => {
  const corsa = runFor(false, 1), scatto = runFor(true, 1);
  assert.ok(scatto.dist > corsa.dist * 1.17, `scatto ${scatto.dist.toFixed(2)} m, corsa ${corsa.dist.toFixed(2)} m in 2 s`);
});

test('animazione: chi scatta usa il clip di scatto, la corsa normale alla stessa velocità no', async () => {
  const { sprintMix } = await import('../../src/athlete3d.js');
  assert.ok(sprintMix(7.0, true) > 0.95, `scatto a 7 m/s: ${sprintMix(7.0, true)}`);
  assert.ok(sprintMix(7.0, false) < 0.05, `corsa a 7 m/s: ${sprintMix(7.0, false)}`);
  assert.ok(sprintMix(7.2, false) < 0.05, 'corsa al massimo di un giocatore medio (7,2 m/s): ancora clip di corsa');
});
