// IA: tiro, passaggi, portatore, rimesse, posizioni in attacco e difesa, portiere.
// I metodi vengono copiati su Match.prototype (vedi match.js): `this` è la partita.
import { W, L, HW, HL, GW, GH, BOX_W, BOX_D, SIX_W, SIX_D, PEN_D, CIRCLE, G, ROLL, clamp, hyp, rng32, FORMATIONS, effStats, ballPhys, segInfo } from './core.js';

// Regolazioni dell'IA (misurate con test/balance.mjs e test/diag-flow.mjs)
const CLEAR_ZONE = 30;      // metri dalla propria linea di fondo in cui un difensore pressato può spazzare
const CLEAR_TOUCH = 0.6;    // spazzate mandate apposta in fallo laterale
const LOFT_RISK = 0.35;     // margine richiesto in più per un lancio alto (i lanci si perdevano 1 volta su 2)
const CROSS_FREE = 2.2;     // il cross si sceglie solo se il compagno in area ha questo spazio (m)
const SHOT_RANGE = 32;      // distanza massima dalla porta per pensare al tiro (m)
const BOX_SHOT = 16;        // sotto questa distanza la posizione di tiro è sempre buona (m)
const SHOT_BAR = 0.18;      // soglia della qualità del tiro (più bassa = tira più spesso)
const LONG_SHOT = 1.1;      // peso della posizione per i tiri da fuori area
const SHOT_BLOCKED = 0.65;  // porta coperta da un difensore: si tira lo stesso, ma meno volentieri
const THROUGH_BOX = 1.0;    // preferenza per il filtrante che porta un compagno dentro l'area
const PRESS_NEAR = 2.6;     // avversario più vicino di così = portatore pressato (m)
const PRESS_REACT = 3.4;    // distanza dell'avversario che fa decidere in fretta il portatore (m)
const PRESS_REACT_T = 0.06; // tempo minimo di decisione sotto pressione (s), più lento per squadre scarse
const SHOT_POST = 0.45;     // distanza dal palo a cui mira l'IA (m): più vicino = più gol e più tiri fuori
const HELPERS = 2;          // compagni che vengono incontro al portatore
const AIR_REACH = 2.4;      // sui lanci vicino alle porte si va sul pallone fino a questa altezza (colpo di testa)
const AIR_ZONE = 17;        // distanza dalla porta avversaria entro cui l'attaccante va a colpire di testa (m)
// Squadra umana senza palla: la CPU pressa il portatore con un giocatore (due vicino alla nostra porta) e gli altri
// rientrano nella posizione di squadra. Le linee disegnate e il dito della persona hanno sempre la precedenza.
const HUM_PRESS_ZONE = 33;  // portatore entro questi metri dalla nostra linea di fondo (nostra trequarti): pressano in due
const HUM_PRESS_KEEP = 4;   // chi sta già pressando conta come più vicino di così: niente scambi continui tra due quasi alla pari (m)
const HUM_BEHIND_D = 2;     // i difensori restano almeno così dietro la palla (m)
const HUM_BEHIND_C = -1;    // i centrocampisti al massimo 1 m davanti alla palla (m)
const HUM_MID_LANE = 0.3;   // quanto i centrocampisti si stringono sulla linea palla-porta (chiudono il centro)
const HUM_SCREEN = 4;       // chi non pressa resta almeno a questa distanza dal portatore, in copertura (m)
const HUM_MARK_R = 7.5;     // si marca l'avversario più vicino al proprio posto entro questa distanza (m)
const HUM_RECOVER = 8;      // più lontano di così dal proprio posto, verso la propria porta: rientro con lo scatto (m)
const HUM_MAGNET_R = 3;     // giocatore mosso dalla persona (linea o dito) entro questa distanza dal pallone: va dritto sul pallone (m)
const HUM_STICK_T = 1.5;    // linea finita vicino al pallone: il giocatore resta attaccato al pallone per questo tempo (s)
// Squadra umana in attacco: compagni senza palla larghi, in profondità e lontani tra loro
const SPACE_MIN = 9;        // distanza minima voluta tra due compagni (m)
const SPACE_PUSH = 0.7;     // parte della distanza mancante recuperata spostando il punto di arrivo (0..1)
const SPACE_PEN = 0.35;     // penalità per metro mancante nella scelta dello spazio libero
const DEEP_FROM = -30;      // con la palla da qui in avanti (m nel verso d'attacco) le punte attaccano la profondità
const HELP_KEEP = 4;        // chi è già d'appoggio conta come più vicino di così al portatore: niente cambi continui di compito (m)
const SUPPORT_FAR = [15, 18]; // il secondo compagno d'appoggio si offre più lontano (m), il primo resta a 8-11 m

