import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Match } from '../../src/sim.js';
import { mkTeam } from '../lib/harness.mjs';

const DT = 1 / 60;
// la squadra 1 (computer) ha la palla; la squadra 0 (umana) difende
function scene() {
  const m = new Match({ seed: 4, halfLen: 99999, human: [true, false], teams: [mkTeam('A', 60, 1), mkTeam('B', 60, 2)] });
  m.phase = 'play'; m.restart = null;
  const c = m.players[18]; m.place(c, 0, 20); m.ball.owner = c; m.att = 1;
  return { m, c };
}
const hold = (m, c) => { for (const o of m.team(1)) o.stun = 0.2; m.ball.owner = c; };

test('in difesa un giocatore corre lungo la linea disegnata da lui', () => {
  // Arrange
  const { m, c } = scene(), d = m.players[3];
  m.place(d, -10, -10);
  const pts = []; for (let k = 1; k <= 12; k++) pts.push({ x: -10 + k, y: -10 + k * 0.5 });
  // Act
  assert.equal(m.userRun(0, d, pts), true);
  for (let k = 0; k < 6 * 60 && m.runOf(d); k++) { hold(m, c); m.step(DT); m.events.length = 0; }
  // Assert
  assert.ok(Math.hypot(d.x - 2, d.y + 4) < 2, `arrivato in fondo alla linea (${d.x.toFixed(1)}, ${d.y.toFixed(1)})`);
  assert.equal(m.runOf(d), null, 'linea finita');
});

test('al massimo tre linee insieme: la quarta sostituisce la più vecchia', () => {
  const { m } = scene();
  const ps = [2, 3, 4, 5].map(i => m.players[i]);
  ps.forEach((p, k) => m.userRun(0, p, [{ x: k * 5, y: -20 }]));
  assert.equal(m.runs[0].length, 3);
  assert.equal(m.runOf(ps[0]), null, 'la più vecchia è sparita');
  m.userRun(0, ps[1], [{ x: 0, y: -30 }]);
  assert.equal(m.runs[0].length, 3, 'una nuova linea dello stesso giocatore sostituisce la sua');
});

test('quando la propria squadra prende palla le linee di difesa si cancellano', () => {
  const { m } = scene(), d = m.players[3];
  m.userRun(0, d, [{ x: 0, y: -30 }]);
  m.ball.owner = m.players[7];
  m.step(DT);
  assert.equal(m.runs[0].length, 0);
});

test('raggio difensivo: cresce con la difesa, cala col passaggio di chi passa', () => {
  const { m } = scene(), d = m.players[3], k = m.players[18];
  m.ball.kick = { team: 1, kicker: k, type: 'ground', off: [], age: 0 };
  d.st.dif = 80; k.st.pas = 40; const wide = m.reachOf(d);
  d.st.dif = 50; k.st.pas = 85; const narrow = m.reachOf(d);
  d.st.dif = 60; k.st.pas = 60; const even = m.reachOf(d);
  assert.ok(wide > even && even > narrow, `${wide} > ${even} > ${narrow}`);
  m.ball.kick.type = 'shot';
  assert.ok(m.reachOf(d) < even, 'sui tiri vale il raggio dei tiri');
});

test('lo stesso passaggio a 1,15 m dal difensore: preso se passa male, non preso se passa bene', () => {
  const run = (dif, pas) => {
    const { m, c } = scene(), d = m.players[3];
    for (const o of m.players) if (o !== c && o !== d) m.place(o, o.team ? 30 : -30, o.i * 4 - 40);
    m.place(d, 1.15, 10); d.st.dif = dif; c.st.pas = pas;
    m.kick(c, { type: 'ground', tx: 0, ty: 0, curve: 0 });
    // traiettoria dritta e senza errore, per confrontare solo il raggio
    const b = m.ball; b.x = 0; b.y = c.y - 0.6; b.vx = 0; b.vy = -14; b.cax = b.cay = 0; b.ct = 0;
    for (let i = 0; i < 120 && !b.owner && b.kick; i++) { d.vx = d.vy = 0; m.contacts(DT); m.updateBall(DT); }
    return b.owner === d || b.last === d;
  };
  assert.equal(run(85, 40), true, 'difensore forte contro passaggio scarso: preso');
  assert.equal(run(45, 90), false, 'difensore debole contro passaggio preciso: passa');
});
