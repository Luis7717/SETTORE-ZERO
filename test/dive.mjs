import { Match, FORMATIONS, rng32 } from '../src/sim.js';
function mkTeam(name, rating, seed) { const r = rng32(seed); const F = FORMATIONS['4-4-2']; return { name, formation: '4-4-2', skill: 0.4, players: F.map((s, i) => { const v = () => Math.round(rating + (r() - 0.5) * 8); return { name: name + i, pos: s[0], vel: v(), tir: v(), pas: v(), dri: v(), dif: v(), fis: v(), por: s[0] === 'P' ? v() + 3 : 20 }; }) }; }
for (const react of [0.08, 0.15, 0.22, 0.3]) for (const side of [-1, 1]) for (const dist of [14, 20, 26]) {
  let sv = 0, gl = 0, N = 20, log = '';
  for (let k = 0; k < N; k++) {
    const m = new Match({ seed: 7 + k, human: [true, false], teams: [mkTeam('A', 56, 1), mkTeam('B', 58, 2)] });
    m.phase = 'play'; m.restart = null;
    for (const q of m.players) if (q.team === 0 && q.pos !== 'P') q.y = 0;
    const c = m.players[20]; c.x = 3; c.y = -50 + dist; const g = m.gk(0); g.x = 0; g.y = -49.2;
    m.ball.owner = c; m.ball.x = 3; m.ball.y = c.y - 0.6;
    m.kick(c, { type: 'shot', tx: side * 2.7, ty: -50, th: 0.9 });
    const shot = m.ball.shot; let t = 0, dived = false;
    while (t < 2.5 && m.phase === 'play' && m.ball.owner === null) { if (!dived && t >= react && shot) { dived = m.userDive(0, (shot.cx - g.x) * 1.15, shot.ch); } m.step(1 / 60); t += 1 / 60; if (m.stats.saves[0]) break; }
    if (m.stats.saves[0]) sv++; else if (m.score[1]) gl++;
    if (k === 0) log = shot ? `cx ${shot.cx.toFixed(1)} tc ${shot.tc.toFixed(2)}` : 'no-shot';
  }
  console.log(`reazione ${react}s lato ${side} dist ${dist}m: parate ${sv}/${N} gol ${gl} (${log})`);
}
