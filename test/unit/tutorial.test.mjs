import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Match } from '../../src/sim.js';
import { Tutorial, LESSONS, REPS } from '../../src/tutorial.js';
import { mkTeam } from '../lib/harness.mjs';

const DT = 1 / 60;
const newMatch = () => new Match({ seed: 5, halfLen: 99999, human: [true, false], teams: [mkTeam('A', 60, 1), mkTeam('B', 40, 2)] });
const recorder = () => { const r = { texts: [], cards: [] }; r.ui = { text: (...a) => r.texts.push(a), card: (L) => r.cards.push(L ? L.title : null) }; return r; };
// un fotogramma come in main.js: blocca, muove, controlla gli eventi, poi li consuma
const frame = (m, t) => { t.before(); m.step(DT); t.after(DT); m.events.length = 0; };

// comandi "da telefono" che superano ogni lezione
const DRIVE = {
  // il passaggio si fa solo nel duello (come in input.js)
  Passaggio(m) { const c = m.ctrl[0], q = m.players[9]; if (m.ball.owner === c && c && m.duelFor(0)) m.userKick(0, { type: 'auto', tx: q.x, ty: q.y, curve: 0 }); },
  Tiro(m) { const c = m.ctrl[0]; if (c && m.ball.owner === c) m.userKick(0, { type: 'shot', tx: 2, ty: 50, th: 1, curve: 0 }); },
  // strada disegnata dal giocatore (una volta per prova)
  'Corsa e scatto'(m, t) {
    const c = m.ctrl[0]; if (!c || m.move[0] || m.ball.owner !== c) return;
    const pts = []; for (let i = 1; i <= 16; i++) pts.push(t.k === 1 ? { x: c.x + i, y: c.y + i * 0.3 } : { x: c.x, y: c.y + i * (t.k === 2 ? 1.5 : 1) });
    m.userPath(0, pts);
  },
  // linea disegnata dal proprio giocatore fino al portatore avversario
  'Recupera palla'(m) { const c = m.ctrl[0], b = m.ball; if (c && b.owner && b.owner.team === 1 && !m.runOf(c)) m.userRun(0, c, [{ x: (c.x + b.x) / 2, y: (c.y + b.y) / 2 }, { x: b.x, y: b.y }]); },
  Dribbling(m) { if (m.duelFor && m.duelFor(0)) m.userDribble(0); else { const c = m.ctrl[0]; if (c) m.userMove(0, c.x, c.y + 4, true); } },
  Portiere(m) { if (m.diveWin(0)) { const s = m.ball.shot, g = m.gk(0); m.userDive(0, s.cx - g.x, s.ch); } },
};

test('allenamento: ogni meccanica ha una scheda e poi 3 prove superate coi comandi del telefono', () => {
  // Arrange
  const m = newMatch(), r = recorder(), t = new Tutorial(m, r.ui);
  const passed = {};
  // Act
  for (let guard = 0; guard < 60 * 60 * 8 && !t.finished; guard++) {
    if (t.card) { t.go(); continue; }
    const L = t.lesson, kBefore = t.k;
    if (!t.done && DRIVE[L.title]) DRIVE[L.title](m, t);
    frame(m, t);
    if (t.done && t.done > 1.25 && kBefore === t.k) passed[L.title] = (passed[L.title] || 0) + 1;
  }
  // Assert
  assert.equal(t.finished, true, 'allenamento concluso; lezioni superate: ' + JSON.stringify(passed));
  assert.deepEqual(r.cards.slice(0, -1), t.lessons.map(l => l.title), 'una scheda per lezione, in ordine');
  assert.equal(r.cards.at(-1), null, 'scheda finale di chiusura');
  assert.equal(r.texts.filter(x => x[1] === 'Bravo!').length, t.lessons.length * REPS, 'tre riuscite per lezione');
});

test('le tre prove di una lezione partono da situazioni diverse', () => {
  for (const L of LESSONS) {
    const pos = [];
    for (let k = 0; k < REPS; k++) {
      const m = newMatch(), r = recorder(), t = new Tutorial(m, r.ui);
      if (L.needs && typeof m[L.needs] !== 'function') continue;
      while (t.lesson !== t.lessons.find(l => l.title === L.title)) t.nextLesson();
      t.go(); t.k = k; t.reset();
      const who = m.ball.owner;
      pos.push(`${who.x.toFixed(0)},${who.y.toFixed(0)}`);
    }
    if (pos.length) assert.equal(new Set(pos).size, pos.length, `${L.title}: ${pos.join(' | ')}`);
  }
});

test('se la prova non riesce entro il tempo si rimette tutto a posto', () => {
  const m = newMatch(), r = recorder(), t = new Tutorial(m, r.ui);
  t.go();
  for (let k = 0; k < 18 * 60; k++) frame(m, t); // nessun comando
  assert.equal(t.li, 0); assert.equal(t.k, 0);
  assert.ok(r.texts.length >= 2, 'la prova è stata riproposta');
  assert.equal(m.ball.owner, m.players[7]);
});
