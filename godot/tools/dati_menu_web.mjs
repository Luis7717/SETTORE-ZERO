// Valori del web per i menu Godot: tests/fixtures/menu.json (visi, stemmi, semi, disposizione delle carte,
// nomi brevi: tests/test_menu_*.gd) e tests/fixtures/carriera_menu.json (carriera di prova per le schermate).
// Uso (dalla cartella del repo):  node godot/tools/dati_menu_web.mjs
import { faceSvg } from '../../src/face2d.js';
import { crestSvg, crestFromSeed } from '../../src/crest.js';
import { lookFromSeed, lookOf } from '../../src/looks.js';
import { fieldLayout } from '../../src/squad-layout.js';
import { shortName } from '../../src/ui-squad.js';
import { FORMATIONS } from '../../src/sim.js';
import { Career } from '../../src/career.js';
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
const out = n => fileURLToPath(new URL('../tests/fixtures/' + n, import.meta.url));
const faces = [];
for (let i = 0; i < 40; i++) { const look = lookFromSeed(i * 7919); faces.push({ look, shirt: '#c8102e', collar: '#ffffff', svg: faceSvg(look, '#c8102e', '#ffffff') }); }
for (let h = 0; h < 17; h++) { const look = { skin: h % 8, hair: h, hairColor: h % 11, eyes: 0, eyeColor: 0, brows: 0, beard: h % 7, boots: 0 }; faces.push({ look, shirt: '#1746a2', collar: '#f2c200', svg: faceSvg(look, '#1746a2', '#f2c200') }); }
const crests = [];
const KC = [[0xc8102e, 0xffffff], [0xf2c200, 0x1b1b1b], [0x1c1c22, 0xe8e8e8], [0xf2f2f2, 0x1b2a5c], [0x4aa3df, 0xffffff]];
for (let i = 0; i < 30; i++) { const c = { shape: i % 10, pattern: (i * 3) % 10, icon: i % 20 }; const [c1, c2] = KC[i % KC.length]; crests.push({ c, c1, c2, svg: crestSvg(c, c1, c2, 'x').replace(/cs\d+/g, 'ID') }); }
const seeds = [0, 1, 3, 10, 17, 24, 31, 66, 123456, 987654321].map(s => ({ seed: s, crest: crestFromSeed(s), look: lookFromSeed(s) }));
const players = [{ id: 1, name: 'L. Ferrante' }, { id: 7, name: 'M. Rossi' }, { id: -3, name: 'A. Benali' }, { id: 22, name: '' }].map(p => ({ p, look: lookOf(p) }));
const layouts = [];
for (const f of Object.keys(FORMATIONS)) for (const [W, H] of [[358, 420], [358, 300], [300, 200], [390, 520]]) layouts.push({ f, W, H, L: fieldLayout(FORMATIONS[f], W, H) });
const names = ['L. Ferrante', 'Ferrante', 'M. De la Fuente Gomez', 'Abc', 'X. Lungonomeassai', '', 'A. B. Carlo Magno'].map(n => [n, shortName(n)]);
writeFileSync(out('menu.json'), JSON.stringify({ faces, crests, seeds, players, layouts, names }));

// carriera di prova: seme fisso, campione, 3 giornate giocate
let t = 1700000000000; Date.now = () => t;
let ms = 12345; Math.random = () => { ms = (ms * 16807) % 2147483647; return ms / 2147483647; };
globalThis.localStorage = { getItem: () => null, setItem: () => {}, removeItem: () => {} };
const c = new Career();
c.create('Atletico Sole', 3);
c.addChampion({ name: 'L. Mancini', pos: 'A', look: { skin: 2, hair: 4, hairColor: 5, eyes: 1, eyeColor: 4, brows: 2, beard: 1, boots: 3 }, num: 10 });
const res = [];
for (const [x, y] of [[2, 1], [0, 0], [1, 3]]) res.push(c.finishMatch(x, y, [{ team: 0, name: c.s.squad[0].name, minute: 23, scorer: { id: c.s.squad[0].id } }]));
writeFileSync(out('carriera_menu.json'), JSON.stringify({ s: c.s, lastRes: res[res.length - 1] }, null, 1));
console.log('ok: menu.json, carriera_menu.json');
