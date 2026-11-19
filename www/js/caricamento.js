// Settore Zero — caricamento a pezzi dei modelli 3D e dell'audio (file veri in www/assets/, elenco in assets/elenco.js)
'use strict';
/* Prima tutti i modelli e i suoni stavano in base64 dentro script caricati all'avvio (~15 MB prima del menu).
   Ora:
   - il menu compare subito; in sottofondo arrivano solo i pezzi della scena del menu (CAR.MENU), poi gli effetti sonori;
   - all'ingresso in un livello (startLevel, avvolto in menu.js) carLevel() scarica SOLO ciò che serve a quel livello
     (carNeeds) con una barra di avanzamento, libera ciò che non serve più e poi avvia il livello;
   - se un file manca o è rotto si va avanti senza: il gioco ha già i ripieghi procedurali (nemici, armi, barile, sala).
   Strutture usate dal resto del codice (invariate): MODELS[nome] = GLTF (grafica.js), HM (materiali della sala),
   SUONI[nome] = dati audio da decodificare (audio.js). Questo file va caricato PRIMA di js/dati.js. */

// compatibilità: se un ramo aggiunge ancora un vecchio models/*.js "incorporato" (ASSET.nome="base64"), lo usiamo da qui
var ASSET = window.ASSET || {};
// audio scaricato e non ancora decodificato (ArrayBuffer; i vecchi suoni/*.js mettevano stringhe base64, valgono ancora)
var SUONI = window.SUONI || {};

const CAR = {
  E: window.ELENCO_ASSET || { models: {}, audio: {} }, // elenco generato da tools/estrai-asset.js
  BASE: 'assets/',
  MAX: 4,             // download contemporanei
  TMAX: 60000,        // ms massimi per un singolo file, poi si rinuncia a quel pezzo
  MENU: ['hall', 'xbot', 'n_texture'], // scena del menu: restano sempre in memoria
  att: 0, coda: [],
  p: {},              // promessa per chiave: 'm:nome' (modello) / 'a:nome' (audio)
  st: {},             // avanzamento per chiave: { b: byte attesi, got: byte arrivati }
  fatto: {},          // audio già consegnato ad audio.js
  hooks: [],          // fn(nome, 'pronto'|'libera', gltf): per chi prepara i modelli (es. armi-ambienti.js)
  wm0: null,          // modelli originali delle armi (WM viene modificato da armi-ambienti.js)
  menuP: null, lvTok: 0, ultimo: null, log: [],
  opt: /[?&]nocache\b/.test(location.search) ? { cache: 'reload' } : {}
};

/* ===== download con limite di contemporaneità ===== */
function carSlot(fn, pri) {
  return new Promise((res, rej) => {
    const go = () => {
      CAR.att++;
      let p;
      try { p = Promise.resolve(fn()); } catch (e) { p = Promise.reject(e); }
      p.then(res, rej).then(carNext, carNext);
    };
    if (CAR.att < CAR.MAX) go(); else if (pri) CAR.coda.unshift(go); else CAR.coda.push(go);
  });
}
function carNext() { CAR.att--; const n = CAR.coda.shift(); if (n) n(); }

// scarica un file contando i byte (rec.got) per la barra; errore se manca, è vuoto o ci mette troppo
async function carGet(url, rec) {
  const ac = typeof AbortController !== 'undefined' ? new AbortController() : null;
  const tm = ac ? setTimeout(() => ac.abort(), CAR.TMAX) : 0;
  try {
    const r = await fetch(url, ac ? Object.assign({ signal: ac.signal }, CAR.opt) : CAR.opt);
    if (!r.ok) throw new Error('HTTP ' + r.status + ' ' + url);
    if (!rec.b) rec.b = +r.headers.get('content-length') || 0;
    let buf;
    if (!r.body || !r.body.getReader) { buf = await r.arrayBuffer(); rec.got = buf.byteLength; }
    else {
      const rd = r.body.getReader(), parts = [];
      let n = 0;
      for (;;) { const x = await rd.read(); if (x.done) break; parts.push(x.value); n += x.value.length; rec.got = n; }
      const u = new Uint8Array(n);
      let o = 0;
      for (const q of parts) { u.set(q, o); o += q.length; }
      buf = u.buffer;
    }
    if (!buf.byteLength) throw new Error('file vuoto ' + url);
    return buf;
  } finally { if (tm) clearTimeout(tm); }
}
const carWarn = (cosa, k, e) => console.warn('[caricamento] ' + cosa + ' non disponibile, continuo senza: ' + k + ' (' + (e && e.message || e) + ')');
function carHook(k, ev, gl) { for (const f of CAR.hooks) { try { f(k, ev, gl); } catch (e) { console.warn('[caricamento] preparazione ' + k, e); } } }

