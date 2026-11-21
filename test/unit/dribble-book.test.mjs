// Dribbling prenotato (Luis 2026-11-21: "il dribbling lo deve fare vicino all'avversario e in base alla posizione sceglie
// un dribbling e va in quella direzione per non andare addosso"): il tasto prenota, il portatore corre verso il difensore
// dal lato scelto e il dribbling vero (esito, evento 'dribble', giochetto) parte solo quando gli arriva vicino.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { HW, DUEL_R } from '../../src/sim.js';
import { DRIB_NEAR, DRIB_BOOK_MAX } from '../../src/sim/duel.js';
import { scene, wake, give, run } from '../lib/scene.mjs';

const DT = 1 / 60;
const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);

// portatore umano (squadra 0) in (px, 0) che guarda verso +y, difensore della squadra 1 davanti a `d` m (spostato di ox)
function setup(seed, { d = 6.5, px = 0, ox = 0, dri = 85, dif = 40 } = {}) {
  const m = scene({ seed }), p = m.players[9], o = m.players[11 + 3];
  wake(p, px, 0); p.fx = 0; p.fy = 1; p.st.dri = dri; give(m, p); m.updateCtrl(0);
  wake(o, px + ox, d); o.fx = 0; o.fy = -1; o.st.dif = dif;
  m.userMove(0, p.x, p.y, true); m.step(DT); m.events.length = 0; // un passo col dito fermo: si apre il duello
  return { m, p, o };
}
// passi finché parte il dribbling (al massimo 2 s): distanza e tempo al momento dell'evento
function untilDribble(m, p, o) {
  let t = 0, at = null, minD = 99, ev = null;
  for (let i = 0; i < 120 && !ev; i++) {
    const d0 = dist(p, o);
    m.step(DT); t += DT;
    ev = m.events.find(e => e.type === 'dribble') || null;
    if (ev) at = d0;
    minD = Math.min(minD, dist(p, o));
    m.events.length = 0;
  }
  return { ev, t, at, minD };
}

test('tasto Dribbling col difensore lontano: prenota, il portatore va verso di lui e il dribbling parte solo vicino', () => {
  // Arrange
  const { m, p, o } = setup(1, { d: DUEL_R - 0.5 });
  assert.equal(m.duelFor(0), true, 'duello aperto');
  // Act
  assert.equal(m.userDribble(0), true, 'tasto toccato');
  const now = m.events.splice(0);
  // Assert: subito niente esito, solo la prenotazione (col lato)
  assert.equal(now.filter(e => e.type === 'dribble').length, 0, 'nessun dribbling subito');
  const bk = now.find(e => e.type === 'dribble_book');
  assert.ok(bk && bk.p === p && bk.o === o && Math.abs(bk.side) === 1, 'evento dribble_book con il lato');
  assert.equal(m.dribBooked(0), true, 'prenotazione in corso: il tasto sparisce');
  assert.equal(m.userDribble(0), false, 'un secondo tocco non fa nulla');
  const { ev, at, t } = untilDribble(m, p, o);
  assert.ok(ev, 'il dribbling parte');
  assert.ok(at <= DRIB_NEAR + 0.4, `parte vicino al difensore: ${at.toFixed(2)} m`);
  assert.ok(t < DRIB_BOOK_MAX + 0.05, `prima del tempo massimo: ${t.toFixed(2)} s`);
  assert.equal(ev.side, bk.side, 'stesso lato della prenotazione (va alla grafica)');
  assert.equal(m.duelFor(0), false, 'il dribbling chiude il duello');
});

test('dribbling prenotato: già vicino al difensore parte subito al tocco', () => {
  // Arrange
  const { m } = setup(2, { d: DRIB_NEAR - 0.3 });
  // Act
  m.userDribble(0);
  // Assert
  assert.ok(m.events.some(e => e.type === 'dribble'), 'dribbling subito');
});

test('dribbling prenotato: se il difensore scappa all\'indietro parte comunque dopo DRIB_BOOK_MAX', () => {
  // Arrange: il difensore resta sempre 5 m davanti al portatore
  const { m, p, o } = setup(3, { d: 5 });
  m.userDribble(0); m.events.length = 0;
  // Act
  let t = 0, ev = null;
  for (let i = 0; i < 120 && !ev; i++) {
    o.x = p.x; o.y = p.y + 5; o.vx = 0; o.vy = 0;
    m.step(DT); t += DT;
    ev = m.events.find(e => e.type === 'dribble'); m.events.length = 0;
  }
  // Assert
  assert.ok(ev, 'il dribbling parte');
  assert.ok(Math.abs(t - DRIB_BOOK_MAX) < 0.05, `dopo il tempo massimo: ${t.toFixed(2)} s`);
});

