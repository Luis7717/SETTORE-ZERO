// La partita: stato, rimesse, calci, pallone, uscite, gol, tempo e comandi umani.
import { W, L, HW, HL, GW, GH, BOX_W, BOX_D, SIX_W, SIX_D, PEN_D, CIRCLE, G, ROLL, clamp, hyp, rng32, FORMATIONS, effStats, ballPhys, segInfo } from './core.js';
import { AIMethods } from './ai.js';
import { MotionMethods } from './motion.js';
import { DuelMethods } from './duel.js';
import { lookOf } from '../looks.js';

const PREVIEW_SEC = 2.4; // durata massima dell'anteprima della traiettoria (s)
const SHOT_V0 = 22; // velocità base del tiro (m/s), più la bravura del tiratore
const GK_REACT = 0.42; // tempo di reazione base del portiere del computer (s), meno la sua bravura
const WIDE_GAP = 2; // metri dalla linea laterale degli esterni quando la squadra attacca
const WALL_RANGE = 30; // punizione entro questa distanza dalla porta: barriera (m)
const WALL_DIST = 9.15; // distanza della barriera dal pallone (m)
const WALL_GAP = 0.75; // spazio tra i giocatori in barriera (m)
const ADV_FREE = 3; // vantaggio solo se nessun altro avversario è più vicino di così al portatore (m)
const ADV_MIN_Y = -5; // ... e solo da qui in avanti (m nel verso d'attacco, 0 = metà campo)
const SPEED_TIRED = 0.86; // a energia 0 la velocità massima scende a questa frazione (l'energia cala più piano con più fisico = resistenza)
const PATH_STEP = 1.2;   // distanza minima tra due punti della strada disegnata (m)
const PATH_REACH = 1.3;  // punto raggiunto quando il portatore è più vicino di così (m)
const RUN_END_REACH = 0.4;  // linea di difesa: l'ultimo punto va raggiunto davvero (così una linea fin sull'avversario arriva al contrasto) (m)
const PATH_SPRINT = 6;   // scatta finché davanti resta più strada di così (m)
const PATH_TTL = 20;     // durata massima di una strada disegnata (s)
const PATH_LOOK = 3;     // il giocatore punta a un punto della strada almeno così avanti: un punto troppo vicino lo frenava e lo scatto non si vedeva (m)
export const RUN_MAX_LEN = 14; // lunghezza massima di una linea di difesa, misurata dal giocatore: il resto si taglia (m)
export const SPRINT_DIST = 6; // dito più lontano di così dal giocatore controllato (m) = scatto

// Taglia una linea che parte da (x0, y0) e passa per pts alla lunghezza max (m): l'ultimo punto cade esattamente a max.
// Usata dal motore (userRun) e dal disegno della linea (src/input.js), così a schermo si vede già tagliata.
export function clipLen(x0, y0, pts, max) {
  const out = []; let px = x0, py = y0, left = max;
  for (const q of pts) {
    const d = hyp(q.x - px, q.y - py);
    if (d >= left) { const k = d > 0 ? left / d : 0; out.push({ ...q, x: px + (q.x - px) * k, y: py + (q.y - py) * k }); return out; }
    out.push(q); left -= d; px = q.x; py = q.y;
  }
  return out;
}
// indice del primo punto della strada (da i in poi) lontano almeno PATH_LOOK da (x, y); l'ultimo se nessuno lo è
function lookAhead(path, i, x, y) {
  let j = i;
  while (j < path.length - 1 && hyp(path[j].x - x, path[j].y - y) < PATH_LOOK) j++;
  return j;
}

export class Match {
  constructor(o) {
    this.rnd = rng32(o.seed || 1);
    this.halfLen = o.halfLen || 180;
    this.human = o.human || [true, false];
    this.autoGk = o.autoGk || [false, false];
    this.teams = o.teams;
    this.players = [];
    for (let t = 0; t < 2; t++) {
      const tm = this.teams[t], F = FORMATIONS[tm.formation] || FORMATIONS['4-4-2'];
      if (tm.skill === undefined) tm.skill = 0.5;
      for (let i = 0; i < 11; i++) this.players.push(this.mk(t, i, tm.players[i], F[i]));
    }
    this.ball = { x: 0, y: 0, h: 0, vx: 0, vy: 0, vh: 0, cax: 0, cay: 0, ct: 0, owner: null, noP: null, noT: 0, last: null, prev: null, kick: null, shot: null };
    this.score = [0, 0]; this.half = 1; this.t = 0; this.time = 0; this.phase = 'play'; this.events = [];
    this.stats = { shots: [0, 0], onT: [0, 0], poss: [0, 0], fouls: [0, 0], corners: [0, 0], saves: [0, 0], headers: [0, 0], volleys: [0, 0] };
    this.ctrl = [null, null]; this.move = [null, null]; this.switchCd = [0, 0]; this.runs = [[], []];
    this.chase = [null, null]; this.presser = [null, null]; this.cover = [null, null]; this.offLine = [HL, HL];
    this.autoDef = [true, true]; // squadra umana senza palla: false = chi non ha linea né dito resta fermo (allenamento "Recupera palla")
    this.predT = 0; this.att = -1; this.dtT = 0; this.lastPass = null; this.restart = null;
    this.goalsLog = []; this.advantage = null;
    this.duel = null; this.duelCd = [0, 0]; this.duelCdP = [null, null];
    this.kickoffTeam = o.kickoff ?? (this.rnd() < 0.5 ? 0 : 1);
    this.setupKickoff(this.kickoffTeam);
  }

