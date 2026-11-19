// Aspetto dei giocatori e stile della divisa: elenchi di opzioni e scelte deterministiche.
// Modulo puro (nessuna grafica, gira in Node): lo usano il motore (match.js), la carriera, la grafica e l'editor.
//
// look di un giocatore: { skin, hair, hairColor, eyes, eyeColor, brows, beard, boots } = indici negli elenchi sotto.
// Giocatori senza `look` (salvataggi vecchi, mercato, avversari): aspetto calcolato da id e nome, sempre uguale.
// Stile della divisa di una squadra: { fit, sleeves, collar, pattern, shorts, socks } = indici in KIT_OPTS.

export const SKINS = [['Chiarissima', '#f6d5bc'], ['Chiara', '#eec09c'], ['Rosata', '#e3ad8a'], ['Olivastra', '#d29b6c'], ['Ambrata', '#b67c50'], ['Bruna', '#93603b'], ['Scura', '#6e432a'], ['Molto scura', '#4b2d1e']];
export const HAIR_COLORS = [['Nero', '#17110e'], ['Castano scuro', '#3a2417'], ['Castano', '#5f3b22'], ['Castano chiaro', '#8b5b33'], ['Biondo scuro', '#a97c46'], ['Biondo', '#d7b26b'], ['Platino', '#eadfba'], ['Rosso', '#9e3c1b'], ['Ramato', '#c2692d'], ['Grigio', '#8e8e8e'], ['Bianco', '#e6e6e6']];
// capelli: m = mesh vera sulla testa (src/players3d.js), i nomi sono quelli dell'editor
export const HAIR_STYLES = ['Calvo', 'Rasato', 'Corti', 'Spazzola', 'Ciuffo', 'Riga di lato', 'Cresta', 'A punte', 'Ricci', 'Afro', 'Caschetto', 'Lunghi', 'Coda', 'Chignon', 'Treccine', 'Frangia', 'All\'indietro'];
export const EYE_SHAPES = ['Tondi', 'A mandorla', 'Sottili', 'Grandi', 'Allungati', 'Assonnati'];
export const EYE_COLORS = [['Marrone scuro', '#3b2517'], ['Marrone', '#6c4424'], ['Nocciola', '#8f6b33'], ['Verde', '#4e7b3a'], ['Azzurro', '#4a90ca'], ['Grigio', '#7c8995'], ['Ambra', '#b27b1f']];
export const BROWS = ['Naturali', 'Sottili', 'Folte', 'Arcuate', 'Dritte', 'Decise'];
export const BEARDS = ['Nessuna', 'Ombra', 'Pizzetto', 'Baffi', 'Baffi e pizzetto', 'Barba corta', 'Barba piena'];
export const BOOTS = [['Nere', '#17171b'], ['Bianche', '#efefef'], ['Rosse', '#d4202c'], ['Gialle', '#f2d21b'], ['Azzurre', '#2fa6e8'], ['Arancio', '#ff7a1a']];

// numero di opzioni per ogni campo del look (per normalizzare e per l'editor)
export const LOOK_N = { skin: SKINS.length, hair: HAIR_STYLES.length, hairColor: HAIR_COLORS.length, eyes: EYE_SHAPES.length, eyeColor: EYE_COLORS.length, brows: BROWS.length, beard: BEARDS.length, boots: BOOTS.length };
export const LOOK_KEYS = Object.keys(LOOK_N);

export const KIT_OPTS = {
  fit: ['Aderente', 'Larga'],
  sleeves: ['Corte', 'Lunghe', 'Senza maniche'],
  collar: ['Girocollo', 'A V', 'Polo'],
  pattern: ['Tinta unita', 'Righe verticali', 'Righe orizzontali', 'Banda diagonale', 'Metà e metà'],
  shorts: ['Corti', 'Lunghi'],
  socks: ['Alti', 'Bassi', 'Ripiegati'],
};
export const KIT_KEYS = Object.keys(KIT_OPTS);
export const DEFAULT_KIT_STYLE = { fit: 0, sleeves: 0, collar: 0, pattern: 0, shorts: 0, socks: 0 };

