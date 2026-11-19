// Giro dei menu (Puppeteer, iPhone 390×844): titolo, squadra nuova (parte l'allenamento, lo si salta),
// come si gioca, hub, rosa, mercato, classifica, partita di campionato.
import { b, p, wait, snap, errs } from './shot.mjs';
await wait(2500); await snap('01-title');
await p.evaluate(() => document.querySelector('[data-a=create]')?.click()); // poi editor dello stemma (Avanti) e del campione (Conferma)
await wait(400); await p.evaluate(() => document.querySelector('[data-a=edok]').click());
await wait(600); await p.evaluate(() => document.querySelector('[data-a=edok]').click());
await p.waitForFunction(() => window.__G.tut && window.__G.tut.card, { timeout: 10000 });
await wait(300); await snap('02-allenamento');
await p.evaluate(() => document.querySelector('[data-o=tutskip]').click());
await wait(400); await snap('03-hub');
await p.evaluate(() => window.__ui.show('howto', 0)); await wait(200); await snap('03b-howto');
await p.evaluate(() => window.__ui.show('squad')); await wait(200); await snap('04-squad');
await p.evaluate(() => window.__ui.show('market')); await wait(200); await snap('05-market');
await p.evaluate(() => window.__ui.show('table')); await wait(200); await snap('06-table');
await p.evaluate(() => window.__start('league')); await wait(3500); await snap('07-match-kickoff');
console.log(errs.join('\n') || 'nessun errore');
await b.close();
