// Diagnosi del gioco d'attacco: dove e come si perde palla, quante volte si arriva negli ultimi 30 m,
// tiri, gol, angoli, rimesse. Uso: node test/diag-flow.mjs [forza] [partite] [modo bot|ai]
import { playMatch } from './lib/harness.mjs';
import { HL } from '../src/sim.js';

const rating = +(process.argv[2] || 60), N = +(process.argv[3] || 20), mode = process.argv[4] || 'bot';
const zone = (y, T) => { const f = y * (T ? -1 : 1); return f < -17 ? 'difesa' : f < HL - 30 ? 'centro' : 'ultimi30'; };
const T0 = () => ({ acts: 0, half: 0, entryShot: 0, actShot: 0, shots: 0, onT: 0, goals: 0, corners: 0, throws: 0, goalkicks: 0, entries: 0, lost: {}, how: {}, passes: 0, passOk: 0, heads: 0, volleys: 0, clears: 0, airGoals: 0, adv: 0, walls: 0, duels: 0, drib: 0, dribOk: 0, fr: 0, near6: 0, minD: 0, pairs: 0, defFr: 0, ahead: 0 });
const S = [T0(), T0()];
for (let g = 0; g < N; g++) {
  let owner = -1, lastKick = [null, null], act = null, airAt = -9;
  const close = a => { const s = S[a.T]; s.acts++; if (a.depth > HL - 30) { s.entries++; if (a.shot) s.entryShot++; } else if (a.depth > 0) s.half++; if (a.shot) s.actShot++; };
  const { m } = playMatch({
    seed: 500 + g, mode, my: rating, op: rating, fB: ['4-4-2', '4-3-3', '3-5-2', '4-2-3-1'][g % 4],
    onStep(mm) {
      const b = mm.ball;
      for (const e of mm.events) {
        if (e.type === 'restart') { if (e.kind === 'corner') S[e.team].corners++; if (e.kind === 'throw') S[e.team].throws++; if (e.kind === 'goalkick') S[e.team].goalkicks++; }
        if (e.type === 'kick' && (e.kind === 'ground' || e.kind === 'loft')) { S[e.p.team].passes++; lastKick[e.p.team] = e.kind; }
        if (e.type === 'kick' && e.kind === 'header') { if (e.clear) S[e.p.team].clears++; else S[e.p.team].heads++; }
        if (e.type === 'kick' && e.kind === 'volley') S[e.p.team].volleys++;
        if (e.type === 'kick') airAt = (e.kind === 'header' || e.kind === 'volley') && !e.clear ? mm.time : (e.kind === 'shot' ? -9 : airAt);
        if (e.type === 'goal' && mm.time - airAt < 3) S[e.team].airGoals++;
        if (e.type === 'advantage') S[e.team].adv++;
        if (e.type === 'duel_start') S[e.p.team].duels++;
        if (e.type === 'dribble') { S[e.p.team].drib++; if (e.ok) S[e.p.team].dribOk++; }
        if (e.type === 'restart' && e.kind === 'freekick' && mm.restart && mm.restart.wallSide) S[e.team].walls++;
      }
      const now = b.owner ? b.owner.team : -1;
      if (now >= 0 && now !== owner) {
        if (owner >= 0 || lastKick[1 - now]) {
          const L = 1 - now, z = zone(b.y, L), ev = mm.events.find(e => e.type === 'tackle' || e.type === 'control');
          const how = ev && ev.type === 'tackle' ? 'contrasto' : lastKick[L] ? 'passaggio intercettato' : 'palla persa';
          S[L].lost[z] = (S[L].lost[z] || 0) + 1; S[L].how[z + ' · ' + how] = (S[L].how[z + ' · ' + how] || 0) + 1;
        }
        if (owner === now || (owner < 0 && lastKick[now])) S[now].passOk++;
        lastKick = [null, null];
      } else if (now >= 0 && now === owner && lastKick[now]) { S[now].passOk++; lastKick[now] = null; }
      if (now >= 0) owner = now;
      // spazi in attacco: compagni entro 6 m dal portatore e distanza media dal compagno più vicino (senza palla, portiere escluso);
      // in difesa (avversario col pallone nella nostra metà): quanti nostri giocatori di movimento sono davanti alla palla
      if (now >= 0 && mm.phase === 'play') {
        const c = b.owner, mates = mm.players.filter(q => q.team === now && !q.off && q.pos !== 'P' && q !== c), s = S[now];
        s.fr++; s.near6 += mates.filter(q => Math.hypot(q.x - c.x, q.y - c.y) < 6).length;
        let sum = 0; for (const q of mates) { let nd = 99; for (const r of mates) if (r !== q) nd = Math.min(nd, Math.hypot(r.x - q.x, r.y - q.y)); sum += nd; }
        s.minD += sum / Math.max(1, mates.length);
        for (let i = 0; i < mates.length; i++) for (let j = i + 1; j < mates.length; j++) if (Math.hypot(mates[i].x - mates[j].x, mates[i].y - mates[j].y) < 6) s.pairs++;
        const D = 1 - now, dd = D ? -1 : 1;
        if (c.y * dd < 0) { const sd = S[D]; sd.defFr++; sd.ahead += mm.players.filter(q => q.team === D && !q.off && q.pos !== 'P' && q.y * dd > c.y * dd + 2).length; }
      }
      // azioni: da quando una squadra prende palla a quando la prende l'altra (o c'è una rimessa per l'altra)
      const shotNow = mm.events.some(e => e.type === 'kick' && e.kind === 'shot');
      if (shotNow && act) act.shot = true;
      const startT = now >= 0 ? now : (mm.phase === 'restart' ? mm.restart.team : -1);
      if (startT >= 0 && (!act || act.T !== startT)) {
        if (act) close(act);
        act = { T: startT, depth: -99, shot: false };
      }
      if (act && now === act.T) act.depth = Math.max(act.depth, b.y * (act.T ? -1 : 1));
    },
  });
  for (let T = 0; T < 2; T++) { S[T].shots += m.stats.shots[T]; S[T].onT += m.stats.onT[T]; S[T].goals += m.score[T]; }
}
const f = v => (v / N).toFixed(1);
for (let T = 0; T < 2; T++) {
  const s = S[T];
  console.log(`${T ? 'IA   ' : mode === 'bot' ? 'UMANO' : 'IA-0 '} tiri ${f(s.shots)} (in porta ${f(s.onT)}) gol ${f(s.goals)} | azioni ${f(s.acts)}: in metà campo avversaria ${f(s.half + s.entries)}, negli ultimi30 ${f(s.entries)}, con tiro ${f(s.actShot)} | angoli ${f(s.corners)} rimesse ${f(s.throws)} rinvii ${f(s.goalkicks)} | passaggi ${f(s.passes)} riusciti ${(s.passOk / Math.max(1, s.passes) * 100).toFixed(0)}%`);
  console.log(`   colpi di testa ${f(s.heads)} al volo ${f(s.volleys)} (gol così ${f(s.airGoals)}) respinte di testa ${f(s.clears)} | vantaggi ${f(s.adv)} punizioni con barriera ${f(s.walls)} | duelli ${f(s.duels)} dribbling ${f(s.drib)} riusciti ${f(s.dribOk)}`);
  console.log(`   spazi: compagni entro 6 m dal portatore ${(s.near6 / Math.max(1, s.fr)).toFixed(2)} | distanza media dal compagno più vicino ${(s.minD / Math.max(1, s.fr)).toFixed(1)} m | coppie di compagni senza palla a meno di 6 m ${(s.pairs / Math.max(1, s.fr)).toFixed(2)} | in difesa nella nostra metà, giocatori davanti alla palla ${(s.ahead / Math.max(1, s.defFr)).toFixed(2)}`);
  console.log('   palle perse:', Object.entries(s.lost).map(([k, v]) => `${k} ${f(v)}`).join(', '));
  console.log('   come:', Object.entries(s.how).sort((a, b) => b[1] - a[1]).slice(0, 6).map(([k, v]) => `${k} ${f(v)}`).join(', '));
}
