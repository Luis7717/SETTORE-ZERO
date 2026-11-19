import { Match, FORMATIONS, rng32, HL } from '../src/sim.js';
function mkTeam(name, rating, seed, formation = '4-4-2') {
  const r = rng32(seed); const F = FORMATIONS[formation];
  return { name, formation, skill: (rating-45)/45, players: F.map((s, i) => { const v = () => Math.round(rating + (r() - 0.5) * 12); return { name: name + i, pos: s[0], vel: v(), tir: v(), pas: v(), dri: v(), dif: v(), fis: v(), por: s[0] === 'P' ? v() + 5 : 20 }; }) };
}
const zone=[0,0,0,0,0,0,0,0,0,0]; const cause={}; let lastOwnerTeam=-1, lastKick=null, lastEv='';
const kicks={}; 
for (let g=0;g<6;g++){
const m = new Match({ seed: 50+g, human: [false, false], teams: [mkTeam('A', 62, 1+g), mkTeam('B', 62, 20+g)] });
while (m.phase!=='full'){
  m.step(1/60); if (m.phase==='half') m.startSecondHalf();
  const b=m.ball;
  if (b.owner){ const d=b.owner.team?-1:1; zone[Math.min(9,Math.floor((b.y*d+HL)/10))]++; }
  for (const e of m.events){
    if (e.type==='kick'){ lastKick=e; const k=e.kind+(e.p.pos); kicks[k]=(kicks[k]||0)+1; }
    if (e.type==='control'){ if (lastOwnerTeam>=0 && e.p.team!==lastOwnerTeam){ const c=lastKick? 'int:'+lastKick.kind : 'loose'; cause[c]=(cause[c]||0)+1; } lastOwnerTeam=e.p.team; lastKick=null; }
    if (e.type==='tackle'){ cause['tackle'+(e.slide?':slide':'')]=(cause['tackle'+(e.slide?':slide':'')]||0)+1; lastOwnerTeam=e.p.team; lastKick=null;}
  }
  m.events.length=0;
}}
console.log('zone possesso (0=propria porta..9=porta avv):', zone.map(z=>Math.round(z/60/6)));
console.log(cause); console.log(kicks);
