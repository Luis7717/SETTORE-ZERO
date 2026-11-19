// Prova a schermo dell'allenamento guidato (Puppeteer, iPhone 390×844): creando la squadra parte l'allenamento,
// compare la scheda della prima meccanica; "Prova" la chiude e un passaggio vero conta come prima riuscita.
import { b, p, wait, snap, errs } from './shot.mjs';

await wait(1200);
await p.evaluate(() => { document.querySelector('[data-a=create]').click(); }); // poi editor dello stemma (Avanti) e del campione (Conferma)
await wait(400); await p.evaluate(() => document.querySelector('[data-a=edok]').click());
await wait(600); await p.evaluate(() => document.querySelector('[data-a=edok]').click());
await p.waitForFunction(() => window.__G.state === 'match' && window.__G.tut && window.__G.tut.card, { timeout: 10000 });
await wait(600);
await snap('t1-scheda-passaggio');
const scheda = await p.evaluate(() => document.getElementById('ov').innerText.replace(/\s+/g, ' ').slice(0, 120));
await p.evaluate(() => document.querySelector('[data-o=tutgo]').click());
await wait(800);
await snap('t2-prova-1');
const prima = await p.evaluate(() => document.getElementById('tut').innerText.replace(/\s+/g, ' '));
await p.evaluate(() => { const m = window.__G.match, q = m.players[9]; m.userKick(0, { type: 'auto', tx: q.x, ty: q.y, curve: 0 }); });
await wait(5000);
const dopo = await p.evaluate(() => ({ prova: window.__G.tut.k, riquadro: document.getElementById('tut').innerText.replace(/\s+/g, ' ') }));
await snap('t3-prova-2');
console.log(JSON.stringify({ scheda, prima, dopo }));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
