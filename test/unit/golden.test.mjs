import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { SCENARIOS, fingerprint } from '../lib/fingerprint.mjs';

const golden = JSON.parse(readFileSync(new URL('../fixtures/golden.json', import.meta.url), 'utf8'));

for (const [i, sc] of SCENARIOS.entries()) {
  test(`partita a seme fisso ${i} (${sc.mode}) identica all'impronta salvata`, () => {
    // Arrange / Act
    const f = fingerprint(sc);
    // Assert
    assert.deepEqual(f, golden[i]);
  });
}
