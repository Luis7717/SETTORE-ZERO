// Campo, luci e ombre (usato da render.js). Coordinate three: X = x, Y = altezza, Z = -y.
// - Erba: texture disegnata una volta (strisce di taglio nette, variazione naturale, usura, linee) + una piccola texture
//   di dettaglio ripetuta (ciuffi) mescolata nello shader: da vicino l'erba ha grana, da lontano resta pulita.
// - Luci: sole/faro principale caldo che fa ombre vere, cielo e rimbalzo dell'erba, controluce freddo.
// - Ombre: solo i giocatori le proiettano e solo il campo le riceve (una passata di profondità con ~22 oggetti);
//   il riquadro dell'ombra segue ciò che inquadra la telecamera, così resta nitida.
import * as THREE from 'three';
import { W, L, HW, HL, BOX_W, BOX_D, SIX_W, SIX_D, PEN_D, CIRCLE } from './sim.js';

export const SHADOWS = true;            // ombre vere dei giocatori (false = solo ombre finte sotto i piedi)
const PX = 16, MX = 10, MY = 12;        // pixel per metro della texture del campo, margini oltre le linee (m)
const PITCH = {
  light: '#4cab40', dark: '#3c9235',    // strisce di taglio chiare e scure (nette)
  lightEdge: '#53b345', darkEdge: '#378a31', // riflesso dentro la striscia (lato dell'erba piegata)
  stripes: 18,                          // strisce lungo il campo (5,5 m l'una; la linea di metà cade su un bordo)
  line: 'rgba(250,252,246,0.97)', lineW: 0.16, // linee bianche (larghezza in m)
};
const DETAIL = { size: 256, rep1: 1.6, rep2: 4.3, k: 0.4 }; // ciuffi: m per ripetizione (due scale), forza
const SUN = {
  color: 0xffe3b8, intensity: 2.1, dir: [-0.42, 0.78, -0.46], // da dietro-sinistra della porta lontana, alto ~51°
  shadowIntensity: 0.78, map: 2048, margin: 4, maxDist: 75,     // margine (m) e distanza massima inquadrata per l'ombra
};
const SKY = { sky: 0xd2e2ff, ground: 0x47682c, intensity: 0.95 };
const FILL = { color: 0xa8c0ff, intensity: 0.4, dir: [0.6, 0.5, 0.62] };
const FOG = { color: 0x5a6688, near: 95, far: 330 }; // foschia di profondità appena accennata (tribune lontane)

function canvasTex(w, h, draw, aniso) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = aniso;
  // ridisegno dopo che il canvas è stato svuotato (src/canvas-mem.js); i disegni del campo hanno il seme fisso
  t.userData.rebuild = () => { c.width = w; c.height = h; draw(c.getContext('2d'), w, h); return c; };
  return t;
}

