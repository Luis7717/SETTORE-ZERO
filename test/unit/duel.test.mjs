import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Match, HL, effStats, headingOf, rng32, DUEL_R, DUEL_GUARD, DUEL_MAX, ZONE_DIST } from '../../src/sim.js';
import { genPlayer } from '../../src/career.js';
import { scene, wake, give, run, tapDribble } from '../lib/scene.mjs';
import { mkTeam } from '../lib/harness.mjs';

// portatore umano (squadra 0) fermo a centrocampo che guarda verso +y, difensore della squadra 1 davanti a `dist` m
function setup(seed, { dist = 3, dri = 60, dif = 60, ox = 0 } = {}) {
  const m = scene({ seed }), p = m.players[9], o = m.players[11 + 3];
  wake(p, 0, 0); p.fx = 0; p.fy = 1; p.st.dri = dri; give(m, p); m.updateCtrl(0);
  wake(o, ox, dist); o.st.dif = dif;
  return { m, p, o };
}
const hold = (m, p) => () => m.userMove(0, p.x, p.y, true); // dito fermo sul portatore: resta dov'è

test('duello: si apre con un avversario davanti entro DUEL_R (7 m), solo per la squadra umana', () => {
  // Arrange
  const { m, p, o } = setup(1, { dist: 6.5 });
  // Act
  const ev = run(m, 1 / 60, hold(m, p));
  // Assert
  const st = ev.find(e => e.type === 'duel_start');
  assert.ok(st && st.p === p && st.o === o);
  assert.equal(m.duelFor(0), true);
  assert.equal(m.duelFor(1), false);
  assert.equal(m.hint(0), 'attack', 'si può ancora disegnare il passaggio');
  assert.deepEqual(Object.keys(m.duel).sort(), ['bt', 'o', 'p', 'side', 't', 'team']);
});

test('duello: non si apre con l\'avversario alle spalle o lontano', () => {
  // Arrange / Act
  const a = setup(2, { dist: -3 }), b = setup(3, { dist: DUEL_R + 1.5 });
  run(a.m, 0.2, hold(a.m, a.p)); run(b.m, 0.05, hold(b.m, b.p));
  // Assert
  assert.equal(a.m.duelFor(0), false, 'alle spalle');
  assert.equal(b.m.duelFor(0), false, 'lontano');
});

test('duello: si chiude per tempo, per lontananza e col passaggio', () => {
  // tempo: difensore fermo (stordito) davanti, portatore fermo
  {
    const { m, p, o } = setup(4, { dist: 3 });
    run(m, 1 / 60, hold(m, p)); o.stun = 999;
    const ev = run(m, DUEL_MAX + 0.1, hold(m, p));
    const end = ev.find(e => e.type === 'duel_end');
    assert.equal(end && end.reason, 'tempo');
    assert.equal(m.duelFor(0), false);
  }
  // lontano
  {
    const { m, p, o } = setup(5, { dist: 3 });
    run(m, 1 / 60, hold(m, p)); o.x = 20; o.y = 20; o.stun = 999;
    const end = run(m, 2 / 60, hold(m, p)).find(e => e.type === 'duel_end');
    assert.equal(end && end.reason, 'lontano');
  }
  // passaggio
  {
    const { m, p } = setup(6, { dist: 3 });
    run(m, 1 / 60, hold(m, p)); p.stun = 0;
    assert.equal(m.userKick(0, { type: 'ground', tx: -15, ty: -5 }), true);
    const end = run(m, 2 / 60).find(e => e.type === 'duel_end');
    assert.equal(end && end.reason, 'passaggio');
  }
});

