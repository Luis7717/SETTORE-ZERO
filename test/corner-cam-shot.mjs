// Prova a schermo della visuale del calcio d'angolo: nostro angolo dalle due bandierine in attacco e angolo
// avversario; per ognuno una schermata e se battitore, pallone e pali stanno a schermo.
// Uso: npm run build && node test/corner-cam-shot.mjs shots
import { b, p, wait, snap, errs } from './shot.mjs';

const CASES = [['nostro-destra', 0, 32, 50], ['nostro-sinistra', 0, -32, 50], ['avversario', 1, 32, -50]];

await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__start('friendly', 50); });
await wait(2500);
const out = [];
for (const [name, team, x, y] of CASES) {
  await p.evaluate((team, x, y) => {
    const G = window.__G, m = G.match; G.paused = false; G.ts = 1;
    m.setRestart('corner', team, x, y);
  }, team, x, y);
  await wait(900);
  const r = await p.evaluate(() => {
    const m = window.__G.match, v = window.__view, r = m.restart, HL = 50, GW = 7.32, GH = 2.44;
    if (!r) return { fase: m.phase, nota: 'angolo già battuto' };
    const gy = Math.sign(r.y) * HL;
    const inside = (x, y, h) => { const s = v.worldToScreen(x, y, h); return s.vis && s.x > 0 && s.x < v.w && s.y > 64 && s.y < v.h - 56; };
    const pts = { battitore: [r.taker.x, r.taker.y, 1], pallone: [m.ball.x, m.ball.y, 0], paloSx: [-GW / 2, gy, 0], paloDx: [GW / 2, gy, 0], traversa: [0, gy, GH] };
    return { fase: m.phase, tipo: r.type, peso: +(v.cornK || 0).toFixed(2), fuori: Object.entries(pts).filter(([, q]) => !inside(...q)).map(([n]) => n) };
  });
  out.push({ caso: name, ...r });
  await snap('corner-' + name);
}
for (const r of out) console.log(JSON.stringify(r));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
