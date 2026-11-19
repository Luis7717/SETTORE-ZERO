import { Match, FORMATIONS, rng32 } from '../src/sim.js';
function mkTeam(name, rating, seed) { const r = rng32(seed); const F = FORMATIONS['4-4-2']; return { name, formation: '4-4-2', skill: 0.4, players: F.map((s, i) => { const v = () => Math.round(rating + (r() - 0.5) * 8); return { name: name + i, pos: s[0], vel: v(), tir: v(), pas: v(), dri: v(), dif: v(), fis: v(), por: s[0] === 'P' ? v() + 3 : 20 }; }) }; }
const m = new Match({ seed: 7, human: [true, false], teams: [mkTeam('A', 56, 1), mkTeam('B', 58, 2)] });
m.phase = 'play'; m.restart = null;
const c = m.players[20]; c.x = 3; c.y = -36; m.ball.owner = c; m.ball.x = 3; m.ball.y = c.y - 0.6;
m.gauss = () => 0;
m.kick(c, { type: 'shot', tx: -2.7, ty: -50, th: 0.9 });
const b = m.ball; console.log('v', b.vx.toFixed(2), b.vy.toFixed(2), b.vh.toFixed(2), 'curl', b.cax, b.cay, b.ct, 'shot', b.shot);
console.log('dir attesa', ((-2.7 - 3) / 13.4).toFixed(3), 'dir reale', (b.vx / b.vy).toFixed(3));
