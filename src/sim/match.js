// La partita: stato, rimesse, calci, pallone, uscite, gol, tempo e comandi umani.
import { W, L, HW, HL, GW, GH, BOX_W, BOX_D, SIX_W, SIX_D, PEN_D, CIRCLE, G, ROLL, clamp, hyp, rng32, FORMATIONS, effStats, ballPhys, segInfo } from './core.js';
import { AIMethods } from './ai.js';
import { MotionMethods } from './motion.js';

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

// i metodi di IA e movimento vivono in file separati ma fanno parte di Match
for (const C of [AIMethods, MotionMethods]) {
  for (const k of Object.getOwnPropertyNames(C.prototype)) if (k !== 'constructor') Object.defineProperty(Match.prototype, k, Object.getOwnPropertyDescriptor(C.prototype, k));
}
