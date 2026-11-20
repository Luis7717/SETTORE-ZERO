// Attrezzi comuni dello stadio: texture disegnate su canvas, colori, costruttore di geometrie a quadrilateri.
// Coordinate three: x = larghezza, y = altezza, z = -y del motore.
import * as THREE from 'three';
import { releaseCanvas } from './canvas-mem.js';

// contesto 2D di un canvas: su Safari iOS, finita la memoria dei canvas, getContext restituisce null
export function ctx2d(c) {
  const g = c.getContext('2d');
  if (!g) throw new Error(`canvas ${c.width}×${c.height} senza contesto 2D (memoria dei canvas finita?)`);
  return g;
}
// disegna (o ridisegna) un canvas w×h con draw; riusa quello dato se c'è
function paint(c, w, h, draw) {
  const cv = c && typeof c.getContext === 'function' ? c : document.createElement('canvas');
  if (cv.width !== w || cv.height !== h) { cv.width = w; cv.height = h; }
  const g = ctx2d(cv);
  g.setTransform(1, 0, 0, 1, 0, 0); g.globalAlpha = 1; g.globalCompositeOperation = 'source-over'; g.clearRect(0, 0, w, h);
  draw(g, w, h);
  return cv;
}
// texture disegnata su canvas. userData.rebuild ridisegna il canvas (dopo che è stato svuotato: src/canvas-mem.js)
export function canvasTex(w, h, draw) {
  const t = new THREE.CanvasTexture(paint(null, w, h, draw)); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4;
  t.userData.draw = draw;
  t.userData.rebuild = () => paint(t.image, w, h, t.userData.draw);
  return t;
}
// ridisegna una texture fatta con canvasTex e la rimanda alla GPU (se il canvas era stato svuotato, lo si rifà e
// poi lo si svuota di nuovo)
export function redrawTex(t, draw) {
  t.userData.draw = draw;
  t.image = t.userData.rebuild ? t.userData.rebuild() : paint(t.image, t.image.width, t.image.height, draw);
  t.needsUpdate = true;
  if (t.userData.releasedBy) releaseCanvas(t.userData.releasedBy, t);
}

export const rnd = (a, b) => a + Math.random() * (b - a);
export const pick = arr => arr[(Math.random() * arr.length) | 0];
export const C = (hex, k = 1) => new THREE.Color(hex).multiplyScalar(k);
export const placeMatrix = (rotY, x, z) => new THREE.Matrix4().makeRotationY(rotY).setPosition(x, 0, z);

// colore css più chiaro (k > 0) o più scuro (k < 0)
export function shade(css, k) {
  const c = new THREE.Color(css);
  if (k > 0) c.lerp(new THREE.Color('#ffffff'), k); else c.multiplyScalar(1 + k);
  return '#' + c.getHexString();
}
export function fitText(g, text, x, y, maxW, size, weight = 900) {
  g.font = `${weight} ${size}px system-ui, Arial, sans-serif`;
  g.fillText(text, x, y, maxW);
}

// Colori dei tifosi da una divisa ({ shirt, shorts } numeri esadecimali): il secondo colore è quello dei
// calzoncini se si distingue dalla maglia, altrimenti bianco o nero.
export function fanColors(kit) {
  const a = new THREE.Color(kit.shirt), b = new THREE.Color(kit.shorts ?? 0xffffff);
  const lum = c => 0.3 * c.r + 0.59 * c.g + 0.11 * c.b;
  const diff = Math.abs(a.r - b.r) + Math.abs(a.g - b.g) + Math.abs(a.b - b.b);
  const second = diff > 0.45 ? b : new THREE.Color(lum(a) > 0.55 ? 0x15171c : 0xf4f4f4);
  return ['#' + a.getHexString(), '#' + second.getHexString()];
}

