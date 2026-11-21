// Fuga (Luis 2026-11-21): avversario vicino alla pari o dietro "per linee" (linee parallele alle linee di porta) =
// niente duello, rallenty e tasto Scatto. Davanti per linee = duello col Dribbling e il passaggio disegnato.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { FLEE_R, FLEE_MAX, LEVEL_TOL, BURST_T, BURST_RUN } from '../../src/sim.js';
const hyp = Math.hypot;
import { scene, wake, give, run } from '../lib/scene.mjs';

// portatore umano (squadra 0) a centrocampo che corre verso +y, avversario della squadra 1 in (ox, oy) rispetto a lui
function setup(seed, { ox = 0, oy = -2.5 } = {}) {
  const m = scene({ seed }), p = m.players[9], o = m.players[11 + 3];
  wake(p, 0, 0); p.fx = 0; p.fy = 1; give(m, p); m.updateCtrl(0);
  wake(o, ox, oy); o.fx = 0; o.fy = 1;
  return { m, p, o };
}
const hold = (m, p) => () => m.userMove(0, p.x, p.y, true); // dito fermo sul portatore: resta dov'è

test('fuga: si apre con un avversario alle spalle o alla pari entro FLEE_R, non è un duello', () => {
  for (const [ox, oy] of [[0, -2.5], [2.5, 0], [-2, -1.5], [3, LEVEL_TOL * 0.8]]) {
    // Arrange
    const { m, p, o } = setup(1, { ox, oy });
    // Act
    const ev = run(m, 1 / 60, hold(m, p));
    // Assert
    const st = ev.find(e => e.type === 'flee_start');
    assert.ok(st && st.p === p && st.o === o, `avversario in ${ox},${oy}`);
    assert.equal(m.fleeFor(0), true);
    assert.equal(m.duelFor(0), false, 'niente duello');
    assert.equal(m.passFor(0), false, 'nella fuga non si passa');
  }
});

test('fuga: non si apre con l\'avversario davanti (duello), lontano, o per la squadra della CPU', () => {
  // Arrange / Act
  const a = setup(2, { ox: 0, oy: 3 }), b = setup(3, { ox: 0, oy: -(FLEE_R + 1) });
  run(a.m, 1 / 60, hold(a.m, a.p)); run(b.m, 1 / 60, hold(b.m, b.p));
  // Assert
  assert.equal(a.m.fleeFor(0), false); assert.equal(a.m.duelFor(0), true, 'davanti = duello');
  assert.equal(b.m.fleeFor(0), false, 'lontano');
  assert.equal(a.m.fleeFor(1), false);
});

test('fuga: si chiude per tempo e il portatore non la riapre subito', () => {
  // Arrange
  const { m, p, o } = setup(4);
  run(m, 1 / 60, hold(m, p)); o.beat = 0; o.vx = o.vy = 0;
  // Act: avversario immobile (tenuto fermo alle spalle)
  const ev = run(m, FLEE_MAX + 0.1, () => { hold(m, p)(); o.x = p.x; o.y = p.y - 2.5; o.vx = o.vy = 0; });
  // Assert
  const end = ev.find(e => e.type === 'flee_end');
  assert.equal(end && end.reason, 'tempo');
  assert.equal(m.fleeFor(0), false, 'pausa prima di riaprirla');
});

