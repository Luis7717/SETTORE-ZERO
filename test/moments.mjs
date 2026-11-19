import { b, p, wait, snap, errs } from './shot.mjs';
await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__career.s.settings.half = 90; window.__start('friendly', 50); });
await wait(1500);
const lerp = (a, c, n) => Array.from({ length: n }, (_, i) => [a[0] + (c[0] - a[0]) * (i + 1) / n, a[1] + (c[1] - a[1]) * (i + 1) / n]);
const scr = (x, y, h) => p.evaluate((x, y, h) => window.__view.worldToScreen(x, y, h), x, y, h);
// 1) tiro a giro dal limite
await p.evaluate(() => { const m = window.__G.match; m.phase = 'play'; m.restart = null; const c = m.players[9]; c.x = -6; c.y = 27; c.vx = c.vy = 0; c.fx = 0; c.fy = 1; m.ball.owner = c; m.ball.kick = null; m.ctrl[0] = c; for (const q of m.players) if (q.team === 1 && q.pos !== 'P') { q.y = Math.min(q.y, 20); } window.__log = []; const ok = m.kick.bind(m); m.kick = (pl, sp) => { window.__log.push(JSON.stringify({ t: sp.type, tx: +sp.tx.toFixed(1), ty: +sp.ty.toFixed(1), th: +(sp.th || 0).toFixed(2), c: +(sp.curve || 0).toFixed(2), h: !!sp.human })); return ok(pl, sp); }; });
await wait(900);
let bs = await scr(-6, 27.6, 0.3);
await p.touchscreen.touchStart(bs.x, bs.y); await wait(80); await p.touchscreen.touchMove(bs.x, bs.y - 8); await wait(600);
bs = await p.evaluate(() => { const m = window.__G.match; return window.__view.worldToScreen(m.ball.x, m.ball.y, 0.3); });
const gl = await scr(2.9, 50, 1.9);
const mid = [(bs.x + gl.x) / 2 - 55, (bs.y + gl.y) / 2];
for (const q of lerp([bs.x, bs.y], mid, 7)) { await p.touchscreen.touchMove(q[0], q[1]); await wait(20); }
for (const q of lerp(mid, [gl.x, gl.y], 7)) { await p.touchscreen.touchMove(q[0], q[1]); await wait(20); }
await wait(250); await snap('m1-shot-draw'); await p.touchscreen.touchEnd();
await wait(700); await snap('m2-shot-fly'); await wait(1500); await snap('m3-shot-after');
console.log('calci:', await p.evaluate(() => window.__log.join(' | ')), 'punteggio', await p.evaluate(() => window.__G.match.score.join('-')));
// 2) tiro avversario e tuffo
await wait(4500);
await p.evaluate(() => { const m = window.__G.match; m.phase = 'play'; m.restart = null; const c = m.players[20]; c.x = 5; c.y = -30; c.fx = 0; c.fy = -1; m.ball.owner = c; m.ball.kick = null; for (const q of m.players) if (q.team === 0 && q.pos !== 'P') q.y = Math.max(q.y, -15); const g = m.gk(0); g.x = 0; g.y = -49.2; g.state = 'play'; window.__side = 0; });
await wait(600);
await p.evaluate(() => { const m = window.__G.match; const c = m.players[20]; m.phase = 'play'; m.restart = null; c.x = 5; c.y = -30; c.state = 'play'; c.stun = 0; const g = m.gk(0); g.x = 0; g.y = -49.2; g.state = 'play'; m.ball.owner = c; m.ball.x = 5; m.ball.y = -30.6; m.kick(c, { type: 'shot', tx: -2.6, ty: -50, th: 1.0, curve: 0 }); });
await wait(350); await snap('m4-dive-prompt');
const info = await p.evaluate(() => { const m = window.__G.match; return { win: m.diveWin(0), ts: window.__G.ts, cx: m.ball.shot && m.ball.shot.cx }; });
console.log('finestra tuffo', JSON.stringify(info));
await p.touchscreen.touchStart(200, 560); await wait(30); for (const q of lerp([200, 560], [200 - 110, 556], 4)) { await p.touchscreen.touchMove(q[0], q[1]); await wait(12); } await p.touchscreen.touchEnd();
await wait(500); await snap('m5-dive'); await wait(1200); await snap('m6-after-dive');
console.log('dopo tuffo', await p.evaluate(() => { const m = window.__G.match; return JSON.stringify({ score: m.score, saves: m.stats.saves, phase: m.phase, gk: m.gk(0).state }); }));
// 3) pausa e cambi
await p.evaluate(() => document.getElementById('pause').click()); await wait(300); await snap('m7-pause');
await p.evaluate(() => document.querySelector('[data-o=subs]').click()); await wait(200);
await p.evaluate(() => { document.querySelector('[data-o=sa][data-v="9"]').click(); }); await wait(100);
await p.evaluate(() => { document.querySelector('[data-o=sb]').click(); }); await wait(100); await snap('m8-subs');
await p.evaluate(() => { document.querySelector('[data-o=dosub]').click(); }); await wait(100);
await p.evaluate(() => { document.querySelector('[data-o=back]').click(); document.querySelector('[data-o=resume]').click(); });
// 4) fine partita
await p.evaluate(() => { window.__G.match.t = 89.5; }); await wait(2500);
await snap('m9-half'); await p.evaluate(() => document.querySelector('[data-o=second]')?.click()); await wait(800);
await p.evaluate(() => { window.__G.match.t = 89.5; }); await wait(5000); await snap('m10-post');
console.log(errs.join('\n') || 'nessun errore');
await b.close();
