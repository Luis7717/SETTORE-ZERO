import { Match, FORMATIONS, rng32, HL } from '../src/sim.js';
function mkTeam(name, rating, seed, f = '4-4-2') { const r = rng32(seed); const F = FORMATIONS[f]; return { name, formation: f, skill: Math.max(0.1, Math.min(0.95, (rating - 42) / 48)), players: F.map((s, i) => { const v = () => Math.round(rating + (r() - 0.5) * 10); return { name: name + i, pos: s[0], vel: v(), tir: v(), pas: v(), dri: v(), dif: v(), fis: v(), por: s[0] === 'P' ? v() + 4 : 20 }; }) }; }
const ends = {}, zone = new Array(10).fill(0); let lastKick = null, own = -1;
const add = (k, y) => { const z = Math.min(9, Math.max(0, Math.floor((-y + HL) / 10))); const key = k + ' z' + z; ends[key] = (ends[key] || 0) + 1; };
for (let g = 0; g < 6; g++) {
  const m = new Match({ seed: 300 + g, halfLen: 150, human: [true, false], teams: [mkTeam('A', 57, g + 1), mkTeam('B', 60, g + 50)] });
  const r = rng32(g + 9);
  while (m.phase !== 'full') {
    m.step(1 / 60); if (m.phase === 'half') m.startSecondHalf();
    const c = m.ctrl[0], b = m.ball;
    if (b.owner && b.owner.team === 1) zone[Math.min(9, Math.max(0, Math.floor((-b.y + HL) / 10)))]++;
    for (const e of m.events) {
      if (e.type === 'kick') lastKick = e.p.team === 1 ? e : null;
      if (e.type === 'tackle' && e.on && e.on.team === 1) add('tackle' + (e.p === c ? ':ctrl' : ':mate') + e.p.pos, b.y);
      if (e.type === 'control') { if (own === 1 && e.p.team === 0 && lastKick) add('int:' + lastKick.kind, b.y); own = e.p.team; }
      if (e.type === 'out' && lastKick) add('out', b.y);
      if (e.type === 'offside') add('offside', b.y);
    }
    m.events.length = 0;
    if (!c) continue;
    if (b.owner === c) { if (m.phase === 'restart') { if (m.restart.t > 1.2) { m.human[0] = false; m.aiRestart(); m.human[0] = true; } } else { m.dtT = 1 / 60; m.human[0] = false; m.carrierAI(c); m.human[0] = true; if (b.owner === c) m.userMove(0, c.tx, c.ty, true); } }
    else if (b.owner && b.owner.team === 1 && r() < 0.9) m.userMove(0, b.x + b.owner.vx * 0.25, b.y + b.owner.vy * 0.25, true);
  }
}
console.log('possesso avversario per zona (0 = loro porta ... 9 = mia porta), secondi:', zone.map(z => Math.round(z / 60 / 6)));
const agg = {}; for (const k in ends) { const [a, z] = k.split(' z'); agg[a] = agg[a] || new Array(10).fill(0); agg[a][+z] += ends[k]; }
for (const k in agg) console.log(k.padEnd(16), agg[k].join(' '), ' tot', agg[k].reduce((a, b) => a + b));
