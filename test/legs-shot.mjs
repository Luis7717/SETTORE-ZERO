// Prova a schermo di bacino, gambe e piedi (src/body/gambe.js), Puppeteer 390×844: primi piani delle gambe in partita
// (fermo davanti, di lato e dietro, corsa, scatto, calcio, scivolata, tuffo, giochetto) e nell'editor con le varianti
// della divisa (pantaloncini corti/lunghi, calzettoni alti/bassi/ripiegati).
// Uso: npm run build && node test/legs-shot.mjs shots
import { b, p, wait, snap, errs } from './shot.mjs';

await wait(1200);
await p.evaluate(() => { window.__newCareer(); return window.__enter('friendly', 50); });
await wait(2500);
// pose: stato del giocatore 9 (o del portiere), fotogrammi di aggiornamento, telecamera relativa al giocatore
const poses = [
  ['fermo-davanti', { st: 'play', v: 0 }, 60, [0, 0.9, 2.4], 0.55],
  ['fermo-lato', { st: 'play', v: 0 }, 60, [2.4, 0.9, 0], 0.55],
  ['fermo-dietro', { st: 'play', v: 0 }, 60, [0, 0.9, -2.4], 0.55],
  ['corsa', { st: 'play', v: 4.5 }, 37, [3.2, 1.0, 0.6], 0.7],
  ['scatto', { st: 'play', v: 8.5 }, 41, [3.4, 1.0, 0.6], 0.7],
  ['calcio', { st: 'play', v: 0, kick: 0.17 }, 1, [3.0, 1.0, 1.2], 0.7],
  ['scivolata', { st: 'slide', v: 0 }, 1, [3.0, 1.2, 1.5], 0.3],
  ['tuffo', { st: 'dive', v: 0, gk: true }, 1, [0, 1.4, 4.2], 0.9],
  ['giochetto', { st: 'play', v: 0, trick: 'elastico' }, 14, [3.0, 1.0, 1.4], 0.6],
];
for (const [name, s, frames, cam, lookY] of poses) {
  await p.evaluate((s, frames, cam, lookY) => {
    const G = window.__G, v = window.__view, m = G.match; G.paused = true; m.phase = 'play'; m.restart = null;
    if (v._upd) v.update = v._upd;
    for (const q of m.players) { q.state = 'play'; q.kickAnim = 0; q.vx = q.vy = 0; q.dive = null; }
    const c = s.gk ? m.players[0] : m.players[9];
    c.x = 0; c.y = s.gk ? -48.5 : 10; c.fx = 0; c.fy = 1; c.vx = 0; c.vy = s.v; c.state = s.st; c.t = 0.2;
    if (s.kick) c.kickAnim = s.kick;
    if (s.gk) { c.t = 0.3; c.dive = { tx: 3, th: 1.2, hx: 0, hh: 1.1, x0: 0, dirx: 1 }; }
    m.ball.owner = null; m.ball.x = 5; m.ball.y = 30; m.ball.h = 0;
    v.tricks = s.trick ? new Map([[c.i, { id: s.trick, name: s.trick, dur: 0.5, t: 0, side: 1 }]]) : new Map();
    for (let i = 0; i < frames; i++) { if (s.kick) c.kickAnim = s.kick; v.update(1 / 60); }
    const f = v.flip, x = f * c.x, z = -f * c.y;
    v.cam.position.set(x + cam[0], cam[1], z - f * cam[2]); v.cam.lookAt(x, lookY, z); v.render();
    v._upd = v.update; v.update = () => {};
  }, s, frames, cam, lookY);
  await snap(`gb-${name}`);
}
await p.evaluate(() => { const v = window.__view; if (v._upd) v.update = v._upd; });
// editor: varianti della divisa, inquadratura sulle gambe
await p.evaluate(() => { localStorage.clear(); window.__career.s = null; window.__ui.show('title', 'new'); });
await wait(400);
await p.evaluate(() => { document.querySelector('#club').value = 'Aurora Valdoro'; document.querySelector('[data-a=create]').click(); });
await wait(600);
await p.evaluate(() => document.querySelector('[data-a=edok]').click());
await wait(3500);
const legsCam = { y: 0.8, z: 2.7, look: 0.6 }, feetCam = { y: 0.35, z: 1.0, look: 0.1 };
const kits = [{ shorts: 0, socks: 0, boots: 2, cam: legsCam }, { shorts: 1, socks: 1, boots: 0, cam: legsCam }, { shorts: 0, socks: 2, boots: 1, cam: legsCam }, { shorts: 0, socks: 0, boots: 1, cam: feetCam }, { shorts: 0, socks: 0, boots: 4, cam: feetCam }];
for (const [i, k] of kits.entries()) {
  for (const [yn, yaw] of [['davanti', 0.35], ['lato', Math.PI / 2], ['dietro', Math.PI]]) {
    await p.evaluate((k, yaw) => {
      const e = window.__ui.ed; e.d.look = { ...e.d.look, boots: k.boots }; e.d.style = { fit: 0, sleeves: 0, collar: 0, pattern: 0, shorts: k.shorts, socks: k.socks };
      e.tab = 'kit'; e.refresh(true); e.view.frame(k.cam, true); e.view.yaw = yaw;
    }, k, yaw);
    await wait(400); await p.evaluate((yaw) => { window.__ui.ed.view.yaw = yaw; }, yaw);
    await snap(`gb-ed${i + 1}-${yn}`);
  }
}
console.log(errs.length ? errs.join('\n') : 'nessun errore');
await b.close();
