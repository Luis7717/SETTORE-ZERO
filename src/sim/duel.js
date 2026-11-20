// Duello col difensore, dribbling e calo delle statistiche per l'uso (dentro la partita).
// I metodi vengono copiati su Match.prototype (vedi match.js): `this` è la partita.
import { HW, HL, clamp, hyp } from './core.js';

// Regolazioni (misurate con test/diag-flow.mjs e i test in test/unit/duel.test.mjs)
export const DUEL_R = 7;       // un avversario davanti più vicino di così al portatore apre il duello (m)
const DUEL_FRONT = 0.35;       // "davanti": coseno minimo tra verso di corsa e direzione dell'avversario (~70°)
const DUEL_END_R = 9.5;        // il duello si chiude ("lontano") se l'avversario si allontana oltre (m)
const DUEL_BEHIND = -0.2;      // ... o se resta alle spalle (coseno sotto questo valore)
export const DUEL_GUARD = 0.6; // per questo tempo di partita il difensore del duello non può rubare palla (s)
export const DUEL_MAX = 2.5;   // durata massima del duello (s)
const DUEL_CD = 1.0;           // dopo la fine, lo stesso portatore non apre un nuovo duello per questo tempo (s)
const DRIB_BASE = 0.5;         // probabilità di riuscita a pari dribbling e difesa
const DRIB_SKILL = 1.2;        // quanto pesa la differenza dribbling - difesa (per punto / 100)
const DRIB_MIN = 0.15, DRIB_MAX = 0.85; // limiti della probabilità di riuscita
const DRIB_STUN = 0.8;         // dribbling riuscito: il difensore resta sbilanciato (fermo) per questo tempo da quando il portatore lo raggiunge (s)
const DRIB_REACH = 1;          // ... "raggiunto" = portatore arrivato a questa distanza dal difensore (m)
const DRIB_BEAT = 1.2;         // finito lo sbilanciamento, il difensore saltato resta ancora "saltato" per questo tempo (s;
                               // sbilanciato + saltato = 2 s, quanto il giochetto più lungo della grafica, l'arcobaleno):
export const DRIB_BEAT_SPD = 0.5; // ... corre a questa frazione della velocità, non contrasta chi l'ha saltato e non gli riapre il duello
const DRIB_PROTECT = 0.35;     // ... e il portatore non può essere contrastato da nessuno per questo tempo (s)
const DRIB_PAST = 3;           // il portatore punta a questa distanza oltre il difensore (m)
const DRIB_SIDE = 2.5;         // ... spostato di lato di tanto (m)
const DRIB_STEAL_R = 2;        // dribbling fallito: entro questa distanza il difensore può prendere il pallone (m)
const DRIB_STEAL = 0.6;        // ... e lo prende con questa probabilità (altrimenti lo devia)
const DRIB_CD = 1.2;           // tempo tra due tentativi di dribbling dello stesso giocatore (s)
export const AI_DRIB_R = 3.2;  // l'IA tenta il dribbling solo con l'avversario davanti entro questa distanza (m)
const AI_DRIB_TRY = 0.22;      // probabilità di tentare a pari dribbling e difesa (cresce col vantaggio)
export const WEAR_DRI = 0.03, WEAR_DRI_MIN = 0.8; // ogni dribbling riuscito: -3% di dribbling, fino all'80%
export const ZONE_DIST = 20;   // negli ultimi metri prima della porta avversaria: area di tiro (rallenty, si può passare)
export const WEAR_TES = 0.02, WEAR_TES_MIN = 0.85; // ogni colpo di testa vinto: -2% di colpi di testa, fino all'85%