/* ===== modelli: fetch -> GLTFLoader.parse -> MODELS[nome] ===== */
function carModel(k, pri) {
  const id = 'm:' + k;
  if (CAR.p[id]) return CAR.p[id];
  if (MODELS[k]) return (CAR.p[id] = Promise.resolve(MODELS[k]));
  const e = CAR.E.models[k], rec = CAR.st[id] = { b: e ? e.b : 0, got: 0 }, emb = typeof ASSET[k] === 'string' ? ASSET[k] : null;
  const dati = emb ? Promise.resolve().then(() => { const b = b64buf(emb); ASSET[k] = null; rec.b = rec.got = b.byteLength; return b; })
    : carSlot(() => carGet(CAR.BASE + (e ? e.f : 'models/' + k + '.glb'), rec), pri);
  const p = dati.then(buf => new Promise((res, rej) => {
    if (!THREE.GLTFLoader) throw new Error('GLTFLoader assente');
    new THREE.GLTFLoader().parse(buf, '', res, rej);
  })).then(gl => {
    if (CAR.p[id] !== p) { carDispose(gl); return null; } // liberato mentre arrivava
    MODELS[k] = gl;
    try { if (typeof modelPrep === 'function') modelPrep(k, gl); } catch (er) { console.warn('[caricamento] preparazione ' + k, er); }
    carHook(k, 'pronto', gl);
    return gl;
  }).catch(er => { carWarn('modello', k, er); if (CAR.p[id] === p) delete CAR.p[id]; return null; })
    .then(gl => { rec.b = rec.got = Math.max(rec.got, rec.b); return gl; });
  return (CAR.p[id] = p);
}
// libera la memoria (GPU e JS) di un GLTF: geometrie, materiali, texture, scheletri
function carDispose(gl) {
  if (!gl || !gl.scene) return;
  const seen = new Set();
  gl.scene.traverse(o => {
    if (o.geometry && !seen.has(o.geometry)) { seen.add(o.geometry); o.geometry.dispose(); }
    const ms = Array.isArray(o.material) ? o.material : o.material ? [o.material] : [];
    for (const m of ms) {
      if (seen.has(m)) continue;
      seen.add(m);
      for (const q in m) { const t = m[q]; if (t && t.isTexture && !seen.has(t)) { seen.add(t); t.dispose(); } }
      m.dispose();
    }
    if (o.isSkinnedMesh && o.skeleton && o.skeleton.boneTexture) o.skeleton.dispose();
  });
}
function carFreeModel(k) {
  const gl = MODELS[k];
  carHook(k, 'libera', gl);
  delete MODELS[k]; delete CAR.p['m:' + k]; delete CAR.st['m:' + k];
  carDispose(gl);
}

/* ===== audio: fetch -> recAdd (audio.js decodifica quando c'è l'AudioContext) ===== */
function carAudio(k, pri) {
  const id = 'a:' + k;
  if (CAR.p[id]) return CAR.p[id];
  const e = CAR.E.audio[k], rec = CAR.st[id] = { b: e ? e.b : 0, got: 0 };
  const dati = typeof SUONI[k] === 'string' ? Promise.resolve(null) // vecchio audio incorporato: è già in memoria
    : carSlot(() => carGet(CAR.BASE + (e ? e.f : 'audio/' + k + '.mp3'), rec), pri);
  // non aspettiamo la decodifica (gira in sottofondo; la musica parte appena pronta, come faceva già audio.js)
  const p = dati.then(buf => { CAR.fatto[k] = 1; recAdd(k, buf || SUONI[k]); })
    .then(() => true)
    .catch(er => { carWarn('audio', k, er); if (CAR.p[id] === p) delete CAR.p[id]; try { recMiss(k); } catch (x) {} return false; })
    .then(ok => { rec.b = rec.got = Math.max(rec.got, rec.b); return ok; });
  return (CAR.p[id] = p);
}
const carFx = () => Object.keys(CAR.E.audio).filter(k => k.indexOf('mus_') !== 0);
function carEffetti(pri) { return Promise.all(carFx().map(k => carAudio(k, pri))); }