  mk(team, i, src, slot) {
    const dir = team ? -1 : 1;
    return {
      team, i, src, name: src.name, pos: slot[0], bx: slot[1], by: slot[2], st: effStats(src, slot[0]),
      x: 0, y: 0, vx: 0, vy: 0, fx: 0, fy: dir, tx: 0, ty: 0, spdF: 1, state: 'play', t: 0, stun: 0, protect: 0,
      contact: 0, tackleCd: 0, kickAnim: 0, energy: 1, sprint: false, dribCd: 0, beat: 0, beatBy: null, burst: 0, wear: { dri: 1, tes: 1 }, wall: null, yellow: 0, off: false, sdx: 0, sdy: 0, hit: false,
      dive: null, phase: this.rnd() * 6, aiT: 0, dx: 0, dy: 0, reactT: 0, decided: true, warn: false,
      sox: 0, soy: 0, soT: this.rnd(), cele: 0, look: this.lookFor(src),
    };
  }

  // aspetto del giocatore sorgente (stesso a ogni partita); il numero casuale si consuma lo stesso,
  // così le partite a seme fisso restano identiche a prima (test/unit/golden.test.mjs)
  lookFor(src) { this.rnd(); return lookOf(src); }

  team(t) { return t ? this.players.slice(11) : this.players.slice(0, 11); }
  gk(t) { return this.players[t * 11]; }
  gauss() { return (this.rnd() + this.rnd() + this.rnd() - 1.5) * 2; }
  // velocità massima: cresce con `vel` e cala con la stanchezza (p.energy 1 → 0,2 durante la partita, più piano con più `fis`)
  vmax(p) { return (5.0 + p.st.vel * 0.036) * (SPEED_TIRED + (1 - SPEED_TIRED) * p.energy); }
  ev(type, d) { this.events.push(Object.assign({ type }, d)); }

  nearOpp(x, y, team) {
    let m = 99;
    for (const o of this.players) if (o.team !== team && !o.off) { const d = hyp(o.x - x, o.y - y); if (d < m) m = d; }
    return m;
  }
  lane(x1, y1, x2, y2, team, speed, exGK) {
    const D = hyp(x2 - x1, y2 - y1); let m = 9;
    for (const o of this.players) {
      if (o.team === team || o.off || (exGK && o.pos === 'P')) continue;
      const [d, t] = segInfo(o.x, o.y, x1, y1, x2, y2);
      const s = t * D;
      if (s < 1.5) { if (t > 0 && d < 1.1) { const mm = d - 1.1; if (mm < m) m = mm; } continue; }
      if (t >= 0.985) { const mm = d - 1.0; if (mm < m) m = mm; continue; }
      const mar = d - (0.9 + Math.max(0, s / speed - 0.2) * this.vmax(o) * 0.75);
      if (mar < m) m = mar;
    }
    return m;
  }
  blocked(x1, y1, x2, y2, team) {
    const D = hyp(x2 - x1, y2 - y1);
    for (const o of this.players) {
      if (o.team === team || o.off) continue;
      const [d, t] = segInfo(o.x, o.y, x1, y1, x2, y2);
      const s = t * D;
      if (s > 2 && s < D - 1.5 && d < 1.4) return true;
    }
    return false;
  }
  inOwnBox(p) { const dir = p.team ? -1 : 1; return Math.abs(p.x) < BOX_W / 2 && p.y * dir < -HL + BOX_D; }

  // ------------------------------------------------------------ posizioni
  anchor(p) {
    const dir = p.team ? -1 : 1, b = this.ball;
    const bf = clamp((b.y * dir + HL) / L, 0, 1), bx = b.x / HW;
    let ax, ay;
    // in attacco gli esterni (terzini e ali) restano larghi, quasi sulla linea laterale
    const wide = this.att === p.team && Math.abs(p.bx) > 0.6 && p.pos !== 'P';
    if (this.att === p.team) { ay = p.by * 0.5 + bf * 0.55 + (p.pos === 'A' ? 0.06 : (p.pos === 'C' && Math.abs(p.bx) > 0.6 ? 0.05 : 0)); ax = wide ? Math.sign(p.bx) : p.bx + bx * 0.15; }
    else { ay = p.by * 0.55 + bf * 0.36 - 0.03; ax = p.bx * 0.7 + bx * 0.28; }
    return [wide ? ax * (HW - WIDE_GAP) : clamp(ax, -0.95, 0.95) * HW * 0.94, (clamp(ay, 0.04, 0.96) - 0.5) * L * dir];
  }
  place(p, x, y) {
    p.x = x; p.y = y; p.vx = p.vy = 0; p.tx = x; p.ty = y; p.state = 'play'; p.t = 0; p.stun = 0; p.contact = 0;
    p.dive = null; p.warn = false; p.hit = false; p.cele = 0;
  }
  resetStates() {
    for (const p of this.players) p.wall = null;
    for (const p of this.players) if (!p.off) { p.state = 'play'; p.t = 0; p.stun = 0; p.contact = 0; p.dive = null; p.warn = false; p.cele = 0; p.beat = 0; p.vx *= 0.3; p.vy *= 0.3; }
  }
  pushAway(team, x, y, R) {
    for (const o of this.players) {
      if (o.team !== team || o.off) continue;
      const dx = o.x - x, dy = o.y - y, d = hyp(dx, dy);
      if (d < R) {
        const dir = o.team ? -1 : 1; let ux = dx / (d || 1), uy = dy / (d || 1);
        if (d < 0.5) { ux = 0; uy = -dir; }
        let nx = x + ux * R, ny = y + uy * R;
        if (Math.abs(nx) > HW - 1 || Math.abs(ny) > HL - 1) { nx = clamp(x, -HW + 8, HW - 8) + (o.i - 5) * 0.8; ny = y - dir * R; ny = clamp(ny, -HL + 1, HL - 1); }
        o.x = nx; o.y = ny; o.vx = o.vy = 0;
      }
    }
  }
  faceTo(p, x, y) { const dx = x - p.x, dy = y - p.y, n = hyp(dx, dy) || 1; p.fx = dx / n; p.fy = dy / n; }

