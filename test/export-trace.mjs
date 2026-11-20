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
//  - sprint.json: il tasto Scatto nel duello (userSprint), che le partite col bot non toccano mai: per alcune scene
//    l'esito e l'impronta dello stato a ogni passo per SPRINT_SEC secondi dopo il tocco.
import { writeFileSync, mkdirSync } from 'node:fs';
import { rng32 } from '../src/sim.js';
import { playMatch } from './lib/harness.mjs';
import { scene, wake, give } from './lib/scene.mjs';

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

// Scatto nel duello: portatore umano verso +y in (px, py), difensore davanti a `dist` m e di lato di `ox` m
const SPRINT_SEC = 2.4;
export const SPRINT_SCENES = [];
for (let seed = 1; seed <= 12; seed++) SPRINT_SCENES.push({ seed, px: 0, py: 0, ox: [0.6, -0.6, 0, 0.02, 1.5, -2][seed % 6], dist: [4, 3, 6][seed % 3], vel: 70, dif: 50 });
SPRINT_SCENES.push({ seed: 13, px: 30, py: 40, ox: -0.5, dist: 4, vel: 80, dif: 40 }, { seed: 14, px: -30.5, py: -10, ox: 0.4, dist: 3.5, vel: 60, dif: 60 });
function sprintScene(sc) {
  const m = scene({ seed: sc.seed }), p = m.players[9], o = m.players[11 + 3];
  wake(p, sc.px, sc.py); p.fx = 0; p.fy = 1; p.st.vel = sc.vel; give(m, p); m.updateCtrl(0);
  wake(o, sc.px + sc.ox, sc.py + sc.dist); o.st.dif = sc.dif; o.fx = 0; o.fy = -1;
  m.userMove(0, p.x, p.y, true); m.step(1 / 60); m.events.length = 0;
  const duel = m.duelFor(0), tapped = m.userSprint(0), e = m.events.find(x => x.type === 'dribble'), burst = p.burst;
  m.events.length = 0;
  const hashes = [], events = [];
  for (let n = 0; n < Math.round(SPRINT_SEC * 60); n++) {
    m.step(1 / 60);
    hashes.push(stepHash(m).toString(16).padStart(8, '0'));
    for (const x of m.events) events.push([n, x.type, x.p ? x.p.team * 11 + x.p.i : -1]);
    m.events.length = 0;
  }
  return { scene: sc, duel, tapped, ok: e ? e.ok : null, burst, hashes: hashes.join(''), events };
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
  // Scatto nel duello
  writeFileSync(`${OUT}/sprint.json`, JSON.stringify({ sec: SPRINT_SEC, scenes: SPRINT_SCENES.map(sprintScene) }) + '\n');
  // partite
  for (const [i, sc] of TRACE_SCENARIOS.entries()) {
    const t = trace(sc);
    writeFileSync(`${OUT}/trace_${i}.json`, JSON.stringify(t) + '\n');
    process.stdout.write(`trace_${i}: ${t.score.join('-')} in ${t.steps} passi, ${t.events.length} eventi\n`);
  }
}

main();
