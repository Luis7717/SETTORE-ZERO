// Esporta i valori di riferimento della grafica JS per il confronto col porting in GDScript della vista Godot
// (godot/tests/test_camfit.gd, test_camuser.gd, test_mosse.gd).
// Uso: node test/export-vista.mjs   → godot/tests/fixtures/vista.json
// Va rilanciato quando cambiano src/camfit.js, src/camuser.js, src/ik.js, src/moves/* o src/tricks.js.
//
// Contenuto: inquadrature calcolate (parata, rallenty largo, calcio d'angolo, fitView) con posizione, punto
// guardato, campo visivo e gruppi tenuti; angoli della visuale girata; IK a due ossa; i sei giochetti della partita
// campionati nel tempo (bacino, busto, gambe, braccia, pallone), una posa specchiata e lo spostamento del pallone.
import { writeFileSync, mkdirSync } from 'node:fs';
import { saveView, wideView, cornerView, fitView, WIDE_MARGIN } from '../src/camfit.js';
import { dragYaw, relaxYaw, keepGoal, isCamDrag } from '../src/camuser.js';
import { twoBone } from '../src/ik.js';
import { trickMove, MATCH_OPT, TRICK_IDS } from '../src/moves/tricks.js';
import { mirrorFrame } from '../src/moves/core.js';
import { ballOffset, bestTrick, chooseTrick, TRICKS } from '../src/tricks.js';

const OUT = 'godot/tests/fixtures';
const ASPECT = 390 / 844, FOV = 70;
const pick = v => ({ pos: v.pos, look: v.look, fov: v.fov, used: v.used, ok: v.ok, t: v.t });

const save = [];
for (const ball of [[0, 0.4, -39], [0, 0.4, -25], [-14, 0.6, -33], [14, 0.6, -33], [27, 0.3, -44], [30, 0.2, -48.5], [5, 6, -30]]) {
  const keeper = [ball[0] * 0.15, -50 + 0.6];
  save.push({ ball, keeper, out: pick(saveView({ ball, keeper, aspect: ASPECT, fov: FOV })) });
}
const wide = [];
const WIDE = [
  [[-6, -10], [[4, 18], [-6, 22], [-18, 6], [20, 8]], false],
  [[-22, 5], [[14, 0], [30, 20], [8, 26], [0, -14]], false],
  [[6, 34], [[-14, 8], [6, -8], [-6, 10]], true],
  [[4, -14], [[8, 22], [-10, 18], [-16, 10]], false],
];
for (const [carrier, rel, goal] of WIDE) {
  const mates = rel.map(q => [carrier[0] + q[0], carrier[1] + q[1]]);
  for (const yaw of [0, 0.5, -1.2]) wide.push({ carrier, mates, goal: goal && Math.abs(yaw) < 0.7, yaw, out: pick(wideView({ carrier, mates, goal: goal && Math.abs(yaw) < 0.7, yaw, aspect: ASPECT, fov: FOV })) });
}
const corner = [];
for (const ball of [[32, 50], [-32, 50], [32, -50], [-32, -50]]) for (const yaw of [0, 0.2, -1.2]) corner.push({ ball, yaw, out: pick(cornerView({ ball, yaw, aspect: ASPECT, fov: FOV })) });
const fit = pick(fitView({ c0: [0, 10, -20], yaw: 0, pitch: 0.5, aspect: ASPECT, fov: FOV, fovMax: 80, tMax: 5, m: WIDE_MARGIN, groups: [[[0, 0, 0]], [[200, 0, 0]], [[3, 0, 10]]] }));

const camuser = {
  drag: [[0, -390, 390], [0, 80, 390], [0.5, -39, 390], [0, -5 * 390, 390]].map(a => [...a, dragYaw(...a)]),
  relax: [[0.8, true, 0.1], [5, true, 0.1], [1.2, false, 0.1], [1.2, false, 1 / 60], [0.0005, false, 0.016]].map(a => [...a, relaxYaw(...a)]),
  keep: [[true, 0], [true, 0.6], [false, 0]].map(a => [...a, keepGoal(...a)]),
  isDrag: [[11, 0], [12, 0], [-40, 10], [20, 40]].map(a => [...a, isCamDrag(...a)]),
};

const ik = [];
for (const [A, C, a, b, pole] of [
  [[0.1, 0.99, 0], [0.12, 0.08, 0.1], 0.52, 0.39, [0, 0.15, 1]],
  [[0.1, 0.99, 0], [0.3, 0.6, 0.5], 0.52, 0.39, [0.3, 0, 1]],
  [[0, 1, 0], [0, -2, 0], 0.5, 0.4, [0, 0, 1]],          // irraggiungibile: gamba tesa
  [[0, 1, 0], [0, 0.95, 0.02], 0.5, 0.4, [0, 0, 1]],     // troppo vicino
  [[0.16, 1.48, -0.07], [0.5, 1.1, 0.2], 0.3, 0.28, [0.35, -0.25, -1]],
]) ik.push({ A, C, a, b, pole, out: twoBone(A, C, a, b, pole) });

const R4 = x => Math.round(x * 1e6) / 1e6;
const arr = a => a.map(R4);
const frame = fr => ({
  pelvis: arr(fr.pelvis.p), rot: Object.fromEntries(Object.entries(fr.rot).map(([k, q]) => [k, arr(q)])),
  legs: Object.fromEntries(Object.entries(fr.legs).map(([s, L]) => [s, { ankle: arr(L.ankle), fq: arr(L.fq), pole: arr(L.pole), w: R4(L.w) }])),
  arms: Object.fromEntries(Object.entries(fr.arms).map(([s, A]) => [s, { hand: arr(A.hand), pole: arr(A.pole) }])),
  ball: { p: arr(fr.ball.p), q: arr(fr.ball.q) },
});
const tricks = {};
for (const id of TRICK_IDS) {
  const mv = trickMove(id, MATCH_OPT), N = 16, frames = [];
  for (let i = 0; i <= N; i++) { const t = mv.T * i / N; frames.push({ t, ...frame(mv.at(t)) }); }
  const offs = [];
  for (let i = 0; i <= 10; i++) offs.push({ q: i / 10, ...ballOffset(id, i / 10) });
  tricks[id] = { T: mv.T, frames, mirror: frame(mirrorFrame(mv.at(mv.T * 0.4))), offs };
}
const choose = [];
for (const dri of [20, 40, 55, 70, 90]) for (const r of [0.1, 0.7, 0.95]) choose.push([dri, r, chooseTrick(dri, r).id]);

mkdirSync(OUT, { recursive: true });
writeFileSync(`${OUT}/vista.json`, JSON.stringify({ aspect: ASPECT, fov: FOV, save, wide, corner, fit, camuser, ik, tricks,
  best: [30, 45, 55, 65, 75, 85, 99].map(d => [d, bestTrick(d)]), choose, trickIds: TRICKS.map(T => T.id) }));
console.log(`scritto ${OUT}/vista.json`);