export class AIMethods {
  // side: -1/1 = palo scelto; se manca, lato opposto al portiere (con un po' di casualità)
  aiShoot(p, pen, side) {
    const dir = p.team ? -1 : 1, gk = this.gk(1 - p.team);
    if (!side) side = pen ? (this.rnd() < 0.5 ? -1 : 1) : (gk.x > 0 ? -1 : 1) * (this.rnd() < 0.8 ? 1 : -1);
    this.kick(p, { type: 'shot', tx: side * (GW / 2 - (pen ? 0.8 : SHOT_POST)), ty: dir * HL, th: this.rnd() < 0.55 ? 0.3 + this.rnd() * 0.4 : 1.2 + this.rnd() * 0.8, curve: (this.rnd() - 0.5) * 1.5 });
  }

  // lato di tiro con la linea libera (0 = entrambi coperti); a pari merito, il palo lontano dal portiere
  shotSide(p) {
    const T = p.team, gy = (T ? -1 : 1) * HL, gk = this.gk(1 - T), tx = GW / 2 - SHOT_POST;
    const open = [-1, 1].filter(sd => this.lane(p.x, p.y, sd * tx, gy, T, 28, true) > 0);
    if (!open.length) return 0;
    if (open.length === 1) return open[0];
    return gk.x > 0 ? -1 : 1;
  }

  // spazzata: lunga e alta verso la fascia; a volte direttamente in fallo laterale
  clear(p) {
    const dir = p.team ? -1 : 1, side = Math.abs(p.x) > 4 ? Math.sign(p.x) : (this.rnd() < 0.5 ? -1 : 1);
    const touch = this.rnd() < CLEAR_TOUCH;
    const tx = side * (touch ? HW + 3 + this.rnd() * 6 : HW - 6 - this.rnd() * 10);
    const ty = clamp(p.y + dir * (22 + this.rnd() * 16), -HL + 6, HL - 6);
    this.kick(p, { type: "loft", tx, ty });
  }

  passOptions(p, exempt) {
    const b = this.ball, T = p.team, dir = T ? -1 : 1, sk = this.teams[T].skill, line = this.offLine[T];
    const press = this.nearOpp(p.x, p.y, T), gy = dir * HL;
    const ox = b.owner === p ? b.x : p.x, oy = b.owner === p ? b.y : p.y;
    let best = null;
    const consider = (m, tx, ty, through) => {
      const d = hyp(tx - ox, ty - oy);
      if (d < 4 || d > 44) return;
      const vp = Math.min(17 + p.st.pas * 0.13, Math.sqrt(25 + 2 * ROLL * d)) * 0.8;
      let safe = this.lane(ox, oy, tx, ty, T, vp), type = 'ground';
      const open = this.nearOpp(tx, ty, T);
      if (through) {
        const dm = hyp(m.x - tx, m.y - ty);
        if (open < dm + 1.5) return;
        safe = Math.min(safe, (open - dm - 1.5) / 3);
      } else if (safe < 0.3 && d > 16) {
        // pallonetto solo se nessun avversario può arrivare sul punto di caduta prima della palla
        const Tl = clamp(d / 14, 0.75, 2.6); let mar = 9;
        for (const o of this.players) if (o.team !== T && !o.off) mar = Math.min(mar, hyp(o.x - tx, o.y - ty) - (0.9 + this.vmax(o) * Math.max(0, Tl - 0.35)));
        const s2 = Math.min(mar / 3, 0.8) - LOFT_RISK; if (s2 > safe) { safe = s2; type = 'loft'; }
      }
      const gain = (ty - oy) * dir;
      let sc = clamp(safe, -2, 1.2) + gain * 0.09 + Math.min(open, 8) * 0.06 - (d > 30 ? 0.25 : 0) + (through ? (Math.abs(tx) < BOX_W / 2 && ty * dir > HL - BOX_D ? THROUGH_BOX : 0.6) : 0);
      const dg = hyp(tx, ty - gy); if (dg < 22) sc += (22 - dg) * 0.05;
      if (m.pos === 'P') sc -= 1;
      sc += (this.rnd() - 0.5) * 0.6 * (1 - sk);
      if (!best || sc > best.sc) best = { m, tx, ty, type, sc, safe, d, gain, through };
    };
    for (const m of this.players) {
      if (m.team !== T || m === p || m.off) continue;
      if (m.pos === 'P' && !(press < 3 && p.y * dir < -HL * 0.3)) continue;
      const mf = m.y * dir;
      if (!exempt && mf > line + 0.2 && mf > b.y * dir && mf > 0) continue;
      consider(m, m.x + m.vx * 0.5, m.y + m.vy * 0.5, false);
      if (Math.abs(ox) > 14 && oy * dir > HL - 24 && m.pos !== 'D' && Math.abs(m.x) < 11 && m.y * dir > HL - 17 && this.nearOpp(m.x, m.y, T) > CROSS_FREE) {
        const sc = 1.1 + (this.rnd() - 0.5) * 0.5 - hyp(m.x, m.y - gy) * 0.03;
        if (!best || sc > best.sc) best = { m, tx: m.x + m.vx * 0.6, ty: m.y + m.vy * 0.6, type: 'loft', sc, safe: 0.5, d: hyp(m.x - ox, m.y - oy), gain: 8, cross: true };
      }
      if (m.pos !== 'D' && m.pos !== 'P' && mf > oy * dir - 3 && mf > -10) {
        const lead = 7 + this.rnd() * 5;
        const gx = m.x * 0.6, n = hyp(gx - m.x, gy - m.y) || 1;
        const tx = m.x + (gx - m.x) / n * lead, ty = m.y + (gy - m.y) / n * lead;
        if (Math.abs(ty) < HL - 5) consider(m, tx, ty, true);
      }
    }
    return best;
  }

