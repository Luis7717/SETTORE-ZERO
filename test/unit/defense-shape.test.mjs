// Squadra umana senza palla (2026-11-20): chi non ha una linea né il dito lo muove la CPU.
// Rientra dietro la palla nella posizione di squadra, uno (due nella nostra trequarti) pressa il portatore,
// le linee disegnate hanno sempre la precedenza.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Match } from '../../src/sim.js';
import { mkTeam } from '../lib/harness.mjs';

const DT = 1 / 60;
// la squadra 1 (computer) ha la palla in (x, y); la squadra 0 (umana) difende, tutti i suoi giocatori partono in attacco
function scene(x, y, seed = 4) {
  const m = new Match({ seed, halfLen: 99999, human: [true, false], teams: [mkTeam('A', 60, 1), mkTeam('B', 60, 2)] });
  m.phase = 'play'; m.restart = null;
  const c = m.players[18]; m.place(c, x, y); m.ball.owner = c; m.att = 1;
  for (const p of m.team(0)) if (p.pos !== 'P') m.place(p, p.bx * 25, 20 + p.i);
  return { m, c };
}
// avversari fermi (il portatore tiene il pallone senza muoversi), nessun dito sullo schermo
const hold = (m, c) => { for (const o of m.team(1)) o.stun = 0.2; m.ball.owner = c; m.move[0] = null; c.protect = 1; };
const play = (m, c, sec, each) => { for (let i = 0; i < sec * 60; i++) { hold(m, c); if (each) each(m); m.step(DT); m.events.length = 0; } };
const outfield = m => m.team(0).filter(p => p.pos !== 'P');
const nearBall = (m, c, r) => outfield(m).filter(p => Math.hypot(p.x - c.x, p.y - c.y) < r);

test('possesso avversario nella nostra metà: difensori e centrocampisti senza linea rientrano dietro la palla', () => {
  // Arrange: tutti i nostri in attacco, l'avversario col pallone nella nostra metà (35 m dalla nostra porta)
  const { m, c } = scene(4, -15);
  // Act: 7 s di possesso avversario
  play(m, c, 7);
  // Assert
  for (const p of outfield(m)) {
    if (nearBall(m, c, 3).includes(p)) continue; // chi pressa sta sul portatore
    if (p.pos === 'D') assert.ok(p.y < c.y - 1, `difensore ${p.i} dietro la palla (y ${p.y.toFixed(1)}, palla ${c.y})`);
    if (p.pos === 'C') assert.ok(p.y < c.y + 1.5, `centrocampista ${p.i} non davanti alla palla (y ${p.y.toFixed(1)})`);
    const [ax, ay] = m.anchor(p);
    assert.ok(Math.hypot(p.x - ax, p.y - ay) < 10, `giocatore ${p.i} vicino al suo posto (${Math.hypot(p.x - ax, p.y - ay).toFixed(1)} m)`);
  }
});

test('rientro di corsa: lontano dal proprio posto, verso la propria porta, il giocatore scatta', () => {
  const { m, c } = scene(0, -10);
  const d = outfield(m).find(p => p.pos === 'D');
  hold(m, c); m.step(DT);
  assert.equal(d.sprint, true, 'il difensore rimasto in attacco rientra scattando');
});

test('pressing: a centrocampo un solo giocatore va sul portatore', () => {
  const { m, c } = scene(0, 8);
  play(m, c, 5);
  assert.equal(nearBall(m, c, 2.5).length, 1, 'uno solo sul portatore');
});

test('pressing: nella nostra trequarti vanno sul portatore in due', () => {
  const { m, c } = scene(6, -24);
  play(m, c, 9);
  assert.equal(nearBall(m, c, 3).length, 2, 'due sul portatore');
});

test('la CPU pressa davvero: il nostro giocatore che va sul portatore prova a rubare palla', () => {
  const { m, c } = scene(0, 0);
  let tackle = false;
  for (let i = 0; i < 12 * 60 && !tackle; i++) {
    for (const o of m.team(1)) o.stun = 0.2; // tutti fermi, portatore compreso (ma si può contrastare)
    m.move[0] = null;
    m.step(DT); tackle = m.events.some(e => e.type === 'tackle' && e.p.team === 0); m.events.length = 0;
  }
  assert.ok(tackle, 'palla rubata dal pressing');
});

test('la linea disegnata vale più del pressing: chi ha la linea la segue, un altro va sul portatore', () => {
  // Arrange: il più vicino al portatore riceve una linea che lo porta lontano
  const { m, c } = scene(0, 8);
  const d = outfield(m).sort((a, b) => Math.hypot(a.x - c.x, a.y - c.y) - Math.hypot(b.x - c.x, b.y - c.y))[0];
  m.place(d, c.x + 3, c.y + 3);
  const end = { x: d.x - 10, y: d.y + 2 };
  assert.equal(m.userRun(0, d, [end]), true);
  // Act
  let maxOff = 0;
  for (let i = 0; i < 4 * 60 && m.runOf(d); i++) {
    hold(m, c); m.step(DT); m.events.length = 0;
    // distanza dalla retta della linea: chi segue la linea non viene tirato via dal pressing
    maxOff = Math.max(maxOff, Math.abs(d.y - (c.y + 3 + (d.x - (c.x + 3)) * (2 / -10))));
  }
  // Assert
  assert.equal(m.runOf(d), null, 'linea finita');
  assert.ok(Math.hypot(d.x - end.x, d.y - end.y) < 1, 'arrivato in fondo alla linea');
  assert.ok(maxOff < 1.5, `rimasto sulla linea (scarto massimo ${maxOff.toFixed(2)} m)`);
  play(m, c, 3);
  assert.ok(nearBall(m, c, 2.5).some(p => p !== d), 'intanto un altro pressa il portatore');
});

test('pallone vagante dopo un rimpallo: ci va il più rapido della squadra umana', () => {
  const { m } = scene(0, 0), b = m.ball;
  b.owner = null; b.kick = null; b.x = -3; b.y = 5; b.vx = 0; b.vy = 0; b.h = 0; b.vh = 0;
  for (const o of m.team(1)) m.place(o, o.x, 45);
  let got = false;
  for (let i = 0; i < 4 * 60 && !got; i++) { m.move[0] = null; for (const o of m.team(1)) o.stun = 0.2; m.step(DT); got = b.owner && b.owner.team === 0; m.events.length = 0; }
  assert.ok(got, 'un nostro giocatore prende il pallone');
});

test('allenamento "Recupera palla" (autoDef spento): chi non ha una linea resta fermo', () => {
  const { m, c } = scene(0, 8);
  m.autoDef[0] = false;
  const start = outfield(m).map(p => [p, p.x, p.y]);
  play(m, c, 2);
  for (const [p, x, y] of start) assert.ok(Math.hypot(p.x - x, p.y - y) < 1, `giocatore ${p.i} fermo`);
});