export class DuelMethods {
  duelFor(T) { return !!(this.duel && this.duel.team === T); }
  // area di tiro: il portatore controllato della squadra umana T è negli ultimi ZONE_DIST m prima della porta avversaria
  inZone(T) {
    const c = this.ball.owner;
    if (!c || c.team !== T || !this.human[T] || this.ctrl[T] !== c || this.phase !== 'play' || c.state !== 'play') return false;
    return (T === 0 ? HL - c.y : c.y + HL) <= ZONE_DIST;
  }
  // si può passare (duello col difensore o area di tiro)
  passFor(T) { return this.duelFor(T) || this.inZone(T); }
  // il difensore del duello non può ancora rubare palla
  duelGuard(o) { const d = this.duel; return !!(d && d.o === o && d.t < DUEL_GUARD); }
  // o è stato saltato col dribbling da c e non si è ancora ripreso: non può contrastarlo né riaprirgli il duello
  beaten(o, c) { return o.beat > 0 && o.beatBy === c; }

  // verso di corsa del portatore (fermo: verso cui guarda)
  runDir(c) { const v = hyp(c.vx, c.vy); return v > 1.5 ? [c.vx / v, c.vy / v] : [c.fx, c.fy]; }
  frontDot(c, o) { const [rx, ry] = this.runDir(c), dx = o.x - c.x, dy = o.y - c.y, d = hyp(dx, dy) || 1; return (dx * rx + dy * ry) / d; }

  // avversario più vicino davanti al portatore entro `R`
  frontOpp(c, R) {
    let best = null, bd = R;
    for (const o of this.players) {
      if (o.team === c.team || o.off || o.stun > 0 || this.beaten(o, c) || (o.state !== 'play' && o.state !== 'prep')) continue;
      const d = hyp(o.x - c.x, o.y - c.y);
      if (d < bd && this.frontDot(c, o) > DUEL_FRONT) { bd = d; best = o; }
    }
    return best;
  }

  // apre e chiude il duello del portatore della squadra umana (chiamato a ogni passo prima dei contrasti)
  updateDuel(dt) {
    for (let T = 0; T < 2; T++) if (this.duelCd[T] > 0) this.duelCd[T] -= dt;
    const b = this.ball, d = this.duel;
    if (d) {
      d.t += dt;
      let why = null;
      if (this.phase !== 'play') why = 'gioco fermo';
      else if (b.owner !== d.p) why = !b.owner && b.kick && b.kick.kicker === d.p ? 'passaggio' : 'palla persa';
      else if (d.o.off || hyp(d.o.x - d.p.x, d.o.y - d.p.y) > DUEL_END_R || this.frontDot(d.p, d.o) < DUEL_BEHIND) why = 'lontano';
      else if (d.t >= DUEL_MAX) why = 'tempo';
      if (why) this.endDuel(why);
      return;
    }
    if (this.phase !== 'play') return;
    const c = b.owner;
    if (!c || !this.human[c.team] || this.ctrl[c.team] !== c || c.state !== 'play') return;
    if (this.duelCd[c.team] > 0 && this.duelCdP[c.team] === c) return;
    const o = this.frontOpp(c, DUEL_R);
    if (!o) return;
    this.duel = { team: c.team, p: c, o, t: 0 };
    this.ev('duel_start', { p: c, o });
  }
  endDuel(reason) {
    const d = this.duel; if (!d) return;
    this.duel = null; this.duelCd[d.team] = DUEL_CD; this.duelCdP[d.team] = d.p;
    this.ev('duel_end', { p: d.p, o: d.o, reason });
  }

  dribbleChance(p, o) { return clamp(DRIB_BASE + DRIB_SKILL * (p.st.dri - o.st.dif) / 100, DRIB_MIN, DRIB_MAX); }