/* ===== cosa serve a un livello =====
   Analizza i dati del livello (lvDef: tipi di nemici di tutte le ondate, corridoi con pericoli, boss) e le armi
   equipaggiate. Ogni voce: { k: modello, alt: modelli da caricare solo se k manca (il ripiego del codice li usa) }.
   Nel dubbio si include: meglio un pezzo in più che un nemico invisibile. */
function carNeeds(L) {
  const m = [], add = (k, alt) => { if (k && !m.some(x => x.k === k)) m.push({ k, alt: alt || [] }); };
  for (const k of CAR.MENU) add(k);          // sala (tutte le stanze), xbot (Varr/Kross/Marsh e 3 tipi di nemici), texture casse
  add('n_barile', ['bar']);                   // barili esplosivi in tutte le stanze e nei corridoi
  const ts = new Set();
  let boss = false, D = [];
  try { D = lvDef(L); } catch (e) { console.warn('[caricamento] livello ' + L, e); }
  for (const d of D) {
    if (d.run) { if ('cqx'.indexOf(d.rk) >= 0) { ts.add('brute'); ts.add('automa'); } continue; } // pericoli dei corridoi (mkDummy)
    if (d.boss) boss = true;
    for (const w of d.waves || []) for (const t of w) { if (t === 'boss') boss = true; else ts.add(t); }
  }
  for (const t of ts) {
    const T = ET[t];
    if (!T) continue;
    if (T.m === 'robot') add('robot', ['sol', 'g_m4']); // senza robot l'automa diventa un bruto (soldato)
    else if (T.m === 'human') { add(T.mdl || 'sol'); add(T.laser ? 'g_sniper' : T.shield ? 'g_suomi' : 'g_m4'); }
    if (T.gren) add('g_frag');
  }
  if (boss) add('g_frag'); // alcuni colossi lanciano granate
  for (const w of carArmi()) add(...carArma(w));
  const au = ['mus_level'];
  if (boss) au.push('mus_boss');
  return { m, au, boss };
}
function carArmi() { const a = S.eq.map(id => wget(id)).filter(Boolean); if (!a.length && S.inv[0]) a.push(S.inv[0]); return a; }
// modello dell'arma in prima persona: quello nuovo di armi-ambienti.js (AA_W) con ripiego sul vecchio (WM originale)
function carArma(w) {
  if (!CAR.wm0) carInit();
  const a = typeof AA_W !== 'undefined' && AA_W[w.t], k0 = CAR.wm0[w.t];
  return a ? [a.wm.k, k0 ? [k0] : []] : [k0, []];
}

/* ===== barra di avanzamento ===== */
function carBar(on, L) {
  let el = document.getElementById('car');
  if (!on) { if (el) el.remove(); return; }
  if (!el) {
    el = document.createElement('div');
    el.id = 'car';
    const boss = L % 5 === 0;
    el.innerHTML = '<div class="pan"><small class="kick">LIVELLO ' + L + ' · CAPITOLO ' + (chI(L) + 1) + (boss ? ' · COLOSSO' : '') + '</small>' +
      '<h2>CARICAMENTO</h2><p>' + lvTxt(L) + '</p><div class="prog"><i id="carb"></i></div><small class="pt" id="cart">0%</small></div>';
    document.body.appendChild(el);
  }
  return el;
}
function carBarSet(ids) {
  let b = 0, g = 0;
  for (const id of ids) { const r = CAR.st[id]; if (!r) continue; b += r.b || 0; g += Math.min(r.got, r.b || r.got); }
  const pc = b ? Math.min(100, Math.round(g / b * 100)) : 0, i = document.getElementById('carb'), t = document.getElementById('cart');
  if (i) i.style.width = pc + '%';
  if (t) t.textContent = (pc >= 100 ? 'PREPARAZIONE… ' : pc + '% · ') + (g / 1048576).toFixed(1).replace('.', ',') + ' / ' + (b / 1048576).toFixed(1).replace('.', ',') + ' MB';
  return g;
}

