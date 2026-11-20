// Prova a schermo della fuga (Puppeteer, iPhone 390×844): avversario alle spalle del portatore →
// tempo rallentato, tasto Scatto; toccandolo il portatore si stacca e prosegue dritto.
import { b, p, wait, snap, errs } from './shot.mjs';

await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__start('friendly', 50); });
await wait(2500);
await p.evaluate(() => {
  const m = window.__G.match; m.phase = 'play'; m.restart = null;
  const c = m.players[7]; m.place(c, 0, 0); c.fx = 0; c.fy = 1; c.vy = 4; m.ball.owner = c; m.ball.kick = null; m.ctrl[0] = c; m.att = 0;
  const o = m.players[16]; m.place(o, 1, -2.5); o.fx = 0; o.fy = 1;
  for (const q of m.players) if (q !== c && q !== o && q.team === 1 && Math.hypot(q.x, q.y) < 12) m.place(q, q.x + 15, q.y);
  window.__log = []; const orig = m.ev.bind(m); m.ev = (t, d) => { if (t.startsWith('flee') || t.startsWith('duel') || t === 'burst' || t === 'tackle') window.__log.push(t + (d.reason ? ':' + d.reason : '') + '@' + m.time.toFixed(2)); return orig(t, d); };
});
await p.waitForFunction(() => window.__G.match.fleeFor(0), { timeout: 4000 }).catch(() => {});
await wait(700);
const st = () => p.evaluate(() => { const m = window.__G.match, c = m.players[7], o = m.players[16]; return { fuga: m.fleeFor(0), duello: m.duelFor(0), tasto: getComputedStyle(document.getElementById('drib')).display, scritta: document.getElementById('drib').textContent, suggerimento: document.getElementById('hint').textContent, tempo: +window.__G.ts.toFixed(2), palla: m.ball.owner === c, y: +c.y.toFixed(1), x: +c.x.toFixed(1), distanza: +Math.hypot(o.x - c.x, o.y - c.y).toFixed(1) }; });
const durante = await st();
await snap('f1-fuga');
await p.evaluate(() => document.getElementById('drib').click());
await wait(1200);
const dopo = await st();
await snap('f2-dopo-scatto');
console.log(JSON.stringify({ durante, dopo, log: await p.evaluate(() => window.__log) }, null, 1));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
