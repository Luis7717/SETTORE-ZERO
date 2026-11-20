// Foglio dei tagli di capelli (Puppeteer, anteprima dell'editor): tutti i 17 tagli, ognuno da tre lati
// (tre quarti davanti, profilo, tre quarti dietro), più una riga "piccola" come in campo.
// Uso: npm run build && node test/hair-shot.mjs shots [colore]      → shots/hair-sheet-1.png, hair-sheet-2.png
import { mkdirSync, writeFileSync } from 'node:fs';
import puppeteer from 'puppeteer-core';
import { serve } from './lib/serve.mjs';

const out = process.argv[2] || 'shots', color = +(process.argv[3] ?? 2);
mkdirSync(out, { recursive: true });
const b = await puppeteer.launch({ executablePath: process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: 'new', args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const p = await b.newPage();
await p.setViewport({ width: 390, height: 844, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
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
await tap('[data-a=edok]'); await wait(3500);
await tap('[data-a=edtab][data-v=hair]'); await wait(900);

const urls = await p.evaluate((color) => {
  const e = window.__ui.ed, v = e.view, N = 17, CW = 200, CH = 200, yaws = [0.55, 1.57, 2.6];
  const sheet = document.createElement('canvas'); sheet.width = CW * 4; sheet.height = CH * 9;
  const g = sheet.getContext('2d'); g.fillStyle = '#1b2033'; g.fillRect(0, 0, sheet.width, sheet.height);
  const tones = [0, 1, 3, 5];
  const urls = [];
  for (let h = 0; h < N; h++) {
    if (h === 9) { urls.push(sheet.toDataURL('image/png')); g.fillStyle = '#1b2033'; g.fillRect(0, 0, sheet.width, sheet.height); }
    const row = h % 9;
    e.d.look = { ...e.d.look, hair: h, hairColor: color, skin: tones[h % 4] + 1, beard: 0 };
    v.setPlayer(e.kitFor(), e.d.look, e.d.num, e.d.name);
    v.swing = false; v.drag = { x: 0, yaw: 0 };
    v.cur = { y: 2.12, z: 2.2, look: 2.04 };
    yaws.forEach((y, i) => { v.yaw = y; v.tick(0); g.drawImage(v.cv, 0, 0, v.cv.width, v.cv.height, i * CW, row * CH, CW, CH * v.cv.height / v.cv.width); });
    // piccolo, come in campo (testa di pochi pixel): corpo intero ridotto
    v.cur = { y: 1.35, z: 5.0, look: 1.2 }; v.yaw = 0.7; v.tick(0);
    g.imageSmoothingEnabled = true; g.drawImage(v.cv, 0, 0, v.cv.width, v.cv.height, 3 * CW + 60, row * CH + 20, 48, 48 * v.cv.height / v.cv.width);
    g.fillStyle = '#fff'; g.font = '14px sans-serif'; g.fillText(h + ' ' + (window.__hairNames ? window.__hairNames[h] : ''), 4, row * CH + 16);
  }
  urls.push(sheet.toDataURL('image/png')); return urls;
}, color);
urls.forEach((u, i) => writeFileSync(`${out}/hair-sheet-${i + 1}.png`, Buffer.from(u.split(',')[1], 'base64')));
console.log(errs.join('\n') || 'nessun errore');
await b.close(); srv.close();
