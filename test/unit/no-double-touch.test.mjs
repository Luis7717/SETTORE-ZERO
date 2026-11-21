// Niente doppio tocco sui calci da fermo (Luis 2026-11-21: "se faccio la rimessa laterale può anche farsela da solo"):
// chi batte rimessa, calcio d'angolo, punizione, rinvio, calcio d'inizio o rigore non può toccare il pallone una seconda
// volta finché non l'ha toccato un altro giocatore (compagno, avversario o portiere). Niente punizione indiretta:
// semplicemente non lo può toccare. Il rilancio del portiere dalle mani (restart 'gk') non conta.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { HW, HL, GW } from '../../src/sim.js';
import { scene, park, wake, run } from '../lib/scene.mjs';
import { playMatch } from '../lib/harness.mjs';

const DT = 1 / 60;
const POS = { throw: [HW, 5], corner: [HW, HL], freekick: [5, -10], goalkick: [5, -HL], kickoff: [0, 0], penalty: [0, 0] };

// calcio da fermo `type` della squadra umana 0; tutti gli altri giocatori parcheggiati (lontani e fermi), così nessun
// altro può toccare il pallone. Il battitore calcia corto verso (dx, dy) da sé e poi gli corre dietro col dito.
function setPiece(type, seed = 1) {
  const m = scene({ seed });
  m.setRestart(type, 0, ...POS[type]);
  const r = m.restart, p = r.taker;
  m.players.forEach((q, k) => { if (q !== p) park(q, k); });
  r.t = 1;
  return { m, p };
}
function shortKick(m, p, dx, dy) {
  const b = m.ball;
  assert.equal(m.userKick(0, { type: 'ground', tx: b.x + dx, ty: b.y + dy }), true, 'calcio battuto');
  assert.equal(m.phase, 'play');
  assert.equal(b.dbl, p, 'battitore segnato');
}
// il battitore insegue il pallone col dito per `sec` secondi (resta lui il controllato: in partita il controllo passerebbe
// al compagno che va sul pallone): ritorna se l'ha toccato
const steer = (m, p) => { const b = m.ball; m.ctrl[0] = p; m.switchCd[0] = 9; m.userMove(0, b.x, b.y, true); };
function chase(m, p, sec) {
  let touched = false;
  run(m, sec, () => { steer(m, p); if (m.ball.owner === p) touched = true; });
  return touched || m.ball.owner === p || m.ball.last !== p;
}

for (const type of ['throw', 'corner', 'freekick', 'goalkick', 'kickoff']) {
  test(`${type}: chi batte non riprende il pallone calciato corto finché non lo tocca un altro`, () => {
    // Arrange
    const { m, p } = setPiece(type, 3);
    const b = m.ball, toward = Math.sign(-b.x) || 1, fwd = type === 'corner' ? -1 : 1;
    // Act: calcio cortissimo (3 m) e inseguimento per 3 s
    shortKick(m, p, toward * 2, fwd * 2);
    const touched = chase(m, p, 3);
    // Assert
    assert.equal(touched, false, 'il battitore non tocca il pallone');
    assert.equal(b.owner, null, 'pallone ancora libero');
    assert.ok(Math.hypot(b.x - p.x, b.y - p.y) < 1.5, `il battitore è sul pallone (${Math.hypot(b.x - p.x, b.y - p.y).toFixed(2)} m) ma non lo prende`);
  });
}

test('calcio d\'angolo: dopo il tocco di un compagno il battitore può riprendere il pallone (uno-due)', () => {
  // Arrange: angolo corto verso un compagno a 6 m
  const { m, p } = setPiece('corner', 4), b = m.ball;
  const mate = m.players[7]; wake(mate, b.x - 6, b.y); mate.st.pas = 80; // sulla linea del battitore: al ritorno niente fuorigioco
  shortKick(m, p, mate.x - b.x, mate.y - b.y);
  // Act: il compagno lo controlla e lo ridà al battitore
  run(m, 3, () => {
    if (b.owner === mate && mate.stun <= 0) m.kick(mate, { type: 'ground', tx: p.x - 5, ty: p.y - 5 });
    else if (!b.owner && b.last === mate) steer(m, p);
  });
  // Assert
  assert.equal(b.owner, p, 'dopo il compagno il battitore riprende il pallone');
  assert.equal(b.dbl, null);
});

