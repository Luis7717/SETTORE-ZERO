// Primi piani di busto, spalle, braccia e mani del calciatore (Puppeteer, iPhone 390×844, servito via http).
// Figure costruite con la stessa make() del gioco, messe a centrocampo con il resto della scena nascosto:
// divise diverse (aderente/larga, maniche corte/lunghe/senza, tre colletti, motivi), davanti, dietro, di lato, 3/4,
// posa a T (proporzioni) e posa "fermo" del clip. Uso: npm run build && node test/busto-shot.mjs shots [prefisso]
import { mkdirSync } from 'node:fs';
import puppeteer from 'puppeteer-core';
import { serve } from './lib/serve.mjs';

const out = process.argv[2] || 'shots', pre = process.argv[3] || '';
mkdirSync(out, { recursive: true });
const b = await puppeteer.launch({ executablePath: process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: 'new', args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const p = await b.newPage();
await p.setViewport({ width: 390, height: 844, deviceScaleFactor: +(process.env.DSF || 1), isMobile: true, hasTouch: true });
const errs = [];
p.on('pageerror', e => errs.push('PAGEERR ' + e.message));
p.on('console', m => { if (m.type() === 'error' && !/404/.test(m.text())) errs.push('CONSOLE ' + m.text()); });
const srv = await serve('www');
await p.goto(srv.url + 'index.html');
const wait = ms => new Promise(r => setTimeout(r, ms));
await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__career.s.settings.half = 90; return window.__enter('friendly', 50); });
await wait(3000);
const ok = await p.evaluate(() => !!window.__view.p3d);
if (!ok) { console.log('modello 3D non caricato'); process.exit(1); }

// kit: colori + stile; view: 'front' | 'back' | 'side' | 'q' (3/4); dist in m; y = altezza guardata; pose: 'idle' | 't'
const shot = (name, o) => p.evaluate((o) => {
  const v = window.__view, G = window.__G; G.paused = true;
  v._upd = v._upd || v.update; v.update = () => {};
  for (const f of v.figs) { f.g.visible = false; f.sh.visible = false; }
  if (v._bf) { v.scene.remove(v._bf.g); v.p3d.dispose(v._bf); }
  const kit = { shirt: o.shirt, shorts: o.shorts, socks: o.socks, style: o.style, crest: { shape: 2, pattern: 1, icon: 3, c1: '#ffffff', c2: '#1b3a8a' } };
  const f = v._bf = v.p3d.make(kit, { skin: o.skin ?? 2, hair: 3, hairColor: 1, eyes: 0, eyeColor: 0, brows: 0, beard: 0, boots: 1 }, { num: o.num ?? 10, name: o.name ?? 'Ferrante', tex: o.tex });
  f.g.scale.setScalar(1.25); v.scene.add(f.g);
  if (o.pose !== 't') { f.mixer.update(o.t ?? 0.4); }
  const a = { front: 0, back: Math.PI, side: Math.PI / 2, q: Math.PI / 4, qb: Math.PI * 0.8 }[o.view];
  const d = o.dist, y = o.y, tx = o.tx || 0;
  v.cam.position.set(tx + Math.sin(a) * d, y + (o.dy || 0), Math.cos(a) * d); v.cam.lookAt(tx, y, 0);
  v.cam.fov = o.fov || v.cam.fov; v.cam.updateProjectionMatrix();
  v.render();
}, o).then(() => p.screenshot({ path: `${out}/${pre}bu-${name}.png` }));

const red = { shirt: 0xc8102e, shorts: 0xffffff, socks: 0xc8102e }, blue = { shirt: 0x1d4ed8, shorts: 0x0f172a, socks: 0x1d4ed8 };
const white = { shirt: 0xf4f4f4, shorts: 0x111111, socks: 0xf4f4f4 }, purple = { shirt: 0x5b21b6, shorts: 0xffffff, socks: 0x5b21b6 };
const S = (fit, sleeves, collar, pattern) => ({ fit, sleeves, collar, pattern, shorts: 0, socks: 0 });
await shot('01-intero-t', { ...red, style: S(0, 0, 0, 0), view: 'front', dist: 4.2, y: 1.15, pose: 't' });
await shot('02-intero-fermo', { ...red, style: S(0, 0, 0, 0), view: 'front', dist: 3.6, y: 1.15 });
await shot('03-busto-davanti', { ...red, style: S(0, 0, 0, 0), view: 'front', dist: 1.5, y: 1.6, tex: 1024 });
await shot('04-busto-dietro', { ...red, style: S(0, 0, 0, 0), view: 'back', dist: 1.7, y: 1.55 });
await shot('05-busto-lato', { ...blue, style: S(0, 0, 1, 2), view: 'side', dist: 1.7, y: 1.5 });
await shot('06-busto-3q-larga', { ...blue, style: S(1, 0, 1, 2), view: 'q', dist: 1.7, y: 1.5 });
await shot('07-polo-lunghe', { ...white, style: S(0, 1, 2, 1), view: 'q', dist: 1.9, y: 1.4 });
await shot('08-senza-maniche', { ...purple, style: S(0, 2, 0, 3), view: 'front', dist: 1.9, y: 1.4 });
await shot('09-colletto-vicino', { ...red, style: S(0, 0, 0, 0), view: 'front', dist: 0.75, y: 1.82, dy: 0.1, tex: 512 });
await shot('10-colletto-v-vicino', { ...blue, style: S(0, 0, 1, 0), view: 'q', dist: 0.75, y: 1.82, dy: 0.1, tex: 512 });
await shot('11-mano', { ...red, style: S(0, 0, 0, 0), view: 'q', dist: 0.75, y: 1.1, tx: 0.36, tex: 1024 });
await shot('12-dietro-partita', { ...white, style: S(0, 0, 0, 4), view: 'back', dist: 2.6, y: 1.3, num: 7, name: 'Kowalczyk' });
await shot('13-mani-davanti', { ...purple, style: S(0, 1, 0, 0), view: 'front', dist: 1.3, y: 1.0, skin: 4 });
console.log(errs.length ? errs.join('\n') : 'nessun errore');
await b.close(); srv.close();
