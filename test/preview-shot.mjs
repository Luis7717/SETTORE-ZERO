// Prova a schermo (Puppeteer, iPhone 390×844): mentre si disegna un passaggio compaiono
// l'anteprima della traiettoria vera e la linea del fuorigioco. Uso: node test/preview-shot.mjs shots
import { b, p, wait, snap, errs } from './shot.mjs';

const lerp = (a, c, n) => Array.from({ length: n }, (_, i) => [a[0] + (c[0] - a[0]) * (i + 1) / n, a[1] + (c[1] - a[1]) * (i + 1) / n]);
const scr = (x, y, h) => p.evaluate((x, y, h) => window.__view.worldToScreen(x, y, h), x, y, h);

await wait(1200);
await p.evaluate(() => { document.querySelector('[data-a=create]').click(); window.__ui.show('hub'); window.__career.s.settings.half = 90; window.__start('friendly', 50); });
await wait(1500);
// portatore a centrocampo, difesa avversaria alta: la linea del fuorigioco cade nel campo visibile
await p.evaluate(() => {
  const m = window.__G.match; m.phase = 'play'; m.restart = null;
  const c = m.players[7]; c.x = -2; c.y = 5; c.vx = c.vy = 0; c.fx = 0; c.fy = 1; m.ball.owner = c; m.ball.kick = null; m.ctrl[0] = c;
  for (const q of m.players) if (q.team === 1 && q.pos !== 'P') q.y = Math.min(Math.max(q.y, 14), 24);
});
await wait(600);
const bs = await p.evaluate(() => { const m = window.__G.match; return window.__view.worldToScreen(m.ball.x, m.ball.y, 0.3); });
await p.touchscreen.touchStart(bs.x, bs.y); await wait(80);
// linea curva verso destra e in avanti (passaggio a giro)
const end = await scr(12, 26, 0), mid = [(bs.x + end.x) / 2 + 60, (bs.y + end.y) / 2];
for (const q of lerp([bs.x, bs.y], mid, 8)) { await p.touchscreen.touchMove(q[0], q[1]); await wait(25); }
for (const q of lerp(mid, [end.x, end.y], 8)) { await p.touchscreen.touchMove(q[0], q[1]); await wait(25); }
await wait(250);
const state = await p.evaluate(() => { const v = window.__view; return { anteprima: v.preview.visible, punti: v.preview.geometry.drawRange.count, fuorigioco: v.offside.visible, lineaY: +(-v.offside.position.z * v.flip).toFixed(1), attesa: +window.__G.match.offsideY(0).toFixed(1) }; });
await snap('p1-anteprima-e-fuorigioco');
await p.touchscreen.touchEnd();
await wait(300);
const after = await p.evaluate(() => ({ anteprima: window.__view.preview.visible, fuorigioco: window.__view.offside.visible }));
await snap('p2-dopo-il-passaggio');
console.log('durante il disegno', JSON.stringify(state));
console.log('dopo il rilascio', JSON.stringify(after));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
