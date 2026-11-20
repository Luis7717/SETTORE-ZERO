// Aiuti alla difesa della squadra umana (richieste del 2026-11-20 sera):
// linee di difesa corte, contrasto "magnetico", intercetto che dà il possesso.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Match, RUN_MAX_LEN, clipLen } from '../../src/sim.js';
import { mkTeam } from '../lib/harness.mjs';
import { scene as bare, wake, give } from '../lib/scene.mjs';

const DT = 1 / 60;
const len = (x0, y0, pts) => { let l = 0, px = x0, py = y0; for (const q of pts) { l += Math.hypot(q.x - px, q.y - py); px = q.x; py = q.y; } return l; };

// ------------------------------------------------------------ linee di difesa corte
test('linea di difesa: si taglia alla lunghezza massima, misurata dal giocatore', () => {
  // Arrange: squadra 1 col pallone, nostra linea lunga 40 m
  const m = new Match({ seed: 4, halfLen: 99999, human: [true, false], teams: [mkTeam('A', 60, 1), mkTeam('B', 60, 2)] });
  m.phase = 'play'; m.restart = null; m.ball.owner = m.players[18];
  const d = m.players[3]; m.place(d, -20, -20);
  const pts = []; for (let k = 1; k <= 40; k++) pts.push({ x: -20 + k, y: -20 });
  // Act
  assert.equal(m.userRun(0, d, pts), true);
  // Assert
  const path = m.runOf(d).path, l = len(d.x, d.y, path), e = path[path.length - 1];
  assert.ok(Math.abs(l - RUN_MAX_LEN) < 0.01, `lunghezza ${l.toFixed(2)} m (massimo ${RUN_MAX_LEN})`);
  assert.ok(Math.abs(e.x - (-20 + RUN_MAX_LEN)) < 0.01 && e.y === -20, 'l’ultimo punto è sulla linea disegnata');
});

test('clipLen: linea corta intatta, linea lunga tagliata a metà di un tratto', () => {
  const corta = [{ x: 3, y: 0 }, { x: 3, y: 4 }];
  assert.deepEqual(clipLen(0, 0, corta, 14), corta);
  const cut = clipLen(0, 0, [{ x: 10, y: 0 }, { x: 10, y: 10 }], 14);
  assert.deepEqual(cut, [{ x: 10, y: 0 }, { x: 10, y: 4 }]);
});

test('finita la linea il giocatore torna subito alla CPU (non resta fermo in fondo)', () => {
  const m = new Match({ seed: 4, halfLen: 99999, human: [true, false], teams: [mkTeam('A', 60, 1), mkTeam('B', 60, 2)] });
  m.phase = 'play'; m.restart = null;
  const c = m.players[18]; m.place(c, 0, -15); m.ball.owner = c; m.att = 1;
  const d = m.team(0).find(p => p.pos === 'D'); m.place(d, 10, 20);
  m.userRun(0, d, [{ x: 10, y: 30 }]); // linea in avanti, lontano dalla sua posizione difensiva
  let i = 0;
  for (; i < 5 * 60 && m.runOf(d); i++) { for (const o of m.team(1)) o.stun = 0.2; c.protect = 1; m.move[0] = null; m.step(DT); m.events.length = 0; }
  const y1 = d.y;
  for (let k = 0; k < 90; k++) { for (const o of m.team(1)) o.stun = 0.2; c.protect = 1; m.move[0] = null; m.step(DT); m.events.length = 0; }
  assert.ok(y1 - d.y > 6, `rientra verso la sua porta (da y ${y1.toFixed(1)} a ${d.y.toFixed(1)})`);
});

// ------------------------------------------------------------ contrasto "magnetico"
// controllato della squadra umana che passa a 2,2 m dal portatore fermo: col dito che tira dritto
function brush(human) {
  const m = bare({ seed: 6, human }), T = human[0] ? 0 : 1, D = 1 - T;
  const c = m.players[D * 11 + 9], d = m.players[T * 11 + 4];
  wake(c, 0, 0); c.fx = 0; c.fy = 1; give(m, c); c.stun = 999; // portatore fermo (si può contrastare)
  wake(d, -7, -2.2); d.st.dif = 60; m.ctrl[T] = d;
  let tackle = false;
  for (let i = 0; i < 3 * 60 && !tackle; i++) {
    if (human[T]) m.userMove(T, 8, -2.2, true, false); else { d.tx = 8; d.ty = -2.2; }
    m.step(DT); tackle = m.events.some(e => e.type === 'tackle' && e.p === d); m.events.length = 0;
  }
  return tackle;
}

test('contrasto magnetico: passando vicino al portatore il nostro controllato va sul pallone e lo ruba', () => {
  assert.equal(brush([true, false]), true);
});

test('raggio di contrasto più largo per chi muove la persona: a 1,15 m dal portatore si ruba palla', () => {
  const run = humanDef => {
    const m = bare({ seed: 7, human: [true, false] }), T = humanDef ? 0 : 1; // T = squadra che difende
    const c = m.players[(1 - T) * 11 + 9], d = m.players[T * 11 + 4];
    wake(c, 0, 0); give(m, c); c.stun = 999;
    wake(d, 1.15 + c.fx * 0.6, c.fy * 0.6); d.st.dif = 60; m.ctrl[T] = d;
    let tackle = false;
    for (let i = 0; i < 60 && !tackle; i++) { d.tx = d.x; d.ty = d.y; d.vx = d.vy = 0; m.contacts(DT); tackle = m.events.some(e => e.type === 'tackle'); m.events.length = 0; }
    return tackle;
  };
  assert.equal(run(true), true, 'squadra umana: preso');
  assert.equal(run(false), false, 'IA: stesso raggio di prima, non preso');
});

// ------------------------------------------------------------ intercetto in corsa
// passaggio avversario dritto contro un nostro difensore che gli corre incontro a 6 m/s
function intercept(seed, humanDef) {
  const m = bare({ seed, human: [true, false] }), T = humanDef ? 0 : 1, k = m.players[(1 - T) * 11 + 7], d = m.players[T * 11 + 3];
  wake(k, 0, 20); wake(d, 0, 0); d.st.dif = 70; k.st.pas = 50;
  const b = m.ball;
  b.owner = null; b.x = 0; b.y = 8; b.h = 0; b.vh = 0; b.vx = 0; b.vy = -15; b.cax = b.cay = 0; b.ct = 0; b.shot = null;
  b.kick = { team: 1 - T, kicker: k, type: 'ground', off: [], age: 0.5 };
  for (let i = 0; i < 90 && !b.owner && b.kick; i++) { d.vx = 0; d.vy = 6; m.contacts(DT); m.updateBall(DT); if (b.kick) b.kick.age = Math.max(b.kick.age, 0.5); }
  return b.owner === d;
}

test('intercetto in corsa: il nostro giocatore prende il pallone, niente rimbalzi', () => {
  for (let s = 1; s <= 12; s++) assert.equal(intercept(s, true), true, `seme ${s}: pallone controllato`);
});

test('intercetto in corsa: l’IA a volte devia ancora (resta realistica)', () => {
  let kept = 0; for (let s = 1; s <= 12; s++) if (intercept(s, false)) kept++;
  assert.ok(kept < 12, `IA: ${kept}/12 controllati`);
});
