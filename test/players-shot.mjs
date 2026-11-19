// Prova a schermo dei giocatori 3D (Puppeteer, iPhone 390×844, servito via http come nell'app).
// Schermate: calcio d'inizio, azione in corsa, tiro, scivolata, tuffo del portiere, esultanza, primo piano.
// Stampa draw call e triangoli (scena intera e solo giocatori) e fps medi su 5 s di gioco.
// Uso: npm run build && node test/players-shot.mjs shots          (con il modello)
//      node test/players-shot.mjs shots --senza-modello             (il file del modello risponde 404: figure a box)
import { mkdirSync } from 'node:fs';
import puppeteer from 'puppeteer-core';
import { serve } from './lib/serve.mjs';

const out = process.argv[2] || 'shots', noModel = process.argv.includes('--senza-modello'), tag = noModel ? 'box' : 'p3d';
mkdirSync(out, { recursive: true });
const b = await puppeteer.launch({ executablePath: process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe', headless: 'new', args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const p = await b.newPage();
await p.setViewport({ width: 390, height: 844, deviceScaleFactor: +(process.env.DSF || 1), isMobile: true, hasTouch: true });
const errs = [];
p.on('pageerror', e => errs.push('PAGEERR ' + e.message));
p.on('console', m => { if (m.type() === 'error' && !/404/.test(m.text())) errs.push('CONSOLE ' + m.text()); });
if (noModel) {
  await p.setRequestInterception(true);
  p.on('request', r => r.url().includes('models/player.glb') ? r.respond({ status: 404, body: '' }) : r.continue());
}
const srv = await serve('www');
await p.goto(srv.url + 'index.html');
const wait = ms => new Promise(r => setTimeout(r, ms));
const snap = async n => { await p.screenshot({ path: `${out}/pl-${tag}-${n}.png` }); };

await wait(1200);
await p.evaluate(() => { document.querySelector('[data-a=create]').click(); window.__ui.show('hub'); window.__career.s.settings.half = 90; return window.__enter('friendly', 50); });
await wait(2500);
const model = await p.evaluate(() => !!(window.__view.figs[0] && window.__view.figs[0].m3d));
await snap('1-calcio-di-inizio');

// numeri: scena intera e differenza con i giocatori nascosti
const measure = () => p.evaluate(() => {
  const v = window.__view, info = v.r.info.render;
  v.render(); const all = { calls: info.calls, tri: info.triangles };
  for (const f of v.figs) { f.g.visible = false; f.sh.visible = false; }
  v.render(); const pl = { calls: all.calls - info.calls, tri: all.tri - info.triangles };
  for (const f of v.figs) { f.g.visible = true; f.sh.visible = true; }
  v.render();
  return { calls: all.calls, tri: all.tri, plCalls: pl.calls, plTri: pl.tri };
});
const stats = await measure();

// azione: la squadra avversaria ha palla a centrocampo, tutti corrono
await p.evaluate(() => {
  const m = window.__G.match; m.phase = 'play'; m.restart = null;
  const c = m.players[19]; c.x = 4; c.y = 6; m.ball.owner = c; m.ball.kick = null; m.ball.x = c.x; m.ball.y = c.y;
});
await wait(1600); await snap('2-azione-in-corsa');
const run = await measure();

// fps medi su 5 s di gioco
const fps = await p.evaluate(() => new Promise(ok => { let n = 0; const t0 = performance.now(); const f = () => { n++; if (performance.now() - t0 < 5000) requestAnimationFrame(f); else ok(n / ((performance.now() - t0) / 1000)); }; requestAnimationFrame(f); }));

// costo in JavaScript della grafica dei giocatori: ms medi di view.update (mixer, pose) su 300 chiamate
const updMs = await p.evaluate(() => { const v = window.__view; const t0 = performance.now(); for (let i = 0; i < 300; i++) v.update(1 / 60); return (performance.now() - t0) / 300; });

// fotogrammi fermi: gioco in pausa, stato impostato a mano, la grafica avanza con view.update
const still = (setup, steps = 40) => p.evaluate((setup, steps) => {
  const G = window.__G, v = window.__view, m = G.match; G.paused = true;
  new Function('m', 'v', setup)(m, v);
  for (let i = 0; i < steps; i++) v.update(1 / 60);
  v.render();
}, setup.toString().replace(/^[^{]*{|}$/g, ''), steps);
// primo piano di lato sul giocatore i (la prossima view.update rimette la telecamera di gioco)
const close = (i, n, front) => p.evaluate((i, front) => {
  const v = window.__view, q = window.__G.match.players[i], s = v.flip, x = s * q.x, z = -s * q.y;
  const yaw = v.figs[i].g.rotation.y, fx = Math.sin(yaw), fz = Math.cos(yaw), dx = front ? fx * 4.2 - fz * 1.5 : 4.2, dz = front ? fz * 4.2 + fx * 1.5 : 1.2;
  v._upd = v.update; v.update = () => {};
  v.cam.position.set(x + dx, 1.6, z + dz); v.cam.lookAt(x, 0.9, z); v.render();
}, i, !!front).then(() => snap(n)).then(() => p.evaluate(() => { const v = window.__view; v.update = v._upd; }));

// tiro: il nostro attaccante a metà del gesto, al limite dell'area
await still((m) => {
  m.phase = 'play'; m.restart = null; const c = m.players[9]; c.state = 'play'; c.x = -4; c.y = 28; c.vx = 0; c.vy = 2; c.fx = 0; c.fy = 1; c.kickAnim = 0.17;
  m.ball.owner = null; m.ball.x = -4; m.ball.y = 28.8; m.ball.h = 0.1; m.ball.vx = 0; m.ball.vy = 0; m.ctrl[0] = c;
});
await snap('3-tiro'); await close(9, '3b-tiro-vicino');
// scivolata di un nostro difensore sull'avversario
await still((m) => {
  m.players[9].kickAnim = 0; const c = m.players[4]; c.state = 'slide'; c.t = 0.2; c.x = 2; c.y = 4; c.fx = 0.3; c.fy = 0.95; c.vx = 0; c.vy = 0;
  const o = m.players[19]; o.x = 2.6; o.y = 5.6; m.ball.owner = o; m.ball.x = 2.6; m.ball.y = 5.9; m.ball.h = 0; m.ctrl[0] = c;
});
await snap('4-scivolata'); await close(4, '4b-scivolata-vicino');
// tuffo del nostro portiere (inquadratura difensiva vicino alla nostra porta)
await still((m) => {
  m.players[4].state = 'play'; const g = m.players[0]; g.state = 'dive'; g.t = 0.3; g.x = 0; g.y = -48.5; g.fx = 0; g.fy = 1;
  g.dive = { tx: 3, th: 1.2, hx: 0, hh: 1.1, x0: 0, dirx: 1 };
  const o = m.players[20]; o.x = 6; o.y = -36; m.ball.owner = null; m.ball.x = 2.2; m.ball.y = -47.5; m.ball.h = 1.1; m.ctrl[0] = m.players[3];
}, 120);
await snap('5-tuffo-portiere'); await close(0, '5b-tuffo-vicino');
// esultanza dopo un gol nostro
await p.evaluate(() => {
  const m = window.__G.match; m.players[0].state = 'play'; m.players[0].dive = null; m.ball.x = 0; m.ball.y = 49; m.ball.last = m.players[9];
  [[7, -4, 41], [8, 3, 43], [9, 0, 45], [10, 6, 40]].forEach(([i, x, y]) => { const q = m.players[i]; q.x = x; q.y = y; q.vx = q.vy = 0; q.fx = 0; q.fy = -1; });
  m.goal(0); window.__G.paused = false;
});
await wait(1200); await snap('6-esultanza');
await p.evaluate(() => { window.__G.paused = true; }); await close(9, '6b-esultanza-vicino', true);
// primo piano (qualità del modello): telecamera bassa vicino a due giocatori fermi
await p.evaluate(() => {
  const G = window.__G, v = window.__view, m = G.match; G.paused = true; m.phase = 'play';
  for (const q of m.players) { q.cele = 0; q.vx = q.vy = 0; q.state = 'play'; q.kickAnim = 0; }
  const a = m.players[9], o = m.players[16], k = m.players[0]; a.x = -1; a.y = 0; a.fx = 0; a.fy = -1; o.x = 1; o.y = 0; o.fx = 0; o.fy = -1;
  k.x = 3; k.y = 0.5; k.fx = 0; k.fy = -1;
  for (let i = 0; i < 20; i++) v.update(1 / 60);
  v.update = () => {}; v.cam.position.set(0.5, 1.6, 5.5); v.cam.lookAt(0.5, 1.1, 0); v.render();
});
await wait(300); await snap('7-primo-piano');

console.log(`modello 3D in uso: ${model ? 'sì' : 'no (figure a box)'}`);
for (const [n, x] of [['calcio d\'inizio', stats], ['azione', run]])
  console.log(`${n}: scena ${x.calls} draw call, ${x.tri} triangoli · giocatori ${x.plCalls} draw call, ${x.plTri} triangoli`);
console.log(`view.update: ${updMs.toFixed(2)} ms a fotogramma (JavaScript)`);
console.log(`fps medi su 5 s: ${fps.toFixed(1)} (Chrome headless con SwiftShader, solo per confronto)`);
console.log(errs.join('\n') || 'nessun errore');
await b.close(); srv.close();