  setRestart(type, team, x, y, taker) {
    const b = this.ball, dir = team ? -1 : 1, own = -dir * HL, opp = 1 - team;
    b.owner = null; b.vx = b.vy = b.vh = 0; b.h = 0; b.kick = null; b.shot = null; b.ct = 0; b.noT = 0;
    this.endDuel('gioco fermo');
    this.phase = 'restart'; this.move = [null, null]; this.runs = [[], []]; this.lastPass = null; this.advantage = null;
    this.resetStates();
    let cut = false, wallSide = 0;
    const mine = this.team(team).filter(p => !p.off), theirs = this.team(opp).filter(p => !p.off);
    const nearest = (list, f) => { let best = null, bd = 1e9; for (const p of list) { if (f && !f(p)) continue; const d = hyp(p.x - x, p.y - y); if (d < bd) { bd = d; best = p; } } return best; };
    if (type === 'kickoff') {
      cut = true; x = 0; y = 0;
      for (const p of this.players) {
        if (p.off) continue; const d = p.team ? -1 : 1;
        this.place(p, p.bx * HW * 0.9, d * (-HL + p.by * 0.68 * L)); p.fx = 0; p.fy = d;
      }
      taker = null; let bd = 9;
      for (const p of mine) if (p.pos !== 'P') { const s = Math.abs(p.bx) - p.by; if (s < bd) { bd = s; taker = p; } }
      this.place(taker, 0, -dir * 0.6);
      this.pushAway(opp, 0, 0, CIRCLE);
    } else if (type === 'throw') {
      x = clamp(x, -HW + 0.3, HW - 0.3); y = clamp(y, -HL + 1, HL - 1);
      taker = nearest(mine, p => p.pos !== 'P'); this.place(taker, x, y);
      this.pushAway(opp, x, y, 5);
    } else if (type === 'freekick') {
      x = clamp(x, -HW + 1, HW - 1); y = clamp(y, -HL + 1, HL - 1);
      taker = nearest(mine, p => p.pos !== 'P'); this.place(taker, x - 0, y - dir * 0.3);
      this.pushAway(opp, x, y, 8.5);
      wallSide = this.buildWall(team, x, y);
    } else if (type === 'gk') {
      for (const o of theirs) if (Math.abs(o.x) < BOX_W / 2 + 1 && o.y * dir < -HL + BOX_D + 1) { o.y = dir * (-HL + BOX_D + 2); o.vx = o.vy = 0; }
    } else if (type === 'goalkick') {
      cut = true; x = (x > 0 ? 1 : -1) * 3; y = own + dir * SIX_D;
      taker = this.gk(team);
      b.x = x; b.y = y; this.att = team;
      for (const p of this.players) if (!p.off && p !== taker) { const [ax, ay] = this.anchor(p); this.place(p, ax + (this.rnd() - .5), ay + (this.rnd() - .5)); }
      this.place(taker, x, y - dir * 0.5);
      for (const o of theirs) if (Math.abs(o.x) < BOX_W / 2 + 1 && o.y * dir < -HL + BOX_D + 1) o.y = dir * (-HL + BOX_D + 2);
    } else if (type === 'corner') {
      cut = true; const sx = x > 0 ? 1 : -1; x = sx * (HW - 0.4); y = dir * (HL - 0.4);
      const gy = dir * HL;
      const out = mine.filter(p => p.pos !== 'P');
      taker = null; let bp = -1; for (const p of out) if (p.pos !== 'D' && p.st.pas > bp) { bp = p.st.pas; taker = p; }
      const order = out.filter(p => p !== taker).sort((a, c) => 'ACD'.indexOf(a.pos) - 'ACD'.indexOf(c.pos));
      const A = [[-3, 7], [3, 8.5], [0, 11.5], [-6, 10], [6, 12.5], [-2, 19], [9, 22], [-10, 46], [8, 50], [0, 44]];
      order.forEach((p, k) => { const s = A[k] || [0, 45]; this.place(p, s[0], gy - dir * s[1]); });
      this.place(this.gk(team), 0, own + dir * 12);
      const Dp = [[-2.6, 5.5], [2.6, 5.5], [0, 8], [-5, 8.5], [5, 9.5], [0, 13], [-3, 3], [-7, 20], [8, 21], [0, 38]];
      theirs.filter(p => p.pos !== 'P').forEach((p, k) => { const s = Dp[k] || [0, 30]; this.place(p, s[0], gy - dir * s[1]); });
      this.place(this.gk(opp), 0, gy - dir * 0.6);
      this.place(taker, x, y);
      this.stats.corners[team]++;
    } else if (type === 'penalty') {
      cut = true; x = 0; y = dir * (HL - PEN_D);
      taker = null; let bt = -1; for (const p of mine) if (p.pos !== 'P' && p.st.tir > bt) { bt = p.st.tir; taker = p; }
      let k = 0;
      for (const p of this.players) {
        if (p.off || p === taker || p.pos === 'P') continue;
        this.place(p, -19 + (k % 10) * 4.2 + (k >= 10 ? 2 : 0), dir * (HL - BOX_D - 2.5 - (k >= 10 ? 2.5 : 0))); k++;
      }
      this.place(this.gk(opp), 0, dir * (HL - 0.4));
      this.place(this.gk(team), 0, own + dir * 14);
      this.place(taker, 0, y - dir * 0.9);
    }
    if (type !== 'gk') {
      this.faceTo(taker, type === 'penalty' ? 0 : clamp(x * 0.3, -10, 10), type === 'penalty' ? dir * HL : (type === 'throw' || type === 'corner' ? y - dir * (type === 'corner' ? 8 : -2) : y + dir * 20));
      if (type === 'throw') this.faceTo(taker, 0, y + dir * 6);
      b.x = taker.x + taker.fx * 0.6; b.y = taker.y + taker.fy * 0.6;
      if (type === 'throw' || type === 'corner') { b.x = clamp(b.x, -HW + 0.2, HW - 0.2); b.y = clamp(b.y, -HL + 0.2, HL - 0.2); }
    }
    b.owner = taker; b.last = taker; b.prev = null;
    taker.vx = taker.vy = 0;
    for (const p of this.players) if (!p.off && p !== taker) this.faceTo(p, b.x, b.y);
    this.att = team;
    this.restart = { type, team, taker, x: b.x, y: b.y, t: 0, wait: 1.1 + this.rnd() * 0.7 + (type === 'penalty' ? 0.8 : 0) + (cut ? 0.5 : 0) + (wallSide ? 0.6 : 0), wallSide };
    this.predT = 0;
    this.updateCtrl(0, true);
    this.ev('restart', { kind: type, team, cut });
  }
  // Barriera della squadra che difende sulla punizione di `team` dal punto (x, y): 2-5 giocatori a 9,15 m,
  // sulla linea tra pallone e palo vicino. Ritorna il lato coperto (-1/1), 0 se la punizione è troppo lontana.
  buildWall(team, x, y) {
    const dir = team ? -1 : 1, gy = dir * HL, dg = hyp(x, gy - y);
    if (dg > WALL_RANGE || y * dir > HL - 1) return 0;
    const side = Math.abs(x) > 2 ? Math.sign(x) : (this.rnd() < 0.5 ? -1 : 1);
    const n = Math.abs(x) > 20 ? 2 : dg < 20 ? 5 : dg < 25 ? 4 : 3;
    const ax = side * GW / 4, ux0 = ax - x, uy0 = gy - y, un = hyp(ux0, uy0) || 1, ux = ux0 / un, uy = uy0 / un;
    const cx = x + ux * WALL_DIST, cy = y + uy * WALL_DIST, nx = -uy, ny = ux;
    const pool = this.team(1 - team).filter(p => !p.off && p.pos !== 'P').sort((a, c) => hyp(a.x - cx, a.y - cy) - hyp(c.x - cx, c.y - cy)).slice(0, n);
    pool.forEach((p, k) => {
      const o = (k - (n - 1) / 2) * WALL_GAP;
      this.place(p, cx + nx * o, cy + ny * o); this.faceTo(p, x, y); p.wall = { x: p.x, y: p.y };
    });
    return side;
  }
  setupKickoff(team) { this.setRestart('kickoff', team, 0, 0); }

