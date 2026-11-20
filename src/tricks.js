// Giochetti del dribbling: solo grafica (il motore decide se il dribbling riesce, qui si sceglie come farlo vedere).
// Più è alto il dribbling del giocatore, più i giochetti possibili sono belli. Nessuna dipendenza da three.js.
import { trickMove, trickDuration, MATCH_OPT, MATCH_SCALE } from './moves/tricks.js';

// in ordine di bellezza; dur = durata dell'animazione (s, nel tempo della grafica): quella del movimento calcolato
// per la partita (src/moves/tricks.js), letta la prima volta che serve
export const TRICKS = [
  { id: 'finta', name: 'Finta di corpo' },
  { id: 'doppiopasso', name: 'Doppio passo' },
  { id: 'elastico', name: 'Elastico' },
  { id: 'veronica', name: 'Veronica' },
  { id: 'sombrero', name: 'Sombrero' },
  { id: 'arcobaleno', name: "Colpo dell'arcobaleno" },
];
for (const T of TRICKS) Object.defineProperty(T, 'dur', { get: () => trickDuration(T.id), enumerable: true });
const DRI_FIRST = 35; // sotto questo dribbling solo la finta di corpo
const DRI_STEP = 10;  // ogni 10 punti di dribbling si sblocca un giochetto più bello

// giochetto più bello che il giocatore sa fare (indice in TRICKS)
export function bestTrick(dri) { return Math.max(0, Math.min(TRICKS.length - 1, Math.floor((dri - DRI_FIRST) / DRI_STEP))); }

// scelta del giochetto: di solito il più bello che sa fare, a volte uno o due più semplici. r = numero casuale in [0, 1)
export function chooseTrick(dri, r) {
  const top = bestTrick(dri), down = r < 0.6 ? 0 : r < 0.9 ? 1 : 2;
  return TRICKS[Math.max(0, top - down)];
}

// spostamento del pallone rispetto alla posizione vera durante il giochetto (q = avanzamento 0..1), preso dal pallone
// del movimento calcolato (mosso dal piede, voli con la gravità vera): { f: avanti (m), s: di lato (m, verso `side`:
// col destro, side = 1, è la sinistra del giocatore), h: altezza (m) }. A inizio e fine è zero.
export function ballOffset(id, q) {
  const mv = trickMove(TRICKS.some(T => T.id === id) ? id : 'finta', MATCH_OPT), B = MATCH_OPT.B, S = MATCH_SCALE;
  const p = mv.at(Math.min(1, Math.max(0, q)) * mv.T).ball.p;
  return { f: (p[2] - B[2]) * S, s: (p[0] - B[0]) * S, h: (p[1] - B[1]) * S };
}
