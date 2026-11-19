import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Career, DIV_SKILL } from '../../src/career.js';

const newCareer = () => { const c = new Career(); c.create('FC Prova', 0); return c; };

test('difficoltà: a pari forza, la squadra del computer è più abile nelle divisioni alte', () => {
  // Arrange
  const c = newCareer(), s = c.s;
  const pick = d => ({ ...c.team(s.divs[d].find(id => id !== 'me')), rating: 65 });
  // Act
  const sk = [0, 1, 2].map(d => c.aiMatchTeam(pick(d)).skill);
  // Assert
  assert.ok(sk[0] > sk[1] && sk[1] > sk[2], `abilità per divisione ${sk.map(v => v.toFixed(3)).join(' ')}`);
  assert.ok(Math.abs(sk[0] - sk[2] - (DIV_SKILL[0] - DIV_SKILL[2])) < 1e-9);
});

test('difficoltà: le squadre vere della Prima sono più abili di quelle della Terza', () => {
  // Arrange
  const c = newCareer(), s = c.s;
  const avg = d => { const ids = s.divs[d].filter(id => id !== 'me'); return ids.reduce((a, id) => a + c.aiMatchTeam(c.team(id)).skill, 0) / ids.length; };
  // Act / Assert
  assert.ok(avg(0) > avg(1) + 0.1 && avg(1) > avg(2) + 0.1, `${avg(0)} ${avg(1)} ${avg(2)}`);
});

test('difficoltà: amichevole (squadra fuori campionato) usa la mia divisione; salvataggio senza campi nuovi', () => {
  // Arrange
  const c = newCareer(), keys = Object.keys(c.s).sort().join(',');
  // Act
  const t = c.aiMatchTeam({ name: 'Amichevole', short: 'AMI', kit: 3, rating: 60, seed: 5 });
  // Assert
  assert.equal(t.skill, c.skillOf(60, c.div()));
  assert.equal(Object.keys(c.s).sort().join(','), keys);
  assert.ok(t.skill > 0.1 && t.skill <= 0.95);
});
