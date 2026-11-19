import { b, p, wait, snap, errs } from './shot.mjs';
await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__career.s.settings.half = 90; window.__start('league'); });
await wait(1500);
const lerp = (a, c, n) => Array.from({ length: n }, (_, i) => [a[0] + (c[0] - a[0]) * (i + 1) / n, a[1] + (c[1] - a[1]) * (i + 1) / n]);
const fps = await p.evaluate(() => new Promise(r => { let n = 0; const t = performance.now(); const f = () => { n++; if (performance.now() - t > 2000) r(n / 2); else requestAnimationFrame(f); }; f(); }));
console.log('fps headless', fps);
// tuffi: 4 tiri, il test si tuffa dal lato giusto
let saved = 0;
for (let k = 0; k < 4; k++) {
  const side = k % 2 ? 1 : -1;
  await p.evaluate((side) => { const m = window.__G.match; m.phase = 'play'; m.restart = null; for (const q of m.players) { q.state = 'play'; q.stun = 0; if (q.team === 0 && q.pos !== 'P') q.y = Math.max(q.y, -10); } window.__view.cy = -32; const c = m.players[20]; c.x = 4; c.y = -32; const g = m.gk(0); g.x = 0; g.y = -49.2; m.ball.owner = c; m.ball.x = 4; m.ball.y = -32.6; window.__s0 = m.stats.saves[0]; window.__g0 = m.score[1]; }, side);
  await wait(700);
  await p.evaluate((side) => { const m = window.__G.match; const c = m.players[20]; m.phase = 'play'; m.restart = null; c.x = 4; c.y = -32; m.ball.owner = c; m.ball.x = 4; m.ball.y = -32.6; m.kick(c, { type: 'shot', tx: side * 2.7, ty: -50, th: 0.9, curve: 0 }); }, side);
  await wait(300); if (k === 0) await snap('d1-prompt');
  await p.touchscreen.touchStart(200, 560); await wait(20); for (const q of lerp([200, 560], [200 + side * 120, 556], 3)) { await p.touchscreen.touchMove(q[0], q[1]); await wait(10); } await p.touchscreen.touchEnd();
  await wait(700); if (k === 0) await snap('d2-dive');
  await wait(2500);
  const r = await p.evaluate(() => { const m = window.__G.match; return { sv: m.stats.saves[0] - window.__s0, gl: m.score[1] - window.__g0, ph: m.phase }; });
  console.log('tiro', k, 'lato', side, JSON.stringify(r)); if (r.sv) saved++;
  await wait(3500);
}
console.log('parate', saved, '/ 4');
// fine partita accelerata
await p.evaluate(() => { window.__G.speed = 10; window.__G.match.t = 88; });
for (let i = 0; i < 40; i++) { await wait(500); const st = await p.evaluate(() => ({ s: window.__G.state, ph: window.__G.match && window.__G.match.phase, scr: window.__ui.screen })); if (st.ph === 'half') { await snap('d3-half'); await p.evaluate(() => { document.querySelector('[data-o=second]').click(); window.__G.match.t = 80; }); } if (st.scr === 'post') break; }
await wait(400); await snap('d4-post');
await p.evaluate(() => document.querySelector('[data-a=continue],[data-a=season]').click()); await wait(300); await snap('d5-hub');
await p.evaluate(() => window.__ui.show('table')); await wait(200); await snap('d6-table');
await p.evaluate(() => window.__ui.show('market')); await wait(200);
await p.evaluate(() => document.querySelector('[data-a=mrow]').click()); await wait(200); await snap('d7-market');
await p.evaluate(() => window.__ui.show('calendar')); await wait(200); await snap('d8-cal');
// stagione intera simulata
const season = await p.evaluate(() => { const c = window.__career; let r; while (c.s.day < 18 && c.s.season === 1) r = c.finishMatch(2, 1, []); return { r: r.season, money: c.s.money, div: c.div(), season: c.s.season, sq: c.s.squad.length }; });
console.log('fine stagione', JSON.stringify(season));
await p.evaluate(() => window.__ui.show('season', window.__career.s.history.length ? { pos: 1, prize: 100, bonus: 200, outcome: 'up', div: 2, newDiv: 1 } : null)); await wait(200); await snap('d9-season');
console.log(errs.join('\n') || 'nessun errore');
await b.close();