// ---------------------------------------------------------------- numeri pseudo-casuali senza stato globale
export function hash32(...parts) {
  let h = 2166136261 >>> 0;
  for (const p of parts) {
    const s = String(p);
    for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619) >>> 0; }
    h ^= 0x9e3779b9; h = Math.imul(h ^ (h >>> 15), 2246822507) >>> 0;
  }
  return h >>> 0;
}
export function seeded(seed) {
  let a = seed >>> 0;
  return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
const wpick = (r, w) => { let t = 0; for (const x of w) t += x; let u = r() * t; for (let i = 0; i < w.length; i++) { u -= w[i]; if (u < 0) return i; } return w.length - 1; };
const ipick = (r, n) => Math.floor(r() * n) % n;

// ---------------------------------------------------------------- aspetto
// aspetto plausibile da un seme: i capelli chiari sono più frequenti con la pelle chiara, barba e calvi più rari
export function lookFromSeed(seed) {
  const r = seeded(hash32('look', seed));
  const skin = wpick(r, [10, 14, 12, 12, 9, 8, 7, 5]);
  const dark = skin >= 4;
  const hairColor = dark ? wpick(r, [60, 25, 8, 2, 1, 1, 0, 0, 0, 2, 1]) : wpick(r, [14, 20, 18, 12, 9, 9, 2, 4, 4, 3, 1]);
  const hair = dark ? wpick(r, [3, 9, 10, 6, 4, 3, 3, 3, 9, 7, 1, 2, 2, 2, 7, 2, 3]) : wpick(r, [2, 7, 14, 7, 9, 8, 2, 4, 5, 1, 4, 4, 3, 3, 1, 5, 6]);
  return {
    skin, hair, hairColor,
    eyes: ipick(r, EYE_SHAPES.length),
    eyeColor: dark ? wpick(r, [55, 35, 8, 1, 0, 1, 2]) : wpick(r, [18, 24, 14, 13, 18, 9, 4]),
    brows: wpick(r, [30, 12, 16, 12, 16, 14]),
    beard: wpick(r, [50, 14, 7, 5, 6, 10, 8]),
    boots: wpick(r, [30, 18, 12, 10, 14, 16]),
  };
}
// completa e corregge un look (campi mancanti o fuori elenco → valori validi, senza toccare l'originale)
export function normalizeLook(l, fallback) {
  const base = fallback || { skin: 1, hair: 2, hairColor: 2, eyes: 0, eyeColor: 1, brows: 0, beard: 0, boots: 0 };
  const out = {};
  for (const k of LOOK_KEYS) { const v = l && Number.isInteger(l[k]) ? l[k] : base[k]; out[k] = ((v % LOOK_N[k]) + LOOK_N[k]) % LOOK_N[k]; }
  return out;
}
// aspetto di un giocatore della carriera (o di un avversario generato): il suo `look` se c'è, altrimenti da id e nome
export function lookOf(p) {
  if (!p) return lookFromSeed(0);
  const auto = lookFromSeed(hash32(p.id, p.name || ''));
  return p.look && typeof p.look === 'object' ? normalizeLook(p.look, auto) : auto;
}

// ---------------------------------------------------------------- stile della divisa
export function normalizeKitStyle(st) {
  const out = {};
  for (const k of KIT_KEYS) { const n = KIT_OPTS[k].length, v = st && Number.isInteger(st[k]) ? st[k] : DEFAULT_KIT_STYLE[k]; out[k] = ((v % n) + n) % n; }
  return out;
}
export function kitStyleFromSeed(seed) {
  const r = seeded(hash32('kit', seed));
  return { fit: wpick(r, [6, 4]), sleeves: wpick(r, [12, 4, 1]), collar: ipick(r, 3), pattern: wpick(r, [8, 4, 3, 2, 2]), shorts: wpick(r, [8, 2]), socks: wpick(r, [8, 2, 3]) };
}

// ---------------------------------------------------------------- numeri di maglia
// cognome per la schiena: "L. Ferrante" → "FERRANTE"
export const backName = name => String(name || '').replace(/^.*\.\s*/, '').trim().toUpperCase().slice(0, 12);
const PREF = { P: [1, 12, 22], D: [2, 3, 4, 5, 6, 13, 14, 15], C: [8, 10, 7, 16, 17, 18, 20], A: [9, 11, 19, 21, 23] };
// numeri per una rosa: chi ha già un numero valido e non doppio lo tiene, gli altri ricevono il primo libero per ruolo.
// Deterministico (dipende solo dall'ordine della rosa). Ritorna una mappa id → numero, non modifica i giocatori.
export function squadNumbers(squad) {
  const used = new Set(), out = new Map();
  for (const p of squad) if (Number.isInteger(p.num) && p.num >= 1 && p.num <= 99 && !used.has(p.num)) { used.add(p.num); out.set(p.id, p.num); }
  for (const p of squad) {
    if (out.has(p.id)) continue;
    let n = (PREF[p.pos] || []).find(x => !used.has(x));
    if (!n) { n = 24; while (used.has(n) && n < 99) n++; }
    used.add(n); out.set(p.id, n);
  }
  return out;
}
