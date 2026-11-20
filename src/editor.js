// Editor dello stemma, del campione, dell'aspetto di un giocatore e dello stile della divisa (schermata 'editor' di UI).
// Modi: 'crest' (stemma), 'champ' (campione: viso, capelli, divisa, nome e ruolo), 'look' (aspetto di un giocatore
// della rosa: viso, capelli, scarpe), 'kit' (stile della divisa). Nella creazione della squadra: stemma → campione.
// L'anteprima 3D è un piccolo renderer three.js dedicato nel canvas della schermata (si spegne uscendo).
// Le scelte aggiornano solo il pannello e l'anteprima, senza ridisegnare la schermata (il canvas resta lo stesso).
import * as THREE from 'three';
import { KITS, POS_NAME, randomName } from './career.js';
import { SKINS, HAIR_COLORS, HAIR_STYLES, EYE_SHAPES, EYE_COLORS, BROWS, BEARDS, BOOTS, KIT_OPTS, lookFromSeed, lookOf, normalizeLook, normalizeKitStyle, kitStyleFromSeed, hash32, seeded } from './looks.js';
import { CREST_SHAPES, CREST_PATTERNS, CREST_ICONS, crestSvg, crestFromSeed } from './crest.js';
import { loadBestPlayers } from './athlete3d.js';

const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const PREVIEW_TEX = 1024;     // texture dell'anteprima: più fine che in partita (si vede da vicino)
const SPIN = 0.45;            // rad/s: rotazione lenta dell'anteprima
const CAM_BODY = { y: 1.35, z: 5.0, look: 1.2 }, CAM_HEAD = { y: 2.1, z: 2.0, look: 2.02 }; // inquadrature (m, giocatore scalato 1,25)
const KIT_LABELS = { fit: 'Maglia', sleeves: 'Maniche', collar: 'Colletto', pattern: 'Motivo', shorts: 'Pantaloncini', socks: 'Calzettoni' };
const STILL = { vx: 0, vy: 0, state: 'play', cele: 0, kickAnim: 0, pos: 'A', i: 0, x: 0, y: 0 }; // giocatore fermo per la posa dell'anteprima
const GK_KIT = { shirt: 0x27e0c0, shorts: 0x0c5c52, socks: 0x27e0c0 };

export class Editor {
  constructor(ui) { this.ui = ui; this.mode = ''; this.tab = ''; this.d = null; this.view = null; }
  get c() { return this.ui.c; }

  // ---------------------------------------------------------------- apertura
  // nuova squadra: { club, kit } → stemma, poi campione; la carriera si crea solo alla conferma finale
  openNew(club, kit) {
    const seed = hash32(club, kit, Date.now());
    this.flow = 'new';
    this.d = { club, kit, crest: crestFromSeed(seed), style: normalizeKitStyle(null), look: lookFromSeed(seed), name: randomName(seeded(seed)), pos: 'A', num: 9 };
    this.mode = 'crest'; this.tab = 'shape';
  }
  openLook(id) {
    const p = this.c.player(id); if (!p) return false;
    this.flow = 'look'; this.mode = 'look'; this.tab = 'face';
    const s = this.c.s;
    this.d = { id, kit: s.kit, crest: this.c.crest(), style: this.c.kitStyle(), look: lookOf(p), name: p.name, pos: p.pos, num: p.num };
    return true;
  }
  openKit() {
    const s = this.c.s, p = s.squad.find(q => q.champ) || s.squad.find(q => q.pos !== 'P') || s.squad[0];
    this.flow = 'kit'; this.mode = 'kit'; this.tab = 'kit';
    this.d = { kit: s.kit, crest: this.c.crest(), style: this.c.kitStyle(), look: lookOf(p), name: p.name, pos: 'A', num: p.num };
  }
  openCrest() {
    const s = this.c.s; this.flow = 'crest'; this.mode = 'crest'; this.tab = 'shape';
    this.d = { kit: s.kit, crest: this.c.crest(), club: s.club };
  }

