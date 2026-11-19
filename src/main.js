import { Match, FORMATIONS, HW, HL, rng32 } from './sim.js';
import { View } from './render.js';
import { Input } from './input.js';
import { Career, DIV_NAMES, KITS, POS_NAME, overall, genPlayer } from './career.js';
import { UI } from './ui.js';
import { Sfx } from './audio.js';
import { Assets } from './assets.js';
import { runLegacyMigration } from './legacy-save.js';

const $ = id => document.getElementById(id);
const canvas = $('c'), hud = $('hud'), ov = $('ov'), uiRoot = $('ui');
const career = new Career(), view = new View(canvas), sfx = new Sfx();
// file pesanti caricati a pezzi da www/assets/ (manifesto incorporato da build.mjs)
const assets = new Assets({ manifest: typeof __MANIFEST__ !== 'undefined' ? __MANIFEST__ : {}, inline: window.__INLINE_ASSETS });
const G = { state: 'menu', match: null, paused: false, ts: 1, mode: '', title: '', subs: 5, bench: [], res: null, demo: null, bigT: 0, endT: 0, selA: null, selB: null };
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const hex = n => '#' + n.toString(16).padStart(6, '0');

const ui = new UI(uiRoot, career, {
  click: () => { sfx.init(); sfx.resume(); sfx.click(); },
  play: (mode, lvl) => enterMatch(mode, lvl),
  settings: () => { sfx.on = career.s.settings.sound; if (!sfx.on) { sfx.crowd(0); sfx.music(false); } else sfx.music(true); },
  act: (a, v, el) => { if (a === 'season') ui.show('season', G.res.res.season); },
});
const input = new Input(canvas, view, {
  kick: s => G.match.userKick(0, s), move: (x, y, h) => G.match.userMove(0, x, y, h), stop: () => G.match.userStop(0),
  slide: (dx, dy) => G.match.userSlide(0, dx, dy), dive: (dx, th) => G.match.userDive(0, dx, th), sw: i => G.match.userSwitch(0, G.match.players[i]),
});

// ---------------------------------------------------------------- menu con partita dimostrativa sullo sfondo
function demoTeam(name, kit, seed) {
  const r = rng32(seed), F = FORMATIONS['4-3-3'];
  return { name, short: name.slice(0, 3), formation: '4-3-3', skill: 0.6, players: F.map((f, i) => genPlayer(r, f[0], 66, -i - 1)), kit: career.kitOf.call(career, kit, false) };
}
function startDemo() {
  const a = demoTeam('AAA', 3, 11), b = demoTeam('BBB', 1, 29);
  G.demo = new Match({ seed: (Math.random() * 1e9) | 0, halfLen: 99999, human: [false, false], teams: [a, b] });
  view.setMatch(G.demo, 0);
}
function toMenu(screen, arg) {
  G.state = 'menu'; G.match = null; input.enabled = false; input.set(null, 0); hud.style.display = 'none'; ov.style.display = 'none'; sfx.crowd(0); sfx.music(true);
  if (!G.demo) startDemo(); else view.setMatch(G.demo, 0);
  ui.show(screen, arg);
}

// ---------------------------------------------------------------- caricamento a pezzi
// Tappa 'match': stadio, giocatori e suoni di gioco, con barra di avanzamento (solo se c'è qualcosa da scaricare).
// Un file che manca o fallisce viene saltato: la partita parte lo stesso.
let loading = false;
async function enterMatch(mode, lvl) {
  if (loading) return;
  loading = true;
  const box = $('load'), bar = $('loadbar'), need = assets.items('match').length > 0 && !assets.stages.has('match');
  if (need) { bar.style.width = '0%'; box.style.display = 'flex'; }
  try {
    await assets.loadStage('match', (d, t) => { bar.style.width = (t ? Math.round(d / t * 100) : 100) + '%'; });
    sfx.useAssets(assets);
    if (view.useAssets) view.useAssets(assets);
  } catch (e) { /* si gioca senza i file mancanti */ }
  box.style.display = 'none'; loading = false;
  startMatch(mode, lvl);
}
// Tappa 'music': in sottofondo dopo l'apertura del menu, senza bloccare nulla.
function loadMusicLater() {
  setTimeout(() => { assets.loadStage('music').then(() => { sfx.useAssets(assets); if (G.state === 'menu') sfx.music(true); }).catch(() => { /* senza musica */ }); }, 1200);
}