test('rimessa: anche il tocco di un avversario libera il battitore', () => {
  // Arrange
  const { m, p } = setPiece('throw', 5), b = m.ball;
  const opp = m.players[11 + 6]; wake(opp, b.x - 5, b.y); opp.st.dif = 99;
  shortKick(m, p, -5, 0);
  // Act: l'avversario lo prende (e lo perde subito, ricade vicino al battitore)
  run(m, 1.5, () => { if (b.owner === opp) { b.owner = null; b.vx = b.vy = 0; b.x = p.x - 0.5; b.y = p.y; opp.stun = 99; } });
  const touched = chase(m, p, 1);
  // Assert
  assert.equal(b.last === opp || touched, true);
  assert.equal(b.owner, p, 'dopo l\'avversario il battitore può prenderlo');
});

test('rigore: dopo il palo il rigorista non può ribattere, dopo la respinta del portiere sì', () => {
  for (const after of ['palo', 'parata']) {
    // Arrange: rigore battuto, poi il pallone torna davanti al rigorista
    const { m, p } = setPiece('penalty', 6), b = m.ball, gk = m.gk(1);
    wake(gk, 0, HL - 0.4);
    assert.equal(m.userKick(0, { type: 'shot', tx: GW / 2 - 0.5, ty: HL, th: 0.5 }), true);
    assert.equal(b.dbl, p);
    if (after === 'palo') {
      // pallone sul palo: rimbalza indietro (updateBall, ramo del palo)
      b.x = GW / 2; b.y = HL - 0.2; b.h = 1; b.vx = 0; b.vy = 18; b.vh = 0; b.shot = null;
      const ev = run(m, DT);
      assert.ok(ev.some(e => e.type === 'post'), 'palo');
    } else {
      m.save(gk, false); // respinta del portiere (non bloccata)
      gk.stun = 99;
    }
    b.x = p.x + 0.4; b.y = p.y + 0.4; b.h = 0; b.vx = b.vy = b.vh = 0; b.ct = 0; b.kick = null; b.shot = null; b.noT = 0;
    // Act
    const touched = chase(m, p, 1);
    // Assert
    if (after === 'palo') assert.equal(touched, false, 'dopo il palo il rigorista non ritocca');
    else assert.equal(b.owner, p, 'dopo la parata il rigorista può ribattere');
  }
});

test('pallone fermo vicino al battitore e nessun altro arriva: dopo DBL_FREE (6 s) il battitore può riprenderlo', () => {
  // Arrange
  const { m, p } = setPiece('throw', 7), b = m.ball;
  shortKick(m, p, -2, 0);
  // Act / Assert
  assert.equal(chase(m, p, 5), false, 'a 5 s ancora no');
  run(m, 1.5, () => steer(m, p));
  assert.equal(b.owner, p, 'dopo 6 s la partita non resta bloccata');
});

test('IA: dopo la rimessa il battitore non va sul pallone, ci va un compagno (la partita non si blocca)', () => {
  let ok = 0;
  for (let s = 0; s < 8; s++) {
    // Arrange: rimessa del computer, tutti in campo
    const m = scene({ seed: 40 + s, human: [false, false] });
    m.setRestart('throw', 0, HW, s * 3 - 10);
    const p = m.restart.taker, b = m.ball;
    // Act: la rimessa la batte l'IA; poi 4 s di gioco
    m.restart.t = 99; m.aiRestart();
    let first = null, t = 0;
    run(m, 4, () => {
      if ((t += DT) > 0.15 && m.chase[0] && b.dbl === p) assert.notEqual(m.chase[0].p, p, 'il battitore non è chi va sul pallone');
      if (!first && b.last !== p) first = b.last;
      if (!first) assert.notEqual(b.owner, p, 'il battitore non lo riprende per primo');
    });
    // Assert
    if (first) ok++;
  }
  assert.ok(ok >= 7, `pallone toccato da un altro dopo la rimessa: ${ok}/8`);
});

test('partite intere: dopo un calcio da fermo il primo a toccare il pallone non è mai il battitore', () => {
  let restarts = 0;
  for (const [seed, mode] of [[11, 'bot'], [12, 'ai'], [13, 'bot'], [14, 'ai']]) {
    // Arrange / Act
    let taker = null, watching = false;
    playMatch({
      seed, mode, halfLen: 150,
      onStep(m) {
        const b = m.ball;
        if (m.phase === 'restart' && m.restart.type !== 'gk') { taker = m.restart.taker; watching = false; return; }
        if (taker && m.phase === 'play' && !watching) { watching = true; restarts++; }
        if (!watching) return;
        // Assert: finché nessun altro l'ha toccato, il battitore non lo ha
        if (b.last !== taker) { watching = false; taker = null; return; }
        assert.notEqual(b.owner, taker, `seme ${seed}: il battitore ha ripreso il pallone senza tocchi di altri`);
      },
    });
  }
  assert.ok(restarts > 15, `calci da fermo controllati: ${restarts}`);
});
