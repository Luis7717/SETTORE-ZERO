// Prova a schermo dei giochetti del dribbling (Puppeteer, iPhone 390×844): per ogni giochetto due fotogrammi
// a metà del gesto, in primo piano di lato, più uno in campo con la telecamera di gioco.
// Uso: npm run build && node test/tricks-shot.mjs shots
import { b, p, wait, snap, errs } from './shot.mjs';
import { TRICKS } from '../src/tricks.js';

await wait(1200);
// __enter carica la tappa 'match' (modello dei giocatori): con __start si vedrebbero le figure a box
await p.evaluate(() => { window.__newCareer(); return window.__enter('friendly', 50); });
await wait(2500);
const info = [];
for (const T of TRICKS) {
  for (const q of [0.3, 0.6]) {
    const r = await p.evaluate((id, dur, q) => {
      const G = window.__G, v = window.__view, m = G.match; G.paused = true;
      m.phase = 'play'; m.restart = null;
      const c = m.players[9]; c.state = 'play'; c.x = 0; c.y = 10; c.vx = 0; c.vy = 0; c.fx = 0; c.fy = 1; c.kickAnim = 0;
      m.ball.owner = c; m.ball.x = 0; m.ball.y = 10.6; m.ball.h = 0; m.ball.vx = m.ball.vy = 0;
      const o = m.players[16]; m.place(o, 0, 13); o.fx = 0; o.fy = -1;
      v.tricks = new Map([[c.i, { id, name: id, dur, t: 0, side: 1 }]]);
      if (v._upd) v.update = v._upd;
      const n = Math.round(q * dur * 60); for (let i = 0; i < n; i++) v.update(1 / 60);
      const s = v.flip, x = s * c.x, z = -s * c.y;
      v.cam.position.set(x + 4.4, 1.7, z + 1.4); v.cam.lookAt(x, 1.0, z); v.render();
      v._upd = v.update; v.update = () => {}; // il ciclo del gioco non rimette la telecamera di gioco
      return { id, q, palla: [+v.ballM.position.x.toFixed(2), +v.ballM.position.y.toFixed(2), +v.ballM.position.z.toFixed(2)], attivo: !!v.trickOf(c) };
    }, T.id, T.dur, q);
    info.push(r);
    await snap(`tr-${TRICKS.indexOf(T) + 1}-${T.id}-${Math.round(q * 100)}`);
  }
}
await p.evaluate(() => { const v = window.__view; v.update = v._upd; });
// in partita: dribbling vero col tasto, giochetto scelto dal dribbling del portatore
await p.evaluate(() => {
  const G = window.__G, m = G.match; G.paused = false;
  const c = m.players[7]; m.place(c, 0, 5); c.fx = 0; c.fy = 1; c.st.dri = 92; m.ball.owner = c; m.ball.kick = null; m.ctrl[0] = c; m.att = 0;
  const o = m.players[16]; m.place(o, 0.5, 10); o.fx = 0; o.fy = -1; m.userMove(0, 0, 12, true);
});
await p.waitForFunction(() => window.__G.match.duelFor(0), { timeout: 4000 }).catch(() => {});
const big = await p.evaluate(() => new Promise(res => { document.getElementById('drib').click(); setTimeout(() => res({ scritta: document.getElementById('big').textContent, giochetto: window.__view.trickOf(window.__G.match.players[7]) }), 250); }));
await snap('tr-9-in-partita');
console.log(JSON.stringify({ fotogrammi: info, inPartita: big }));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
