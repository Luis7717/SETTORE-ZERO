// Tempi della creazione dei giocatori realistici (mappa dei texel, pittura, geometria). Uso: npm run build && node test/athlete-prof.mjs
import puppeteer from 'puppeteer-core';
import { serve } from './lib/serve.mjs';
const b = await puppeteer.launch({ executablePath: process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: 'new', args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const p = await b.newPage(); await p.setViewport({ width: 390, height: 844 });
p.on('pageerror', e => console.log('PAGEERR', e.message));
const srv = await serve('www'); await p.goto(srv.url + 'index.html');
await new Promise(r => setTimeout(r, 1200));
await p.evaluate(() => { window.__newCareer(); return window.__enter('friendly', 50); });
await new Promise(r => setTimeout(r, 2500));
const r = await p.evaluate(() => {
  const m = window.__view.p3d, kit = window.__G.match.teams[0].kit, out = {};
  const t = (n, f) => { const t0 = performance.now(); const x = f(); out[n] = +(performance.now() - t0).toFixed(1); return x; };
  m.maps.clear();
  t('texMap512', () => m.texMap(512)); t('detail512', () => m.detailAt(512));
  const look = { skin: 3, hair: 8, hairColor: 1, eyes: 2, eyeColor: 3, brows: 2, beard: 6, boots: 2 };
  t('crest0', () => m.crestCanvas(kit.crest || { shape: 1, pattern: 1, icon: 1, c1: 0xff0000, c2: 0xffffff })); t('face0', () => m.faceCanvas(look, '#a0704f', '#222222')); t('eyes0', () => { const c = document.createElement('canvas'); c.width = c.height = 512; const g = c.getContext('2d'); g.scale(0.5, 0.5); m.paintEyes(g, look, '#a0704f'); });
  for (let k = 0; k < 3; k++) t('paint' + k, () => m.paint(kit, look, { num: 9, name: 'ROSSI' }, 512));
  t('face', () => m.faceCanvas(look, '#a0704f', '#222222')); t('back', () => m.backCanvas('#ff0000', '#ffffff', { pattern: 0 }, { num: 9, name: 'ROSSI' }));
  t('make', () => m.make(kit, look, { num: 9, name: 'ROSSI' }));
  out.kind = m.constructor.name; out.headY = m.headY; out.L = m.L; out.leftSign = m.leftSign;
  return out;
});
console.log(JSON.stringify(r, null, 1));
await b.close(); srv.close();
