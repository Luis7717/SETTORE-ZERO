// Allenamento guidato: per ogni meccanica una scheda di spiegazione, poi la si prova subito
// in campo 3 volte, in 3 situazioni diverse. Usa una partita vera e la prepara a ogni prova;
// avanza quando il motore segnala l'evento giusto. Non tocca il motore: sposta solo giocatori
// e pallone come fanno i test.

const STEP_TIMEOUT = 16;  // secondi prima di rimettere a posto la prova
const DONE_PAUSE = 1.3;   // secondi di "Bravo!" prima della prova successiva
const FREEZE = 0.2;       // stordimento rinnovato a ogni fotogramma per tenere fermi i giocatori fuori dalla prova
export const REPS = 3;    // prove per ogni meccanica

// Ogni lezione: testo della scheda, 3 situazioni (setup con indice k), come si riconosce la riuscita,
// chi resta fermo. `needs`: metodo del motore senza il quale la lezione si salta.
const PASS_DEF_DIST = 11; // lezione Passaggio: distanza iniziale del difensore davanti al portatore (m)

export const LESSONS = [
  {
    title: 'Passaggio',
    short: 'Corri verso il difensore; quando il tempo rallenta disegna dalla palla fino a un compagno.',
    text: 'Si passa quando ti avvicini a un difensore (la visuale si abbassa e il tempo rallenta) e negli ultimi 20 metri prima della porta. Allora <b>disegna dalla palla fino a un compagno</b>, chiunque sia: il passaggio si disegna sempre, toccare il compagno non basta. I puntini azzurri mostrano dove andrà davvero la palla.',
    setup(m, T, k) {
      const c = T.carrier(m, 7, [0, -6, 4][k], [0, -4, 6][k]); T.clearOpp(m);
      // difensore a una decina di metri: prima ci si avvicina, poi parte il duello (DUEL_R = 7 m)
      const o = m.players[16]; T.put(m, o, c.x + [0, 1.5, -1.5][k], c.y + PASS_DEF_DIST); o.fx = 0; o.fy = -1;
      const mate = [[9, 18], [-22, 10], [17, 6]][k]; T.put(m, m.players[9], mate[0], mate[1]); return { c, o };
    },
    check(e, m, st) { return e.type === 'control' && e.p.team === 0 && e.p !== st.c; },
    freeze: 'opp-but-o',
  },
  {
    title: 'Tiro',
    short: 'Disegna una linea che finisce in porta.',
    text: 'Disegna una linea che <b>finisce dentro la porta</b>: più in alto la finisci, più alto va il tiro. <b>Curvala</b> per tirare a giro attorno al portiere.',
    setup(m, T, k) { const p = [[5, 29], [-12, 33], [2, 22]][k]; const c = T.carrier(m, 9, p[0], p[1]); T.clearOpp(m); return { c }; },
    check(e) { return e.type === 'kick' && e.p.team === 0 && e.kind === 'shot'; },
    freeze: 'opp-but-gk',
  },
  {
    title: 'Corsa e scatto',
    text: 'Col pallone, <b>disegna la strada</b> partendo dal tuo giocatore: lui la segue. Con tanta strada davanti <b>scatta</b> (ma si stanca prima). Se la linea finisce dentro la porta è un tiro.',
    setup(m, T, k) { const c = T.carrier(m, 7, [0, -10, 8][k], [-14, -6, -20][k]); T.clearOpp(m); return { c, x0: c.x, y0: c.y, k }; },
    poll(m, st) {
      const c = st.c; if (m.ball.owner !== c) return false;
      if (st.k === 0) return c.y - st.y0 > 12;                 // avanti
      if (st.k === 1) return Math.abs(c.x - st.x0) > 10;      // verso la fascia
      return !!c.sprint && Math.hypot(c.x - st.x0, c.y - st.y0) > 12; // scatto
    },
    hint: ['Disegna una strada in avanti di una decina di metri.', 'Ora disegna una strada che curva verso una fascia.', 'Ora una strada lunga: il giocatore <b>scatta</b>.'],
    freeze: 'opp',
  },
  {
    title: 'Recupera palla',
    short: "Disegna una linea dal tuo giocatore fino all'avversario.",
    text: "In difesa <b>disegna una linea dai tuoi giocatori</b> (tutti tranne il portiere): corrono lungo la strada che tracci. Mandali addosso all'avversario o sulla linea del passaggio per intercettarlo: ogni difensore prende la palla dentro un piccolo raggio, più largo se è bravo in difesa e più stretto se chi passa è bravo nei passaggi.",
    setup(m, T, k) {
      const o = m.players[20]; T.put(m, o, [0, -14, 12][k], [6, 10, 2][k]); o.fx = 0; o.fy = -1; m.ball.owner = o; m.ball.kick = null; m.att = 1;
      const me = m.players[7]; T.put(m, me, o.x + 1, o.y - 8); m.ctrl[0] = me;
      return { o };
    },
    check(e) { return e.type === 'tackle' && e.p.team === 0; },
    poll(m) { return !!(m.ball.owner && m.ball.owner.team === 0); },
    // l'avversario resta fermo col pallone (prima lo perdeva da solo passando a vuoto); i tuoi si muovono solo con la linea
    freeze: 'opp', noAutoDef: true,
  },
  {
    title: 'Dribbling',
    short: 'Avvicinati al difensore e tocca Dribbling.',
    text: 'Quando arrivi addosso a un difensore la visuale si abbassa e il tempo rallenta: puoi <b>passare</b> a un compagno libero oppure toccare <b>Dribbling</b> in basso per saltarlo.',
    needs: 'userDribble',
    setup(m, T, k) {
      const c = T.carrier(m, 7, [0, -10, 10][k], [-6, 0, -2][k]); T.clearOpp(m);
      const o = m.players[16]; T.put(m, o, c.x + [0, 1, -1][k], c.y + 7); o.fx = 0; o.fy = -1;
      T.put(m, m.players[9], c.x + [12, 14, -14][k], c.y + 4);
      return { c, o };
    },
    check(e) { return e.type === 'dribble' && e.p.team === 0 && e.ok; },
    freeze: 'opp-but-o',
  },
  {
    title: 'Portiere',
    short: 'Quando tira, linea dal portiere al punto della porta.',
    text: 'Quando l\'avversario tira la visuale va dietro la tua porta e il tempo rallenta. <b>Tira una linea dal portiere al punto della porta</b> dove arriva la palla e alza il dito al momento giusto: troppo presto o troppo lontano e non ci arriva.',
    setup(m, T, k) {
      const o = m.players[20]; T.put(m, o, [4, -12, 10][k], [-31, -34, -28][k]); o.fx = 0; o.fy = -1; m.ball.owner = o; m.ball.kick = null; m.att = 1; o.aiT = 0.6;
      T.put(m, m.gk(0), 0, -49);
      return { o };
    },
    check(e, m) { return (e.type === 'dive' || e.type === 'save') && e.p.team === 0 && (e.type === 'save' || !m.autoGk[0]); },
    freeze: 'all-but-shooter',
  },
];

