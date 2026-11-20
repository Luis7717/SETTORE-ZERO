// Cartelloni LED a bordo campo e fascia LED tra i due anelli, con sponsor inventati.
// Una texture 1024×1024: 16 righe (una per sponsor), ognuna con due grafiche da 512×64 (marchio e slogan).
// Come negli stadi veri i cartelloni girano tutti insieme: di solito lo stesso sponsor su tutta la linea,
// a volte un mosaico di sponsor diversi; il cambio scorre in verticale e corre lungo la linea (shader).
import * as THREE from 'three';
import { canvasTex, fitText, shade } from './stadium-kit.js';

export const AD_DESIGN_M = 7.6;            // metri di cartellone per una grafica (512×64 px su 0.95 m di altezza)
const AD_U_PER_M = 0.5 / AD_DESIGN_M;      // u per metro (la riga della texture contiene due grafiche)
const ROWS = 16, ROW_H = 64;
const AD_HOLD = 7, AD_FLIP = 0.9;          // secondi fermi e durata del cambio

// [nome, slogan, colore, colore 2, icona] — tutti inventati
const BRANDS = [
  ['TIRO A GIRO', 'IL CALCIO A UN DITO', '#0b3d91', '#ffd43b', 'ball'],
  ['CAFFÈ BORGO', 'IL CAFFÈ DEL QUARTIERE', '#5a2f17', '#f2d1a0', 'cup'],
  ['GELATERIA STELLA', 'GUSTO DA CAMPIONI', '#d6336c', '#fff0f6', 'star'],
  ['FORNO DEL CORSO', 'PANE FRESCO OGNI GIORNO', '#c77700', '#fff4d6', 'loaf'],
  ['RADIO CURVA', 'LA VOCE DELLO STADIO', '#5b2a86', '#e9d8ff', 'waves'],
  ['PIZZERIA DA NINO', 'FORNO A LEGNA DAL 1987', '#b3122b', '#ffe8a3', 'slice'],
  ['OFFICINA ROSSI', 'RIPARAZIONI IN GIORNATA', '#14606e', '#d3f2f7', 'gear'],
  ['PASTA MONTI', 'TRAFILATA AL BRONZO', '#e0a100', '#1d2a6b', 'peaks'],
  ['BICI LAMPO', 'PEDALA PIÙ VELOCE', '#0f7a55', '#d9ffef', 'bolt'],
  ['ACQUA LIMPIDELLA', "L'ACQUA DEI CAMPIONI", '#1d7fc4', '#e3f4ff', 'drop'],
  ['MOBILI GIRARDI', 'CASA TUA, STILE TUO', '#7a4e2d', '#f5e6d3', 'square'],
  ['FERRAMENTA BRUNO', 'TUTTO PER IL FAI DA TE', '#c44e00', '#fff', 'gear'],
  ['LATTERIA ALPINA', 'LATTE DI MONTAGNA', '#2b7bb9', '#fff', 'peaks'],
  ['TAXI 777', 'SEMPRE IN ORARIO', '#e5b800', '#111', 'check'],
  ['CARTOLERIA LUNA', 'QUADERNI E SOGNI', '#3a3f9e', '#ffe9a8', 'moon'],
  ['AUTO CORTI', 'GUIDA SICURA', '#a11d1d', '#fff', 'wheel'],
];

