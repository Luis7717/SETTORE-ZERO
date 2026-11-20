// Giochetti del dribbling: solo grafica (il motore decide se il dribbling riesce, qui si sceglie come farlo vedere).
// Più è alto il dribbling del giocatore, più i giochetti possibili sono belli. Nessuna dipendenza da three.js.

// in ordine di bellezza; dur = durata dell'animazione (s, nel tempo della grafica)
export const TRICKS = [
  { id: 'finta', name: 'Finta di corpo', dur: 0.55 },
  { id: 'doppiopasso', name: 'Doppio passo', dur: 0.75 },
  { id: 'elastico', name: 'Elastico', dur: 0.6 },
  { id: 'veronica', name: 'Veronica', dur: 0.7 },
  { id: 'sombrero', name: 'Sombrero', dur: 0.8 },
  { id: 'arcobaleno', name: 'Colpo dell\'arcobaleno', dur: 0.85 },
];
const DRI_FIRST = 35; // sotto questo dribbling solo la finta di corpo
const DRI_STEP = 10;  // ogni 10 punti di dribbling si sblocca un giochetto più bello

// giochetto più bello che il giocatore sa fare (indice in TRICKS)
export function bestTrick(dri) { return Math.max(0, Math.min(TRICKS.length - 1, Math.floor((dri - DRI_FIRST) / DRI_STEP))); }

// scelta del giochetto: di solito il più bello che sa fare, a volte uno o due più semplici. r = numero casuale in [0, 1)
export function chooseTrick(dri, r) {
  const top = bestTrick(dri), down = r < 0.6 ? 0 : r < 0.9 ? 1 : 2;
  return TRICKS[Math.max(0, top - down)];
}

const bump = q => Math.sin(Math.PI * Math.min(1, Math.max(0, q)));

// spostamento del pallone rispetto alla posizione vera durante il giochetto (q = avanzamento 0..1):
// { f: avanti (m), s: di lato (m, verso `side`), h: altezza (m) }
export function ballOffset(id, q) {
  switch (id) {
    case 'finta': return { f: 0, s: 0.18 * Math.sin(2 * Math.PI * q), h: 0 };
    case 'doppiopasso': return { f: 0.1 * bump(q), s: 0, h: 0 };
    // fuori con l'esterno, poi dentro di colpo dall'altra parte
    case 'elastico': { if (q < 0.45) return { f: 0, s: 0.5 * bump(q / 0.9), h: 0 }; const u = (q - 0.45) / 0.55; return { f: 0, s: 0.5 * Math.cos(Math.PI * u * 1.5) * (1 - u), h: 0 }; }
    // il giocatore gira sul pallone: il pallone gli fa un giro intorno ai piedi
    case 'veronica': { const a = 2 * Math.PI * q; return { f: 0.35 * (Math.cos(a) - 1), s: 0.35 * Math.sin(a), h: 0 }; }
    // pallone alzato sopra la testa del difensore
    case 'sombrero': return { f: 0.8 * bump(q), s: 0, h: 1.9 * bump(q) };
    // di tacco da dietro, sopra la propria testa, e giù davanti
    case 'arcobaleno': return { f: q < 0.5 ? -0.6 * bump(2 * q) : 0.6 * bump(2 * q - 1), s: 0, h: 2.3 * bump(q) };
    default: return { f: 0, s: 0, h: 0 };
  }
}
