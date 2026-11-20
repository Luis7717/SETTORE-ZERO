// Capelli dei giocatori 3D, costruiti a codice (nessun file esterno). Modulo puro: niente three.js, gira anche in Node.
//
// Ogni taglio è fatto di "calotte" lisce appoggiate su una superficie di base che avvolge la testa (un superellissoide
// adattato alla testa squadrata del modello Kenney): bordo che segue una curva morbida (niente seghettature),
// normali lisce calcolate sulla griglia, un risvolto interno scuro che chiude il bordo (spessore leggibile).
// Pezzi in più per i tagli che li vogliono: coda di cavallo (tubo curvo con elastico), crocchia (tornita),
// punte (coni), cresta (striscia sopra la testa rasata).
// La tinta sta in una piccola zona della texture del giocatore (R.hair in players3d.js): sfumatura dalla radice
// alla punta, lucentezza a ciocche, ricci, treccine, riga, sfumatura rasata sulla nuca.
//
// Coordinate locali della testa in raggi R: x = destra, y = su, z = avanti. el/az in gradi (az 0 = viso, 90 = destra).

const DEG = Math.PI / 180;
const smooth = (a, b, x) => { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
const lerp = (a, b, t) => a + (b - a) * t;
export const dirL = (el, az) => { const ce = Math.cos(el * DEG); return [ce * Math.sin(az * DEG), Math.sin(el * DEG), ce * Math.cos(az * DEG)]; };
// attaccatura: elevazione in funzione del giro, da nodi [|az|, el] raccordati in modo morbido (simmetrica destra/sinistra)
export const prof = (az, k) => { const a = Math.min(180, Math.abs(az)); for (let i = 0; i < k.length - 1; i++) if (a <= k[i + 1][0]) return lerp(k[i][1], k[i + 1][1], smooth(k[i][0], k[i + 1][0], a)); return k[k.length - 1][1]; };
// bozzi morbidi e isotropi sulla superficie (ricci, afro): somma di onde in direzioni fisse
const LUMP_K = [[0.62, 0.55, 0.56], [-0.7, 0.3, 0.65], [0.2, -0.85, 0.48], [0.5, 0.45, -0.74], [-0.3, -0.4, -0.86], [-0.85, 0.5, -0.1]];
const lumps = (L, f) => { let s = 0; for (let i = 0; i < LUMP_K.length; i++) { const k = LUMP_K[i]; s += Math.sin(f * (k[0] * L[0] + k[1] * L[1] + k[2] * L[2]) + i * 1.7); } return s / LUMP_K.length; };
const softMin = (a, b, k) => (a + b - Math.sqrt((a - b) * (a - b) + k * k)) / 2;

const SHORT = [[0, 31], [45, 25], [85, 8], [105, 5], [180, -20]];   // attaccatura di un taglio corto
const BUZZ = [[0, 30], [45, 24], [85, 8], [105, 5], [180, -20]];    // rasato (dipinto)
const QUIFF = (el, az) => smooth(70, 5, Math.abs(az - 6)) * smooth(30, 60, el) * (1 - 0.75 * smooth(72, 92, el));
// sfera dell'afro (in R): centro più in alto e indietro del riferimento, raggio da testa vera (≈ 3 cm in cima,
// 2 cm ai lati, appena sopra la fronte); dove la testa sporge oltre la sfera (nuca) resta uno spessore minimo
const AFRO_C = [0, 0.2, -0.2], AFRO_R = 1.24, AFRO_MIN = 0.17;
const afroT = (L) => { const d = L[0] * AFRO_C[0] + L[1] * AFRO_C[1] + L[2] * AFRO_C[2], c2 = AFRO_C[0] ** 2 + AFRO_C[1] ** 2 + AFRO_C[2] ** 2; return d + Math.sqrt(Math.max(0, d * d - c2 + AFRO_R * AFRO_R)); };

// Tagli, nello stesso ordine di HAIR_STYLES in looks.js (gli indici sono nei salvataggi).
//   line: attaccatura · th(el, az, v, b, L): spessore in R (v = 0 sul bordo, 1 in cima; b = raggio della base)
//   hang/drop/flare: sotto l'elevazione `hang` i capelli scendono dritti (lunghi) · taper: [spessore al bordo, larghezza]
//   post(p, el, az): ritocco del punto · extra: pezzi in più · paint: come si dipinge la tinta · buzz: nuca rasata dipinta
export const HAIR = [
  null,                                                                                     // 0 calvo
  { buzz: BUZZ, paint: 'none' },                                                            // 1 rasato
  { line: SHORT, th: (el) => 0.04 + 0.03 * smooth(20, 70, el), paint: 'fade', taper: [0.5, 0.2] }, // 2 corti
  { line: [[0, 33], [45, 27], [85, 9], [105, 6], [180, -18]], th: (el) => 0.05 + 0.2 * smooth(22, 66, el), paint: 'brush', taper: [0.5, 0.2],
    post: (p, el, az, top) => { p[1] = softMin(p[1], top + 0.14, 0.06); } },                                   // 3 spazzola (sopra piatta)
  { line: SHORT, th: (el, az) => 0.05 + 0.025 * smooth(20, 70, el) + 0.3 * QUIFF(el, az), paint: 'fine',
    post: (p, el, az) => { const q = QUIFF(el, az); p[2] += 0.16 * q; p[1] += 0.05 * q; } }, // 4 ciuffo
  { line: [[0, 28], [45, 22], [85, 6], [105, 3], [180, -20]], part: -38, paint: 'part', cols: 44,
    th: (el, az) => 0.07 + 0.07 * smooth(-40, 70, az) * smooth(10, 60, el) - 0.05 * Math.exp(-(((az + 38) / 9) ** 2)) * smooth(32, 52, el) * (1 - smooth(80, 90, el)) }, // 5 riga di lato
  { buzz: BUZZ, strip: { w: 17, from: 34, to: 200, h: (ph) => 0.08 + 0.3 * smooth(34, 75, ph) * smooth(200, 125, ph) }, paint: 'fine' }, // 6 cresta
  { line: SHORT, th: (el) => 0.06 + 0.02 * smooth(20, 70, el), paint: 'fine', extra: 'spikes' }, // 7 a punte
  { line: [[0, 27], [45, 21], [85, 2], [110, -2], [180, -26]], cols: 40, rows: 12, paint: 'curly', taper: [0.55, 0.3],
    th: (el, az, v, b, L) => 0.12 + 0.05 * smooth(0, 60, el) + 0.07 * lumps(L, 7) },       // 8 ricci
  { line: [[0, 23], [45, 17], [85, -6], [110, -9], [180, -30]], cols: 40, rows: 12, paint: 'afro', taper: [0.25, 0.4],
    th: (el, az, v, b, L) => -softMin(-AFRO_MIN, b - afroT(L), 0.08) + 0.025 * lumps(L, 9) }, // 9 afro
  { line: [[0, 19], [34, 18], [64, -32], [120, -36], [180, -38]], hang: -4, drop: 1.0, flare: 0.1, cols: 44, paint: 'fine', taper: [0.45, 0.25],
    th: (el) => 0.085 + 0.025 * smooth(20, 70, el) },                                       // 10 caschetto
  { line: [[0, 26], [30, 22], [66, -44], [120, -62], [180, -70]], hang: -4, drop: 1.15, flare: 0.14, cols: 44, rows: 11, part: 0, paint: 'part', taper: [0.5, 0.2],
    th: (el) => 0.08 + 0.015 * smooth(20, 70, el) },                                        // 11 lunghi
  { line: [[0, 30], [45, 24], [85, 7], [105, 5], [180, -18]], th: (el) => 0.042 + 0.018 * smooth(10, 70, el), paint: 'slick', extra: 'tail' }, // 12 coda
  { line: [[0, 30], [45, 24], [85, 7], [105, 5], [180, -18]], th: (el) => 0.042 + 0.018 * smooth(10, 70, el), paint: 'slick', extra: 'bun' },  // 13 chignon
  { line: [[0, 26], [30, 22], [66, -38], [120, -56], [180, -62]], hang: -4, drop: 1.1, flare: 0.05, cols: 60, rows: 10, paint: 'braids', taper: [0.7, 0.15],
    th: (el, az) => 0.06 + 0.045 * Math.pow(Math.abs(Math.sin(6 * az * DEG)), 0.6) * smooth(30, 10, el) + 0.02 * smooth(30, 80, el) }, // 14 treccine
  { line: [[0, 4], [32, 6], [68, -6], [100, -8], [180, -22]], cols: 44, paint: 'fringe', taper: [0.6, 0.15],
    th: (el) => 0.085 + 0.025 * smooth(30, 80, el) },                                       // 15 frangia
  { line: [[0, 37], [45, 30], [85, 10], [105, 7], [180, -18]], paint: 'slick', taper: [0.5, 0.25],
    th: (el, az) => 0.035 + 0.05 * smooth(40, 150, Math.abs(az)) * smooth(-10, 60, el) + 0.015 * smooth(50, 90, el) }, // 16 all'indietro
];
export const HAIR_SHELL_COLS = 40, HAIR_SHELL_ROWS = 9;
const SKIRT_IN = -0.06;   // il risvolto del bordo entra sotto la base (in R): chiude lo spazio tra capelli e testa
const TUCK = 0.07;        // il bordo rientra verso la testa: niente visiera

// ---------------------------------------------------------------- testa: superficie di base
// frame = { c, up, fwd, right (array o oggetti {x,y,z}), R, pts: punti della testa (per adattare la base), N?: esponente del superellissoide }
export function makeBase(frame) {
  const v3 = o => Array.isArray(o) ? o : [o.x, o.y, o.z];
  const c = v3(frame.c), up = v3(frame.up), fwd = v3(frame.fwd), right = v3(frame.right), R = frame.R;
  const loc = p => { const d = [p[0] - c[0], p[1] - c[1], p[2] - c[2]]; return [(d[0] * right[0] + d[1] * right[1] + d[2] * right[2]) / R, (d[0] * up[0] + d[1] * up[1] + d[2] * up[2]) / R, (d[0] * fwd[0] + d[1] * fwd[1] + d[2] * fwd[2]) / R]; };
  const P = frame.pts.map(p => loc(v3(p)));
  const ext = [0, 0, 0, 0, 0, 0];   // +x, -x, +y, -y, +z, -z
  for (const p of P) { ext[0] = Math.max(ext[0], p[0]); ext[1] = Math.max(ext[1], -p[0]); ext[2] = Math.max(ext[2], p[1]); ext[3] = Math.max(ext[3], -p[1]); ext[4] = Math.max(ext[4], p[2]); ext[5] = Math.max(ext[5], -p[2]); }
  const sx = Math.max(ext[0], ext[1]); ext[0] = ext[1] = sx; // simmetrica
  for (let i = 0; i < 6; i++) ext[i] = Math.max(0.3, ext[i]);
  const N = frame.N || 4;   // 4 = testa squadrata (Kenney), più basso = testa tonda (modello realistico)
  const raw = L => { const a = L[0] >= 0 ? ext[0] : ext[1], b = L[1] >= 0 ? ext[2] : ext[3], d = L[2] >= 0 ? ext[4] : ext[5]; return Math.pow(Math.abs(L[0] / a) ** N + Math.abs(L[1] / b) ** N + Math.abs(L[2] / d) ** N, -1 / N); };
  // la base deve contenere la testa dove ci sono capelli (non il mento): si allarga del rapporto massimo
  let k = 1; for (const p of P) { if (p[1] < -0.4 && p[2] > 0) continue; const r = Math.hypot(p[0], p[1], p[2]); if (r > 1e-6) k = Math.max(k, r / raw([p[0] / r, p[1] / r, p[2] / r])); }
  const base = L => raw(L) * k * 1.01;
  const world = p => [c[0] + R * (right[0] * p[0] + up[0] * p[1] + fwd[0] * p[2]), c[1] + R * (right[1] * p[0] + up[1] * p[1] + fwd[1] * p[2]), c[2] + R * (right[2] * p[0] + up[2] * p[1] + fwd[2] * p[2])];
  return { base, world, ext, k };
}

// Base "radiale" per una testa vera (modello realistico): per ogni direzione il raggio massimo della testa,
// letto da una griglia elevazione × giro riempita coi punti, allargata di una cella e ammorbidita. Aderisce alla testa
// (niente spazio tra capelli e cranio) dove un superellissoide lascerebbe vuoti o la buche.
// frame come makeBase; i punti senza capelli (viso, orecchie) si tolgono prima: le celle vuote si riempiono dai vicini.
export const RB_STEP = 5;   // gradi per cella
export function makeRadialBase(frame) {
  const v3 = o => Array.isArray(o) ? o : [o.x, o.y, o.z];
  const c = v3(frame.c), up = v3(frame.up), fwd = v3(frame.fwd), right = v3(frame.right), R = frame.R;
  const NE = 180 / RB_STEP + 1, NA = 360 / RB_STEP, grid = new Float32Array(NE * NA).fill(-1);
  const cell = (e, a) => e * NA + ((a % NA) + NA) % NA;
  for (const q of frame.pts) {
    const p = v3(q), d = [p[0] - c[0], p[1] - c[1], p[2] - c[2]];
    const x = (d[0] * right[0] + d[1] * right[1] + d[2] * right[2]) / R, y = (d[0] * up[0] + d[1] * up[1] + d[2] * up[2]) / R, z = (d[0] * fwd[0] + d[1] * fwd[1] + d[2] * fwd[2]) / R;
    const r = Math.hypot(x, y, z); if (r < 1e-6) continue;
    const el = Math.asin(Math.max(-1, Math.min(1, y / r))) / DEG, az = Math.atan2(x, z) / DEG;
    const i = cell(Math.round((el + 90) / RB_STEP), Math.round((az + 180) / RB_STEP));
    if (r > grid[i]) grid[i] = r;
  }
  // celle vuote: media dei vicini pieni, finché tutto è pieno
  for (let it = 0; it < 200; it++) {
    const add = []; let empty = 0;
    for (let e = 0; e < NE; e++) for (let a = 0; a < NA; a++) {
      const i = cell(e, a); if (grid[i] >= 0) continue; empty++;
      let s = 0, n = 0; for (const [de, da] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const ee = e + de; if (ee < 0 || ee >= NE) continue; const g = grid[cell(ee, a + da)]; if (g >= 0) { s += g; n++; } }
      if (n) add.push(i, s / n);
    }
    for (let k = 0; k < add.length; k += 2) grid[add[k]] = add[k + 1];
    if (!empty) break;
  }
  for (let i = 0; i < grid.length; i++) if (grid[i] < 0) grid[i] = 1;
  // allargata di una cella (i capelli non entrano tra due punti) e ammorbidita due volte
  const pass = (f) => { const out = new Float32Array(grid.length); for (let e = 0; e < NE; e++) for (let a = 0; a < NA; a++) { const vals = []; for (let de = -1; de <= 1; de++) for (let da = -1; da <= 1; da++) { const ee = Math.max(0, Math.min(NE - 1, e + de)); vals.push(grid[cell(ee, a + da)]); } out[cell(e, a)] = f(vals); } grid.set(out); };
  pass(v => Math.max(...v));
  pass(v => v.reduce((x, y) => x + y, 0) / v.length); pass(v => v.reduce((x, y) => x + y, 0) / v.length);
  const base = L => {
    const r = Math.hypot(L[0], L[1], L[2]) || 1, el = Math.asin(Math.max(-1, Math.min(1, L[1] / r))) / DEG, az = Math.atan2(L[0], L[2]) / DEG;
    const fe = Math.max(0, Math.min(NE - 1.001, (el + 90) / RB_STEP)), fa = (az + 180) / RB_STEP, e0 = Math.floor(fe), a0 = Math.floor(fa), te = fe - e0, ta = fa - a0;
    const g = (e, a) => grid[cell(Math.min(NE - 1, e), a)];
    return 1.015 * lerp(lerp(g(e0, a0), g(e0, a0 + 1), ta), lerp(g(e0 + 1, a0), g(e0 + 1, a0 + 1), ta), te);
  };
  const world = p => [c[0] + R * (right[0] * p[0] + up[0] * p[1] + fwd[0] * p[2]), c[1] + R * (right[1] * p[0] + up[1] * p[1] + fwd[1] * p[2]), c[2] + R * (right[2] * p[0] + up[2] * p[1] + fwd[2] * p[2])];
  return { base, world };
}

// ---------------------------------------------------------------- griglie con normali morbide
// pt(i, j) → punto locale; uv(i, j) → [u, v] nella zona dei capelli (0..1); wrap: l'ultima colonna ripete la prima
// inner(i) → un punto dentro il pezzo (per girare i triangoli verso l'esterno). Le righe coincidenti (poli) si uniscono.
function grid(out, rows, cols, pt, uv, wrap, inner, pole = -1) {
  const nc = cols + 1, P = [], U = [], I = [];
  for (let i = 0; i <= rows; i++) {
    const row = []; for (let j = 0; j < nc; j++) row.push(pt(i, wrap && j === cols ? 0 : j));
    // riga quasi in un punto (polo): tutti i punti nel baricentro, niente buchi
    let span = 0; for (const p of row) span = Math.max(span, Math.hypot(p[0] - row[0][0], p[1] - row[0][1], p[2] - row[0][2]));
    if (span < 1e-4 || i === pole) { const m = [0, 0, 0]; for (const p of row) for (let k = 0; k < 3; k++) m[k] += p[k] / nc; row.fill(m); }
    for (let j = 0; j < nc; j++) { P.push(row[j]); U.push(uv(i, j)); }
  }
  let sign = 0;
  for (let i = 0; i < rows; i++) for (let j = 0; j < cols; j++) {
    const a = i * nc + j, b = a + 1, c = a + nc + 1, d = a + nc;
    I.push(a, b, d, b, c, d);
    const n = cross(sub(P[b], P[a]), sub(P[d], P[a])), m = inner(i);
    sign += dot(n, sub(P[a], m));
  }
  if (sign < 0) for (let t = 0; t < I.length; t += 3) { const x = I[t + 1]; I[t + 1] = I[t + 2]; I[t + 2] = x; }
  // normali: somma delle normali dei triangoli, poi cuciture e poli uniti
  const Nn = P.map(() => [0, 0, 0]);
  for (let t = 0; t < I.length; t += 3) { const a = P[I[t]], b = P[I[t + 1]], c = P[I[t + 2]], n = cross(sub(b, a), sub(c, a)); for (const k of [I[t], I[t + 1], I[t + 2]]) for (let q = 0; q < 3; q++) Nn[k][q] += n[q]; }
  const same = (x, y) => Math.abs(P[x][0] - P[y][0]) + Math.abs(P[x][1] - P[y][1]) + Math.abs(P[x][2] - P[y][2]) < 1e-9;
  for (let i = 0; i <= rows; i++) {
    const r0 = i * nc;
    if (same(r0, r0 + (cols >> 1)) && same(r0, r0 + cols)) { const m = [0, 0, 0]; for (let j = 0; j < nc; j++) for (let q = 0; q < 3; q++) m[q] += Nn[r0 + j][q]; for (let j = 0; j < nc; j++) Nn[r0 + j] = m.slice(); }
    else if (wrap) { const m = [0, 0, 0]; for (let q = 0; q < 3; q++) m[q] = Nn[r0][q] + Nn[r0 + cols][q]; Nn[r0] = m.slice(); Nn[r0 + cols] = m.slice(); }
  }
  const base = out.pos.length / 3;
  for (let k = 0; k < P.length; k++) {
    out.pos.push(...P[k]); const n = Nn[k], l = Math.hypot(n[0], n[1], n[2]) || 1; out.nrm.push(n[0] / l, n[1] / l, n[2] / l); out.uv.push(...U[k]);
  }
  for (const x of I) out.ind.push(base + x);
}
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const norm = a => { const l = Math.hypot(a[0], a[1], a[2]) || 1; return [a[0] / l, a[1] / l, a[2] / l]; };
const add = (a, b, s = 1) => [a[0] + b[0] * s, a[1] + b[1] * s, a[2] + b[2] * s];

// zone della tinta (0..1 dentro R.hair): calotta (v 0 in cima → TEX_EDGE sul bordo), risvolto scuro, pezzi in più
export const TEX_SHELL = [0.01, 0.77], TEX_TOP = 0.02, TEX_EDGE = 0.86, TEX_UNDER = 0.95, TEX_EXTRA = [0.84, 0.98], TEX_TIE = [0.06, 0.14];

// ---------------------------------------------------------------- geometria di un taglio (coordinate locali in R)
export function hairPieces(style, baseFn) {
  const st = HAIR[style], out = { pos: [], nrm: [], uv: [], ind: [] };
  if (!st) return out;
  if (st.line) shell(out, st, baseFn);
  if (st.strip) strip(out, st, baseFn);
  if (st.extra === 'tail') tail(out, baseFn);
  else if (st.extra === 'bun') bun(out, baseFn);
  else if (st.extra === 'spikes') spikes(out, baseFn);
  return out;
}

function shellPoint(st, base, el, az, v, tOverride) {
  const he = st.hang, hanging = he != null && el < he;
  const e0 = hanging ? he - (he - el) * 0.12 : el;
  const L = dirL(e0, az), b = base(L);
  let t = tOverride ?? st.th(el, az, v, b, L);
  if (tOverride == null) { const tp = st.taper || [0.4, 0.25], e = smooth(0, tp[1], v); t = t * (tp[0] + (1 - tp[0]) * e) - TUCK * (1 - e); }
  const p = [L[0] * (b + t), L[1] * (b + t), L[2] * (b + t)];
  if (hanging) {
    const drop = (Math.sin(he * DEG) - Math.sin(el * DEG)) * (st.drop || 1), hn = Math.hypot(L[0], L[2]) || 1, fl = (st.flare || 0) * drop;
    p[1] -= drop; p[0] += L[0] / hn * fl; p[2] += L[2] / hn * fl;
  }
  if (st.post) st.post(p, el, az, base([0, 1, 0]));
  return p;
}

function shell(out, st, base) {
  const C = st.cols || HAIR_SHELL_COLS, Rw = st.rows || HAIR_SHELL_ROWS;
  const az = j => -180 + 360 * j / C, line = j => prof(az(j), st.line);
  const el = (i, j) => { const l = line(j); return i === Rw ? 90 : l + (90 - l) * (i / Rw); };
  const u = j => lerp(TEX_SHELL[0], TEX_SHELL[1], j / C);
  grid(out, Rw, C, (i, j) => shellPoint(st, base, el(i, j), az(j), i / Rw), (i, j) => [u(j), lerp(TEX_EDGE, TEX_TOP, i / Rw)], true, () => [0, 0, 0], Rw);
  // risvolto: dal bordo esterno verso l'interno, sotto la base (tinta scura)
  grid(out, 1, C, (i, j) => i === 0 ? shellPoint(st, base, line(j), az(j), 0, SKIRT_IN) : shellPoint(st, base, line(j), az(j), 0),
    (i, j) => [u(j), i === 0 ? 0.99 : TEX_UNDER], true, () => [0, 0, 0]);
}

// cresta: striscia lungo il centro della testa, da davanti (ph = 0 avanti, 90 in cima, 180 dietro), bordi dentro la base
function strip(out, st, base) {
  const S = st.strip, rows = 8, cols = 22;
  grid(out, rows, cols, (i, j) => {
    const w = (-1 + 2 * i / rows) * S.w, ph = lerp(S.from, S.to, j / cols);
    const s = [0, Math.sin(ph * DEG), Math.cos(ph * DEG)], cw = Math.cos(w * DEG), L = [Math.sin(w * DEG), s[1] * cw, s[2] * cw];
    const pr = Math.pow(Math.cos((w / S.w) * Math.PI / 2), 0.55), t = S.h(ph) * pr + SKIRT_IN * (1 - pr), b = base(L);
    const p = [L[0] * (b + t), L[1] * (b + t), L[2] * (b + t)];
    p[2] += 0.05 * pr * smooth(60, 120, ph); // la cresta si piega un poco in avanti
    return p;
  }, (i, j) => [lerp(TEX_SHELL[0], TEX_SHELL[1], j / cols), lerp(TEX_EDGE, TEX_TOP, Math.sin(Math.PI * i / rows))], false, () => [0, 0, 0]);
}

// coda di cavallo: tubo lungo una curva dietro la nuca, con l'elastico (strozzatura vicino alla radice)
const TAIL_T = [0, 0.07, 0.13, 0.22, 0.34, 0.48, 0.62, 0.76, 0.88, 0.96, 1];
function tail(out, base) {
  const L0 = dirL(14, 180), r0 = base(L0), root = [L0[0] * (r0 - 0.05), L0[1] * (r0 - 0.05), L0[2] * (r0 - 0.05)];
  const ctrl = [root, add(root, [0, -0.02, -0.3]), add(root, [0, -0.32, -0.52]), add(root, [0, -0.82, -0.48]), add(root, [0, -1.18, -0.36])];
  const at = t => catmull(ctrl, t);
  const rad = t => t < 0.07 ? 0.18 : t < 0.15 ? 0.135 : lerp(0.27, 0.05, smooth(0.25, 1, t)) * (1 - 0.4 * smooth(0.15, 0.05, t));
  const cols = 10, rows = TAIL_T.length - 1;
  grid(out, rows, cols, (i, j) => {
    const t = TAIL_T[i], c = at(t), T = norm(sub(at(Math.min(1, t + 0.02)), at(Math.max(0, t - 0.02)))), B = [1, 0, 0], N = norm(cross(B, T)), a = 2 * Math.PI * j / cols, r = i === rows ? 0 : rad(t);
    return [c[0] + r * (Math.cos(a) * B[0] + Math.sin(a) * N[0]), c[1] + r * (Math.cos(a) * B[1] + Math.sin(a) * N[1]), c[2] + r * (Math.cos(a) * B[2] + Math.sin(a) * N[2])];
  }, (i, j) => [lerp(TEX_EXTRA[0], TEX_EXTRA[1], j / cols), TAIL_T[i]], true, i => at(TAIL_T[i]));
}
function catmull(P, t) {
  const n = P.length - 1, x = Math.min(n - 1e-6, t * n), i = Math.floor(x), f = x - i;
  const p0 = P[Math.max(0, i - 1)], p1 = P[i], p2 = P[i + 1], p3 = P[Math.min(n, i + 2)], f2 = f * f, f3 = f2 * f;
  return [0, 1, 2].map(k => 0.5 * (2 * p1[k] + (-p0[k] + p2[k]) * f + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * f2 + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * f3));
}

// crocchia: tornita attorno a un asse che esce dalla testa in alto dietro, con l'elastico alla base
const BUN = [[0.16, -0.08, 0], [0.165, 0.02, 0.08], [0.155, 0.07, 0.12], [0.25, 0.11, 0.22], [0.32, 0.24, 0.42], [0.3, 0.38, 0.6], [0.22, 0.48, 0.78], [0.1, 0.54, 0.92], [0, 0.555, 1]];
function bun(out, base) {
  const L = dirL(52, 180), b = base(L), ax = norm(add(L, [0, 0.3, 0])), o = [L[0] * b, L[1] * b, L[2] * b];
  const B = norm(cross(ax, [1, 0, 0])), A = norm(cross(B, ax)), cols = 12;
  grid(out, BUN.length - 1, cols, (i, j) => {
    const [r, h] = BUN[i], a = 2 * Math.PI * j / cols, sq = 1 + 0.12 * Math.cos(2 * a); // un po' ovale
    return add(add(add(o, ax, h), A, r * sq * Math.cos(a)), B, r * Math.sin(a));
  }, (i, j) => [lerp(TEX_EXTRA[0], TEX_EXTRA[1], j / cols), BUN[i][2]], true, i => add(o, ax, BUN[i][1]));
}

// punte: ciuffetti a cuneo (sezione schiacciata, punta che piega all'indietro), tanti e corti, appoggiati sulla base
// [el, az, lunghezza in R]: più lunghi in cima e davanti, corti verso la nuca e le tempie
const SPIKES = [[84, 0, 0.35], [68, -26, 0.35], [68, 26, 0.35], [66, 90, 0.29], [66, -90, 0.29], [70, 160, 0.26], [62, 135, 0.25], [62, -135, 0.25],
  [50, 0, 0.32], [48, -45, 0.29], [48, 45, 0.29], [44, 110, 0.22], [44, -110, 0.22], [46, 180, 0.20], [34, -20, 0.23], [34, 20, 0.23], [30, 70, 0.17], [30, -70, 0.17]];
function spikes(out, base) {
  const cols = 5;
  SPIKES.forEach(([el, az, len], k) => {
    const L = dirL(el, az), b = base(L), root = [L[0] * (b - 0.03), L[1] * (b - 0.03), L[2] * (b - 0.03)];
    const ax = norm(add(add(L, [0, 0.55, 0]), [0, 0, -1], 0.22)), B = norm(cross(ax, Math.abs(ax[0]) > 0.9 ? [0, 1, 0] : [1, 0, 0])), A = cross(B, ax);
    const tw = 0.6 + 0.25 * Math.sin(k * 2.3);   // schiacciamento diverso per ciuffo: niente file di coni uguali
    const ring = (h, r, sh) => (j) => { const a = 2 * Math.PI * j / cols; return add(add(add(add(root, ax, h), A, r * Math.cos(a)), B, r * tw * Math.sin(a)), [0, 0, -1], sh); };
    const rings = [ring(0, 0.2, 0), ring(len * 0.45, 0.1, 0.04), ring(len, 0, 0.12)];
    grid(out, 2, cols, (i, j) => rings[i](j), (i, j) => [lerp(TEX_EXTRA[0], TEX_EXTRA[1], j / cols), lerp(0.2, 1, i / 2)], true, () => root);
  });
}

// ---------------------------------------------------------------- cute sotto i capelli (zona testa della texture)
// alpha della tinta dei capelli sulla pelle in direzione (el, az): attaccatura morbida o nuca rasata a puntini
// basette: giro (gradi, davanti all'orecchio che sta a 109..125) e punta in basso
const BURN_AZ = [97, 107], BURN_EL = -12, NAPE_EL = [-34, -27];   // nuca: sotto NAPE_EL niente tinta (collo pulito)
export function scalpPaint(style, el, az, noise, burns = false) {
  const st = HAIR[style]; if (!st) return 0;
  let a = 0;
  const A = Math.abs(az), soft = lerp(5, 11, smooth(100, 170, A));   // sulla nuca la sfumatura è più lunga (taglio sfumato)
  if (st.line) a = smooth(prof(az, st.line) - soft, prof(az, st.line) + 0.5, el);
  if (st.buzz) a = Math.max(a, smooth(-4, 2, el - prof(az, st.buzz)) * (0.5 + 0.35 * noise));
  // basette: striscia davanti all'orecchio (giro BURN_AZ), dall'attaccatura fin verso metà orecchio, bordi morbidi
  const burn = smooth(BURN_AZ[0] - 4, BURN_AZ[0] + 2, A) * smooth(BURN_AZ[1] + 3, BURN_AZ[1] - 3, A) * smooth(BURN_EL - 5, BURN_EL + 4, el);
  if (burns) a = Math.max(a, burn * (st.buzz ? 0.5 + 0.35 * noise : 0.8)) * smooth(NAPE_EL[0], NAPE_EL[1], el);
  if (st.strip) {
    const L = dirL(el, az), w = Math.asin(Math.max(-1, Math.min(1, L[0]))) / DEG; let ph = Math.atan2(L[1], L[2]) / DEG; if (ph < -90) ph += 360;
    a = Math.max(a, smooth(st.strip.w + 3, st.strip.w - 3, Math.abs(w)) * smooth(st.strip.from - 4, st.strip.from + 2, ph) * smooth(st.strip.to + 4, st.strip.to - 2, ph));
  }
  return a;
}

// stessa tinta della cute per un punto della testa vera (modello realistico): head = riferimento dei capelli
// {c, up, fwd, right} (oggetti {x,y,z}), i = indice del texel per il rumore; con le basette
export function scalpAt(head, style, x, y, z, i) {
  const dx = x - head.c.x, dy = y - head.c.y, dz = z - head.c.z, h = head;
  const ly = dx * h.up.x + dy * h.up.y + dz * h.up.z, lx = dx * h.right.x + dy * h.right.y + dz * h.right.z, lz = dx * h.fwd.x + dy * h.fwd.y + dz * h.fwd.z;
  return scalpPaint(style, Math.atan2(ly, Math.hypot(lx, lz)) / DEG, Math.atan2(lx, lz) / DEG, (Math.imul(i, 2654435761) >>> 0) / 4294967296, true);
}

// ---------------------------------------------------------------- tinta (canvas 2D, coordinate su 1024)
const rgb = h => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];
const toHex = c => '#' + c.map(x => Math.max(0, Math.min(255, Math.round(x))).toString(16).padStart(2, '0')).join('');
export const mixHex = (a, b, t) => { const x = rgb(a), y = rgb(b); return toHex(x.map((v, i) => v + (y[i] - v) * t)); };
const lum = h => { const c = rgb(h); return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255; };
const rand = s => { let a = s; return () => { a = (a * 16807) % 2147483647; return a / 2147483647; }; };

