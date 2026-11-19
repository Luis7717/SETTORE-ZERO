import { Match, FORMATIONS, HW, HL, GW } from '../src/sim.js';
import { rng32 } from '../src/sim.js';

function mkTeam(name, rating, seed, formation = '4-4-2') {
  const r = rng32(seed); const F = FORMATIONS[formation];
  const players = F.map((s, i) => {
    const v = () => Math.round(rating + (r() - 0.5) * 12);
    return { name: name + i, pos: s[0], vel: v(), tir: v(), pas: v(), dri: v(), dif: v(), fis: v(), por: s[0] === 'P' ? v() + 5 : 20 };
  });
  return { name, formation, players, skill: Math.max(0.1, Math.min(0.95, (rating - 45) / 45)) };
}

const mode = process.argv[2] || 'ai';
const N = +(process.argv[3] || 12);
let tot = 0, ev = {}, nan = 0, maxStall = 0;
const t0 = Date.now();
for (let g = 0; g < N; g++) {
  const fs = Object.keys(FORMATIONS);
  const m = new Match({ seed: 100 + g, halfLen: 180, human: mode === 'bot' ? [true, false] : [false, false], teams: [mkTeam('A', 60 + (g % 3) * 8, g * 7 + 1, fs[g % 4]), mkTeam('B', 62, g * 13 + 5, fs[(g + 1) % 4])] });
  const br = rng32(999 + g);
  let steps = 0, stall = 0, lastBx = 0, lastBy = 0;
  while (m.phase !== 'full' && steps < 60 * 60 * 20) {
    m.step(1 / 60); steps++;
    if (m.phase === 'half') m.startSecondHalf();
    for (const e of m.events) ev[e.type + (e.kind ? ':' + e.kind : '')] = (ev[e.type + (e.kind ? ':' + e.kind : '')] || 0) + 1;
    m.events.length = 0;
    const b = m.ball;
    if (!isFinite(b.x + b.y + b.h + b.vx + b.vy)) { nan++; console.log('NaN ball', g, steps); break; }
    for (const p of m.players) if (!isFinite(p.x + p.y + p.fx + p.fy)) { nan++; console.log('NaN player', g, steps, p.name, p.state); break; }
    if (Math.hypot(b.x - lastBx, b.y - lastBy) < 0.01) { stall++; if (stall > maxStall) maxStall = stall; } else stall = 0;
    lastBx = b.x; lastBy = b.y;
    if (mode === 'bot') {
      const c = m.ctrl[0];
      if (c && m.ball.owner === c) {
        if (br() < 0.02) {
          const r = br();
          if (r < 0.25 && c.y > 20) m.userKick(0, { type: 'shot', tx: (br() - 0.5) * GW, ty: HL, th: br() * 2.2, curve: (br() - 0.5) * 4 });
          else m.userKick(0, { type: 'auto', tx: c.x + (br() - 0.5) * 30, ty: c.y + br() * 25 - 3, curve: (br() - 0.5) * 6 });
        } else if (br() < 0.05) m.userMove(0, c.x + (br() - 0.5) * 20, c.y + br() * 20, false);
      } else if (c) {
        if (br() < 0.01) m.userSlide(0, m.ball.x - c.x, m.ball.y - c.y);
        else if (br() < 0.2) m.userMove(0, m.ball.x, m.ball.y, true);
      }
      if (m.diveWin(0) && br() < 0.08) m.userDive(0, (m.ball.shot.cx - m.gk(0).x) * (0.6 + br() * 0.8), m.ball.shot.ch);
    }
  }
  tot += m.score[0] + m.score[1];
  console.log(`g${g} ${m.score[0]}-${m.score[1]} tiri ${m.stats.shots} in porta ${m.stats.onT} poss ${m.stats.poss.map(x => Math.round(x))} falli ${m.stats.fouls} corner ${m.stats.corners} parate ${m.stats.saves} passi ${steps}`);
}
console.log('gol/partita', (tot / N).toFixed(2), 'NaN', nan, 'stallo max (s)', (maxStall / 60).toFixed(1), 'ms', Date.now() - t0);
console.log(ev);
