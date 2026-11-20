// Prova a schermo della lezione Dribbling (Puppeteer, iPhone 390×844): si apre il duello, dopo un attimo si tocca
// il tasto Dribbling vero e si salvano fotogrammi durante il giochetto, con la distanza difensore-portatore.
// Uso: npm run build && node test/tut-dribble-shot.mjs shots [prova 1..3]
import { b, p, wait, snap, errs } from './shot.mjs';
const K = Math.max(0, Math.min(2, +(process.argv[3] || 1) - 1));

await wait(1200);
// __enter carica la tappa 'match' (modello dei giocatori): con __start si vedrebbero le figure a box
await p.evaluate(() => { window.__newCareer(); return window.__enter('tutorial', 50); });
await wait(2500);
const ok = await p.evaluate(k => {
  const G = window.__G, t = G.tut; if (!t) return false;
  while (t.lesson && t.lesson.title !== 'Dribbling') t.nextLesson();
  t.card = true; t.go(); t.k = k; t.reset();
  document.getElementById('ov').style.display = 'none'; G.paused = false;
  return true;
}, K);
if (!ok) { console.log('tutorial non partito'); await b.close(); process.exit(1); }
const state = () => p.evaluate(() => {
  const G = window.__G, m = G.match, t = G.tut, c = t.st.c, o = t.st.o;
  return { t: +m.time.toFixed(2), duel: m.duelFor(0), d: +Math.hypot(o.x - c.x, o.y - c.y).toFixed(2), stun: +Math.max(0, o.stun).toFixed(2),
    beat: +Math.max(0, o.beat || 0).toFixed(2), palla: m.ball.owner ? (m.ball.owner.team ? 'avversario' : 'nostra') : 'libera', bravo: t.done > 0,
    tasto: getComputedStyle(document.getElementById('drib')).display !== 'none' };
});
const log = [];
// aspetta il duello, poi un attimo di rallenty
for (let i = 0; i < 40 && !(await state()).duel; i++) await wait(100);
await wait(700);
log.push({ n: 'dr-0', ...(await state()) }); await snap('dr-0');
await p.click('#drib');
for (let i = 1; i <= 12; i++) { await wait(60); log.push({ n: `dr-${i}`, ...(await state()) }); await snap(`dr-${i}`); }
for (const r of log) console.log(JSON.stringify(r));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
