// Esporta le tracce del motore JS per il confronto con il porting in GDScript (godot/tests/test_equivalence.gd).
// Uso: node test/export-trace.mjs   → godot/tests/fixtures/{rng,math,trace_N}.json
// Va rilanciato ogni volta che il motore JS cambia (e il porting GDScript va aggiornato di conseguenza).
//
// Contenuto:
//  - rng.json: i primi numeri di rng32 per alcuni semi, come bit esatti (16 cifre esadecimali, little endian);
//  - math.json: sin, cos, atan2 e Math.hypot su valori casuali negli intervalli usati dal motore (bit esatti):
//    servono a sapere se le funzioni di Godot danno gli stessi bit di V8;
//  - trace_N.json: partite intere a seme fisso: un'impronta a 32 bit dello stato a OGNI passo (pallone e giocatori,
//    bit per bit), gli eventi con il passo in cui avvengono, lo stato in chiaro ogni FRAME_EVERY passi
//    (per misurare di quanto divergono le partite, se divergono), punteggio, statistiche e numero di passi.
//  - sprint.json: la fuga e il tasto Scatto (userSprint → burst), che le partite col bot non toccano mai: per alcune
//    scene (avversario dietro, alla pari, davanti "per linee", squadra 1) se si apre la fuga o il duello, l'esito del
//    tocco e l'impronta dello stato a ogni passo per SPRINT_SEC secondi dopo.
//  - dribble.json: il tasto Dribbling prenotato (userDribble → dribBookStep → dribble col lato scelto), che le partite
//    col bot non usano: difensore a varie distanze e di lato, vicino alla linea laterale, un altro avversario, squadra 1;
//    esito del tocco, eventi (col lato) e impronta dello stato a ogni passo per DRIB_SEC secondi.
//  - restart.json: niente doppio tocco sui calci da fermo (b.dbl, dblBan): rimessa, angolo, punizione, rinvio, calcio
//    d'inizio e rigore battuti corti, col battitore che insegue il pallone (anche oltre DBL_FREE) o a campo pieno con l'IA.
import { writeFileSync, mkdirSync } from 'node:fs';
import { rng32, HW, HL } from '../src/sim.js';
import { playMatch } from './lib/harness.mjs';
import { scene, wake, give, park } from './lib/scene.mjs';

const OUT = 'godot/tests/fixtures';
const FRAME_EVERY = 120;
const dv = new DataView(new ArrayBuffer(8));
const hex = x => { dv.setFloat64(0, x, true); let s = ''; for (let i = 0; i < 8; i++) s += dv.getUint8(i).toString(16).padStart(2, '0'); return s; };
// impronta FNV-1a sui 32 bit bassi e alti del double (stessa funzione in GDScript)
const mix = (h, x) => {
  dv.setFloat64(0, x, true);
  h = Math.imul(h ^ dv.getUint32(0, true), 16777619) >>> 0;
  return Math.imul(h ^ dv.getUint32(4, true), 16777619) >>> 0;
};
const STATE = { play: 1, prep: 2, slide: 3, down: 4, dive: 5 };
export function stepHash(m) {
  const b = m.ball;
  let h = 2166136261;
  for (const v of [b.x, b.y, b.h, b.vx, b.vy, b.vh]) h = mix(h, v);
  for (const p of m.players) {
    for (const v of [p.x, p.y, p.vx, p.vy, p.fx, p.fy, p.energy]) h = mix(h, v);
    h = Math.imul(h ^ STATE[p.state], 16777619) >>> 0;
  }
  return h;
}
const r6 = x => Math.round(x * 1e6) / 1e6;

export const TRACE_SCENARIOS = [
  { seed: 1, mode: 'bot', my: 60, op: 60, halfLen: 60 },
  { seed: 2, mode: 'bot', my: 55, op: 70, halfLen: 60, fB: '4-3-3' },
  { seed: 3, mode: 'bot', my: 75, op: 65, halfLen: 60, fA: '3-5-2', fB: '4-2-3-1' },
  { seed: 4, mode: 'ai', my: 62, op: 62, halfLen: 60, fA: '4-3-3', fB: '3-5-2' },
  { seed: 5, mode: 'ai', my: 50, op: 80, halfLen: 60, fA: '4-2-3-1' },
  { seed: 7, mode: 'bot', my: 60, op: 60, halfLen: 150 },
  { seed: 42, mode: 'ai', my: 60, op: 60, halfLen: 150, fA: '4-3-3', fB: '4-2-3-1' },
];

