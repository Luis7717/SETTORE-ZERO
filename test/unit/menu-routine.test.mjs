// Allenamento del campione sullo sfondo del menu (src/menu-routine.js): sequenza completa e pallone sensato.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { menuRoutine, cycleLength, JUGGLE_T, TOUCH_T } from '../../src/menu-routine.js';
import { TRICKS } from '../../src/tricks.js';

test('un giro: palleggi, giochetto, corsa, tiro, pausa; il giro dopo usa il giochetto successivo', () => {
  const seen = [];
  for (let t = 0; t < cycleLength(0); t += 0.05) { const s = menuRoutine(t).seg; if (seen[seen.length - 1] !== s) seen.push(s); }
  assert.deepEqual(seen, ['juggle', 'trick', 'run', 'shot', 'rest']);
  assert.equal(menuRoutine(JUGGLE_T + 0.1).trick.id, TRICKS[0].id);
  assert.equal(menuRoutine(cycleLength(0) + JUGGLE_T + 0.1).trick.id, TRICKS[1].id);
  // dopo tutti i giochetti si ricomincia dal primo
  let t0 = 0; for (let k = 0; k < TRICKS.length; k++) t0 += cycleLength(k);
  assert.equal(menuRoutine(t0 + JUGGLE_T + 0.1).trick.id, TRICKS[0].id);
});

test('palleggi: il pallone tocca il piede a ogni tocco e sale tra un tocco e l\'altro, piede alternato', () => {
  const touch = menuRoutine(3 * TOUCH_T + 0.001), mid = menuRoutine(3.5 * TOUCH_T);
  assert.ok(touch.ball.h < 0.3, `al tocco ${touch.ball.h}`);
  assert.ok(mid.ball.h > 0.7, `a metà ${mid.ball.h}`);
  assert.ok(touch.leg.lift > 0.9 && mid.leg.lift === 0);
  assert.notEqual(menuRoutine(2 * TOUCH_T + 0.01).leg.side, menuRoutine(3 * TOUCH_T + 0.01).leg.side);
});

test('corsa con velocità per l\'animazione, tiro col calcio, poi il pallone vola via e sparisce', () => {
  let run = null, shot = null, gone = false;
  for (let t = JUGGLE_T; t < cycleLength(0); t += 0.02) {
    const s = menuRoutine(t);
    if (s.seg === 'run') run = s; if (s.seg === 'shot') shot = s; if (s.seg === 'rest' && !s.ball.visible) gone = true;
  }
  assert.ok(run.vx > 5); assert.ok(shot.kickAnim > 0); assert.ok(gone);
});

test('mai numeri sbagliati, pallone mai sotto terra', () => {
  for (let t = 0; t < 120; t += 0.037) {
    const s = menuRoutine(t);
    for (const v of [s.ball.f, s.ball.s, s.ball.h, s.vx, s.kickAnim]) assert.ok(Number.isFinite(v));
    assert.ok(s.ball.h >= 0, `t=${t} h=${s.ball.h}`);
  }
});
