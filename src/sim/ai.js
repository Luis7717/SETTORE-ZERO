// IA: tiro, passaggi, portatore, rimesse, posizioni in attacco e difesa, portiere.
// I metodi vengono copiati su Match.prototype (vedi match.js): `this` è la partita.
import { W, L, HW, HL, GW, GH, BOX_W, BOX_D, SIX_W, SIX_D, PEN_D, CIRCLE, G, ROLL, clamp, hyp, rng32, FORMATIONS, effStats, ballPhys, segInfo } from './core.js';

export class AIMethods {
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
}
