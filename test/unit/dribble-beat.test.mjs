// Dribbling riuscito: il difensore saltato non contrasta e non si attacca al portatore durante il giochetto,
// e la lezione "Dribbling" dell'allenamento si supera con facilità (segnalazione di Luis del 2026-11-20:
// "il giocatore si appiccica al portatore di palla e non permette di dribblare").
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Match, DUEL_R } from '../../src/sim.js';
import { DRIB_BEAT_SPD } from '../../src/sim/duel.js';
import { Tutorial, REPS } from '../../src/tutorial.js';
import { scene, wake, give, run } from '../lib/scene.mjs';
import { mkTeam } from '../lib/harness.mjs';

const DT = 1 / 60;
const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);

// portatore umano (squadra 0) che corre verso +y senza dito (va avanti da solo), difensore davanti a `d` m
function duelScene(seed, d) {
  const m = scene({ seed }), p = m.players[9], o = m.players[11 + 3];
  wake(p, 0, 0); p.fx = 0; p.fy = 1; p.st.dri = 85; give(m, p); m.updateCtrl(0);
  wake(o, 0, d); o.fx = 0; o.fy = -1; o.st.dif = 40;
  return { m, p, o };
}
// cerca un seme in cui il dribbling (toccato appena si apre il duello) riesce
function dribbledAt(d) {
  for (let s = 0; s < 30; s++) {
    const st = duelScene(500 + s, d);
    run(st.m, DT);
    if (!st.m.duelFor(0)) continue;
    assert.equal(st.m.userDribble(0), true);
    const e = st.m.events.find(x => x.type === 'dribble'); st.m.events.length = 0;
    if (e && e.ok) return st;
  }
  assert.fail('nessun dribbling riuscito in 30 prove');
}

test('dribbling toccato appena si apre il duello (difensore a ~7 m): il portatore lo supera e il difensore non gli si attacca', () => {
  // Arrange: il duello si apre a DUEL_R, il tasto si tocca subito
  const { m, p, o } = dribbledAt(DUEL_R - 0.3);
  // Act: 3 s di partita, il portatore va avanti da solo
  let minAfterPast = 99, past = false, d2 = 0, t = 0;
  const ev = run(m, 3, () => {
    if (p.y > o.y + 0.5) past = true;
    if (past) minAfterPast = Math.min(minAfterPast, dist(o, p));
    if ((t += DT) <= 2) d2 = dist(o, p);
  });
  // Assert
  assert.equal(ev.filter(e => e.type === 'tackle' && e.p === o).length, 0, 'il difensore saltato non contrasta');
  assert.equal(ev.filter(e => e.type === 'duel_start' && e.o === o).length, 0, 'non si riapre il duello con lo stesso difensore');
  assert.equal(m.ball.owner, p, 'il portatore ha ancora il pallone');
  assert.ok(past, `portatore oltre il difensore: ${p.y.toFixed(1)} contro ${o.y.toFixed(1)}`);
  assert.ok(minAfterPast > 1.2, `superato, il difensore resta staccato: minimo ${minAfterPast.toFixed(2)} m`);
  assert.ok(d2 > 3.5, `vantaggio vero dopo 2 s: ${d2.toFixed(1)} m`);
});

test('difensore saltato ancora sbilanciato: anche addosso al pallone non contrasta chi l\'ha saltato, e corre piano', () => {
  // Arrange: dribbling riuscito da vicino, poi lo sbilanciamento (fermo) finisce e il difensore è sul pallone
  const { m, p, o } = dribbledAt(2.5);
  o.stun = 0; o.tackleCd = 0; p.protect = 0;
  assert.ok(o.beat > 0.3, 'resta "saltato" dopo lo sbilanciamento');
  o.x = m.ball.x; o.y = m.ball.y + 0.3;
  // Act
  let vmax = 0;
  const ev = run(m, 0.3, () => { p.vx = p.vy = 0; p.tx = p.x; p.ty = p.y; vmax = Math.max(vmax, Math.hypot(o.vx, o.vy)); });
  // Assert
  assert.equal(ev.filter(e => e.type === 'tackle').length, 0, 'nessun contrasto');
  assert.equal(m.ball.owner, p);
  assert.ok(vmax <= m.vmax(o) * DRIB_BEAT_SPD + 0.05, `velocità ${vmax.toFixed(2)} contro massimo ${(m.vmax(o) * DRIB_BEAT_SPD).toFixed(2)}`);
});

