// Esporta i riferimenti della carriera JS per il confronto col porting in GDScript (godot/tests/test_carriera.gd).
// Uso: node test/export-carriera.mjs   → godot/tests/fixtures/carriera.json
// Va rilanciato ogni volta che cambiano src/career.js, src/looks.js o src/crest.js (e il porting va aggiornato).
//
// Contenuto:
//  - pezzi: genPlayer, overall/overallAs/value, fmtMoney, hash32, lookFromSeed, kitStyleFromSeed, crestFromSeed,
//    normalizeLook/KitStyle/Crest, crestColors, squadNumbers, backName, Array.sort di V8 col confronto a caso;
//  - scenari di carriera a seme fisso: stato dopo create (calendario compreso), operazioni di mercato e rosa,
//    ogni giornata (squadre della partita, risultato, classifiche, soldi), fine stagione con promozioni e
//    retrocessioni, stato completo in alcuni punti.
import { writeFileSync, mkdirSync } from 'node:fs';
import { Career, overall, overallAs, value, fmtMoney, genPlayer, randomName } from '../src/career.js';
import { rng32 } from '../src/sim.js';
import { hash32, lookFromSeed, lookOf, kitStyleFromSeed, normalizeLook, normalizeKitStyle, squadNumbers, backName } from '../src/looks.js';
import { crestFromSeed, normalizeCrest, crestColors } from '../src/crest.js';

const OUT = 'godot/tests/fixtures';
const clone = x => JSON.parse(JSON.stringify(x));

// create() prende il seme da Date.now() e Math.random(): qui li si fissa per avere un seme noto
function createWithSeed(c, name, kit, seed) {
  const now = Date.now, rnd = Math.random;
  Date.now = () => seed; Math.random = () => 0;
  try { c.create(name, kit); } finally { Date.now = now; Math.random = rnd; }
  if (c.s.seed !== undefined && c.s.club !== name) throw new Error('create non riuscito');
}

// ---------------------------------------------------------------- pezzi
function pieces() {
  const players = [];
  for (const [seed, pos, level, id, young] of [[1, 'P', 54, 1, false], [2, 'D', 70.5, 2, true], [3, 'C', 62, -3, false], [4, 'A', 81.25, 4, true], [5, 'A', 50, 5, false], [99, 'C', 76, 6, true]]) {
    const r = rng32(seed);
    const p = genPlayer(r, pos, level, id, young);
    players.push({ args: [seed, pos, level, id, young], p, next: r(), overall: overall(p), value: value(p), as: ['P', 'D', 'C', 'A'].map(x => overallAs(p, x)) });
  }
  const names = []; { const r = rng32(17); for (let i = 0; i < 5; i++) names.push(randomName(r)); }
  const money = [0, 5, 999, 999.4, 999.5, 1000, 1125, 1135, 1005, -1125, 2500, 12345, -50, 250.4, 1999995];
  const hashes = [['club', 'FC Prova'], ['look', 0], ['look', 123456789], ['crest', 4294967295], ['kit', -7], ['Città di Pàlermo', 'é'], ['😀 emoji', 1.5], [3, 'x', null], ['me', 'FC Tiro a Giro']];
  const seeds = [0, 1, 7, 42, 977, 123456789, 999999999, 4294967295];
  const sortRuns = [];
  // (sotto 8 elementi V8 recente usa un altro metodo: career.js mescola solo liste da 10 e da 32)
  for (const [seed, n] of [[1, 8], [2, 9], [3, 10], [4, 10], [5, 32], [6, 63], [7, 17]]) {
    const r = rng32(seed), a = [...Array(n).keys()];
    let calls = 0;
    a.sort(() => { calls++; return r() - 0.5; });
    sortRuns.push({ seed, n, out: a, calls });
  }
  const squad = [{ id: 1, pos: 'P' }, { id: 2, pos: 'P', num: 1 }, { id: 3, pos: 'D', num: 4 }, { id: 4, pos: 'D', num: 4 }, { id: 5, pos: 'A', num: 0 }, { id: 6, pos: 'A' }, { id: 7, pos: 'C', num: 99 }, { id: 8, pos: 'X' }];
  return {
    players, names,
    money: money.map(k => [k, fmtMoney(k)]),
    hash32: hashes.map(h => [h, hash32(...h)]),
    looks: seeds.map(s => [s, lookFromSeed(s)]),
    lookOf: [{ id: 5, name: 'L. Ferrante' }, { id: 6, name: 'M. Rossi', look: { skin: 9, hair: -1 } }, { id: -1, name: '' }].map(p => [p, lookOf(p)]),
    kitStyles: seeds.map(s => [s, kitStyleFromSeed(s)]),
    crests: seeds.map(s => [s, crestFromSeed(s)]),
    normLook: [[{ skin: -1, hair: 99, eyes: 2.5, boots: 7 }, normalizeLook({ skin: -1, hair: 99, eyes: 2.5, boots: 7 })], [null, normalizeLook(null)]],
    normKit: [[{ fit: 3, sleeves: -1, collar: 'x' }, normalizeKitStyle({ fit: 3, sleeves: -1, collar: 'x' })], [null, normalizeKitStyle(null)]],
    normCrest: [[{ shape: 12, pattern: -1, icon: 5.5 }, normalizeCrest({ shape: 12, pattern: -1, icon: 5.5 })], [null, normalizeCrest(null)]],
    crestColors: [[0xc8102e, 0xffffff], [0xf2c200, 0x1b1b1b], [0x1c1c22, 0xe8e8e8], [0xf2f2f2, 0xf0f0f0], [0x222222, 0x333333], [0x7a1230, 0xf0d9a0]].map(([a, b]) => [a, b, crestColors(a, b)]),
    squadNumbers: [...squadNumbers(squad).entries()],
    backName: ['L. Ferrante', 'Mario', '', 'A.B. De Rossi Lunghissimo'].map(n => [n, backName(n)]),
    sort: sortRuns,
  };
}