/* ===== ingresso in un livello: carica, libera, avvia ===== */
function carLevel(L, go) {
  const tok = ++CAR.lvTok, t0 = performance.now();
  try { ainit(); } catch (e) {}
  const N = carNeeds(L), ids = new Set();
  const audio = N.au.concat(carFx()).filter(k => !CAR.fatto[k] && (CAR.E.audio[k] || typeof SUONI[k] === 'string'));
  const daFare = N.m.filter(x => !MODELS[x.k]);
  if (!daFare.length && !audio.length) { carFree(N); go(); CAR.ultimo = { L, byte: 0, ms: Math.round(performance.now() - t0), file: 0 }; return Promise.resolve(); }
  const pb = ui.querySelector('[data-a=play]');
  if (pb) pb.textContent = 'CARICAMENTO…';
  let el = null;
  const tBar = setTimeout(() => { if (tok === CAR.lvTok) el = carBar(true, L); }, 100);
  const tick = setInterval(() => { if (el) carBarSet(ids); }, 60);
  const modello = x => { if (!MODELS[x.k]) ids.add('m:' + x.k); return carModel(x.k, true).then(gl => gl || !x.alt.length ? gl : Promise.all(x.alt.map(a => { ids.add('m:' + a); return carModel(a, true); }))); };
  const lavori = N.m.map(modello).concat(audio.map(k => {
    ids.add('a:' + k);
    return carAudio(k, true);
  }));
  return Promise.all(lavori).then(() => {
    clearTimeout(tBar); clearInterval(tick);
    if (tok !== CAR.lvTok) return; // nel frattempo è stato chiesto un altro livello
    const byte = carBarSet(ids);
    carFree(N);
    carBar(false);
    CAR.ultimo = { L, byte, ms: Math.round(performance.now() - t0), file: ids.size };
    CAR.log.push(CAR.ultimo);
    go();
  }).catch(e => { clearTimeout(tBar); clearInterval(tick); carBar(false); console.warn('[caricamento] livello ' + L, e); if (tok === CAR.lvTok) go(); });
}
// libera i modelli e la musica che il livello N non usa (mai i pezzi del menu, mai la musica che sta suonando)
function carFree(N) {
  const keep = new Set(CAR.MENU);
  for (const x of N.m) { keep.add(x.k); for (const a of x.alt) keep.add(a); }
  for (const id of Object.keys(CAR.p)) {
    if (id.indexOf('m:') !== 0) continue;
    const k = id.slice(2);
    if (!keep.has(k) && MODELS[k]) carFreeModel(k);
  }
  if (!N.boss && CAR.fatto.mus_boss && recFree('mus_boss')) { delete CAR.p['a:mus_boss']; delete CAR.fatto.mus_boss; delete CAR.st['a:mus_boss']; }
}

/* ===== avvio: scena del menu in sottofondo, poi gli effetti sonori ===== */
function carInit() { if (!CAR.wm0) { CAR.wm0 = {}; for (const t in WM) CAR.wm0[t] = WM[t].k; } }
function carMenu() {
  if (CAR.menuP) return CAR.menuP;
  carInit();
  CAR.menuP = Promise.all(CAR.MENU.map(k => carModel(k))).then(() => { modelsReady = true; if (CAR.menuRes) CAR.menuRes(); });
  CAR.menuP.then(() => carEffetti(false));
  return CAR.menuP;
}
// arma presa a metà livello (baule) e non ancora caricata: la scarica e ricostruisce l'arma in mano quando arriva
function carArmaOra() {
  if (!G || typeof cw !== 'function') return;
  const w = cw(), [k, alt] = carArma(w);
  if (!k || MODELS[k] || alt.some(a => MODELS[a])) return;
  const rifai = gl => { if (gl && G && (state === 'play' || state === 'pause') && cw() === w) buildWeapon(); };
  carModel(k).then(gl => gl ? rifai(gl) : alt.length ? carModel(alt[0]).then(rifai) : null);
}
