// Prova a schermo di pallone, porte, rete, bandierine ed effetti (Puppeteer, iPhone 390×844).
// Tiro in porta (la rete si gonfia), tiro sul palo (la porta trema), scia, sbuffo d'erba, coriandoli.
// Stampa anche i numeri di renderer.info (draw call, triangoli) in gioco e dopo il gol.
// Uso: npm run build && node test/props-shot.mjs shots [prefisso]
import { b, p, wait, snap, errs } from './shot.mjs';
const pre = process.argv[3] || '';
const shot = n => snap(pre + n);

await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__career.s.settings.half = 90; window.__start('friendly', 50); });
await wait(2500);

// pausa del ciclo del gioco: qui si fa avanzare a mano partita e grafica, a passi di 1/60 s
await p.evaluate(() => {
  const G = window.__G, v = window.__view; G.paused = true;
  v._upd = v.update; v.camFix = null;
  v.update = () => {};
  window.__adv = (n, cam) => {
    const m = G.match;
    for (let i = 0; i < n; i++) { m.step(1 / 60); m.events.length = 0; v._upd(1 / 60); }
    if (cam) { v.cam.position.set(cam[0], cam[1], cam[2]); v.cam.lookAt(cam[3], cam[4], cam[5]); }
    v.render();
    const r = v.r.info.render; return { calls: r.calls, tri: r.triangles };
  };
  window.__setup = (bx, by) => {
    const m = G.match; m.phase = 'play'; m.restart = null;
    for (const q of m.players) { q.state = 'play'; q.vx = q.vy = 0; q.kickAnim = 0; }
    const c = m.players[9]; m.place(c, bx, by - 0.6); c.fx = 0; c.fy = 1; m.ctrl[0] = c;
    const ball = m.ball; ball.owner = c; ball.kick = null; ball.shot = null; ball.x = bx; ball.y = by; ball.h = 0; ball.vx = ball.vy = ball.vh = 0;
    return c;
  };
  // tiro "finto" ma col motore vero: pallone libero con la velocità data, come dopo Match.kick
  window.__shoot = (x, y, vx, vy, vh) => {
    const m = G.match, c = window.__setup(x, y), ball = m.ball;
    const gk = m.gk(1); m.place(gk, -3.4, 49.3); gk.state = 'play';
    for (const q of m.players) if (q.team === 1 && q.pos !== 'P') m.place(q, q.x, Math.min(q.y, 30));
    ball.owner = null; ball.h = 0.02; ball.vx = vx; ball.vy = vy; ball.vh = vh; ball.ct = 0; ball.cax = ball.cay = 0;
    ball.noP = c; ball.noT = 0.35; ball.last = c; ball.kick = { team: 0, kicker: c, off: [], age: 0, type: 'shot', human: true };
    c.kickAnim = 0.35;
  };
});

