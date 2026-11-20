// Prova a schermo della visuale del duello: compagni davanti → visuale dritta; nessuno davanti → si gira verso il lato
// con più compagni. Uso: npm run build && node test/duel-side-shot.mjs shots
import { b, p, wait, snap, errs } from './shot.mjs';

await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__start('friendly', 50); });
await wait(2500);
const out = {};
for (const [name, mates] of [['davanti', [[4, 18], [-6, 20]]], ['destra', [[18, 2], [22, -4], [-14, -14]]], ['sinistra', [[-18, 3], [-20, -3], [14, -14]]]]) {
  out[name] = await p.evaluate(async (mates) => {
    const G = window.__G, m = G.match; G.paused = false; m.phase = 'play'; m.restart = null;
    const c = m.players[7]; m.place(c, 0, 0); c.fx = 0; c.fy = 1; m.ball.owner = c; m.ball.kick = null; m.ctrl[0] = c; m.att = 0;
    let k = 0; for (const q of m.team(0)) { if (q === c || q.pos === 'P') continue; const at = mates[k] || [-28 + k, -30]; m.place(q, c.x + at[0], c.y + at[1]); k++; }
    for (const o of m.team(1)) if (o.pos !== 'P') m.place(o, 0, 40);
    const o = m.players[16]; m.place(o, 0.5, 5); o.fx = 0; o.fy = -1;
    await new Promise(r => setTimeout(r, 1500));
    const v = window.__view, vis = [];
    for (const q of m.team(0)) { if (q === c || q.pos === 'P') continue; const sp = v.worldToScreen(q.x, q.y, 1); vis.push([+(q.x - c.x).toFixed(0), +(q.y - c.y).toFixed(0), sp.x > 0 && sp.x < v.w && sp.y > 0 && sp.y < v.h ? 'si' : 'no']); }
    return { duello: m.duelFor(0), lato: v.duelSide(m), giro: +v.sideK.toFixed(2), compagni: vis.filter(x => Math.hypot(x[0], x[1]) < 35) };
  }, mates);
  await snap('ds-' + name);
}
console.log(JSON.stringify(out));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
