// Stadio robusto (segnalazione dall'iPhone del 2026-11-20: "in partita manca lo sfondo"): ogni pezzo si costruisce per
// conto suo, un canvas negato (memoria dei canvas di Safari iOS finita) o un metodo mancante (ctx.roundRect prima di
// iOS 16) toglie solo quel pezzo; i canvas delle texture si svuotano dopo il caricamento sulla GPU e si rifanno se serve.
import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import { buildStadium, stadiumSummary, FALLBACK_SKY } from '../../src/stadium.js';
import { releaseCanvas, restoreTextures, releasedCount, reviveCanvas } from '../../src/canvas-mem.js';
import { redrawTex, canvasTex } from '../../src/stadium-kit.js';
import { logError, canvasBytes, diagLines, MAX_ERRS, errText } from '../../src/diag.js';

// ---------------------------------------------------------------- finto canvas 2D (accetta qualunque disegno)
function fakeCtx(canvas, missing) {
  const store = {};
  return new Proxy(store, {
    get(t, k) {
      if (k in t) return t[k];
      if (missing.has(k)) return undefined;
      if (k === 'canvas') return canvas;
      if (k === 'measureText') return s => ({ width: String(s).length * 10 });
      if (k === 'getImageData') return (x, y, w, h) => ({ data: new Uint8ClampedArray(w * h * 4) });
      if (k === 'createImageData') return (w, h) => ({ data: new Uint8ClampedArray(w * h * 4) });
      return () => ({ addColorStop() {} });
    },
    set(t, k, v) { t[k] = v; return true; },
  });
}
// deny(w, h, n): true se l'n-esimo canvas (w×h) non deve avere il contesto 2D
function installDocument({ deny = () => false, missing = [] } = {}) {
  const made = [], miss = new Set(missing);
  globalThis.document = {
    createElement(name) {
      assert.equal(name, 'canvas');
      const c = { width: 300, height: 150, n: made.length };
      c.getContext = () => (deny(c.width, c.height, c.n) ? null : fakeCtx(c, miss));
      made.push(c);
      return c;
    },
  };
  return made;
}
const KIT_A = { shirt: 0xd23b3b, shorts: 0xffffff }, KIT_B = { shirt: 0x2f6fd6, shorts: 0xf2c230 };
const build = (opts = {}) => {
  const scene = new THREE.Scene(), errs = [];
  const st = buildStadium(scene, { ...opts, onError: (w, e) => errs.push([w, errText(e)]) });
  return { scene, st, errs };
};
const ALL = ['cielo', 'texture tribune', 'texture pubblico', 'texture cartelloni', 'texture luci', 'texture bandiere',
  'tribune (forma)', 'tribuna dietro (forma)', 'cartelloni (forma)', 'panchine', 'tribune', 'pubblico', 'luci', 'cartelloni',
  'bandiere', 'maxischermo', 'tribuna dietro', 'pubblico dietro', 'luci dietro', 'terreno'];

test('stadio completo: tutti i pezzi ci sono, nessun errore', () => {
  installDocument();
  const { scene, st, errs } = build();
  assert.deepEqual(errs, []);
  for (const k of ALL) assert.equal(st.parts[k], true, k);
  assert.equal(stadiumSummary(st), 'ok');
  assert.equal(scene.background.getHex(), 0x0b1028);
  assert.ok(st.root.children.length >= 9, 'cielo, struttura, pubblico, luci, cartelloni, bandiere, schermo, tribuna dietro, terreno');
  assert.equal(st.crowdMats.length, 2);
  assert.equal(st.textures.length, 7, 'cielo, tribune, pubblico, cartelloni, luci, bandiere, maxischermo');
});

test('senza ctx.roundRect (Safari prima di iOS 16) il pubblico si disegna lo stesso', () => {
  installDocument({ missing: ['roundRect'] });
  const { st, errs } = build();
  assert.deepEqual(errs, []);
  assert.equal(st.parts['texture pubblico'], true);
  assert.equal(st.parts.pubblico, true);
});

test('canvas del pubblico negato: manca solo il pubblico, il resto dello stadio resta', () => {
  let big = 0; // il secondo canvas 1024×1024 è quello del pubblico (il primo è l'atlante delle tribune)
  installDocument({ deny: (w, h) => w === 1024 && h === 1024 && ++big === 2 });
  const { st, errs } = build();
  assert.equal(st.parts['texture pubblico'], false);
  assert.equal(st.parts.pubblico, false);
  assert.equal(st.parts['pubblico dietro'], false);
  for (const k of ['cielo', 'tribune', 'luci', 'cartelloni', 'bandiere', 'maxischermo', 'tribuna dietro', 'terreno']) assert.equal(st.parts[k], true, k);
  assert.ok(errs.some(([w, m]) => w === 'stadio/texture pubblico' && /contesto 2D/.test(m)), JSON.stringify(errs));
  assert.match(stadiumSummary(st), /^senza .*pubblico/);
  // la partita va avanti: aggiornamento e colori delle squadre non lanciano
  st.update(0.016, 0.5, { phase: 'play', score: [1, 0] });
  st.setTeams(KIT_A, KIT_B, ['CASA', 'OSP']);
});