  // ---------------------------------------------------------------- schermata
  html() {
    const d = this.d, k = KITS[d.kit] || KITS[0];
    const title = { crest: 'Lo stemma', champ: 'Crea il tuo campione', look: 'Aspetto', kit: 'Stile della divisa' }[this.mode];
    const back = this.flow === 'new' ? (this.mode === 'champ' ? 'edback' : 'edcancel') : 'edcancel';
    const head = `<div class="top edtop"><button class="back" data-a="${back}" aria-label="Indietro">‹</button><h2>${title}</h2>${this.flow === 'new' ? `<span class="pill">${this.mode === 'crest' ? '1' : '2'} di 2</span>` : ''}</div>`;
    const stage = this.mode === 'crest'
      ? `<div class="edstage cst" id="edcrest">${crestSvg(d.crest, k[1], k[2], 'big')}<b>${esc(d.club || '')}</b></div>`
      : `<div class="edstage"><canvas id="edc" aria-label="Anteprima del giocatore"></canvas><div class="edwait" id="edwait">Carico l'anteprima…</div><div class="edname" id="edtag">${esc(d.name || '')} · ${d.num || ''}</div></div>`;
    const ok = this.flow === 'new' ? (this.mode === 'crest' ? 'Avanti' : 'Conferma e allenati') : 'Salva';
    return `${head}${stage}<div id="edpanel">${this.panel()}</div>
      <div class="edbar"><button class="btn ghost" data-a="edrand">Casuale</button><button class="btn big" data-a="edok">${ok}</button></div>`;
  }

  tabs() {
    const T = { crest: [['shape', 'Forma'], ['pattern', 'Motivo'], ['icon', 'Simbolo']], champ: [['face', 'Viso'], ['hair', 'Capelli'], ['kit', 'Divisa'], ['me', 'Nome e ruolo']], look: [['face', 'Viso'], ['hair', 'Capelli'], ['boots', 'Scarpe']], kit: [['kit', 'Divisa']] }[this.mode];
    if (T.length < 2) return '';
    return `<div class="edtabs" role="tablist">${T.map(([v, n]) => `<button class="edtab ${this.tab === v ? 'on' : ''}" role="tab" aria-selected="${this.tab === v}" data-a="edtab" data-v="${v}">${n}</button>`).join('')}</div>`;
  }

  panel() {
    const d = this.d, L = d.look;
    const chips = (key, names, cur) => `<div class="edchips">${names.map((n, i) => `<button class="chip ${i === cur ? 'on' : ''}" data-a="edset" data-v="${key}:${i}">${esc(n)}</button>`).join('')}</div>`;
    const sw = (key, list, cur) => `<div class="edsw">${list.map(([n, c], i) => `<button class="sw ${i === cur ? 'on' : ''}" style="--c:${c}" data-a="edset" data-v="${key}:${i}" aria-label="${esc(n)}"></button>`).join('')}</div>`;
    const row = (label, val, body) => `<h3>${label}${val ? ` <em>${esc(val)}</em>` : ''}</h3>${body}`;
    let out = this.tabs();
    if (this.mode === 'crest') {
      const k = KITS[d.kit] || KITS[0], list = { shape: CREST_SHAPES, pattern: CREST_PATTERNS, icon: CREST_ICONS }[this.tab];
      out += `<p class="note">Colori presi dalla maglia (${esc(k[0])}).</p><div class="edgrid ${this.tab === 'icon' ? 'g5' : ''}">${list.map(([n], i) => {
        const c = { ...d.crest, [this.tab]: i };
        return `<button class="edopt ${d.crest[this.tab] === i ? 'on' : ''}" data-a="edset" data-v="crest.${this.tab}:${i}" aria-label="${esc(n)}">${crestSvg(c, k[1], k[2])}<span>${esc(n)}</span></button>`;
      }).join('')}</div>`;
      return out;
    }
    if (this.tab === 'face') {
      out += row('Pelle', SKINS[L.skin][0], sw('look.skin', SKINS, L.skin));
      out += row('Occhi', '', chips('look.eyes', EYE_SHAPES, L.eyes));
      out += row('Colore degli occhi', EYE_COLORS[L.eyeColor][0], sw('look.eyeColor', EYE_COLORS, L.eyeColor));
      out += row('Sopracciglia', '', chips('look.brows', BROWS, L.brows));
      out += row('Barba', '', chips('look.beard', BEARDS, L.beard));
    } else if (this.tab === 'hair') {
      out += row('Taglio', `${L.hair + 1} di ${HAIR_STYLES.length}`, chips('look.hair', HAIR_STYLES, L.hair));
      out += row('Colore', HAIR_COLORS[L.hairColor][0], sw('look.hairColor', HAIR_COLORS, L.hairColor));
    } else if (this.tab === 'boots') {
      out += row('Scarpe', BOOTS[L.boots][0], sw('look.boots', BOOTS, L.boots));
    } else if (this.tab === 'kit') {
      out += `<p class="note">Lo stile vale per tutta la squadra; i colori sono quelli scelti per la maglia.</p>`;
      for (const key of Object.keys(KIT_OPTS)) out += row(KIT_LABELS[key], '', chips('style.' + key, KIT_OPTS[key], d.style[key]));
      if (this.mode === 'champ') out += row('Scarpe del campione', BOOTS[L.boots][0], sw('look.boots', BOOTS, L.boots));
    } else if (this.tab === 'me') {
      out += `<h3>Nome</h3><input id="edname" maxlength="20" value="${esc(d.name)}" autocomplete="off" aria-label="Nome del campione">`;
      out += row('Ruolo', '', `<div class="edchips">${['P', 'D', 'C', 'A'].map(p => `<button class="chip ${d.pos === p ? 'on' : ''}" data-a="edset" data-v="pos:${p}">${{ P: 'Portiere', D: 'Difensore', C: 'Centrocampista', A: 'Attaccante' }[p]}</button>`).join('')}</div>`);
      out += row('Numero di maglia', '', `<div class="ednum"><button class="btn" data-a="ednum" data-v="-1" aria-label="Numero precedente">−</button><b>${d.num}</b><button class="btn" data-a="ednum" data-v="1" aria-label="Numero successivo">+</button></div><div class="edchips">${[7, 9, 10, 11, 1, 4, 8, 99].map(n => `<button class="chip ${d.num === n ? 'on' : ''}" data-a="edset" data-v="num:${n}">${n}</button>`).join('')}</div>`);
      out += `<p class="note">Il campione entra in rosa come un giovane forte della Terza Divisione (${POS_NAME[d.pos]}), con l'aspetto che hai scelto.</p>`;
    }
    return out;
  }

