// Movimento dei giocatori, scivolate, tuffi, parate, falli, possesso e contatti col pallone.
// I metodi vengono copiati su Match.prototype (vedi match.js): `this` è la partita.
import { W, L, HW, HL, GW, GH, BOX_W, BOX_D, SIX_W, SIX_D, PEN_D, CIRCLE, G, ROLL, clamp, hyp, rng32, FORMATIONS, effStats, ballPhys, segInfo } from './core.js';

export class MotionMethods {
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
}