function trace(sc) {
  const hashes = [], events = [], frames = [];
  let n = 0;
  const { m, steps } = playMatch({
    ...sc,
    onStep(mm) {
      hashes.push(stepHash(mm).toString(16).padStart(8, '0'));
      for (const e of mm.events) events.push([n, e.type, e.kind || '', e.p ? e.p.team * 11 + e.p.i : -1]);
      if (n % FRAME_EVERY === 0) {
        const b = mm.ball;
        frames.push([n, r6(b.x), r6(b.y), r6(b.h), ...mm.players.flatMap(p => [r6(p.x), r6(p.y)])]);
      }
      n++;
    },
  });
  return { scenario: sc, steps, score: m.score, stats: m.stats, frameEvery: FRAME_EVERY, hashes: hashes.join(''), events, frames };
}

// Fuga e Scatto: portatore umano della squadra `team` in (px, py) che corre verso la porta avversaria (con velocità
// iniziale vy0), avversario a (ox, oy) da lui; oy > 0 = più avanti verso la porta che attacca il portatore.
// Un passo col dito fermo (o tenuto in avanti, `run`), poi il tocco di Scatto e SPRINT_SEC secondi di partita.
const SPRINT_SEC = 2.4;
export const SPRINT_SCENES = [];
{
  const OFF = [[0, -2.5], [2.5, 0], [-2, -1.5], [3, 0.4], [0.8, -1.2], [-1, -3.5], [1.5, 0.3], [0, 3], [2, 2], [-0.3, 0.6], [3.5, -0.2], [0, -4.5]];
  for (let k = 0; k < OFF.length; k++) SPRINT_SCENES.push({ seed: k + 1, team: 0, px: 0, py: 0, ox: OFF[k][0], oy: OFF[k][1], vy0: k % 3 ? 4 : 0, run: k % 2 === 1 });
  SPRINT_SCENES.push(
    { seed: 13, team: 0, px: 30, py: 40, ox: -1, oy: -2, vy0: 4, run: true },
    { seed: 14, team: 0, px: -30.5, py: -10, ox: 0.5, oy: -1, vy0: 0, run: false },
    { seed: 15, team: 1, px: 0, py: 0, ox: 0.5, oy: -2, vy0: 4, run: true },
    { seed: 16, team: 1, px: 10, py: 20, ox: -2, oy: 0.2, vy0: 0, run: false },
    { seed: 17, team: 1, px: 0, py: 0, ox: 1, oy: 2.5, vy0: 0, run: false },
  );
}
function sprintScene(sc) {
  const T = sc.team, dir = T ? -1 : 1;
  const m = scene({ seed: sc.seed, human: T ? [false, true] : [true, false] }), p = m.players[T * 11 + 9], o = m.players[(1 - T) * 11 + 3];
  wake(p, sc.px, sc.py); p.fx = 0; p.fy = dir; p.vy = sc.vy0 * dir; give(m, p); m.updateCtrl(T);
  wake(o, sc.px + sc.ox, sc.py + sc.oy * dir); o.fx = 0; o.fy = dir;
  if (sc.run) m.userMove(T, p.x, p.y + 10 * dir, true); else m.userMove(T, p.x, p.y, true);
  m.step(1 / 60); m.events.length = 0;
  const flee = m.fleeFor(T), duel = m.duelFor(T), tapped = m.userSprint(T), burst = p.burst;
  const evs0 = m.events.map(x => x.type);
  m.events.length = 0;
  const hashes = [], events = [];
  for (let n = 0; n < Math.round(SPRINT_SEC * 60); n++) {
    m.step(1 / 60);
    hashes.push(stepHash(m).toString(16).padStart(8, '0'));
    for (const x of m.events) events.push([n, x.type, x.p ? x.p.team * 11 + x.p.i : -1]);
    m.events.length = 0;
  }
  return { scene: sc, flee, duel, tapped, burst, tapEvents: evs0, hashes: hashes.join(''), events };
}

