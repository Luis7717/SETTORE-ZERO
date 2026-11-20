// Prova a schermo della Rosa (Puppeteer, iPhone 390×844, servito via http come nell'app):
// tre formazioni, una carta scelta (pannello del giocatore), confronto con un giocatore della panchina,
// scambio campo↔panchina fatto, panchina scorsa, e la stessa schermata nello spazio tra le aree sicure (390×763).
// Controlla anche che la schermata non scorra e che le carte non si sovrappongano né escano dal campo.
// Uso: npm run build && node test/squad-shot.mjs shots
import { mkdirSync } from 'node:fs';
import puppeteer from 'puppeteer-core';
import { serve } from './lib/serve.mjs';

const out = process.argv[2] || 'shots';
mkdirSync(out, { recursive: true });
const b = await puppeteer.launch({ executablePath: process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: 'new', args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const p = await b.newPage();
await p.setViewport({ width: 390, height: 844, deviceScaleFactor: +(process.env.DSF || 2), isMobile: true, hasTouch: true });
const errs = [];
p.on('pageerror', e => errs.push('PAGEERR ' + e.message));
p.on('console', m => { if (m.type() === 'error' && !/404/.test(m.text())) errs.push('CONSOLE ' + m.text()); });
const srv = await serve('www');
await p.goto(srv.url + 'index.html');
const wait = ms => new Promise(r => setTimeout(r, ms));
const snap = async n => { await p.screenshot({ path: `${out}/rosa-${n}.png` }); };
const tap = async sel => { await p.evaluate(s => { const e = document.querySelector(s); if (!e) throw new Error('manca ' + s); e.click(); }, sel); await wait(350); };

// misure: niente scorrimento, carte dentro il campo e senza sovrapposizioni, larghezza delle carte
const check = async label => {
  const r = await p.evaluate(() => {
    const scr = document.querySelector('#ui .scr'), f = document.querySelector('#ui .field'), fr = f.getBoundingClientRect();
    const cards = [...f.querySelectorAll('.fc')].map(e => e.getBoundingClientRect());
    let over = 0, outside = 0;
    for (let i = 0; i < cards.length; i++) {
      const a = cards[i];
      if (a.left < fr.left - 0.5 || a.right > fr.right + 0.5 || a.top < fr.top - 0.5 || a.bottom > fr.bottom + 0.5) outside++;
      for (let j = i + 1; j < cards.length; j++) { const c = cards[j]; if (a.left < c.right - 0.5 && c.left < a.right - 0.5 && a.top < c.bottom - 0.5 && c.top < a.bottom - 0.5) over++; }
    }
    const bench = [...document.querySelectorAll('#ui .brow .fc')].map(e => e.getBoundingClientRect());
    return { scrolls: scr.scrollHeight > scr.clientHeight + 1, pageW: document.documentElement.scrollWidth, field: [Math.round(fr.width), Math.round(fr.height)], cards: cards.length, cardW: Math.round(cards[0].width), over, outside, benchCards: bench.length, benchBottom: Math.round(Math.max(...bench.map(x => x.bottom))), vh: innerHeight };
  });
  console.log(label, JSON.stringify(r));
  if (r.scrolls || r.over || r.outside || r.cards !== 11 || r.pageW > 390 || r.benchBottom > r.vh) errs.push('MISURE ' + label + ' ' + JSON.stringify(r));
};

await wait(1200);
await p.evaluate(() => { localStorage.clear(); window.__newCareer('FC Prova'); });
await wait(500);
// un giocatore della panchina con un aspetto particolare (capelli afro e barba) per vedere il ritratto
await p.evaluate(() => { const s = window.__career.s, bench = window.__career.bench(); bench[0].look = { skin: 6, hair: 9, hairColor: 0, eyes: 0, eyeColor: 0, brows: 2, beard: 5, boots: 0 }; });
await p.evaluate(() => window.__ui.act('go', 'squad')); await wait(700);
await snap('1-442'); await check('4-4-2');
await tap('[data-a=form][data-v="3-5-2"]'); await snap('2-352'); await check('3-5-2');
await tap('[data-a=form][data-v="4-2-3-1"]'); await snap('3-4231'); await check('4-2-3-1');
await tap('[data-a=form][data-v="4-3-3"]'); await snap('4-433'); await check('4-3-3');
// fuori ruolo: un difensore messo a centrocampo
await p.evaluate(() => { const c = window.__career, s = c.s; const d = s.lineup[1], m = s.lineup[5]; c.swap(d, m); window.__ui.redraw(); });
await wait(300); await snap('5-fuori-ruolo'); await check('fuori ruolo');
// carta scelta: pannello del giocatore (Aspetto, Vendi) e badge verdi/rossi sulle altre carte
const ids = await p.evaluate(() => { const c = window.__career, s = c.s; return { st: s.lineup[9], bench: c.bench().find(q => q.pos === 'A').id }; });
await tap(`.field [data-a=pl][data-v="${ids.st}"]`); await snap('6-scelto'); await check('scelto');
// confronto con un giocatore della panchina
await tap(`.brow [data-a=pl][data-v="${ids.bench}"]`); await snap('7-confronto'); await check('confronto');
// scambio fatto (tasto Scambia)
await tap('[data-a=swp]'); await wait(150); await snap('8-scambio-fatto');
const swapped = await p.evaluate((ids) => { const s = window.__career.s; return { inCampo: s.lineup.includes(ids.bench), fuori: !s.lineup.includes(ids.st), saved: JSON.parse(localStorage.getItem('tag_save_v1')).lineup.includes(ids.bench) }; }, ids);
console.log('scambio', JSON.stringify(swapped));
if (!swapped.inCampo || !swapped.fuori || !swapped.saved) errs.push('SCAMBIO non riuscito ' + JSON.stringify(swapped));
// panchina scorsa fino in fondo
await p.evaluate(() => { document.querySelector('.brow').scrollLeft = 9999; }); await wait(200); await snap('9-panchina-scorsa');
// portiere scelto (statistiche da portiere) e "Vendi" con conferma
await tap(`.field [data-a=pl][data-v="${await p.evaluate(() => window.__career.s.lineup[0])}"]`);
await tap('[data-a=sell]'); await snap('10-portiere-vendi');
await tap('[data-a=unsel]');
// "Aspetto" apre l'editor e torna alla Rosa
await tap(`.field [data-a=pl][data-v="${ids.bench}"]`);
await tap('[data-a=edlook]'); await wait(2500); await snap('11-aspetto');
await tap('[data-a=edok]'); await wait(800); await snap('12-ritorno'); await check('ritorno');
// lo spazio vero su iPhone: tolte le aree sicure in alto (47) e in basso (34)
await p.setViewport({ width: 390, height: 763, deviceScaleFactor: +(process.env.DSF || 2), isMobile: true, hasTouch: true });
await p.evaluate(() => { window.__ui.sel = null; window.__ui.tgt = null; window.__ui.just = null; window.__ui.act('form', '4-2-3-1'); }); await wait(400);
await snap('13-aree-sicure-4231'); await check('aree sicure 4-2-3-1');
await tap(`.field [data-a=pl][data-v="${await p.evaluate(() => window.__career.s.lineup[5])}"]`);
await tap(`.field [data-a=pl][data-v="${await p.evaluate(() => window.__career.s.lineup[2])}"]`);
await snap('14-aree-sicure-confronto'); await check('aree sicure confronto');

console.log(errs.join('\n') || 'nessun errore');
await b.close(); srv.close();