  // y (nel verso d'attacco di T) del penultimo avversario; HL se non ce ne sono abbastanza
  lineOf(T) {
    const dir = T ? -1 : 1; let a = -99, s = -99;
    for (const o of this.players) if (o.team !== T && !o.off) { const v = o.y * dir; if (v > a) { s = a; a = v; } else if (v > s) s = v; }
    return s === -99 ? HL : s;
  }
  // linea del fuorigioco per chi attacca (squadra T), in coordinata y del campo:
  // penultimo difensore, ma mai dietro al pallone né nella propria metà campo
  offsideY(T) {
    const dir = T ? -1 : 1;
    return dir * Math.max(this.lineOf(T), this.ball.y * dir, 0);
  }

  // ------------------------------------------------------------ calci
  // Parametri di lancio del pallone, senza toccare la partita.
  // gA / gT danno l'errore casuale di direzione e di altezza: in partita this.gauss(), nell'anteprima 0.
  launch(p, spec, gA, gT) {
    const b = this.ball, T = p.team;
    const sx = b.owner === p ? b.x : p.x + p.fx * 0.6, sy = b.owner === p ? b.y : p.y + p.fy * 0.6;
    let type = spec.type, th = spec.th || 0;
    let dx = spec.tx - sx, dy = spec.ty - sy, D = hyp(dx, dy);
    if (D < 1) { dx = p.fx; dy = p.fy; D = 1; }
    if (type === 'auto') type = (D > 30 || this.blocked(sx, sy, spec.tx, spec.ty, T)) ? 'loft' : 'ground';
    const press = this.nearOpp(p.x, p.y, T);
    let sig = type === 'shot' ? (0.5 + (100 - p.st.tir) * 0.04) * (press < 2 ? 1.5 : 1) : (0.3 + (100 - p.st.pas) * 0.025) * (type === 'loft' ? 1.4 : 1);
    if (spec.human) sig *= 0.75;
    const a = gA() * sig * Math.PI / 180, ca = Math.cos(a), sa = Math.sin(a);
    let ux = dx / D, uy = dy / D;
    [ux, uy] = [ux * ca - uy * sa, ux * sa + uy * ca];
    const nx = -uy, ny = ux;
    let v0, Tt, vh = 0;
    if (type === 'ground') {
      v0 = Math.min(17 + p.st.pas * 0.13, Math.sqrt(25 + 2 * ROLL * D));
      const disc = v0 * v0 - 2 * ROLL * D; Tt = disc > 0 ? (v0 - Math.sqrt(disc)) / ROLL : v0 / ROLL;
    } else if (type === 'loft') {
      const vm = 15 + p.st.pas * 0.11; Tt = clamp(D / 14, 0.75, 2.6);
      if (D / Tt > vm) D = vm * Tt;
      v0 = D / Tt; vh = G * Tt / 2;
    } else {
      v0 = SHOT_V0 + p.st.tir * 0.14; Tt = D / v0;
      th = Math.max(0.05, th + gT() * sig * 0.017 * D);
      vh = (th + 0.5 * G * Tt * Tt) / Tt;
    }
    Tt = Math.max(Tt, 0.15);
    const c = clamp(spec.curve || 0, -D * 0.3, D * 0.3);
    let ac = clamp(-8 * c / (Tt * Tt), -14, 14);
    const lv = -ac * Tt / 2;
    return { type, sx, sy, v0, vx: ux * v0 + nx * lv, vy: uy * v0 + ny * lv, vh, cax: nx * ac, cay: ny * ac, ct: ac ? Tt : 0 };
  }