// ---------------------------------------------------------------- partita
function startMatch(mode, lvl) {
  const s = career.s, my = career.myMatchTeam();
  let opp, title;
  if (mode === 'league') { const nm = career.nextMatch(); if (!nm) return; opp = career.aiMatchTeam(nm.opp); title = `Giornata ${nm.day} · ${DIV_NAMES[nm.div]}`; }
  else { opp = career.aiMatchTeam({ name: 'Amichevole', short: 'AMI', kit: (s.kit + 4) % KITS.length, rating: lvl, seed: (Math.random() * 1e9) | 0 }); title = 'Amichevole'; }
  G.mode = mode; G.title = title; G.subs = 5; G.bench = my.bench.slice(); G.res = null; G.paused = false; G.ts = 1; G.endT = 0;
  G.match = new Match({ seed: (Math.random() * 1e9) | 0, halfLen: s.settings.half, human: [true, false], autoGk: [!!s.settings.autoGk, false], teams: [my, opp] });
  G.demo = null;
  view.setMatch(G.match, 0); input.set(G.match, 0); input.enabled = true;
  ui.hide(); ov.style.display = 'none'; hud.style.display = 'block'; G.state = 'match';
  $('tn0').textContent = my.short; $('tn1').textContent = opp.short;
  $('k0').style.background = hex(my.kit.shirt); $('k1').style.background = hex(opp.kit.shirt);
  sfx.on = s.settings.sound; sfx.init(); sfx.resume(); sfx.music(false); sfx.crowd(0.16);
  s.tut = (s.tut || 0) + 1; career.save();
  big(title, '', 1800);
}

function big(text, cls, ms, small) {
  const b = $('big'); b.className = 'on ' + (cls || ''); b.innerHTML = esc(text) + (small ? `<small>${esc(small)}</small>` : ''); G.bigT = performance.now() + (ms || 1400);
}
function fade() { const f = $('fade'); f.style.transition = 'none'; f.style.opacity = 0.85; requestAnimationFrame(() => requestAnimationFrame(() => { f.style.transition = 'opacity .35s'; f.style.opacity = 0; })); }

const HINTS = {
  attack: 'Disegna dalla palla per passare o tirare · tieni premuto per correre',
  defend: 'Tieni premuto per muovere il difensore · scorri veloce = scivolata',
  loose: 'Palla libera: tieni premuto per andarci',
  dive: 'TUFFATI! Scorri verso il tiro',
};
const RHINT = { kickoff: 'Calcio d\'inizio: disegna il passaggio', throw: 'Rimessa: disegna il passaggio', corner: 'Calcio d\'angolo: disegna il cross', goalkick: 'Rinvio: disegna il passaggio', freekick: 'Punizione: disegna il passaggio o il tiro', penalty: 'RIGORE: disegna il tiro in porta', gk: 'Rilancio del portiere: disegna il passaggio' };

function events(m) {
  for (const e of m.events) {
    switch (e.type) {
      case 'kick': sfx.kick(e.v); break;
      case 'tackle': case 'block': sfx.kick(9); break;
      case 'goal':
        if (e.team === 0) { sfx.goal(); big('GOL!', 'g', 2600, (e.scorer ? e.scorer.name : 'Autogol') + ' · ' + e.minute + '\''); }
        else { sfx.ooh(); big('Gol subito', 'b', 2400, (e.scorer ? e.scorer.name : 'Autogol') + ' · ' + e.minute + '\''); }
        break;
      case 'restart':
        if (e.cut) fade();
        if (e.kind === 'kickoff' || e.kind === 'freekick' || e.kind === 'penalty') sfx.whistle();
        if (e.kind === 'corner') big('Calcio d\'angolo', '', 1300);
        else if (e.kind === 'penalty') big('RIGORE!', e.team === 0 ? 'g' : 'b', 1800);
        break;
      case 'offside': big('Fuorigioco', '', 1300); sfx.whistle(); break;
      case 'foul': sfx.whistle(); big(e.card === 'red' ? 'Espulso!' : e.card === 'yellow' ? 'Ammonito' : 'Fallo', e.card ? 'b' : '', 1500, e.card ? e.by.name : ''); break;
      case 'save': if (!e.catch) { big('Parata!', e.p.team === 0 ? 'g' : '', 1000); sfx.ooh(); } break;
      case 'post': big('Palo!', '', 1000); sfx.post(); break;
      case 'half': sfx.whistle(true); showHalf(); break;
      case 'full': sfx.whistle(true); G.endT = performance.now() + 1500; break;
    }
  }
  m.events.length = 0;
}

function finish(forfeit) {
  const m = G.match; input.enabled = false; hud.style.display = 'none'; ov.style.display = 'none'; sfx.crowd(0);
  if (forfeit) { m.score[0] = 0; m.score[1] = Math.max(3, m.score[1]); m.goalsLog = m.goalsLog.filter(g => g.team === 1); }
  let res = null;
  if (G.mode === 'league') res = career.finishMatch(m.score[0], m.score[1], m.goalsLog);
  G.res = { m, res, title: G.title + (forfeit ? ' · abbandonata' : '') };
  G.state = 'menu'; G.match = null; input.set(null, 0);
  ui.show('post', G.res);
}

