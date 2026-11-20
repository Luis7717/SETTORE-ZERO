// Costo della grafica in partita (Puppeteer, SwiftShader, iPhone 390×844): draw call, triangoli, fotogrammi al secondo,
// ms per render() (sincronizzato leggendo un pixel) e tempo di disegno della texture del campo.
// Usa __enter (carica il modello dei giocatori, come nel gioco). Uso: npm run build && node test/pitch-perf.mjs
import { b, p, wait, errs } from './shot.mjs';
await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__career.s.settings.half = 90; window.__enter('friendly', 50); });
await p.waitForFunction(() => window.__view.p3d && window.__G.match, { timeout: 20000 });
await wait(2500);
const r = await p.evaluate(async () => {
  const v = window.__view, info = v.r.info.render, gl = v.r.getContext();
  v.render(); const calls = info.calls, tri = info.triangles;
  const fps = await new Promise(res => { let n = 0; const t0 = performance.now(); const f = () => { n++; if (performance.now() - t0 < 4000) requestAnimationFrame(f); else res(n / ((performance.now() - t0) / 1000)); }; requestAnimationFrame(f); });
  const px = new Uint8Array(4), sync = () => gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, px); sync(); const t0 = performance.now(); for (let i = 0; i < 20; i++) { v.render(); sync(); } const ms = (performance.now() - t0) / 20;
  return { calls, tri, fps: +fps.toFixed(1), msRender: +ms.toFixed(1), pitchMs: v.pitchMs !== undefined ? +v.pitchMs.toFixed(1) : null, shadows: v.r.shadowMap.enabled, players3d: !!v.p3d };
});
console.log(JSON.stringify(r));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
