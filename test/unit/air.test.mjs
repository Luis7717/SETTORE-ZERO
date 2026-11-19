import { test } from 'node:test';
import assert from 'node:assert/strict';
import { HL, GW } from '../../src/sim.js';
import { scene, wake, give } from '../lib/scene.mjs';
import { playMatch } from '../lib/harness.mjs';

test('colpo di testa: su un cross alto l\'attaccante in area colpisce verso la porta', () => {
  let ok = 0;
  for (let s = 0; s < 20; s++) {
    // Arrange / Act
    const m = scene({ seed: 40 + s, human: [false, false] }), p = m.players[9];
    wake(p, 1, HL - 9); wake(m.gk(1), 0, HL - 0.6);
    const b = m.ball; b.x = p.x - 0.5; b.y = p.y; b.h = 1.9; b.vx = 9; b.vy = 0; b.vh = -1; b.ct = 0; b.last = m.players[5];
    b.kick = { team: 0, kicker: m.players[5], off: [], age: 1, type: 'loft', human: false };
    m.contacts(1 / 60);
    const e = m.events.find(x => x.type === 'kick');
    // Assert: parte verso la porta (linea di porta raggiunta entro 3 m dai pali)
    assert.ok(e && e.kind === 'header' && e.p === p, `seme ${s}: ${JSON.stringify(e && e.kind)}`);
    const t = (HL - b.y) / b.vy, xg = b.x + b.vx * t;
    if (b.vy > 0 && Math.abs(xg) < GW / 2 + 3) ok++;
  }
  assert.ok(ok >= 16, `colpi verso la porta ${ok}/20`);
});

test("colpo di testa: cross vero dalla fascia, l'attaccante va sul pallone e colpisce verso la porta", () => {
  let ok = 0;
  for (let s = 0; s < 10; s++) {
    // Arrange
    const m = scene({ seed: 60 + s, human: [false, false] }), q = m.players[5], p = m.players[9];
    wake(q, -24, HL - 14); q.fx = 1; q.fy = 0; give(m, q); wake(p, 1, HL - 9); wake(m.gk(1), 0, HL - 0.6);
    // Act
    m.kick(q, { type: 'loft', tx: p.x, ty: p.y }); m.events.length = 0;
    let e = null;
    for (let i = 0; i < 180 && !e; i++) { m.step(1 / 60); e = m.events.find(x => x.type === 'kick'); m.events.length = 0; }
    // Assert
    if (e && e.p === p && (e.kind === 'header' || e.kind === 'volley') && m.ball.vy > 0) ok++;
  }
  assert.ok(ok >= 8, `colpi verso la porta ${ok}/10`);
});

test('tiro al volo: pallone a mezza altezza su un lancio di un compagno, vicino alla porta', () => {
  // Arrange
  const m = scene({ seed: 8, human: [false, false] }), p = m.players[9];
  wake(p, -2, HL - 11);
  const b = m.ball; b.x = p.x; b.y = p.y - 0.4; b.h = 0.9; b.vx = 0; b.vy = 10; b.vh = -2; b.ct = 0;
  b.kick = { team: 0, kicker: m.players[5], off: [], age: 1, type: 'loft', human: false };
  // Act
  m.contacts(1 / 60);
  // Assert
  const e = m.events.find(x => x.type === 'kick');
  assert.equal(e && e.kind, 'volley');
  assert.ok(b.vy > 10, 'parte forte verso la porta');
  assert.equal(m.stats.volleys[0], 1); assert.equal(m.stats.shots[0], 1);
});

test('colpo di testa: il difensore vicino alla propria porta respinge lontano', () => {
  // Arrange: lancio della squadra 1 verso la porta della squadra 0 (y = -HL), difensore della 0 sotto il pallone
  const m = scene({ seed: 9, human: [false, false] }), d = m.players[2];
  wake(d, 0, -HL + 12);
  const b = m.ball; b.x = d.x; b.y = d.y + 0.4; b.h = 2.0; b.vx = 0; b.vy = -12; b.vh = -1; b.ct = 0;
  b.kick = { team: 1, kicker: m.players[16], off: [], age: 1, type: 'loft', human: false };
  // Act
  m.contacts(1 / 60);
  // Assert
  const e = m.events.find(x => x.type === 'kick');
  assert.ok(e && e.kind === 'header' && e.clear, JSON.stringify(e && e.kind));
  assert.ok(b.vy > 5, `respinta verso l'avanti: vy ${b.vy}`);
  assert.equal(m.ball.kick, null);
});

test('colpo di testa: un pallone alto lontano dalle porte resta ingiocabile come prima', () => {
  // Arrange
  const m = scene({ seed: 10, human: [false, false] }), p = m.players[7];
  wake(p, 0, 0);
  const b = m.ball; b.x = 0; b.y = 0.3; b.h = 2.0; b.vx = 0; b.vy = 10; b.vh = -1;
  b.kick = { team: 0, kicker: m.players[5], off: [], age: 1, type: 'loft', human: false };
  // Act
  m.contacts(1 / 60);
  // Assert
  assert.equal(m.events.length, 0);
});

test('colpo di testa: in fuorigioco sul cross si fischia', () => {
  // Arrange
  const m = scene({ seed: 11, human: [false, false] }), p = m.players[9];
  wake(p, 1, HL - 9);
  const b = m.ball; b.x = p.x; b.y = p.y; b.h = 1.8; b.vx = 9; b.vy = 0; b.vh = -1;
  b.kick = { team: 0, kicker: m.players[5], off: [p], age: 1, type: 'loft', human: false };
  // Act
  m.contacts(1 / 60);
  // Assert
  assert.ok(m.events.some(e => e.type === 'offside'));
  assert.equal(m.restart.type, 'freekick'); assert.equal(m.restart.team, 1);
});

test('colpi di testa: in partite simulate capitano', () => {
  // Arrange / Act
  let heads = 0, shots = 0;
  for (let s = 0; s < 6; s++) {
    const { m } = playMatch({ seed: 900 + s, mode: 'bot' });
    heads += m.stats.headers[0] + m.stats.headers[1] + m.stats.volleys[0] + m.stats.volleys[1];
    shots += m.stats.shots[0] + m.stats.shots[1];
  }
  // Assert
  assert.ok(heads > 0, `colpi di testa/al volo in 6 partite: ${heads}`);
  assert.ok(shots > 0);
});