  // ---------------------------------------------------------------- azioni (tutte 'ed…'): true se gestita
  act(a, v) {
    const d = this.d; if (!d) return false;
    switch (a) {
      case 'edtab': this.tab = v; this.refresh(true); return true;
      case 'edset': {
        const [path, raw] = v.split(':'), [obj, key] = path.includes('.') ? path.split('.') : [null, path];
        const val = key === 'pos' ? raw : +raw;
        if (obj) d[obj] = { ...d[obj], [key]: val }; else d[key] = val;
        if (key === 'pos' && val === 'P' && d.num === 9) d.num = 1;
        this.refresh(false); return true;
      }
      case 'ednum': d.num = ((d.num - 1 + +v + 99) % 99) + 1; this.refresh(false); return true;
      case 'edrand': this.randomize(); this.refresh(false); return true;
      case 'edback': this.mode = 'crest'; this.tab = 'shape'; this.ui.show('editor'); return true;
      case 'edcancel': this.close(this.flow === 'new' ? ['title', 'new'] : this.flow === 'look' ? ['squad'] : ['settings']); return true;
      case 'edok': this.confirm(); return true;
    }
    return false;
  }
  randomize() {
    const d = this.d, r = seeded(hash32(Date.now(), Math.random()));
    if (this.mode === 'crest') { d.crest = crestFromSeed(r() * 1e9 | 0); return; }
    if (this.tab === 'kit') { d.style = kitStyleFromSeed(r() * 1e9 | 0); return; }
    if (this.tab === 'me') { d.name = randomName(r); return; }
    const L = lookFromSeed(r() * 1e9 | 0);
    // "Casuale" cambia solo la scheda aperta (viso o capelli), il resto resta com'è
    d.look = this.tab === 'hair' ? { ...d.look, hair: L.hair, hairColor: L.hairColor } : this.tab === 'boots' ? { ...d.look, boots: L.boots } : { ...L, hair: d.look.hair, hairColor: d.look.hairColor, boots: d.look.boots };
  }
  confirm() {
    const c = this.c, d = this.d;
    if (this.mode === 'crest' && this.flow === 'new') { this.mode = 'champ'; this.tab = 'face'; this.ui.show('editor'); return; }
    if (this.flow === 'new') {
      c.create(d.club, d.kit); c.setCrest(d.crest); c.setKitStyle(d.style);
      c.addChampion({ name: d.name, pos: d.pos, look: d.look, num: d.num });
      this.unmount(); this.d = null; this.ui.api.play('tutorial'); return;
    }
    if (this.flow === 'crest') { c.setCrest(d.crest); this.close(['settings'], 'Stemma salvato'); return; }
    if (this.flow === 'kit') { c.setKitStyle(d.style); this.close(['settings'], 'Divisa salvata'); return; }
    if (this.flow === 'look') { c.setLook(d.id, d.look); this.ui.sel = d.id; this.close(['squad'], 'Aspetto salvato'); }
  }
  close([screen, arg], msg) { this.unmount(); this.d = null; this.ui.msg = msg || ''; this.ui.show(screen, arg); this.ui.msg = ''; }