test('Scatto: il portatore si stacca, corre dritto più veloce e l\'avversario non lo contrasta', () => {
  // Arrange
  const { m, p, o } = setup(5, { ox: 0.8, oy: -1.2 });
  p.vy = 4; run(m, 1 / 60, () => m.userMove(0, p.x, p.y + 10, true));
  assert.equal(m.fleeFor(0), true);
  const y0 = p.y, gap0 = hyp(o.x - p.x, o.y - p.y);
  // Act
  const ok = m.userSprint(0);
  const ev = run(m, BURST_T, () => {});
  // Assert
  assert.equal(ok, true);
  assert.equal(m.fleeFor(0), false, 'la fuga si chiude con lo scatto');
  assert.equal(m.ball.owner, p, 'ha ancora il pallone');
  assert.ok(!ev.some(e => e.type === 'tackle'), 'nessun contrasto');
  assert.ok(p.y - y0 > 6, `prosegue dritto in avanti (${(p.y - y0).toFixed(1)} m)`);
  assert.ok(Math.abs(p.x) < 1.5, 'dritto, non di lato');
  assert.ok(hyp(o.x - p.x, o.y - p.y) > gap0 + 2, 'si è staccato');
  assert.ok(m.move[0] === null || hyp(m.move[0].x - p.x, m.move[0].y - (y0 + BURST_RUN)) < BURST_RUN, 'meta dritta davanti');
});

test('Scatto: fuori dalla fuga il tasto non fa niente', () => {
  const { m, p } = setup(6, { ox: 0, oy: -(FLEE_R + 3) });
  run(m, 1 / 60, hold(m, p));
  assert.equal(m.userSprint(0), false);
  assert.equal(p.burst, 0);
});

test("per linee: con l'avversario davanti di lato c'è il duello (Dribbling), non la fuga", () => {
  // Arrange: avversario più avanti di 2 m, spostato di 2 m: dentro il cono del duello
  const { m, p } = setup(7, { ox: 2, oy: 2 });
  // Act
  run(m, 1 / 60, hold(m, p));
  // Assert
  assert.equal(m.duelFor(0), true, 'davanti = duello');
  assert.equal(m.fleeFor(0), false);
  assert.equal(m.userDribble(0), true, 'nel duello il tasto è Dribbling');
});

test('per linee: portatore che corre di lato verso un avversario alla pari = fuga, non duello', () => {
  // Arrange: il portatore corre verso +x, l'avversario gli sta davanti nel verso di corsa ma sulla stessa linea
  const { m, p, o } = setup(8, { ox: 3, oy: 0 });
  p.fx = 1; p.fy = 0; o.fx = -1; o.fy = 0;
  // Act
  run(m, 1 / 60, () => m.userMove(0, p.x + 10, p.y, true));
  // Assert
  assert.equal(m.duelFor(0), false, 'alla pari: niente duello');
  assert.equal(m.fleeFor(0), true, 'alla pari: Scatto');
});

test("per linee: il duello si chiude quando l'avversario arriva alla pari, e si apre la fuga", () => {
  // Arrange
  const { m, p, o } = setup(9, { ox: 1.5, oy: 3 });
  run(m, 1 / 60, hold(m, p));
  assert.equal(m.duelFor(0), true);
  // Act: l'avversario scivola alla pari del portatore
  o.y = p.y; o.x = p.x + 2; o.vx = o.vy = 0;
  const ev = run(m, 1 / 30, () => { hold(m, p)(); o.y = p.y; o.x = p.x + 2; o.vx = o.vy = 0; });
  // Assert
  assert.equal(ev.find(e => e.type === 'duel_end')?.reason, 'lontano');
  assert.equal(m.duelFor(0), false);
  assert.equal(m.fleeFor(0), true);
});

test('squadra 1 (attacca verso -y): "dietro" vale al contrario', () => {
  // Arrange: portatore umano della squadra 1 che corre verso -y, avversario 2 m più in alto (= alle sue spalle)
  const m = scene({ seed: 10, human: [false, true] }), p = m.players[11 + 9], o = m.players[3];
  wake(p, 0, 0); p.fx = 0; p.fy = -1; give(m, p); m.updateCtrl(1);
  wake(o, 0.5, 2); o.fx = 0; o.fy = -1;
  // Act
  run(m, 1 / 60, () => m.userMove(1, p.x, p.y, true));
  // Assert
  assert.equal(m.fleeFor(1), true);
  assert.equal(m.duelFor(1), false);
});
