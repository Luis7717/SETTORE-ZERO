// Prova a schermo del tutorial: una schermata 1,2 s dopo l'inizio di ogni prova di ogni lezione, e se il portatore
// (o il controllato) è dentro lo schermo. Uso: npm run build && node test/tut-lessons-shot.mjs shots
import { b, p, wait, snap, errs } from './shot.mjs';

await wait(1200);
await p.evaluate(() => { window.__newCareer(); window.__start('tutorial', 50); });
await wait(2500);
const out = [];
const lessons = await p.evaluate(() => window.__G.tut ? window.__G.tut.lessons.length : 0);
if (!lessons) { console.log('tutorial non partito'); await b.close(); process.exit(1); }
for (let li = 0; li < lessons; li++) for (let k = 0; k < 3; k++) {
  const r = await p.evaluate(async (li, k) => {
    const t = window.__G.tut, m = window.__G.match, v = window.__view;
    while (t.li < li) t.nextLesson();
    t.card = true; t.go(); t.k = k; t.reset();
    document.getElementById('ov').style.display = 'none'; window.__G.paused = false;
    await new Promise(r => setTimeout(r, 1200));
    const who = t.lesson.title === 'Portiere' ? m.gk(0) : m.ball.owner && m.ball.owner.team === 0 ? m.ball.owner : m.ctrl[0];
    const sp = who && v.worldToScreen(who.x, who.y, 1);
    return { lezione: t.lesson.title, prova: k + 1, visibile: !!(sp && sp.x > 0 && sp.x < v.w && sp.y > 60 && sp.y < v.h - 60) };
  }, li, k);
  out.push(r);
  await snap(`tl-${li + 1}-${k + 1}`);
}
console.log(JSON.stringify(out.filter(x => !x.visibile)), out.length, 'prove');
console.log(errs.join('\n') || 'nessun errore');
await b.close();
