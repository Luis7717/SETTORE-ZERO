// Prova a schermo del duello (Puppeteer, iPhone 390×844): portatore davanti a un difensore →
// telecamera bassa, tempo rallentato, tasto Dribbling. Il tasto prenota il dribbling (2026-11-21): il tasto sparisce,
// il portatore va verso il difensore e il giochetto parte solo vicino a lui (d3 = giochetto in corso accanto al difensore).
// Uso: node test/duel-shot.mjs shots
import { b, p, wait, snap, errs } from './shot.mjs';

await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__start('friendly', 50); });
await wait(2500);
await p.evaluate(() => {
  const m = window.__G.match; m.phase = 'play'; m.restart = null;
  const c = m.players[7]; m.place(c, 0, 5); c.fx = 0; c.fy = 1; m.ball.owner = c; m.ball.kick = null; m.ctrl[0] = c; m.att = 0;
  c.st.dri = 90; // dribbling alto: giochetto bello e quasi sempre riuscito
  const o = m.players[16]; m.place(o, 0.6, 11); o.fx = 0; o.fy = -1; o.st.dif = 30;
  window.__G.match.userMove(0, 0, 12, true);
  window.__log = []; const orig = m.ev.bind(m);
  m.ev = (t, d) => {
    if (t.startsWith('duel') || t.startsWith('dribble') || t === 'tackle') {
      const dist = d.p && d.o ? Math.hypot(d.p.x - d.o.x, d.p.y - d.o.y).toFixed(2) : '';
      window.__log.push(t + (d.reason ? ':' + d.reason : '') + (d.side ? ' lato ' + d.side : '') + (d.ok !== undefined ? ' ok=' + d.ok : '') + (dist ? ' a ' + dist + ' m' : '') + ' @' + m.time.toFixed(2));
      if (t === 'dribble') window.__dribT = performance.now();
    }
    return orig(t, d);
  };
});
await p.waitForFunction(() => window.__G.match.duelFor(0), { timeout: 4000 }).catch(() => {});
await wait(700);
const state = () => p.evaluate(() => {
  const m = window.__G.match, c = m.players[7], o = m.players[16];
  return { duello: m.duelFor(0), prenotato: !!(m.dribBooked && m.dribBooked(0)), tasto: getComputedStyle(document.getElementById('drib')).display, tempo: +window.__G.ts.toFixed(2), distanza: +Math.hypot(c.x - o.x, c.y - o.y).toFixed(2) };
});
const during = await state();
await snap('d1-duello');
await p.evaluate(() => document.getElementById('drib').click());
await wait(150);
const booked = await state();
await snap('d2-prenotato');
// giochetto: schermata 0,35 s veri dopo che il dribbling è partito
await p.waitForFunction(() => window.__dribT, { timeout: 5000 }).catch(() => {});
await p.waitForFunction(() => performance.now() - window.__dribT > 350, { timeout: 3000 }).catch(() => {});
const trick = await p.evaluate(() => { const m = window.__G.match, c = m.players[7], o = m.players[16]; return { giochetto: window.__view.trickOf(c), distanza: +Math.hypot(c.x - o.x, c.y - o.y).toFixed(2) }; });
await snap('d3-giochetto');
await wait(1200);
await snap('d4-dopo');
console.log(JSON.stringify({ durante: during, dopoIlTocco: booked, giochetto: trick, log: await p.evaluate(() => window.__log) }, null, 1));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
