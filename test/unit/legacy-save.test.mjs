import { test } from 'node:test';
import assert from 'node:assert/strict';
import { migrateLegacySave, runLegacyMigration, SAVE_KEY } from '../../src/legacy-save.js';

const mem = (init = {}) => { const m = new Map(Object.entries(init)); return { getItem: k => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)), m }; };
const SAVE = JSON.stringify({ club: 'FC Prova', div: 2, money: 1500, settings: { half: 90 } });

test('copia il vecchio salvataggio nella nuova origine vuota', () => {
  const st = mem();
  assert.equal(migrateLegacySave(st, SAVE), 'migrated');
  assert.equal(st.getItem(SAVE_KEY), SAVE);
});

test('non sovrascrive mai un salvataggio già presente nella nuova origine', () => {
  const st = mem({ [SAVE_KEY]: '{"club":"Nuovo"}' });
  assert.equal(migrateLegacySave(st, SAVE), 'kept');
  assert.equal(st.getItem(SAVE_KEY), '{"club":"Nuovo"}');
});

test('nessun vecchio salvataggio: non scrive nulla', () => {
  for (const legacy of [undefined, null, '']) {
    const st = mem();
    assert.equal(migrateLegacySave(st, legacy), 'none');
    assert.equal(st.m.size, 0);
  }
});

test('vecchio salvataggio rovinato: ignorato senza scrivere', () => {
  for (const legacy of ['{rotto', '42', '"testo"', 'null']) {
    const st = mem();
    assert.equal(migrateLegacySave(st, legacy), 'invalid', legacy);
    assert.equal(st.m.size, 0);
  }
});

test('localStorage che lancia errori: esito error, si riproverà', () => {
  const st = { getItem: () => null, setItem: () => { throw new Error('QuotaExceeded'); } };
  assert.equal(migrateLegacySave(st, SAVE), 'error');
  const st2 = { getItem: () => { throw new Error('SecurityError'); }, setItem: () => {} };
  assert.equal(migrateLegacySave(st2, SAVE), 'error');
});

test('in pagina avvisa l\'app iOS con l\'esito, e senza app non fa nulla', () => {
  const msgs = [];
  const win = { __legacySave: SAVE, localStorage: mem(), webkit: { messageHandlers: { legacy: { postMessage: m => msgs.push(m) } } } };
  assert.equal(runLegacyMigration(win), 'migrated');
  assert.deepEqual(msgs, [{ result: 'migrated' }]);
  assert.equal(win.localStorage.getItem(SAVE_KEY), SAVE);
  assert.equal(runLegacyMigration({ localStorage: mem() }), null);
});
