// Inquadrature ravvicinate dello stadio (Puppeteer, 390×844): tribuna vicina, cartelloni, curva, maxischermo,
// settore ospiti, ola, gol. Uso: npm run build && DSF=2 node test/stadium-close-shot.mjs shots [prefisso]
import { b, p, wait, snap } from './shot.mjs';
await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__start('friendly', 50); });
await p.waitForFunction(() => window.__view && window.__view.stadium, { timeout: 15000 });
await wait(2000);
const pre = process.argv[3] || '';
await p.evaluate(() => { const v = window.__view; window.__G.paused = true; v.update = () => {}; });
const cam = async (n, pos, look) => { await p.evaluate((pos, look) => { const v = window.__view; v.cam.position.set(...pos); v.cam.lookAt(...look); v.stadium.update(0.016, window.__G.match.phase === 'goal' ? 1 : 0, window.__G.match); v.render(); }, pos, look); await wait(200); await snap(pre + n); };
await cam('c1-tribuna-vicina', [20, 4, -30], [50, 8, -30]);
await cam('c2-cartelloni', [0, 2, -40], [-36, 1, -55]);
await cam('c3-curva', [0, 6, -30], [0, 10, -70]);
await cam('c7-schermo', [0, 28, -55], [0, 28, -95]);
await cam('c4-ospiti', [-10, 10, -30], [-50, 14, -55]);
// ola e gol: forzati a mano
await p.evaluate(() => { const v = window.__view; v.stadium.update(40, 0); for (let i = 0; i < 24; i++) v.stadium.update(0.1, 0); v.cam.position.set(-20, 40, 60); v.cam.lookAt(0, 0, -25); v.render(); });
await wait(200); await snap(pre + 'c6-ola');
await p.evaluate(() => { const v = window.__view, m = window.__G.match; m.score[0] = 1; m.phase = 'goal'; for (let i = 0; i < 30; i++) v.stadium.update(0.05, 1, m); v.cam.position.set(0, 6, -30); v.cam.lookAt(0, 10, -70); v.render(); });
await wait(200); await snap(pre + 'c5-gol');
await cam('c8-schermo-gol', [0, 28, -55], [0, 28, -95]);
await b.close();
