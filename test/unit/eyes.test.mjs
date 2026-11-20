// Forme degli occhi (src/body/occhi.js): sulla parte del bulbo davvero visibile dalla camera (finestra dell'orbita),
// le 6 forme dell'editor devono essere nettamente diverse. Prima le palpebre cadevano nella parte nascosta del
// tassello e le forme a schermo erano quasi uguali.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { shapeHead } from '../../src/body/testa.js';
import { buildEyeTable, paintEyeTile, EYE_FORMS, LID_TONE } from '../../src/body/occhi.js';
import { SKINS, EYE_SHAPES } from '../../src/looks.js';

async function table() {
  const buf = readFileSync(new URL('../../assets/models/athlete.glb', import.meta.url));
  const gltf = await new Promise((ok, ko) => new GLTFLoader().parse(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength), '', ok, ko));
  let mesh = null; gltf.scene.traverse(o => { if (o.isSkinnedMesh && !mesh) mesh = o; });
  shapeHead(mesh);
  const UV = mesh.geometry.attributes.uv, isEye = new Uint8Array(UV.count);
  for (let i = 0; i < UV.count; i++) isEye[i] = UV.getX(i) >= 0.875 && UV.getY(i) >= 0.875 ? 1 : 0; // come isEye di src/athlete3d.js
  return buildEyeTable(mesh.geometry, isEye);
}
const tabP = table();

// celle visibili dipinte: aperte (bulbo: non pelle della palpebra né ciglia) e di iride (colore azzurro)
function measure(tab, eyes, skin = 1) {
  const px = paintEyeTile(tab, { eyes, skin, eyeColor: 4 }), sk = [parseInt(SKINS[skin][1].slice(1, 3), 16), parseInt(SKINS[skin][1].slice(3, 5), 16), parseInt(SKINS[skin][1].slice(5, 7), 16)];
  const open = new Uint8Array(tab.visible.length); let nOpen = 0, nIris = 0;
  tab.visible.forEach((i, k) => {
    const r = px[i * 4], g = px[i * 4 + 1], b = px[i * 4 + 2];
    const skinLike = Math.hypot(r - sk[0] * LID_TONE[0], g - sk[1] * LID_TONE[1], b - sk[2] * LID_TONE[2]) < 45, dark = r + g + b < 150 && b <= r + 10;
    if (!skinLike && !dark) { open[k] = 1; nOpen++; }
    if (b > r + 30 && b > 90) nIris++;
  });
  return { open, frac: nOpen / tab.visible.length, iris: nIris / tab.visible.length };
}

test('la finestra visibile del bulbo è larga e bassa come un occhio vero', async () => {
  const t = await tabP;
  assert.ok(t.visible.length > 150, `celle visibili: ${t.visible.length}`);
  assert.ok(t.W > 10 && t.W < 18, `semilarghezza ${t.W} mm`);
  assert.ok(t.H > 3 && t.H < 8, `semialtezza ${t.H} mm`);
  assert.equal(EYE_FORMS.length, EYE_SHAPES.length);
});

test('le 6 forme degli occhi sono nettamente diverse nella parte visibile', async () => {
  const t = await tabP, m = EYE_SHAPES.map((_, e) => measure(t, e));
  const [tondi, mandorla, sottili, grandi, allungati, assonnati] = m;
  assert.ok(assonnati.frac < tondi.frac * 0.65, `assonnati ${assonnati.frac.toFixed(2)} contro tondi ${tondi.frac.toFixed(2)}`);
  assert.ok(sottili.frac < grandi.frac * 0.5, `sottili ${sottili.frac.toFixed(2)} contro grandi ${grandi.frac.toFixed(2)}`);
  assert.ok(grandi.iris > tondi.iris * 1.25, `iride grandi ${grandi.iris.toFixed(2)} contro tondi ${tondi.iris.toFixed(2)}`);
  assert.ok(allungati.frac < tondi.frac && allungati.frac > sottili.frac, 'allungati: più bassi dei tondi, più aperti dei sottili');
  // a coppie: almeno il 12% della finestra cambia da aperto a coperto (o viceversa)
  for (let a = 0; a < m.length; a++) for (let b = a + 1; b < m.length; b++) {
    let diff = 0; for (let k = 0; k < m[a].open.length; k++) diff += m[a].open[k] !== m[b].open[k];
    assert.ok(diff / m[a].open.length > 0.12, `${EYE_SHAPES[a]} e ${EYE_SHAPES[b]} differiscono solo del ${(100 * diff / m[a].open.length).toFixed(1)}%`);
  }
  assert.ok(mandorla.frac > 0.1, 'a mandorla: apertura visibile');
});

test('colore degli occhi e pelle restano: iride del colore scelto, palpebra del colore della pelle', async () => {
  const t = await tabP, c = t.visible[t.visible.length >> 1];
  const blue = paintEyeTile(t, { eyes: 3, skin: 1, eyeColor: 4 }), brown = paintEyeTile(t, { eyes: 3, skin: 1, eyeColor: 0 });
  let differ = 0; for (const i of t.visible) differ += Math.abs(blue[i * 4 + 2] - brown[i * 4 + 2]) > 20;
  assert.ok(differ > t.visible.length * 0.1, 'il colore dell\'iride cambia');
  const light = paintEyeTile(t, { eyes: 5, skin: 0, eyeColor: 1 }), dark = paintEyeTile(t, { eyes: 5, skin: 7, eyeColor: 1 });
  assert.ok(light[0] > dark[0] + 60 && c >= 0, 'la palpebra segue la pelle');
});
