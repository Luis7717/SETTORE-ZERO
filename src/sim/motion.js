// Movimento dei giocatori, scivolate, tuffi, parate, falli, possesso e contatti col pallone.
// I metodi vengono copiati su Match.prototype (vedi match.js): `this` è la partita.
import { W, L, HW, HL, GW, GH, BOX_W, BOX_D, SIX_W, SIX_D, PEN_D, CIRCLE, G, ROLL, clamp, hyp, rng32, FORMATIONS, effStats, ballPhys, segInfo } from './core.js';

// Regolazioni (misurate con test/balance.mjs, test/diag-flow.mjs e i test in test/unit)
const GK_AI_SPEED = 2.6;    // velocità base del tuffo del portiere comandato dal computer (m/s)
const GK_HUMAN_SPEED = 2.4; // velocità base del tuffo quando lo comanda il giocatore (m/s)
const SHOT_BLOCK_R = 0.6;   // un tiro forte si ferma su un difensore solo se lo prende quasi in pieno (m)
const PARRY_OUT = 0.6;      // respinte non bloccate che finiscono oltre la linea di fondo
const BLOCK_OUT = 0.4;      // tiri ribattuti vicino all'area che finiscono in angolo
const TACKLE_LOOSE = 0.3;   // contrasti vinti in cui la palla schizza via invece di restare al difensore
const PASS_DEFLECT = 0.3;   // passaggi intercettati che vengono solo deviati
const SPRINT_BONUS = 0.16;  // velocità in più nello scatto a energia piena (a energia bassa rende meno)
const SPRINT_DRAIN = 3.5;   // lo scatto consuma energia questo numero di volte più in fretta della corsa
const RECOVER_V = 2.5;      // sotto questa velocità (camminata, fermo) l'energia si recupera (m/s)
const RECOVER_RATE = 0.004; // energia recuperata al secondo camminando o da fermi
const FEINT_DOT = 0.5;      // la finta vale solo se la nuova direzione si scosta da quella di corsa (coseno massimo)
const FEINT_CD = 1.2;       // tempo di ricarica della finta (s)
const FEINT_R = 3.5;        // difensori entro questa distanza dal portatore possono cascarci (m)
const FEINT_BASE = 0.5;     // probabilità di sbilanciare un difensore a pari dribbling e difesa
const FEINT_SKILL = 1.5;    // quanto pesa la differenza dribbling - difesa (per punto / 100)
const FEINT_STUN = 0.7;     // durata dello sbilanciamento del difensore (s)
const FEINT_PROTECT = 0.3;  // dopo la finta il portatore non può essere contrastato per questo tempo (s)

