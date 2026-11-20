// Costo dello stadio (Puppeteer + SwiftShader, 390×844): fotogrammi al secondo in partita con 22 giocatori,
// con lo stadio acceso e spento, e i numeri di renderer.info. SwiftShader è una GPU finta su CPU: i valori
// servono solo a confrontare due versioni sulla stessa macchina, non dicono gli fps del telefono.
// Uso: npm run build && node test/stadium-perf.mjs
import { b, p, wait, errs } from './shot.mjs';

await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__career.s.settings.half = 90; window.__start('friendly', 50); });
await p.waitForFunction(() => window.__view && window.__view.stadium, { timeout: 15000 });
await wait(2000);

const fps = (ms) => p.evaluate((ms) => new Promise((res) => {
  let n = 0; const t0 = performance.now();
  const f = () => { n++; if (performance.now() - t0 < ms) requestAnimationFrame(f); else res(+(n * 1000 / (performance.now() - t0)).toFixed(1)); };
  requestAnimationFrame(f);
}), ms);
const info = () => p.evaluate(() => {
  const v = window.__view, r = v.r.info; v.render();
  return { calls: r.render.calls, tri: r.render.triangles, geos: r.memory.geometries, tex: r.memory.textures, buildMs: +v.stadium.buildMs.toFixed(1) };
});

// tempo di disegno di un fotogramma (ms), con readPixels per aspettare la fine del lavoro della GPU finta;
// stadio acceso e spento alternati più volte, si prende la mediana (la macchina può essere occupata da altro)
const frameMs = (on) => p.evaluate((on) => {
  const v = window.__view, gl = v.r.getContext(), px = new Uint8Array(4);
  v.stadium.root.visible = on; v.render(); gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, px);
  const t0 = performance.now();
  for (let k = 0; k < 10; k++) { v.render(); gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, px); }
  v.stadium.root.visible = true;
  return (performance.now() - t0) / 10;
}, on);
const med = a => { const s = a.slice().sort((x, y) => x - y); return +s[s.length >> 1].toFixed(2); };
const msOn = [], msOff = [];
await p.evaluate(() => { window.__G.paused = true; });
for (let k = 0; k < 9; k++) { msOn.push(await frameMs(true)); msOff.push(await frameMs(false)); }
await p.evaluate(() => { window.__G.paused = false; });
const on = [], off = [];
for (let k = 0; k < 2; k++) {
  on.push(await fps(3000));
  await p.evaluate(() => { window.__view.stadium.root.visible = false; });
  off.push(await fps(3000));
  await p.evaluate(() => { window.__view.stadium.root.visible = true; });
}
const i = await info();
const avg = a => +(a.reduce((s, x) => s + x, 0) / a.length).toFixed(1);
console.log(`ms per fotogramma (mediana): con stadio ${med(msOn)} · senza ${med(msOff)} · costo stadio ${(med(msOn) - med(msOff)).toFixed(2)} ms`);
console.log(`fps SwiftShader con stadio: ${avg(on)} (${on.join(', ')}) · senza stadio: ${avg(off)} (${off.join(', ')})`);
console.log(`renderer.info scena intera: ${i.calls} draw call, ${i.tri} triangoli, ${i.geos} geometrie, ${i.tex} texture · costruzione stadio ${i.buildMs} ms`);
console.log(errs.join('\n') || 'nessun errore');
await b.close();
