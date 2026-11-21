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
const DRIB_WIDE = 1.5;         // ... ma di più se serve per passare accanto al difensore ad almeno tanto di lato (m; da vicino
                               // la linea dritta verso il punto oltre gli passava addosso)
const DRIB_STEAL_R = 2;        // dribbling fallito: entro questa distanza il difensore può prendere il pallone (m)
const DRIB_STEAL = 0.6;        // ... e lo prende con questa probabilità (altrimenti lo devia)
const DRIB_CD = 1.2;           // tempo tra due tentativi di dribbling dello stesso giocatore (s)
export const AI_DRIB_R = 3.2;  // l'IA tenta il dribbling solo con l'avversario davanti entro questa distanza (m)
const AI_DRIB_TRY = 0.22;      // probabilità di tentare a pari dribbling e difesa (cresce col vantaggio)
export const WEAR_DRI = 0.03, WEAR_DRI_MIN = 0.8; // ogni dribbling riuscito: -3% di dribbling, fino all'80%
export const ZONE_DIST = 20;   // negli ultimi metri prima della porta avversaria: area di tiro (rallenty, si può passare)
export const WEAR_TES = 0.02, WEAR_TES_MIN = 0.85; // ogni colpo di testa vinto: -2% di colpi di testa, fino all'85%
// Davanti o dietro "per linee" (Luis 2026-11-21): si divide il campo in linee parallele alle linee di porta. L'avversario
// è davanti solo se sta su una linea più avanti (verso la porta avversaria) di almeno LEVEL_TOL; altrimenti è alla pari o
// dietro. Davanti = duello (Dribbling o passaggio disegnato); alla pari o dietro = fuga (Scatto o passaggio disegnato).
export const LEVEL_TOL = 0.5;  // "alla pari": fino a tanto più avanti del portatore conta ancora come stessa linea (m)
export const FLEE_R = 4;       // avversario alla pari o dietro più vicino di così al portatore apre la fuga (m)
const FLEE_END_R = 7;          // la fuga si chiude se l'avversario si allontana oltre (m)
export const FLEE_MAX = 2.5;   // durata massima della fuga (s)
const FLEE_CD = 1.5;           // dopo la fine, lo stesso portatore non apre una nuova fuga per questo tempo (s)
export const BURST_T = 1.2;    // Scatto: per questo tempo il portatore corre più veloce (s)
export const BURST_SPD = 1.15; // ... di questo fattore (sopra lo scatto normale)
const BURST_SHAKE = 0.6;       // ... e l'avversario resta indietro: corre piano e non lo contrasta per questo tempo (s)
export const BURST_RUN = 14;   // ... poi il portatore prosegue dritto fino a questa distanza (m)
// Dribbling prenotato (Luis 2026-11-21: "il dribbling lo deve fare vicino all'avversario"): il tasto non decide subito,
// il portatore corre verso il difensore puntando il lato scelto e il dribbling vero scatta solo quando gli arriva vicino.
export const DRIB_NEAR = 2;    // il dribbling prenotato scatta quando il portatore arriva a questa distanza dal difensore (m)
export const DRIB_BOOK_MAX = 1.2; // ... o comunque dopo questo tempo di partita dal tocco, anche se non si è avvicinato (s)
const DRIB_AIM = 1.2;          // ... intanto corre verso il difensore puntando un punto spostato di tanto dal lato scelto (m)
const SIDE_LEAN = 1.5;         // scelta del lato: peso dello sbilanciamento del difensore rispetto alla linea di corsa (per m)
const SIDE_LEAN_T = 0.3;       // ... in cui conta anche dove sta andando il difensore (velocità di lato per questo tempo, s)
const SIDE_FREE = 0.25;        // ... peso dello spazio libero da altri avversari oltre il difensore (per m)
const SIDE_FREE_MAX = 8;       // ... spazio contato fino a tanto (m)
const SIDE_EDGE = 8;           // ... entro tanto dalla linea laterale si va sempre verso il centro (m)

export class DuelMethods {
  duelFor(T) { return !!(this.duel && this.duel.team === T); }
  // la squadra T ha toccato Dribbling e il portatore sta andando verso il difensore (il tasto non serve più)
  dribBooked(T) { return !!(this.duel && this.duel.team === T && this.duel.side); }
  // area di tiro: il portatore controllato della squadra umana T è negli ultimi ZONE_DIST m prima della porta avversaria
  inZone(T) {
    const c = this.ball.owner;
    if (!c || c.team !== T || !this.human[T] || this.ctrl[T] !== c || this.phase !== 'play' || c.state !== 'play') return false;
    return (T === 0 ? HL - c.y : c.y + HL) <= ZONE_DIST;
  }
  // si può passare (duello col difensore, fuga o area di tiro)
  passFor(T) { return this.duelFor(T) || this.fleeFor(T) || this.inZone(T); }
  // il difensore del duello non può ancora rubare palla
  duelGuard(o) { const d = this.duel; return !!(d && d.o === o && d.t < DUEL_GUARD); }
  // o è stato saltato col dribbling da c e non si è ancora ripreso: non può contrastarlo né riaprirgli il duello
  beaten(o, c) { return o.beat > 0 && o.beatBy === c; }

