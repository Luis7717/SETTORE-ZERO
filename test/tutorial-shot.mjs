// Prova a schermo dell'allenamento guidato (Puppeteer, iPhone 390×844): dall'ultima pagina di "Come si gioca"
// si entra in campo, compare il riquadro della prova; un passaggio vero fa avanzare alla prova del tiro.
import { b, p, wait, snap, errs } from './shot.mjs';

await wait(1200);
await p.evaluate(() => { document.querySelector('[data-a=create]').click(); });
await wait(300);
await p.evaluate(() => window.__ui.show('howto', 4));
await wait(300);
await snap('t0-come-si-gioca-ultima');
await p.evaluate(() => document.querySelector('[data-a=tutorial]').click());
await p.waitForFunction(() => window.__G.state === 'match' && window.__G.tut, { timeout: 10000 });
await wait(1500);
const a = await p.evaluate(() => ({ prova: window.__G.tut.i, riquadro: document.getElementById('tut').innerText }));
await snap('t1-prova-passaggio');
await p.evaluate(() => { const m = window.__G.match, q = m.players[9]; m.userKick(0, { type: 'auto', tx: q.x, ty: q.y, curve: 0 }); });
await wait(4000);
const c = await p.evaluate(() => ({ prova: window.__G.tut.i, riquadro: document.getElementById('tut').innerText }));
await snap('t2-prova-tiro');
console.log(JSON.stringify({ prima: a, dopo: c }));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