// ---------------------------------------------------------------- costruttore di geometrie a quadrilateri
// Ogni quadrilatero: angoli a,b,c,d (in basso a sinistra, in basso a destra, in alto a destra, in alto a sinistra
// visti da chi guarda), un colore (o 4) e un rettangolo uv [u0, v0, u1, v1]. `face` indica da che parte si guarda:
// se l'ordine dei vertici è al contrario lo si gira, così le facce posteriori si possono scartare.
export const WHITE_UV = [0.01, 0.99, 0.02, 0.995];
const V = new THREE.Vector3(), V2 = new THREE.Vector3(), V3 = new THREE.Vector3();
export class QuadBuilder {
  constructor() { this.pos = []; this.col = []; this.uv = []; }
  quad(a, b, c, d, color, uv = WHITE_UV, face = null) {
    const cols = Array.isArray(color) ? color : [color, color, color, color];
    const uvs = [[uv[0], uv[1]], [uv[2], uv[1]], [uv[2], uv[3]], [uv[0], uv[3]]];
    let p = [a, b, c, d], q = [0, 1, 2, 3];
    if (face) {
      V.set(b[0] - a[0], b[1] - a[1], b[2] - a[2]); V2.set(c[0] - a[0], c[1] - a[1], c[2] - a[2]);
      if (V3.crossVectors(V, V2).dot(V.set(face[0], face[1], face[2])) < 0) { p = [a, d, c, b]; q = [0, 3, 2, 1]; }
    }
    for (const k of [0, 1, 2, 0, 2, 3]) {
      this.pos.push(p[k][0], p[k][1], p[k][2]);
      const cc = cols[q[k]]; this.col.push(cc.r, cc.g, cc.b);
      this.uv.push(uvs[q[k]][0], uvs[q[k]][1]);
    }
  }
  tri(a, b, c, color, face) {
    V.set(b[0] - a[0], b[1] - a[1], b[2] - a[2]); V2.set(c[0] - a[0], c[1] - a[1], c[2] - a[2]);
    const pts = V3.crossVectors(V, V2).dot(V.set(face[0], face[1], face[2])) < 0 ? [a, c, b] : [a, b, c];
    for (const p of pts) { this.pos.push(p[0], p[1], p[2]); this.col.push(color.r, color.g, color.b); this.uv.push(WHITE_UV[0], WHITE_UV[1]); }
  }
  // parete verticale rivolta verso -z (il campo, nel sistema locale della tribuna): xl è il bordo sinistro visto dal campo
  wall(xl, xr, z, y0, y1, color, uv) { this.quad([xl, y0, z], [xr, y0, z], [xr, y1, z], [xl, y1, z], color, uv, [0, 0, -1]); }
  floor(x0, x1, z0, z1, y, color, uv) { this.quad([x0, y, z0], [x1, y, z0], [x1, y, z1], [x0, y, z1], color, uv, [0, 1, 0]); }
  // parete verticale nel piano x = costante, rivolta verso sx (+1 o -1)
  side(x, z0, z1, y0, y1, color, sx) { this.quad([x, y0, z0], [x, y0, z1], [x, y1, z1], [x, y1, z0], color, WHITE_UV, [sx, 0, 0]); }
  // barra sottile tra due punti (corrimano, travi), larga w, vista dal campo
  bar(a, b, w, color) {
    this.quad([a[0] - w, a[1], a[2]], [a[0] + w, a[1], a[2]], [b[0] + w, b[1], b[2]], [b[0] - w, b[1], b[2]], color, WHITE_UV, [0, 0.3, -1]);
  }
  hbar(x0, x1, y, z, h, color) { this.wall(x1, x0, z, y - h / 2, y + h / 2, color); }
  box(cx, cy, cz, sx, sy, sz, color, top = color) {
    const x0 = cx - sx / 2, x1 = cx + sx / 2, y0 = cy - sy / 2, y1 = cy + sy / 2, z0 = cz - sz / 2, z1 = cz + sz / 2;
    this.quad([x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1], top, WHITE_UV, [0, 1, 0]);
    this.quad([x0, y0, z0], [x1, y0, z0], [x1, y1, z0], [x0, y1, z0], color, WHITE_UV, [0, 0, -1]);
    this.quad([x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1], color, WHITE_UV, [0, 0, 1]);
    this.quad([x0, y0, z0], [x0, y0, z1], [x0, y1, z1], [x0, y1, z0], color, WHITE_UV, [-1, 0, 0]);
    this.quad([x1, y0, z0], [x1, y0, z1], [x1, y1, z1], [x1, y1, z0], color, WHITE_UV, [1, 0, 0]);
  }
  geometry(matrix) {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(this.pos, 3));
    g.setAttribute('color', new THREE.Float32BufferAttribute(this.col, 3));
    g.setAttribute('uv', new THREE.Float32BufferAttribute(this.uv, 2));
    if (matrix) g.applyMatrix4(matrix);
    return g;
  }
}
