// Misura il tempo di apertura del menu (dalla navigazione al menu disegnato), media di N aperture.
// Uso: node test/menu-time.mjs [file|http] [N]
import puppeteer from 'puppeteer-core';
import { pathToFileURL } from 'node:url';
import { serve } from './lib/serve.mjs';

const mode = process.argv[2] || 'http', N = +(process.argv[3] || 5), dir = process.argv[4] || 'www';
const srv = mode === 'http' ? await serve(dir) : null;
const url = srv ? srv.url + 'index.html' : pathToFileURL(process.cwd() + '/' + dir + '/index.html').href;
const b = await puppeteer.launch({ executablePath: process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: 'new', args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const times = [];
for (let i = 0; i < N; i++) {
  const p = await b.newPage();
  await p.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true });
  await p.setCacheEnabled(false);
  await p.goto(url, { waitUntil: 'domcontentloaded' });
  await p.waitForFunction(() => window.__ui && window.__ui.screen === 'title' && document.querySelector('#ui .scr'), { timeout: 20000 });
  times.push(await p.evaluate(() => performance.now()));
  await p.close();
}
await b.close(); if (srv) srv.close();
times.sort((a, c) => a - c);
console.log(`menu aperto (${mode}, ${dir}): mediana ${times[N >> 1].toFixed(0)} ms, min ${times[0].toFixed(0)}, max ${times[N - 1].toFixed(0)} su ${N} aperture`);
