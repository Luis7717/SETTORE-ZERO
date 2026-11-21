// Luis 2026-11-21: durante il rallenty (duello, fuga, area di tiro) niente corsa disegnata: ogni linea è un passaggio
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Input } from '../../src/input.js';
import { scene, wake, give, run } from '../lib/scene.mjs';

// Input senza schermo: basta la partita e i punti della linea
function lineOn(m, end) { const i = Object.create(Input.prototype); i.match = m; i.team = 0; i.pts = [{ x: 0, y: 0 }, end]; return i; }
function carrier(seed, y = 0) {
  const m = scene({ seed }), p = m.players[9];
  wake(p, 0, y); p.fx = 0; p.fy = 1; give(m, p); m.updateCtrl(0);
  return { m, p };
}
const hold = (m, p) => () => m.userMove(0, p.x, p.y, true);
const far = { x: 15, y: 10 }; // punto nel vuoto, lontano da tutti

test('fuori dal rallenty la linea nel vuoto è una corsa', () => {
  const { m, p } = carrier(1); run(m, 1 / 60, hold(m, p));
  assert.equal(m.passFor(0), false);
  assert.equal(lineOn(m, far).runPath(), true);
});

test('rallenty: in duello, fuga e area di tiro la linea nel vuoto è un passaggio, non una corsa', () => {
  // duello: avversario davanti
  let { m, p } = carrier(2); wake(m.players[14], 0.5, 4); run(m, 1 / 60, hold(m, p));
  assert.equal(m.duelFor(0), true); assert.equal(lineOn(m, far).runPath(), false, 'duello');
  // fuga: avversario alle spalle
  ({ m, p } = carrier(3)); wake(m.players[14], 0.5, -2); run(m, 1 / 60, hold(m, p));
  assert.equal(m.fleeFor(0), true); assert.equal(lineOn(m, far).runPath(), false, 'fuga');
  // area di tiro: ultimi 20 m
  ({ m, p } = carrier(4, 35)); run(m, 1 / 60, hold(m, p));
  assert.equal(m.inZone(0), true); assert.equal(lineOn(m, { x: 15, y: 40 }).runPath(), false, 'area di tiro');
});
