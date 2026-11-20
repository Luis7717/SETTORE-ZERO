// Prova a schermo della visuale girata col dito nel rallenty (src/camuser.js), con tocchi veri (Puppeteer, 390×844):
// duello e area di tiro → visuale dritta, girata a sinistra, girata a destra, linea disegnata con la visuale girata
// (deve finire sul compagno), ritorno dritto dopo il passaggio. In fondo la lezione "Passaggio" del tutorial fatta
// disegnando (il tocco sul compagno non passa più).
// Uso: npm run build && node test/cam-user-shot.mjs shots
import { b, p, wait, snap, errs } from './shot.mjs';

const lerp = (a, c, n) => Array.from({ length: n }, (_, i) => [a[0] + (c[0] - a[0]) * (i + 1) / n, a[1] + (c[1] - a[1]) * (i + 1) / n]);
async function drag(a, c, n = 12, ms = 25, hold = false) {
  await p.touchscreen.touchStart(a[0], a[1]); await wait(40);
  for (const q of lerp(a, c, n)) { await p.touchscreen.touchMove(q[0], q[1]); await wait(ms); }
  if (!hold) { await wait(60); await p.touchscreen.touchEnd(); }
}
const state = () => p.evaluate(() => {
  const m = window.__G.match, v = window.__view, c = m.ball.owner;
  return { yaw: +(v.userYaw * 180 / Math.PI).toFixed(1), duello: m.duelFor(0), area: m.inZone(0), owner: c ? c.i : null, kick: !!m.ball.kick, fov: +v.cam.fov.toFixed(0) };
});
const scr = (i, h = 1) => p.evaluate((i, h) => { const q = window.__G.match.players[i], s = window.__view.worldToScreen(q.x, q.y, h); return [Math.round(s.x), Math.round(s.y)]; }, i, h);

await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__start('friendly', 50); });
await wait(2500);
const out = [];

// [nome, portatore, compagni relativi, difensore davanti]
const CASES = [
  ['duello', [0, -5], [[-24, 4], [23, 2], [9, 24], [-12, 20], [27, 16], [-4, -16]], true],
  ['area', [6, 32], [[-26, -2], [17, 2], [-14, 8], [6, -8], [-6, 10]], false],
];
for (const [name, at, mates, duel] of CASES) {
  await p.evaluate((at, mates, duel) => {
    const G = window.__G, m = G.match, inp = window.__input;
    G.paused = false; G.speed = 0.0005; m.phase = 'play'; m.restart = null; inp.cancel(); window.__view.userYaw = 0;
    const c = m.players[7]; m.place(c, at[0], at[1]); c.fx = 0; c.fy = 1; c.vx = c.vy = 0;
    m.ball.owner = c; m.ball.x = c.x; m.ball.y = c.y + 0.4; m.ball.h = 0; m.ball.kick = null; m.ball.shot = null; m.ctrl[0] = c; m.att = 0;
    let k = 0; for (const q of m.team(0)) { if (q === c || q.pos === 'P') continue; const rel = mates[k] || [-26 + k * 2, -34]; m.place(q, c.x + rel[0], c.y + rel[1]); q.vx = q.vy = 0; k++; }
    k = 0; for (const o of m.team(1)) if (o.pos !== 'P') { m.place(o, -20 + k * 4, Math.min(49, c.y + 40)); k++; }
    if (duel) { const o = m.players[16]; m.place(o, c.x + 0.5, c.y + 4); o.fx = 0; o.fy = -1; m.step(0.001); }
  }, at, mates, duel);
  await wait(1500);
  out.push({ caso: name, foto: 'dritta', ...(await state()) }); await snap(`cu-${name}-1-dritta`);
  // dito a sinistra in alto, lontano dal portatore, trascinato verso destra: si afferra il campo → si guarda a sinistra
  await drag([60, 330], [200, 330]); await wait(900);
  out.push({ caso: name, foto: 'sinistra', ...(await state()) }); await snap(`cu-${name}-2-sinistra`);
  await drag([330, 330], [50, 330], 16); await wait(900);
  out.push({ caso: name, foto: 'destra', ...(await state()) }); await snap(`cu-${name}-3-destra`);
  // linea dal portatore al compagno più vicino a schermo, con la visuale girata a destra
  const recv = await p.evaluate(() => {
    const m = window.__G.match, v = window.__view, c = m.ball.owner; let best = null, bd = 1e9;
    for (const q of m.team(0)) { if (q === c || q.pos === 'P') continue; const s = v.worldToScreen(q.x, q.y, 0); if (s.x < 30 || s.x > v.w - 30 || s.y < 90 || s.y > v.h - 120) continue; const d = Math.hypot(q.x - c.x, q.y - c.y); if (d < bd) { bd = d; best = q.i; } }
    return best;
  });
  const from = await scr(7, 0.3), to = await scr(recv, 0);
  await drag(from, to, 16, 30, true); await wait(400);
  const lineEnd = await p.evaluate((recv) => { const inp = window.__input, e = inp.pts[inp.pts.length - 1], q = window.__G.match.players[recv]; return { dist: +Math.hypot(e.x - q.x, e.y - q.y).toFixed(2), punti: inp.pts.length }; }, recv);
  out.push({ caso: name, foto: 'linea', ricevitore: recv, fineLineaDalCompagno_m: lineEnd.dist, ...(await state()) }); await snap(`cu-${name}-4-linea-girata`);
  await p.touchscreen.touchEnd();
  await p.evaluate(() => { window.__G.speed = 1; });
  await wait(250);
  out.push({ caso: name, foto: 'passaggio partito', ...(await state()) });
  await wait(2200);
  out.push({ caso: name, foto: 'ritorno', ...(await state()) }); await snap(`cu-${name}-5-ritorno`);
}
await p.evaluate(() => { window.__G.speed = 1; });

