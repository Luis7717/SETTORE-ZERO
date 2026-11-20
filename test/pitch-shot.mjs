// Prova a schermo di campo, luci e ombre con i giocatori 3D veri (Puppeteer, iPhone 390×844).
// Uso: npm run build && node test/pitch-shot.mjs shots [prefisso]
import { mkdirSync } from 'node:fs';
import { b, p, wait, snap, errs } from './shot.mjs';
const pre = process.argv[3] || '';
mkdirSync(process.argv[2] || 'shots', { recursive: true });
await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__career.s.settings.half = 90; window.__enter('friendly', 50); });
await p.waitForFunction(() => window.__view.p3d && window.__G.match, { timeout: 20000 });
await wait(2500); await snap(pre + 'p1-calcio-di-inizio');
const attack = (x, y) => p.evaluate((x, y) => {
  const m = window.__G.match; m.phase = 'play'; m.restart = null;
  const c = m.players[9]; c.x = x; c.y = y; c.vx = c.vy = 0; c.fx = 0; c.fy = 1; m.ball.owner = c; m.ball.kick = null; m.ctrl[0] = c;
}, x, y);
await attack(-12, 30); await wait(1500); await snap(pre + 'p2-attacco-vicino-porta');
await attack(20, -5); await wait(1500); await snap(pre + 'p3-fascia');
// da vicino: telecamera bassa accanto a un giocatore (erba da vicino, ombra netta)
await p.evaluate(() => {
  const v = window.__view, m = window.__G.match, c = m.players[9]; window.__G.paused = true; v.update(0.016);
  v.update = () => {}; v.cam.position.set(c.x + 3, 2.2, -c.y + 5); v.cam.lookAt(c.x, 0.8, -c.y); v.render();
});
await wait(300); await snap(pre + 'p4-da-vicino');
await p.evaluate(() => { const v = window.__view; v.cam.position.set(-20, 40, 60); v.cam.lookAt(0, 0, -25); v.render(); });
await wait(300); await snap(pre + 'p5-larga');
console.log(errs.join('\n') || 'nessun errore');
await b.close();
