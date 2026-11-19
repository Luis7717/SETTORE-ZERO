import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Assets } from '../../src/assets.js';

const buf = n => new Uint8Array(n).buffer;
const fakeFetch = (files, log = []) => async (url) => {
  log.push(url);
  if (url in files) { const f = files[url]; if (f instanceof Error) throw f; return { ok: true, status: 200, arrayBuffer: async () => f }; }
  return { ok: false, status: 404 };
};

test('carica i file di una tappa con avanzamento', async () => {
  const man = { match: [{ id: 'a', file: 'x/a.bin' }, { id: 'b', file: 'b.bin' }] };
  const prog = [];
  const A = new Assets({ manifest: man, fetchFn: fakeFetch({ 'assets/x/a.bin': buf(3), 'assets/b.bin': buf(5) }) });
  const r = await A.loadStage('match', (d, t) => prog.push([d, t]));
  assert.deepEqual(r.failed, []);
  assert.deepEqual(r.ok.sort(), ['a', 'b']);
  assert.equal(A.get('a').byteLength, 3);
  assert.deepEqual(prog.at(-1), [2, 2]);
});

test('un file mancante o in errore viene saltato e il resto arriva lo stesso', async () => {
  const man = { match: [{ id: 'ok', file: 'ok.bin' }, { id: 'manca', file: 'manca.bin' }, { id: 'rotto', file: 'rotto.bin' }] };
  const A = new Assets({ manifest: man, fetchFn: fakeFetch({ 'assets/ok.bin': buf(1), 'assets/rotto.bin': new Error('rete') }) });
  const r = await A.loadStage('match');
  assert.deepEqual(r.ok, ['ok']);
  assert.deepEqual(r.failed.sort(), ['manca', 'rotto']);
  assert.equal(A.get('manca'), null);
  assert.equal(A.has('ok'), true);
});

test('tappa vuota o sconosciuta: finisce subito senza richieste', async () => {
  const log = [], prog = [];
  const A = new Assets({ manifest: {}, fetchFn: fakeFetch({}, log) });
  assert.deepEqual(await A.loadStage('match', (d, t) => prog.push([d, t])), { ok: [], failed: [] });
  assert.deepEqual(log, []);
  assert.deepEqual(prog, [[0, 0]]);
});

test('la stessa tappa chiesta due volte si scarica una volta sola', async () => {
  const log = [];
  const A = new Assets({ manifest: { music: [{ id: 'm', file: 'm.mp3' }] }, fetchFn: fakeFetch({ 'assets/m.mp3': buf(2) }, log) });
  await Promise.all([A.loadStage('music'), A.loadStage('music')]);
  assert.equal(log.length, 1);
});

test('versione a file unico: usa i data URL incorporati al posto della rete', async () => {
  const log = [];
  const A = new Assets({ manifest: { match: [{ id: 'a', file: 'a.bin' }] }, inline: { 'a.bin': 'data:x' }, fetchFn: fakeFetch({ 'data:x': buf(4) }, log) });
  await A.loadStage('match');
  assert.deepEqual(log, ['data:x']);
  assert.equal(A.get('a').byteLength, 4);
});

test('una richiesta appesa scade e la tappa finisce lo stesso', async () => {
  const A = new Assets({ manifest: { match: [{ id: 'lento', file: 'lento.bin' }] }, timeoutMs: 30, fetchFn: () => new Promise(() => {}) });
  const r = await A.loadStage('match');
  assert.deepEqual(r.failed, ['lento']);
  assert.match(A.failed.get('lento'), /tempo scaduto/);
});

test('dopo un fallimento la tappa si può riprovare', async () => {
  let n = 0;
  const A = new Assets({ manifest: { match: [{ id: 'a', file: 'a.bin' }] }, fetchFn: async () => (++n === 1 ? { ok: false, status: 500 } : { ok: true, arrayBuffer: async () => buf(1) }) });
  assert.deepEqual((await A.loadStage('match')).failed, ['a']);
  assert.deepEqual((await A.loadStage('match')).ok, ['a']);
});
