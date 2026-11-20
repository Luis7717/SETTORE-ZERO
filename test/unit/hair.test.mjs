// Capelli costruiti a codice (src/hair3d.js): ogni taglio si costruisce senza errori, senza buchi né numeri sbagliati,
// resta leggero e ha una forma diversa dagli altri. Testa finta: un cubo smussato come quella del modello Kenney.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { HAIR, makeBase, hairPieces } from '../../src/hair3d.js';
import { HAIR_STYLES } from '../../src/looks.js';

const pts = [];
for (let x = -1; x <= 1; x += 0.25) for (let y = -1; y <= 1; y += 0.25) for (let z = -1; z <= 1; z += 0.25) {
  if (Math.max(Math.abs(x), Math.abs(y), Math.abs(z)) < 1) continue;
  const k = Math.hypot(x, y, z) > 1.5 ? 0.9 : 1; // spigoli smussati
  pts.push([0.78 * x * k, 0.95 * y * k, 0.92 * z * k]);
}
const base = makeBase({ c: [0, 0, 0], up: [0, 1, 0], fwd: [0, 0, 1], right: [1, 0, 0], R: 1, pts }).base;
const MAX_TRIS = 2200; // per taglio (le treccine sono le più fitte)

test('un taglio per ogni nome dell\'editor, nello stesso ordine', () => {
  assert.equal(HAIR.length, HAIR_STYLES.length);
  assert.equal(HAIR[0], null); // calvo
});

test('ogni taglio: geometria valida, normali unitarie, leggera', () => {
  for (let s = 0; s < HAIR.length; s++) {
    const g = hairPieces(s, base), n = g.pos.length / 3, tris = g.ind.length / 3;
    assert.equal(g.nrm.length, g.pos.length, `taglio ${s}: normali`);
    assert.equal(g.uv.length / 2, n, `taglio ${s}: uv`);
    assert.ok(g.pos.every(Number.isFinite) && g.nrm.every(Number.isFinite) && g.uv.every(Number.isFinite), `taglio ${s}: numeri non finiti`);
    assert.ok(g.ind.every(i => i >= 0 && i < n), `taglio ${s}: indici fuori`);
    assert.ok(g.uv.every(u => u >= 0 && u <= 1), `taglio ${s}: uv fuori dalla zona dei capelli`);
    for (let i = 0; i < n; i++) { const l = Math.hypot(g.nrm[i * 3], g.nrm[i * 3 + 1], g.nrm[i * 3 + 2]); assert.ok(Math.abs(l - 1) < 1e-3, `taglio ${s}: normale ${l}`); }
    assert.ok(tris <= MAX_TRIS, `taglio ${s}: ${tris} triangoli`);
    if (s >= 2) assert.ok(tris > 0, `taglio ${s}: vuoto`);
    // normali verso l'esterno (in media): i triangoli non sono girati al contrario
    let out = 0; for (let i = 0; i < n; i++) out += g.nrm[i * 3] * g.pos[i * 3] + g.nrm[i * 3 + 1] * g.pos[i * 3 + 1] + g.nrm[i * 3 + 2] * g.pos[i * 3 + 2];
    if (n) assert.ok(out > 0, `taglio ${s}: normali verso l'interno`);
  }
});

const box = g => { const b = [Infinity, Infinity, Infinity, -Infinity, -Infinity, -Infinity]; for (let i = 0; i < g.pos.length; i += 3) for (let k = 0; k < 3; k++) { b[k] = Math.min(b[k], g.pos[i + k]); b[k + 3] = Math.max(b[k + 3], g.pos[i + k]); } return b; };

test('coda e chignon sporgono dietro la testa più degli altri tagli corti', () => {
  const tail = box(hairPieces(12, base)), bun = box(hairPieces(13, base)), slick = box(hairPieces(16, base));
  assert.ok(tail[2] < slick[2] - 0.4, 'la coda deve uscire dietro');
  assert.ok(tail[1] < -0.5, 'la coda deve scendere');
  assert.ok(bun[2] < slick[2] - 0.05 && bun[4] > slick[4] + 0.15, 'la crocchia deve stare in alto dietro');
});

test('tagli lunghi scendono, afro è il più voluminoso, cresta è stretta', () => {
  const b = s => box(hairPieces(s, base));
  assert.ok(b(11)[1] < b(10)[1] && b(10)[1] < b(2)[1], 'lunghi < caschetto < corti in basso');
  const vol = x => (x[3] - x[0]) * (x[4] - x[1]) * (x[5] - x[2]);
  for (const s of [2, 3, 4, 5, 8, 15, 16]) assert.ok(vol(b(9)) > vol(b(s)), `afro più grande di ${s}`);
  assert.ok(b(6)[3] - b(6)[0] < 0.8, 'cresta stretta');
});

test('ogni taglio ha una forma diversa dagli altri', () => {
  const sig = [];
  for (let s = 2; s < HAIR.length; s++) { const g = hairPieces(s, base); sig.push([s, box(g).concat(g.pos.length)]); }
  for (let i = 0; i < sig.length; i++) for (let j = i + 1; j < sig.length; j++) {
    const d = sig[i][1].reduce((a, v, k) => a + (k < 6 ? Math.abs(v - sig[j][1][k]) : 0), 0) + (sig[i][1][6] !== sig[j][1][6] ? 0.05 : 0);
    assert.ok(d > 0.02, `tagli ${sig[i][0]} e ${sig[j][0]} troppo simili`);
  }
});