test('duello: per i primi 0,6 s il difensore non ruba palla, dopo sì', () => {
  // Arrange: difensore fortissimo attaccato al portatore scarso
  const { m, p, o } = setup(7, { dist: 1.0, dri: 20, dif: 99 });
  // Act
  const early = run(m, DUEL_GUARD - 0.05, hold(m, p));
  const ownerAfterGuard = m.ball.owner;
  const late = run(m, 1.5, hold(m, p));
  // Assert
  assert.ok(early.some(e => e.type === 'duel_start'));
  assert.ok(!early.some(e => e.type === 'tackle'), 'nessun contrasto nella finestra di protezione');
  assert.equal(ownerAfterGuard, p);
  assert.ok(late.some(e => e.type === 'tackle' && e.p === o), 'dopo la finestra il difensore ruba palla');
  const end = late.find(e => e.type === 'duel_end');
  assert.equal(end && end.reason, 'palla persa');
});

test('dribbling: riuscito = portatore oltre il difensore, difensore sbilanciato, duello chiuso', () => {
  // Arrange: cerca un seme in cui riesce (85 contro 40: probabilità 0,85)
  for (let s = 0; s < 20; s++) {
    const { m, p, o } = setup(20 + s, { dist: 2.5, dri: 85, dif: 40 });
    run(m, 1 / 60, hold(m, p));
    // Act
    const ev = tapDribble(m);
    assert.ok(ev.some(e => e.type === 'dribble_book'), 'tasto Dribbling: dribbling prenotato');
    const d = ev.find(e => e.type === 'dribble');
    if (!d.ok) continue;
    run(m, 0.6);
    // Assert
    assert.ok(o.stun > 0, 'difensore ancora sbilanciato');
    assert.equal(m.ball.owner, p);
    assert.ok(p.y > o.y, `portatore oltre il difensore: ${p.y.toFixed(1)} contro ${o.y.toFixed(1)}`);
    assert.equal(ev.find(e => e.type === 'duel_end').reason, 'dribbling');
    assert.equal(m.userDribble(0), false, 'senza duello aperto non si dribbla');
    return;
  }
  assert.fail('nessun dribbling riuscito in 20 prove');
});

test('dribbling: la riuscita cresce col dribbling e cala con la difesa; se fallisce il difensore prende o devia', () => {
  const rate = (dri, dif) => {
    let ok = 0, lost = 0;
    for (let s = 0; s < 120; s++) {
      const { m, p } = setup(200 + s, { dist: 1.5, dri, dif });
      run(m, 1 / 60, hold(m, p));
      const d = tapDribble(m).find(e => e.type === 'dribble');
      if (d.ok) ok++; else if (m.ball.owner !== p) lost++;
    }
    return { ok: ok / 120, lost: lost / (120 - ok || 1) };
  };
  // Act
  const bravo = rate(85, 45), pari = rate(60, 60), scarso = rate(45, 85);
  // Assert
  assert.ok(bravo.ok > pari.ok + 0.15 && pari.ok > scarso.ok + 0.15, `riuscita ${bravo.ok} / ${pari.ok} / ${scarso.ok}`);
  assert.equal(scarso.lost, 1, 'ogni dribbling fallito fa perdere il pallone');
});

test('dribbling: anche l\'IA lo tenta nei suoi duelli', () => {
  let n = 0;
  for (let s = 0; s < 30; s++) {
    // Arrange: portatore del computer, avversario davanti verso la porta
    const m = scene({ seed: 300 + s, human: [false, false] }), p = m.players[9], o = m.players[11 + 3];
    wake(p, 0, 10); p.fx = 0; p.fy = 1; give(m, p); p.aiT = 0; wake(o, 0, 12.5);
    for (const q of m.team(0)) if (q !== p) q.off = true; // nessun compagno a cui passare
    // Act
    if (run(m, 0.5).some(e => e.type === 'dribble' && e.p === p)) n++;
  }
  // Assert
  assert.ok(n >= 3, `dribbling tentati dall'IA: ${n}/30`);
});

