// Prova a schermo dei comandi nuovi (Puppeteer, iPhone 390×844, tocchi veri):
// 1) fuori dal duello la linea disegnata dal giocatore è una strada da correre (niente passaggio);
// 2) sul tiro avversario la visuale va dietro la porta e la linea dal portiere fa partire il tuffo.
import { b, p, wait, snap, errs } from './shot.mjs';

const lerp = (a, c, n) => Array.from({ length: n }, (_, i) => [a[0] + (c[0] - a[0]) * (i + 1) / n, a[1] + (c[1] - a[1]) * (i + 1) / n]);
const scr = (x, y, h) => p.evaluate((x, y, h) => window.__view.worldToScreen(x, y, h), x, y, h);
const res = {};

await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__career.s.settings.half = 90; window.__start('friendly', 50); });
await wait(2500);
// 1) strada da correre
await p.evaluate(() => {
  const m = window.__G.match; m.phase = 'play'; m.restart = null;
  const c = m.players[7]; m.place(c, 0, -10); c.fx = 0; c.fy = 1; m.ball.owner = c; m.ball.kick = null; m.ctrl[0] = c; m.att = 0;
  for (const o of m.team(1)) if (o.pos !== 'P') m.place(o, -28 + o.i * 2, 30);
});
await wait(500);
const bs = await p.evaluate(() => { const m = window.__G.match; return window.__view.worldToScreen(m.ball.x, m.ball.y, 0.3); });
await p.touchscreen.touchStart(bs.x, bs.y); await wait(60);
const mid = await scr(4, -2, 0), end = await scr(12, 4, 0);
for (const q of lerp([bs.x, bs.y], [mid.x, mid.y], 8)) { await p.touchscreen.touchMove(q[0], q[1]); await wait(25); }
for (const q of lerp([mid.x, mid.y], [end.x, end.y], 8)) { await p.touchscreen.touchMove(q[0], q[1]); await wait(25); }
await snap('c1-strada-disegnata');
res.durante = await p.evaluate(() => ({ anteprimaPassaggio: window.__view.preview.visible, linea: window.__view.path.visible, tempo: +window.__G.ts.toFixed(2) }));
await p.evaluate(() => { const m = window.__G.match; window.__log = []; const o = m.ev.bind(m); m.ev = (t, d) => { window.__log.push(t + (d && d.kind ? ':' + d.kind : '') + (d && d.p ? '#' + d.p.i : '')); return o(t, d); }; });
await p.touchscreen.touchEnd();
await wait(200);
res.dopo = await p.evaluate(() => { const m = window.__G.match, mv = m.move[0]; return { strada: !!(mv && mv.path), punti: mv && mv.path ? mv.path.length : 0, palla: m.ball.owner === m.players[7] }; });
await wait(2500);
res.arrivo = await p.evaluate(() => { const c = window.__G.match.players[7]; return [+c.x.toFixed(1), +c.y.toFixed(1)]; });
await snap('c2-corsa');
// 2) parata con la linea dal portiere
await p.evaluate(() => {
  const m = window.__G.match; m.phase = 'play'; m.restart = null; m.move[0] = null;
  const o = m.players[20]; m.place(o, 3, -30); o.fx = 0; o.fy = -1; m.ball.owner = o; m.ball.kick = null; m.att = 1; o.aiT = 0.3;
  for (const q of m.team(0)) if (q.pos !== 'P') m.place(q, -28 + q.i * 2, 5);
  m.place(m.gk(0), 0, -49.4);
});
await p.waitForFunction(() => window.__G.match.diveWin(0), { timeout: 8000 }).catch(() => {});
await wait(350);
await snap('c3-parata-visuale');
res.parata = await p.evaluate(() => ({ finestra: window.__G.match.diveWin(0), tempo: +window.__G.ts.toFixed(2), camAltezza: +window.__view.cam.position.y.toFixed(1), camDietroPorta: window.__view.cam.position.z > 49 }));
const g = await p.evaluate(() => { const m = window.__G.match, k = m.gk(0); return window.__view.worldToScreen(k.x, k.y, 1); });
const tgt = await p.evaluate(() => { const s = window.__G.match.ball.shot; return s ? window.__view.worldToScreen(s.cx, -50, s.ch) : null; });
if (tgt) {
  await p.touchscreen.touchStart(g.x, g.y); await wait(30);
  for (const q of lerp([g.x, g.y], [tgt.x, tgt.y], 6)) { await p.touchscreen.touchMove(q[0], q[1]); await wait(15); }
  await snap('c4-linea-portiere');
  await p.touchscreen.touchEnd();
  await wait(150);
  res.tuffo = await p.evaluate(() => window.__G.match.gk(0).state);
}
await wait(1500);
// 3) difesa: linea disegnata da un proprio giocatore (tocco vero), che poi la segue
await p.evaluate(() => {
  const m = window.__G.match; m.phase = 'play'; m.restart = null; m.move[0] = null; m.runs = [[], []];
  const o = m.players[18]; m.place(o, 0, 12); o.fx = 0; o.fy = -1; m.ball.owner = o; m.ball.kick = null; m.att = 1; o.protect = 5;
  for (const q of m.team(1)) q.stun = 5;
  m.place(m.players[4], 4, 2); for (const q of m.team(0)) if (q.pos !== 'P' && q.i !== 4) m.place(q, -28 + q.i * 2, -20);
  window.__outs = []; const out = window.__input.out, f = out.run; out.run = (...a) => { window.__outs.push(a[0]); return f(...a); };
});
await wait(300);
{
  const st = await p.evaluate(() => { const q = window.__G.match.players[4]; return window.__view.worldToScreen(q.x, q.y, 0.9); });
  const en = await scr(-1, 8, 0);
  await p.touchscreen.touchStart(st.x, st.y); await wait(30);
  for (const q of lerp([st.x, st.y], [en.x, en.y], 8)) { await p.touchscreen.touchMove(q[0], q[1]); await wait(45); }
  await p.touchscreen.touchEnd(); await wait(150);
}
res.difesa = await p.evaluate(() => ({ chiamate: window.__outs, linee: window.__G.match.runs[0].map(r => r.p.i), aSchermo: window.__view.runLines.filter(l => l.visible).length }));
await snap('c5-linee-difesa');
res.log = await p.evaluate(() => window.__log.slice(0, 12));
console.log(JSON.stringify(res));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
