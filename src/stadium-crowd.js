// Pubblico dello stadio e bandiere che sventolano.
// Pubblico: una texture 1024×1024 con 4 righe di tifosi calmi (in alto) e le stesse persone in festa (in basso):
// righe 0-1 tifosi di casa misti, riga 2 curva (più sciarpe e colori di casa), riga 3 settore ospiti.
// Salti, braccia alzate e ola sono decisi nel fragment shader, persona per persona, con una funzione hash.
// Bandiere: una sola geometria; sventolio e oscillazione a mano nel vertex shader.
import * as THREE from 'three';
import { canvasTex, redrawTex, rnd, pick, shade } from './stadium-kit.js';

export const CELLS = 40;            // persone per riga della texture
export const SEAT_W = 0.5;          // metri per persona
export const TILE = SEAT_W * CELLS; // metri coperti da una riga della texture
export const CROWD_H = 2.2;         // altezza della striscia di una fila (metri; le persone escono un po' tarchiate, come viste dall'alto)
export const CROWD_VARIANTS = { home: [0, 1], curva: 2, away: 3 };
const CELL_W = 1024 / CELLS, STRIP = 128;

// ---------------------------------------------------------------- texture del pubblico
const NEUTRAL_DARK = ['#22252c', '#2c313b', '#363b46', '#1d2a40', '#3a2f28', '#2b2b2b', '#41464f'];
const NEUTRAL_LIGHT = ['#c9ccd2', '#e4e6ea', '#9aa0aa', '#b7a98c'];
const SKIN = ['#f1c9a5', '#e0b48c', '#c68f63', '#a8714a', '#8d5a3b', '#5e3b26'];
const HAIR = ['#1c1410', '#3a2414', '#6b4423', '#c9a45c', '#8a8a8a', '#111'];

