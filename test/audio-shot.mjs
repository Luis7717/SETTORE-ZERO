// Prova a schermo dei suoni veri: dopo l'ingresso in partita tutti i file audio del manifesto
// devono essere scaricati e decodificati (Puppeteer, servito via http come nell'app). Uso: node test/audio-shot.mjs
import { b, p, wait, errs } from './shot.mjs';

await wait(1200);
await p.evaluate(() => { window.__newCareer(); });
await p.mouse.click(200, 400); // primo tocco: crea il contesto audio, come su iPhone
await wait(2500); // la musica arriva in sottofondo
await p.evaluate(() => window.__enter('friendly', 50));
await p.waitForFunction(() => window.__G.state === 'match', { timeout: 10000 });
await wait(2500);
const r = await p.evaluate(() => ({ scaricati: [...window.__assets.data.keys()], falliti: [...window.__assets.failed.keys()], decodificati: Object.keys(window.__sfx.buf).sort(), contesto: window.__sfx.ctx && window.__sfx.ctx.state }));
console.log(JSON.stringify(r));
console.log(errs.join('\n') || 'nessun errore');
await b.close();