  // aggiorna pannello (e schede), cartellino e anteprima senza ricostruire la schermata
  refresh(tabChanged) {
    const root = this.ui.root, p = root.querySelector('#edpanel'); if (!p) return;
    const sc = root.firstChild, top = sc ? sc.scrollTop : 0;
    p.innerHTML = this.panel();
    if (sc) sc.scrollTop = tabChanged ? 0 : top;
    const d = this.d, k = KITS[d.kit] || KITS[0];
    if (this.mode === 'crest') { const st = root.querySelector('#edcrest'); if (st) st.firstElementChild.outerHTML = crestSvg(d.crest, k[1], k[2], 'big'); return; }
    const tag = root.querySelector('#edtag'); if (tag) tag.textContent = `${d.name} · ${d.num}`;
    if (this.view) { this.view.frame(this.tab === 'face' || this.tab === 'hair' ? CAM_HEAD : CAM_BODY); this.view.swing = this.tab === 'face'; this.view.setPlayer(this.kitFor(), d.look, d.num, d.name); }
  }
  kitFor() {
    const d = this.d, k = KITS[d.kit] || KITS[0], gk = d.pos === 'P';
    const kit = gk ? { ...GK_KIT } : { shirt: k[1], shorts: k[2], socks: k[1] };
    kit.style = gk ? { ...d.style, sleeves: 1, pattern: 0, collar: 0 } : { ...d.style };
    kit.crest = { ...d.crest, c1: k[1], c2: k[2] }; if (gk) kit.gloves = true;
    return kit;
  }

  // ---------------------------------------------------------------- anteprima
  mount(root) {
    const k = KITS[this.d.kit] || KITS[0];
    root.style.setProperty('--k1', '#' + k[1].toString(16).padStart(6, '0')); root.style.setProperty('--k2', '#' + k[2].toString(16).padStart(6, '0'));
    const name = root.querySelector('#edname'); // il nome si scrive senza ridisegnare
    root.addEventListener('input', this.onInput || (this.onInput = e => { if (e.target.id === 'edname' && this.d) { this.d.name = e.target.value.slice(0, 20); const t = root.querySelector('#edtag'); if (t) t.textContent = `${this.d.name} · ${this.d.num}`; } }));
    void name;
    const cv = root.querySelector('#edc'); if (!cv) return;
    this.unmount();
    this.view = new Preview(cv);
    this.view.frame(this.tab === 'face' || this.tab === 'hair' ? CAM_HEAD : CAM_BODY, true); this.view.swing = this.tab === 'face';
    const assets = this.ui.api.assets || (typeof window !== 'undefined' && window.__assets);
    const view = this.view;
    const ready = assets ? assets.loadStage('match').then(() => loadBestPlayers(assets)) : Promise.resolve(null);
    ready.then(m => {
      if (this.view !== view) return;
      const w = this.ui.root.querySelector('#edwait');
      if (!m) { if (w) w.textContent = 'Anteprima 3D non disponibile'; return; }
      if (w) w.style.display = 'none';
      // inquadratura del viso all'altezza della testa del modello in uso (il modello realistico ha la testa più alta)
      if (m.headY) { CAM_HEAD.look = m.headY * 1.25 - 0.03; CAM_HEAD.y = CAM_HEAD.look + 0.06; CAM_HEAD.z = 1.35; CAM_BODY.z = 5.6; CAM_BODY.look = 1.2; CAM_BODY.y = 1.3; view.frame(this.tab === 'face' || this.tab === 'hair' ? CAM_HEAD : CAM_BODY, true); }
      view.p3d = m; view.setPlayer(this.kitFor(), this.d.look, this.d.num, this.d.name);
    }).catch(() => { const w = this.ui.root.querySelector('#edwait'); if (w) w.textContent = 'Anteprima 3D non disponibile'; });
  }
  unmount() { if (this.view) { this.view.dispose(); this.view = null; } }
}