test('dribbling prenotato: si annulla se il duello finisce prima (palla persa, difensore lontano, passaggio)', () => {
  // palla persa
  {
    const { m, p, o } = setup(4, { d: 6 });
    m.userDribble(0);
    m.ball.owner = o; m.ball.last = o;
    const ev = run(m, 1.5);
    assert.equal(ev.filter(e => e.type === 'dribble').length, 0, 'palla persa: niente dribbling');
    assert.equal(ev.find(e => e.type === 'duel_end').reason, 'palla persa');
    assert.equal(m.dribBooked(0), false);
    void p;
  }
  // difensore che sparisce lontano
  {
    const { m, o } = setup(5, { d: 6 });
    m.userDribble(0);
    o.x = 25; o.y = 40; o.stun = 999;
    const ev = run(m, 1.5);
    assert.equal(ev.filter(e => e.type === 'dribble').length, 0, 'difensore lontano: niente dribbling');
    assert.equal(ev.find(e => e.type === 'duel_end').reason, 'lontano');
  }
  // passaggio disegnato durante la corsa
  {
    const { m, p } = setup(6, { d: 6 });
    m.userDribble(0); p.stun = 0;
    assert.equal(m.userKick(0, { type: 'ground', tx: -15, ty: -5 }), true);
    const ev = run(m, 1.5);
    assert.equal(ev.filter(e => e.type === 'dribble').length, 0, 'passaggio: niente dribbling');
    assert.equal(ev.find(e => e.type === 'duel_end').reason, 'passaggio');
  }
});

test('lato del dribbling: opposto allo sbilanciamento del difensore', () => {
  // Arrange / Act: difensore spostato a sinistra (x < 0, il portatore guarda +y) o a destra della linea di corsa
  const left = setup(7, { d: 5, ox: -0.8 }), right = setup(8, { d: 5, ox: 0.8 });
  left.m.userDribble(0); right.m.userDribble(0);
  // Assert: +1 = sinistra del portatore (x più piccole), -1 = destra
  assert.equal(left.m.duel.side, -1, 'difensore a sinistra: si passa a destra');
  assert.equal(right.m.duel.side, 1, 'difensore a destra: si passa a sinistra');
});

test('lato del dribbling: vicino alla linea laterale sempre verso il centro', () => {
  // Arrange: difensore spostato verso il centro (lo sbilanciamento direbbe "verso fuori")
  const nearR = setup(9, { d: 5, px: HW - 3, ox: -0.6 }), nearL = setup(10, { d: 5, px: -(HW - 3), ox: 0.6 });
  // Act
  nearR.m.userDribble(0); nearL.m.userDribble(0);
  // Assert: a destra (x > 0) il centro è a sinistra (+1), e viceversa
  assert.equal(nearR.m.duel.side, 1, 'vicino alla linea di destra: verso il centro');
  assert.equal(nearL.m.duel.side, -1, 'vicino alla linea di sinistra: verso il centro');
});

test('lato del dribbling: verso lo spazio libero da altri avversari', () => {
  // Arrange: difensore dritto davanti, un secondo avversario oltre di lui sulla sinistra
  const { m, p } = setup(11, { d: 5 });
  const q = m.players[11 + 5]; wake(q, -2.5, p.y + 8);
  // Act
  m.userDribble(0);
  // Assert
  assert.equal(m.duel.side, -1, 'si passa a destra, dove non c\'è nessuno');
});

test('dribbling riuscito: il portatore passa dal lato scelto senza attraversare il difensore', () => {
  let done = 0;
  for (let s = 0; s < 40 && done < 6; s++) {
    // Arrange: difensore un po' di lato, a destra o a sinistra
    const ox = s % 2 ? 0.7 : -0.7, { m, p, o } = setup(100 + s, { d: 6, ox });
    m.userDribble(0);
    const side = m.duel.side;
    // Act
    const { ev } = untilDribble(m, p, o);
    if (!ev || !ev.ok) continue;
    let minD = dist(p, o), crossed = false;
    run(m, 1.2, () => {
      minD = Math.min(minD, dist(p, o));
      // quando il portatore è all'altezza del difensore deve stare dal lato scelto (+1 = x minori)
      if (Math.abs(p.y - o.y) < 0.3 && (p.x - o.x) * -side < 0.3) crossed = true;
    });
    // Assert
    assert.ok(minD > 0.9, `seme ${100 + s}: mai addosso al difensore (minimo ${minD.toFixed(2)} m)`);
    assert.equal(crossed, false, `seme ${100 + s}: passa dal lato scelto`);
    assert.ok(p.y > o.y, 'portatore oltre il difensore');
    done++;
  }
  assert.ok(done >= 4, `dribbling riusciti controllati: ${done}`);
});

test('IA: il dribbling resta immediato (a 3,2 m, senza prenotazione) e porta il lato nell\'evento', () => {
  let n = 0;
  for (let s = 0; s < 30; s++) {
    // Arrange: portatore del computer, avversario davanti (come in duel.test.mjs)
    const m = scene({ seed: 300 + s, human: [false, false] }), p = m.players[9], o = m.players[11 + 3];
    wake(p, 0, 10); p.fx = 0; p.fy = 1; give(m, p); p.aiT = 0; wake(o, 0, 12.5);
    for (const q of m.team(0)) if (q !== p) q.off = true;
    // Act
    const ev = run(m, 0.5);
    // Assert
    assert.equal(ev.filter(e => e.type === 'dribble_book').length, 0, 'l\'IA non prenota');
    const d = ev.find(e => e.type === 'dribble' && e.p === p);
    if (d) { assert.equal(Math.abs(d.side), 1); n++; }
  }
  assert.ok(n >= 3, `dribbling tentati dall'IA: ${n}/30`);
});