test('calo per uso: ogni dribbling riuscito -3% fino all\'80%, ogni colpo di testa vinto -2% fino all\'85%', () => {
  // Arrange
  const m = scene({ seed: 9 }), p = m.players[9], dri0 = p.st.dri, tes0 = p.st.tes;
  // Act
  m.wearDown(p, 'dri', 0.03, 0.8);
  // Assert
  assert.ok(Math.abs(p.wear.dri - 0.97) < 1e-9 && Math.abs(p.st.dri - dri0 * 0.97) < 1e-9);
  for (let k = 0; k < 20; k++) { m.wearDown(p, 'dri', 0.03, 0.8); m.wearDown(p, 'tes', 0.02, 0.85); }
  assert.ok(Math.abs(p.wear.dri - 0.8) < 1e-9 && Math.abs(p.st.dri - dri0 * 0.8) < 1e-9, 'minimo 80%');
  assert.ok(Math.abs(p.wear.tes - 0.85) < 1e-9 && Math.abs(p.st.tes - tes0 * 0.85) < 1e-9, 'minimo 85%');
  // sostituzione: il nuovo entrato è fresco
  m.substitute(0, 9, p.src);
  assert.deepEqual(p.wear, { dri: 1, tes: 1 });
  assert.equal(p.st.dri, dri0);
});

test('calo per uso: il dribbling riuscito lo applica, la partita nuova riparte da pieno', () => {
  // Arrange / Act
  let p = null;
  for (let s = 0; s < 20 && !p; s++) {
    const st = setup(40 + s, { dist: 2.5, dri: 85, dif: 40 });
    run(st.m, 1 / 60, hold(st.m, st.p));
    if (tapDribble(st.m).find(e => e.type === 'dribble').ok) p = st.p;
  }
  // Assert
  assert.ok(p && Math.abs(p.wear.dri - 0.97) < 1e-9 && Math.abs(p.st.dri - 85 * 0.97) < 1e-9);
  const again = new Match({ seed: 1, teams: [mkTeam('A', 60, 8), mkTeam('B', 60, 18)] });
  for (const q of again.players) assert.deepEqual(q.wear, { dri: 1, tes: 1 });
});

test('colpo di testa: usa la statistica tes e la consuma un pochino', () => {
  // Arrange: cross alto sull'attaccante in area (come in air.test.mjs)
  const m = scene({ seed: 41, human: [false, false] }), p = m.players[9];
  wake(p, 1, HL - 9); wake(m.gk(1), 0, HL - 0.6);
  const b = m.ball; b.x = p.x - 0.5; b.y = p.y; b.h = 1.9; b.vx = 9; b.vy = 0; b.vh = -1; b.ct = 0;
  b.kick = { team: 0, kicker: m.players[5], off: [], age: 1, type: 'loft', human: false };
  const tes0 = p.st.tes;
  // Act
  m.contacts(1 / 60);
  // Assert
  assert.equal(m.events.find(e => e.type === 'kick').kind, 'header');
  assert.ok(Math.abs(p.st.tes - tes0 * 0.98) < 1e-9 && Math.abs(p.wear.tes - 0.98) < 1e-9);
});

test('contrasto aereo: vince più spesso chi ha più colpi di testa', () => {
  const rate = (tA, tD) => {
    let a = 0, n = 0;
    for (let s = 0; s < 100; s++) {
      // attaccante della squadra 0 e difensore della squadra 1 alla stessa distanza dal pallone alto
      const m = scene({ seed: 500 + s, human: [false, false] }), p = m.players[9], d = m.players[11 + 2];
      wake(p, 0.5, HL - 9); wake(d, -0.5, HL - 9); p.st.tes = tA; d.st.tes = tD;
      const b = m.ball; b.x = 0; b.y = HL - 9; b.h = 2.0; b.vx = 0; b.vy = 6; b.vh = -1; b.ct = 0;
      b.kick = { team: 0, kicker: m.players[5], off: [], age: 1, type: 'loft', human: false };
      m.contacts(1 / 60);
      const e = m.events.find(x => x.type === 'aerial');
      if (e) { n++; if (e.p === p) a++; }
    }
    return a / n;
  };
  // Act
  const alto = rate(85, 45), basso = rate(45, 85);
  // Assert
  assert.ok(alto > 0.7 && basso < 0.3, `attaccante vince ${alto} (tes alto) / ${basso} (tes basso)`);
});

