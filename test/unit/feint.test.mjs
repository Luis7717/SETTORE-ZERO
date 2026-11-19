import { test } from 'node:test';
import assert from 'node:assert/strict';
import { scene, wake, give, run } from '../lib/scene.mjs';

// portatore della squadra 0 che corre verso +y, difensore della squadra 1 davanti che prepara la scivolata
function setup(seed, dri = 75, dif = 55) {
  const m = scene({ seed }), p = m.players[9], o = m.players[11 + 3];
  wake(p, 0, 0); p.vx = 0; p.vy = 6; p.fx = 0; p.fy = 1; p.st.dri = dri; give(m, p); m.updateCtrl(0);
  wake(o, 0.3, 2); o.st.dif = dif; o.state = 'prep'; o.t = 0.26; o.warn = true;
  return { m, p, o };
}

test('finta: il portatore cambia direzione di colpo', () => {
  // Arrange
  const { m, p } = setup(1);
  // Act: scorrimento verso destra
  const ok = m.userFeint(0, 1, 0);
  run(m, 0.2);
  // Assert
  assert.equal(ok, true);
  assert.ok(p.vx > 3 && Math.abs(p.vy) < p.vx, `velocità dopo la finta ${p.vx.toFixed(2)}, ${p.vy.toFixed(2)}`);
  assert.equal(m.ball.owner, p, 'il pallone resta al portatore');
});

test('finta: il difensore che entra viene sbilanciato, più spesso se il dribbling batte la difesa', () => {
  // Arrange / Act
  const rate = (dri, dif) => {
    let n = 0;
    for (let s = 0; s < 80; s++) { const { m, o } = setup(100 + s, dri, dif); m.userFeint(0, -1, -0.3); if (o.stun > 0 && o.state === 'play') n++; }
    return n / 80;
  };
  const bravo = rate(85, 50), scarso = rate(45, 80);
  // Assert
  assert.ok(bravo > 0.6, `dribblatore bravo: ${bravo}`);
  assert.ok(scarso < bravo - 0.3, `dribblatore scarso: ${scarso}`);
});

test('finta: evento con i difensori sbilanciati e tempo di ricarica', () => {
  // Arrange
  const { m } = setup(7, 90, 40);
  // Act
  const first = m.userFeint(0, 1, 0), ev = m.events.find(e => e.type === 'feint');
  const again = m.userFeint(0, -1, 0);
  run(m, 1.3);
  const later = m.userFeint(0, -1, -1);
  // Assert
  assert.equal(first, true);
  assert.ok(ev && Array.isArray(ev.fooled));
  assert.equal(again, false, 'subito dopo non si può ripetere');
  assert.equal(later, true, 'dopo la ricarica sì');
});

test('finta: scorrere nella stessa direzione di corsa non è una finta; senza pallone non fa nulla', () => {
  // Arrange
  const { m, p, o } = setup(9);
  // Act / Assert
  assert.equal(m.userFeint(0, 0, 1), false);
  m.ball.owner = o;
  assert.equal(m.userFeint(0, 1, 0), false);
  assert.ok(p);
});