// ---------------------------------------------------------------- texture del campo
function drawPitch(g, w, h) {
  let seed = 1234567; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  const X = x => (x + HW + MX) * PX, Y = y => (HL - y + MY) * PX;
  // strisce di taglio: bordo netto tra una striscia e l'altra, dentro una sfumatura leggera (erba piegata)
  const sh = (L * PX) / PITCH.stripes;
  for (let i = -3; i < PITCH.stripes + 3; i++) {
    const y0 = MY * PX + i * sh, odd = ((i % 2) + 2) % 2 === 1, gr = g.createLinearGradient(0, y0, 0, y0 + sh);
    gr.addColorStop(0, odd ? PITCH.lightEdge : PITCH.darkEdge); gr.addColorStop(0.45, odd ? PITCH.light : PITCH.dark); gr.addColorStop(1, odd ? PITCH.light : PITCH.dark);
    g.fillStyle = gr; g.fillRect(0, Math.floor(y0), w, Math.ceil(sh) + 1);
  }
  // taglio incrociato appena accennato (fasce lungo il campo)
  const sw = (W * PX) / 12;
  for (let i = 0; i < 12; i += 2) { g.fillStyle = 'rgba(255,255,230,0.025)'; g.fillRect(MX * PX + i * sw, 0, sw, h); }
  // variazione naturale: chiazze grandi e morbide, un po' più gialle o più scure
  for (let i = 0; i < 140; i++) {
    const x = rnd() * w, y = rnd() * h, r = (2 + rnd() * 8) * PX, gr = g.createRadialGradient(x, y, 0, x, y, r);
    gr.addColorStop(0, rnd() < 0.5 ? 'rgba(20,60,10,0.07)' : 'rgba(200,235,110,0.06)'); gr.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = gr; g.fillRect(x - r, y - r, r * 2, r * 2);
  }
  // usura leggera davanti alle porte, sul dischetto e al centro
  const wear = (x, y, rx, ry, a) => { g.save(); g.translate(X(x), Y(y)); g.scale(1, ry / rx); const r = rx * PX, gr = g.createRadialGradient(0, 0, 0, 0, 0, r); gr.addColorStop(0, `rgba(165,170,95,${a})`); gr.addColorStop(1, 'rgba(165,170,95,0)'); g.fillStyle = gr; g.fillRect(-r, -r, r * 2, r * 2); g.restore(); };
  for (const d of [1, -1]) { wear(0, d * (HL - 2.2), 6.5, 2.6, 0.16); wear(0, d * (HL - PEN_D), 1.4, 1.4, 0.14); }
  wear(0, 0, 2.4, 2.4, 0.07);
  // grana media (si vede a metà distanza, dove i ciuffi del dettaglio si sono già fusi)
  for (let i = 0; i < 9000; i++) { g.fillStyle = rnd() < 0.5 ? 'rgba(230,255,200,0.035)' : 'rgba(0,30,0,0.045)'; g.fillRect(rnd() * w, rnd() * h, 2, 2 + rnd() * 3); }
  // linee: un solo tratto netto (niente alone: da lontano restano pulite con mipmap + anisotropia)
  g.lineJoin = 'miter'; g.strokeStyle = PITCH.line; g.lineWidth = PITCH.lineW * PX;
  g.strokeRect(X(-HW), Y(HL), W * PX, L * PX);
  g.beginPath(); g.moveTo(X(-HW), Y(0)); g.lineTo(X(HW), Y(0)); g.stroke();
  g.beginPath(); g.arc(X(0), Y(0), CIRCLE * PX, 0, 7); g.stroke();
  for (const d of [1, -1]) {
    const gy = d * HL;
    g.strokeRect(X(-BOX_W / 2), Math.min(Y(gy), Y(gy - d * BOX_D)), BOX_W * PX, BOX_D * PX);
    g.strokeRect(X(-SIX_W / 2), Math.min(Y(gy), Y(gy - d * SIX_D)), SIX_W * PX, SIX_D * PX);
    g.beginPath(); const a = Math.acos((BOX_D - PEN_D) / CIRCLE);
    if (d > 0) g.arc(X(0), Y(gy - d * PEN_D), CIRCLE * PX, Math.PI / 2 - a, Math.PI / 2 + a); else g.arc(X(0), Y(gy - d * PEN_D), CIRCLE * PX, -Math.PI / 2 - a, -Math.PI / 2 + a);
    g.stroke();
    for (const sx of [1, -1]) { g.beginPath(); g.arc(X(sx * HW), Y(gy), 1 * PX, sx > 0 ? (d > 0 ? Math.PI / 2 : Math.PI) : (d > 0 ? 0 : -Math.PI / 2), sx > 0 ? (d > 0 ? Math.PI : Math.PI * 1.5) : (d > 0 ? Math.PI / 2 : 0)); g.stroke(); }
  }
  g.fillStyle = PITCH.line;
  for (const [x, y, r] of [[0, 0, 0.3], [0, HL - PEN_D, 0.22], [0, -(HL - PEN_D), 0.22]]) { g.beginPath(); g.arc(X(x), Y(y), r * PX, 0, 7); g.fill(); }
}