  // Anteprima del volo del pallone per il calcio `spec`, senza errore di mira e senza cambiare la partita.
  // Punti ogni 1/30 s: { t, x, y, h }.
  predictKick(p, spec, sec = PREVIEW_SEC) {
    const L = this.launch(p, spec, () => 0, () => 0);
    const s = { x: L.sx, y: L.sy, h: 0.02, vx: L.vx, vy: L.vy, vh: L.vh, cax: L.cax, cay: L.cay, ct: L.ct };
    const pts = [{ t: 0, x: s.x, y: s.y, h: s.h }];
    for (let k = 1; k <= sec * 60; k++) {
      ballPhys(s, 1 / 60);
      if (k % 2 === 0) pts.push({ t: k / 60, x: s.x, y: s.y, h: s.h });
      if (Math.abs(s.x) > HW + 1 || Math.abs(s.y) > HL + 1 || (s.h === 0 && hyp(s.vx, s.vy) < 0.3)) break;
    }
    return pts;
  }

  kick(p, spec) {
    const b = this.ball, T = p.team, dir = T ? -1 : 1;
    // stesso ordine di estrazione dei numeri casuali di prima: prima la direzione, poi (solo nei tiri) l'altezza
    const { type, sx, sy, v0, vx, vy, vh, cax, cay, ct } = this.launch(p, spec, () => this.gauss(), () => this.gauss());
    b.owner = null; b.x = sx; b.y = sy; b.h = 0.02;
    b.vx = vx; b.vy = vy; b.vh = vh;
    b.cax = cax; b.cay = cay; b.ct = ct;
    b.noP = p; b.noT = 0.35;
    if (b.last !== p) { b.prev = b.last; b.last = p; }
    let exempt = false;
    if (this.phase === 'restart') { exempt = ['throw', 'goalkick', 'corner'].includes(this.restart.type); this.phase = 'play'; this.restart = null; }
    const off = [];
    if (!exempt) {
      this.computeLines();
      const line = this.offLine[T];
      for (const m of this.players) if (m.team === T && m !== p && !m.off && m.y * dir > line + 0.3 && m.y * dir > sy * dir + 0.3 && m.y * dir > 0) off.push(m);
    }
    b.kick = { team: T, kicker: p, off, age: 0, type, human: !!spec.human };
    b.shot = null;
    this.detectShot();
    if (b.shot && b.shot.team === T) { this.stats.shots[T]++; if (b.shot.on) this.stats.onT[T]++; }
    else if (type === 'shot') this.stats.shots[T]++;
    p.kickAnim = 0.35; p.stun = Math.max(p.stun, 0.12);
    this.predT = 0;
    if (type === 'shot') this.useAdvantage(T);
    this.ev('kick', { p, kind: type, v: v0 });
  }

  detectShot() {
    const b = this.ball, s = { x: b.x, y: b.y, h: b.h, vx: b.vx, vy: b.vy, vh: b.vh, cax: b.cax, cay: b.cay, ct: b.ct };
    const dt = 1 / 60;
    for (let i = 0; i < 200; i++) {
      const py = s.y, px = s.x, ph = s.h;
      ballPhys(s, dt);
      if (Math.abs(s.y) >= HL) {
        const f = (HL - Math.abs(py)) / (Math.abs(s.y) - Math.abs(py) || 1e-6);
        const cx = px + (s.x - px) * f, ch = ph + (s.h - ph) * f;
        const defT = s.y > 0 ? 1 : 0;
        if (Math.abs(cx) < GW / 2 + 1.6 && ch < GH + 1.3 && hyp(s.vx, s.vy) > 5) {
          const gk = this.gk(defT);
          b.shot = { team: 1 - defT, cx, ch, tc: i * dt, on: Math.abs(cx) < GW / 2 && ch < GH, gx0: gk.x };
          gk.reactT = Math.max(0.06, GK_REACT - gk.st.por * 0.0026) * (1.25 - 0.35 * this.teams[defT].skill);
          gk.decided = false;
        }
        return;
      }
      if (Math.abs(s.x) > HW + 2) return;
    }
  }


  // ------------------------------------------------------------ palla
  updateBall(dt) {
    const b = this.ball;
    if (b.noT > 0) b.noT -= dt;
    if (b.owner) {
      const o = b.owner;
      b.x = o.x + o.fx * 0.6; b.y = o.y + o.fy * 0.6; b.h = 0; b.vx = o.vx; b.vy = o.vy; b.vh = 0;
      if (this.phase === 'play' && (Math.abs(b.x) > HW || Math.abs(b.y) > HL)) this.out(b.x, b.y, 0);
      return;
    }
    const px = b.x, py = b.y, ph = b.h;
    ballPhys(b, dt);
    if (this.phase !== 'play') {
      if (this.phase === 'goal') { b.vx *= 0.92; b.vy *= 0.9; b.x = clamp(b.x, -GW / 2 + 0.2, GW / 2 - 0.2); b.y = clamp(b.y, -HL - 1.9, HL + 1.9); }
      return;
    }
    if (b.shot && b.kick && b.kick.age > b.shot.tc + 0.35) b.shot = null;
    if (Math.abs(b.y) > HL) {
      const f = (HL - Math.abs(py)) / (Math.abs(b.y) - Math.abs(py) || 1e-6);
      const cx = px + (b.x - px) * f, ch = ph + (b.h - ph) * f;
      if (ch < GH + 0.13 && Math.abs(Math.abs(cx) - GW / 2) < 0.13) {
        b.y = Math.sign(b.y) * (HL - 0.05); b.vy = -b.vy * 0.5; b.vx += Math.sign(cx) * (Math.abs(cx) > GW / 2 ? 3 : -3); b.ct = 0; b.shot = null; this.predT = 0;
        this.ev('post', {}); return;
      }
      if (Math.abs(cx) < GW / 2 && Math.abs(ch - GH) < 0.13) {
        b.y = Math.sign(b.y) * (HL - 0.05); b.vy = -b.vy * 0.45; b.vh = -Math.abs(b.vh) * 0.4 - 1; b.ct = 0; b.shot = null; this.predT = 0;
        this.ev('post', {}); return;
      }
      this.out(cx, b.y, ch);
    } else if (Math.abs(b.x) > HW) this.out(b.x, b.y, b.h);
  }

