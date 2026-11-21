// Scene costruite a mano per i test del motore: partita in gioco, tutti i giocatori "parcheggiati"
// lontano e fermi (stordimento lunghissimo), tranne quelli che il test rimette in campo con `wake`.
import { Match } from '../../src/sim.js';
import { mkTeam } from './harness.mjs';

export function scene({ seed = 1, human = [true, false], my = 60, op = 60 } = {}) {
  const m = new Match({ seed, halfLen: 9999, human, teams: [mkTeam('A', my, seed * 7 + 1), mkTeam('B', op, seed * 13 + 5)] });
  m.phase = 'play'; m.restart = null;
  const b = m.ball; b.owner = null; b.kick = null; b.shot = null; b.x = 0; b.y = 0; b.h = 0; b.vx = b.vy = b.vh = 0;
  m.players.forEach((p, k) => park(p, k));
  m.events.length = 0;
  return m;
}

// fermo in un angolo lontano, senza poter toccare il pallone
export function park(p, k = p.i + p.team * 11) {
  p.x = (k % 2 ? 1 : -1) * 31; p.y = -45 + k * 4.3; p.vx = p.vy = 0; p.tx = p.x; p.ty = p.y;
  p.state = 'play'; p.stun = 999; p.contact = 0;
}

// rimette un giocatore in gioco nel punto (x, y)
export function wake(p, x, y) {
  p.x = x; p.y = y; p.vx = p.vy = 0; p.tx = x; p.ty = y; p.stun = 0; p.state = 'play'; p.contact = 0; p.tackleCd = 0; p.protect = 0;
}

export function give(m, p) { const b = m.ball; b.owner = p; b.last = p; b.x = p.x + p.fx * 0.6; b.y = p.y + p.fy * 0.6; p.protect = 0; }

// passi da 1/60 s; onStep(m) prima di ogni passo; ritorna gli eventi visti
export function run(m, sec, onStep) {
  const ev = [];
  for (let i = 0; i < Math.round(sec * 60); i++) { if (onStep) onStep(m); m.step(1 / 60); ev.push(...m.events); m.events.length = 0; }
  return ev;
}

// tocco del tasto Dribbling: prenota il dribbling e fa passi da 1/60 s finché non parte davvero (evento 'dribble',
// al massimo 2 s); ritorna gli eventi visti dal tocco in poi (vuoto se il tasto non ha fatto nulla)
export function tapDribble(m, T = 0) {
  if (!m.userDribble(T)) return [];
  const ev = m.events.splice(0);
  for (let i = 0; i < 120 && !ev.some(e => e.type === 'dribble'); i++) { m.step(1 / 60); ev.push(...m.events); m.events.length = 0; }
  return ev;
}
