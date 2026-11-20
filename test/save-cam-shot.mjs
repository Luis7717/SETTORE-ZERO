// Prova a schermo della visuale della parata: tiro avversario da 5 posizioni (centrale vicino, centrale da 25 m,
// angolato a sinistra e a destra, molto laterale). Per ognuna una schermata e se pali, traversa, portiere e pallone
// sono dentro lo schermo (fuori dalle fasce del punteggio in alto e del suggerimento in basso).
// Uso: npm run build && node test/save-cam-shot.mjs shots
import { b, p, wait, snap, errs } from './shot.mjs';

const SHOTS = [
  ['centrale-vicino', [0, -39], [1.5, 1.0]],
  ['centrale-25m', [0, -25], [-2.5, 1.5]],
  ['angolato-sinistra', [-14, -33], [2.0, 0.8]],
  ['angolato-destra', [14, -33], [-2.5, 1.2]],
  ['molto-laterale', [27, -44], [-1.0, 1.5]],
];

await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__start('friendly', 50); });
await wait(2500);
const out = [];
for (const [name, from, to] of SHOTS) {
  const r = await p.evaluate(async (from, to) => {
    const G = window.__G, m = G.match, v = window.__view, HL = 50, GW = 7.32, GH = 2.44;
    G.paused = false; m.phase = 'play'; m.restart = null; G.ts = 1;
    // tutti lontani dall'azione, il nostro portiere al suo posto, il tiratore col pallone
    let k = 0; for (const q of m.players) { if (q.pos === 'P') continue; m.place(q, -26 + (k % 10) * 5.5, 22 + (k / 10 | 0) * 6); k++; }
    const gk = m.gk(0); m.place(gk, 0, -HL + 0.6); gk.fx = 0; gk.fy = 1; gk.state = 'play';
    const o = m.players[20]; m.place(o, from[0], from[1]);
    const dx = to[0] - from[0], dy = -HL - from[1], d = Math.hypot(dx, dy); o.fx = dx / d; o.fy = dy / d;
    m.ball.owner = o; m.ball.x = o.x + o.fx * 0.5; m.ball.y = o.y + o.fy * 0.5; m.ball.h = 0; m.ball.kick = null; m.ball.shot = null; m.att = 1;
    m.kick(o, { type: 'shot', tx: to[0], ty: -HL, th: to[1], curve: 0 });
    // se la mira casuale lo porta fuori dallo specchio, il tiro si segna lo stesso: serve solo la visuale
    if (!m.ball.shot) m.ball.shot = { team: 1, cx: to[0], ch: to[1], tc: 1, on: true, gx0: gk.x };
    await new Promise(r => setTimeout(r, 1500));
    const inside = (x, y, h) => { const s = v.worldToScreen(x, y, h); return s.vis && s.x > 0 && s.x < v.w && s.y > 64 && s.y < v.h - 56; };
    const b = m.ball, pts = {
      paloSx0: [-GW / 2, -HL, 0], paloDx0: [GW / 2, -HL, 0], traversaSx: [-GW / 2, -HL, GH], traversaDx: [GW / 2, -HL, GH],
      portiere: [gk.x, gk.y, 1], pallone: [b.x, b.y, b.h],
    };
    const fuori = Object.entries(pts).filter(([, q]) => !inside(...q)).map(([n]) => n);
    return { parata: m.diveWin(0), pallone: [+b.x.toFixed(1), +b.y.toFixed(1)], fov: +v.cam.fov.toFixed(0), fuori };
  }, from, to);
  out.push({ tiro: name, ...r });
  await snap('save-' + name);
}
for (const r of out) console.log(JSON.stringify(r));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
