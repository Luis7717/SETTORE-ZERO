// Stima dell'equilibrio: un "giocatore medio" simulato contro l'IA.
import { Match, FORMATIONS, rng32, HL } from '../src/sim.js';
function mkTeam(name, rating, seed, f = '4-4-2') { const r = rng32(seed); const F = FORMATIONS[f]; return { name, formation: f, skill: Math.max(0.1, Math.min(0.95, (rating - 42) / 48)), players: F.map((s, i) => { const v = () => Math.round(rating + (r() - 0.5) * 10); return { name: name + i, pos: s[0], vel: v(), tir: v(), pas: v(), dri: v(), dif: v(), fis: v(), por: s[0] === 'P' ? v() + 4 : 20 }; }) }; }
const my = +(process.argv[2] || 57), op = +(process.argv[3] || 55), N = +(process.argv[4] || 10), press = +(process.argv[5] || 1);
let gf = 0, ga = 0, sf = 0, sa = 0, w = 0, d = 0, l = 0, poss = 0;
for (let g = 0; g < N; g++) {
  const m = new Match({ seed: 300 + g, halfLen: 150, human: [true, false], teams: [mkTeam('A', my, g + 1), mkTeam('B', op, g + 50, Object.keys(FORMATIONS)[g % 4])] });
  const r = rng32(g + 9); let diveAt = -1;
  while (m.phase !== 'full') {
    m.step(1 / 60); if (m.phase === 'half') m.startSecondHalf(); m.events.length = 0;
    const c = m.ctrl[0], b = m.ball; if (!c) continue;
    if (b.owner === c) {
      if (m.phase === 'restart') { if (m.restart.t > 1.2) { m.human[0] = false; m.aiRestart(); m.human[0] = true; } }
      else { m.dtT = 1 / 60; m.human[0] = false; m.carrierAI(c); m.human[0] = true; if (b.owner === c) m.userMove(0, c.tx, c.ty, true); }
    } else if (b.owner && b.owner.team === 1) { if (press && r() < 0.9) m.userMove(0, b.x + b.owner.vx * 0.25, b.y + b.owner.vy * 0.25, true); }
    if (m.diveWin(0)) { if (diveAt < 0) diveAt = m.time + 0.12 + r() * 0.16; if (m.time >= diveAt) { const s = b.shot, gk = m.gk(0); m.userDive(0, (s.cx - gk.x) * (0.8 + r() * 0.6) + (r() < 0.12 ? -Math.sign(s.cx - gk.x) * 3 : 0), s.ch + (r() - 0.5) * 0.8); diveAt = -1; } } else diveAt = -1;
  }
  gf += m.score[0]; ga += m.score[1]; sf += m.stats.shots[0]; sa += m.stats.shots[1]; poss += m.stats.poss[0] / (m.stats.poss[0] + m.stats.poss[1]);
  if (m.score[0] > m.score[1]) w++; else if (m.score[0] < m.score[1]) l++; else d++;
}
console.log(`io ${my} vs ${op}: V${w} N${d} P${l} | gol ${(gf / N).toFixed(1)}-${(ga / N).toFixed(1)} | tiri ${(sf / N).toFixed(1)}-${(sa / N).toFixed(1)} | possesso ${(poss / N * 100).toFixed(0)}%`);
