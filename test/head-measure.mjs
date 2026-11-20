// Misure di testa e collo del modello atleta in unità T (altezza della testa, mento → cima del cranio), su sezioni
// orizzontali vere della mesh, prima e dopo la rifinitura di src/body/testa.js. Confronto con PROPORZIONI.md.
// Uso: node test/head-measure.mjs
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { shapeHead } from '../src/body/testa.js';

async function load() {
  const buf = readFileSync(new URL('../assets/models/athlete.glb', import.meta.url));
  const ab = buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength);
  const gltf = await new Promise((ok, ko) => new GLTFLoader().parse(ab, '', ok, ko));
  let mesh = null; gltf.scene.traverse(o => { if (o.isSkinnedMesh && !mesh) mesh = o; });
  return mesh;
}

export function measure(mesh) {
  const geo = mesh.geometry, P = geo.attributes.position, I = geo.index.array, J = geo.attributes.skinIndex, W = geo.attributes.skinWeight, UV = geo.attributes.uv;
  const H = mesh.skeleton.bones.findIndex(b => b.name === 'Head');
  const eye = i => UV.getX(i) >= 0.875 && UV.getY(i) >= 0.875;
  const hw = new Float32Array(P.count); for (let i = 0; i < P.count; i++) for (let k = 0; k < 4; k++) if (J.getComponent(i, k) === H) hw[i] += W.getComponent(i, k);
  // sezione orizzontale a quota y: punti dove i lati dei triangoli attraversano il piano
  const slice = (y, keep) => { const out = []; for (let t = 0; t < I.length; t += 3) { const v = [I[t], I[t + 1], I[t + 2]]; if (v.some(eye) || (keep && !v.every(keep))) continue;
    for (let e = 0; e < 3; e++) { const a = v[e], b = v[(e + 1) % 3], da = P.getY(a) - y, db = P.getY(b) - y; if ((da < 0) === (db < 0)) continue; const f = da / (da - db);
      out.push([P.getX(a) + (P.getX(b) - P.getX(a)) * f, y, P.getZ(a) + (P.getZ(b) - P.getZ(a)) * f]); } } return out; };
  let ymin = Infinity, ymax = -Infinity, top = -Infinity, zc = 0, n = 0;
  for (let i = 0; i < P.count; i++) { const y = P.getY(i); ymin = Math.min(ymin, y); ymax = Math.max(ymax, y); if (hw[i] > 0.5 && !eye(i)) { top = Math.max(top, y); zc += P.getZ(i); n++; } }
  zc /= n;
  let chin = Infinity, neckZ = -Infinity;
  for (let i = 0; i < P.count; i++) if (Math.abs(P.getX(i)) < 0.012 && P.getY(i) > top - 0.29 && P.getY(i) < top - 0.25) neckZ = Math.max(neckZ, P.getZ(i));
  for (let i = 0; i < P.count; i++) if (hw[i] > 0.3 && Math.abs(P.getX(i)) < 0.012 && P.getZ(i) > neckZ + 0.025 && P.getY(i) < top - 0.12) chin = Math.min(chin, P.getY(i));
  const T = top - chin, r = x => +(x / T).toFixed(3), ext = (s, k) => s.length ? Math.max(...s.map(p => p[k])) - Math.min(...s.map(p => p[k])) : 0;
  const isHead = i => hw[i] > 0.3;
  let wSkull = 0, wEars = 0, depth = 0;
  for (let f = 0.62; f <= 0.86; f += 0.02) wSkull = Math.max(wSkull, ext(slice(chin + f * T, isHead), 0));
  for (let f = 0.36; f <= 0.6; f += 0.02) wEars = Math.max(wEars, ext(slice(chin + f * T, isHead), 0));
  for (let f = 0.56; f <= 0.86; f += 0.02) depth = Math.max(depth, ext(slice(chin + f * T, isHead).filter(p => Math.abs(p[0]) < 0.012), 2));
  const jaw = ext(slice(chin + 0.15 * T, isHead), 0);
  // incavo del collo (davanti): scendendo dal mento, dove il davanti del collo torna ad avanzare (inizio del petto)
  const frontZ = y => { const s = slice(y).filter(p => Math.abs(p[0]) < 0.012 && p[2] > zc - 0.06); return s.length ? Math.max(...s.map(p => p[2])) : -1; };
  let notch = chin, minZ = Infinity;
  for (let y = chin - 0.012; y > chin - 0.2; y -= 0.003) { const z = frontZ(y); if (z < minZ) minZ = z; else if (z > minZ + 0.01) { notch = y; break; } }
  // larghezza del collo: di lato, alla profondità del centro del collo, la minima tra metà collo e il mento
  let neckW = Infinity;
  for (let y = notch + 0.4 * (chin - notch); y < chin - 0.004; y += 0.003) { const s = slice(y).filter(p => p[2] < zc + 0.005 && p[2] > zc - 0.06 && Math.abs(p[0]) < 0.15); if (s.length) neckW = Math.min(neckW, ext(s, 0)); }
  const total = ymax - ymin;
  return { totale_m: +total.toFixed(4), T_m: +T.toFixed(4), altezza_in_T: +(total / T).toFixed(2), testa_larga_T: r(wSkull), testa_profonda_T: r(depth),
    con_orecchie_T: r(wEars), mascella_T: r(jaw), collo_largo_T: r(neckW), collo_visibile_T: r(chin - notch), mento_y: +chin.toFixed(4), incavo_y: +notch.toFixed(4) };
}

export async function measureBoth() {
  const before = measure(await load());
  const m2 = await load(); shapeHead(m2);
  return { before, after: measure(m2) };
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const { before, after } = await measureBoth();
  console.log('obiettivo: altezza 8 T · testa larga 0,68 T · profonda 0,82 T · collo visibile 0,35 T · collo largo 0,5 T');
  console.table({ prima: before, dopo: after });
}
