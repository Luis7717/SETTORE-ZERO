// Prova a schermo del caricamento a pezzi (Puppeteer, iPhone 390×844), servendo www/ come fa l'app:
// 1) menu subito, 2) ingresso in partita con un file presente e uno mancante: la partita parte lo stesso,
// 3) la tappa musica arriva in sottofondo, 4) la versione a file unico funziona aprendola da disco,
// 5) senza assets/three.min.js (indispensabile) compare il messaggio d'errore invece di una pagina vuota.
// Alla fine ricostruisce www/ col manifesto vero. Uso: node test/loading-shot.mjs shots
import puppeteer from 'puppeteer-core';
import { execFileSync } from 'node:child_process';
import { rmSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { serve } from './lib/serve.mjs';

const out = process.argv[2] || 'shots';
const run = (...a) => execFileSync(process.execPath, ['build.mjs', ...a], { stdio: 'inherit' });
const wait = ms => new Promise(r => setTimeout(r, ms));
const res = {};
run('--manifest', 'test/fixtures/assets-test/manifest.json');
run('--manifest', 'test/fixtures/assets-test/manifest.json', '--single');
rmSync('www/assets/sparisce.wav'); // file mancante a partita in corso di caricamento
const srv = await serve('www');
const b = await puppeteer.launch({ executablePath: process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: 'new', args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--autoplay-policy=no-user-gesture-required'] });
try {
  const p = await b.newPage(); const errs = [];
  p.on('pageerror', e => errs.push('PAGEERR ' + e.message));
  await p.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true });
  await p.goto(srv.url + 'index.html');
  await p.waitForFunction(() => window.__ui && window.__ui.screen === 'title', { timeout: 20000 });
  res.menu = true;
  await p.evaluate(() => { window.__newCareer(); });
  await p.waitForFunction(() => window.__assets.stages.has('music'), { timeout: 8000 });
  res.musica = await p.evaluate(async () => (await window.__assets.stages.get('music')).ok);
  const bar = p.waitForFunction(() => document.getElementById('load').style.display === 'flex', { timeout: 3000 }).then(() => true, () => false);
  await p.evaluate(() => window.__enter('friendly', 50));
  res.barraVista = await bar;
  await p.waitForFunction(() => window.__G.state === 'match', { timeout: 10000 });
  await wait(1200);
  res.partita = await p.evaluate(async () => { const A = window.__assets; return { ok: ['crowd', 'kick'].filter(id => A.has(id)), falliti: [...A.failed.keys()], barraNascosta: document.getElementById('load').style.display === 'none', stato: window.__G.state, tappaDaRiprovare: !A.stages.has('match') }; });
  await p.screenshot({ path: `${out}/load-1-partita.png` });
  res.errori = errs;
  // file unico da disco
  const q = await b.newPage(); const errs2 = [];
  q.on('pageerror', e => errs2.push('PAGEERR ' + e.message));
  await q.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true });
  await q.goto(pathToFileURL(process.cwd() + '/dist/tiro-a-giro.html').href);
  await q.waitForFunction(() => window.__ui && window.__ui.screen === 'title', { timeout: 20000 });
  await q.evaluate(() => { window.__newCareer(); window.__enter('friendly', 50); });
  await q.waitForFunction(() => window.__G.state === 'match', { timeout: 10000 });
  res.fileUnico = await q.evaluate(() => ['crowd', 'kick'].filter(id => window.__assets.has(id)));
  res.erroriFileUnico = errs2;
  // three.min.js che non arriva: messaggio chiaro, nessun errore di pagina
  const z = await b.newPage(); const errs3 = [];
  z.on('pageerror', e => errs3.push('PAGEERR ' + e.message));
  await z.setViewport({ width: 390, height: 844, isMobile: true, hasTouch: true });
  await z.setRequestInterception(true);
  z.on('request', rq => (rq.url().endsWith('/assets/three.min.js') ? rq.respond({ status: 404, body: '' }) : rq.continue()));
  await z.goto(srv.url + 'index.html', { waitUntil: 'load' });
  await wait(500);
  res.senzaThree = await z.evaluate(() => ({ messaggio: getComputedStyle(document.getElementById('nothree')).display === 'flex', menu: !!window.__ui }));
  res.erroriSenzaThree = errs3;
  await z.screenshot({ path: `${out}/load-2-senza-three.png` });
} finally {
  await b.close(); srv.close();
  run(); run('--single');
}
console.log(JSON.stringify(res, null, 1));
