// Proporzioni di testa e collo del modello atleta dopo src/body/testa.js (PROPORZIONI.md, unità T = altezza della testa).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { measureBoth } from '../head-measure.mjs';

test('testa e collo rispettano PROPORZIONI.md (tolleranza 3%)', async () => {
  const { after: m } = await measureBoth();
  const near = (v, want, name) => assert.ok(Math.abs(v - want) <= want * 0.03, `${name}: ${v} invece di ${want}`);
  near(m.altezza_in_T, 8, 'altezza totale (T)');
  near(m.testa_larga_T, 0.68, 'testa larga (T)');
  near(m.testa_profonda_T, 0.82, 'testa profonda (T)');
  near(m.collo_visibile_T, 0.35, 'collo visibile (T)');
  near(m.collo_largo_T, 0.5, 'collo largo (T)');
});

test('la base del collo (attaccatura alle spalle) non si muove', async () => {
  const { before, after } = await measureBoth();
  assert.ok(Math.abs(after.incavo_y - before.incavo_y) < 0.003, `incavo del collo spostato: ${before.incavo_y} → ${after.incavo_y}`);
});