function icon(g, kind, x, y, r, col) {
  g.save(); g.translate(x, y); g.fillStyle = col; g.strokeStyle = col; g.lineWidth = r * 0.22; g.lineCap = 'round';
  const star = (n, ro, ri) => { g.beginPath(); for (let k = 0; k < n * 2; k++) { const a = k * Math.PI / n - Math.PI / 2, rr = k % 2 ? ri : ro; g.lineTo(Math.cos(a) * rr, Math.sin(a) * rr); } g.closePath(); g.fill(); };
  switch (kind) {
    case 'ball': g.beginPath(); g.arc(r * 0.25, -r * 0.2, r * 0.55, 0, 7); g.fill(); g.beginPath(); g.arc(-r * 0.2, r * 0.4, r * 0.9, Math.PI * 1.05, Math.PI * 1.7); g.stroke(); break;
    case 'cup': g.beginPath(); g.moveTo(-r * 0.7, -r * 0.3); g.lineTo(r * 0.5, -r * 0.3); g.lineTo(r * 0.35, r * 0.7); g.lineTo(-r * 0.55, r * 0.7); g.fill(); g.beginPath(); g.arc(r * 0.55, r * 0.1, r * 0.28, -1.5, 1.5); g.stroke();
      for (const sx of [-0.35, 0.1]) { g.beginPath(); g.moveTo(r * sx, -r * 0.5); g.quadraticCurveTo(r * (sx + 0.2), -r * 0.75, r * sx, -r * 0.95); g.stroke(); } break;
    case 'star': star(5, r, r * 0.42); break;
    case 'loaf': g.beginPath(); g.ellipse(0, 0, r, r * 0.55, 0, 0, 7); g.fill(); g.strokeStyle = 'rgba(0,0,0,0.35)'; for (const k of [-0.4, 0, 0.4]) { g.beginPath(); g.moveTo(r * k - r * 0.15, -r * 0.3); g.lineTo(r * k + r * 0.15, r * 0.3); g.stroke(); } break;
    case 'waves': g.beginPath(); g.arc(-r * 0.6, 0, r * 0.18, 0, 7); g.fill(); for (const k of [0.5, 0.9]) { g.beginPath(); g.arc(-r * 0.6, 0, r * k * 1.2, -0.8, 0.8); g.stroke(); } break;
    case 'slice': g.beginPath(); g.moveTo(0, r); g.lineTo(-r * 0.8, -r * 0.6); g.quadraticCurveTo(0, -r * 1.05, r * 0.8, -r * 0.6); g.fill(); break;
    case 'gear': star(8, r, r * 0.72); g.globalCompositeOperation = 'destination-out'; g.beginPath(); g.arc(0, 0, r * 0.3, 0, 7); g.fill(); break;
    case 'peaks': g.beginPath(); g.moveTo(-r, r * 0.7); g.lineTo(-r * 0.3, -r * 0.6); g.lineTo(0.05 * r, 0); g.lineTo(r * 0.4, -r * 0.8); g.lineTo(r, r * 0.7); g.fill(); break;
    case 'bolt': g.beginPath(); g.moveTo(r * 0.2, -r); g.lineTo(-r * 0.55, r * 0.15); g.lineTo(-r * 0.05, r * 0.15); g.lineTo(-r * 0.25, r); g.lineTo(r * 0.55, -r * 0.15); g.lineTo(r * 0.05, -r * 0.15); g.fill(); break;
    case 'drop': g.beginPath(); g.moveTo(0, -r); g.quadraticCurveTo(r * 0.8, 0, r * 0.6, r * 0.4); g.arc(0, r * 0.4, r * 0.6, 0, Math.PI); g.quadraticCurveTo(-r * 0.8, 0, 0, -r); g.fill(); break;
    case 'square': g.fillRect(-r * 0.7, -r * 0.7, r * 0.6, r * 0.6); g.fillRect(r * 0.1, -r * 0.7, r * 0.6, r * 0.6); g.fillRect(-r * 0.7, r * 0.1, r * 1.4, r * 0.6); break;
    case 'check': for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) if ((i + j) % 2 === 0) g.fillRect(-r + i * r * 0.66, -r + j * r * 0.66, r * 0.66, r * 0.66); g.strokeRect(-r, -r, r * 2, r * 2); break;
    case 'moon': g.beginPath(); g.arc(0, 0, r * 0.85, 0, 7); g.fill(); g.globalCompositeOperation = 'destination-out'; g.beginPath(); g.arc(r * 0.4, -r * 0.2, r * 0.7, 0, 7); g.fill(); break;
    default: g.beginPath(); g.arc(0, 0, r * 0.85, 0, 7); g.stroke(); g.beginPath(); g.arc(0, 0, r * 0.25, 0, 7); g.fill();
  }
  g.restore();
}

// grafica 512×64: logo (variante 0) o slogan su fondo invertito (variante 1)
function drawAd(g, x, y, brand, variant) {
  const [name, slogan, c1, c2, ic] = brand, W = 512, H = ROW_H;
  g.save(); g.translate(x, y); g.beginPath(); g.rect(0, 0, W, H); g.clip();
  const bg = variant === 0 ? c1 : '#0c0f16', fg = variant === 0 ? c2 : c1 === '#e5b800' || c1 === '#e0a100' ? c1 : shade(c1, 0.35);
  const gr = g.createLinearGradient(0, 0, 0, H); gr.addColorStop(0, shade(bg, 0.14)); gr.addColorStop(0.5, bg); gr.addColorStop(1, shade(bg, -0.3));
  g.fillStyle = gr; g.fillRect(0, 0, W, H);
  g.textBaseline = 'middle';
  if (variant === 0) {
    g.fillStyle = 'rgba(255,255,255,0.08)'; g.beginPath(); g.moveTo(330, 0); g.lineTo(400, 0); g.lineTo(350, H); g.lineTo(280, H); g.fill();
    icon(g, ic, 52, 33, 21, fg);
    g.fillStyle = fg; g.textAlign = 'left'; fitText(g, name, 92, 35, 400, 40);
  } else {
    g.fillStyle = c1; g.fillRect(0, 0, 14, H); g.fillRect(W - 14, 0, 14, H);
    icon(g, ic, 46, 33, 17, fg);
    g.fillStyle = '#ffffff'; g.textAlign = 'center'; fitText(g, slogan, 270, 25, 400, 22, 800);
    g.fillStyle = fg; fitText(g, name, 270, 48, 400, 16, 900);
  }
  g.fillStyle = '#040507'; g.fillRect(0, 0, W, 2); g.fillRect(0, H - 2, W, 2);
  g.restore();
}
export function adsTexture() {
  const t = canvasTex(1024, 1024, (g) => { BRANDS.forEach((b, r) => { drawAd(g, 0, r * ROW_H, b, 0); drawAd(g, 512, r * ROW_H, b, 1); }); });
  t.wrapS = THREE.RepeatWrapping;
  return t;
}