// ---------------------------------------------------------------- pausa, intervallo, cambi
function overlay(html) { ov.innerHTML = html; ov.style.display = 'block'; }
function showPause() {
  G.paused = true; input.cancel();
  overlay(`<div class="ovh">Pausa</div><button class="btn big" data-o="resume">Riprendi</button><button class="btn" data-o="subs">Cambi (${G.subs} rimasti)</button><button class="btn ghost" data-o="quit">${G.mode === 'league' ? 'Abbandona (sconfitta 0–3)' : 'Esci dall\'amichevole'}</button>
  <div class="card"><p class="note"><b>Attacco</b>: disegna dalla palla per passare o tirare, tieni premuto per correre.<br><b>Difesa</b>: tieni premuto per muovere il difensore, scorri veloce per la scivolata.<br><b>Portiere</b>: scorri verso il lato del tiro.</p></div>`);
}
function showHalf() {
  const m = G.match; G.paused = true; input.cancel();
  overlay(`<div class="ovh">Intervallo</div><div class="ovs">${m.score[0]} – ${m.score[1]}</div><button class="btn big" data-o="second">Secondo tempo</button><button class="btn" data-o="subs">Cambi (${G.subs} rimasti)</button>`);
}
function showSubs() {
  const m = G.match, on = m.team(0).filter(p => !p.off);
  const row = (p, src, sel, key, id) => `<div class="prow ${sel ? 'sel' : ''}" data-o="${key}" data-v="${id}"><span class="pos p${p.pos}">${POS_NAME[p.pos]}</span><span class="pn">${esc(src.name)}</span>${p.energy !== undefined ? `<span class="en"><i style="width:${Math.round(p.energy * 100)}%"></i></span>` : ''}<span class="ovr">${overall(src)}</span></div>`;
  overlay(`<div class="ovh" style="margin-top:0;font-size:22px">Cambi · ${G.subs} rimasti</div><p class="note">Tocca chi esce e chi entra.</p><h3>In campo</h3>${on.map(p => row(p, p.src, G.selA === p.i, 'sa', p.i)).join('')}<h3>Panchina</h3>${G.bench.map((b, i) => row({ pos: b.pos }, b, G.selB === i, 'sb', i)).join('') || '<p class="note">Nessuno in panchina.</p>'}
  <button class="btn big" data-o="dosub" ${G.selA === null || G.selB === null || G.subs <= 0 ? 'style="opacity:.4"' : ''}>Conferma cambio</button><button class="btn ghost" data-o="back">Indietro</button>`);
}
ov.addEventListener('click', e => {
  const t = e.target.closest('[data-o]'); if (!t) return; const a = t.dataset.o, m = G.match; sfx.click();
  if (a === 'resume') { ov.style.display = 'none'; G.paused = false; }
  else if (a === 'second') { ov.style.display = 'none'; G.paused = false; m.startSecondHalf(); }
  else if (a === 'quit') { if (t.dataset.ok !== '1') { t.dataset.ok = '1'; t.textContent = 'Tocca di nuovo per confermare'; return; } if (G.mode === 'league') finish(true); else toMenu('hub'); }
  else if (a === 'subs') { G.selA = G.selB = null; showSubs(); }
  else if (a === 'sa') { G.selA = +t.dataset.v; showSubs(); }
  else if (a === 'sb') { G.selB = +t.dataset.v; showSubs(); }
  else if (a === 'dosub') {
    if (G.selA === null || G.selB === null || G.subs <= 0) return;
    const out = m.team(0)[G.selA].src, inn = G.bench[G.selB];
    m.substitute(0, G.selA, inn); G.bench.splice(G.selB, 1); G.subs--; G.selA = G.selB = null; void out; showSubs();
  } else if (a === 'back') { if (m.phase === 'half') showHalf(); else showPause(); }
});
$('pause').addEventListener('click', () => { if (G.state === 'match' && !G.paused) showPause(); });
document.addEventListener('visibilitychange', () => { if (document.hidden && G.state === 'match' && !G.paused && G.match.phase !== 'half') showPause(); });

