// Strumenti comuni per i test in Node: squadre finte, "umano simulato" e partite complete.
import { Match, FORMATIONS, rng32 } from '../../src/sim.js';

const skillOf = (rating) => Math.max(0.1, Math.min(0.95, (rating - 42) / 48));

/** Squadra con statistiche intorno a `rating` (stesso schema di balance.mjs). */
export function mkTeam(name, rating, seed, formation = '4-4-2', skill = skillOf(rating)) {
  const r = rng32(seed), F = FORMATIONS[formation];
  const players = F.map((s, i) => {
    const v = () => Math.round(rating + (r() - 0.5) * 10);
    return { name: name + i, pos: s[0], vel: v(), tir: v(), pas: v(), dri: v(), dif: v(), fis: v(), por: s[0] === 'P' ? v() + 4 : 20 };
  });
  return { name, formation, skill, players };
}

/**
 * "Giocatore medio" che comanda la squadra 0 con gli stessi comandi del telefono:
 * con la palla usa le scelte dell'IA, in difesa pressa col solo giocatore controllato,
 * in porta si tuffa con un ritardo e un errore casuali.
 */
export function makeBot(seed, press = 1) {
  const r = rng32(seed);
  let diveAt = -1;
  return function botStep(m) {
    const c = m.ctrl[0], b = m.ball;
    if (c) {
      if (b.owner === c) {
        if (m.phase === 'restart') { if (m.restart.t > 1.2) { m.human[0] = false; m.aiRestart(); m.human[0] = true; } }
        else { m.dtT = 1 / 60; m.human[0] = false; m.carrierAI(c); m.human[0] = true; if (b.owner === c) m.userMove(0, c.tx, c.ty, true); }
      } else if (b.owner && b.owner.team === 1) { if (press && r() < 0.9) m.userMove(0, b.x + b.owner.vx * 0.25, b.y + b.owner.vy * 0.25, true); }
    }
    if (m.diveWin(0)) {
      if (diveAt < 0) diveAt = m.time + 0.12 + r() * 0.16;
      if (m.time >= diveAt) {
        const s = b.shot, gk = m.gk(0);
        m.userDive(0, (s.cx - gk.x) * (0.8 + r() * 0.6) + (r() < 0.12 ? -Math.sign(s.cx - gk.x) * 3 : 0), s.ch + (r() - 0.5) * 0.8);
        diveAt = -1;
      }
    } else diveAt = -1;
  };
}

/**
 * Gioca una partita intera a passi di 1/60 s.
 * mode 'bot' = umano simulato (squadra 0) contro IA; 'ai' = IA contro IA.
 * onStep(m) viene chiamato a ogni passo prima che gli eventi vengano svuotati.
 */
export function playMatch({ seed, my = 60, op = 60, mode = 'bot', halfLen = 150, fA = '4-4-2', fB = '4-4-2', onStep, maxSteps = 60 * 60 * 30 }) {
  const m = new Match({ seed, halfLen, human: mode === 'bot' ? [true, false] : [false, false], teams: [mkTeam('A', my, seed * 7 + 1, fA), mkTeam('B', op, seed * 13 + 5, fB)] });
  const bot = mode === 'bot' ? makeBot(seed + 9) : null;
  let steps = 0;
  while (m.phase !== 'full' && steps < maxSteps) {
    m.step(1 / 60); steps++;
    if (m.phase === 'half') m.startSecondHalf();
    if (bot) bot(m);
    if (onStep) onStep(m);
    m.events.length = 0;
  }
  return { m, steps };
}

export const FORMATION_NAMES = Object.keys(FORMATIONS);
