// Motore partita — costanti, numeri casuali con seme, formazioni e fisica del pallone.
// Coordinate: x = larghezza (-HW..HW), y = lunghezza (-HL..HL), h = altezza.
// La squadra 0 attacca verso +y, la squadra 1 verso -y.
export const W = 64, L = 100, HW = W / 2, HL = L / 2;
export const GW = 7.32, GH = 2.44, BOX_W = 40.32, BOX_D = 16.5, SIX_W = 18.32, SIX_D = 5.5, PEN_D = 11, CIRCLE = 9.15;
export const G = 11.5, ROLL = 5.0;
export const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
export const hyp = Math.hypot;

export function rng32(a) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// [ruolo, x (-1..1), y (0 = propria porta .. 1 = porta avversaria)]
export const FORMATIONS = {
  '4-4-2': [['P', 0, .03], ['D', -.72, .2], ['D', -.24, .16], ['D', .24, .16], ['D', .72, .2], ['C', -.78, .44], ['C', -.26, .4], ['C', .26, .4], ['C', .78, .44], ['A', -.22, .66], ['A', .22, .66]],
  '4-3-3': [['P', 0, .03], ['D', -.72, .2], ['D', -.24, .16], ['D', .24, .16], ['D', .72, .2], ['C', -.5, .42], ['C', 0, .37], ['C', .5, .42], ['A', -.72, .64], ['A', 0, .69], ['A', .72, .64]],
  '3-5-2': [['P', 0, .03], ['D', -.5, .19], ['D', 0, .16], ['D', .5, .19], ['C', -.85, .45], ['C', -.4, .41], ['C', 0, .36], ['C', .4, .41], ['C', .85, .45], ['A', -.22, .66], ['A', .22, .66]],
  '4-2-3-1': [['P', 0, .03], ['D', -.72, .2], ['D', -.24, .16], ['D', .24, .16], ['D', .72, .2], ['C', -.25, .35], ['C', .25, .35], ['C', -.7, .53], ['C', 0, .52], ['C', .7, .53], ['A', 0, .7]],
};

// Colpi di testa (`tes`): i giocatori dei salvataggi vecchi non ce l'hanno e lo si ricava da fisico e tiro,
// con un aggiustamento per ruolo e una piccola variazione fissa presa dalle altre statistiche (niente numeri casuali,
// così lo stesso giocatore ha sempre lo stesso valore). Non viene scritto nel salvataggio.
const TES_ROLE = { P: -5, D: 8, C: -1, A: 2 };
export function headingOf(src) {
  if (typeof src.tes === 'number') return src.tes;
  const vary = (((src.vel | 0) * 7 + (src.dri | 0) * 13 + (src.pas | 0) * 3) % 9) - 4;
  return clamp(Math.round(((src.fis | 0) + (src.tir | 0)) / 2 + (TES_ROLE[src.pos] || 0) + vary), 18, 99);
}

const POSPEN = { PP: 1, DD: 1, CC: 1, AA: 1, DC: .92, CD: .92, CA: .92, AC: .92, DA: .82, AD: .82 };
export function effStats(src, slotPos) {
  let f = POSPEN[src.pos + slotPos];
  if (f === undefined) f = 0.6;
  const s = { vel: src.vel, tir: src.tir * f, pas: src.pas * f, dri: src.dri * f, dif: src.dif * f, fis: src.fis, por: src.por, tes: headingOf(src) * f };
  if (slotPos === 'P' && src.pos !== 'P') s.por = Math.min(src.por, 25);
  return s;
}

export function ballPhys(s, dt) {
  if (s.ct > 0) { s.vx += s.cax * dt; s.vy += s.cay * dt; s.ct -= dt; }
  s.x += s.vx * dt; s.y += s.vy * dt;
  if (s.h > 0 || s.vh > 0) {
    s.vh -= G * dt; s.h += s.vh * dt;
    if (s.h <= 0) {
      s.h = 0;
      if (s.vh < -2.2) { s.vh = -s.vh * 0.5; s.vx *= 0.8; s.vy *= 0.8; } else s.vh = 0;
    }
  } else {
    const v = hyp(s.vx, s.vy);
    if (v > 0) { const nv = Math.max(0, v - ROLL * dt); s.vx *= nv / v; s.vy *= nv / v; }
  }
}

export function segInfo(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay, l2 = dx * dx + dy * dy || 1e-9;
  const t = clamp(((px - ax) * dx + (py - ay) * dy) / l2, 0, 1);
  return [hyp(px - (ax + dx * t), py - (ay + dy * t)), t];
}