const res = {};
// 1) gioco normale a centrocampo: numeri di riferimento
await p.evaluate(() => window.__setup(0, 0));
res.gioco = await p.evaluate(() => window.__adv(30));
await shot('pr-1-gioco');
// 2) pallone da vicino (texture, lucentezza, ombra)
res.palla = await p.evaluate(() => { const v = window.__view, s = v.flip; return window.__adv(1, [s * 0.9, 0.55, -s * 0.2 - 0.9, 0, 0.21, -s * 0.2]); });
// il pallone è dove lo mette il portatore (0.6 m davanti): guardiamo lì
await p.evaluate(() => { const v = window.__view, bm = v.ballM.position; const s = v.flip; window.__adv(0, [bm.x + 0.6, 0.55, bm.z - s * 0.75, bm.x, 0.2, bm.z]); });
await shot('pr-2-pallone');
// 3) porta avversaria vista dalla telecamera di gioco, portatore al limite dell'area
await p.evaluate(() => window.__setup(4, 28));
res.porta = await p.evaluate(() => window.__adv(90));
await shot('pr-3-porta-gioco');
// 4) porta da vicino, di tre quarti (pali, giunti, rete)
await p.evaluate(() => { const v = window.__view, s = v.flip; window.__adv(0, [s * 7, 1.7, -s * 41.5, 0, 1.1, -s * 50.5]); });
await shot('pr-4-porta-vicino');
await p.evaluate(() => { const v = window.__view, s = v.flip; window.__adv(0, [s * 9, 1.4, -s * 52.5, 0, 1.2, -s * 50.8]); });
await shot('pr-5-porta-lato');
// 5) tiro forte: scia e sbuffo d'erba appena calciato
await p.evaluate(() => window.__shoot(2, 34, 1.2, 30, 3.2));
res.scia = await p.evaluate(() => window.__adv(4));
await shot('pr-6-sbuffo');
await p.evaluate(() => { const v = window.__view, s = v.flip; window.__adv(0, [s * 4.5, 1.3, -s * 31.5, s * 2, 0.4, -s * 34.5]); });
await shot('pr-6b-sbuffo-vicino');
await p.evaluate(() => window.__adv(14));
await shot('pr-7-scia');
// 6) il pallone entra: la rete si gonfia (vista di lato e da dietro la porta)
await p.waitForFunction(() => true);
const n = await p.evaluate(() => { let k = 0; while (window.__G.match.phase === 'play' && k < 120) { window.__adv(1); k++; } return k; });
res.golDopoPassi = n;
res.fase = await p.evaluate(() => window.__G.match.phase);
res.gol = await p.evaluate(() => window.__adv(12));
await shot('pr-8-gol-gioco');
await p.evaluate(() => { const v = window.__view, s = v.flip; window.__adv(0, [s * 8, 1.6, -s * 51.8, 0, 1.1, -s * 51]); });
await shot('pr-9-gol-rete-lato');
await p.evaluate(() => { const v = window.__view, s = v.flip; window.__adv(0, [s * 2.5, 1.5, -s * 45.5, 0, 0.9, -s * 51.5]); });
await shot('pr-10-gol-rete-fronte');
res.coriandoli = await p.evaluate(() => window.__adv(40));
await shot('pr-11-coriandoli');
// 7) tiro sul palo: la porta trema
await p.evaluate(() => { const m = window.__G.match; m.setupKickoff(0); window.__adv(1); window.__shoot(3.66, 40, 0, 26, 2.6); });
const k2 = await p.evaluate(() => { let k = 0; const m = window.__G.match; while (Math.abs(m.ball.vy) > 0 && m.ball.vy > 0 && k < 80) { window.__adv(1); k++; } return k; });
res.paloPassi = k2;
await p.evaluate(() => { const v = window.__view, s = v.flip; window.__adv(3, [s * 6.5, 1.6, -s * 44.5, s * 2, 1.1, -s * 50.5]); });
await shot('pr-12-palo');
// 8) bandierina d'angolo
await p.evaluate(() => { const v = window.__view, s = v.flip; window.__adv(20, [s * 28.5, 1.4, -s * 46.5, s * 32, 0.9, -s * 50]); });
await shot('pr-13-bandierina');
// 9) linee: strada disegnata con la freccia e linee di difesa (stessa API usata da src/input.js)
await p.evaluate(() => {
  const m = window.__G.match, v = window.__view; m.setupKickoff(0); window.__setup(-4, -5); window.__adv(120);
  const a = m.players[3], c = m.players[5];
  m.runs[0] = [{ p: a, i: 0, path: Array.from({ length: 20 }, (_, k) => ({ x: a.x + Math.sin(k / 6) * 5, y: a.y + k * 0.6 })) }, { p: c, i: 0, path: Array.from({ length: 14 }, (_, k) => ({ x: c.x - k * 0.5, y: c.y + k * 0.4 })) }];
  window.__adv(2);
  const pts = Array.from({ length: 30 }, (_, k) => ({ x: -4 + Math.sin(k / 9) * 9, y: -5 + k * 0.7, h: 0 }));
  v.setPath(pts, false, null); window.__adv(0);
});
await shot('pr-14-linee');
await p.evaluate(() => { const v = window.__view; v.clearPath(); window.__G.match.runs[0] = []; v.update = v._upd; window.__G.paused = false; });
console.log(JSON.stringify(res));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
