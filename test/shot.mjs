// Apre il gioco in Chrome a misura iPhone e salva schermate.
import puppeteer from 'puppeteer-core';
import { pathToFileURL } from 'node:url';
const out = process.argv[2] || 'shots';
const b = await puppeteer.launch({ executablePath: '/usr/bin/google-chrome', headless: 'new', args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const p = await b.newPage();
await p.setViewport({ width: 390, height: 844, deviceScaleFactor: +(process.env.DSF || 1), isMobile: true, hasTouch: true });
const errs = [];
p.on('pageerror', e => errs.push('PAGEERR ' + e.message));
p.on('console', m => { if (m.type() === 'error') errs.push('CONSOLE ' + m.text()); });
await p.goto(pathToFileURL(process.cwd() + '/www/index.html').href);
const wait = ms => new Promise(r => setTimeout(r, ms));
const snap = async n => { await p.screenshot({ path: `${out}/${n}.png` }); };
export { b, p, wait, snap, errs };
