// Allenamento del campione sullo sfondo del menu (src/menu-routine.js): sequenza completa e pallone sensato.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { menuRoutine, cycleLength, juggleTime, RUN_T } from '../../src/menu-routine.js';
import { TRICKS } from '../../src/tricks.js';
import { BALL_R } from '../../src/moves/juggle.js';

test('un giro: palleggi, giochetto, corsa, tiro, pallone nuovo; il giro dopo usa il giochetto successivo', () => {
  const seen = [];
  for (let t = 0; t < cycleLength(0); t += 0.05) { const s = menuRoutine(t).seg; if (seen[seen.length - 1] !== s) seen.push(s); }
  assert.deepEqual(seen, ['juggle', 'trick', 'run', 'shot', 'rest']);
  const J = juggleTime();
  assert.equal(menuRoutine(J + 0.1).trick.id, TRICKS[0].id);
  assert.equal(menuRoutine(cycleLength(0) + J + 0.1).trick.id, TRICKS[1].id);
  // dopo tutti i giochetti si ricomincia dal primo
  let t0 = 0; for (let k = 0; k < TRICKS.length; k++) t0 += cycleLength(k);
  assert.equal(menuRoutine(t0 + J + 0.1).trick.id, TRICKS[0].id);
});

test('palleggi: posa calcolata a pieno peso e pallone che sale e scende', () => {
  let lo = 9, hi = 0;
  for (let t = 1.5; t < juggleTime() - 1.5; t += 0.05) { const s = menuRoutine(t); assert.ok(s.frame && s.w === 1); lo = Math.min(lo, s.ball.p[1]); hi = Math.max(hi, s.ball.p[1]); }
  assert.ok(lo < 0.45 && hi > 0.9, `pallone fra ${lo.toFixed(2)} e ${hi.toFixed(2)} m`);
});

test('corsa col clip (la posa calcolata sfuma solo ai bordi), tiro che manda via il pallone, che poi sparisce', () => {
  let run = null, gone = false, fast = 0;
  const J = juggleTime(), T0 = J + (cycleLength(0) - J - RUN_T) * 0; // inizio del giochetto
  for (let t = T0; t < cycleLength(0); t += 0.02) {
    const s = menuRoutine(t);
    if (s.seg === 'run' && s.w === 0) run = s;
    if (s.seg === 'shot') { fast = Math.max(fast, s.ball.p[2]); if (!s.ball.vis) gone = true; }
  }
  assert.ok(run && run.vx > 5 && run.frame === null); assert.ok(fast > 10); assert.ok(gone);
});

test('mai numeri sbagliati, pallone mai sotto terra', () => {
  for (let t = 0; t < 120; t += 0.037) {
    const s = menuRoutine(t);
    for (const v of [...s.ball.p, ...s.ball.q, s.vx, s.w]) assert.ok(Number.isFinite(v));
    assert.ok(s.ball.p[1] >= BALL_R - 1e-6, `t=${t} h=${s.ball.p[1]}`);
  }
});