export class MotionMethods {
  movePlayers(dt) {
    const b = this.ball, live = this.phase === 'play';
    for (const p of this.players) {
      if (p.off) continue;
      if (p.stun > 0) p.stun -= dt;
      if (p.protect > 0) p.protect -= dt;
      if (p.tackleCd > 0) p.tackleCd -= dt;
      if (p.kickAnim > 0) p.kickAnim -= dt;
      if (p.feintCd > 0) p.feintCd -= dt;
      if (p.state === 'play') {
        let dx = p.tx - p.x, dy = p.ty - p.y; const d = hyp(dx, dy);
        const vm = this.vmax(p) * (b.owner === p ? 0.86 + p.st.dri * 0.001 : 1) * p.spdF * (p.sprint ? 1 + SPRINT_BONUS * (0.3 + 0.7 * p.energy) : 1);
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
        if (v < RECOVER_V) p.energy = Math.min(1, p.energy + RECOVER_RATE * dt);
        else p.energy = Math.max(0.2, p.energy - (v / 8) * (v / 8) * dt * 0.0022 * (1.3 - p.st.fis * 0.006) * (p.sprint ? SPRINT_DRAIN : 1));
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

  // Finta del portatore p verso (dx, dy): cambio di direzione secco; i difensori vicini che stavano entrando
  // (contatto in corso, scivolata in preparazione o in avvicinamento) possono restare sbilanciati.
  feint(p, dx, dy) {
    const n = hyp(dx, dy); if (n < 1e-6) return false;
    const ux = dx / n, uy = dy / n, v = hyp(p.vx, p.vy);
    const rx = v > 1 ? p.vx / v : p.fx, ry = v > 1 ? p.vy / v : p.fy;
    if (ux * rx + uy * ry > FEINT_DOT) return false;
    const sp = this.vmax(p) * 0.8;
    p.feintCd = FEINT_CD; p.vx = ux * sp; p.vy = uy * sp; p.fx = ux; p.fy = uy;
    p.dx = p.tx = p.x + ux * 8; p.dy = p.ty = p.y + uy * 8; p.protect = Math.max(p.protect, FEINT_PROTECT);
    const fooled = [];
    for (const o of this.players) {
      if (o.team === p.team || o.off || o.stun > 0 || (o.state !== 'play' && o.state !== 'prep')) continue;
      const ox = o.x - p.x, oy = o.y - p.y, d = hyp(ox, oy);
      if (d > FEINT_R) continue;
      const closing = -(o.vx * ox + o.vy * oy) / (d || 1);
      if (!(o.contact > 0 || o.state === 'prep' || closing > 1)) continue;
      const chance = clamp(FEINT_BASE + FEINT_SKILL * (p.st.dri - o.st.dif) / 100, 0.15, 0.85);
      if (this.rnd() < chance) {
        o.stun = FEINT_STUN; o.contact = 0; o.vx *= 0.3; o.vy *= 0.3;
        if (o.state === 'prep') { o.state = 'play'; o.warn = false; }
        fooled.push(o);
      }
    }
    this.ev('feint', { p, fooled });
    return true;
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
    const b = this.ball, d = p.dive, vs = Math.min(hm ? GK_HUMAN_SPEED + p.st.por * 0.03 : GK_AI_SPEED + p.st.por * 0.025, (hm ? 30 : 22) * (p.t + dt));
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
    if (this.rnd() < PARRY_OUT) { this.deflectBehind(p); this.ev('save', { p, catch: false, out: true }); return; }
    const sx = p.dive ? p.dive.dirx : (b.x >= p.x ? 1 : -1);
    b.vx = sx * (5 + this.rnd() * 3); b.vy = -b.vy * 0.15; b.vh = 2 + this.rnd() * 2; b.ct = 0;
    if (b.last !== p) { b.prev = b.last; b.last = p; } b.kick = null; b.shot = null; b.noP = p; b.noT = 0.4; this.predT = 0;
    this.ev('save', { p, catch: false });
  }

  // Manda il pallone oltre la linea di fondo difesa dalla squadra di p, fuori dai pali
  // (o sopra la traversa se è già alto): ne nasce un calcio d'angolo, mai un gol.
  deflectBehind(p) {
    const b = this.ball, out = p.team ? 1 : -1, by = out * HL;
    const dist = Math.max(0.3, Math.abs(by - b.y)), t = Math.max(0.3, dist / (3 + this.rnd() * 3)), vy = out * dist / t;
    const sx = Math.abs(b.x) > 0.3 ? Math.sign(b.x) : (this.rnd() < 0.5 ? -1 : 1);
    const vx = (sx * (GW / 2 + 0.9 + this.rnd() * 3) - b.x) / t;
    b.vy = vy; b.ct = 0;
    if (b.h > 1.5 || Math.abs(vx) > 18) { b.vx = (this.rnd() - 0.5) * 3; b.vh = (GH + 0.8 - b.h + 0.5 * G * t * t) / t; }
    else { b.vx = vx; b.vh = 0.5 * G * t + 0.4 + this.rnd(); }
    b.h = Math.max(b.h, 0.05);
    if (b.last !== p) { b.prev = b.last; b.last = p; } b.kick = null; b.shot = null; b.noP = p; b.noT = 0.4; this.predT = 0;
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
          if (o.contact >= need && this.rnd() < TACKLE_LOOSE) {
            o.contact = 0; o.tackleCd = 0.5; c.stun = 0.3; c.tackleCd = 0.6;
            const side = Math.abs(b.x) > HW - 12 ? Math.sign(b.x) : (this.rnd() < 0.5 ? -1 : 1);
            const ang = Math.atan2(b.y - o.y, b.x - o.x) + (this.rnd() - 0.5) * 1.6, sp = 5 + this.rnd() * 4;
            b.owner = null; b.vx = Math.cos(ang) * sp * 0.6 + side * (4 + this.rnd() * 5); b.vy = Math.sin(ang) * sp; b.vh = 1 + this.rnd() * 1.5; b.h = 0.05; b.ct = 0;
            b.prev = b.last; b.last = o; b.kick = null; b.shot = null; b.noP = c; b.noT = 0.3; this.lastPass = null; this.predT = 0;
            this.ev('tackle', { p: o, on: c, loose: true });
            return;
          }
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
      if (d < (gk ? 1.25 : (b.kick && b.kick.type === 'shot' && b.kick.team !== p.team ? SHOT_BLOCK_R : 0.95)) && b.h < (gk ? 2.35 : 1.7) && d < bd) { bd = d; best = p; }
    }
    if (!best) return;
    const p = best, sp = hyp(b.vx - p.vx, b.vy - p.vy), gk = p.pos === 'P' && this.inOwnBox(p);
    if (gk && b.shot && b.shot.team !== p.team) { this.save(p, true); return; }
    const mate = b.kick && b.kick.team === p.team;
    const fresh = b.kick && b.kick.age < 0.22 && sp > 6;
    if (!gk && !mate && ((b.shot && sp > 14) || sp > 22 + p.st.dri * 0.06 || fresh)) {
      const hard = !!b.shot;
      if (hard && !mate && Math.abs(b.y) > HL - BOX_D - 4 && this.rnd() < BLOCK_OUT) {
        this.deflectBehind(p); b.vh = Math.max(b.vh, 1.5); this.ev('block', { p, hard, out: true }); return;
      }
      b.vx = -b.vx * 0.25 + (this.rnd() - .5) * 5; b.vy = -b.vy * 0.3 + (this.rnd() - .5) * 3; b.vh = 1.5 + this.rnd() * 3; b.ct = 0;
      b.prev = b.last; b.last = p; b.shot = null; b.kick = null; b.noP = p; b.noT = 0.3; this.predT = 0;
      this.ev('block', { p, hard });
      return;
    }
    // passaggio intercettato: a volte il difensore riesce solo a deviarlo
    if (!gk && !mate && b.kick && b.kick.type !== 'shot' && sp > 8 && this.rnd() < PASS_DEFLECT) {
      const a = Math.atan2(b.vy, b.vx) + (this.rnd() < 0.5 ? -1 : 1) * (0.5 + this.rnd() * 0.9), v = hyp(b.vx, b.vy) * (0.45 + this.rnd() * 0.25);
      b.vx = Math.cos(a) * v; b.vy = Math.sin(a) * v; b.vh = 0.5 + this.rnd() * 2; b.h = Math.max(b.h, 0.05); b.ct = 0;
      b.prev = b.last; b.last = p; b.shot = null; b.kick = null; b.noP = p; b.noT = 0.3; this.lastPass = null; this.predT = 0;
      this.ev('block', { p, hard: false, deflect: true });
      return;
    }
    this.give(p);
  }
}
