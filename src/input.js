// Comandi a un dito. Traduce i tocchi in ordini per la squadra `team`.
import { HW, HL, GW, GH, SPRINT_DIST } from './sim.js';

const NO_OFFSIDE = ['throw', 'goalkick', 'corner']; // ripartenze senza fuorigioco
const PASS_SNAP = 5; // la linea che finisce entro tanti metri da un compagno è un passaggio a lui (m)

export class Input {
  // out: { kick(spec), move(x,y,held,sprint), stop(), dive(dx,th), sw(playerIndex), path(pts), run(playerIndex, pts) }
  // (se `move` ignora `sprint` il motore lo ricalcola uguale)
  constructor(el, view, out) {
    this.el = el; this.view = view; this.out = out; this.match = null; this.team = 0; this.enabled = false;
    this.mode = null; this.pts = []; this.sx = 0; this.sy = 0; this.x = 0; this.y = 0; this.t0 = 0; this.id = null;
    this.drawing = false; this.onTap = null;
    el.addEventListener('pointerdown', e => this.down(e));
    el.addEventListener('pointermove', e => this.moveEv(e));
    el.addEventListener('pointerup', e => this.up(e));
    el.addEventListener('pointercancel', e => this.cancel(e));
  }
  set(match, team) { this.match = match; this.team = team; this.cancel(); }
  cancel() { this.mode = null; this.id = null; this.drawing = false; this.pts = []; this.view.clearPath(); }

  pos(e) { const r = this.el.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; }

  down(e) {
    const m = this.match; if (!m || !this.enabled || this.id !== null) return;
    e.preventDefault();
    const [x, y] = this.pos(e); this.id = e.pointerId; this.sx = this.x = x; this.sy = this.y = y; this.t0 = performance.now(); this.moved = 0;
    try { this.el.setPointerCapture(e.pointerId); } catch (_) { }
    const T = this.team, b = m.ball, c = m.ctrl[T], hint = m.hint(T);
    if (hint === 'dive') { this.mode = 'dive'; return; }
    if (c && b.owner === c && (hint === 'attack' || hint === 'restart')) {
      const sp = this.view.worldToScreen(b.x, b.y, 0.3), sc = this.view.worldToScreen(c.x, c.y, 1);
      const R = Math.max(64, this.view.h * 0.085);
      if (Math.hypot(x - sp.x, y - sp.y) < R || Math.hypot(x - sc.x, y - sc.y) < R || hint === 'restart' && !this.nearMate(x, y)) {
        this.mode = 'draw'; this.drawing = true; this.pts = [{ x: b.x, y: b.y, h: 0, sx: x, sy: y }];
        return;
      }
    }
    // difesa: dito su un proprio giocatore = linea da fargli seguire (tutti tranne il portiere)
    if (hint === 'defend' || hint === 'loose') {
      const r = this.nearOwn(x, y);
      if (r) { this.mode = 'dpath'; this.runner = r; this.pts = [{ x: r.x, y: r.y, h: 0, sx: x, sy: y }]; return; }
    }
    this.mode = 'move';
  }

  // proprio giocatore (non portiere, compreso quello controllato) sotto il dito
  nearOwn(x, y) {
    const m = this.match, T = this.team; let best = null, bd = Math.max(50, this.view.h * 0.065);
    for (const p of m.players) {
      if (p.team !== T || p.off || p.pos === 'P') continue;
      const s = this.view.worldToScreen(p.x, p.y, 0.9), d = Math.hypot(x - s.x, y - s.y);
      if (d < bd) { bd = d; best = p; }
    }
    return best;
  }

  nearMate(x, y) {
    const m = this.match, T = this.team; let best = null, bd = Math.max(46, this.view.h * 0.06);
    for (const p of m.players) {
      if (p.team !== T || p.off || p === m.ctrl[T]) continue;
      const s = this.view.worldToScreen(p.x, p.y, 0.9); const d = Math.hypot(x - s.x, y - s.y);
      if (d < bd) { bd = d; best = p; }
    }
    return best;
  }

