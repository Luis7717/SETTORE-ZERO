// "Impronta" di partite a seme fisso: serve a dimostrare che un cambio di struttura del motore
// (es. dividere sim.js in più file) non cambia di un millimetro il comportamento.
import { createHash } from 'node:crypto';
import { playMatch } from './harness.mjs';

export const SCENARIOS = [
  { seed: 1, mode: 'bot', my: 60, op: 60, halfLen: 60 },
  { seed: 2, mode: 'bot', my: 55, op: 70, halfLen: 60, fB: '4-3-3' },
  { seed: 3, mode: 'bot', my: 75, op: 65, halfLen: 60, fA: '3-5-2', fB: '4-2-3-1' },
  { seed: 4, mode: 'ai', my: 62, op: 62, halfLen: 60, fA: '4-3-3', fB: '3-5-2' },
  { seed: 5, mode: 'ai', my: 50, op: 80, halfLen: 60, fA: '4-2-3-1' },
];

export function fingerprint(sc) {
  const h = createHash('sha256'), events = {};
  let n = 0;
  const { m, steps } = playMatch({
    ...sc,
    onStep(mm) {
      for (const e of mm.events) { const k = e.type + (e.kind ? ':' + e.kind : ''); events[k] = (events[k] || 0) + 1; }
      if (++n % 30 === 0) {
        const b = mm.ball;
        h.update(`${b.x},${b.y},${b.h};`);
        for (const p of mm.players) h.update(`${p.x},${p.y},${p.state};`);
      }
    },
  });
  return { score: m.score.join('-'), steps, stats: JSON.stringify(m.stats), events, hash: h.digest('hex').slice(0, 16) };
}