// piccolo renderer dell'anteprima: giocatore che ruota piano, trascinabile col dito
class Preview {
  constructor(canvas) {
    this.cv = canvas;
    this.r = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
    this.r.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.scene = new THREE.Scene();
    this.scene.add(new THREE.HemisphereLight(0xeef4ff, 0x40506a, 1.6));
    const sun = new THREE.DirectionalLight(0xffffff, 1.6); sun.position.set(2, 4, 3); this.scene.add(sun);
    const back = new THREE.DirectionalLight(0x9ec5ff, 0.7); back.position.set(-3, 2, -3); this.scene.add(back);
    const disc = new THREE.Mesh(new THREE.CircleGeometry(0.85, 40), new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.28 }));
    disc.rotation.x = -Math.PI / 2; disc.position.y = 0.002; this.scene.add(disc);
    this.cam = new THREE.PerspectiveCamera(30, 1, 0.05, 50);
    this.cur = { ...CAM_BODY }; this.goal = CAM_BODY; this.yaw = 0.5; this.drag = null; this.fig = null; this.t = 0;
    this.key = '';
    const down = e => { this.drag = { x: e.clientX, yaw: this.yaw }; canvas.setPointerCapture && canvas.setPointerCapture(e.pointerId); };
    const move = e => { if (this.drag) this.yaw = this.drag.yaw + (e.clientX - this.drag.x) * 0.012; };
    const up = () => { this.drag = null; };
    canvas.addEventListener('pointerdown', down); canvas.addEventListener('pointermove', move); canvas.addEventListener('pointerup', up); canvas.addEventListener('pointercancel', up);
    this.last = performance.now();
    const loop = (now) => { if (!this.r) return; this.raf = requestAnimationFrame(loop); this.tick(Math.min(0.05, (now - this.last) / 1000)); this.last = now; };
    this.raf = requestAnimationFrame(loop);
  }
  // inquadratura; da vicino il viso oscilla davanti invece di girare (si vedrebbe la nuca metà del tempo)
  frame(c, now) { this.goal = c; this.swing = c === CAM_HEAD; if (now) this.cur = { ...c }; }
  setPlayer(kit, look, num, name) {
    if (!this.p3d) return;
    const key = JSON.stringify([kit, look, num, name]); if (key === this.key) return; this.key = key;
    if (this.fig) { this.scene.remove(this.fig.g); this.p3d.dispose(this.fig); }
    this.fig = this.p3d.make(kit, normalizeLook(look), { num, name, tex: PREVIEW_TEX });
    this.fig.g.scale.setScalar(1.25); this.scene.add(this.fig.g);
  }
  tick(dt) {
    const w = this.cv.clientWidth, h = this.cv.clientHeight; if (!w || !h) return;
    if (this.cv.width !== Math.round(w * this.r.getPixelRatio())) { this.r.setSize(w, h, false); this.cam.aspect = w / h; this.cam.updateProjectionMatrix(); }
    this.t += dt;
    if (!this.drag) this.yaw = this.swing ? this.yaw + (0.55 * Math.sin(this.t * 0.7) - this.yaw) * Math.min(1, dt * 2) : this.yaw + dt * SPIN;
    const k = Math.min(1, dt * 6); for (const n of ['y', 'z', 'look']) this.cur[n] += (this.goal[n] - this.cur[n]) * k;
    // la stessa posa del campo, da fermo (il modello realistico chiude un po' gambe e braccia del clip "fermo")
    if (this.fig) { this.fig.g.rotation.y = this.yaw; this.p3d.pose(STILL, this.fig, dt, { t: this.t, phase: 'menu', flip: 1, yaw: 0, ball: null, scale: 1.25, trick: null }); }
    this.cam.position.set(0, this.cur.y, this.cur.z); this.cam.lookAt(0, this.cur.look, 0);
    this.r.render(this.scene, this.cam);
  }
  dispose() {
    cancelAnimationFrame(this.raf);
    if (this.fig && this.p3d) this.p3d.dispose(this.fig);
    if (this.r) { this.r.dispose(); if (this.r.forceContextLoss) this.r.forceContextLoss(); this.r = null; }
  }
}