  goalY() { return this.team === 0 ? HL : -HL; }
  // passaggio permesso in un duello col difensore, nell'area di tiro (ultimi 20 m) o su una rimessa
  canPass() { const m = this.match; return m.phase === 'restart' || !!(m.passFor && m.passFor(this.team)); }
  // compagno (chiunque, tranne il portatore) vicino a un punto del campo
  mateAt(x, y, R = PASS_SNAP) {
    const m = this.match; let best = null, bd = R;
    for (const p of m.players) if (p.team === this.team && !p.off && p !== m.ctrl[this.team]) { const d = Math.hypot(p.x - x, p.y - y); if (d < bd) { bd = d; best = p; } }
    return best;
  }
  // la linea è una strada da correre? No se finisce in porta, se si è in duello o rimessa (ogni linea è un passaggio),
  // e nell'area di tiro se finisce su un compagno (altrimenti si corre lì)
  runPath() {
    const m = this.match, e = this.pts[this.pts.length - 1];
    if (!e || e.goal) return false;
    if (m.phase === 'restart' || (m.duelFor && m.duelFor(this.team))) return false;
    if (m.inZone && m.inZone(this.team)) return !this.mateAt(e.x, e.y);
    return true;
  }

  // punto del campo (o della porta) sotto il dito
  pick(x, y) {
    const gy = this.goalY(), v = this.view;
    const g = v.screenToGround(x, y), q = v.screenToGoal(x, y, gy);
    const beyond = !g || Math.abs(g.y) > HL && Math.sign(g.y) === Math.sign(gy);
    if (q && beyond && q.h >= 0 && q.h < GH + 2.2 && Math.abs(q.x) < GW / 2 + 3.5) return { x: q.x, y: gy, h: Math.max(0.15, q.h), goal: true };
    if (!g) return null;
    return { x: Math.max(-HW - 2, Math.min(HW + 2, g.x)), y: Math.max(-HL - 2, Math.min(HL + 2, g.y)), h: 0 };
  }

  moveEv(e) {
    if (e.pointerId !== this.id) return;
    const [x, y] = this.pos(e); this.moved += Math.hypot(x - this.x, y - this.y); this.x = x; this.y = y;
    if (this.mode === 'draw') {
      const last = this.pts[this.pts.length - 1];
      if (Math.hypot(x - last.sx, y - last.sy) >= 5) {
        const p = this.pick(x, y);
        if (p) { p.sx = x; p.sy = y; this.pts.push(p); if (this.pts.length > 150) this.pts.splice(1, 1); }
        this.showPath();
      }
    } else if (this.mode === 'dpath') {
      const last = this.pts[this.pts.length - 1];
      if (Math.hypot(x - last.sx, y - last.sy) >= 5) {
        const g = this.view.screenToGround(x, y);
        if (g) { this.pts.push({ x: g.x, y: g.y, h: 0, sx: x, sy: y }); if (this.pts.length > 150) this.pts.splice(1, 1); }
        if (this.pts.length >= 2) this.view.setPath(this.pts, false, null);
      }
    } else if (this.mode === 'dive') {
      // linea dal portiere verso il punto della porta dove tuffarsi: il tuffo parte quando si alza il dito
      const t = this.diveTarget(), g = this.match.gk(this.team);
      if (t) this.view.setPath([{ x: g.x, y: g.y, h: 0 }, { x: t.x, y: this.ownGoalY(), h: t.h }], true, null);
    }
  }

  showPath() {
    const m = this.match, b = m.ball, pts = this.pts;
    if (pts.length < 2) return;
    pts[0].x = b.x; pts[0].y = b.y;
    const e = pts[pts.length - 1];
    let recv = null;
    if (this.runPath()) { this.view.setPath(pts, false, null); this.view.setPreview([], null); return; } // strada da correre
    if (!e.goal) recv = this.mateAt(e.x, e.y);
    this.view.setPath(pts, e.goal, recv);
    // anteprima del volo vero e linea del fuorigioco (non vale su rimessa, rinvio e angolo)
    const c = m.ctrl[this.team];
    if (!c || b.owner !== c) return;
    const free = m.phase === 'restart' && NO_OFFSIDE.includes(m.restart.type);
    this.view.setPreview(m.predictKick(c, this.spec()), free ? null : m.offsideY(this.team));
  }

  spec() {
    const m = this.match, b = m.ball, pts = this.pts, e = pts[pts.length - 1], gy = this.goalY();
    const sx = b.x, sy = b.y; let tx = e.x, ty = e.y, type = 'auto', th = 0;
    if (e.goal) { type = 'shot'; th = e.h; ty = gy; }
    const dx = tx - sx, dy = ty - sy, D = Math.hypot(dx, dy) || 1, nx = -dy / D, ny = dx / D;
    let curve = 0;
    for (const p of pts) { if (p.goal) continue; const d = (p.x - sx) * nx + (p.y - sy) * ny; if (Math.abs(d) > Math.abs(curve)) curve = d; }
    return { type, tx, ty, th, curve };
  }

