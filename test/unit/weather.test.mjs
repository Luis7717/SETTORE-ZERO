import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Match, weatherFx, ballPhys } from '../../src/sim.js';
import { mkTeam } from '../lib/harness.mjs';
import { scene, wake, give } from '../lib/scene.mjs';

// Meteo (campo facoltativo `meteo` delle opzioni della partita): pioggia = palla più veloce e scivolate/contrasti
// più lunghi, neve = palla più lenta. Senza il campo tutto resta come prima (le golden non cambiano: golden.test.mjs).

function partita(meteo) {
  const a = mkTeam('A', 60, 11), b = mkTeam('B', 60, 22);
  return new Match({ seed: 5, halfLen: 60, human: [false, false], teams: [a, b], meteo });
}

// metri percorsi da un pallone rasoterra lanciato a v0 m/s finché si ferma
function corsa(roll, v0) {
  const s = { x: 0, y: 0, h: 0, vx: 0, vy: v0, vh: 0, cax: 0, cay: 0, ct: 0 };
  for (let i = 0; i < 6000 && s.vy > 0; i++) ballPhys(s, 1 / 60, roll);
  return s.y;
}

test('meteo: senza campo, sereno, nuvoloso e valori sconosciuti non cambiano niente', () => {
  // Arrange
  const base = weatherFx(undefined);
  // Act / Assert
  for (const w of ['sereno', 'nuvoloso', 'grandine', 3, null]) assert.deepEqual(weatherFx(w), base);
  assert.deepEqual(base, { roll: 5, slide: 1, stun: 1 });
});

test('meteo: sereno dà la stessa partita di nessun meteo, passo per passo', () => {
  // Arrange
  const m1 = partita(undefined), m2 = partita('sereno');
  // Act
  for (let i = 0; i < 1800; i++) { m1.step(1 / 60); m2.step(1 / 60); }
  // Assert
  assert.deepEqual(m2.score, m1.score);
  assert.equal(m2.ball.x, m1.ball.x);
  assert.equal(m2.ball.y, m1.ball.y);
});

test('meteo: pioggia = meno attrito, scivolata e contrasti più lunghi; neve = più attrito', () => {
  // Arrange / Act
  const r = weatherFx('pioggia'), n = weatherFx('neve');
  // Assert
  assert.ok(r.roll < 5 && r.slide > 1 && r.stun > 1, JSON.stringify(r));
  assert.ok(n.roll > 5 && n.slide === 1 && n.stun === 1, JSON.stringify(n));
});

test('meteo: lo stesso pallone corre di più sotto la pioggia e di meno sulla neve', () => {
  // Arrange
  const dry = corsa(weatherFx().roll, 15), wet = corsa(weatherFx('pioggia').roll, 15), snow = corsa(weatherFx('neve').roll, 15);
  // Assert
  assert.ok(wet > dry * 1.25, `bagnato ${wet} asciutto ${dry}`);
  assert.ok(snow < dry * 0.8, `neve ${snow} asciutto ${dry}`);
});

test('meteo: la partita tiene il meteo e il suo attrito', () => {
  // Arrange / Act
  const m = partita('pioggia'), s = partita();
  // Assert
  assert.equal(m.meteo, 'pioggia');
  assert.equal(m.roll, weatherFx('pioggia').roll);
  assert.equal(s.meteo, '');
  assert.equal(s.roll, 5);
});

test('meteo: sulla neve un passaggio rasoterra arriva comunque (si calcia più forte)', () => {
  // Arrange
  const m = partita('neve'), p = m.players[5];
  // Act: anteprima di un passaggio di 20 m, il pallone deve arrivarci
  const pts = m.predictKick(p, { type: 'ground', tx: p.x, ty: p.y + 20 }, 4);
  const far = Math.max(...pts.map(q => Math.abs(q.y - p.y)));
  // Assert
  assert.ok(far >= 19, `il passaggio si ferma a ${far} m`);
});

test('meteo: pioggia e neve cambiano la partita (stesso seme)', () => {
  // Arrange
  const m0 = partita(), m1 = partita('pioggia'), m2 = partita('neve');
  // Act
  for (let i = 0; i < 1800; i++) { m0.step(1 / 60); m1.step(1 / 60); m2.step(1 / 60); }
  // Assert
  assert.notEqual(m1.ball.x, m0.ball.x);
  assert.notEqual(m2.ball.x, m0.ball.x);
});

// scivolata comandata (userSlide) di un difensore senza nessuno vicino: quanto dura e quanta strada fa
function scivolata(meteo) {
  const m = scene({ seed: 3, meteo }), p = m.players[4], c = m.players[11 + 9];
  wake(p, 0, 0); wake(c, 20, 20); give(m, c); m.ctrl[0] = p;
  m.userSlide(0, 0, 1);
  let t = 0;
  while (p.state === 'slide' && t < 2) { m.step(1 / 60); t += 1 / 60; }
  return { t, y: p.y };
}

test('meteo: sotto la pioggia la scivolata dura e scorre di più', () => {
  // Arrange / Act
  const dry = scivolata(), wet = scivolata('pioggia');
  // Assert
  assert.ok(wet.t > dry.t * 1.2, `bagnato ${wet.t} s, asciutto ${dry.t} s`);
  assert.ok(wet.y > dry.y * 1.15, `bagnato ${wet.y} m, asciutto ${dry.y} m`);
});

// contrasto vinto da un difensore della CPU sul portatore fermo: quanto resta fermo chi perde palla
function contrasto(meteo) {
  const m = scene({ seed: 4, human: [false, false], meteo }), c = m.players[9], o = m.players[11 + 3];
  // il portatore resta fermo (stordito a lungo): il contrasto gli rimette lo stordimento giusto
  wake(c, 0, 0); c.fy = 1; give(m, c); c.stun = 99; wake(o, 0, 1.2); o.st.dif = 99; c.st.dri = 20;
  for (let i = 0; i < 600; i++) {
    m.step(1 / 60);
    const e = m.events.find(x => x.type === 'tackle' && x.on === c); m.events.length = 0;
    if (e) return c.stun;
  }
  return -1;
}

test('meteo: sotto la pioggia chi perde il contrasto resta fermo di più', () => {
  // Arrange / Act
  const dry = contrasto(), wet = contrasto('pioggia');
  // Assert
  assert.ok(dry > 0, `contrasto all'asciutto ${dry}`);
  assert.ok(wet > dry * 1.2, `bagnato ${wet} s, asciutto ${dry} s`);
});