  out(x, y, h) {
    const b = this.ball, lt = b.last ? b.last.team : 0;
    if (Math.abs(y) > HL) {
      const defT = y > 0 ? 1 : 0;
      if (Math.abs(x) < GW / 2 && h < GH) return this.goal(1 - defT);
      this.ev('out', { kind: lt === defT ? 'corner' : 'goalkick' });
      if (lt === defT) this.setRestart('corner', 1 - defT, x, y); else this.setRestart('goalkick', defT, x, y);
    } else {
      this.ev('out', { kind: 'throw' });
      this.setRestart('throw', 1 - lt, Math.sign(x) * HW, y);
    }
  }

  goal(forT) {
    const b = this.ball; this.score[forT]++;
    const s = b.last, og = !s || s.team !== forT;
    let scorer = og ? null : s, assist = null;
    if (scorer && this.lastPass && this.lastPass.to === scorer && this.lastPass.from !== scorer) assist = this.lastPass.from;
    if (og && b.prev && b.prev.team === forT) { scorer = b.prev; }
    const minute = Math.min(90, Math.floor((this.half - 1) * 45 + this.t / this.halfLen * 45) + 1);
    this.goalsLog.push({ team: forT, name: scorer ? scorer.name : 'Autogol', minute, scorer: scorer ? scorer.src : null, assist: assist ? assist.src : null });
    this.endDuel('gioco fermo');
    this.advantage = null; this.phase = 'goal'; this.goalT = 3.2; this.nextKick = 1 - forT; b.owner = null; b.shot = null; b.kick = null; b.ct = 0;
    for (const p of this.players) if (!p.off) { p.cele = p.team === forT ? 1 : -1; if (p.state !== 'play') { p.state = 'play'; p.dive = null; } }
    this.ev('goal', { team: forT, scorer, assist, og: og && !scorer, minute });
  }

  // ------------------------------------------------------------ ciclo
  step(dt) {
    const b = this.ball;
    this.time += dt;
    if (this.phase === 'full' || this.phase === 'half') return;
    for (let T = 0; T < 2; T++) { const m = this.move[T]; if (m) { m.ttl -= dt; if (m.ttl <= 0) this.move[T] = null; } this.switchCd[T] -= dt; }
    if (this.phase === 'goal') {
      this.goalT -= dt;
      for (const p of this.players) { p.tx = p.x; p.ty = p.y; }
      this.movePlayers(dt); this.updateBall(dt);
      if (this.goalT <= 0) this.setupKickoff(this.nextKick);
      return;
    }
    this.think(dt);
    this.movePlayers(dt);
    this.updateBall(dt);
    this.updateDuel(dt);
    if (this.phase === 'play') {
      this.contacts(dt);
      if (this.phase === 'play') this.checkAdvantage(dt);
      if (this.phase === 'play') {
        this.t += dt;
        if (this.att >= 0) this.stats.poss[this.att] += dt;
        if (this.t >= this.halfLen && !b.shot) this.endHalf();
      }
    } else if (this.phase === 'restart') {
      const r = this.restart; r.t += dt;
      if (!this.human[r.team] ? r.t >= r.wait : r.t > 14) this.aiRestart();
    }
    this.updateCtrl(dt);
  }

  // ------------------------------------------------------------ vantaggio
  // Fallo su `on`: si lascia correre se la sua squadra ha ancora il pallone fuori dalla propria metà e nessun altro avversario addosso.
  advantageOk(on, by) {
    const b = this.ball, dir = on.team ? -1 : 1;
    if (b.owner !== on || on.y * dir < ADV_MIN_Y) return false;
    for (const o of this.players) if (o.team !== on.team && o !== by && !o.off && hyp(o.x - on.x, o.y - on.y) < ADV_FREE) return false;
    return true;
  }
  checkAdvantage(dt) {
    const a = this.advantage; if (!a) return;
    const o = this.ball.owner;
    if (o && o.team !== a.team) {
      this.advantage = null; this.ev('advantage_back', { team: a.team });
      this.setRestart('freekick', a.team, a.x, a.y); return;
    }
    a.t -= dt;
    if (a.t <= 0) { this.advantage = null; this.ev('advantage_over', { team: a.team }); }
  }
  // un tiro della squadra che ha il vantaggio lo chiude: il vantaggio è stato sfruttato
  useAdvantage(T) { if (this.advantage && this.advantage.team === T) { this.advantage = null; this.ev('advantage_over', { team: T }); } }

  endHalf() {
    this.endDuel('gioco fermo'); this.resetStates(); this.ball.shot = null;
    if (this.half === 1) { this.phase = 'half'; this.ev('half', {}); }
    else { this.phase = 'full'; this.ev('full', {}); }
  }
  startSecondHalf() {
    if (this.phase !== 'half') return;
    this.half = 2; this.t = 0; this.setupKickoff(1 - this.kickoffTeam);
  }
  minute() { return Math.min(this.half === 1 ? 45 : 90, Math.floor((this.half - 1) * 45 + this.t / this.halfLen * 45)); }