function shirtFor(variant, home, away) {
  const r = Math.random();
  if (variant === CROWD_VARIANTS.away) return r < 0.5 ? away[0] : r < 0.68 ? away[1] : r < 0.9 ? pick(NEUTRAL_DARK) : pick(NEUTRAL_LIGHT);
  const homeShare = variant === CROWD_VARIANTS.curva ? 0.62 : 0.42;
  if (r < homeShare) return home[0];
  if (r < homeShare + 0.14) return home[1];
  if (r < homeShare + 0.17) return away[0];
  return Math.random() < 0.8 ? pick(NEUTRAL_DARK) : pick(NEUTRAL_LIGHT);
}
function personLook(variant, home, away) {
  const team = variant === CROWD_VARIANTS.away ? away : home, curva = variant === CROWD_VARIANTS.curva;
  return {
    empty: Math.random() < (variant === CROWD_VARIANTS.away ? 0.1 : 0.03),
    shirt: shade(shirtFor(variant, home, away), rnd(-0.22, 0.08)),
    w: rnd(20, 27), h: rnd(46, 58), dy: rnd(-4, 3),
    skin: pick(SKIN), hair: pick(HAIR),
    cap: Math.random() < 0.12 ? pick([team[0], team[1], '#15171c']) : null,
    hood: Math.random() < 0.08,
    scarf: Math.random() < (curva ? 0.7 : 0.38) ? team : null,
    flag: Math.random() < (curva ? 0.06 : 0.025) ? team : null,
    clap: Math.random() < 0.25,
  };
}
function drawPerson(g, x, y, p, up) {
  const cx = x + CELL_W / 2, base = y + STRIP - 1, top = base - p.h + p.dy, l = cx - p.w / 2, hy = top - 7, r = p.w / 2;
  if (p.flag && up) {
    g.fillStyle = '#d8d8d8'; g.fillRect(cx + 6, y + 2, 2, top - y);
    g.fillStyle = p.flag[0]; g.fillRect(cx - 16, y + 3, 22, 8); g.fillStyle = p.flag[1]; g.fillRect(cx - 16, y + 11, 22, 8);
  }
  g.fillStyle = p.shirt;
  if (up) { // braccia alzate
    g.beginPath(); g.moveTo(l + 2, top + 8); g.lineTo(l - 4, top - 30); g.lineTo(l + 2, top - 31); g.lineTo(l + 7, top + 6); g.fill();
    g.beginPath(); g.moveTo(l + p.w - 2, top + 8); g.lineTo(l + p.w + 4, top - 30); g.lineTo(l + p.w - 2, top - 31); g.lineTo(l + p.w - 7, top + 6); g.fill();
  }
  // busto con spalle arrotondate, luce dall'alto
  g.beginPath(); g.roundRect(l, top, p.w, base - top + 1, [r * 0.8, r * 0.8, 0, 0]); g.fill();
  // luce dall'alto sulle spalle, ombra in basso (fasce semitrasparenti: molto più veloci dei gradienti)
  g.fillStyle = 'rgba(255,255,255,0.16)'; g.fillRect(l + 3, top + 1, p.w - 6, 4);
  const hgt = base - top;
  g.fillStyle = 'rgba(0,0,0,0.14)'; g.fillRect(l, top + hgt * 0.45, p.w, hgt * 0.55 + 1);
  g.fillStyle = 'rgba(0,0,0,0.16)'; g.fillRect(l, top + hgt * 0.72, p.w, hgt * 0.28 + 1);
  g.fillStyle = 'rgba(0,0,0,0.28)'; g.fillRect(l, top + 10, 1.5, base - top - 10); g.fillRect(l + p.w - 1.5, top + 10, 1.5, base - top - 10);
  if (!up) {
    g.fillStyle = 'rgba(0,0,0,0.25)'; g.fillRect(l + 3, top + 12, 2.5, 22); g.fillRect(l + p.w - 5.5, top + 12, 2.5, 22);
    if (p.clap) { g.fillStyle = p.skin; g.beginPath(); g.arc(cx, top + 20, 3, 0, 7); g.fill(); }
  }
  if (p.scarf && !up) { g.fillStyle = p.scarf[0]; g.fillRect(l + 2, top + 1, p.w - 4, 5); g.fillStyle = p.scarf[1]; g.fillRect(cx - 2.5, top + 6, 5, 16); g.fillStyle = p.scarf[0]; g.fillRect(cx - 2.5, top + 12, 5, 4); }
  // testa
  if (p.hood) { g.fillStyle = shade(p.shirt, -0.15); g.beginPath(); g.arc(cx, hy, 8.5, 0, 7); g.fill(); }
  g.fillStyle = p.skin; g.beginPath(); g.ellipse(cx, hy + 0.5, 6.2, 7.2, 0, 0, 7); g.fill();
  g.fillStyle = 'rgba(0,0,0,0.18)'; g.beginPath(); g.ellipse(cx, hy + 4, 5.5, 3, 0, 0, Math.PI); g.fill();
  if (!p.hood) { g.fillStyle = p.cap || p.hair; g.beginPath(); g.arc(cx, hy - 1, 6.8, Math.PI, 0); g.fill(); if (p.cap) g.fillRect(cx - 8, hy - 2, 16, 2.2); }
  if (up) {
    g.fillStyle = p.skin; g.beginPath(); g.arc(l - 2, top - 32, 3.2, 0, 7); g.arc(l + p.w + 2, top - 32, 3.2, 0, 7); g.fill();
    if (p.scarf) { // sciarpa tesa sopra la testa
      g.fillStyle = p.scarf[0]; g.fillRect(l - 4, top - 36, p.w + 8, 7);
      g.fillStyle = p.scarf[1]; for (let k = 0; k < p.w + 8; k += 7) g.fillRect(l - 4 + k, top - 36, 3.5, 7);
    }
  }
}
function drawCrowd(g, home, away) {
  for (let v = 0; v < 4; v++) {
    const people = [];
    for (let j = 0; j < CELLS; j++) people.push(personLook(v, home, away));
    // prima le persone più basse (dietro), poi quelle davanti: le spalle si sovrappongono come in una folla vera
    const order = people.map((p, j) => j).sort((a, b) => people[a].h - people[b].h);
    for (const up of [false, true]) for (const j of order) {
      const p = people[j]; if (p.empty) continue;
      drawPerson(g, j * CELL_W, (up ? 4 : 0) * STRIP + v * STRIP, p, up);
    }
  }
}
export function crowdTexture(home, away) {
  const t = canvasTex(1024, 1024, (g) => drawCrowd(g, home, away));
  t.wrapS = THREE.RepeatWrapping;
  t.redraw = (h, a) => redrawTex(t, (g) => drawCrowd(g, h, a));
  return t;
}