test('nessun canvas disponibile: niente texture, ma tribune e terreno ci sono e lo sfondo non è nero', () => {
  installDocument({ deny: () => true });
  const { scene, st, errs } = build();
  assert.equal(st.parts.cielo, false);
  assert.equal(scene.background.getHex(), FALLBACK_SKY);
  assert.notEqual(FALLBACK_SKY, 0x000000);
  assert.equal(st.parts.tribune, true, 'struttura coi soli colori dei vertici');
  assert.equal(st.parts.terreno, true);
  for (const k of ['pubblico', 'luci', 'cartelloni', 'bandiere', 'maxischermo']) assert.equal(st.parts[k], false, k);
  assert.ok(errs.length >= 6);
  st.update(0.016, 0, { phase: 'goal', score: [1, 0] });
  st.setTeams(KIT_A, KIT_B, ['CASA', 'OSP']);
  assert.deepEqual(st.textures, []);
});

test('un pezzo che lancia a metà (bandiere) non toglie gli altri', () => {
  installDocument({ deny: (w, h) => w === 512 && h === 256 }); // texture delle bandiere
  const { st } = build();
  assert.equal(st.parts.bandiere, false);
  for (const k of ['pubblico', 'tribune', 'maxischermo', 'cartelloni']) assert.equal(st.parts[k], true, k);
});

// ---------------------------------------------------------------- canvas svuotati dopo il caricamento sulla GPU
function fakeRenderer(lost = false) {
  const up = [];
  return { up, initTexture: t => up.push([t, t.image.width, t.image.height]), getContext: () => ({ isContextLost: () => lost }) };
}

test('releaseCanvas: carica la texture, svuota il canvas, lo rifà per i ridisegni e al ritorno del contesto', () => {
  const made = installDocument();
  const r = fakeRenderer(), t = canvasTex(256, 128, g => g.fillRect(0, 0, 1, 1));
  const freed = releaseCanvas(r, t);
  assert.equal(freed, 256 * 128 * 4);
  assert.equal(r.up.length, 1); assert.deepEqual(r.up[0].slice(1), [256, 128], 'caricata quando il canvas era ancora pieno');
  assert.equal(t.image.width, 0); assert.equal(t.image.height, 0);
  assert.equal(canvasBytes(made), 0);
  assert.equal(releasedCount(r), 1);
  // ridisegno (es. colori dei tifosi): canvas rifatto, ricaricato, svuotato di nuovo
  redrawTex(t, g => g.fillRect(0, 0, 2, 2));
  assert.equal(r.up.length, 2); assert.deepEqual(r.up[1].slice(1), [256, 128]);
  assert.equal(t.image.width, 0);
  // contesto perso e tornato: ridisegnate e ricaricate
  assert.equal(restoreTextures(r), 1);
  assert.equal(r.up.length, 3); assert.deepEqual(r.up[2].slice(1), [256, 128]);
  assert.equal(t.image.width, 0);
  // texture eliminata: esce dall'elenco
  t.dispose();
  assert.equal(releasedCount(r), 0);
});

test('releaseCanvas: con il contesto perso o senza renderer il canvas resta pieno', () => {
  installDocument();
  const t = canvasTex(64, 64, () => {});
  assert.equal(releaseCanvas(fakeRenderer(true), t), 0);
  assert.equal(t.image.width, 64);
  assert.equal(releaseCanvas(null, t), 0);
  assert.equal(releaseCanvas({}, t), 0);
  assert.equal(reviveCanvas(t), true);
});

test('stadio: tutte le texture si possono svuotare (memoria dei canvas da ~15 MB a 0)', () => {
  const made = installDocument();
  const { st } = build();
  st.setTeams(KIT_A, KIT_B, ['CASA', 'OSP']);
  const before = canvasBytes(made);
  assert.ok(before > 14 * 1048576, `canvas dello stadio ${(before / 1048576).toFixed(1)} MB`);
  const r = fakeRenderer();
  for (const t of st.textures) releaseCanvas(r, t);
  assert.equal(canvasBytes(made), 0);
  // un ridisegno dopo (nuove squadre, nuovo risultato) rifà solo per un attimo i canvas che servono
  st.setTeams(KIT_B, KIT_A, ['OSP', 'CASA']);
  st.update(0.016, 0, { phase: 'play', score: [2, 1] });
  assert.equal(canvasBytes(made), 0);
});

// ---------------------------------------------------------------- diagnostica
test('logError: errori uguali di fila si contano, al massimo MAX_ERRS', () => {
  const win = {};
  const quiet = console.error; console.error = () => {};
  try {
    logError('stadio', new Error('x'), win); logError('stadio', new Error('x'), win);
    assert.equal(win.__errs.length, 1); assert.equal(win.__errs[0].n, 2);
    for (let i = 0; i < 30; i++) logError('a', 'e' + i, win);
    assert.equal(win.__errs.length, MAX_ERRS);
    assert.equal(win.__errs[MAX_ERRS - 1].msg, 'e29');
  } finally { console.error = quiet; }
});

test('diagLines: stadio, WebGL e ultimi errori in righe brevi', () => {
  const win = { __errs: [] };
  assert.deepEqual(diagLines({ stadium: 'ok', gl: 'WebGL2' }, win), ['stadio: ok · WebGL2', 'nessun errore']);
  win.__errs.push({ where: 'stadio/pubblico', msg: 'canvas senza contesto', n: 3 });
  const lines = diagLines({ stadium: 'senza pubblico' }, win);
  assert.equal(lines[0], 'stadio: senza pubblico');
  assert.equal(lines[1], 'stadio/pubblico: canvas senza contesto (×3)');
  assert.equal(canvasBytes([{ width: 1024, height: 1024 }, { width: 0, height: 5 }, null]), 4 * 1048576);
});
