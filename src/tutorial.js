// Allenamento guidato: cinque prove in campo (passaggio, tiro, corsa, recupero palla, parata).
// Usa una partita vera e la prepara a ogni prova; avanza quando il motore segnala l'evento giusto.
// Non tocca il motore: sposta solo giocatori e pallone come fanno i test.

const STEP_TIMEOUT = 16;  // secondi prima di rimettere a posto la prova
const DONE_PAUSE = 1.4;   // secondi di "Bravo!" prima della prova successiva
const FREEZE = 0.2;       // stordimento rinnovato a ogni fotogramma per tenere fermi i giocatori fuori dalla prova

export const STEPS = [
  {
    title: 'Passaggio',
    text: 'Appoggia il dito sul tuo giocatore e <b>disegna una linea</b> fino al compagno libero.',
    setup(m, T) { const c = T.carrier(m, 7, 0, 0); T.put(m, m.players[9], 7, 14); T.clearOpp(m); return { c }; },
    check(e, m, st) { return e.type === 'control' && e.p.team === 0 && e.p !== st.c; },
    freeze: 'opp',
  },
  {
    title: 'Tiro',
    text: 'Disegna una linea che <b>finisce dentro la porta</b>. Curvala per tirare a giro.',
    setup(m, T) { const c = T.carrier(m, 9, 5, 29); T.clearOpp(m); return { c }; },
    check(e) { return e.type === 'kick' && e.p.team === 0 && e.kind === 'shot'; },
    freeze: 'opp-but-gk',
  },
  {
    title: 'Corsa',
    text: '<b>Tieni premuto</b> un punto più avanti sul campo: il tuo giocatore ci corre col pallone.',
    setup(m, T) { const c = T.carrier(m, 7, 0, -12); T.clearOpp(m); return { c, y0: c.y }; },
    poll(m, st) { return m.ball.owner === st.c && st.c.y - st.y0 > 12; },
    freeze: 'opp',
  },
  {
    title: 'Recupera palla',
    text: 'Senza palla <b>tieni premuto</b> per andare addosso all\'avversario, o <b>scorri veloce</b> verso di lui per la scivolata.',
    setup(m, T) {
      const o = m.players[20]; T.put(m, o, 0, 6); o.fx = 0; o.fy = -1; m.ball.owner = o; m.ball.kick = null; m.att = 1;
      const me = m.players[7]; T.put(m, me, 1, -2); m.ctrl[0] = me;
      return { o };
    },
    check(e) { return e.type === 'tackle' && e.p.team === 0; },
    poll(m) { return !!(m.ball.owner && m.ball.owner.team === 0); },
    freeze: 'all-but-duel',
  },
  {
    title: 'Parata',
    text: 'Quando l\'avversario tira il tempo rallenta: <b>scorri verso il lato del tiro</b> per tuffarti.',
    setup(m, T) {
      const o = m.players[20]; T.put(m, o, 4, -31); o.fx = 0; o.fy = -1; m.ball.owner = o; m.ball.kick = null; m.att = 1; o.aiT = 0.6;
      T.put(m, m.gk(0), 0, -49);
      return { o };
    },
    check(e, m) { return (e.type === 'dive' || e.type === 'save') && e.p.team === 0 && (e.type === 'save' || !m.autoGk[0]); },
    freeze: 'all-but-shooter',
  },
];

export class Tutorial {
  constructor(m, onText) {
    this.m = m; this.onText = onText; this.i = -1; this.t = 0; this.done = 0; this.st = null; this.finished = false;
    this.next();
  }

  // ------------------------------------------------ aiuti per preparare le prove
  put(m, p, x, y) { m.place(p, x, y); p.fx = 0; p.fy = 1; }
  carrier(m, idx, x, y) {
    const c = m.players[idx]; this.put(m, c, x, y);
    const b = m.ball; b.owner = c; b.kick = null; b.shot = null; b.h = 0; b.vx = b.vy = b.vh = 0; m.ctrl[0] = c; m.att = 0; c.protect = 1;
    return c;
  }
  // avversari lontani dall'azione (portiere al suo posto)
  clearOpp(m) {
    let k = 0;
    for (const p of m.team(1)) { if (p.pos === 'P') { this.put(m, p, 0, 49); continue; } this.put(m, p, -26 + (k % 5) * 13, 41 - Math.floor(k / 5) * 3); k++; }
  }

  // ------------------------------------------------ svolgimento
  next() {
    this.i++; this.t = 0; this.done = 0;
    if (this.i >= STEPS.length) { this.finished = true; this.onText(null, 'Allenamento finito! Ora sei pronto per il campionato.', STEPS.length, STEPS.length); return; }
    this.reset();
  }
  reset() {
    const m = this.m, s = STEPS[this.i];
    m.phase = 'play'; m.restart = null; m.move = [null, null]; m.lastPass = null; m.resetStates();
    for (const p of m.players) if (!p.off) { p.vx = p.vy = 0; p.stun = 0; }
    m.place(m.gk(0), 0, -49); m.place(m.gk(1), 0, 49);
    for (const p of m.team(0)) if (p.pos !== 'P' && p.i !== 7 && p.i !== 9) { const [ax, ay] = m.anchor(p); this.put(m, p, ax, Math.min(ay, -5)); }
    this.st = s.setup(m, this) || {};
    m.events.length = 0;
    this.onText(s.title, s.text, this.i, STEPS.length);
  }
  frozen(p) {
    const f = STEPS[this.i].freeze, st = this.st;
    if (f === 'opp') return p.team === 1;
    if (f === 'opp-but-gk') return p.team === 1 && p.pos !== 'P';
    if (f === 'all-but-duel') return p !== st.o && p !== this.m.ctrl[0];
    if (f === 'all-but-shooter') return p !== st.o && p.pos !== 'P';
    return false;
  }
  // da chiamare prima di m.step: tiene fermi i giocatori fuori dalla prova
  before() {
    if (this.finished || this.i < 0) return;
    for (const p of this.m.players) if (!p.off && this.frozen(p)) p.stun = Math.max(p.stun, FREEZE);
  }
  // da chiamare dopo m.step, prima che main.js consumi m.events
  after(dt) {
    if (this.finished) return;
    const m = this.m, s = STEPS[this.i];
    if (this.done) { this.done -= dt; if (this.done <= 0) this.next(); return; }
    this.t += dt;
    let ok = false;
    for (const e of m.events) if (s.check && s.check(e, m, this.st)) ok = true;
    if (!ok && s.poll && s.poll(m, this.st)) ok = true;
    if (ok) { this.done = DONE_PAUSE; this.onText(s.title, 'Bravo!', this.i + 1, STEPS.length, true); return; }
    // pallone uscito, gol o tempo scaduto: si rimette a posto la stessa prova
    if (m.phase !== 'play' || this.t > STEP_TIMEOUT) this.reset();
  }
}