export function paintHairTex(g, style, hairC, skin, rect) {
  const [x, y, w, h] = rect, st = HAIR[style] || {}, kind = st.paint || 'fine', l = lum(hairC);
  const dark = mixHex(hairC, '#000000', 0.38), deep = mixHex(hairC, '#000000', 0.62);
  const shine = mixHex(hairC, l > 0.6 ? '#ffffff' : '#fff1dc', 0.16 + 0.22 * (1 - l));
  const X = u => x + w * u, Y = v => y + h * v;
  g.save();
  g.fillStyle = hairC; g.fillRect(x - 16, y - 16, w + 32, h + 32);
  g.beginPath(); g.rect(x - 16, y - 16, w + 32, h + 32); g.clip();
  // calotta: più chiara in cima, lucentezza a metà, scura verso il bordo (profondità)
  const sx = X(0), sw = X(0.8) - sx, top = Y(0), edge = Y(TEX_EDGE + 0.04);
  const gr = g.createLinearGradient(0, Y(TEX_TOP), 0, Y(TEX_EDGE));
  gr.addColorStop(0, mixHex(hairC, '#000000', 0.06)); gr.addColorStop(0.42, mixHex(hairC, shine, 0.35)); gr.addColorStop(0.72, hairC); gr.addColorStop(1, mixHex(hairC, '#000000', 0.18)); // bordo come la cute dipinta sotto: niente riga scura all'attaccatura
  g.fillStyle = gr; g.fillRect(sx, top, sw, edge - top);
  const r = rand(97 + style * 31);
  const shellH = Y(TEX_EDGE) - Y(TEX_TOP);
  if (kind === 'curly' || kind === 'afro') {
    const n = kind === 'afro' ? 1400 : 900, rr = kind === 'afro' ? 1.1 : 1.6;
    for (let i = 0; i < n; i++) { const px = sx + r() * sw, py = Y(TEX_TOP) + r() * shellH, s = r(), a0 = r() * 6.3; g.strokeStyle = s < 0.5 ? dark : s < 0.85 ? mixHex(hairC, shine, 0.6) : shine; g.lineWidth = 0.7 + 0.5 * r(); g.globalAlpha = 0.45 + 0.35 * r(); g.beginPath(); g.arc(px, py, rr * (0.8 + r()), a0, a0 + 3.6); g.stroke(); }
    g.globalAlpha = 1;
  } else if (kind === 'braids') {
    const nb = 12, bw = sw / nb;
    for (let k = 0; k < nb; k++) {
      const cx = sx + bw * (k + 0.5);
      g.fillStyle = deep; g.globalAlpha = 0.55; g.fillRect(sx + bw * k - 0.6, top, 1.2, edge - top); g.globalAlpha = 1;
      g.strokeStyle = dark; g.lineWidth = 0.9;
      for (let py = Y(0.3); py < edge; py += 3.2) { g.beginPath(); g.moveTo(cx - bw * 0.42, py); g.lineTo(cx, py + 1.8); g.lineTo(cx + bw * 0.42, py); g.stroke(); }
      g.strokeStyle = shine; g.globalAlpha = 0.5; g.beginPath(); g.moveTo(cx - bw * 0.15, Y(0.3)); g.lineTo(cx - bw * 0.15, edge); g.stroke(); g.globalAlpha = 1;
    }
  } else if (kind !== 'none') {
    // ciocche sottili (lungo la caduta dei capelli), poco contrastate: niente bande
    const n = kind === 'slick' ? 160 : kind === 'brush' ? 60 : 110, a = kind === 'slick' ? 0.3 : 0.18;
    g.lineCap = 'round';
    for (let i = 0; i < n; i++) {
      const px = sx + r() * sw, y0 = Y(TEX_TOP) + r() * shellH * 0.5, len = shellH * (0.3 + r() * 0.6);
      g.strokeStyle = r() < 0.55 ? dark : shine; g.globalAlpha = a * (0.5 + r() * 0.5); g.lineWidth = 0.6 + r() * 0.8;
      g.beginPath(); g.moveTo(px, y0); g.lineTo(px + (r() - 0.5) * 2, Math.min(edge, y0 + len)); g.stroke();
    }
    g.globalAlpha = 1;
    if (kind === 'brush') for (let i = 0; i < 500; i++) { g.fillStyle = r() < 0.5 ? dark : shine; g.globalAlpha = 0.3; g.fillRect(sx + r() * sw, Y(TEX_TOP) + r() * shellH * 0.6, 0.9, 0.9); }
    g.globalAlpha = 1;
  }
  // banda di lucentezza spezzata a ciocche
  if (kind !== 'none') {
    const by = Y(kind === 'slick' ? 0.3 : 0.36), bh = shellH * (kind === 'slick' ? 0.2 : 0.14);
    for (let i = 0; i < 70; i++) { g.fillStyle = shine; g.globalAlpha = 0.18 + 0.25 * r(); g.fillRect(sx + r() * sw, by + (r() - 0.5) * bh * 0.6, 0.8 + r() * 1.6, bh * (0.4 + r() * 0.6)); }
    g.globalAlpha = 1;
  }
  // sfumatura rasata vicino al bordo (corti, spazzola): verso il colore della pelle
  if (kind === 'fade' || kind === 'brush') {
    const fg = g.createLinearGradient(0, Y(0.55), 0, Y(TEX_EDGE)); fg.addColorStop(0, 'rgba(0,0,0,0)'); fg.addColorStop(1, mixHex(hairC, skin, 0.5));
    g.fillStyle = fg; g.fillRect(sx, Y(0.55), sw, Y(TEX_EDGE + 0.04) - Y(0.55));
  }
  if (kind === 'fringe') { g.fillStyle = dark; g.globalAlpha = 0.5; g.fillRect(sx, Y(TEX_EDGE - 0.08), sw, Y(TEX_EDGE + 0.04) - Y(TEX_EDGE - 0.08)); g.globalAlpha = 1; }
  // riga: sottile linea di cute lungo il giro della riga, dalla fronte verso la cima
  if (kind === 'part' && st.part != null) {
    const ln = prof(st.part, st.line), C = st.cols || HAIR_SHELL_COLS, vOf = e => (e - ln) / (90 - ln);
    const u = lerp(TEX_SHELL[0], TEX_SHELL[1], Math.round((st.part + 180) / 360 * C) / C);
    g.strokeStyle = mixHex(skin, hairC, 0.55); g.lineWidth = 1.1; g.beginPath(); g.moveTo(X(u), Y(lerp(TEX_EDGE, TEX_TOP, vOf(ln + 2)))); g.lineTo(X(u), Y(lerp(TEX_EDGE, TEX_TOP, vOf(80)))); g.stroke();
  }
  // risvolto interno: scuro
  g.fillStyle = mixHex(dark, deep, 0.4); g.fillRect(sx, Y(TEX_UNDER - 0.03), sw, Y(1) + 16 - Y(TEX_UNDER - 0.03));
  // pezzi in più (coda, crocchia, punte): radice scura, punte più chiare, elastico
  const ex = X(TEX_EXTRA[0] - 0.03), ew = X(TEX_EXTRA[1] + 0.03) - ex;
  const eg = g.createLinearGradient(0, Y(0), 0, Y(1)); eg.addColorStop(0, dark); eg.addColorStop(0.3, mixHex(hairC, shine, 0.4)); eg.addColorStop(0.6, hairC); eg.addColorStop(1, mixHex(hairC, shine, 0.3));
  g.fillStyle = eg; g.fillRect(ex, Y(0) - 16, ew, h + 32);
  for (let i = 0; i < 40; i++) { g.strokeStyle = r() < 0.5 ? dark : shine; g.globalAlpha = 0.25; g.lineWidth = 0.7; const px = ex + r() * ew; g.beginPath(); g.moveTo(px, Y(r() * 0.5)); g.lineTo(px, Y(0.5 + r() * 0.5)); g.stroke(); }
  g.globalAlpha = 1;
  if (st.extra === 'tail' || st.extra === 'bun') { g.fillStyle = l < 0.25 ? '#b8323a' : '#26262c'; g.fillRect(ex, Y(TEX_TIE[0]), ew, Y(TEX_TIE[1]) - Y(TEX_TIE[0])); }
  g.restore();
}