  updateCtrl(dt, force) {
    const b = this.ball;
    for (let T = 0; T < 2; T++) {
      if (!this.human[T]) { this.ctrl[T] = null; continue; }
      let c = this.ctrl[T];
      if (c && c.off) c = null;
      const nearest = () => { let n = null, bd = 1e9; for (const p of this.players) if (p.team === T && !p.off && p.pos !== 'P') { const d = hyp(p.x - b.x, p.y - b.y) + (p.state !== 'play' ? 6 : 0); if (d < bd) { bd = d; n = p; } } return n; };
      if (b.owner && b.owner.team === T) c = b.owner;
      else if (this.phase === 'restart' || this.phase === 'goal') { if (!c || c.pos === 'P' || force) c = nearest(); }
      else if (!b.owner) {
        const ch = this.chase[T];
        if (ch && ch.p2 && (this.switchCd[T] <= 0 || !c || c.pos === 'P') && c !== ch.p2) { c = ch.p2; this.switchCd[T] = 0.6; }
        if (!c || c.pos === 'P') c = nearest();
      } else {
        const n = nearest();
        if (!c || c.pos === 'P') c = n;
        else if (n && n !== c && this.switchCd[T] <= 0 && hyp(c.x - b.x, c.y - b.y) - hyp(n.x - b.x, n.y - b.y) > 3.5) { c = n; this.switchCd[T] = 0.8; }
      }
      if (c !== this.ctrl[T]) { this.ctrl[T] = c; const m = this.move[T]; if (m && !m.held) this.move[T] = null; }
    }
  }

