import { test } from 'node:test';
import assert from 'node:assert/strict';
import { TRICKS, bestTrick, chooseTrick, ballOffset } from '../../src/tricks.js';

test('giochetti: più dribbling sblocca giochetti più belli', () => {
  // Arrange / Act
  const tops = [30, 45, 55, 65, 75, 85, 99].map(bestTrick);
  // Assert
  for (let i = 1; i < tops.length; i++) assert.ok(tops[i] >= tops[i - 1], tops.join(','));
  assert.equal(TRICKS[bestTrick(30)].id, 'finta', 'dribbling scarso: solo la finta di corpo');
  assert.equal(TRICKS[bestTrick(90)].id, 'arcobaleno', 'dribbling da campione: il colpo dell’arcobaleno');
});

test('giochetti: di solito il più bello che sa fare, mai uno più bello di quello', () => {
  for (const dri of [40, 60, 80, 95]) {
    const top = bestTrick(dri), seen = new Set();
    for (let k = 0; k < 100; k++) { const T = chooseTrick(dri, k / 100); seen.add(T.id); assert.ok(TRICKS.indexOf(T) <= top); }
    assert.equal(chooseTrick(dri, 0.1), TRICKS[top]);
    if (top >= 2) assert.ok(seen.size >= 2, 'c’è un po’ di varietà');
  }
});

test('giochetti: il pallone parte e torna al suo posto (nessuno scatto a inizio e fine)', () => {
  for (const T of TRICKS) {
    for (const q of [0, 1]) {
      const o = ballOffset(T.id, q);
      assert.ok(Math.abs(o.f) < 0.02 && Math.abs(o.s) < 0.02 && Math.abs(o.h) < 0.02, `${T.id} a q=${q}: ${JSON.stringify(o)}`);
    }
    let maxH = 0; for (let q = 0; q <= 1; q += 0.05) maxH = Math.max(maxH, ballOffset(T.id, q).h);
    if (T.id === 'sombrero' || T.id === 'arcobaleno') assert.ok(maxH > 1.5, `${T.id}: pallone alto ${maxH.toFixed(2)} m`);
  }
});