  // verso di corsa del portatore (fermo: verso cui guarda)
  runDir(c) { const v = hyp(c.vx, c.vy); return v > 1.5 ? [c.vx / v, c.vy / v] : [c.fx, c.fy]; }
  frontDot(c, o) { const [rx, ry] = this.runDir(c), dx = o.x - c.x, dy = o.y - c.y, d = hyp(dx, dy) || 1; return (dx * rx + dy * ry) / d; }

  // o sta su una linea più avanti di c (verso la porta che attacca c) di almeno LEVEL_TOL
  aheadLine(c, o) { return (o.y - c.y) * (c.team === 0 ? 1 : -1) > LEVEL_TOL; }

  // avversario più vicino davanti al portatore entro `R` (lines: anche più avanti "per linee", per il duello della persona)
  frontOpp(c, R, lines = false) {
    let best = null, bd = R;
    for (const o of this.players) {
      if (o.team === c.team || o.off || o.stun > 0 || this.beaten(o, c) || (o.state !== 'play' && o.state !== 'prep')) continue;
      const d = hyp(o.x - c.x, o.y - c.y);
      if (d < bd && this.frontDot(c, o) > DUEL_FRONT && (!lines || this.aheadLine(c, o))) { bd = d; best = o; }
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
      else if (d.o.off || hyp(d.o.x - d.p.x, d.o.y - d.p.y) > DUEL_END_R || this.frontDot(d.p, d.o) < DUEL_BEHIND || !this.aheadLine(d.p, d.o)) why = 'lontano';
      else if (d.t >= DUEL_MAX && !d.side) why = 'tempo'; // col dribbling prenotato decide DRIB_BOOK_MAX
      if (why) this.endDuel(why); // anche la prenotazione del dribbling finisce qui (palla persa, difensore lontano, ...)
      else if (d.side) this.dribBookStep(d, dt);
      return;
    }
    if (this.phase !== 'play') return;
    const c = b.owner;
    if (!c || !this.human[c.team] || this.ctrl[c.team] !== c || c.state !== 'play') return;
    if (this.duelCd[c.team] > 0 && this.duelCdP[c.team] === c) return;
    const o = this.frontOpp(c, DUEL_R, true);
    if (!o) return;
    // side: 0 = niente dribbling prenotato, ±1 = prenotato da quel lato (bt = tempo dal tocco)
    this.duel = { team: c.team, p: c, o, t: 0, side: 0, bt: 0 };
    this.ev('duel_start', { p: c, o });
  }
  endDuel(reason) {
    const d = this.duel; if (!d) return;
    this.duel = null; this.duelCd[d.team] = DUEL_CD; this.duelCdP[d.team] = d.p;
    this.ev('duel_end', { p: d.p, o: d.o, reason });
  }

  fleeFor(T) { return !!(this.flee && this.flee.team === T); }
  // avversario più vicino alla pari o dietro il portatore (per linee) entro `R`
  sideOpp(c, R) {
    let best = null, bd = R;
    for (const o of this.players) {
      if (o.team === c.team || o.off || o.stun > 0 || this.beaten(o, c) || o.state !== 'play') continue;
      const d = hyp(o.x - c.x, o.y - c.y);
      if (d < bd && !this.aheadLine(c, o)) { bd = d; best = o; }
    }
    return best;
  }
  // apre e chiude la fuga del portatore della squadra umana (dopo updateDuel: il duello ha la precedenza)
  updateFlee(dt) {
    for (let T = 0; T < 2; T++) if (this.fleeCd[T] > 0) this.fleeCd[T] -= dt;
    const b = this.ball, f = this.flee;
    if (f) {
      f.t += dt;
      let why = null;
      if (this.phase !== 'play') why = 'gioco fermo';
      else if (b.owner !== f.p) why = !b.owner && b.kick && b.kick.kicker === f.p ? 'passaggio' : 'palla persa';
      else if (this.duel) why = 'duello';
      else if (f.o.off || f.o.stun > 0 || hyp(f.o.x - f.p.x, f.o.y - f.p.y) > FLEE_END_R || this.aheadLine(f.p, f.o)) why = 'lontano';
      else if (f.t >= FLEE_MAX) why = 'tempo';
      if (why) this.endFlee(why);
      return;
    }
    if (this.phase !== 'play' || this.duel) return;
    const c = b.owner;
    if (!c || !this.human[c.team] || this.ctrl[c.team] !== c || c.state !== 'play' || c.burst > 0) return;
    if (this.fleeCd[c.team] > 0 && this.fleeCdP[c.team] === c) return;
    const o = this.sideOpp(c, FLEE_R);
    if (!o) return;
    this.flee = { team: c.team, p: c, o, t: 0 };
    this.ev('flee_start', { p: c, o });
  }
  endFlee(reason) {
    const f = this.flee; if (!f) return;
    this.flee = null; this.fleeCd[f.team] = FLEE_CD; this.fleeCdP[f.team] = f.p;
    this.ev('flee_end', { p: f.p, o: f.o, reason });
  }
  // Scatto: il portatore si stacca dall'avversario e prosegue dritto nel verso di corsa
  burst(p, o) {
    const T = p.team, [rx, ry] = this.runDir(p);
    const tx = clamp(p.x + rx * BURST_RUN, -HW + 1, HW - 1), ty = clamp(p.y + ry * BURST_RUN, -HL + 1, HL - 1);
    const sp = this.vmax(p);
    p.burst = BURST_T; p.fx = rx; p.fy = ry;
    if (p.vx * rx + p.vy * ry < sp) { p.vx = rx * sp; p.vy = ry * sp; } // parte subito, senza la rincorsa
    if (o && o.state === 'play') { o.beat = Math.max(o.beat, BURST_SHAKE); o.beatBy = p; }
    if (this.human[T] && this.ctrl[T] === p) this.move[T] = { x: tx, y: ty, ttl: BURST_T + 1, held: false, sprint: true };
    this.ev('burst', { p, o });
  }

