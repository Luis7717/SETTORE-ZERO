// Rosa: carte nel campo senza sovrapposizioni per ogni formazione, scambio che lascia la formazione valida,
// variazione della forza con uno scambio, nome breve e ritratto SVG.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { FORMATIONS } from '../../src/sim.js';
import { Career, overallAs } from '../../src/career.js';
import { fieldRows, fieldLayout, overlaps, canSwap, swapLineup, swapDelta, CARD_W } from '../../src/squad-layout.js';
import { faceSvg } from '../../src/face2d.js';
import { shortName, benchOrder, pickCard } from '../../src/ui-squad.js';
import { HAIR_STYLES, BEARDS } from '../../src/looks.js';

// campo a 390 px di schermo (358 + 2×10 di margine negativo) e altezze da iPhone piccolo a grande
const W = 378, HEIGHTS = [330, 380, 403, 460, 560];

test('ogni formazione: file dal portiere agli attaccanti', () => {
  for (const [name, F] of Object.entries(FORMATIONS)) {
    const rows = fieldRows(F);
    assert.deepEqual(rows[0], [0], name + ': il portiere sta da solo nella prima fila');
    assert.equal(rows.flat().length, 11, name);
    assert.ok(rows.at(-1).every(i => F[i][0] === 'A'), name + ': ultima fila di attaccanti');
  }
});

test('carte nel campo: niente sovrapposizioni, dentro il campo, portiere in basso e attaccanti in alto', () => {
  for (const [name, F] of Object.entries(FORMATIONS)) {
    for (const H of HEIGHTS) {
      const { cards, w, h, scale } = fieldLayout(F, W, H);
      assert.equal(cards.length, 11);
      assert.ok(w >= 56 * 0.72 && scale <= 1, `${name} ${H}: carta troppo piccola`);
      if (H >= 380) assert.ok(w >= 56, `${name} ${H}: carta larga almeno 56 px (${w})`);
      for (const c of cards) {
        assert.ok(c.x - w / 2 >= 0 && c.x + w / 2 <= W, `${name} ${H}: carta fuori in larghezza`);
        assert.ok(c.y - h / 2 >= 0 && c.y + h / 2 <= H, `${name} ${H}: carta fuori in altezza`);
      }
      for (let i = 0; i < 11; i++) for (let j = i + 1; j < 11; j++) assert.ok(!overlaps(cards[i], cards[j], w, h), `${name} ${H}: carte ${i} e ${j} sovrapposte`);
      const gk = cards[0].y;
      assert.ok(cards.every((c, i) => i === 0 || c.y < gk), `${name}: il portiere è il più in basso`);
      const att = cards.filter((_, i) => F[i][0] === 'A'), others = cards.filter((_, i) => F[i][0] !== 'A');
      assert.ok(Math.max(...att.map(c => c.y)) < Math.min(...others.map(c => c.y)), `${name}: attaccanti in alto`);
    }
  }
});

test('carte nel campo: a sinistra quelle con x negativa (la squadra attacca verso l\'alto)', () => {
  const F = FORMATIONS['4-4-2'], { cards } = fieldLayout(F, W, 420);
  assert.ok(cards[1].x < cards[4].x, 'terzino sinistro a sinistra');
  assert.ok(Math.abs(cards[0].x - W / 2) < 0.5, 'portiere al centro');
  // formazione simmetrica → carte simmetriche
  assert.ok(Math.abs((cards[1].x + cards[4].x) / 2 - W / 2) < 0.5);
});

test('a grandezza piena su iPhone 390×844 (con le aree sicure) le carte restano larghe 64 px', () => {
  for (const F of Object.values(FORMATIONS)) assert.equal(fieldLayout(F, W, 403).w, CARD_W);
});

function career() { const c = new Career(); c.create('FC Prova', 0); return c; }

