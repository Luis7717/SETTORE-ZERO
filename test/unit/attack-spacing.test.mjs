// Squadra umana in attacco (2026-11-20): i compagni senza palla si smarcano lontani tra loro (niente grappoli),
// le punte attaccano la profondità sulla linea del fuorigioco, il secondo d'appoggio si offre più lontano.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Match } from '../../src/sim.js';
import { mkTeam } from '../lib/harness.mjs';

const DT = 1 / 60;
// portatore umano a (0, y0) fermo col pallone, compagni partiti tutti ammucchiati intorno a lui, avversari ai loro posti
function scene(seed, y0 = -12) {
  const m = new Match({ seed, halfLen: 99999, human: [true, false], teams: [mkTeam('A', 60, seed), mkTeam('B', 60, seed + 50)] });
  m.phase = 'play'; m.restart = null;
  const c = m.players[7]; m.place(c, 0, y0); c.fx = 0; c.fy = 1; m.ball.owner = c; m.ctrl[0] = c; m.att = 0;
  m.team(0).filter(p => p.pos !== 'P' && p !== c).forEach((p, k) => m.place(p, Math.cos(k) * 4, y0 + Math.sin(k) * 4));
  for (const o of m.team(1)) { const [ax, ay] = m.anchor(o); m.place(o, ax, ay); }
  return { m, c };
}
const hold = (m, c) => { for (const o of m.team(1)) o.stun = 0.2; m.ball.owner = c; c.stun = 0.2; m.move[0] = null; };
const mates = (m, c) => m.team(0).filter(p => p.pos !== 'P' && p !== c);
// distanza media di ogni compagno senza palla dal compagno più vicino
function spacing(m, c) {
  const ms = mates(m, c); let s = 0;
  for (const q of ms) s += Math.min(...ms.filter(r => r !== q).map(r => Math.hypot(r.x - q.x, r.y - q.y)));
  return s / ms.length;
}

test('attacco: dopo pochi secondi i compagni senza palla si sono allargati (niente grappoli)', () => {
  // Arrange / Act: 5 semi, 8 s di gioco, misura negli ultimi 3 s
  let sum = 0, n = 0, pairs = 0, frames = 0;
  for (const seed of [1, 2, 3, 4, 5]) {
    const { m, c } = scene(seed);
    for (let i = 0; i < 8 * 60; i++) {
      hold(m, c); m.step(DT); m.events.length = 0;
      if (i >= 5 * 60) {
        sum += spacing(m, c); n++; frames++;
        const ms = mates(m, c);
        for (let a = 0; a < ms.length; a++) for (let b = a + 1; b < ms.length; b++) if (Math.hypot(ms[a].x - ms[b].x, ms[a].y - ms[b].y) < 6) pairs++;
      }
    }
  }
  // Assert
  assert.ok(sum / n > 12, `distanza media dal compagno più vicino ${(sum / n).toFixed(1)} m`);
  assert.ok(pairs / frames < 0.3, `coppie di compagni a meno di 6 m: ${(pairs / frames).toFixed(2)} in media`);
});

test('attacco: nessun compagno senza palla resta addosso al portatore', () => {
  for (const seed of [1, 2, 3]) {
    const { m, c } = scene(seed);
    for (let i = 0; i < 8 * 60; i++) { hold(m, c); m.step(DT); m.events.length = 0; }
    const near = mates(m, c).filter(p => Math.hypot(p.x - c.x, p.y - c.y) < 6).length;
    assert.equal(near, 0, `seme ${seed}: ${near} compagni entro 6 m dal portatore`);
  }
});

test('attacco: le punte attaccano la profondità già dalla nostra metà campo (sulla linea del fuorigioco)', () => {
  const { m, c } = scene(2, -22);
  for (let i = 0; i < 8 * 60; i++) { hold(m, c); m.step(DT); m.events.length = 0; }
  const line = m.offLine[0], deep = m.team(0).filter(p => p.pos === 'A' && p.y > line - 4);
  assert.ok(deep.length >= 1, `punte vicino alla linea del fuorigioco (${line.toFixed(1)}): ${m.team(0).filter(p => p.pos === 'A').map(p => p.y.toFixed(1)).join(', ')}`);
  assert.ok(m.team(0).every(p => p.y <= line + 0.5), 'nessuno in fuorigioco');
});
