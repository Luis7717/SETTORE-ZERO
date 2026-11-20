// Rosa: logica pura della schermata (nessun DOM, gira in Node).
// - fieldLayout: posizione delle 11 carte nel campo disegnato, dalla formazione scelta, senza sovrapposizioni.
// - swapLineup / canSwap: scambio campo↔campo o campo↔panchina che lascia la formazione valida.
// - swapDelta: quanto cambia la somma delle valutazioni dei titolari con uno scambio (badge verde/rosso sulle carte).

// misure della carta a grandezza piena (px); sotto CARD_MIN_SCALE il campo è davvero troppo piccolo
export const CARD_W = 64;
export const CARD_H = 70;
const CARD_MIN_SCALE = 0.72;
const FIELD_PAD = 4;        // margine tra carte e bordo del campo
const GAP_X = 6;            // spazio minimo tra due carte della stessa fila
const GAP_Y = 4;            // spazio minimo tra due file
const ROW_SPAN = 0.1;       // posti con y entro questo scarto (in lunghezza di campo 0..1) stanno nella stessa fila
const ROW_OFFSET_MAX = 7;   // spostamento in px dentro la fila (terzini e ali un po' più avanti), se c'è spazio
const ROW_OFFSET_K = 160;   // px per unità di y nello spostamento dentro la fila
const RELAX_STEPS = 60;

// file della formazione, dal portiere (prima) agli attaccanti (ultima): ogni fila è un elenco di indici dei posti
export function fieldRows(F) {
  const order = F.map((_, i) => i).sort((a, b) => F[a][2] - F[b][2] || F[a][1] - F[b][1]);
  const rows = [];
  for (const i of order) {
    const row = rows[rows.length - 1];
    if (row && F[i][2] - F[row[0]][2] <= ROW_SPAN) row.push(i); else rows.push([i]);
  }
  return rows;
}

// centri in una fila: dalla x della formazione, poi le carte troppo vicine si allargano (in modo simmetrico)
// e si tengono dentro [lo, hi]. Ritorna un nuovo array di centri (stesso ordine di xs, che è crescente).
function spreadRow(xs, minD, lo, hi) {
  const c = xs.slice();
  for (let k = 0; k < RELAX_STEPS; k++) {
    let moved = false;
    for (let i = 0; i + 1 < c.length; i++) {
      const d = minD - (c[i + 1] - c[i]);
      if (d > 1e-6) { c[i] -= d / 2; c[i + 1] += d / 2; moved = true; }
    }
    for (let i = 0; i < c.length; i++) c[i] = Math.min(hi, Math.max(lo, c[i]));
    if (!moved) break;
  }
  // garanzia finale: da sinistra a destra e poi da destra a sinistra
  for (let i = 1; i < c.length; i++) c[i] = Math.max(c[i], c[i - 1] + minD);
  if (c.length) c[c.length - 1] = Math.min(c[c.length - 1], hi);
  for (let i = c.length - 2; i >= 0; i--) c[i] = Math.min(c[i], c[i + 1] - minD);
  return c;
}

// Carte nel campo largo W e alto H (px). Portiere in basso, attaccanti in alto (la squadra attacca verso l'alto).
// Ritorna { cards: [{ x, y }] (centri, nello stesso ordine dei posti di F), w, h, scale }.
export function fieldLayout(F, W, H) {
  const rows = fieldRows(F), n = rows.length;
  const maxPerRow = Math.max(...rows.map(r => r.length));
  // scala della carta: deve starci la fila più lunga in larghezza e tutte le file in altezza
  const sW = (W - 2 * FIELD_PAD - (maxPerRow - 1) * GAP_X) / (maxPerRow * CARD_W);
  const sH = n > 1 ? (H - 2 * FIELD_PAD - (n - 1) * GAP_Y) / (n * CARD_H) : (H - 2 * FIELD_PAD) / CARD_H;
  const scale = Math.max(CARD_MIN_SCALE, Math.min(1, sW, sH));
  const w = CARD_W * scale, h = CARD_H * scale;
  // spostamento dentro la fila solo se le file restano distanti abbastanza
  const free = n > 1 ? (H - 2 * FIELD_PAD - h) / (n - 1) - h - GAP_Y : 0;
  const off = Math.max(0, Math.min(ROW_OFFSET_MAX, free / 2));
  const top = FIELD_PAD + off + h / 2, bottom = H - FIELD_PAD - off - h / 2;
  const step = n > 1 ? (bottom - top) / (n - 1) : 0;
  const lo = FIELD_PAD + w / 2, hi = W - FIELD_PAD - w / 2, half = (hi - lo) / 2, mid = W / 2;
  const cards = new Array(F.length);
  rows.forEach((row, r) => {
    const yc = n > 1 ? bottom - r * step : H / 2;
    const meanY = row.reduce((t, i) => t + F[i][2], 0) / row.length;
    const byX = row.slice().sort((a, b) => F[a][1] - F[b][1]);
    const xs = spreadRow(byX.map(i => mid + F[i][1] * half), w + GAP_X, lo, hi);
    byX.forEach((i, k) => {
      const dy = Math.max(-off, Math.min(off, (F[i][2] - meanY) * ROW_OFFSET_K));
      cards[i] = { x: xs[k], y: yc - dy };
    });
  });
  return { cards, w, h, scale };
}

// due rettangoli (centri, misure w×h) si toccano?
export function overlaps(a, b, w, h) { return Math.abs(a.x - b.x) < w - 1e-6 && Math.abs(a.y - b.y) < h - 1e-6; }

// scambio: almeno uno dei due deve essere titolare (panchina↔panchina non cambia niente)
export function canSwap(lineup, a, b) { return a !== b && (lineup.includes(a) || lineup.includes(b)); }

// nuova formazione dopo lo scambio di a e b (id); quella passata non viene toccata
export function swapLineup(lineup, a, b) {
  return lineup.map(id => (id === a ? b : id === b ? a : id));
}

// variazione della somma delle valutazioni dei titolari (ogni posto valutato col suo ruolo) se si scambiano a e b;
// rate(p, ruolo) è la valutazione nel ruolo (overallAs di career.js, passata da fuori per non legare i due file)
export function swapDelta(lineup, F, a, b, rate) {
  if (!a || !b || a.id === b.id) return 0;
  const ia = lineup.indexOf(a.id), ib = lineup.indexOf(b.id);
  let d = 0;
  if (ia >= 0) d += rate(b, F[ia][0]) - rate(a, F[ia][0]);
  if (ib >= 0) d += rate(a, F[ib][0]) - rate(b, F[ib][0]);
  return d;
}