// Geometria di un nastro LED: parete rivolta verso -z nel sistema locale, da xl a xr (xl > xr, visti dal campo).
// u = metri dall'inizio della linea (continuo, così le grafiche corrono da un pannello all'altro), v = 0..1.
export function ledStrip(qb, xl, xr, z, y0, y1, startM) {
  const u0 = startM * AD_U_PER_M, u1 = (startM + (xl - xr)) * AD_U_PER_M;
  qb.quad([xl, y0, z], [xr, y0, z], [xr, y1, z], [xl, y1, z], new THREE.Color(1, 1, 1), [u0, 0, u1, 1], [0, 0, -1]);
}

// materiale LED: sceglie la riga (sponsor) nello shader; niente tonemapping, così i colori restano accesi
export function adsMaterial(map, uniforms) {
  const m = new THREE.MeshBasicMaterial({ map, toneMapped: false });
  m.onBeforeCompile = (sh) => {
    for (const k of ['uAdA', 'uAdB', 'uAdFlip', 'uAdMosA', 'uAdMosB']) sh.uniforms[k] = uniforms[k];
    sh.fragmentShader = 'uniform float uAdA;\nuniform float uAdB;\nuniform float uAdFlip;\nuniform float uAdMosA;\nuniform float uAdMosB;\n'
      + sh.fragmentShader.replace('#include <map_fragment>', ADS_FRAG);
  };
  m.customProgramCacheKey = () => 'tag-ads';
  return m;
}
const ADS_FRAG = /* glsl */`
#ifdef USE_MAP
  vec2 uv0 = vMapUv;
  float panel = floor(uv0.x * 2.0);
  float p = clamp(uAdFlip * 1.8 - fract(uv0.x * 0.045), 0.0, 1.0);
  p = p * p * (3.0 - 2.0 * p);
  float s = uv0.y + p;
  float useB = step(1.0, s);
  float shift = mod(panel * 5.0, 16.0) * mix(uAdMosA, uAdMosB, useB);
  float row = mod(mix(uAdA, uAdB, useB) + shift, 16.0);
  float ly = clamp(fract(s), 0.03, 0.97);
  vec2 suv = vec2(uv0.x, 1.0 - (row + 1.0 - ly) / 16.0);
  vec2 sc = vec2(1.0, 0.0625);
  vec4 sampledDiffuseColor = textureGrad(map, suv, dFdx(uv0) * sc, dFdy(uv0) * sc);
  float seam = mix(1.0, smoothstep(0.0, 0.05, fract(s)) * smoothstep(1.0, 0.95, fract(s)), step(0.001, p) * step(p, 0.999));
  diffuseColor *= sampledDiffuseColor * seam;
#endif
`;

// stato dei cartelloni: il giro k mostra lo sponsor row(k); nei primi AD_FLIP secondi di ogni giro
// si passa dal precedente al nuovo. Un giro ogni quattro è a mosaico.
export function adsTicker(uniforms) {
  let t = 0;
  const row = k => (k * 5) % ROWS, mos = k => (k % 4 === 3 ? 1 : 0);
  return (dt) => {
    t += dt;
    const cyc = AD_HOLD + AD_FLIP, k = Math.floor(t / cyc), f = (t % cyc) / AD_FLIP;
    const flipping = k > 0 && f < 1, a = flipping ? k - 1 : k;
    uniforms.uAdA.value = row(a); uniforms.uAdMosA.value = mos(a);
    uniforms.uAdB.value = row(k); uniforms.uAdMosB.value = mos(k);
    uniforms.uAdFlip.value = flipping ? f : 0;
  };
}