// ciuffi d'erba: rumore ripetibile senza cuciture (valori 0..1, media ~0.5), dato e non colore
function detailTex(aniso) {
  const n = DETAIL.size, c = document.createElement('canvas'); c.width = c.height = n;
  const g = c.getContext('2d'), img = g.createImageData(n, n), d = img.data;
  let seed = 98765; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  const G = 16, lat = Array.from({ length: G * G }, rnd); // reticolo avvolto: macchie morbide
  const val = (x, y) => {
    const fx = x / n * G, fy = y / n * G, x0 = Math.floor(fx), y0 = Math.floor(fy), tx = fx - x0, ty = fy - y0;
    const at = (i, j) => lat[((j % G + G) % G) * G + ((i % G + G) % G)], s = t => t * t * (3 - 2 * t);
    const a = at(x0, y0) + (at(x0 + 1, y0) - at(x0, y0)) * s(tx), b = at(x0, y0 + 1) + (at(x0 + 1, y0 + 1) - at(x0, y0 + 1)) * s(tx);
    return a + (b - a) * s(ty);
  };
  for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
    const v = 0.5 + (val(x, y) - 0.5) * 0.45 + (rnd() - 0.5) * 0.5, k = (y * n + x) * 4, b = Math.max(0, Math.min(255, v * 255));
    d[k] = d[k + 1] = d[k + 2] = b; d[k + 3] = 255;
  }
  g.putImageData(img, 0, 0);
  // fili corti un po' più chiari e più scuri
  for (let i = 0; i < 2600; i++) {
    const x = rnd() * n, y = rnd() * n, l = 2 + rnd() * 4, a = rnd() * Math.PI;
    g.strokeStyle = rnd() < 0.5 ? 'rgba(255,255,255,0.35)' : 'rgba(0,0,0,0.35)'; g.lineWidth = 1;
    for (const ox of [0, -n, n]) for (const oy of [0, -n, n]) { g.beginPath(); g.moveTo(x + ox, y + oy); g.lineTo(x + ox + Math.cos(a) * l, y + oy + Math.sin(a) * l); g.stroke(); }
  }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.NoColorSpace; t.wrapS = t.wrapT = THREE.RepeatWrapping; t.anisotropy = aniso;
  t.userData.rebuild = () => detailTex(aniso).image; // stesso seme: stesso disegno
  return t;
}

// mesh del campo: texture grande + ciuffi ripetuti (due scale, per non vedere la ripetizione), riceve le ombre
export function buildPitch(scene, renderer) {
  const t0 = performance.now(), aniso = renderer.capabilities.getMaxAnisotropy();
  const pw = W + MX * 2, ph = L + MY * 2;
  const tex = canvasTex(pw * PX, ph * PX, drawPitch, aniso);
  const det = detailTex(aniso);
  const mat = new THREE.MeshLambertMaterial({ map: tex });
  mat.onBeforeCompile = (sh) => {
    sh.uniforms.grassDetail = { value: det };
    sh.fragmentShader = 'uniform sampler2D grassDetail;\n' + sh.fragmentShader.replace('#include <map_fragment>', `#include <map_fragment>
  float gd = texture2D(grassDetail, vMapUv * vec2(${(pw / DETAIL.rep1).toFixed(2)}, ${(ph / DETAIL.rep1).toFixed(2)})).r * 0.6
           + texture2D(grassDetail, vMapUv * vec2(${(pw / DETAIL.rep2).toFixed(2)}, ${(ph / DETAIL.rep2).toFixed(2)}) + vec2(0.37, 0.11)).r * 0.4;
  diffuseColor.rgb *= ${(1 - DETAIL.k).toFixed(2)} + ${(2 * DETAIL.k).toFixed(2)} * gd;`);
  };
  mat.customProgramCacheKey = () => 'tag-pitch';
  const pitch = new THREE.Mesh(new THREE.PlaneGeometry(pw, ph), mat);
  pitch.rotation.x = -Math.PI / 2; pitch.receiveShadow = SHADOWS; scene.add(pitch);
  return { mesh: pitch, ms: performance.now() - t0, textures: [tex, det] }; // render.js ne svuota i canvas dopo il caricamento
}

// ---------------------------------------------------------------- luci, ombre, tonemapping
export function setupRenderer(r) {
  // tonemapping neutro: i colori restano quelli scelti (erba viva), le luci forti non si "bruciano"
  r.toneMapping = THREE.NeutralToneMapping; r.toneMappingExposure = 1.06;
  r.shadowMap.enabled = SHADOWS; r.shadowMap.type = THREE.PCFShadowMap;
}

export function buildLights(scene) {
  scene.add(new THREE.HemisphereLight(SKY.sky, SKY.ground, SKY.intensity));
  const sun = new THREE.DirectionalLight(SUN.color, SUN.intensity);
  const fill = new THREE.DirectionalLight(FILL.color, FILL.intensity);
  fill.position.set(FILL.dir[0] * 100, FILL.dir[1] * 100, FILL.dir[2] * 100);
  scene.add(sun, sun.target, fill);
  scene.fog = new THREE.Fog(FOG.color, FOG.near, FOG.far);
  if (SHADOWS) {
    sun.castShadow = true; sun.shadow.mapSize.set(SUN.map, SUN.map); sun.shadow.intensity = SUN.shadowIntensity;
    sun.shadow.bias = -0.0004; sun.shadow.normalBias = 0; sun.shadow.radius = 1;
    sun.shadow.autoUpdate = true;
    const c = sun.shadow.camera; c.near = 10; c.far = 320;
  }
  return { sun, fill, flip: 0, v: new THREE.Vector3() };
}

