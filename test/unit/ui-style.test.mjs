// Stili dei menu: i Safari per iPhone più vecchi non conoscono color-mix() e scartano l'intera regola.
// Ogni sfondo che lo usa deve avere subito prima uno sfondo di riserva senza color-mix, altrimenti il menu
// resta trasparente (si vede la partita dietro e le opzioni scorrono dietro l'anteprima del giocatore).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { UI_CSS } from '../../src/ui-style.js';

test('ogni sfondo con color-mix ha prima uno sfondo di riserva senza color-mix', () => {
  const decls = [...UI_CSS.matchAll(/([a-z-]+)\s*:\s*([^;{}]*)/g)];
  let checked = 0;
  decls.forEach(([, prop, val], k) => {
    if (!val.includes('color-mix')) return;
    checked++;
    const prev = decls[k - 1];
    assert.ok(prev && prev[1] === prop && !prev[2].includes('color-mix'), `manca la riserva prima di "${prop}:${val.slice(0, 60)}…"`);
  });
  assert.ok(checked > 0);
});

test("la barra delle schede dell'editor è opaca", () => {
  const rule = UI_CSS.match(/\.edtabs\{[^}]*\}/)[0];
  assert.match(rule, /background:#[0-9a-f]{6}[;}]/);
});
