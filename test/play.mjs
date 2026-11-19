import { b, p, wait, snap, errs } from './shot.mjs';
await wait(1500);
await p.evaluate(() => { document.querySelector('[data-a=create]').click(); window.__ui.show('hub'); window.__career.s.settings.half = 90; window.__start('friendly', 50); window.__G.speed = 3; });
await wait(2500);
const st = () => p.evaluate(() => {
  const G = window.__G, m = G.match, v = window.__view; if (!m) return null;
  const c = m.ctrl[0], bs = v.worldToScreen(m.ball.x, m.ball.y, 0.3);
  const mates = m.players.filter(q => q.team === 0 && q !== c && !q.off && q.pos !== 'P').map(q => { const s = v.worldToScreen(q.x, q.y, 0.5); return { x: s.x, y: s.y, wy: q.y, wx: q.x }; });
  const gl = v.worldToScreen(2.5, 50, 1.2);
  return { hint: m.hint(0), phase: m.phase, bs, mates, gl, by: m.ball.y, bx: m.ball.x, score: m.score.join('-'), min: m.minute(), cy: c ? c.y : 0, ts: G.ts, own: m.ball.owner ? m.ball.owner.team : -1, shot: m.ball.shot ? m.ball.shot.cx : null, gkx: m.gk(0).x, paused: G.paused, half: m.half };
});
const drag = async (x1, y1, pts, hold = 30) => {
  await p.touchscreen.touchStart(x1, y1); await wait(60);
  for (const [x, y] of pts) { await p.touchscreen.touchMove(x, y); await wait(hold); }
  await p.touchscreen.touchEnd();
};
const lerp = (a, c, n) => Array.from({ length: n }, (_, i) => [a[0] + (c[0] - a[0]) * (i + 1) / n, a[1] + (c[1] - a[1]) * (i + 1) / n]);
let shots = 0, n = 0, snaps = {};
const once = async (k) => { if (!snaps[k]) { snaps[k] = 1; await snap('p-' + k); } };
const t0 = Date.now();
while (Date.now() - t0 < +(process.env.DUR || 150000)) {
  const s = await st(); if (!s) break; n++;
  if (s.paused) { await p.evaluate(() => { const o = document.querySelector('[data-o=second]') || document.querySelector('[data-o=resume]'); o && o.click(); }); await once('half'); await wait(400); continue; }
  if (s.hint === 'attack' || s.hint === 'restart') {
    const inV = q => q.x > 10 && q.x < 380 && q.y > 120 && q.y < 800;
    if (s.by > 24 && s.hint === 'attack' && s.gl.y > 60) {
      // tiro a giro: curva verso l'esterno poi in porta
      const mid = [(s.bs.x + s.gl.x) / 2 + 40, (s.bs.y + s.gl.y) / 2];
      await p.touchscreen.touchStart(s.bs.x, s.bs.y); await wait(60); await p.touchscreen.touchMove(s.bs.x, s.bs.y - 8); await wait(500);
      { const z = await st(); s.bs = z.bs; s.gl = z.gl; mid[0] = (s.bs.x + s.gl.x) / 2 + 40; mid[1] = (s.bs.y + s.gl.y) / 2; }
      for (const q of lerp([s.bs.x, s.bs.y], mid, 6)) { await p.touchscreen.touchMove(q[0], q[1]); await wait(25); }
      for (const q of lerp(mid, [s.gl.x, s.gl.y], 6)) { await p.touchscreen.touchMove(q[0], q[1]); await wait(25); }
      await wait(150); await once('shot-draw'); await p.touchscreen.touchEnd(); shots++; await wait(500); await once('shot-fly'); await wait(600); await once('shot-after');
    } else {
      const fw = s.mates.filter(q => q.wy > s.by + 3 && inV(q)).sort((a, c) => c.wy - a.wy);
      const any = s.mates.filter(inV);
      const tgt = fw[Math.min(1, fw.length - 1)] || any[0] || s.mates[0];
      if (tgt && n % 3 !== 0) {
        await p.touchscreen.touchStart(s.bs.x, s.bs.y); await wait(60); await p.touchscreen.touchMove(s.bs.x, s.bs.y - 8); await wait(500);
        const z = await st(); const f2 = z.mates.filter(q => q.wy > z.by + 3 && inV(q)).sort((a, c) => c.wy - a.wy); const t2 = f2[Math.min(1, f2.length - 1)] || z.mates.filter(inV)[0] || tgt;
        for (const q of lerp([z.bs.x, z.bs.y], [t2.x, t2.y - 10], 8)) { await p.touchscreen.touchMove(q[0], q[1]); await wait(25); }
        await wait(200); await once('pass-draw'); await p.touchscreen.touchEnd(); await wait(350); await once('pass-fly');
      } else {
        // corre in avanti tenendo premuto
        await p.touchscreen.touchStart(195 + (Math.random() - 0.5) * 120, 300); await wait(700); await once('run'); await p.touchscreen.touchEnd();
      }
    }
  } else if (s.hint === 'dive') {
    await once('dive-prompt');
    const d = s.shot > s.gkx ? 1 : -1;
    await drag(195, 600, lerp([195, 600], [195 + d * 130, 590], 4), 12); await wait(250); await once('dive'); await wait(400);
  } else if (s.hint === 'defend') {
    await p.touchscreen.touchStart(s.bs.x, Math.min(820, Math.max(130, s.bs.y))); await wait(450); await once('defend');
    const s2 = await st(); if (s2 && s2.bs) await p.touchscreen.touchMove(s2.bs.x, Math.min(820, Math.max(130, s2.bs.y)));
    await wait(300); await p.touchscreen.touchEnd();
    if (n % 5 === 0) { const s3 = await st(); if (s3 && s3.hint === 'defend') { await drag(195, 500, lerp([195, 500], [195 + (s3.bs.x - 195) * 0.4, 500 + (s3.bs.y - 500) * 0.4 - 30], 3), 15); await wait(200); await once('slide'); } }
  } else await wait(200);
  if (s.phase === 'full') break;
}
const s = await st();
console.log('fine', s ? s.score + ' min ' + s.min + ' half ' + s.half : 'partita chiusa', 'tiri bot', shots);
await wait(2500); await snap('p-end');
console.log(errs.join('\n') || 'nessun errore');
await b.close();