// direzione dell'ombra a terra (radianti, attorno a Y) per le ombre finte; segue lo specchio della visuale
export function shadowYaw(flip) { return Math.atan2(SUN.dir[0] * flip, SUN.dir[2] * flip); }

// il sole viene sempre dallo stesso lato rispetto alla telecamera; il riquadro dell'ombra copre solo il campo inquadrato
export function fitSun(lights, cam, flip) {
  const { sun, fill, v } = lights, s = flip || 1;
  if (lights.flip !== s) {
    lights.flip = s;
    sun.position.set(SUN.dir[0] * s * 120, SUN.dir[1] * 120, SUN.dir[2] * s * 120); sun.target.position.set(0, 0, 0);
    fill.position.set(FILL.dir[0] * s * 100, FILL.dir[1] * 100, FILL.dir[2] * s * 100);
    sun.updateMatrixWorld(); sun.target.updateMatrixWorld();
    const c = sun.shadow.camera; c.position.copy(sun.position); c.lookAt(0, 0, 0); c.updateMatrixWorld();
  }
  if (!SHADOWS) return;
  const c = sun.shadow.camera, inv = c.matrixWorldInverse, o = cam.position;
  let x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
  const lim = (a, m) => Math.max(-m, Math.min(m, a));
  for (const [nx, ny] of [[-1, -1], [1, -1], [-1, 1], [1, 1], [0, 1]]) {
    v.set(nx, ny, 0.5).unproject(cam).sub(o);
    let t = v.y < -1e-4 ? -o.y / v.y : Infinity;
    const hd = Math.hypot(v.x, v.z) * t; if (hd > SUN.maxDist) t = SUN.maxDist / Math.hypot(v.x, v.z);
    const px = lim(o.x + v.x * t, HW + SUN.margin), pz = lim(o.z + v.z * t, HL + SUN.margin);
    for (const h of [0, 2.2]) { // a terra e all'altezza della testa (le ombre dei giocatori a bordo inquadratura)
      v.set(px, h, pz).applyMatrix4(inv);
      x0 = Math.min(x0, v.x); x1 = Math.max(x1, v.x); y0 = Math.min(y0, v.y); y1 = Math.max(y1, v.y);
    }
  }
  // dimensione a gradini di 4 m e bordi agganciati ai texel: l'ombra non "trema" mentre la telecamera si muove
  const m = SUN.margin, step = 4, size = Math.ceil((Math.max(x1 - x0, y1 - y0) + 2 * m) / step) * step, tx = size / SUN.map;
  const cx = Math.round((x0 + x1) / 2 / tx) * tx, cy = Math.round((y0 + y1) / 2 / tx) * tx;
  if (c.left !== cx - size / 2 || c.bottom !== cy - size / 2 || c.right !== cx + size / 2) {
    c.left = cx - size / 2; c.right = cx + size / 2; c.bottom = cy - size / 2; c.top = cy + size / 2; c.updateProjectionMatrix();
  }
}

// ombra finta ai piedi di un giocatore: con le ombre vere resta solo la macchia di contatto (piedi "appoggiati");
// senza, anche un'ombra allungata verso il lato opposto al sole
export function playerShadowTexture(aniso) {
  return canvasTex(128, 128, (g) => {
    if (!SHADOWS) {
      g.save(); g.translate(64, 64); g.rotate(-Math.PI / 2); g.translate(28, 0); g.scale(1, 0.3);
      const gr = g.createRadialGradient(0, 0, 0, 0, 0, 34); gr.addColorStop(0, 'rgba(0,0,0,0.42)'); gr.addColorStop(1, 'rgba(0,0,0,0)');
      g.fillStyle = gr; g.fillRect(-34, -34, 68, 68); g.restore();
    }
    const gr = g.createRadialGradient(64, 64, 1, 64, 64, 30); gr.addColorStop(0, 'rgba(0,0,0,0.5)'); gr.addColorStop(0.5, 'rgba(0,0,0,0.3)'); gr.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = gr; g.fillRect(0, 0, 128, 128);
  }, aniso);
}
