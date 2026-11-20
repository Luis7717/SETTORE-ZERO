// Prova a schermo del campione sullo sfondo del menu (Puppeteer, iPhone 390×844): schede nascoste, sfondo opaco,
// tempo fermo su istanti scelti; per palleggi, ogni giochetto e tiro una sequenza fitta di fotogrammi, poi un mosaico
// per ognuno (pagina HTML che affianca le immagini).
// Uso: npm run build && node test/menu-anim-shot.mjs shots [passo=0.15] [vicino|menu] [filtro]
//   vicino = telecamera in primo piano; filtro = solo le sequenze col nome che lo contiene (es. elastico)
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { b, p, wait, errs } from './shot.mjs';
import { menuRoutine, cycleLength, juggleTime, RUN_T } from '../src/menu-routine.js';
import { TRICKS } from '../src/tricks.js';
import { trickMove, MENU_OPT } from '../src/moves/tricks.js';
import { shotMove } from '../src/moves/shot.js';

const out = process.argv[2] || 'shots', step = +(process.argv[3] || 0.15), close = process.argv[4] === 'vicino', only = process.argv[5] || '';
const dir = `${out}/menu-anim`; mkdirSync(dir, { recursive: true });
await wait(1200);
await p.evaluate(() => { window.__newCareer('FC Prova'); });
await p.waitForFunction(() => window.__menuBg && window.__menuBg.view && window.__menuBg.view.fig, { timeout: 20000 });
await p.evaluate((close) => {
  document.getElementById('ui').style.visibility = 'hidden';
  const cv = document.querySelector('#menubg canvas'); cv.style.opacity = '1';
  document.getElementById('menubg').style.opacity = '1';
  if (close) window.__menuBg.view.dbgCam = { pos: [-1.3, 1.05, 4.7], look: [0.15, 0.62, 0.35] }; // davanti a destra del giocatore, in basso
}, close);
const frame = async (t, name) => {
  await p.evaluate(t => { window.__menuBg.view.hold = t; }, t);
  await p.evaluate(() => new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r))));
  const path = `${dir}/${name}.png`;
  await p.screenshot({ path, clip: close ? { x: 0, y: 120, width: 390, height: 600 } : { x: 45, y: 170, width: 300, height: 560 } });
  return path;
};
// mosaico: le immagini in griglia, ognuna col suo tempo
async function mosaic(name, shots, cols = 6) {
  const page = await b.newPage();
  const w = close ? 195 : 150, h = close ? 300 : 280;
  const cells = shots.map(s => `<div><img src="data:image/png;base64,${readFileSync(s.path).toString('base64')}"><span>${s.label}</span></div>`).join('');
  const rows = Math.ceil(shots.length / cols);
  await page.setViewport({ width: cols * w, height: rows * h + 24 });
  await page.setContent(`<style>body{margin:0;background:#1d2733;font:12px sans-serif;color:#fff}h1{font-size:13px;margin:4px}
    .g{display:grid;grid-template-columns:repeat(${cols},${w}px)}div{position:relative}img{width:${w}px;height:${h}px;object-fit:cover;display:block}
    span{position:absolute;left:3px;top:2px;background:#0008;padding:1px 3px}</style><h1>${name}</h1><div class="g">${cells}</div>`);
  const path = `${out}/mosaico-${name}${close ? '-vicino' : ''}.png`;
  await page.screenshot({ path, fullPage: true }); await page.close();
  return path;
}
const seq = async (name, t0, t1) => {
  if (only && !name.includes(only)) return null;
  const shots = [];
  for (let t = t0; t <= t1 + 1e-6; t += step) shots.push({ path: await frame(t, `${name}-${shots.length}`), label: `${(t - t0).toFixed(2)} s ${menuRoutine(t).seg}` });
  return mosaic(name, shots);
};
const made = [];
// palleggi (giro 0), in due mosaici
const J = juggleTime();
made.push(await seq('palleggi-1', 0, J / 2));
made.push(await seq('palleggi-2', J / 2, J));
// i sei giochetti: giro k, dall'inizio del giochetto
let c0 = 0;
for (let k = 0; k < TRICKS.length; k++) {
  const T = trickMove(TRICKS[k].id, MENU_OPT).T;
  made.push(await seq(`giochetto-${k + 1}-${TRICKS[k].id}`, c0 + J, c0 + J + T));
  if (k === 0) made.push(await seq('tiro', c0 + J + T + RUN_T - 0.3, c0 + J + T + RUN_T + Math.min(1.4, shotMove().T)));
  c0 += cycleLength(k);
}
console.log(made.join('\n'));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