// Dribbling prenotato: portatore umano della squadra `team` in (px, 0) che guarda verso la porta avversaria, difensore a
// (ox, d) da lui (d in avanti), con velocità ovy verso il portatore; `extra` = un altro avversario a (ex, ey) da lui.
// Un passo col dito fermo (si apre il duello), poi il tocco di Dribbling e DRIB_SEC secondi di partita.
const DRIB_SEC = 2.4;
export const DRIB_SCENES = [
  { seed: 1, team: 0, px: 0, d: 6.5, ox: 0, ovy: 0 },
  { seed: 2, team: 0, px: 0, d: 5, ox: -0.8, ovy: 2 },
  { seed: 3, team: 0, px: 0, d: 5, ox: 0.8, ovy: 0 },
  { seed: 4, team: 0, px: 0, d: 3, ox: 0.3, ovy: 3 },
  { seed: 5, team: 0, px: 0, d: 1.6, ox: 0, ovy: 0 },
  { seed: 6, team: 0, px: 29, d: 5, ox: -0.6, ovy: 0 },
  { seed: 7, team: 0, px: -29, d: 4, ox: 0.6, ovy: 1 },
  { seed: 8, team: 0, px: 5, d: 6, ox: 0, ovy: 0, extra: [-2.5, 8] },
  { seed: 9, team: 1, px: 3, d: 5.5, ox: 0.5, ovy: 2 },
  { seed: 10, team: 1, px: -10, d: 4.5, ox: -0.4, ovy: 0, extra: [2, 7] },
  { seed: 11, team: 0, px: 0, d: 6, ox: 0, ovy: 0, dri: 30, dif: 90 },
  { seed: 12, team: 0, px: 0, d: 6.8, ox: 1.2, ovy: -1 },
];
function dribScene(sc) {
  const T = sc.team, dir = T ? -1 : 1;
  const m = scene({ seed: sc.seed, human: T ? [false, true] : [true, false] }), p = m.players[T * 11 + 9], o = m.players[(1 - T) * 11 + 3];
  wake(p, sc.px, 0); p.fx = 0; p.fy = dir; p.st.dri = sc.dri || 80; give(m, p); m.updateCtrl(T);
  wake(o, sc.px + sc.ox, sc.d * dir); o.fx = 0; o.fy = -dir; o.vy = -sc.ovy * dir; o.st.dif = sc.dif || 50;
  if (sc.extra) wake(m.players[(1 - T) * 11 + 5], sc.px + sc.extra[0], sc.extra[1] * dir);
  m.userMove(T, p.x, p.y, true); m.step(1 / 60); m.events.length = 0;
  const duel = m.duelFor(T), tapped = m.userDribble(T), booked = m.dribBooked(T);
  const tapEvents = m.events.map(x => [x.type, x.side || 0]);
  m.events.length = 0;
  const hashes = [], events = [];
  for (let n = 0; n < Math.round(DRIB_SEC * 60); n++) {
    m.step(1 / 60);
    hashes.push(stepHash(m).toString(16).padStart(8, '0'));
    for (const x of m.events) events.push([n, x.type, x.p ? x.p.team * 11 + x.p.i : -1, x.side || 0]);
    m.events.length = 0;
  }
  return { scene: sc, duel, tapped, booked, tapEvents, hashes: hashes.join(''), events };
}