test('tes: i giocatori dei salvataggi vecchi lo ricavano senza scriverlo, quelli nuovi lo hanno', () => {
  // Arrange: giocatore di un vecchio salvataggio (senza tes)
  const old = { id: 3, name: 'L. Rossi', pos: 'D', age: 25, vel: 60, tir: 40, pas: 55, dri: 50, dif: 70, fis: 72, por: 12, goals: 0, assists: 0, apps: 3, pot: 66 };
  const copy = JSON.stringify(old);
  // Act
  const st = effStats(old, 'D');
  // Assert
  assert.ok(st.tes >= 18 && st.tes <= 99 && Number.isFinite(st.tes));
  assert.equal(JSON.stringify(old), copy, 'il salvataggio non cambia');
  assert.equal(effStats(old, 'D').tes, st.tes, 'sempre lo stesso valore');
  assert.ok(headingOf(old) > headingOf({ ...old, pos: 'P' }), 'il ruolo conta');
  // giocatore nuovo
  const r = rng32(7), n = genPlayer(r, 'A', 65, 1, false);
  assert.equal(typeof n.tes, 'number');
  assert.equal(n.tes, headingOf({ ...n, tes: undefined }));
  assert.equal(effStats({ ...n, tes: 90 }, 'A').tes, 90);
  // una partita con giocatori senza tes gira e ha tes in ogni giocatore
  const m = new Match({ seed: 3, teams: [mkTeam('A', 60, 8), mkTeam('B', 60, 18)] });
  for (const p of m.players) assert.ok(Number.isFinite(p.st.tes));
  for (let i = 0; i < 600; i++) m.step(1 / 60);
});

test('stanchezza: correndo la velocità massima cala, più piano con più resistenza (fis)', () => {
  // Arrange: due giocatori identici tranne il fisico, fatti correre a lungo
  const m = scene({ seed: 11, human: [false, false] }), a = m.players[5], c = m.players[6];
  wake(a, -10, 0); wake(c, 10, 0); a.st.fis = 90; c.st.fis = 30; a.st.vel = c.st.vel = 70;
  const v0 = m.vmax(a);
  // Act: 200 s di corsa avanti e indietro
  for (let i = 0; i < 200 * 60; i++) {
    const k = Math.floor(i / 300) % 2 ? -1 : 1;
    for (const p of [a, c]) { p.tx = p.x; p.ty = k * 40; }
    m.movePlayers(1 / 60);
  }
  // Assert
  assert.ok(a.energy < 1 && c.energy < a.energy, `energia: fis 90 ${a.energy.toFixed(2)}, fis 30 ${c.energy.toFixed(2)}`);
  assert.ok(m.vmax(c) < m.vmax(a) && m.vmax(a) < v0);
});

test('area di tiro: negli ultimi 20 m il portatore umano può passare, prima no', () => {
  // Arrange
  const { m, p } = setup(30, { dist: -5 });
  // Act / Assert
  p.y = HL - ZONE_DIST - 2; assert.equal(m.inZone(0), false, 'a 22 m dalla porta');
  assert.equal(m.passFor(0), false);
  p.y = HL - ZONE_DIST + 1; assert.equal(m.inZone(0), true, 'a 19 m dalla porta');
  assert.equal(m.passFor(0), true);
  assert.equal(m.inZone(1), false, 'non per la squadra avversaria');
  m.human[0] = false; assert.equal(m.inZone(0), false, 'solo per la squadra umana');
});

test('area di tiro: vale solo per la porta avversaria e col pallone tra i piedi', () => {
  const { m, p } = setup(31, { dist: -5 });
  p.y = -HL + 5; assert.equal(m.inZone(0), false, 'vicino alla propria porta');
  p.y = HL - 5; m.ball.owner = null; assert.equal(m.inZone(0), false, 'pallone libero');
});
