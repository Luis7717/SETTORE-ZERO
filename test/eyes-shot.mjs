// Prova a schermo delle 6 forme degli occhi nell'editor del campione (Puppeteer, iPhone 390×844, servito via http):
// per due pelli (chiara e scura) fotografa il primo piano del viso dell'editor e il corpo intero, poi mette i ritagli
// in tre fogli di confronto (eyes-viso.png, eyes-occhi.png da vicino, eyes-corpo.png) con il nome della forma sotto ogni riquadro.
// Uso: npm run build && node test/eyes-shot.mjs shots
import { mkdirSync, writeFileSync } from 'node:fs';
import puppeteer from 'puppeteer-core';
import { serve } from './lib/serve.mjs';
import { EYE_SHAPES, SKINS } from '../src/looks.js';

const out = process.argv[2] || 'shots';
mkdirSync(out, { recursive: true });
const SKIN_IDS = [1, 6];                 // pelle chiara e pelle scura
const CLIP_FACE = { x: 95, y: 215, width: 200, height: 110 }; // ritaglio del viso (px CSS) nel primo piano
const CLIP_EYES = { x: 150, y: 258, width: 110, height: 40 }; // ritaglio stretto sugli occhi nel primo piano
const CLIP_BODY = { x: 165, y: 108, width: 60, height: 50 }; // ritaglio della testa nel corpo intero
const b = await puppeteer.launch({ executablePath: process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: 'new', args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const p = await b.newPage();
await p.setViewport({ width: 390, height: 844, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
const errs = [];
p.on('pageerror', e => errs.push('PAGEERR ' + e.message));
p.on('console', m => { if (m.type() === 'error' && !/404/.test(m.text())) errs.push('CONSOLE ' + m.text()); });
const srv = await serve('www');
await p.goto(srv.url + 'index.html');
const wait = ms => new Promise(r => setTimeout(r, ms));
const tap = async sel => { await p.evaluate(s => { const e = document.querySelector(s); if (!e) throw new Error('manca ' + s); e.click(); }, sel); await wait(250); };

await wait(1200);
await p.evaluate(() => { localStorage.clear(); window.__career.s = null; window.__ui.show('title', 'new'); });
await wait(400);
await p.evaluate(() => { document.querySelector('#club').value = 'Aurora Valdoro'; });
await tap('[data-a=create]'); await wait(500);
await tap('[data-a=edok]'); await wait(3500); // stemma confermato: editor del campione, scheda Viso

const shots = { viso: [], occhi: [], corpo: [] };
for (const skin of SKIN_IDS) for (let eyes = 0; eyes < EYE_SHAPES.length; eyes++) {
  const look = { skin, hair: 4, hairColor: 1, eyes, eyeColor: 1, brows: 0, beard: 0, boots: 2 };
  // primo piano dell'editor (inquadratura della scheda Viso), quasi di fronte e fermo
  await p.evaluate((look) => { const e = window.__ui.ed; e.d.look = look; e.tab = 'face'; e.refresh(true); e.view.swing = false; e.view.yaw = 0.12; }, look);
  await wait(700); await p.evaluate(() => { window.__ui.ed.view.yaw = 0.12; }); await wait(150);
  if (eyes === 0 && skin === SKIN_IDS[0]) await p.screenshot({ path: `${out}/eyes-primo-piano.png` });
  shots.viso.push({ name: `${EYE_SHAPES[eyes]} · ${SKINS[skin][0]}`, img: await p.screenshot({ clip: CLIP_FACE, encoding: 'base64' }) });
  shots.occhi.push({ name: `${EYE_SHAPES[eyes]} · ${SKINS[skin][0]}`, img: await p.screenshot({ clip: CLIP_EYES, encoding: 'base64' }) });
  // corpo intero (inquadratura della scheda Divisa)
  await p.evaluate(() => { const e = window.__ui.ed; e.tab = 'kit'; e.refresh(true); e.view.swing = false; e.view.yaw = 0.12; });
  await wait(700); await p.evaluate(() => { window.__ui.ed.view.yaw = 0.12; }); await wait(150);
  if (eyes === 0 && skin === SKIN_IDS[0]) await p.screenshot({ path: `${out}/eyes-corpo-intero.png` });
  shots.corpo.push({ name: `${EYE_SHAPES[eyes]} · ${SKINS[skin][0]}`, img: await p.screenshot({ clip: CLIP_BODY, encoding: 'base64' }) });
}

// fogli di confronto: 6 colonne (forme) × 2 righe (pelli)
async function sheet(list, clip, file, zoom) {
  const q = await b.newPage();
  const w = clip.width * zoom, cell = l => `<figure><img src="data:image/png;base64,${l.img}" width="${w}"><figcaption>${l.name}</figcaption></figure>`;
  await q.setViewport({ width: w * 6 + 70, height: (clip.height * zoom + 40) * 2 + 20, deviceScaleFactor: 1 });
  await q.setContent(`<style>body{margin:10px;background:#111;color:#eee;font:15px sans-serif;display:grid;grid-template-columns:repeat(6,${w}px);gap:10px}figure{margin:0}img{display:block}</style>${list.map(cell).join('')}`);
  await q.screenshot({ path: `${out}/${file}`, fullPage: true });
  await q.close();
}
await sheet(shots.viso, CLIP_FACE, 'eyes-viso.png', 2);
await sheet(shots.occhi, CLIP_EYES, 'eyes-occhi.png', 4);
await sheet(shots.corpo, CLIP_BODY, 'eyes-corpo.png', 4);
writeFileSync(`${out}/eyes-errori.txt`, errs.join('\n') || 'nessun errore');
console.log(errs.join('\n') || 'nessun errore');
await b.close(); srv.close();