  carrierAI(p) {
    const b = this.ball, T = p.team, dir = T ? -1 : 1, sk = this.teams[T].skill, gy = dir * HL;
    const dg = hyp(p.x, p.y - gy), press = this.nearOpp(b.x, b.y, T);
    p.aiT -= this.dtT;
    // avversario in arrivo: si decide subito (prima che arrivi il contrasto)
    const react = PRESS_REACT_T + 0.1 * (1 - sk);
    if (press < PRESS_REACT && p.aiT > react) p.aiT = react;
    if (p.aiT <= 0 && p.stun <= 0) {
      p.aiT = 0.42 - 0.2 * sk + this.rnd() * 0.15;
      if (dg < SHOT_RANGE) {
        const ang = Math.abs(Math.atan2(p.x, Math.max(0.1, HL - p.y * dir)));
        // dentro l'area si tira quasi sempre; da fuori solo da buona posizione (i tiri da lontano li para quasi tutti)
        let q = (dg < BOX_SHOT ? 1 : clamp((SHOT_RANGE - dg) / (SHOT_RANGE - BOX_SHOT), 0, 1) * LONG_SHOT) * clamp(1.25 - ang * 0.9, 0.1, 1);
        // si guarda la linea verso ciascun palo (dove si mira davvero), meglio se lontano dal portiere
        const side = this.shotSide(p);
        if (!side) q *= SHOT_BLOCKED;
        if (dg < 10) q += 0.5;
        if (q > SHOT_BAR + this.rnd() * 0.3 - (press < 2.5 ? 0.12 : 0)) { this.aiShoot(p, false, side); return; }
      }
      // pressato vicino alla propria porta e senza passaggi sicuri: spazzata lunga verso la fascia
      if (p.y * dir < -HL + CLEAR_ZONE && press < 2.6) {
        const safe = this.passOptions(p);
        if (!safe || safe.safe < (this.inOwnBox(p) ? 0.5 : 0.15)) { this.clear(p); return; }
      }
      // avversario che chiude la strada verso la porta
      const gdx = -p.x * 0.5, gdy = gy - p.y, gn = hyp(gdx, gdy) || 1;
      let front = 99;
      for (const o of this.players) {
        if (o.team === T || o.off) continue;
        const dx = o.x - p.x, dy = o.y - p.y, d = hyp(dx, dy);
        if (d < 5 && (dx * gdx + dy * gdy) / (d * gn || 1) > 0.6) front = Math.min(front, d);
      }
      const pass = this.passOptions(p);
      p.holdN = (p.holdN || 0) + 1;
      if (pass) {
        let want = 0;
        if (press < PRESS_NEAR) want = pass.safe > 0 ? 0.95 : (p.y * dir < -HL * 0.5 ? 0.5 : 0);
        else if (pass.safe > 0.15) {
          if (pass.gain > 6) want = front < 5 ? 0.8 : 0.45;
          else if (front < 4) want = 0.6;
          else if (p.holdN > 5) want = 0.3;
        }
        if (this.rnd() < want) { this.kick(p, { type: pass.safe > 0 ? pass.type : 'loft', tx: pass.tx, ty: pass.ty }); return; }
      }
      // avversario davanti e nessun passaggio scelto: a volte si prova il dribbling (stessa regola dell'umano)
      if (front < 5 && this.aiDribble(p)) return;
      const base = Math.atan2(gy - p.y, (dg > 30 ? p.x * 0.7 : 0) - p.x);
      let bs = -1e9, ba = base;
      for (const o of [-1.2, -0.7, -0.35, 0, 0.35, 0.7, 1.2]) {
        const a = base + o, qx = p.x + Math.cos(a) * 5, qy = p.y + Math.sin(a) * 5;
        let s2 = (dg - hyp(qx, qy - gy)) * 1.5 + Math.min(this.nearOpp(qx, qy, T), 4) * (press < PRESS_NEAR ? 2.6 : 1.1) - Math.abs(o) * 0.3;
        if (Math.abs(qx) > HW - 2 || Math.abs(qy) > HL - 1.5) s2 -= 6;
        if (s2 > bs) { bs = s2; ba = a; }
      }
      p.dx = p.x + Math.cos(ba) * 10; p.dy = p.y + Math.sin(ba) * 10;
    }
    p.tx = clamp(p.dx, -HW + 1, HW - 1); p.ty = clamp(p.dy, -HL + 1, HL - 1);
  }

