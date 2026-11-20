// three.js sta in www/assets/three.min.js, non dentro www/index.html (che deve restare sotto 1 MB con margine).
// Controlla la build salvata in www/ (npm run build la rigenera; build.mjs fa lo stesso controllo sul metafile).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, statSync } from 'node:fs';
import { createContext, runInContext } from 'node:vm';

const INDEX = 'www/index.html', THREE_FILE = 'www/assets/three.min.js';
// frase dei messaggi interni di three.js: c'è solo dove c'è il codice di three
const THREE_MARK = 'THREE.WebGLRenderer:';
const MAX_INDEX_KB = 700; // limite vero 1 MB; qui si tiene margine per il codice che arriverà

test('www/index.html non contiene three.js e resta sotto i 700 KB', () => {
  const html = readFileSync(INDEX, 'utf8');
  assert.equal(html.includes(THREE_MARK), false, 'three.js è tornato dentro www/index.html');
  assert.ok(statSync(INDEX).size < MAX_INDEX_KB * 1024, `www/index.html pesa ${statSync(INDEX).size >> 10} KB`);
});

test('index.html carica three.min.js prima del codice e ha il messaggio se manca', () => {
  const html = readFileSync(INDEX, 'utf8');
  const tag = html.indexOf('<script src="assets/three.min.js"></script>');
  assert.ok(tag > 0, 'manca il tag di three.min.js');
  assert.ok(tag < html.lastIndexOf('<script>'), 'three.min.js va caricato prima del codice del gioco');
  assert.ok(html.includes('if(!window.__THREE||!window.__THREE_ADDONS)'), 'manca il controllo col messaggio');
  assert.ok(html.includes('id="nothree"'));
  assert.ok(statSync(THREE_FILE).size < 20 * 1024 * 1024);
});

test('three.min.js crea tutto three e ogni addon che il gioco chiede', async () => {
  const ctx = createContext({});
  ctx.globalThis = ctx;
  runInContext(readFileSync(THREE_FILE, 'utf8'), ctx);
  const real = await import('three');
  assert.deepEqual(Object.keys(ctx.__THREE).sort(), Object.keys(real).sort(), 'three nel file non è intero');
  const asked = [...readFileSync(INDEX, 'utf8').matchAll(/__THREE_ADDONS\["([^"]+)"\]/g)].map(m => m[1]);
  assert.ok(asked.includes('examples/jsm/loaders/GLTFLoader.js'));
  for (const key of asked) {
    const mod = ctx.__THREE_ADDONS[key];
    assert.ok(mod && Object.keys(mod).length > 0, `addon ${key} mancante in three.min.js`);
  }
  assert.equal(typeof ctx.__THREE_ADDONS['examples/jsm/loaders/GLTFLoader.js'].GLTFLoader, 'function');
});