test('difensore saltato: finito il tempo torna normale e può contrastare di nuovo', () => {
  // Arrange
  const { m, p, o } = dribbledAt(2.5);
  o.stun = 0; o.beat = 0; o.tackleCd = 0; p.protect = 0;
  o.x = m.ball.x; o.y = m.ball.y + 0.3;
  // Act
  const ev = run(m, 1.5, () => { p.vx = p.vy = 0; p.tx = p.x; p.ty = p.y; o.tx = m.ball.x; o.ty = m.ball.y; });
  // Assert
  assert.ok(ev.some(e => e.type === 'tackle' && e.p === o), 'il contrasto torna possibile');
});

// ---------------------------------------------------------------- lezione Dribbling, come sul telefono
const newTut = (seed) => {
  const m = new Match({ seed, halfLen: 99999, human: [true, false], teams: [mkTeam('A', 55, seed), mkTeam('B', 40, seed + 1)] });
  const t = new Tutorial(m, { text() {}, card() {} });
  while (t.lesson.title !== 'Dribbling') t.nextLesson();
  t.go();
  return { m, t };
};
// un fotogramma vero (1/60 s) col rallenty del duello come in main.js (G.ts verso 0,08)
function frame(m, t, g) {
  const target = m.duelFor(0) ? 0.08 : 1;
  g.ts += (target - g.ts) * Math.min(1, DT * 14);
  const sdt = DT * g.ts;
  t.before(); m.step(sdt); t.after(sdt); m.events.length = 0;
}

test('lezione Dribbling: dopo un tentativo fallito il tasto della prova nuova funziona subito', () => {
  // Arrange: come dopo un dribbling fallito, attese ancora in corso quando la prova riparte
  const { m, t } = newTut(3);
  const c0 = t.st.c;
  c0.dribCd = 1.2; m.duelCd[0] = 1; m.duelCdP[0] = c0;
  t.reset();
  // Act: il duello si apre al primo passo (difensore a 7 m)
  const g = { ts: 1 }; frame(m, t, g);
  // Assert
  assert.equal(m.duelFor(0), true, 'duello aperto subito');
  assert.equal(m.userDribble(0), true, 'il tasto Dribbling funziona');
});

test('lezione Dribbling: si supera con facilità toccando il tasto dopo un attimo, e il difensore saltato non si attacca', () => {
  const SEEDS = 8;
  let attempts = 0, sticky = 0, passed = 0;
  for (let seed = 1; seed <= SEEDS; seed++) {
    // Arrange
    const { m, t } = newTut(seed * 31), g = { ts: 1 }, L = t.lesson;
    let since = 0, tapC = null, tapO = null;
    // Act: tocco del tasto 1 s vero dopo l'apertura del duello, finché le 3 prove non sono superate
    for (let f = 0; f < 60 * 120 && t.lesson === L; f++) {
      if (m.duelFor(0)) {
        since += DT;
        if (since >= 1 && !tapC && m.userDribble(0)) { attempts++; tapC = t.st.c; tapO = t.st.o; }
      } else since = 0;
      frame(m, t, g);
      // durante il "Bravo!" (giochetto in corso) il difensore saltato, ormai superato, non deve stare addosso al portatore
      if (t.done && tapC && tapC.y > tapO.y + 0.5 && dist(tapC, tapO) < 1.2) sticky++;
      if (!t.done && !m.duelFor(0)) tapC = tapO = null;
    }
    if (t.lesson !== L) passed++;
  }
  // Assert
  assert.equal(passed, SEEDS, 'lezione superata in tutte le partite');
  assert.ok(attempts <= SEEDS * REPS * 1.5, `tentativi ${attempts} per ${SEEDS * REPS} prove superate`);
  assert.equal(sticky, 0, 'fotogrammi col difensore saltato attaccato al portatore');
});
