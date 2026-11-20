// Esporta i valori di riferimento dello sfondo del menu (src/menu-routine.js e i movimenti calcolati del menu:
// palleggi, giochetti versione menu, tiro, pallone che rotola) per il confronto col porting in GDScript
// (godot/tests/test_sfondo_menu.gd).
// Uso: node test/export-menu.mjs   → godot/tests/fixtures/menu.json
// Va rilanciato quando cambiano src/menu-routine.js, src/moves/* o src/tricks.js.
import { writeFileSync, mkdirSync } from 'node:fs';
import { menuRoutine, cycleLength, juggleTime } from '../src/menu-routine.js';
import { juggleMove } from '../src/moves/juggle.js';
import { shotMove, rollInMove } from '../src/moves/shot.js';
import { trickMove, MENU_OPT } from '../src/moves/tricks.js';
import { TRICKS } from '../src/tricks.js';

const OUT = 'godot/tests/fixtures';
const R6 = x => Math.round(x * 1e6) / 1e6;
const arr = a => a.map(R6);
const frame = fr => fr && ({
  pelvis: arr(fr.pelvis.p), rot: Object.fromEntries(Object.entries(fr.rot).map(([k, q]) => [k, arr(q)])),
  legs: Object.fromEntries(Object.entries(fr.legs).map(([s, L]) => [s, { ankle: arr(L.ankle), fq: arr(L.fq), pole: arr(L.pole), w: R6(L.w) }])),
  arms: Object.fromEntries(Object.entries(fr.arms).map(([s, A]) => [s, { hand: arr(A.hand), pole: arr(A.pole) }])),
  ball: { p: arr(fr.ball.p), q: arr(fr.ball.q) },
});

// durate dei movimenti e tocchi dei palleggi
const J = juggleMove();
const moves = {
  juggle: { T: J.T, touches: J.touches.map(x => ({ t: R6(x.t), part: x.part, kind: x.kind })) },
  shot: { T: shotMove().T }, roll: { T: rollInMove().T },
  tricks: Object.fromEntries(TRICKS.map(T => [T.id, { T: trickMove(T.id, MENU_OPT).T }])),
};
// la sequenza nel tempo: sei giri (uno per giochetto), un campione ogni 0,23 s
let total = 0; for (let k = 0; k < TRICKS.length; k++) total += cycleLength(k);
const samples = [];
for (let t = 0; t < total + 3; t += 0.23) {
  const s = menuRoutine(t);
  samples.push({ t: R6(t), seg: s.seg, vx: s.vx, w: R6(s.w), cycle: s.cycle, trick: s.trick && { id: s.trick.id, q: R6(s.trick.q) },
    frame: frame(s.frame), ball: { p: arr(s.ball.p), q: arr(s.ball.q), vis: s.ball.vis } });
}
mkdirSync(OUT, { recursive: true });
writeFileSync(`${OUT}/menu.json`, JSON.stringify({ juggleTime: juggleTime(), cycles: TRICKS.map((_, k) => cycleLength(k)), total, moves, samples }));
console.log(`scritto ${OUT}/menu.json: ${samples.length} campioni, giro completo ${total.toFixed(2)} s`);
