// Stili dei menu: i Safari per iPhone più vecchi non conoscono color-mix(). Con var() dentro, la regola non viene
// scartata ma diventa "vuota" al calcolo (sfondo trasparente, anche con una riserva prima): si vedeva la partita
// dietro i menu e le opzioni dell'editor scorrevano dietro l'anteprima. I colori mescolati li calcola teamMixVars().
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { UI_CSS, teamMixVars } from '../../src/ui-style.js';

test('nessun color-mix negli stili dei menu', () => {
  assert.ok(!UI_CSS.includes('color-mix'));
});

test('colori della squadra mescolati: uno per ogni variabile usata, valori giusti', () => {
  const used = new Set(UI_CSS.match(/--k1m\d+-[0-9a-f]{6}/g));
  const vars = new Map(teamMixVars('#ff0000'));
  assert.deepEqual(new Set(vars.keys()), used);
  assert.ok(used.size >= 7);
  // 38% di rosso puro su #0b1426: (255·0,38 + 11·0,62, 20·0,62, 38·0,62)
  assert.equal(vars.get('--k1m38-0b1426'), '#680c18');
  for (const v of vars.values()) assert.match(v, /^#[0-9a-f]{6}$/);
});

test("la barra delle schede dell'editor è opaca", () => {
  const rule = UI_CSS.match(/\.edtabs\{[^}]*\}/)[0];
  assert.match(rule, /background:#[0-9a-f]{6}[;}]/);
});