  // Tentativo di dribbling del portatore p contro o (stessa regola per umano e IA). Ritorna true se riesce.
  dribble(p, o) {
    const b = this.ball, T = p.team;
    const ok = this.rnd() < this.dribbleChance(p, o);
    p.dribCd = DRIB_CD;
    const dx = o.x - p.x, dy = o.y - p.y, d = hyp(dx, dy) || 1, ux = dx / d, uy = dy / d;
    if (ok) {
      // di lato verso il centro se si è vicini alla linea laterale, altrimenti a caso
      const side = Math.abs(p.x) > HW - 8 ? -Math.sign(p.x) * Math.sign(uy || 1) : (this.rnd() < 0.5 ? -1 : 1);
      const nx = -uy * side, ny = ux * side;
      const tx = clamp(p.x + ux * (d + DRIB_PAST) + nx * DRIB_SIDE, -HW + 1, HW - 1), ty = clamp(p.y + uy * (d + DRIB_PAST) + ny * DRIB_SIDE, -HL + 1, HL - 1);
      const wx = tx - p.x, wy = ty - p.y, wn = hyp(wx, wy) || 1, sp = this.vmax(p) * 1.05;
      p.vx = wx / wn * sp; p.vy = wy / wn * sp; p.fx = wx / wn; p.fy = wy / wn;
      p.dx = p.tx = tx; p.dy = p.ty = ty; p.aiT = Math.max(p.aiT, 0.35);
      p.protect = Math.max(p.protect, DRIB_PROTECT);
      // il tasto si può toccare appena si apre il duello (difensore a 7 m): lo sbilanciamento conta da quando il portatore
      // arriva addosso al difensore, altrimenti finiva prima e il difensore, ancora davanti, gli si attaccava addosso
      o.stun = DRIB_STUN + Math.max(0, d - DRIB_REACH) / sp; o.contact = 0; o.vx *= 0.3; o.vy *= 0.3;
      o.beat = o.stun + DRIB_BEAT; o.beatBy = p;
      if (o.state === 'prep') { o.state = 'play'; o.warn = false; }
      this.wearDown(p, 'dri', WEAR_DRI, WEAR_DRI_MIN);
      // la corsa dura finché il portatore non arriva oltre il difensore (prima tornava dritto e gli passava accanto)
      if (this.human[T] && this.ctrl[T] === p) this.move[T] = { x: tx, y: ty, ttl: Math.max(0.6, wn / sp + 0.15), held: false, sprint: false };
    } else {
      p.stun = Math.max(p.stun, 0.35); p.tackleCd = 0.6;
      if (this.human[T] && this.ctrl[T] === p) this.move[T] = null;
      if (d < DRIB_STEAL_R && this.rnd() < DRIB_STEAL) {
        b.owner = o; b.prev = b.last; b.last = o; b.kick = null; this.lastPass = null;
        o.protect = 0.5; o.contact = 0; o.aiT = 0.25; o.dx = o.x; o.dy = o.y; o.holdN = 0;
        this.ev('tackle', { p: o, on: p, dribble: true });
      } else {
        // deviato: il pallone schizza verso il difensore, un po' di lato
        const a = Math.atan2(uy, ux) + (this.rnd() - 0.5) * 1.4, v = 5 + this.rnd() * 3;
        b.owner = null; b.vx = Math.cos(a) * v; b.vy = Math.sin(a) * v; b.vh = 0.8; b.h = 0.05; b.ct = 0;
        b.kick = null; b.shot = null; b.noP = p; b.noT = 0.4; this.lastPass = null; this.predT = 0;
      }
    }
    this.ev('dribble', { p, o, ok });
    if (this.duel && this.duel.p === p) this.endDuel(ok ? 'dribbling' : 'palla persa');
    return ok;
  }

  // l'IA (e l'umano simulato) col pallone e un avversario davanti a volte prova il dribbling
  aiDribble(p) {
    if (p.dribCd > 0 || p.stun > 0) return false;
    const o = this.frontOpp(p, AI_DRIB_R);
    if (!o) return false;
    if (this.rnd() >= clamp(AI_DRIB_TRY + (p.st.dri - o.st.dif) / 100, 0.05, 0.6)) return false;
    this.dribble(p, o);
    return true;
  }

  // calo per l'uso di una statistica dentro la partita (p.wear[key] da 1 fino a `min`); torna pieno alla partita dopo
  wearDown(p, key, step, min) {
    const old = p.wear[key], nw = Math.max(min, old - step);
    if (nw >= old) return;
    p.st[key] *= nw / old; p.wear[key] = nw;
  }
}
