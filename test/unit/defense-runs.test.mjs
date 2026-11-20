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

test('tutti i giocatori di movimento possono avere una linea, il portiere no', () => {
  const { m } = scene();
  const outfield = m.team(0).filter(p => p.pos !== 'P');
  outfield.forEach((p, k) => assert.equal(m.userRun(0, p, [{ x: -20 + k * 4, y: -20 }]), true));
  assert.equal(m.runs[0].length, 10);
  assert.equal(m.userRun(0, m.gk(0), [{ x: 0, y: -40 }]), false, 'il portiere no');
  m.userRun(0, outfield[1], [{ x: 0, y: -30 }]);
  assert.equal(m.runs[0].length, 10, 'una nuova linea dello stesso giocatore sostituisce la sua');
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

test('in difesa chi ha una linea la segue senza che la CPU la sovrascriva; gli altri li muove la CPU', () => {
  // Arrange (prima del 2026-11-20 sera gli altri restavano fermi: ora rientrano, pressano, marcano)
  const { m, c } = scene(), d = m.players[3];
  const start = m.team(0).filter(p => p.pos !== 'P').map(p => [p, p.x, p.y]);
  const end = { x: d.x + 6, y: d.y };
  m.userRun(0, d, [end]);
  // Act: 2 s di gioco con l'avversario fermo col pallone
  let off = 0, reached = 99;
  for (let i = 0; i < 120; i++) {
    hold(m, c); m.step(DT); m.events.length = 0;
    if (m.runOf(d)) off = Math.max(off, Math.abs(d.y - end.y));
    reached = Math.min(reached, Math.hypot(d.x - end.x, d.y - end.y));
  }
  // Assert
  assert.ok(reached < 1, 'chi ha la linea arriva in fondo');
  assert.equal(m.runOf(d), null, 'linea finita: il giocatore torna alla CPU');
  assert.ok(off < 0.8, `resta sulla sua linea (scarto ${off.toFixed(2)} m)`);
  const moved = start.filter(([p, x, y]) => p !== d && Math.hypot(p.x - x, p.y - y) > 1).length;
  assert.ok(moved >= 3, `la CPU muove gli altri (${moved} si sono mossi)`);
});

test('in difesa il giocatore controllato si muove col dito tenuto premuto', () => {
  const { m, c } = scene(), k = m.ctrl[0];
  assert.ok(k, 'c’è un controllato');
  const x0 = k.x, y0 = k.y;
  for (let i = 0; i < 60; i++) { hold(m, c); m.userMove(0, x0 + 8, y0, true); m.step(DT); m.events.length = 0; }
  assert.ok(Math.hypot(k.x - x0, k.y - y0) > 3, 'il controllato segue il dito');
});

test('una linea disegnata fin sull’avversario col pallone porta al contrasto', () => {
  const { m, c } = scene(), d = m.players[3];
  m.place(d, c.x - 6, c.y - 6); d.st.dif = 70;
  m.userRun(0, d, [{ x: c.x - 3, y: c.y - 3 }, { x: c.x, y: c.y }]);
  let won = false;
  for (let i = 0; i < 6 * 60 && !won; i++) { hold(m, c); c.stun = 0; c.vx = c.vy = 0; m.step(DT); won = m.events.some(e => e.type === 'tackle' && e.p === d); m.events.length = 0; }
  assert.ok(won, 'il difensore arriva sull’avversario e contrasta');
});

test('nessuna scivolata: in una partita intera l’IA non entra mai in scivolata', async () => {
  const { playMatch } = await import('../lib/harness.mjs');
  let slides = 0;
  for (const seed of [1, 2]) playMatch({ seed, mode: 'ai', onStep: m => { for (const e of m.events) if (e.type === 'slide') slides++; } });
  assert.equal(slides, 0);
});
