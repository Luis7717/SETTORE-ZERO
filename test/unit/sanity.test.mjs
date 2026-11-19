import { test } from 'node:test';
import assert from 'node:assert/strict';
import { playMatch } from '../lib/harness.mjs';

test('partita completa senza NaN e senza palla ferma più di 6 secondi', () => {
  // Arrange
  let nan = 0, stall = 0, maxStall = 0, lx = 0, ly = 0;
  // Act
  const { m } = playMatch({
    seed: 42, mode: 'ai', halfLen: 90,
    onStep(mm) {
      const b = mm.ball;
      if (!Number.isFinite(b.x + b.y + b.h + b.vx + b.vy)) nan++;
      for (const p of mm.players) if (!Number.isFinite(p.x + p.y + p.fx + p.fy)) nan++;
      if (mm.phase === 'play' && Math.hypot(b.x - lx, b.y - ly) < 0.01) { stall++; maxStall = Math.max(maxStall, stall); } else stall = 0;
      lx = b.x; ly = b.y;
    },
  });
  // Assert
  assert.equal(m.phase, 'full');
  assert.equal(nan, 0);
  assert.ok(maxStall < 6 * 60, `palla ferma per ${maxStall} passi`);
});
