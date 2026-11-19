// Aspetto dei giocatori, stile della divisa, stemma, numeri di maglia, campione dell'editor e salvataggi vecchi.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Career, genPlayer, KITS } from '../../src/career.js';
import { Match, rng32, FORMATIONS } from '../../src/sim.js';
import { lookOf, lookFromSeed, normalizeLook, LOOK_N, LOOK_KEYS, squadNumbers, backName, normalizeKitStyle, KIT_OPTS, DEFAULT_KIT_STYLE } from '../../src/looks.js';
import { crestFromSeed, crestSvg, CREST_N, CREST_SHAPES, CREST_PATTERNS, CREST_ICONS } from '../../src/crest.js';

const mem = () => { const m = new Map(); return { getItem: k => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)), removeItem: k => m.delete(k), m }; };
const fresh = () => { globalThis.localStorage = mem(); const c = new Career(); c.create('FC Prova', 2); return c; };
const validLook = l => LOOK_KEYS.every(k => Number.isInteger(l[k]) && l[k] >= 0 && l[k] < LOOK_N[k]);
// salvataggio "vecchio": senza look, numeri, stile della divisa e stemma
const oldSave = () => { const c = fresh(), s = JSON.parse(JSON.stringify(c.s)); delete s.kitStyle; delete s.crest; for (const p of s.squad) { delete p.look; delete p.num; } return s; };

test('opzioni dell\'editor: almeno 15 tagli, 10 sagome, 10 motivi e 20 simboli dello stemma', () => {
  assert.ok(LOOK_N.hair >= 15); assert.equal(CREST_SHAPES.length, 10); assert.equal(CREST_PATTERNS.length, 10); assert.equal(CREST_ICONS.length, 20);
  assert.deepEqual(Object.keys(KIT_OPTS), ['fit', 'sleeves', 'collar', 'pattern', 'shorts', 'socks']);
});

test('aspetto di un giocatore senza look: deterministico da id e nome, valido, vario', () => {
  // Arrange
  const r = rng32(5), players = Array.from({ length: 40 }, (_, i) => genPlayer(r, 'C', 55, i + 1));
  // Act
  const a = players.map(lookOf), b = players.map(p => lookOf(JSON.parse(JSON.stringify(p))));
  // Assert
  assert.deepEqual(a, b);
  assert.ok(a.every(validLook));
  assert.ok(new Set(a.map(l => l.hair)).size >= 6, 'tagli diversi');
  assert.ok(new Set(a.map(l => l.skin)).size >= 4, 'carnagioni diverse');
});

test('look salvato: si usa quello (completato se manca un campo), senza modificare il giocatore', () => {
  const p = { id: 3, name: 'A. Rossi', look: { skin: 2, hair: 7 } };
  const l = lookOf(p);
  assert.equal(l.skin, 2); assert.equal(l.hair, 7); assert.ok(validLook(l));
  assert.deepEqual(p.look, { skin: 2, hair: 7 });
  assert.deepEqual(normalizeLook({ skin: 99, hair: -1 }).skin, 99 % LOOK_N.skin);
});

test('in partita l\'aspetto viene dal giocatore sorgente ed è lo stesso a ogni partita', () => {
  const c = fresh(), my = c.myMatchTeam(), opp = c.aiMatchTeam(c.team('t0'));
  const m1 = new Match({ seed: 11, teams: [my, opp] }), m2 = new Match({ seed: 999, teams: [c.myMatchTeam(), c.aiMatchTeam(c.team('t0'))] });
  for (let i = 0; i < 22; i++) { assert.deepEqual(m1.players[i].look, m2.players[i].look); assert.deepEqual(m1.players[i].look, lookOf(m1.players[i].src)); }
  // un cambio porta l'aspetto di chi entra
  const sub = my.bench[0]; m1.substitute(0, 5, sub);
  assert.deepEqual(m1.players[5].look, lookOf(sub));
});