// ---------------------------------------------------------------- materiale del pubblico
// uExcite: 0 calmi, 1 festa (gol). uOla: angolo (radianti, attorno al centro del campo) della cresta dell'ola;
// uOlaAmp: 0 niente ola, 1 ola in corso.
export function crowdMaterial(map, uniforms) {
  const m = new THREE.MeshBasicMaterial({ map, vertexColors: true, alphaTest: 0.45 });
  m.onBeforeCompile = (sh) => {
    for (const k of ['uTime', 'uExcite', 'uOla', 'uOlaAmp']) sh.uniforms[k] = uniforms[k];
    sh.vertexShader = 'varying float vAng;\n' + sh.vertexShader.replace('#include <project_vertex>',
      '#include <project_vertex>\n  vec4 wpCrowd = modelMatrix * vec4(transformed, 1.0);\n  vAng = atan(wpCrowd.x, wpCrowd.z * 0.62);');
    sh.fragmentShader = 'uniform float uTime;\nuniform float uExcite;\nuniform float uOla;\nuniform float uOlaAmp;\nvarying float vAng;\n'
      + sh.fragmentShader.replace('#include <map_fragment>', CROWD_FRAG);
  };
  m.customProgramCacheKey = () => 'tag-crowd-2';
  return m;
}
const CROWD_FRAG = /* glsl */`
#ifdef USE_MAP
  vec2 uv0 = vMapUv;
  float cell = floor(uv0.x * ${CELLS}.0);
  float rowId = floor(uv0.y * 8.0);
  float h = fract(sin(cell * 12.9898 + rowId * 78.233) * 43758.5453);
  float local = fract(uv0.y * 8.0);
  float d = abs(mod(vAng - uOla + 3.14159, 6.28318) - 3.14159);
  float ola = uOlaAmp * smoothstep(0.42, 0.08, d + h * 0.08);
  float up = max(step(h, uExcite * 0.95 - 0.08), step(0.45, ola));
  float idle = (0.5 + 0.5 * sin(uTime * (1.2 + h) + h * 40.0)) * 0.01;
  float hop = uExcite * max(0.0, sin(uTime * (7.0 + 5.0 * h) + h * 60.0)) * 0.11 * step(0.2, h) + ola * 0.1;
  local = clamp(local - idle - hop, 0.004, 0.996);
  vec2 suv = vec2(uv0.x, (rowId + local) * 0.125 - up * 0.5);
  vec4 sampledDiffuseColor = textureGrad(map, suv, dFdx(uv0), dFdy(uv0));
  diffuseColor *= sampledDiffuseColor;
#endif
`;