  aiRestart() {
    const r = this.restart, p = r.taker, T = p.team, dir = T ? -1 : 1;
    if (r.type === 'penalty') return this.aiShoot(p, true);
    if (r.type === 'corner') return this.kick(p, { type: 'loft', tx: (this.rnd() - 0.5) * 10, ty: dir * (HL - 5 - this.rnd() * 6), curve: (this.rnd() - 0.5) * 3 });
    if (r.type === 'kickoff') {
      let m = null, bd = 99; for (const q of this.players) if (q.team === T && q !== p && !q.off && q.pos !== 'P') { const d = hyp(q.x - p.x, q.y - p.y); if (d < bd && q.y * dir < p.y * dir - 2) { bd = d; m = q; } }
      if (m) return this.kick(p, { type: 'ground', tx: m.x, ty: m.y });
    }
    if (r.type === 'freekick') {
      const dg = hyp(p.x, p.y - dir * HL);
      if (dg < 27 && Math.abs(p.x) < 16) return this.aiShoot(p, false, r.wallSide ? -r.wallSide : 0);
      if (dg < 42) return this.kick(p, { type: 'loft', tx: (this.rnd() - 0.5) * 12, ty: dir * (HL - 7 - this.rnd() * 5) });
    }
    const o = this.passOptions(p, r.type === 'throw' || r.type === 'goalkick');
    if (o && o.safe > -0.2) return this.kick(p, { type: o.type, tx: o.tx, ty: o.ty });
    this.kick(p, { type: 'loft', tx: clamp(p.x * 0.5 + (this.rnd() - 0.5) * 24, -HW + 4, HW - 4), ty: clamp(p.y + dir * 36, -HL + 8, HL - 8) });
  }

  // ------------------------------------------------------------ IA
  computeLines() {
    for (let T = 0; T < 2; T++) this.offLine[T] = Math.max(0, this.lineOf(T));
  }
  computeChasers() {
    const b = this.ball;
    this.presser = [null, null];
    for (let T = 0; T < 2; T++) {
      let bp = null, bd = 1e9;
      for (const p of this.players) if (p.team === T && !p.off && p.pos !== 'P' && p.state === 'play') { const d = hyp(p.x - b.x, p.y - b.y); if (d < bd) { bd = d; bp = p; } }
      this.presser[T] = bp;
    }
    this.helpers = [[], []];
    if (b.owner) {
      const c = b.owner, was = (this.human[c.team] && this.helpWas) || [], dist = q => hyp(q.x - c.x, q.y - c.y) - (was.includes(q) ? HELP_KEEP : 0);
      const near = this.players.filter(q => q.team === c.team && q !== c && !q.off && q.pos !== 'P' && q.state === 'play').sort((q1, q2) => dist(q1) - dist(q2));
      this.helpers[c.team] = near.slice(0, HELPERS);
      this.helpWas = this.helpers[c.team];
    }
    // squadra umana in difesa: chi va sul portatore (i più vicini al pallone, senza linea disegnata)
    const was = this.hPress || [[], []];
    this.hPress = [[], []];
    if (b.owner && this.human[1 - b.owner.team]) {
      const c = b.owner, T = 1 - c.team, dir = T ? -1 : 1, deep = c.y * dir < -HL + HUM_PRESS_ZONE;
      const dist = p => hyp(p.x - c.x, p.y - c.y) - (was[T].includes(p) ? HUM_PRESS_KEEP : 0);
      this.hPress[T] = this.players.filter(p => p.team === T && !p.off && p.pos !== 'P' && p.state === 'play' && !this.runOf(p))
        .sort((p1, p2) => dist(p1) - dist(p2)).slice(0, deep ? 2 : 1);
    }
    this.cover = [null, null];
    if (b.owner) {
      const c = b.owner, T = 1 - c.team, dir = T ? -1 : 1, own = -dir * HL;
      const ux = -c.x * 0.6, uy = own - c.y, n = hyp(ux, uy) || 1, qx = c.x + ux / n * 4, qy = c.y + uy / n * 4;
      const first = this.human[T] ? this.ctrl[T] : this.presser[T];
      let bp = null, bd = 14;
      for (const p of this.players) if (p.team === T && !p.off && p.pos !== 'P' && p.state === 'play' && p !== first) { const d = hyp(p.x - qx, p.y - qy); if (d < bd) { bd = d; bp = p; } }
      this.cover[T] = this.human[T] || this.teams[T].skill < 0.42 ? null : bp;
      this.chase = [null, null]; return;
    }
    const N = 36, px = [], py = [], ph = [];
    const s = { x: b.x, y: b.y, h: b.h, vx: b.vx, vy: b.vy, vh: b.vh, cax: b.cax, cay: b.cay, ct: b.ct };
    for (let k = 0; k < N; k++) {
      px.push(clamp(s.x, -HW, HW)); py.push(clamp(s.y, -HL, HL)); ph.push(s.h);
      for (let j = 0; j < 4; j++) ballPhys(s, 0.025);
    }
    for (let T = 0; T < 2; T++) {
      const dir = T ? -1 : 1;
      let best = null, bestO = null;
      for (const p of this.players) {
        if (p.team !== T || p.off || p.state !== 'play') continue;
        if (b.kick && b.kick.kicker === p && b.kick.age < 1.2) continue;
        if (this.dblBan(p)) continue; // ha battuto il calcio da fermo: non può ritoccarlo, ci vanno gli altri
        const gk = p.pos === 'P', vm = this.vmax(p), hm = gk ? 2.3 : 1.5;
        // sui lanci alti vicino alle porte si va incontro al pallone per colpirlo di testa
        const loft = !gk && b.kick && b.kick.type === 'loft' && b.kick.kicker !== p, mate = loft && b.kick.team === T;
        let r = null;
        for (let k = 0; k < N; k++) {
          if (ph[k] > (loft && ph[k] <= AIR_REACH && (mate ? hyp(px[k], py[k] - dir * HL) < AIR_ZONE : hyp(px[k], py[k] + dir * HL) < AIR_ZONE + 15) ? AIR_REACH : hm)) continue;
          const t = k * 0.1, d = hyp(p.x - px[k], p.y - py[k]);
          if (d - 0.8 <= vm * Math.max(0, t - 0.12)) { r = { p, t, x: px[k], y: py[k] }; break; }
        }
        if (!r) r = { p, t: 50 + hyp(p.x - px[N - 1], p.y - py[N - 1]), x: px[N - 1], y: py[N - 1] };
        if (gk) { if (!(Math.abs(r.x) < BOX_W / 2 && r.y * dir < -HL + BOX_D)) continue; }
        else if (!bestO || r.t < bestO.t) bestO = r;
        if (!best || r.t < best.t) best = r;
      }
      this.chase[T] = best ? { p: best.p, x: best.x, y: best.y, t: best.t, p2: bestO ? bestO.p : null, x2: bestO ? bestO.x : 0, y2: bestO ? bestO.y : 0 } : null;
    }
  }