  // ------------------------------------------------------------ comandi umani
  userKick(T, spec) {
    const p = this.ctrl[T], b = this.ball;
    if (!p || b.owner !== p || p.stun > 0) return false;
    if (this.phase === 'restart') { if (this.restart.taker !== p || this.restart.t < 0.35) return false; }
    else if (this.phase !== 'play') return false;
    spec.human = true; this.move[T] = null;
    this.kick(p, spec); return true;
  }
  // corsa lungo una strada disegnata dal giocatore col pallone: pts = [{x, y}, ...] in metri.
  // Il portatore segue i punti uno dopo l'altro; scatta finché davanti ha ancora più di PATH_SPRINT metri di strada.
  userPath(T, pts) {
    const c = this.ctrl[T], b = this.ball;
    if (!c || b.owner !== c || !Array.isArray(pts) || pts.length < 1) return false;
    const path = [];
    for (const q of pts) {
      const x = clamp(q.x, -HW + 0.5, HW - 0.5), y = clamp(q.y, -HL + 0.5, HL - 0.5), l = path[path.length - 1];
      if (!l || hyp(x - l.x, y - l.y) >= PATH_STEP) path.push({ x, y });
    }
    const e = pts[pts.length - 1], z = path[path.length - 1], ex = clamp(e.x, -HW + 0.5, HW - 0.5), ey = clamp(e.y, -HL + 0.5, HL - 0.5);
    if (z && (z.x !== ex || z.y !== ey)) path.push({ x: ex, y: ey }); // l'ultimo punto della linea c'è sempre
    if (!path.length) return false;
    this.move[T] = { x: path[0].x, y: path[0].y, ttl: PATH_TTL, held: false, sprint: false, path, i: 0, owner: c };
    return true;
  }
  // chiamata da assign(): avanza lungo la strada e aggiorna il punto da raggiungere
  followPath(p, mv) {
    const T = p.team;
    if (this.ball.owner !== mv.owner || p !== mv.owner) { this.move[T] = null; return; }
    while (mv.i < mv.path.length - 1 && hyp(mv.path[mv.i].x - p.x, mv.path[mv.i].y - p.y) < PATH_REACH) mv.i++;
    const q = mv.path[mv.i], a = mv.path[lookAhead(mv.path, mv.i, p.x, p.y)]; mv.x = a.x; mv.y = a.y;
    let left = hyp(q.x - p.x, q.y - p.y);
    for (let k = mv.i + 1; k < mv.path.length; k++) left += hyp(mv.path[k].x - mv.path[k - 1].x, mv.path[k].y - mv.path[k - 1].y);
    mv.sprint = left > PATH_SPRINT;
    if (mv.i === mv.path.length - 1 && left < PATH_REACH) this.move[T] = null;
  }
  // Difesa: linea disegnata da un proprio giocatore senza palla, che corre lungo quella strada.
  // Tutti i giocatori di movimento possono avere la loro linea (il portiere no); una nuova linea dello stesso giocatore sostituisce la sua.
  userRun(T, p, pts) {
    const b = this.ball;
    if (!p || p.team !== T || p.off || p.pos === 'P' || b.owner === p || this.phase !== 'play' || !Array.isArray(pts) || !pts.length) return false;
    pts = clipLen(p.x, p.y, pts, RUN_MAX_LEN);
    const path = [];
    for (const q of pts) {
      const x = clamp(q.x, -HW + 0.5, HW - 0.5), y = clamp(q.y, -HL + 0.5, HL - 0.5), l = path[path.length - 1];
      if (!l || hyp(x - l.x, y - l.y) >= PATH_STEP) path.push({ x, y });
    }
    const e = pts[pts.length - 1], z = path[path.length - 1], ex = clamp(e.x, -HW + 0.5, HW - 0.5), ey = clamp(e.y, -HL + 0.5, HL - 0.5);
    if (z && (z.x !== ex || z.y !== ey)) path.push({ x: ex, y: ey }); // l'ultimo punto della linea c'è sempre
    if (!path.length) return false;
    const runs = this.runs[T].filter(r => r.p !== p);
    runs.push({ p, path, i: 0, ttl: PATH_TTL });
    this.runs[T] = runs;
    return true;
  }
  runOf(p) { return this.runs[p.team].find(r => r.p === p) || null; }
  // chiamata da assign(): punto da raggiungere lungo la linea; false quando la linea è finita o non vale più
  followRun(p, r) {
    const b = this.ball;
    if (b.owner && b.owner.team === p.team || p.state !== 'play') { this.runs[p.team] = this.runs[p.team].filter(q => q !== r); return false; }
    r.ttl -= this.dtT;
    while (r.i < r.path.length - 1 && hyp(r.path[r.i].x - p.x, r.path[r.i].y - p.y) < PATH_REACH) r.i++;
    const q = r.path[r.i];
    if (r.ttl <= 0 || (r.i === r.path.length - 1 && hyp(q.x - p.x, q.y - p.y) < RUN_END_REACH)) { this.runs[p.team] = this.runs[p.team].filter(z => z !== r); this.runEnded(p); return false; }
    const a = r.path[lookAhead(r.path, r.i, p.x, p.y)]; p.tx = a.x; p.ty = a.y;
    let left = hyp(q.x - p.x, q.y - p.y);
    for (let k = r.i + 1; k < r.path.length; k++) left += hyp(r.path[k].x - r.path[k - 1].x, r.path[k].y - r.path[k - 1].y);
    p.sprint = left > PATH_SPRINT;
    return true;
  }
  // sprint: true/false dal telefono; se manca, scatto quando il dito tenuto premuto è lontano dal giocatore controllato
  userMove(T, x, y, held, sprint) {
    if (sprint === undefined) { const c = this.ctrl[T]; sprint = !!(held && c && hyp(x - c.x, y - c.y) > SPRINT_DIST); }
    this.move[T] = { x: clamp(x, -HW - 1, HW + 1), y: clamp(y, -HL - 1, HL + 1), ttl: held ? 0.3 : 1.8, held: !!held, sprint: !!(held && sprint) };
  }
  userStop(T) { this.move[T] = null; }
  userSlide(T, dx, dy) {
    const p = this.ctrl[T], b = this.ball;
    if (!p || this.phase !== 'play' || p.state !== 'play' || p.stun > 0 || p.pos === 'P') return false;
    if (b.owner && b.owner.team === T) return false;
    const n = hyp(dx, dy); if (n < 1e-6) return false;
    p.state = 'slide'; p.t = 0; p.sdx = dx / n; p.sdy = dy / n; p.hit = false; p.fx = p.sdx; p.fy = p.sdy; this.move[T] = null;
    this.ev('slide', { p }); return true;
  }
  diveWin(T) { const b = this.ball, g = this.gk(T); return !!(this.human[T] && this.phase === 'play' && b.shot && b.shot.team !== T && !b.owner && g.state === 'play'); }
  userDive(T, dxm, th) {
    if (!this.diveWin(T)) return false;
    const g = this.gk(T); this.startDive(g, g.x + dxm, th); return true;
  }
  userSwitch(T, p) {
    const b = this.ball;
    if (!p || p.team !== T || p.off || p.pos === 'P' || (b.owner && b.owner.team === T) || this.phase !== 'play') return false;
    this.ctrl[T] = p; this.switchCd[T] = 2; this.move[T] = null; return true;
  }
  // dribbling nel duello aperto per la squadra T (tasto in basso). Ritorna true se il tentativo è partito;
  // l'esito arriva con l'evento 'dribble' { p, o, ok }.
  userDribble(T) {
    const d = this.duel;
    if (!d || d.team !== T || this.phase !== 'play') return false;
    const p = d.p;
    // niente attesa tra due tentativi (p.dribCd vale per l'IA): fra due duelli passa già DUEL_CD, e nel rallenty
    // l'attesa durava molti secondi veri col tasto in vista che non faceva nulla
    if (this.ball.owner !== p || p.stun > 0 || p.state !== 'play') return false;
    this.dribble(p, d.o);
    return true;
  }
  // Scatto nel duello aperto per la squadra T (tasto in basso, al posto del Dribbling). Come userDribble.
  userSprint(T) {
    const d = this.duel;
    if (!d || d.team !== T || this.phase !== 'play') return false;
    const p = d.p;
    if (this.ball.owner !== p || p.stun > 0 || p.state !== 'play') return false;
    this.dribble(p, d.o, true);
    return true;
  }
  hint(T) {
    const b = this.ball;
    if (this.phase === 'restart') return this.restart.team === T ? 'restart' : 'wait';
    if (this.phase !== 'play') return '';
    if (this.diveWin(T)) return 'dive';
    // nel duello resta 'attack' (così input.js lascia disegnare il passaggio): per il duello c'è duelFor(T)
    if (b.owner && b.owner.team === T) return 'attack';
    if (b.owner) return 'defend';
    return 'loose';
  }
  substitute(T, idx, src) {
    const p = this.team(T)[idx]; if (!p || p.off) return false;
    p.src = src; p.name = src.name; p.st = effStats(src, p.pos); p.energy = 1; p.wear = { dri: 1, tes: 1 }; p.dribCd = 0; p.yellow = 0; p.look = this.lookFor(src);
    if (this.duel && (this.duel.p === p || this.duel.o === p)) this.endDuel('gioco fermo');
    this.ev('sub', { p }); return true;
  }
}

// i metodi di IA e movimento vivono in file separati ma fanno parte di Match
for (const C of [AIMethods, MotionMethods, DuelMethods]) {
  for (const k of Object.getOwnPropertyNames(C.prototype)) if (k !== 'constructor') Object.defineProperty(Match.prototype, k, Object.getOwnPropertyDescriptor(C.prototype, k));
}
