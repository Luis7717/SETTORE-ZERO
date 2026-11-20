// Prova a schermo del duello (Puppeteer, iPhone 390×844): portatore davanti a un difensore →
// telecamera bassa, anelli verdi sui compagni liberi, tempo rallentato, tasto Dribbling che funziona.
import { b, p, wait, snap, errs } from './shot.mjs';

await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__start('friendly', 50); });
await wait(2500);
await p.evaluate(() => {
  const m = window.__G.match; m.phase = 'play'; m.restart = null;
  const c = m.players[7]; m.place(c, 0, 5); c.fx = 0; c.fy = 1; m.ball.owner = c; m.ball.kick = null; m.ctrl[0] = c; m.att = 0;
  const o = m.players[16]; m.place(o, 0.5, 9); o.fx = 0; o.fy = -1;
  window.__G.match.userMove(0, 0, 12, true);
  window.__log = []; const orig = m.ev.bind(m); m.ev = (t, d) => { if (t.startsWith('duel') || t === 'tackle' || t === 'restart') window.__log.push(t + (d.reason ? ':' + d.reason : '') + '@' + m.time.toFixed(2)); return orig(t, d); };
});
await p.waitForFunction(() => window.__G.match.duelFor(0), { timeout: 4000 }).catch(() => {});
await wait(700);
const during = await p.evaluate(() => ({ stato: window.__G.state, pausa: window.__G.paused, tempoPartita: +window.__G.match.time.toFixed(2), fase: window.__G.match.phase, proprietario: window.__G.match.ball.owner && window.__G.match.ball.owner.i, duello: window.__G.match.duelFor(0), tasto: getComputedStyle(document.getElementById('drib')).display, tempo: +window.__G.ts.toFixed(2), camH: +window.__view.cam.position.y.toFixed(1) }));
await snap('d1-duello');
const ev = await p.evaluate(() => new Promise(res => { const m = window.__G.match; const seen = []; const orig = m.ev.bind(m); m.ev = (t, d) => { if (t === 'dribble') seen.push(d.ok); return orig(t, d); }; document.getElementById('drib').click(); setTimeout(() => res(seen), 1500); }));
await snap('d2-dopo-dribbling');
console.log(JSON.stringify({ durante: during, dribbling: ev, log: await p.evaluate(() => window.__log) }));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