export class Tutorial {
  // ui: { text(title, html, rep, reps, good), card(lesson, index, total) | card(null) a fine allenamento }
  constructor(m, ui) {
    this.m = m; this.ui = ui;
    this.lessons = LESSONS.filter(l => !l.needs || typeof m[l.needs] === 'function');
    this.li = -1; this.k = 0; this.t = 0; this.done = 0; this.st = null; this.card = false; this.finished = false;
    this.nextLesson();
  }
  get lesson() { return this.lessons[this.li]; }

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
  nextLesson() {
    this.li++; this.k = 0;
    if (this.li >= this.lessons.length) { this.finished = true; this.card = false; this.ui.card(null); return; }
    this.card = true; this.ui.card(this.lesson, this.li, this.lessons.length);
  }
  // la scheda è stata chiusa: si comincia a provare
  go() { if (!this.card) return; this.card = false; this.reset(); }
  reset() {
    const m = this.m, L = this.lesson;
    this.t = 0; this.done = 0;
    m.phase = 'play'; m.restart = null; m.move = [null, null]; m.runs = [[], []]; m.lastPass = null; m.resetStates();
    m.autoDef = [!L.noAutoDef, true]; // in "Recupera palla" la CPU non difende: si impara a disegnare la linea
    // in allenamento niente espulsioni né stanchezza: ogni prova riparte con tutti in campo
    for (const p of m.players) { p.off = false; p.yellow = 0; p.energy = 1; p.vx = p.vy = 0; p.stun = 0; }
    m.ctrl[0] = null;
    m.place(m.gk(0), 0, -49); m.place(m.gk(1), 0, 49);
    for (const p of m.team(0)) if (p.pos !== 'P' && p.i !== 7 && p.i !== 9) { const [ax, ay] = m.anchor(p); this.put(m, p, ax, Math.min(ay, -5)); }
    this.st = L.setup(m, this, this.k) || {};
    m.events.length = 0;
    this.ui.text(L.title, L.hint ? L.hint[this.k] : L.short, this.k, REPS);
  }
  frozen(p) {
    const f = this.lesson.freeze, st = this.st;
    if (f === 'opp') return p.team === 1;
    if (f === 'opp-but-gk') return p.team === 1 && p.pos !== 'P';
    if (f === 'opp-but-o') return p.team === 1 && p !== st.o;
    if (f === 'all-but-duel') return p !== st.o && p !== this.m.ctrl[0];
    if (f === 'all-but-shooter') return p !== st.o && p.pos !== 'P';
    return false;
  }
  // da chiamare prima di m.step: tiene fermi i giocatori fuori dalla prova
  before() {
    if (this.finished || this.card) return;
    for (const p of this.m.players) if (!p.off && this.frozen(p)) p.stun = Math.max(p.stun, FREEZE);
  }
  // da chiamare dopo m.step, prima che main.js consumi m.events
  after(dt) {
    if (this.finished || this.card) return;
    const m = this.m, L = this.lesson;
    if (this.done) {
      this.done -= dt;
      if (this.done <= 0) { this.k++; if (this.k >= REPS) this.nextLesson(); else this.reset(); }
      return;
    }
    this.t += dt;
    let ok = false;
    for (const e of m.events) if (L.check && L.check(e, m, this.st)) ok = true;
    if (!ok && L.poll && L.poll(m, this.st)) ok = true;
    if (ok) { this.done = DONE_PAUSE; this.ui.text(L.title, 'Bravo!', this.k + 1, REPS, true); return; }
    // pallone uscito, gol o tempo scaduto: si rimette a posto la stessa prova
    const lost = this.st.c && m.ball.owner && m.ball.owner.team === 1;
    if (m.phase !== 'play' || this.t > STEP_TIMEOUT || lost) this.reset();
  }
}
