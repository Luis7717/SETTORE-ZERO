// Prova a schermo dell'editor (Puppeteer, iPhone 390×844, servito via http come nell'app):
// creazione squadra → editor dello stemma (tre schede) → editor del campione (quattro schede) → 5 campioni diversi
// (viso da vicino e corpo intero, davanti e dietro) → conferma → Rosa con il pulsante Aspetto → Impostazioni.
// Uso: npm run build && node test/editor-shot.mjs shots
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
const snap = async n => { await p.screenshot({ path: `${out}/ed-${n}.png` }); };
const tap = async sel => { await p.evaluate(s => { const e = document.querySelector(s); if (!e) throw new Error('manca ' + s); e.click(); }, sel); await wait(250); };

await wait(1200);
await p.evaluate(() => { localStorage.clear(); window.__career.s = null; window.__ui.show('title', 'new'); });
await wait(400);
await p.type('#club', 'Aurora Valdoro');
await tap('[data-a=kit][data-v="7"]');
await p.evaluate(() => { document.querySelector('#club').value = 'Aurora Valdoro'; });
await tap('[data-a=create]'); await wait(500);
await snap('1-stemma-forma');
await tap('[data-a=edset][data-v="crest.shape:5"]');
await tap('[data-a=edtab][data-v=pattern]'); await tap('[data-a=edset][data-v="crest.pattern:1"]'); await snap('2-stemma-motivo');
await tap('[data-a=edtab][data-v=icon]'); await tap('[data-a=edset][data-v="crest.icon:2"]'); await snap('3-stemma-simbolo');
await tap('[data-a=edok]'); await wait(3500);
await snap('4-campione-viso');
await tap('[data-a=edtab][data-v=hair]'); await wait(900); await snap('5-campione-capelli');
await tap('[data-a=edtab][data-v=kit]'); await wait(900); await snap('6-campione-divisa');
await p.evaluate(() => { document.querySelector('.scr').scrollTop = 9999; }); await wait(300); await snap('6b-campione-divisa-giu');
await tap('[data-a=edtab][data-v=me]'); await wait(600); await snap('7-campione-nome-ruolo');

// 5 combinazioni: viso da vicino e corpo davanti / dietro
const combos = [
  { look: { skin: 1, hair: 4, hairColor: 5, eyes: 1, eyeColor: 4, brows: 0, beard: 0, boots: 2 }, style: { fit: 0, sleeves: 0, collar: 0, pattern: 1, shorts: 0, socks: 0 } },
  { look: { skin: 6, hair: 9, hairColor: 0, eyes: 3, eyeColor: 0, brows: 2, beard: 5, boots: 1 }, style: { fit: 1, sleeves: 1, collar: 2, pattern: 0, shorts: 1, socks: 2 } },
  { look: { skin: 3, hair: 11, hairColor: 7, eyes: 0, eyeColor: 3, brows: 3, beard: 0, boots: 4 }, style: { fit: 0, sleeves: 2, collar: 1, pattern: 3, shorts: 0, socks: 1 } },
  { look: { skin: 0, hair: 6, hairColor: 1, eyes: 5, eyeColor: 5, brows: 5, beard: 4, boots: 3 }, style: { fit: 1, sleeves: 0, collar: 0, pattern: 2, shorts: 0, socks: 0 } },
  { look: { skin: 4, hair: 12, hairColor: 2, eyes: 4, eyeColor: 6, brows: 4, beard: 6, boots: 5 }, style: { fit: 0, sleeves: 1, collar: 2, pattern: 4, shorts: 1, socks: 2 } },
];
for (const [i, c] of combos.entries()) {
  await p.evaluate((c) => { const e = window.__ui.ed; e.d.look = c.look; e.d.style = c.style; e.tab = 'face'; e.refresh(true); e.view.yaw = 0; const hy = e.view.p3d && e.view.p3d.headY; e.view.frame(hy ? { y: hy * 1.25 + 0.03, z: 1.25, look: hy * 1.25 - 0.03 } : { y: 1.82, z: 1.75, look: 1.78 }, true); }, c); // inquadratura sulla testa del modello in uso
  await wait(500); await p.evaluate(() => { window.__ui.ed.view.yaw = 0.25; }); await snap(`8-combo${i + 1}-viso`);
  await p.evaluate(() => { const e = window.__ui.ed; e.tab = 'kit'; e.refresh(true); e.view.frame(e.view.p3d && e.view.p3d.headY ? { y: 1.1, z: 5.3, look: 1.08 } : { y: 1.05, z: 4.6, look: 1.0 }, true); e.view.yaw = 0.3; });
  await wait(300); await p.evaluate(() => { window.__ui.ed.view.yaw = 0.3; }); await snap(`8-combo${i + 1}-corpo`);
  await p.evaluate(() => { window.__ui.ed.view.yaw = Math.PI; }); await snap(`8-combo${i + 1}-dietro`);
}
// conferma: la carriera nasce col campione, poi parte l'allenamento
await p.evaluate(() => { const e = window.__ui.ed; e.d.name = 'Leo Bomber'; e.d.num = 10; e.d.pos = 'A'; });
await tap('[data-a=edok]'); await wait(3000);
const after = await p.evaluate(() => { const s = window.__career.s; const ch = s.squad.find(q => q.champ); return { state: window.__G.state, mode: window.__G.mode, champ: ch && { name: ch.name, num: ch.num, look: ch.look, pos: ch.pos }, inLineup: ch && s.lineup.includes(ch.id), crest: s.crest, kitStyle: s.kitStyle }; });
await snap('9-allenamento');
// Rosa: scheda del campione con "Aspetto", poi l'editor dell'aspetto; Impostazioni con divisa e stemma
await p.evaluate(() => { window.__G.tut = null; window.__G.state = 'menu'; window.__G.match = null; document.getElementById('hud').style.display = 'none'; window.__ui.show('hub'); });
await wait(500); await snap('10-hub');
await p.evaluate(() => { const s = window.__career.s; window.__ui.sel = s.squad.find(q => q.champ).id; window.__ui.show('squad'); }); await wait(400); await snap('11-rosa-scheda');
await tap('[data-a=edlook]'); await wait(2500); await snap('12-aspetto');
await tap('[data-a=edcancel]'); await p.evaluate(() => window.__ui.show('settings')); await wait(400); await snap('13-impostazioni');
await p.evaluate(() => window.__ui.show('table')); await wait(300); await snap('14-classifica');
await p.evaluate(() => window.__ui.show('calendar')); await wait(300); await snap('15-calendario');

console.log(JSON.stringify(after));
console.log(errs.join('\n') || 'nessun errore');
await b.close(); srv.close();
