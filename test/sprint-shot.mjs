// Prova a schermo dello Scatto (Puppeteer, iPhone 390×844): portatore davanti a un difensore → duello col tasto
// Scatto (era Dribbling); toccandolo il portatore brucia il difensore e prosegue dritto.
import { b, p, wait, snap, errs } from './shot.mjs';

await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__start('friendly', 50); });
await wait(2500);
await p.evaluate(() => {
  const m = window.__G.match; m.phase = 'play'; m.restart = null;
  const c = m.players[7]; m.place(c, 0, 5); c.fx = 0; c.fy = 1; c.st.vel = 90; m.ball.owner = c; m.ball.kick = null; m.ctrl[0] = c; m.att = 0;
  const o = m.players[16]; m.place(o, 0.5, 9); o.fx = 0; o.fy = -1; o.st.dif = 20;
  m.sprintChance = () => 1; // per la foto: lo scatto riesce sempre
  m.userMove(0, 0, 12, true);
  window.__log = []; const orig = m.ev.bind(m); m.ev = (t, d) => { if (t.startsWith('duel') || t === 'dribble' || t === 'tackle') window.__log.push(t + (d.reason ? ':' + d.reason : '') + (t === 'dribble' ? ':' + (d.ok ? 'ok' : 'no') + (d.sprint ? ':scatto' : '') : '') + '@' + m.time.toFixed(2)); return orig(t, d); };
});
await p.waitForFunction(() => window.__G.match.duelFor(0), { timeout: 4000 }).catch(() => {});
await wait(700);
const st = () => p.evaluate(() => { const m = window.__G.match, c = m.players[7], o = m.players[16]; return { duello: m.duelFor(0), tasto: getComputedStyle(document.getElementById('drib')).display, scritta: document.getElementById('drib').textContent, suggerimento: document.getElementById('hint').textContent, tempo: +window.__G.ts.toFixed(2), palla: m.ball.owner === c, x: +c.x.toFixed(1), y: +c.y.toFixed(1), difensoreY: +o.y.toFixed(1) }; });
const durante = await st();
await snap('s1-duello-scatto');
await p.evaluate(() => document.getElementById('drib').click());
await wait(500); await snap('s2-scatto');
await wait(1000);
const dopo = await st();
await snap('s3-dopo-scatto');
console.log(JSON.stringify({ durante, dopo, log: await p.evaluate(() => window.__log) }, null, 1));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
