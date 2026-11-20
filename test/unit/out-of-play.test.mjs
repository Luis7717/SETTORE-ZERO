import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Match, HL, GW, rng32 } from '../../src/sim.js';
import { mkTeam, playMatch } from '../lib/harness.mjs';

const newMatch = (seed) => {
  const m = new Match({ seed, halfLen: 9999, human: [false, false], teams: [mkTeam('A', 60, 1), mkTeam('B', 60, 2)] });
  m.phase = 'play'; m.restart = null; m.ball.owner = null;
  return m;
};
// lascia correre il pallone (senza giocatori che lo tocchino) finché esce o passano `sec` secondi
const runBall = (m, sec = 3) => {
  for (const p of m.players) { p.x = 0; p.y = 0; p.state = 'down'; p.t = 99; }
  const ev = [];
  for (let i = 0; i < sec * 60 && m.phase === 'play'; i++) { m.updateBall(1 / 60); ev.push(...m.events); m.events.length = 0; }
  return ev;
};

test('deflectBehind: il pallone esce dalla linea di fondo fuori dai pali o sopra la traversa, mai in porta', () => {
  const r = rng32(7);
  for (let k = 0; k < 200; k++) {
    // Arrange: palla davanti alla porta della squadra 0 (y = -HL), alta o bassa, ferma o veloce
    const m = newMatch(100 + k), gk = m.gk(0), b = m.ball;
    b.x = (r() - 0.5) * GW * 1.4; b.y = -HL + 0.3 + r() * 5; b.h = r() * 2.4; b.vx = (r() - 0.5) * 20; b.vy = -5 - r() * 20; b.vh = 0;
    // Act
    m.deflectBehind(gk);
    const ev = runBall(m);
    // Assert
    assert.ok(!ev.some(e => e.type === 'goal'), `gol al tentativo ${k}`);
    assert.equal(m.phase, 'restart', `palla non uscita al tentativo ${k}`);
    assert.equal(m.restart.type, 'corner');
    assert.equal(m.restart.team, 1);
  }
});

test('save: una parte delle respinte non bloccate finisce in calcio d\'angolo', () => {
  let corners = 0;
  const N = 60;
  for (let k = 0; k < N; k++) {
    // Arrange: tiro forte e laterale che il portiere della squadra 1 non può bloccare
    const m = newMatch(300 + k), gk = m.gk(1), b = m.ball;
    gk.x = 0; gk.y = HL - 0.6; b.x = 2.5; b.y = HL - 0.8; b.h = 1; b.vx = 2; b.vy = 28; b.vh = 0; b.last = m.players[9];
    // Act
    m.save(gk, false);
    runBall(m);
    // Assert (conteggio)
    if (m.phase === 'restart' && m.restart.type === 'corner') corners++;
  }
  assert.ok(corners >= N * 0.3 && corners <= N * 0.8, `angoli ${corners} su ${N}`);
});

test('spazzata: il difensore pressato senza passaggi sicuri rinvia lungo', () => {
  let long = 0;
  const N = 20;
  for (let k = 0; k < N; k++) {
    // Arrange: difensore della squadra 1 nella propria area, attaccante addosso, compagni (portiere compreso) tutti marcati stretti
    const m = newMatch(700 + k), d = m.players[13], b = m.ball;
    const mates = m.team(1), opps = m.team(0);
    mates.forEach((p, i) => { p.x = -24 + i * 4.8; p.y = HL - 30; p.vx = p.vy = 0; p.state = 'play'; });
    opps.forEach((o, i) => { const p = mates[i]; o.x = p.x; o.y = p.y - 0.8; o.vx = o.vy = 0; o.state = 'play'; });
    d.x = 5; d.y = HL - 10; d.fx = 0; d.fy = -1; b.owner = d; d.protect = 9; d.aiT = 0; b.x = d.x; b.y = d.y - 0.6;
    const att = m.players[9]; att.x = d.x; att.y = d.y - 1.4; att.tackleCd = 9;
    let kick = null;
    // Act
    for (let i = 0; i < 90 && !kick; i++) { m.dtT = 1 / 60; m.carrierAI(d); kick = m.events.find(e => e.type === 'kick'); m.events.length = 0; }
    // Assert (conteggio)
    // lunghezza del volo = velocità orizzontale × tempo in aria; deve andare verso la porta avversaria (y decrescente)
    const flight = Math.hypot(b.vx, b.vy) * 2 * b.vh / 11.5;
    if (kick && kick.kind === 'loft' && b.vy < 0 && flight > 18) long++;
  }
  assert.ok(long >= N * 0.7, `spazzate lunghe ${long} su ${N}`);
});

test('contrasto: a volte la palla schizza via invece di passare pulita al difensore', () => {
  let loose = 0, clean = 0;
  for (let g = 0; g < 10; g++) playMatch({ seed: 40 + g, mode: 'ai', halfLen: 90, onStep(m) { for (const e of m.events) if (e.type === 'tackle' && !e.slide) { if (e.loose) loose++; else clean++; } } });
  const frac = loose / Math.max(1, loose + clean);
  assert.ok(frac > 0.15 && frac < 0.45, `contrasti con palla vagante ${loose} su ${loose + clean}`);
});

// angoli e rimesse a squadra e a partita, umano simulato contro IA a pari forza
const restarts = (() => {
  let corners = 0, throws = 0;
  const N = 8;
  for (let g = 0; g < N; g++) playMatch({ seed: 900 + g, mode: 'bot', my: 60, op: 60, onStep(m) { for (const e of m.events) if (e.type === 'restart') { if (e.kind === 'corner') corners++; if (e.kind === 'throw') throws++; } } });
  return { corners: corners / N / 2, throws: throws / N / 2 };
})();

// Obiettivo NON più raggiunto dal 2026-11-20 (vedi DECISIONI.md): con la difesa della squadra umana mossa dalla CPU
// l'IA arriva molto meno al tiro, e gli angoli vengono quasi solo dai tiri respinti (ora circa 0,8-1,1 a squadra).
test('in partita c\'è almeno un calcio d\'angolo a squadra (media)', { todo: 'angoli sotto obiettivo con la nuova difesa umana' }, () => {
  assert.ok(restarts.corners >= 1, `angoli per squadra ${restarts.corners}`);
});

// Obiettivo NON ancora raggiunto (vedi DECISIONI.md): le rimesse restano poche.
test('in partita ci sono almeno 2 rimesse laterali a squadra (media)', { todo: 'rimesse ancora sotto obiettivo' }, () => {
  assert.ok(restarts.throws >= 2, `rimesse per squadra ${restarts.throws}`);
});
