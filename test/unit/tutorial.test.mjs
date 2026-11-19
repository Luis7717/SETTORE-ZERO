import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Match } from '../../src/sim.js';
import { Tutorial, STEPS } from '../../src/tutorial.js';
import { mkTeam } from '../lib/harness.mjs';

const DT = 1 / 60;
const newMatch = () => new Match({ seed: 5, halfLen: 99999, human: [true, false], teams: [mkTeam('A', 60, 1), mkTeam('B', 40, 2)] });
// un fotogramma come in main.js: blocca, muove, controlla gli eventi, poi li consuma
const frame = (m, t) => { t.before(); m.step(DT); t.after(DT); m.events.length = 0; };
const run = (m, t, sec, each) => { for (let k = 0; k < sec * 60 && !t.finished; k++) { if (each) each(m, t); frame(m, t); } };

test('allenamento guidato: le cinque prove si superano coi comandi del telefono', () => {
  // Arrange
  const m = newMatch(), texts = [];
  const t = new Tutorial(m, (title, text, i) => texts.push([title, text, i]));
  assert.equal(t.i, 0);
  // 1) passaggio al compagno libero
  m.userKick(0, { type: 'auto', tx: m.players[9].x, ty: m.players[9].y, curve: 0 });
  run(m, t, 5);
  assert.ok(t.i >= 1, 'dopo il passaggio si passa al tiro');
  // 2) tiro in porta
  m.userKick(0, { type: 'shot', tx: 2, ty: 50, th: 1, curve: 0 });
  run(m, t, 3);
  assert.ok(t.i >= 2, 'dopo il tiro si passa alla corsa');
  // 3) corsa tenendo premuto più avanti
  run(m, t, 5, (mm) => { if (t.i === 2 && !t.done) mm.userMove(0, 0, 20, true); });
  assert.ok(t.i >= 3, 'dopo la corsa si passa al recupero palla');
  // 4) recupero palla: andare addosso al portatore avversario
  run(m, t, 12, (mm) => { if (t.i === 3 && !t.done && mm.ball.owner) mm.userMove(0, mm.ball.x, mm.ball.y, true); });
  assert.ok(t.i >= 4, 'dopo il recupero si passa alla parata');
  // 5) parata: tuffo verso il tiro appena l'avversario tira
  run(m, t, 20, (mm) => { if (mm.diveWin(0)) { const s = mm.ball.shot, g = mm.gk(0); mm.userDive(0, s.cx - g.x, s.ch); } });
  // Assert
  assert.equal(t.finished, true, 'allenamento concluso');
  assert.equal(texts.filter(x => x[1] === 'Bravo!').length, STEPS.length);
});

test('se la prova non riesce entro il tempo si rimette tutto a posto', () => {
  const m = newMatch(), shown = [];
  const t = new Tutorial(m, (title, text, i) => shown.push(i));
  run(m, t, 18); // nessun comando
  assert.equal(t.i, 0);
  assert.ok(shown.length >= 2, 'la prova è stata riproposta');
  assert.equal(m.ball.owner, m.players[7]);
});