  think(dt) {
    const b = this.ball;
    this.dtT = dt;
    this.att = b.owner ? b.owner.team : (b.kick ? b.kick.team : (this.phase === 'restart' ? this.restart.team : -1));
    this.predT -= dt;
    if (this.predT <= 0) { this.predT = 0.1; this.computeChasers(); this.computeLines(); }
    for (const p of this.players) {
      if (p.off || p.state !== 'play') continue;
      p.spdF = 1; p.sprint = false;
      this.assign(p);
    }
  }

  // la squadra T è senza palla: possesso avversario, oppure pallone libero che non viene da un nostro passaggio o tiro
  manualDef(T) { const b = this.ball; return b.owner ? b.owner.team !== T : !(b.kick && b.kick.team === T); }

  assign(p) {
    const b = this.ball, T = p.team, dir = T ? -1 : 1, hum = this.human[T];
    if (this.phase === 'restart' && this.restart.taker === p) { p.tx = p.x; p.ty = p.y; return; }
    if (this.phase === 'restart' && p.wall) { p.tx = p.wall.x; p.ty = p.wall.y; return; }
    const mv = hum && this.ctrl[T] === p ? this.move[T] : null;
    if (mv && mv.path) this.followPath(p, mv);
    const def = hum && p.pos !== 'P' && this.phase === 'play' && this.manualDef(T);
    // linea disegnata in difesa: vale più di tutto il resto (anche del pressing) finché non è finita
    if (hum && b.owner !== p && this.runs[T].length) { const r = this.runOf(p); if (r && this.followRun(p, r)) { if (def) this.magnet(p); return; } }
    // senza palla (avversario in possesso o pallone libero non passato da noi): il controllato segue il dito,
    // gli altri li muove la CPU (pressing e posizione difensiva, vedi humanDefend)
    if (def) {
      if (mv && !mv.path) { p.tx = mv.x; p.ty = mv.y; p.sprint = !!mv.sprint; this.magnet(p); return; }
      if (!this.autoDef[T]) { p.tx = p.x; p.ty = p.y; return; }
      return this.humanDefend(p);
    }
    if (mv && mv.sprint) p.sprint = true;
    if (b.owner === p) {
      if (hum) {
        if (mv) { p.tx = mv.x; p.ty = mv.y; }
        else { p.tx = p.x * 0.9; p.ty = clamp(p.y + dir * 8, -HL + 3, HL - 3); p.spdF = 0.7; }
      } else this.carrierAI(p);
      return;
    }
    if (mv) { p.tx = mv.x; p.ty = mv.y; return; }
    if (p.pos === 'P') return this.gkAI(p);
    if (!b.owner && this.phase === 'play') {
      const ch = this.chase[T];
      if (ch && ch.p === p) { p.tx = ch.x; p.ty = ch.y; return; }
      if (ch && ch.p2 === p) { p.tx = ch.x2; p.ty = ch.y2; return; }
    }
    if (this.att === T) this.support(p); else this.defend(p);
    if (this.phase === 'restart' && this.restart.team !== T) {
      const r = this.restart, R = r.type === 'throw' ? 5 : r.type === 'kickoff' ? CIRCLE : 8.5;
      const dx = p.tx - r.x, dy = p.ty - r.y, d = hyp(dx, dy);
      if (d < R) { p.tx = r.x + (dx / (d || 1)) * R; p.ty = r.y + (dy / (d || 1)) * R; if (d < 0.1) p.ty = r.y - dir * R; }
      if (r.type === 'kickoff' && p.ty * dir > -0.5) p.ty = -dir * 0.5;
    }
    if (this.phase === 'restart' && this.restart.type === 'kickoff' && p.ty * dir > -0.3) p.ty = -dir * 0.3;
  }

