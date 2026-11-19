// Prova a schermo dello stadio (Puppeteer, iPhone 390×844): inquadrature di gioco, una larga, il pubblico in festa,
// e i numeri di costo (draw call e triangoli dello stadio, ms di costruzione).
// Uso: npm run build && node test/stadium-shot.mjs shots
import { mkdirSync } from 'node:fs';
import { b, p, wait, snap, errs } from './shot.mjs';

mkdirSync(process.argv[2] || 'shots', { recursive: true });
await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__career.s.settings.half = 90; window.__start('friendly', 50); });
await wait(2500);
await snap('s1-calcio-di-inizio');

// azione vicino alla porta avversaria: la telecamera scende e la tribuna di fondo riempie lo schermo
const attack = (x, y) => p.evaluate((x, y) => {
  const m = window.__G.match; m.phase = 'play'; m.restart = null;
  const c = m.players[9]; c.x = x; c.y = y; c.vx = c.vy = 0; c.fx = 0; c.fy = 1; m.ball.owner = c; m.ball.kick = null; m.ctrl[0] = c;
}, x, y);
await attack(-12, 30); await wait(1500); await snap('s2-attacco-vicino-porta');
await attack(24, 0); await wait(1500); await snap('s3-fascia-destra');

// numeri: stadio acceso e spento nello stesso fotogramma (differenza = costo dello stadio)
const measure = () => p.evaluate(() => {
  const v = window.__view, info = v.r.info.render, root = v.stadium.root;
  v.render(); const all = { calls: info.calls, tri: info.triangles };
  root.visible = false; v.render(); const without = { calls: info.calls, tri: info.triangles }; root.visible = true; v.render();
  return { calls: all.calls - without.calls, tri: all.tri - without.tri, sceneCalls: all.calls, sceneTri: all.tri, buildMs: +v.stadium.buildMs.toFixed(1) };
});
const stats = await measure();

// pubblico in festa (excitement = 1)
await p.evaluate(() => { const v = window.__view, up = v.stadium.update; v.stadium.update = (dt) => up(dt, 1); });
await wait(1500); await snap('s4-pubblico-in-festa');

// inquadratura larga: telecamera alta dietro la porta, la tribuna alle spalle resta fuori
await p.evaluate(() => {
  const v = window.__view; window.__G.paused = true;
  v.update = () => {}; v.cam.position.set(-20, 40, 60); v.cam.lookAt(0, 0, -25); v.render();
});
await wait(300); await snap('s5-larga');
const wide = await measure();
await p.evaluate(() => { const v = window.__view; v.cam.position.set(0, 14, -20); v.cam.lookAt(-60, 12, -80); v.render(); });
await wait(300); await snap('s6-angolo-e-maxischermo');
await p.evaluate(() => { const v = window.__view; v.cam.position.set(0, 10, -40); v.cam.lookAt(0, 6, 75); v.render(); });
await wait(300); await snap('s7-tribuna-alle-spalle');

console.log(`costruzione dello stadio: ${stats.buildMs} ms`);
for (const [n, x] of [['inquadratura di gioco', stats], ['inquadratura larga', wide]])
  console.log(`${n}: stadio ${x.calls} draw call, ${x.tri} triangoli (scena intera ${x.sceneCalls} draw call, ${x.sceneTri} triangoli)`);
console.log(errs.join('\n') || 'nessun errore');
await b.close();