test('avversari: stessa squadra = stessi aspetti, stile e stemma; squadre diverse = stemmi in genere diversi', () => {
  const c = fresh(), t = c.team('t3'), a = c.aiMatchTeam(t), b = c.aiMatchTeam(t);
  assert.deepEqual(a.players.map(p => p.look), b.players.map(p => p.look));
  assert.deepEqual(a.kit.style, b.kit.style); assert.deepEqual(a.kit.crest, b.kit.crest);
  assert.deepEqual(a.players.map(p => p.num), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
  assert.equal(a.kit.gk.gloves, true);
  const crests = new Set(Object.values(c.s.teams).map(x => JSON.stringify(c.teamCrest(x))));
  assert.ok(crests.size >= 15, 'stemmi variati: ' + crests.size);
});

test('numeri di maglia: nessun doppione, chi ha già un numero lo tiene', () => {
  const sq = [{ id: 1, pos: 'P', num: 9 }, { id: 2, pos: 'A', num: 9 }, { id: 3, pos: 'A' }, { id: 4, pos: 'P' }, ...Array.from({ length: 30 }, (_, i) => ({ id: 10 + i, pos: 'DCA'[i % 3] }))];
  const n = squadNumbers(sq), vals = [...n.values()];
  assert.equal(new Set(vals).size, vals.length);
  assert.equal(n.get(1), 9); assert.notEqual(n.get(2), 9);
  assert.equal(n.get(4), 1, 'portiere senza numero → 1');
  assert.ok(vals.every(v => v >= 1 && v <= 99));
  assert.equal(backName('L. Ferrante'), 'FERRANTE');
});

test('salvataggio vecchio senza look, numeri, divisa e stemma: si carica, valori predefiniti stabili', () => {
  // Arrange
  const s = oldSave(); globalThis.localStorage = mem(); localStorage.setItem('tag_save_v1', JSON.stringify(s));
  // Act
  const c = new Career(); assert.ok(c.load());
  const c2 = new Career(); c2.load();
  // Assert
  const nums = c.s.squad.map(p => p.num);
  assert.equal(new Set(nums).size, nums.length, 'numeri senza doppioni');
  assert.deepEqual(nums, c2.s.squad.map(p => p.num));
  assert.deepEqual(c.kitStyle(), DEFAULT_KIT_STYLE);
  assert.deepEqual(c.crest(), c2.crest());
  assert.ok(c.s.squad.every(p => p.look === undefined), 'l\'aspetto non si scrive nel salvataggio');
  assert.deepEqual(c.s.squad.map(lookOf), c2.s.squad.map(lookOf));
  const t = c.myMatchTeam(); assert.ok(t.kit.style && t.kit.crest && t.kit.gk.style);
});

test('campi nuovi salvati e ricaricati: stemma, stile della divisa, aspetto', () => {
  const c = fresh();
  c.setCrest({ shape: 4, pattern: 7, icon: 19 }); c.setKitStyle({ fit: 1, sleeves: 2, collar: 1, pattern: 3, shorts: 1, socks: 2 });
  const id = c.s.squad[3].id; c.setLook(id, { skin: 5, hair: 9, hairColor: 0, eyes: 3, eyeColor: 1, brows: 2, beard: 6, boots: 4 });
  const c2 = new Career(); c2.load();
  assert.deepEqual(c2.s.crest, { shape: 4, pattern: 7, icon: 19 });
  assert.deepEqual(c2.kitStyle(), { fit: 1, sleeves: 2, collar: 1, pattern: 3, shorts: 1, socks: 2 });
  assert.deepEqual(lookOf(c2.player(id)), { skin: 5, hair: 9, hairColor: 0, eyes: 3, eyeColor: 1, brows: 2, beard: 6, boots: 4 });
  assert.deepEqual(normalizeKitStyle({ fit: 7 }).fit, 7 % 2);
});

test('campione dell\'editor: entra in rosa col ruolo, l\'aspetto e il numero scelti, senza doppioni', () => {
  // Arrange
  const c = fresh(), before = c.s.squad.length, taken = c.s.squad.find(p => p.num === 10);
  const look = { skin: 3, hair: 6, hairColor: 7, eyes: 1, eyeColor: 4, brows: 3, beard: 2, boots: 2 };
  // Act
  const p = c.addChampion({ name: 'Leo Bomber', pos: 'C', look, num: 10 });
  // Assert
  assert.equal(c.s.squad.length, before + 1);
  assert.equal(p.name, 'Leo Bomber'); assert.equal(p.pos, 'C'); assert.equal(p.num, 10); assert.deepEqual(p.look, look); assert.ok(p.champ);
  assert.ok(p.age >= 17 && p.age <= 21, 'giovane');
  if (taken) assert.notEqual(taken.num, 10);
  const nums = c.s.squad.map(q => q.num); assert.equal(new Set(nums).size, nums.length);
  const c2 = new Career(); c2.load(); assert.deepEqual(c2.player(p.id).look, look);
});

test('stemma: deterministico dal seme, SVG coi colori della maglia', () => {
  assert.deepEqual(crestFromSeed(42), crestFromSeed(42));
  const c = crestFromSeed(7); for (const k of Object.keys(CREST_N)) assert.ok(c[k] >= 0 && c[k] < CREST_N[k]);
  const svg = crestSvg(c, KITS[1][1], KITS[1][2]);
  assert.match(svg, /^<svg class="crest/); assert.match(svg, /#1746a2/);
});