test('scambio campo↔campo e campo↔panchina: formazione sempre di 11 giocatori diversi della rosa', () => {
  const c = career(), s = c.s, ids = new Set(s.squad.map(p => p.id));
  const valid = () => { assert.equal(s.lineup.length, 11); assert.equal(new Set(s.lineup).size, 11); assert.ok(s.lineup.every(id => ids.has(id))); };
  const [a, b] = s.lineup, bench = c.bench()[0].id;
  c.swap(a, b); valid(); assert.equal(s.lineup[0], b); assert.equal(s.lineup[1], a);
  c.swap(s.lineup[3], bench); valid(); assert.equal(s.lineup[3], bench);
  const before = s.lineup.slice(), b2 = c.bench().map(p => p.id);
  c.swap(b2[0], b2[1]); assert.deepEqual(s.lineup, before, 'panchina↔panchina non cambia niente');
  c.swap(before[2], before[2]); assert.deepEqual(s.lineup, before, 'con se stesso non cambia niente');
});

test('swapLineup non modifica la formazione passata', () => {
  const l = [1, 2, 3], out = swapLineup(l, 1, 9);
  assert.deepEqual(l, [1, 2, 3]); assert.deepEqual(out, [9, 2, 3]);
  assert.deepEqual(swapLineup(l, 3, 1), [3, 2, 1]);
  assert.equal(canSwap(l, 4, 5), false); assert.equal(canSwap(l, 4, 1), true); assert.equal(canSwap(l, 1, 1), false);
});

test('swapDelta è la variazione esatta della somma delle valutazioni', () => {
  const c = career(), s = c.s, F = FORMATIONS[s.formation];
  const sum = l => l.reduce((t, id, i) => t + overallAs(c.player(id), F[i][0]), 0);
  const bench = c.bench();
  for (const [a, b] of [[s.lineup[0], s.lineup[5]], [s.lineup[2], bench[0].id], [bench[1].id, s.lineup[9]]]) {
    const d = swapDelta(s.lineup, F, c.player(a), c.player(b), overallAs);
    assert.equal(sum(swapLineup(s.lineup, a, b)) - sum(s.lineup), d);
  }
});

test('tocchi: scelta, confronto, scambio col secondo tocco', () => {
  const c = career(), s = c.s, ui = { c, sel: null, tgt: null, just: null };
  const a = s.lineup[4], b = c.bench()[0].id;
  pickCard(ui, a); assert.equal(ui.sel, a); assert.equal(ui.tgt, null);
  pickCard(ui, b); assert.equal(ui.tgt, b); assert.ok(s.lineup.includes(a), 'il confronto non scambia ancora');
  pickCard(ui, b); assert.equal(s.lineup[4], b); assert.deepEqual(ui.just, [a, b]); assert.equal(ui.sel, null);
  const [x, y] = c.bench().map(p => p.id);
  pickCard(ui, x); pickCard(ui, y); assert.equal(ui.sel, y, 'panchina → panchina sceglie l\'altro'); assert.equal(ui.tgt, null);
  pickCard(ui, y); assert.equal(ui.sel, null, 'toccare di nuovo il scelto lo toglie');
});

test('nome breve e ordine della panchina', () => {
  assert.equal(shortName('L. Ferrante'), 'Ferrante');
  assert.equal(shortName('Leo Bomber'), 'Leo Bomber');
  assert.equal(shortName('Massimiliano Bomberone'), 'Bomberone');
  const c = career(), order = benchOrder(c.bench());
  assert.ok(order.every((p, i) => i === 0 || 'PDCA'.indexOf(order[i - 1].pos) <= 'PDCA'.indexOf(p.pos)));
});

test('ritratto SVG per ogni taglio e barba, anche con aspetto vecchio o mancante', () => {
  for (let hair = 0; hair < HAIR_STYLES.length; hair++) for (let beard = 0; beard < BEARDS.length; beard++) {
    const svg = faceSvg({ skin: hair % 8, hair, hairColor: beard, beard }, '#c8102e', '#ffffff');
    assert.match(svg, /^<svg[^>]*viewBox="0 0 40 40"[\s\S]*<\/svg>$/);
    assert.ok(!svg.includes('undefined') && !svg.includes('NaN'));
  }
  assert.match(faceSvg(undefined, '#000000', '#ffffff'), /<svg/);
});
