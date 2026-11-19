// Motore partita: nessuna dipendenza grafica, gira anche in Node per i test.
// Coordinate: x = larghezza (-HW..HW), y = lunghezza (-HL..HL), h = altezza.
// La squadra 0 attacca verso +y, la squadra 1 verso -y.
export const W = 64, L = 100, HW = W / 2, HL = L / 2;
export const GW = 7.32, GH = 2.44, BOX_W = 40.32, BOX_D = 16.5, SIX_W = 18.32, SIX_D = 5.5, PEN_D = 11, CIRCLE = 9.15;
const G = 11.5, ROLL = 5.0;
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const hyp = Math.hypot;

export function rng32(a) {
  return function () {
    a |= 0; a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// [ruolo, x (-1..1), y (0 = propria porta .. 1 = porta avversaria)]
export const FORMATIONS = {
  '4-4-2': [['P', 0, .03], ['D', -.72, .2], ['D', -.24, .16], ['D', .24, .16], ['D', .72, .2], ['C', -.78, .44], ['C', -.26, .4], ['C', .26, .4], ['C', .78, .44], ['A', -.22, .66], ['A', .22, .66]],
  '4-3-3': [['P', 0, .03], ['D', -.72, .2], ['D', -.24, .16], ['D', .24, .16], ['D', .72, .2], ['C', -.5, .42], ['C', 0, .37], ['C', .5, .42], ['A', -.72, .64], ['A', 0, .69], ['A', .72, .64]],
  '3-5-2': [['P', 0, .03], ['D', -.5, .19], ['D', 0, .16], ['D', .5, .19], ['C', -.85, .45], ['C', -.4, .41], ['C', 0, .36], ['C', .4, .41], ['C', .85, .45], ['A', -.22, .66], ['A', .22, .66]],
  '4-2-3-1': [['P', 0, .03], ['D', -.72, .2], ['D', -.24, .16], ['D', .24, .16], ['D', .72, .2], ['C', -.25, .35], ['C', .25, .35], ['C', -.7, .53], ['C', 0, .52], ['C', .7, .53], ['A', 0, .7]],
};

const POSPEN = { PP: 1, DD: 1, CC: 1, AA: 1, DC: .92, CD: .92, CA: .92, AC: .92, DA: .82, AD: .82 };
export function effStats(src, slotPos) {
  let f = POSPEN[src.pos + slotPos];
  if (f === undefined) f = 0.6;
  const s = { vel: src.vel, tir: src.tir * f, pas: src.pas * f, dri: src.dri * f, dif: src.dif * f, fis: src.fis, por: src.por };
  if (slotPos === 'P' && src.pos !== 'P') s.por = Math.min(src.por, 25);
  return s;
}

function ballPhys(s, dt) {
  if (s.ct > 0) { s.vx += s.cax * dt; s.vy += s.cay * dt; s.ct -= dt; }
  s.x += s.vx * dt; s.y += s.vy * dt;
  if (s.h > 0 || s.vh > 0) {
    s.vh -= G * dt; s.h += s.vh * dt;
    if (s.h <= 0) {
      s.h = 0;
      if (s.vh < -2.2) { s.vh = -s.vh * 0.5; s.vx *= 0.8; s.vy *= 0.8; } else s.vh = 0;
    }
  } else {
    const v = hyp(s.vx, s.vy);
    if (v > 0) { const nv = Math.max(0, v - ROLL * dt); s.vx *= nv / v; s.vy *= nv / v; }
  }
}

function segInfo(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay, l2 = dx * dx + dy * dy || 1e-9;
  const t = clamp(((px - ax) * dx + (py - ay) * dy) / l2, 0, 1);
  return [hyp(px - (ax + dx * t), py - (ay + dy * t)), t];
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
    this.stats = { shots: [0, 0], onT: [0, 0], poss: [0, 0], fouls: [0, 0], corners: [0, 0], saves: [0, 0] };
    this.ctrl = [null, null]; this.move = [null, null]; this.switchCd = [0, 0];
    this.chase = [null, null]; this.presser = [null, null]; this.cover = [null, null]; this.offLine = [HL, HL];
    this.predT = 0; this.att = -1; this.dtT = 0; this.lastPass = null; this.restart = null;
    this.goalsLog = [];
    this.kickoffTeam = o.kickoff ?? (this.rnd() < 0.5 ? 0 : 1);
    this.setupKickoff(this.kickoffTeam);
  }

  mk(team, i, src, slot) {
    const dir = team ? -1 : 1;
    return {
      team, i, src, name: src.name, pos: slot[0], bx: slot[1], by: slot[2], st: effStats(src, slot[0]),
      x: 0, y: 0, vx: 0, vy: 0, fx: 0, fy: dir, tx: 0, ty: 0, spdF: 1, state: 'play', t: 0, stun: 0, protect: 0,
      contact: 0, tackleCd: 0, kickAnim: 0, energy: 1, yellow: 0, off: false, sdx: 0, sdy: 0, hit: false,
      dive: null, phase: this.rnd() * 6, aiT: 0, dx: 0, dy: 0, reactT: 0, decided: true, warn: false,
      sox: 0, soy: 0, soT: this.rnd(), cele: 0, look: Math.floor(this.rnd() * 1000),
    };
  }

  team(t) { return t ? this.players.slice(11) : this.players.slice(0, 11); }
  gk(t) { return this.players[t * 11]; }
  gauss() { return (this.rnd() + this.rnd() + this.rnd() - 1.5) * 2; }
  vmax(p) { return (5.0 + p.st.vel * 0.036) * (0.86 + 0.14 * p.energy); }
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
    if (this.att === p.team) { ay = p.by * 0.5 + bf * 0.55 + (p.pos === 'A' ? 0.06 : (p.pos === 'C' && Math.abs(p.bx) > 0.6 ? 0.05 : 0)); ax = p.bx + bx * 0.15; }
    else { ay = p.by * 0.55 + bf * 0.36 - 0.03; ax = p.bx * 0.7 + bx * 0.28; }
    return [clamp(ax, -0.95, 0.95) * HW * 0.94, (clamp(ay, 0.04, 0.96) - 0.5) * L * dir];
  }
  place(p, x, y) {
    p.x = x; p.y = y; p.vx = p.vy = 0; p.tx = x; p.ty = y; p.state = 'play'; p.t = 0; p.stun = 0; p.contact = 0;
    p.dive = null; p.warn = false; p.hit = false; p.cele = 0;
  }
  resetStates() {
    for (const p of this.players) if (!p.off) { p.state = 'play'; p.t = 0; p.stun = 0; p.contact = 0; p.dive = null; p.warn = false; p.cele = 0; p.vx *= 0.3; p.vy *= 0.3; }
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
    this.phase = 'restart'; this.move = [null, null]; this.lastPass = null;
    this.resetStates();
    let cut = false;
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
    this.restart = { type, team, taker, x: b.x, y: b.y, t: 0, wait: 1.1 + this.rnd() * 0.7 + (type === 'penalty' ? 0.8 : 0) + (cut ? 0.5 : 0) };
    this.predT = 0;
    this.updateCtrl(0, true);
    this.ev('restart', { kind: type, team, cut });
  }
  setupKickoff(team) { this.setRestart('kickoff', team, 0, 0); }

  // ------------------------------------------------------------ calci
  kick(p, spec) {
    const b = this.ball, T = p.team, dir = T ? -1 : 1;
    const sx = b.owner === p ? b.x : p.x + p.fx * 0.6, sy = b.owner === p ? b.y : p.y + p.fy * 0.6;
    let type = spec.type, th = spec.th || 0;
    let dx = spec.tx - sx, dy = spec.ty - sy, D = hyp(dx, dy);
    if (D < 1) { dx = p.fx; dy = p.fy; D = 1; }
    if (type === 'auto') type = (D > 30 || this.blocked(sx, sy, spec.tx, spec.ty, T)) ? 'loft' : 'ground';
    const press = this.nearOpp(p.x, p.y, T);
    let sig = type === 'shot' ? (0.5 + (100 - p.st.tir) * 0.04) * (press < 2 ? 1.5 : 1) : (0.3 + (100 - p.st.pas) * 0.025) * (type === 'loft' ? 1.4 : 1);
    if (spec.human) sig *= 0.75;
    const a = this.gauss() * sig * Math.PI / 180, ca = Math.cos(a), sa = Math.sin(a);
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
      v0 = 20 + p.st.tir * 0.13; Tt = D / v0;
      th = Math.max(0.05, th + this.gauss() * sig * 0.017 * D);
      vh = (th + 0.5 * G * Tt * Tt) / Tt;
    }
    Tt = Math.max(Tt, 0.15);
    const c = clamp(spec.curve || 0, -D * 0.3, D * 0.3);
    let ac = clamp(-8 * c / (Tt * Tt), -14, 14);
    const lv = -ac * Tt / 2;
    b.owner = null; b.x = sx; b.y = sy; b.h = 0.02;
    b.vx = ux * v0 + nx * lv; b.vy = uy * v0 + ny * lv; b.vh = vh;
    b.cax = nx * ac; b.cay = ny * ac; b.ct = ac ? Tt : 0;
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
          gk.reactT = Math.max(0.06, 0.36 - gk.st.por * 0.0026) * (1.25 - 0.35 * this.teams[defT].skill);
          gk.decided = false;
        }
        return;
      }
      if (Math.abs(s.x) > HW + 2) return;
    }
  }

  aiShoot(p, pen) {
    const dir = p.team ? -1 : 1, gk = this.gk(1 - p.team);
    const side = pen ? (this.rnd() < 0.5 ? -1 : 1) : (gk.x > 0 ? -1 : 1) * (this.rnd() < 0.8 ? 1 : -1);
    this.kick(p, { type: 'shot', tx: side * (GW / 2 - 0.8), ty: dir * HL, th: this.rnd() < 0.55 ? 0.3 + this.rnd() * 0.4 : 1.2 + this.rnd() * 0.8, curve: (this.rnd() - 0.5) * 1.5 });
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
        const s2 = Math.min(mar / 3, 0.8) - 0.1; if (s2 > safe) { safe = s2; type = 'loft'; }
      }
      const gain = (ty - oy) * dir;
      let sc = clamp(safe, -2, 1.2) + gain * 0.09 + Math.min(open, 8) * 0.06 - (d > 30 ? 0.25 : 0) + (through ? 0.6 : 0);
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
      if (Math.abs(ox) > 14 && oy * dir > HL - 24 && m.pos !== 'D' && Math.abs(m.x) < 11 && m.y * dir > HL - 17) {
        const sc = 1.3 + (this.rnd() - 0.5) * 0.5 - hyp(m.x, m.y - gy) * 0.03;
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
    if (p.aiT <= 0 && p.stun <= 0) {
      p.aiT = 0.42 - 0.2 * sk + this.rnd() * 0.15;
      if (dg < 32) {
        const ang = Math.abs(Math.atan2(p.x, Math.max(0.1, HL - p.y * dir)));
        let q = clamp((32 - dg) / 16, 0, 1) * clamp(1.25 - ang * 0.9, 0.1, 1);
        if (this.lane(p.x, p.y, 0, gy, T, 28, true) < 0) q *= 0.4;
        if (dg < 10) q += 0.5;
        if (q > 0.33 + this.rnd() * 0.3 - (press < 2.5 ? 0.12 : 0)) { this.aiShoot(p); return; }
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
        if (press < 2.1) want = pass.safe > 0 ? 0.92 : (p.y * dir < -HL * 0.5 ? 0.5 : 0);
        else if (pass.safe > 0.15) {
          if (pass.gain > 6) want = front < 5 ? 0.8 : 0.45;
          else if (front < 4) want = 0.6;
          else if (p.holdN > 5) want = 0.3;
        }
        if (this.rnd() < want) { this.kick(p, { type: pass.safe > 0 ? pass.type : 'loft', tx: pass.tx, ty: pass.ty }); return; }
      }
      const base = Math.atan2(gy - p.y, (dg > 30 ? p.x * 0.7 : 0) - p.x);
      let bs = -1e9, ba = base;
      for (const o of [-1.2, -0.7, -0.35, 0, 0.35, 0.7, 1.2]) {
        const a = base + o, qx = p.x + Math.cos(a) * 5, qy = p.y + Math.sin(a) * 5;
        let s2 = (dg - hyp(qx, qy - gy)) * 1.5 + Math.min(this.nearOpp(qx, qy, T), 4) * 1.1 - Math.abs(o) * 0.3;
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
      if (dg < 27 && Math.abs(p.x) < 16) return this.aiShoot(p);
      if (dg < 42) return this.kick(p, { type: 'loft', tx: (this.rnd() - 0.5) * 12, ty: dir * (HL - 7 - this.rnd() * 5) });
    }
    const o = this.passOptions(p, r.type === 'throw' || r.type === 'goalkick');
    if (o && o.safe > -0.2) return this.kick(p, { type: o.type, tx: o.tx, ty: o.ty });
    this.kick(p, { type: 'loft', tx: clamp(p.x * 0.5 + (this.rnd() - 0.5) * 24, -HW + 4, HW - 4), ty: clamp(p.y + dir * 36, -HL + 8, HL - 8) });
  }

  // ------------------------------------------------------------ IA
  computeLines() {
    for (let T = 0; T < 2; T++) {
      const dir = T ? -1 : 1; let a = -99, s = -99;
      for (const o of this.players) if (o.team !== T && !o.off) { const v = o.y * dir; if (v > a) { s = a; a = v; } else if (v > s) s = v; }
      this.offLine[T] = Math.max(0, s === -99 ? HL : s);
    }
  }
  computeChasers() {
    const b = this.ball;
    this.presser = [null, null];
    for (let T = 0; T < 2; T++) {
      let bp = null, bd = 1e9;
      for (const p of this.players) if (p.team === T && !p.off && p.pos !== 'P' && p.state === 'play') { const d = hyp(p.x - b.x, p.y - b.y); if (d < bd) { bd = d; bp = p; } }
      this.presser[T] = bp;
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
        const gk = p.pos === 'P', vm = this.vmax(p), hm = gk ? 2.3 : 1.5;
        let r = null;
        for (let k = 0; k < N; k++) {
          if (ph[k] > hm) continue;
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
      p.spdF = 1;
      this.assign(p);
    }
  }

  assign(p) {
    const b = this.ball, T = p.team, dir = T ? -1 : 1, hum = this.human[T];
    if (this.phase === 'restart' && this.restart.taker === p) { p.tx = p.x; p.ty = p.y; return; }
    const mv = hum && this.ctrl[T] === p ? this.move[T] : null;
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

  support(p) {
    const b = this.ball, T = p.team, dir = T ? -1 : 1;
    const [ax, ay] = this.anchor(p);
    p.soT -= this.dtT;
    if (p.soT <= 0) {
      p.soT = 0.5 + this.rnd() * 0.4; let bs = -1e9;
      for (const c of [[0, 0], [5, 0], [-5, 0], [0, 4], [3.5, 3], [-3.5, 3], [0, -4]]) {
        const qx = ax + c[0], qy = ay + c[1] * dir;
        if (Math.abs(qx) > HW - 1.5 || Math.abs(qy) > HL - 2) continue;
        const s = Math.min(this.nearOpp(qx, qy, T), 7) + (this.lane(b.x, b.y, qx, qy, T, 18) > 0 ? 1.5 : 0) + (c[1] > 0 ? 0.6 : 0) + this.rnd() * 0.5;
        if (s > bs) { bs = s; p.sox = c[0]; p.soy = c[1] * dir; }
      }
    }
    let tx = ax + p.sox, ty = ay + p.soy;
    const line = this.offLine[T], flight = !b.owner && b.kick && b.kick.team === T;
    if (p.pos === 'A' && b.y * dir > -15) ty = Math.max(ty * dir, Math.min(line - 0.8, HL - 6)) * dir;
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
          p.tx = b.x + c.vx * 0.25; p.ty = b.y + c.vy * 0.25;
          const d = hyp(p.x - b.x, p.y - b.y), sk = this.teams[T].skill;
          if (d > 1.5 && d < 3.2 && p.tackleCd <= 0 && c.protect <= 0 && this.rnd() < this.dtT * (0.2 + 0.5 * sk)) {
            const dot = ((p.x - c.x) * c.fx + (p.y - c.y) * c.fy) / (hyp(p.x - c.x, p.y - c.y) || 1);
            if (dot < 0.6) { p.state = 'prep'; p.t = 0.26; p.warn = true; p.vx *= 0.5; p.vy *= 0.5; }
          }
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

  // ------------------------------------------------------------ movimento
  movePlayers(dt) {
    const b = this.ball, live = this.phase === 'play';
    for (const p of this.players) {
      if (p.off) continue;
      if (p.stun > 0) p.stun -= dt;
      if (p.protect > 0) p.protect -= dt;
      if (p.tackleCd > 0) p.tackleCd -= dt;
      if (p.kickAnim > 0) p.kickAnim -= dt;
      if (p.state === 'play') {
        let dx = p.tx - p.x, dy = p.ty - p.y; const d = hyp(dx, dy);
        const vm = this.vmax(p) * (b.owner === p ? 0.86 + p.st.dri * 0.001 : 1) * p.spdF;
        let sp = p.stun > 0 ? 0 : Math.min(vm, d * 3.2);
        if (d < 0.15) sp = 0;
        const wx = d > 0 ? dx / d * sp : 0, wy = d > 0 ? dy / d * sp : 0;
        const acc = (11 + p.st.fis * 0.06) * dt;
        const ex = wx - p.vx, ey = wy - p.vy, e = hyp(ex, ey);
        if (e <= acc) { p.vx = wx; p.vy = wy; } else { p.vx += ex / e * acc; p.vy += ey / e * acc; }
        p.x += p.vx * dt; p.y += p.vy * dt;
        const v = hyp(p.vx, p.vy);
        let lx, ly;
        if (v > 0.8) { lx = p.vx / v; ly = p.vy / v; }
        else { lx = b.x - p.x; ly = b.y - p.y; const n = hyp(lx, ly); if (n > 0.8 && b.owner !== p) { lx /= n; ly /= n; } else { lx = p.fx; ly = p.fy; } }
        const k = Math.min(1, dt * (b.owner === p ? 8 + p.st.dri * 0.05 : 12));
        p.fx += (lx - p.fx) * k; p.fy += (ly - p.fy) * k;
        const n = hyp(p.fx, p.fy) || 1; p.fx /= n; p.fy /= n;
        p.phase += v * dt * 1.9;
        p.energy = Math.max(0.2, p.energy - (v / 8) * (v / 8) * dt * 0.0022 * (1.3 - p.st.fis * 0.006));
      } else if (p.state === 'prep') {
        p.t -= dt; p.vx *= 0.9; p.vy *= 0.9; p.x += p.vx * dt; p.y += p.vy * dt;
        if (p.t <= 0) {
          p.warn = false;
          const c = b.owner; let tx = b.x, ty = b.y;
          if (c) { tx += c.vx * 0.22; ty += c.vy * 0.22; }
          const dx = tx - p.x, dy = ty - p.y, n = hyp(dx, dy) || 1;
          if (live && c && c.team !== p.team && n < 5) { p.state = 'slide'; p.t = 0; p.sdx = dx / n; p.sdy = dy / n; p.hit = false; p.fx = p.sdx; p.fy = p.sdy; this.ev('slide', { p }); }
          else p.state = 'play';
        }
      } else if (p.state === 'slide') this.slideStep(p, dt);
      else if (p.state === 'down') { p.t -= dt; p.vx = p.vy = 0; if (p.t <= 0) { p.state = 'play'; p.tackleCd = 0.4; } }
      else if (p.state === 'dive') this.diveStep(p, dt);
      p.x = clamp(p.x, -HW - 3, HW + 3); p.y = clamp(p.y, -HL - 2.5, HL + 2.5);
    }
    // separazione
    const taker = this.phase === 'restart' ? this.restart.taker : null;
    for (let i = 0; i < 22; i++) {
      const a = this.players[i]; if (a.off || a.state === 'dive') continue;
      for (let j = i + 1; j < 22; j++) {
        const c = this.players[j]; if (c.off || c.state === 'dive') continue;
        const dx = c.x - a.x, dy = c.y - a.y, d2 = dx * dx + dy * dy;
        if (d2 < 0.49 && d2 > 1e-6) {
          const d = Math.sqrt(d2), k = (0.7 - d) / d * 0.5;
          if (a !== taker) { a.x -= dx * k; a.y -= dy * k; }
          if (c !== taker) { c.x += dx * k; c.y += dy * k; }
        }
      }
    }
  }

  slideStep(p, dt) {
    const b = this.ball, sp = 10.5 * (1 - p.t / 0.45) + 2.5;
    p.vx = p.sdx * sp; p.vy = p.sdy * sp; p.x += p.vx * dt; p.y += p.vy * dt; p.t += dt;
    if (this.phase === 'play' && !p.hit) {
      const db = hyp(b.x - p.x, b.y - p.y);
      if (b.owner && b.owner.team !== p.team) {
        const c = b.owner, dc = hyp(c.x - p.x, c.y - p.y);
        if (db < 0.95) {
          p.hit = true; c.stun = 0.55; c.tackleCd = 0.8;
          b.owner = null; b.vx = p.sdx * 7 + (this.rnd() - .5) * 2; b.vy = p.sdy * 7 + (this.rnd() - .5) * 2; b.vh = 1; b.h = 0.05; b.ct = 0;
          b.prev = b.last; b.last = p; b.kick = null; b.noP = c; b.noT = 0.5; this.predT = 0;
          this.ev('tackle', { p, on: c, slide: true });
        } else if (dc < 0.6) { p.hit = true; this.foul(p, c); return; }
      } else if (!b.owner && db < 0.95 && b.h < 0.7 && !(b.noP === p && b.noT > 0)) {
        p.hit = true; b.vx = p.sdx * 9; b.vy = p.sdy * 9; b.vh = 1.5; b.ct = 0;
        if (b.last !== p) { b.prev = b.last; b.last = p; } b.kick = null; b.shot = null; b.noP = p; b.noT = 0.3; this.predT = 0;
        this.ev('tackle', { p, slide: true });
      }
    }
    if (p.t >= 0.45 && p.state === 'slide') { p.state = 'down'; p.t = 0.6; p.vx = p.vy = 0; }
  }

  diveStep(p, dt) {
    const hm = this.human[p.team] && !this.autoGk[p.team];
    const b = this.ball, d = p.dive, vs = Math.min(hm ? 6.5 + p.st.por * 0.035 : 4.5 + p.st.por * 0.03, (hm ? 30 : 22) * (p.t + dt));
    d.hx += clamp(d.tx - d.hx, -vs * dt, vs * dt);
    d.hh += clamp(d.th - d.hh, -vs * 0.7 * dt, vs * 0.7 * dt);
    const bt = Math.abs(d.hx - d.x0) > 0.75 ? d.hx - d.dirx * 0.75 : d.x0;
    p.x += clamp(bt - p.x, -vs * dt, vs * dt);
    p.t += dt;
    if (this.phase === 'play' && !b.owner && !(b.noP === p && b.noT > 0) && Math.abs(b.y - p.y) < 0.9 + Math.abs(b.vy) * dt) {
      const prog = clamp(p.t / 0.4, 0, 1);
      const [dd] = segInfo(b.x, b.h, d.x0, 1.0 - prog * 0.3, d.hx, d.hh);
      if (dd < 0.72 + p.st.por * 0.002) this.save(p, Math.abs(b.x - d.x0) < 1.3);
    }
    if (p.t > 0.8 && p.state === 'dive') { p.state = 'down'; p.t = 0.55; }
  }

  save(p, central) {
    const b = this.ball, sp = hyp(b.vx, b.vy, b.vh);
    this.stats.saves[p.team]++;
    if (sp < 16 || (central && sp < 25)) { this.ev('save', { p, catch: true }); this.give(p); return; }
    const sx = p.dive ? p.dive.dirx : (b.x >= p.x ? 1 : -1);
    b.vx = sx * (5 + this.rnd() * 3); b.vy = -b.vy * 0.15; b.vh = 2 + this.rnd() * 2; b.ct = 0;
    if (b.last !== p) { b.prev = b.last; b.last = p; } b.kick = null; b.shot = null; b.noP = p; b.noT = 0.4; this.predT = 0;
    this.ev('save', { p, catch: false });
  }

  foul(by, on) {
    this.stats.fouls[by.team]++;
    const behind = by.sdx * on.fx + by.sdy * on.fy > 0.45;
    let card = null;
    if (behind) { by.yellow++; card = by.yellow >= 2 ? 'red' : 'yellow'; }
    const dirD = by.team ? -1 : 1;
    const inBox = Math.abs(on.x) < BOX_W / 2 && on.y * dirD < -HL + BOX_D;
    this.ev('foul', { by, on, card, pen: inBox });
    const ox = on.x, oy = on.y;
    if (card === 'red') { by.off = true; by.x = HW + 8; by.y = 0; by.state = 'play'; if (this.ctrl[by.team] === by) this.ctrl[by.team] = null; }
    if (inBox) this.setRestart('penalty', on.team, 0, 0); else this.setRestart('freekick', on.team, ox, oy);
  }

  give(p) {
    const b = this.ball, k = b.kick;
    b.owner = p; b.vh = 0; b.h = 0; b.ct = 0; b.shot = null; b.vx = p.vx; b.vy = p.vy;
    if (k && k.team === p.team && k.kicker !== p && k.off.includes(p)) {
      b.kick = null; this.ev('offside', { p });
      this.setRestart('freekick', 1 - p.team, p.x, p.y); return;
    }
    if (k && k.team === p.team && k.kicker !== p) this.lastPass = { from: k.kicker, to: p };
    else if (!k || k.team !== p.team) this.lastPass = null;
    b.kick = null;
    if (b.last !== p) { b.prev = b.last; b.last = p; }
    p.protect = 0.35; p.aiT = 0.12 + this.rnd() * 0.2; p.contact = 0; p.holdN = 0;
    p.dx = p.x; p.dy = p.y;
    this.ev('control', { p });
    if (p.pos === 'P' && this.inOwnBox(p) && this.phase === 'play') this.setRestart('gk', p.team, p.x, p.y, p);
  }

  contacts(dt) {
    const b = this.ball;
    if (b.owner) {
      const c = b.owner;
      if (c.protect > 0) return;
      for (const o of this.players) {
        if (o.team === c.team || o.off || o.state !== 'play' || o.stun > 0 || o.tackleCd > 0) continue;
        const d = hyp(o.x - b.x, o.y - b.y);
        if (d < 0.85 + o.st.dif * 0.0025) {
          o.contact += dt;
          const hc = this.human[c.team], ho = this.human[o.team];
          let need = 0.10 + 0.22 * c.st.dri / (c.st.dri + o.st.dif);
          if (hc && !ho) need *= 2.5 - 1.3 * this.teams[o.team].skill;
          if (ho && this.ctrl[o.team] !== o) need *= 2.4;
          if (o.contact >= need) {
            b.owner = o; b.prev = b.last; b.last = o; b.kick = null; this.lastPass = null;
            o.protect = 0.5; o.contact = 0; o.aiT = 0.25; o.dx = o.x; o.dy = o.y; o.holdN = 0;
            c.stun = 0.4; c.tackleCd = 0.8;
            this.ev('tackle', { p: o, on: c });
            if (o.pos === 'P' && this.inOwnBox(o)) this.setRestart('gk', o.team, o.x, o.y, o);
            return;
          }
        } else if (o.contact > 0) o.contact = Math.max(0, o.contact - dt * 2);
      }
      return;
    }
    if (b.kick) b.kick.age += dt;
    let best = null, bd = 9;
    for (const p of this.players) {
      if (p.off || p.state !== 'play' || p.stun > 0 || (b.noP === p && b.noT > 0)) continue;
      const gk = p.pos === 'P' && this.inOwnBox(p);
      const d = hyp(p.x - b.x, p.y - b.y);
      // palla appena calciata che si allontana: non si può toccare
      if (b.kick && b.kick.age < 0.3 && b.kick.team !== p.team && (p.x - b.x) * b.vx + (p.y - b.y) * b.vy < 0) continue;
      if (d < (gk ? 1.25 : 0.95) && b.h < (gk ? 2.35 : 1.7) && d < bd) { bd = d; best = p; }
    }
    if (!best) return;
    const p = best, sp = hyp(b.vx - p.vx, b.vy - p.vy), gk = p.pos === 'P' && this.inOwnBox(p);
    if (gk && b.shot && b.shot.team !== p.team) { this.save(p, true); return; }
    const mate = b.kick && b.kick.team === p.team;
    const fresh = b.kick && b.kick.age < 0.22 && sp > 6;
    if (!gk && !mate && ((b.shot && sp > 14) || sp > 22 + p.st.dri * 0.06 || fresh)) {
      const hard = !!b.shot;
      b.vx = -b.vx * 0.25 + (this.rnd() - .5) * 5; b.vy = -b.vy * 0.3 + (this.rnd() - .5) * 3; b.vh = 1.5 + this.rnd() * 3; b.ct = 0;
      b.prev = b.last; b.last = p; b.shot = null; b.kick = null; b.noP = p; b.noT = 0.3; this.predT = 0;
      this.ev('block', { p, hard });
      return;
    }
    this.give(p);
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
    this.phase = 'goal'; this.goalT = 3.2; this.nextKick = 1 - forT; b.owner = null; b.shot = null; b.kick = null; b.ct = 0;
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
    if (this.phase === 'play') {
      this.contacts(dt);
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

  endHalf() {
    this.resetStates(); this.ball.shot = null;
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
  userMove(T, x, y, held) { this.move[T] = { x: clamp(x, -HW - 1, HW + 1), y: clamp(y, -HL - 1, HL + 1), ttl: held ? 0.3 : 1.8, held: !!held }; }
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
  hint(T) {
    const b = this.ball;
    if (this.phase === 'restart') return this.restart.team === T ? 'restart' : 'wait';
    if (this.phase !== 'play') return '';
    if (this.diveWin(T)) return 'dive';
    if (b.owner && b.owner.team === T) return 'attack';
    if (b.owner) return 'defend';
    return 'loose';
  }
  substitute(T, idx, src) {
    const p = this.team(T)[idx]; if (!p || p.off) return false;
    p.src = src; p.name = src.name; p.st = effStats(src, p.pos); p.energy = 1; p.yellow = 0; p.look = Math.floor(this.rnd() * 1000);
    this.ev('sub', { p }); return true;
  }
}