  // Lato del dribbling di p su o: +1 = alla sinistra di p (guardando il difensore), -1 = alla destra. Dalla parte opposta
  // allo sbilanciamento del difensore rispetto alla linea di corsa, verso lo spazio libero da altri avversari, e verso il
  // centro se si è vicini alla linea laterale. Niente numeri casuali: a parità vince la sinistra.
  dribSide(p, o) {
    const [rx, ry] = this.runDir(p), dx = o.x - p.x, dy = o.y - p.y, d = hyp(dx, dy) || 1, ux = dx / d, uy = dy / d;
    // > 0: il difensore sta (o si sposta) a sinistra della linea di corsa del portatore
    const lean = (dx * -ry + dy * rx) + (o.vx * -ry + o.vy * rx) * SIDE_LEAN_T;
    let best = 1, bs = -1e9;
    for (const s of [1, -1]) {
      const nx = -uy * s, ny = ux * s, qx = o.x + ux * DRIB_PAST + nx * DRIB_SIDE, qy = o.y + uy * DRIB_PAST + ny * DRIB_SIDE;
      let free = SIDE_FREE_MAX;
      for (const q of this.players) if (q.team !== p.team && q !== o && !q.off) free = Math.min(free, hyp(q.x - qx, q.y - qy));
      let sc = -s * lean * SIDE_LEAN + free * SIDE_FREE;
      if (Math.abs(p.x) > HW - SIDE_EDGE && nx * p.x > 0) sc -= 100; // verso la linea laterale vicina: mai
      if (sc > bs) { bs = sc; best = s; }
    }
    return best;
  }
  // dribbling prenotato dal tasto (d = duello con d.side scelto): il portatore corre verso il difensore puntando il lato
  // scelto; arrivato a DRIB_NEAR (o passato DRIB_BOOK_MAX) parte il dribbling vero. Chiamato a ogni passo da updateDuel.
  dribBookStep(d, dt) {
    const p = d.p, o = d.o, T = d.team;
    d.bt += dt;
    const dx = o.x - p.x, dy = o.y - p.y, dist = hyp(dx, dy);
    if (dist <= DRIB_NEAR || d.bt >= DRIB_BOOK_MAX) { this.dribble(p, o, d.side); return; }
    const ux = dx / (dist || 1), uy = dy / (dist || 1);
    const x = clamp(o.x - uy * d.side * DRIB_AIM, -HW + 0.5, HW - 0.5), y = clamp(o.y + ux * d.side * DRIB_AIM, -HL + 0.5, HL - 0.5);
    if (this.human[T] && this.ctrl[T] === p) this.move[T] = { x, y, ttl: 0.3, held: false, sprint: true };
  }

  dribbleChance(p, o) { return clamp(DRIB_BASE + DRIB_SKILL * (p.st.dri - o.st.dif) / 100, DRIB_MIN, DRIB_MAX); }

  // Tentativo di dribbling del portatore p contro o (stessa regola per umano e IA). Ritorna true se riesce.
  // side: lato già scelto (dribbling prenotato dal tasto), altrimenti lo sceglie dribSide.
  dribble(p, o, side = 0) {
    const b = this.ball, T = p.team;
    const ok = this.rnd() < this.dribbleChance(p, o);
    p.dribCd = DRIB_CD;
    const dx = o.x - p.x, dy = o.y - p.y, d = hyp(dx, dy) || 1, ux = dx / d, uy = dy / d;
    if (ok) {
      if (!side) side = this.dribSide(p, o);
      const nx = -uy * side, ny = ux * side, lat = Math.max(DRIB_SIDE, DRIB_WIDE * (d + DRIB_PAST) / d);
      const tx = clamp(p.x + ux * (d + DRIB_PAST) + nx * lat, -HW + 1, HW - 1), ty = clamp(p.y + uy * (d + DRIB_PAST) + ny * lat, -HL + 1, HL - 1);
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
    // side va anche alla grafica: il giochetto va da quel lato (+1 = sinistra del portatore)
    this.ev('dribble', { p, o, ok, side: side || this.dribSide(p, o) });
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