// ---------------------------------------------------------------- bandiere
// texture 512×256: 4×4 disegni da 128×64. Righe 0-2 colori di casa, riga 3 ospiti.
const FLAG_W = 128, FLAG_H = 64;
function drawFlag(g, x, y, kind, a, b) {
  g.save(); g.translate(x, y); g.beginPath(); g.rect(0, 0, FLAG_W, FLAG_H); g.clip();
  g.fillStyle = a; g.fillRect(0, 0, FLAG_W, FLAG_H); g.fillStyle = b;
  switch (kind % 8) {
    case 0: g.fillRect(FLAG_W / 2, 0, FLAG_W / 2, FLAG_H); break;                                   // metà e metà
    case 1: g.fillRect(0, FLAG_H / 2, FLAG_W, FLAG_H / 2); break;                                   // sopra e sotto
    case 2: for (let k = 1; k < 6; k += 2) g.fillRect(k * FLAG_W / 6, 0, FLAG_W / 6, FLAG_H); break; // strisce
    case 3: g.beginPath(); g.moveTo(0, FLAG_H); g.lineTo(FLAG_W, 0); g.lineTo(FLAG_W, FLAG_H); g.fill(); break;
    case 4: g.beginPath(); g.moveTo(0, 0); g.lineTo(FLAG_W * 0.45, FLAG_H / 2); g.lineTo(0, FLAG_H); g.fill(); break; // punta
    case 5: { g.beginPath(); for (let k = 0; k < 10; k++) { const r = k % 2 ? 9 : 22, an = k * Math.PI / 5 - Math.PI / 2; g.lineTo(64 + Math.cos(an) * r, 32 + Math.sin(an) * r); } g.fill(); break; } // stella
    case 6: for (let k = 0; k < 4; k++) g.fillRect(0, k * 16 + 8, FLAG_W, 6); break;                // righe sottili
    default: g.beginPath(); g.arc(64, 32, 20, 0, 7); g.fill(); g.fillStyle = a; g.beginPath(); g.arc(64, 32, 11, 0, 7); g.fill(); // anello
  }
  // stemma del tifo al centro (pallone in un anello): la bandiera è di una squadra, non di una nazione
  if (kind % 8 !== 5 && kind % 8 !== 7) {
    const cx = kind % 8 === 4 ? 78 : 64;
    g.fillStyle = b; g.beginPath(); g.arc(cx, 32, 17, 0, 7); g.fill();
    g.fillStyle = a; g.beginPath(); g.arc(cx, 32, 13, 0, 7); g.fill();
    g.fillStyle = '#ffffff'; g.beginPath(); g.arc(cx, 32, 8, 0, 7); g.fill();
    g.fillStyle = '#15171c'; g.beginPath(); for (let k = 0; k < 5; k++) { const an = k * 1.2566 - 1.57; g.lineTo(cx + Math.cos(an) * 3.5, 32 + Math.sin(an) * 3.5); } g.fill();
  }
  g.fillStyle = 'rgba(0,0,0,0.25)'; g.fillRect(0, 0, 5, FLAG_H);
  g.restore();
}
function drawFlags(g, home, away) {
  for (let r = 0; r < 4; r++) for (let c = 0; c < 4; c++) {
    const [a, b] = r === 3 ? away : home, swap = (r + c) % 3 === 2;
    drawFlag(g, c * FLAG_W, r * FLAG_H, r * 4 + c + (r === 3 ? 1 : 0), swap ? b : a, swap ? a : b);
  }
}
export function flagTexture(home, away) {
  const t = canvasTex(512, 256, (g) => drawFlags(g, home, away));
  t.redraw = (h, a) => redrawTex(t, (g) => drawFlags(g, h, a));
  return t;
}
const flagUV = (i) => { const c = i % 4, r = (i / 4) | 0; return [c / 4 + 0.004, 1 - (r + 1) / 4 + 0.008, (c + 1) / 4 - 0.004, 1 - r / 4 - 0.008]; };

