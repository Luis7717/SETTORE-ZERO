import { Match, FORMATIONS, rng32 } from '../src/sim.js';
function mkTeam(name, rating, seed, formation = '4-4-2') { const r = rng32(seed); const F = FORMATIONS[formation]; return { name, formation, skill: (rating-42)/48, players: F.map((s, i) => { const v = () => Math.round(rating + (r() - 0.5) * 12); return { name: name + i, pos: s[0], vel: v(), tir: v(), pas: v(), dri: v(), dif: v(), fis: v(), por: s[0] === 'P' ? v() + 5 : 20 }; }) }; }
const m = new Match({ seed: 5, human: [false, false], teams: [mkTeam('A', 60, 1), mkTeam('B', 60, 2)] });
const ok = m.kick.bind(m);
m.kick = (p, sp) => { const d = p.team ? -1 : 1; console.log(`   ${m.time.toFixed(1)} ${p.name}(${p.pos}) y=${(p.y * d).toFixed(0)} x=${p.x.toFixed(0)} ${sp.type} -> y=${(sp.ty * d).toFixed(0)} x=${sp.tx.toFixed(0)} press=${m.nearOpp(p.x, p.y, p.team).toFixed(1)} line=${m.offLine[p.team].toFixed(0)}`); return ok(p, sp); };
for (let i = 0; i < 60 * 70; i++) {
  m.step(1 / 60);
  for (const e of m.events) { if (e.type === 'control') console.log(`${m.time.toFixed(1)} ctrl ${e.p.name}(${e.p.pos}) y=${(e.p.y * (e.p.team ? -1 : 1)).toFixed(0)}`); else if (e.type !== 'kick') console.log(m.time.toFixed(1), e.type, e.kind || '', e.p ? e.p.name : ''); }
  m.events.length = 0;
}