  // giocatore mosso dalla persona vicino al pallone (avversario col pallone o pallone libero): l'ultimo tratto va dritto
  // sul pallone, così il contrasto non si manca di poco. true se ha cambiato la destinazione
  magnet(p) {
    const b = this.ball, c = b.owner;
    if (hyp(b.x - p.x, b.y - p.y) > HUM_MAGNET_R || b.h > 1.7) return false;
    p.tx = b.x + (c ? c.vx : b.vx) * 0.2; p.ty = b.y + (c ? c.vy : b.vy) * 0.2;
    return true;
  }
  // giocatore della squadra umana mosso dalla persona: il controllato, chi segue una linea, chi l'ha appena finita addosso al pallone
  directed(p) { return !!this.human[p.team] && (this.ctrl[p.team] === p || p.stickT > 0 || !!this.runOf(p)); }
  // chiamata quando finisce una linea di difesa: se è finita addosso al pallone, il giocatore ci resta attaccato un attimo
  runEnded(p) {
    const b = this.ball;
    if (this.human[p.team] && this.manualDef(p.team) && hyp(b.x - p.x, b.y - p.y) < HUM_MAGNET_R + 1.5) p.stickT = HUM_STICK_T;
  }
  // squadra umana senza palla, giocatore senza linea e senza dito: pressing (i più vicini), pallone vagante
  // (il più rapido ad arrivarci; i passaggi avversari in volo no: l'intercetto resta alla persona),
  // altrimenti posizione di squadra dietro la palla con marcatura a zona
  humanDefend(p) {
    const b = this.ball, T = p.team, dir = T ? -1 : 1, own = -dir * HL, c = b.owner;
    p.stickT = Math.max(0, (p.stickT || 0) - this.dtT);
    if (p.stickT > 0 && this.magnet(p)) return;
    if (!c) { const ch = this.chase[T]; if (ch && ch.p2 === p && !b.kick) { p.tx = ch.x2; p.ty = ch.y2; return; } }
    else if (this.hPress && this.hPress[T].includes(p)) { p.tx = b.x + c.vx * 0.25; p.ty = b.y + c.vy * 0.25; return; }
    const [ax, ay] = this.anchor(p);
    let tx = ax, ty = ay, mo = null, md = HUM_MARK_R;
    for (const o of this.players) if (o.team !== T && !o.off && o.pos !== 'P' && o !== c) { const d = hyp(o.x - ax, o.y - ay); if (d < md) { md = d; mo = o; } }
    if (mo) {
      const ux = -mo.x, uy = own - mo.y, n = hyp(ux, uy) || 1;
      tx = ax * 0.35 + (mo.x + ux / n * 1.6) * 0.65; ty = ay * 0.35 + (mo.y + uy / n * 1.6) * 0.65;
    }
    // centrocampisti: si stringono sulla linea tra palla e centro della porta (chiudono i passaggi centrali)
    if (p.pos === 'C') { const k = clamp((ty - own) / ((b.y - own) || 1), 0, 1); tx += (b.x * k - tx) * HUM_MID_LANE; }
    // chi non pressa non va addosso al portatore: resta in copertura a qualche metro
    if (c) {
      let ux = tx - c.x, uy = ty - c.y; const d = hyp(ux, uy);
      if (d < HUM_SCREEN) { if (d < 0.5) { ux = -c.x * 0.3; uy = own - c.y; } const n = hyp(ux, uy) || 1; tx = c.x + ux / n * HUM_SCREEN; ty = c.y + uy / n * HUM_SCREEN; }
    }
    // difensori e centrocampisti rientrano dietro la linea della palla
    const lim = p.pos === 'D' ? b.y * dir - HUM_BEHIND_D : p.pos === 'C' ? b.y * dir - HUM_BEHIND_C : null;
    if (lim !== null && ty * dir > lim) ty = Math.max(lim, -HL + 4) * dir;
    p.tx = clamp(tx, -HW + 1, HW - 1); p.ty = clamp(ty, -HL + 1, HL - 1);
    // lontano dal proprio posto, con la porta alle spalle: rientro di corsa
    if (hyp(p.tx - p.x, p.ty - p.y) > HUM_RECOVER && (p.ty - p.y) * dir < 0) p.sprint = true;
  }