// Costruttore delle bandiere, nel sistema locale di una tribuna (x lungo, z verso l'esterno, il campo a -z).
// Ogni vertice porta: perno (piede dell'asta) e fase, asse di oscillazione (verso il campo), ampiezza
// dell'oscillazione a mano e posizione lungo il telo (0 all'asta, 1 in punta).
const FLAG_SEG = 6;
export class FlagBuilder {
  constructor() { this.pos = []; this.uv = []; this.piv = []; this.ax = []; }
  _v(p, uv, piv, ax) { this.pos.push(...p); this.uv.push(...uv); this.piv.push(...piv); this.ax.push(...ax); }
  // asta alta poleH dal punto base (mondo), telo lungo w e alto h verso dir (vettore orizzontale unitario)
  flag(base, toField, dir, poleH, w, h, design, swing, phase) {
    const top = [base[0], base[1] + poleH, base[2]], piv = [...base, phase], ax = (along) => [toField[0], toField[2], swing, along];
    const tri = (a, b, c, ua, ub, uc, la, lb, lc) => { this._v(a, ua, piv, ax(la)); this._v(b, ub, piv, ax(lb)); this._v(c, uc, piv, ax(lc)); };
    // asta: striscia sottile rivolta verso il campo
    const pw = 0.035, px = [dir[0] * pw, 0, dir[2] * pw], WU = [0.002, 0.002];
    const p0 = [base[0] - px[0], base[1], base[2] - px[2]], p1 = [base[0] + px[0], base[1], base[2] + px[2]];
    const p2 = [top[0] + px[0], top[1] + 0.1, top[2] + px[2]], p3 = [top[0] - px[0], top[1] + 0.1, top[2] - px[2]];
    tri(p0, p1, p2, WU, WU, WU, -1, -1, -1); tri(p0, p2, p3, WU, WU, WU, -1, -1, -1); // along = -1: asta
    // telo
    const [u0, v0, u1, v1] = flagUV(design);
    for (let i = 0; i < FLAG_SEG; i++) {
      const a0 = i / FLAG_SEG, a1 = (i + 1) / FLAG_SEG;
      const at = (a, y) => [top[0] + dir[0] * w * a, y, top[2] + dir[2] * w * a];
      const A = at(a0, top[1] - h), B = at(a1, top[1] - h), Cc = at(a1, top[1]), D = at(a0, top[1]);
      const ua0 = u0 + (u1 - u0) * a0, ua1 = u0 + (u1 - u0) * a1;
      tri(A, B, Cc, [ua0, v0], [ua1, v0], [ua1, v1], a0, a1, a1);
      tri(A, Cc, D, [ua0, v0], [ua1, v1], [ua0, v1], a0, a1, a0);
    }
  }
  geometry() {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(this.pos, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(this.uv, 2));
    g.setAttribute('aPiv', new THREE.Float32BufferAttribute(this.piv, 4));
    g.setAttribute('aAx', new THREE.Float32BufferAttribute(this.ax, 4));
    return g;
  }
}
export function flagMaterial(map, uniforms) {
  const m = new THREE.MeshBasicMaterial({ map, side: THREE.DoubleSide });
  m.onBeforeCompile = (sh) => {
    sh.uniforms.uTime = uniforms.uTime; sh.uniforms.uExcite = uniforms.uExcite;
    sh.vertexShader = 'uniform float uTime;\nuniform float uExcite;\nattribute vec4 aPiv;\nattribute vec4 aAx;\nvarying float vShade;\nvarying float vPole;\n'
      + sh.vertexShader.replace('#include <begin_vertex>', FLAG_VERT);
    sh.fragmentShader = 'varying float vShade;\nvarying float vPole;\n' + sh.fragmentShader.replace('#include <map_fragment>',
      '#include <map_fragment>\n  diffuseColor.rgb = mix(diffuseColor.rgb * vShade, vec3(0.78), vPole);');
  };
  m.customProgramCacheKey = () => 'tag-flags';
  return m;
}
const FLAG_VERT = /* glsl */`
  vec3 transformed = position;
  float t = uTime + aPiv.w, along = max(aAx.w, 0.0);
  vPole = step(aAx.w, -0.5);
  vec3 k = normalize(vec3(aAx.x, 0.0, aAx.y));
  float speed = 1.0 + uExcite * 0.9;
  float wave = sin(t * 7.0 * speed - along * 6.0);
  transformed += k * wave * 0.22 * along;
  transformed.y -= along * along * (0.18 + 0.08 * sin(t * 3.1));
  vShade = 0.86 + 0.22 * cos(t * 7.0 * speed - along * 6.0) * min(1.0, along * 3.0);
  // oscillazione a mano attorno al piede dell'asta (rotazione attorno all'asse verso il campo)
  float ang = sin(t * 2.4 * speed) * aAx.z * (0.55 + 0.6 * uExcite);
  vec3 rel = transformed - aPiv.xyz;
  float c = cos(ang), s = sin(ang);
  rel = rel * c + cross(k, rel) * s + k * dot(k, rel) * (1.0 - c);
  transformed = aPiv.xyz + rel;
`;