  ownGoalY() { return -this.goalY(); }
  // punto della propria porta sotto il dito (la telecamera è dietro la porta mentre si para)
  diveTarget() {
    const q = this.view.screenToGoal(this.x, this.y, this.ownGoalY());
    if (!q) return null;
    return { x: Math.max(-GW / 2 - 1.5, Math.min(GW / 2 + 1.5, q.x)), h: Math.max(0.2, Math.min(GH + 0.4, q.h)) };
  }
  doDive() {
    this.view.clearPath();
    const t = this.diveTarget(), g = this.match.gk(this.team);
    if (t) { this.out.dive(t.x - g.x, t.h); return; }
    // riserva: gesto senza punto in porta (vecchio comando: verso e lunghezza dello scorrimento)
    const dx = this.x - this.sx, dy = this.y - this.sy, w = this.view.w * 0.36, s = this.view.flip;
    this.out.dive(s * Math.max(-1, Math.min(1, dx / w)) * 3.7, Math.max(0.2, Math.min(2.5, 1.0 - (dy / w) * 1.5)));
  }

  up(e) {
    if (e.pointerId !== this.id) return;
    const m = this.match, T = this.team; this.id = null;
    const dt = performance.now() - this.t0, dist = Math.hypot(this.x - this.sx, this.y - this.sy), mode = this.mode;
    this.mode = null;
    if (!m) return;
    if (mode === 'draw') {
      this.drawing = false;
      let len = 0; for (let i = 1; i < this.pts.length; i++) len += Math.hypot(this.pts[i].sx - this.pts[i - 1].sx, this.pts[i].sy - this.pts[i - 1].sy);
      if (this.pts.length >= 2 && len > 28) {
        if (this.runPath()) this.out.path(this.pts.slice(1).map(q => ({ x: q.x, y: q.y })));
        else this.out.kick(this.spec());
      }
      this.pts = []; this.view.clearPath();
      return;
    }
    if (mode === 'dive') { if (dist > 22) this.doDive(); else this.view.clearPath(); return; }
    if (mode === 'dpath') {
      const r = this.runner, pts = this.pts; this.runner = null; this.pts = []; this.view.clearPath();
      let len = 0; for (let i = 1; i < pts.length; i++) len += Math.hypot(pts[i].sx - pts[i - 1].sx, pts[i].sy - pts[i - 1].sy);
      if (pts.length >= 2 && len > 28) { this.out.run(r.i, pts.slice(1).map(q => ({ x: q.x, y: q.y }))); return; }
      if (dist < 16 && r !== m.ctrl[T]) this.out.sw(r.i); // tocco = passa a comandare quel giocatore
      return;
    }
    if (mode !== 'move') return;
    const hint = m.hint(T);
    if (dist < 16 && dt < 320) {
      const mate = this.nearMate(this.x, this.y);
      if (mate) {
        if ((hint === 'attack' || hint === 'restart') && this.canPass()) this.out.kick({ type: 'auto', tx: mate.x + mate.vx * 0.45, ty: mate.y + mate.vy * 0.45, curve: 0 });
        else if (hint === 'attack' || hint === 'restart') { /* fuori da duello e area di tiro niente passaggio diretto */ }
        else this.out.sw(mate.i);
      } else { const g = this.view.screenToGround(this.x, this.y); if (g) this.out.move(g.x, g.y, false); }
      return;
    }
    this.out.stop();
  }

  // chiamata a ogni fotogramma: tenendo premuto il giocatore segue il dito
  update() {
    if (this.mode === 'move' && this.id !== null && (performance.now() - this.t0 > 110 || this.moved > 12)) {
      const g = this.view.screenToGround(this.x, this.y);
      if (g) {
        // dito lontano dal giocatore controllato = scatto; vicino = corsa normale
        const c = this.match && this.match.ctrl[this.team];
        this.out.move(g.x, g.y, true, !!(c && Math.hypot(g.x - c.x, g.y - c.y) > SPRINT_DIST));
      }
    }
    if (this.mode === 'draw') {
      const m = this.match, c = m && m.ctrl[this.team];
      if (!m || !c || m.ball.owner !== c) { this.cancel(); return; }
      this.showPath();
    }
    if (this.mode === 'dive' && this.match && !this.match.diveWin(this.team)) this.mode = 'move';
  }
}
