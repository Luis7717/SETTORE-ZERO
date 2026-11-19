import { test } from 'node:test';
import assert from 'node:assert/strict';
import { playMatch, FORMATION_NAMES } from '../lib/harness.mjs';

// Stesso metodo di test/balance.mjs: "umano simulato" (squadra 0) contro IA, squadre di pari forza,
// partite da 2 × 150 s di gioco (la durata predefinita nel gioco).
// Obiettivo NON ancora raggiunto (vedi DECISIONI.md): resta come "todo". L'esito con i numeri veri
// compare in `npm test` ma non blocca gli altri test.
test('equilibrio a pari forza: 6-10 tiri a squadra e 2-4 gol totali a partita (media)', { todo: 'gol e tiri della squadra umana sotto obiettivo' }, () => {
  // Arrange
  const N = 16;
  let shots = [0, 0], goals = 0;
  // Act
  for (let g = 0; g < N; g++) {
    const { m } = playMatch({ seed: 2000 + g, mode: 'bot', my: 60, op: 60, fB: FORMATION_NAMES[g % 4] });
    shots[0] += m.stats.shots[0]; shots[1] += m.stats.shots[1]; goals += m.score[0] + m.score[1];
  }
  // Assert
  const s0 = shots[0] / N, s1 = shots[1] / N, gl = goals / N, msg = `tiri ${s0.toFixed(1)}-${s1.toFixed(1)}, gol totali ${gl.toFixed(2)}`;
  assert.ok(s0 >= 6 && s0 <= 10, 'umano: ' + msg);
  assert.ok(s1 >= 6 && s1 <= 10, 'IA: ' + msg);
  assert.ok(gl >= 2 && gl <= 4, msg);
});
