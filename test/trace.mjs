import { Match, FORMATIONS, rng32 } from '../src/sim.js';
function mkTeam(name, rating, seed, formation = '4-4-2') {
  const r = rng32(seed); const F = FORMATIONS[formation];
  return { name, formation, skill: (rating-45)/45, players: F.map((s, i) => { const v = () => Math.round(rating + (r() - 0.5) * 12); return { name: name + i, pos: s[0], vel: v(), tir: v(), pas: v(), dri: v(), dif: v(), fis: v(), por: s[0] === 'P' ? v() + 5 : 20 }; }) };
}
const m = new Match({ seed: 5, human: [false, false], teams: [mkTeam('A', 60, 1), mkTeam('B', 62, 2)] });
const T = +(process.argv[2]||25);
for (let i = 0; i < 60 * T; i++) {
  m.step(1 / 60);
  for (const e of m.events) {
    const b = m.ball;
    console.log((i / 60).toFixed(2), e.type, e.kind || '', e.p ? e.p.name + '(' + e.p.pos + ')' : '', 'ball', b.x.toFixed(1), b.y.toFixed(1), 'v', Math.hypot(b.vx, b.vy).toFixed(1), e.on ? 'on ' + e.on.name : '');
  }
  m.events.length = 0;
}
