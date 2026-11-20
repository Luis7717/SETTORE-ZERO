// Piccoli aiuti comuni ai menu (src/ui.js, src/ui-squad.js).
import { headingOf } from './sim.js';

export const hex = n => '#' + n.toString(16).padStart(6, '0');
export const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
// statistiche nella scheda giocatore; 'fis' è la resistenza, 'tes' i colpi di testa (calcolati se il salvataggio è vecchio)
export const STATS = [['vel', 'VEL'], ['fis', 'RES'], ['tir', 'TIR'], ['pas', 'PAS'], ['dri', 'DRI'], ['dif', 'DIF'], ['tes', 'TES']];
export const GK_STATS = [['por', 'POR'], ['pas', 'PAS'], ['fis', 'RES'], ['vel', 'VEL']];
export const statOf = (p, k) => (k === 'tes' ? headingOf(p) : p[k]);
// fascia di valutazione: colore del numero e del bordo della carta
export const ovrCls = o => (o >= 75 ? 'o4' : o >= 65 ? 'o3' : o >= 55 ? 'o2' : 'o1');
