// Apre il gioco in Chrome a misura iPhone e salva schermate.
import puppeteer from 'puppeteer-core';
import { serve } from './lib/serve.mjs';
const out = process.argv[2] || 'shots';
const b = await puppeteer.launch({ executablePath: process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: 'new', args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const p = await b.newPage();
await p.setViewport({ width: 390, height: 844, deviceScaleFactor: +(process.env.DSF || 1), isMobile: true, hasTouch: true });
const errs = [];
p.on('pageerror', e => errs.push('PAGEERR ' + e.message));
p.on('console', m => { if (m.type() === 'error') errs.push('CONSOLE ' + m.text()); });
// servito via http come nell'app (schema app://): con file:// i file in www/assets non si caricherebbero
const srv = await serve(process.env.WWW || 'www'); // WWW: un'altra cartella da provare (es. una build vecchia)
b.on('disconnected', () => srv.close());
await p.goto(srv.url + 'index.html');
const wait = ms => new Promise(r => setTimeout(r, ms));
const snap = async n => { await p.screenshot({ path: `${out}/${n}.png` }); };
export { b, p, wait, snap, errs };
