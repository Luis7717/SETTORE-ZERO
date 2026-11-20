// Prova a schermo della visuale larga nel rallenty in attacco: duello col difensore, area di tiro e disegno della
// corsa, con compagni larghi sulle fasce. Per ognuna una schermata, i compagni entro 35 m (davanti o di fianco) che
// restano fuori dallo schermo e quanto è alto il portatore a schermo (px).
// Uso: npm run build && node test/wide-cam-shot.mjs shots
import { b, p, wait, snap, errs } from './shot.mjs';

// [nome, portatore [x, y], compagni (relativi al portatore), difensore davanti?, disegno?]
const CASES = [
  ['duello-largo', [0, 0], [[-24, 4], [23, 2], [9, 24], [-12, 20], [27, 16], [-4, -16]], true, false],
  ['duello-davanti', [-6, -10], [[4, 18], [-6, 22], [20, 8], [-18, 6]], true, false],
  ['duello-fascia', [-22, 5], [[14, 0], [24, 8], [30, 20], [8, 26], [0, -14]], true, false],
  ['area-tiro', [6, 34], [[-28, -4], [19, 2], [-14, 8], [6, -8], [-6, 10]], false, false],
  ['corsa-disegno', [4, -14], [[-25, 3], [22, 6], [8, 22], [-10, 18], [26, 20]], false, true],
];

await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__start('friendly', 50); });
await wait(2500);
const out = [];
for (const [name, at, mates, duel, draw] of CASES) {
  const r = await p.evaluate(async (at, mates, duel, draw) => {
    const G = window.__G, m = G.match, v = window.__view, inp = window.__input;
    G.paused = false; m.phase = 'play'; m.restart = null; inp.cancel();
    const c = m.players[7]; m.place(c, at[0], at[1]); c.fx = 0; c.fy = 1; c.vx = c.vy = 0;
    m.ball.owner = c; m.ball.x = c.x; m.ball.y = c.y + 0.4; m.ball.h = 0; m.ball.kick = null; m.ball.shot = null; m.ctrl[0] = c; m.att = 0;
    let k = 0; for (const q of m.team(0)) { if (q === c || q.pos === 'P') continue; const rel = mates[k] || [-26 + k * 2, -34]; m.place(q, c.x + rel[0], c.y + rel[1]); q.vx = q.vy = 0; k++; }
    k = 0; for (const o of m.team(1)) if (o.pos !== 'P') { m.place(o, -20 + k * 4, Math.min(49, c.y + 40)); k++; }
    if (duel) { const o = m.players[16]; m.place(o, c.x + 0.5, c.y + 4); o.fx = 0; o.fy = -1; }
    if (draw) { const s = v.worldToScreen(c.x, c.y, 0); inp.mode = 'draw'; inp.drawing = true; inp.pts = [{ x: c.x, y: c.y, h: 0, sx: s.x, sy: s.y }]; }
    await new Promise(r => setTimeout(r, 1500));
    const inside = (x, y, h) => { const s = v.worldToScreen(x, y, h); return s.vis && s.x > 0 && s.x < v.w && s.y > 64 && s.y < v.h - 56; };
    const fuori = [];
    for (const q of m.team(0)) {
      if (q === c || q.pos === 'P') continue;
      const dx = q.x - c.x, dy = q.y - c.y;
      if (Math.hypot(dx, dy) > 35 || dy < -5) continue;
      if (!inside(q.x, q.y, 0.9)) fuori.push([Math.round(dx), Math.round(dy)]);
    }
    const top = v.worldToScreen(c.x, c.y, 2.25), foot = v.worldToScreen(c.x, c.y, 0);
    const res = { pos: [+c.x.toFixed(1), +c.y.toFixed(1), +m.ball.x.toFixed(1), +m.ball.y.toFixed(1), m.ball.owner === c], duello: m.duelFor(0), area: m.inZone(0), disegno: inp.drawing, portatoreDentro: inside(c.x, c.y, 1), portatorePx: Math.round(foot.y - top.y), fov: +v.cam.fov.toFixed(0), fuori };
    if (draw) inp.cancel();
    return res;
  }, at, mates, duel, draw);
  out.push({ caso: name, ...r });
  await snap('wide-' + name);
}
for (const r of out) console.log(JSON.stringify(r));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