  // penalità per i compagni troppo vicini al punto (x, y) (squadra umana in attacco): niente grappoli
  crowd(p, x, y) {
    let pen = 0;
    for (const q of this.players) if (q.team === p.team && q !== p && !q.off && q.pos !== 'P') { const d = hyp(q.x - x, q.y - y); if (d < SPACE_MIN) pen += SPACE_MIN - d; }
    return pen;
  }
  // sposta (x, y) lontano dai compagni più vicini di SPACE_MIN (portatore compreso)
  spread(p, x, y) {
    for (const q of this.players) {
      if (q.team !== p.team || q === p || q.off || q.pos === 'P') continue;
      const dx = x - q.x, dy = y - q.y, d = hyp(dx, dy);
      if (d < SPACE_MIN) { const k = (SPACE_MIN - d) * SPACE_PUSH / (d || 1); x += (d ? dx : (p.i % 2 ? 1 : -1)) * k; y += dy * k; }
    }
    return [clamp(x, -HW + 1.5, HW - 1.5), clamp(y, -HL + 2, HL - 2)];
  }

  // compagno vicino al portatore: cerca uno spazio libero raggiungibile con un passaggio sicuro
  offerSupport(p, c) {
    const T = p.team, dir = T ? -1 : 1;
    p.supT = (p.supT || 0) - this.dtT;
    if (p.supT <= 0 || p.supC !== c) {
      p.supT = 0.35 + this.rnd() * 0.25; p.supC = c;
      let bs = -1e9; p.supX = p.x - c.x; p.supY = p.y - c.y;
      // squadra umana: il secondo d'appoggio si offre più lontano (linee di passaggio a distanze diverse), lontano dai compagni
      const hum = this.human[T], far = hum && this.helpers[T][1] === p;
      for (const r of far ? SUPPORT_FAR : [8, 11]) for (let k = -5; k <= 5; k++) {
        const a = Math.atan2(dir, 0) + k * 0.5, qx = c.x + Math.cos(a) * r, qy = c.y + Math.sin(a) * r;
        if (Math.abs(qx) > HW - 1.5 || Math.abs(qy) > HL - 2 || qy * dir > this.offLine[T] - 0.8) continue;
        const sc = Math.min(this.nearOpp(qx, qy, T), 7) * 0.8 + clamp(this.lane(c.x, c.y, qx, qy, T, 16), -2, 2) * 1.2 + (qy - c.y) * dir * 0.07 - hyp(qx - p.x, qy - p.y) * 0.08 + this.rnd() * 0.3
          - (hum ? this.crowd(p, qx, qy) * SPACE_PEN : 0);
        if (sc > bs) { bs = sc; p.supX = qx - c.x; p.supY = qy - c.y; }
      }
    }
    p.tx = clamp(c.x + p.supX, -HW + 1, HW - 1); p.ty = clamp(c.y + p.supY, -HL + 1, HL - 1);
    if (this.human[T]) {
      [p.tx, p.ty] = this.spread(p, p.tx, p.ty);
      const mf = this.offLine[T] - 0.8; if (p.ty * dir > mf) p.ty = mf * dir;
    }
  }

  support(p) {
    const b = this.ball, T = p.team, dir = T ? -1 : 1, hum = this.human[T] && this.phase === 'play';
    if (this.phase === 'play' && b.owner && b.owner.team === T && this.helpers && this.helpers[T].includes(p)) return this.offerSupport(p, b.owner);
    const [ax, ay] = this.anchor(p);
    p.soT -= this.dtT;
    if (p.soT <= 0) {
      p.soT = 0.5 + this.rnd() * 0.4; let bs = -1e9;
      for (const c of [[0, 0], [5, 0], [-5, 0], [0, 4], [3.5, 3], [-3.5, 3], [0, -4]]) {
        const qx = ax + c[0], qy = ay + c[1] * dir;
        if (Math.abs(qx) > HW - 1.5 || Math.abs(qy) > HL - 2) continue;
        const s = Math.min(this.nearOpp(qx, qy, T), 7) + (this.lane(b.x, b.y, qx, qy, T, 18) > 0 ? 1.5 : 0) + (c[1] > 0 ? 0.6 : 0) + this.rnd() * 0.5
          - (hum ? this.crowd(p, qx, qy) * SPACE_PEN : 0);
        if (s > bs) { bs = s; p.sox = c[0]; p.soy = c[1] * dir; }
      }
    }
    let tx = ax + p.sox, ty = ay + p.soy;
    const line = this.offLine[T], flight = !b.owner && b.kick && b.kick.team === T;
    // le punte attaccano lo spazio dietro la difesa, sulla linea del fuorigioco (la squadra umana già dalla propria metà)
    if (p.pos === 'A' && b.y * dir > (hum ? DEEP_FROM : -15)) ty = Math.max(ty * dir, Math.min(line - 0.8, HL - 6)) * dir;
    if (hum) [tx, ty] = this.spread(p, tx, ty);
    if (!flight) { const mf = Math.max(line - 0.8, b.y * dir); if (ty * dir > mf) ty = mf * dir; }
    p.tx = tx; p.ty = ty;
  }