// tocco breve su un compagno nel duello: niente passaggio
await p.evaluate(() => {
  const G = window.__G, m = G.match; G.speed = 0.0005; m.phase = 'play'; m.restart = null; window.__input.cancel();
  const c = m.players[7]; m.place(c, 0, -5); c.fx = 0; c.fy = 1; m.ball.owner = c; m.ball.kick = null; m.ctrl[0] = c; m.place(m.players[9], 8, 12);
  const o = m.players[16]; m.place(o, 0.5, -1); o.fx = 0; o.fy = -1; m.step(0.001);
});
await wait(900);
const mt = await scr(9);
await p.touchscreen.tap(mt[0], mt[1]); await wait(300);
out.push({ caso: 'tocco su compagno', ...(await state()) });
await p.evaluate(() => { window.__G.speed = 1; });

// lezione "Passaggio" del tutorial: corsa verso il difensore disegnata, poi passaggio disegnato al compagno
await p.evaluate(() => { window.__start('tutorial', 50); });
await wait(1500);
const tut = [];
for (let k = 0; k < 3; k++) {
  await p.evaluate((k) => { const t = window.__G.tut; t.card = true; t.go(); t.k = k; t.reset(); document.getElementById('ov').style.display = 'none'; window.__G.paused = false; window.__input.cancel(); }, k);
  await wait(700);
  const c0 = await scr(7, 0.3);
  await drag(c0, [c0[0], Math.max(120, c0[1] - 260)], 10, 25);
  let duel = false;
  for (let i = 0; i < 40 && !duel; i++) { await wait(150); duel = await p.evaluate(() => window.__G.match.duelFor(0)); }
  // la prova a schermo va a pochi fotogrammi al secondo: tempo quasi fermo mentre il "dito" disegna il passaggio
  await p.evaluate(() => { window.__G.speed = 0.0005; }); await wait(300);
  const a = await scr(7, 0.3), r = await scr(9, 0);
  await drag(a, r, 14, 25, true); await wait(200);
  await p.evaluate(() => { window.__G.speed = 1; }); await p.touchscreen.touchEnd();
  let ok = false;
  for (let i = 0; i < 40 && !ok; i++) { await wait(150); ok = await p.evaluate(() => { const t = window.__G.tut; return !!t.done || t.k > 0 || t.li > 0; }); }
  tut.push({ prova: k + 1, duello: duel, riuscita: ok });
  if (k === 0) await snap('cu-tutorial-passaggio');
}
for (const r of out) console.log(JSON.stringify(r));
console.log('tutorial Passaggio:', JSON.stringify(tut));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