// Calci da fermo: setRestart(type, team, x, y), poi il battitore calcia corto verso (dx, dy) dal pallone.
// solo = tutti gli altri parcheggiati e il battitore che insegue il pallone col dito (squadra umana 0) per RESTART_SEC s
// (oltre DBL_FREE); altrimenti campo pieno, IA contro IA.
const RESTART_SEC = 7.5;
export const RESTART_SCENES = [
  { seed: 1, type: 'throw', team: 0, x: HW, y: 5, dx: -2, dy: 2, solo: true },
  { seed: 2, type: 'corner', team: 0, x: HW, y: HL, dx: -2, dy: -2, solo: true },
  { seed: 3, type: 'freekick', team: 0, x: 5, y: -10, dx: -2, dy: 2, solo: true },
  { seed: 4, type: 'goalkick', team: 0, x: 5, y: -HL, dx: -2, dy: 2, solo: true },
  { seed: 5, type: 'kickoff', team: 0, x: 0, y: 0, dx: 2, dy: 2, solo: true },
  { seed: 6, type: 'penalty', team: 0, x: 0, y: 0, dx: 1, dy: 3, solo: true },
  { seed: 7, type: 'throw', team: 1, x: -HW, y: -8, dx: 3, dy: -3, solo: false },
  { seed: 8, type: 'corner', team: 1, x: -HW, y: -HL, dx: 4, dy: 4, solo: false },
  { seed: 9, type: 'freekick', team: 0, x: -6, y: 12, dx: 2, dy: 1, solo: false },
  { seed: 10, type: 'goalkick', team: 1, x: -5, y: HL, dx: 3, dy: -3, solo: false },
];
function restartScene(sc) {
  const m = scene({ seed: sc.seed, human: sc.solo ? [true, false] : [false, false] });
  m.setRestart(sc.type, sc.team, sc.x, sc.y);
  const p = m.restart.taker, b = m.ball;
  if (sc.solo) m.players.forEach((q, k) => { if (q !== p) park(q, k); });
  m.restart.t = 1;
  m.kick(p, { type: 'ground', tx: b.x + sc.dx, ty: b.y + sc.dy });
  const dbl = b.dbl === p;
  m.events.length = 0;
  const hashes = [], events = [];
  for (let n = 0; n < Math.round(RESTART_SEC * 60); n++) {
    if (sc.solo) { m.ctrl[0] = p; m.switchCd[0] = 9; m.userMove(0, b.x, b.y, true); }
    m.step(1 / 60);
    hashes.push(stepHash(m).toString(16).padStart(8, '0'));
    for (const x of m.events) events.push([n, x.type, x.kind || '', x.p ? x.p.team * 11 + x.p.i : -1]);
    m.events.length = 0;
  }
  return { scene: sc, taker: p.team * 11 + p.i, dbl, hashes: hashes.join(''), events };
}

function main() {
  mkdirSync(OUT, { recursive: true });
  // numeri casuali
  const rng = {};
  for (const s of [1, 2, 42, 7 * 7 + 1, 123456789, 4294967295, -5]) { const r = rng32(s); rng[s] = Array.from({ length: 500 }, () => hex(r())); }
  writeFileSync(`${OUT}/rng.json`, JSON.stringify(rng) + '\n');
  // funzioni matematiche (valori nei campi usati dal motore)
  const r = rng32(2026), N = 2000, math = { sin: [], cos: [], atan2: [], hypot: [] };
  for (let i = 0; i < N; i++) {
    const a = (r() - 0.5) * 4 * Math.PI, y = (r() - 0.5) * 120, x = (r() - 0.5) * 120 * (r() < 0.1 ? 1e-3 : 1);
    math.sin.push([hex(a), hex(Math.sin(a))]);
    math.cos.push([hex(a), hex(Math.cos(a))]);
    math.atan2.push([hex(y), hex(x), hex(Math.atan2(y, x))]);
    math.hypot.push([hex(y), hex(x), hex(Math.hypot(y, x))]);
  }
  writeFileSync(`${OUT}/math.json`, JSON.stringify(math) + '\n');
  // fuga e Scatto
  writeFileSync(`${OUT}/sprint.json`, JSON.stringify({ sec: SPRINT_SEC, scenes: SPRINT_SCENES.map(sprintScene) }) + '\n');
  // dribbling prenotato e calci da fermo senza doppio tocco
  writeFileSync(`${OUT}/dribble.json`, JSON.stringify({ sec: DRIB_SEC, scenes: DRIB_SCENES.map(dribScene) }) + '\n');
  writeFileSync(`${OUT}/restart.json`, JSON.stringify({ sec: RESTART_SEC, scenes: RESTART_SCENES.map(restartScene) }) + '\n');
  // partite
  for (const [i, sc] of TRACE_SCENARIOS.entries()) {
    const t = trace(sc);
    writeFileSync(`${OUT}/trace_${i}.json`, JSON.stringify(t) + '\n');
    process.stdout.write(`trace_${i}: ${t.score.join('-')} in ${t.steps} passi, ${t.events.length} eventi\n`);
  }
}

main();