  defend(p) {
    const b = this.ball, T = p.team, dir = T ? -1 : 1, own = -dir * HL, hum = this.human[T];
    const [ax, ay] = this.anchor(p);
    let tx = ax, ty = ay;
    if (this.phase === 'play' && b.owner && b.owner.team !== T) {
      const c = b.owner;
      if (hum ? this.ctrl[T] === p : this.presser[T] === p) {
        if (hum) { // contenimento automatico se non si tocca lo schermo
          const ux = -c.x, uy = own - c.y, n = hyp(ux, uy) || 1;
          p.tx = c.x + ux / n * 2.6; p.ty = c.y + uy / n * 2.6;
        } else {
          // niente scivolate (tolte anche all'IA il 2026-11-20): il pressatore ruba palla solo col contatto
          p.tx = b.x + c.vx * 0.25; p.ty = b.y + c.vy * 0.25;
        }
        return;
      }
      if (this.cover[T] === p) {
        const ux = -c.x * 0.6, uy = own - c.y, n = hyp(ux, uy) || 1;
        p.tx = c.x + ux / n * 3.2; p.ty = c.y + uy / n * 3.2; return;
      }
    }
    let mo = null, md = 7.5;
    for (const o of this.players) if (o.team !== T && !o.off && o.pos !== 'P' && o !== b.owner) { const d = hyp(o.x - ax, o.y - ay); if (d < md) { md = d; mo = o; } }
    if (mo) {
      const ux = -mo.x, uy = own - mo.y, n = hyp(ux, uy) || 1;
      tx = ax * 0.35 + (mo.x + ux / n * 1.6) * 0.65; ty = ay * 0.35 + (mo.y + uy / n * 1.6) * 0.65;
    }
    p.tx = tx; p.ty = ty;
  }

  gkAI(p) {
    const b = this.ball, T = p.team, dir = T ? -1 : 1, own = -dir * HL;
    if (this.phase === 'restart') { p.tx = 0; p.ty = own + dir * (this.restart.team === T ? 9 : 1.2); return; }
    const s = b.shot;
    if (s && s.team !== T) {
      p.ty = own + dir * 0.6;
      if (this.human[T] && !this.autoGk[T]) { p.tx = s.gx0 + clamp(s.cx - s.gx0, -0.9, 0.9); return; }
      if (!p.decided) {
        p.reactT -= this.dtT; p.tx = p.x;
        if (p.reactT <= 0) {
          p.decided = true;
          if (Math.abs(s.cx - p.x) > 1.0 || s.ch > 2.0) this.startDive(p, s.cx, s.ch);
        }
      } else p.tx = clamp(s.cx, -GW / 2, GW / 2);
      return;
    }
    const ch = this.chase[T];
    if (!b.owner && ch && ch.p === p) { p.tx = ch.x; p.ty = ch.y; return; }
    if (this.att === T) { p.tx = b.x * 0.1; p.ty = own + dir * clamp((b.y * dir + HL) * 0.22, 3, 16); return; }
    const vx = b.x, vy = b.y - own, d = hyp(vx, vy) || 1;
    let out = clamp(d * 0.09, 0.8, 4.5);
    if (b.owner && d < 16) {
      let nd = 99; const c = b.owner;
      for (const q of this.players) if (q.team === T && q !== p && !q.off) nd = Math.min(nd, hyp(q.x - c.x, q.y - c.y));
      if (nd > 3) out = clamp(d - 3, 1, 8);
    }
    p.tx = clamp(vx / d * out, -GW / 2 - 1, GW / 2 + 1); p.ty = own + vy / d * out;
  }

  startDive(p, tx, th) {
    p.state = 'dive'; p.t = 0; p.vx = p.vy = 0;
    const t = clamp(tx, -GW / 2 - 0.9, GW / 2 + 0.9);
    p.dive = { tx: t, th: clamp(th, 0.15, 2.7), hx: p.x, hh: 1.1, x0: p.x, dirx: t >= p.x ? 1 : -1 };
    this.ev('dive', { p });
  }
}