// ---------------------------------------------------------------- scenari di carriera
const digest = c => ({
  seed: c.s.seed, money: c.s.money, day: c.s.day, season: c.s.season, nextId: c.s.nextId, divs: clone(c.s.divs),
  tables: [0, 1, 2].map(d => c.table(d)), lineup: clone(c.s.lineup), rating: c.s.teams.me.rating, last: clone(c.s.last),
  market: c.s.market.map(p => [p.id, p.name, p.pos, p.age, p.price, overall(p)]),
});

function goalsLog(c, n) {
  const log = [];
  for (let k = 0; k < n; k++) {
    const scorer = c.player(c.s.lineup[9 + (k % 2)]), assist = k % 3 === 2 ? null : c.player(c.s.lineup[7]);
    log.push({ team: 0, scorer: { id: scorer.id }, assist: assist ? { id: assist.id } : null });
  }
  log.push({ team: 1, scorer: { id: 9999 }, assist: null }); // gol avversario: non conta per i miei
  return log;
}

function scenario({ name, seed, kit, mode, days, ops, diffAt }) {
  const c = new Career();
  createWithSeed(c, name, kit, seed);
  const out = { name, seed, kit, mode, created: clone(c.s), ops: [], days: [], snapshots: {} };
  if (ops) {
    const cheapest = c.s.market.slice().sort((a, b) => a.price - b.price || a.id - b.id)[0];
    out.ops.push(['buy', cheapest.id, c.buy(cheapest.id)]);
    out.ops.push(['buy', 123456, c.buy(123456)]);
    const b = c.bench();
    out.ops.push(['sell', b[b.length - 1].id, c.sell(b[b.length - 1].id)]);
    out.ops.push(['sellPrice', c.s.squad[3].id, c.sellPrice(c.s.squad[3])]);
    out.ops.push(['swap', c.s.lineup[9], c.bench()[0].id, c.swap(c.s.lineup[9], c.bench()[0].id) ?? null]);
    c.setKitStyle({ fit: 1, sleeves: 4, collar: 2, pattern: 3, shorts: 1, socks: 2 });
    c.setCrest({ shape: 12, pattern: -1, icon: 5 });
    const champ = c.addChampion({ name: '  Campione Prova Con Un Nome Lungo  ', pos: 'A', look: { skin: 3, hair: 20, beard: 2 }, num: 9 });
    out.ops.push(['addChampion', clone(champ)]);
    out.ops.push(['setLook', c.setLook(c.s.squad[5].id, { skin: 7, eyes: 3 }), c.setLook(424242, {})]);
    out.ops.push(['kitStyle', c.kitStyle(), 'crest', c.crest(), 'teamCrest', c.teamCrest(c.team('t3')), c.teamCrest({ id: 'x9', name: 'Senza Seme' })]);
    out.ops.push(['myRating', c.myRating(), 'divOf', c.divOf(c.team('t0')), c.divOf({ id: 'amico' }), 'skillOf', c.skillOf(66, 0), c.skillOf(40)]);
    c.refreshMarket(7);
    out.snapshots.afterOps = clone(c.s);
  }
  for (let i = 0; i < days; i++) {
    if (diffAt !== undefined && i === diffAt) c.s.settings.diff = 2;
    const nm = c.nextMatch(), my = c.myMatchTeam(), opp = c.aiMatchTeam(nm.opp);
    const [gm, go] = mode === 'win' ? [4, 1] : c.simScore(c.myRating(), nm.opp.rating);
    const res = c.finishMatch(gm, go, goalsLog(c, gm));
    const day = { nm: { home: nm.home, opp: nm.opp.id, day: nm.day, div: nm.div }, score: [gm, go], res, digest: digest(c) };
    if (i < 2 || res.season) { day.myTeam = clone(my); day.oppTeam = clone(opp); } else day.oppTeam = { formation: opp.formation, skill: opp.skill, kit: opp.kit, p0: opp.players[0], p10: opp.players[10] };
    out.days.push(day);
    if (res.season) out.snapshots['season' + (c.s.season - 1)] = clone(c.s);
  }
  out.final = clone(c.s);
  return out;
}

const fixture = {
  pieces: pieces(),
  scenarios: [
    scenario({ name: 'FC Città Prova', seed: 12345, kit: 3, mode: 'sim', days: 20, ops: true, diffAt: 10 }),
    scenario({ name: '1 2 3', seed: 2024, kit: 0, mode: 'win', days: 55, ops: false }),
  ],
};
mkdirSync(OUT, { recursive: true });
const txt = JSON.stringify(fixture);
writeFileSync(`${OUT}/carriera.json`, txt);
console.log(`scritto ${OUT}/carriera.json (${(txt.length / 1024).toFixed(0)} KB): ${fixture.scenarios.map(s => `${s.name}: ${s.days.length} giornate, esiti ${s.days.filter(d => d.res.season).map(d => d.res.season.outcome).join('/')}`).join(' · ')}`);