// ---------------------------------------------------------------- radar
const radar = $('radar'), rc = radar.getContext('2d');
function drawRadar(m) {
  const w = radar.width, h = radar.height, X = x => (x + HW) / (HW * 2) * (w - 12) + 6, Y = y => (HL - y) / (HL * 2) * (h - 12) + 6;
  rc.clearRect(0, 0, w, h); rc.strokeStyle = 'rgba(255,255,255,.45)'; rc.lineWidth = 1.5;
  rc.strokeRect(6, 6, w - 12, h - 12); rc.beginPath(); rc.moveTo(6, h / 2); rc.lineTo(w - 6, h / 2); rc.stroke();
  rc.strokeRect(X(-20), 6, X(20) - X(-20), Y(HL - 16.5) - 6); rc.strokeRect(X(-20), Y(-HL + 16.5), X(20) - X(-20), h - 6 - Y(-HL + 16.5));
  const c = m.ctrl[0];
  for (const p of m.players) {
    if (p.off) continue;
    rc.fillStyle = p.pos === 'P' ? hex(m.teams[p.team].kit.gk.shirt) : hex(m.teams[p.team].kit.shirt);
    rc.beginPath(); rc.arc(X(p.x), Y(p.y), p === c ? 7 : 5, 0, 7); rc.fill();
    rc.strokeStyle = p === c ? '#ffe14a' : (p.team === 0 ? '#fff' : '#000'); rc.lineWidth = p === c ? 3 : 1; rc.stroke();
  }
  rc.fillStyle = '#fff'; rc.strokeStyle = '#000'; rc.lineWidth = 1.5; rc.beginPath(); rc.arc(X(m.ball.x), Y(m.ball.y), 4, 0, 7); rc.fill(); rc.stroke();
}

// ---------------------------------------------------------------- ciclo principale
let last = performance.now(), hudT = 0, lastHint = '';
function frame(now) {
  requestAnimationFrame(frame);
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  if (G.state === 'match') {
    const m = G.match;
    if (!G.paused) {
      input.update();
      const dive = m.diveWin(0) && !m.autoGk[0];
      const target = input.drawing ? 0.13 : dive ? 0.3 : 1;
      G.ts += (target - G.ts) * Math.min(1, dt * 14);
      const sdt = dt * G.ts * (G.speed || 1), n = Math.max(1, Math.ceil(sdt / (1 / 60)));
      for (let i = 0; i < n; i++) m.step(sdt / n);
      events(m);
      const myRestart = m.phase === 'restart' && m.restart && m.restart.team === 0;
      const mine = m.ball.owner && m.ball.owner.team === 0;
      view.setZoom(input.drawing || myRestart ? 1 : m.phase === 'restart' ? 0.5 : mine ? 0.4 : 0.15);
      $('slow').className = G.ts < 0.6 ? 'on' : '';
      if (G.endT && now > G.endT) { G.endT = 0; finish(false); return; }
    }
    if (now > hudT) {
      hudT = now + 100;
      $('sc').textContent = m.score[0] + ' – ' + m.score[1]; $('clock').textContent = m.minute() + '\'';
      drawRadar(m);
      const h = m.hint(0); let txt = h === 'restart' ? RHINT[m.restart.type] : (HINTS[h] || '');
      if ((career.s.tut || 0) > 4 && (h === 'attack' || h === 'defend' || h === 'loose')) txt = '';
      if (txt !== lastHint) { lastHint = txt; const el = $('hint'); el.className = h === 'dive' || (h === 'restart' && m.restart.type === 'penalty') ? 'hot' : ''; el.innerHTML = txt ? `<span>${txt}</span>` : ''; }
    }
    if (G.bigT && now > G.bigT) { G.bigT = 0; $('big').className = ''; }
    view.update(G.paused ? 0 : dt * Math.max(G.ts, 0.25));
    view.render();
  } else if (G.demo && ui.screen === 'title') {
    const d = G.demo; d.step(dt); d.events.length = 0; if (d.phase === 'half') d.startSecondHalf();
    view.update(dt); view.render();
  }
}

window.addEventListener('resize', () => view.resize());
window.addEventListener('orientationchange', () => setTimeout(() => view.resize(), 200));
document.addEventListener('gesturestart', e => e.preventDefault());
document.addEventListener('touchmove', e => { if (!e.target.closest('.scr') && !e.target.closest('#ov')) e.preventDefault(); }, { passive: false });

// osservatore dello sfondo trasparente solo nella schermata iniziale
const mo = new MutationObserver(() => uiRoot.classList.toggle('clear', ui.screen === 'title'));
mo.observe(uiRoot, { childList: true });

runLegacyMigration(window); // vecchio salvataggio dell'app (origine file://), se l'app iOS lo passa
career.load();
if (career.s) { sfx.on = career.s.settings.sound; }
toMenu('title');
requestAnimationFrame(frame);
loadMusicLater();
window.__G = G; window.__career = career; window.__view = view; window.__ui = ui; window.__start = startMatch; window.__enter = enterMatch; window.__assets = assets; window.__sfx = sfx;
