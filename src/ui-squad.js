// Schermata Rosa: campo visto dall'alto con le carte degli 11 titolari nei posti della formazione, panchina
// scorrevole sotto, in alto le formazioni oppure il pannello del giocatore scelto o il confronto tra due giocatori.
// Tocchi: uno sceglie un giocatore, un secondo (che con lui si può scambiare) apre il confronto, toccarlo ancora
// (o "Scambia") li scambia. La schermata è ferma: niente scorrimento verticale.
import { FORMATIONS } from './sim.js';
import { POS_NAME, KITS, overall, overallAs, value, fmtMoney } from './career.js';
import { lookOf } from './looks.js';
import { faceSvg } from './face2d.js';
import { fieldLayout, canSwap, swapDelta, CARD_W, CARD_H } from './squad-layout.js';
import { hex, esc, STATS, GK_STATS, statOf, ovrCls } from './ui-util.js';

const ROLE_ORDER = 'PDCA';
const SHORT_NAME_MAX = 10;

// nome breve per la carta: "L. Ferrante" → "Ferrante"; un nome lungo con spazi → l'ultima parola
export function shortName(name) {
  const s = String(name || '').replace(/^.*\.\s*/, '').trim();
  return s.length > SHORT_NAME_MAX && s.includes(' ') ? s.split(/\s+/).pop() : s;
}

// panchina in ordine: ruolo (portieri prima) e poi valutazione
export function benchOrder(list) {
  return list.slice().sort((a, b) => ROLE_ORDER.indexOf(a.pos) - ROLE_ORDER.indexOf(b.pos) || overall(b) - overall(a));
}

// gestione dei tocchi sulle carte (stato in ui.sel = scelto, ui.tgt = confronto, ui.just = appena scambiati)
export function pickCard(ui, id) {
  const c = ui.c, lineup = c.s.lineup;
  ui.just = null;
  if (ui.sel === null || !c.player(ui.sel)) { ui.sel = id; ui.tgt = null; return; }
  if (ui.sel === id) { ui.sel = null; ui.tgt = null; return; }
  if (ui.tgt === id) { c.swap(ui.sel, id); ui.just = [ui.sel, id]; ui.sel = null; ui.tgt = null; return; }
  if (canSwap(lineup, ui.sel, id)) { ui.tgt = id; return; }
  ui.sel = id; ui.tgt = null; // panchina → panchina: si sceglie l'altro
}

function shirtColors(c) { const k = KITS[c.s.kit] || KITS[0]; return [hex(k[1]), hex(k[2])]; }

// una carta: valutazione nel ruolo del posto, ruolo, ritratto, nome breve; fuori ruolo = ruolo vero in arancio
function card(ui, p, slotPos, extra) {
  const role = slotPos || p.pos, o = slotPos ? overallAs(p, slotPos) : overall(p), off = slotPos && slotPos !== p.pos;
  const cls = ['fc', 't-' + ovrCls(o)];
  if (ui.sel === p.id) cls.push('sel');
  if (ui.tgt === p.id) cls.push('tgt');
  if (ui.just && ui.just.includes(p.id)) cls.push('just');
  const [k1, k2] = extra.colors, d = extra.delta;
  return `<div class="${cls.join(' ')}" data-a="pl" data-v="${p.id}"${extra.slot !== undefined ? ` data-i="${extra.slot}"` : ''} role="button" aria-label="${esc(p.name)}, ${POS_NAME[role]} ${o}">`
    + `<span class="fr"><b class="${ovrCls(o)}">${o}</b><i class="pos p${role}">${POS_NAME[role]}</i></span>`
    + `<span class="fp">${faceSvg(lookOf(p), k1, k2)}</span>`
    + (off ? `<i class="foff" title="Fuori ruolo">${POS_NAME[p.pos]}</i>` : '')
    + (d !== null ? `<i class="fd ${d > 0 ? 'up' : d < 0 ? 'dn' : 'eq'}">${d > 0 ? '+' : d < 0 ? '−' : '='}${d ? Math.abs(d) : ''}</i>` : '')
    + `<span class="fn">${esc(shortName(p.name))}</span></div>`;
}

const PITCH_LINES = '<div class="fl"><i class="fh"></i><i class="fcc"></i><i class="fb t"></i><i class="fb b"></i></div>';

function lineupSum(c, lineup, F) {
  return lineup.reduce((t, id, i) => { const p = c.player(id); return t + (p ? overallAs(p, F[i][0]) : 30); }, 0);
}

// ruolo e valutazione di un giocatore dove sta adesso (posto in campo o panchina)
function placeOf(c, F, p) {
  const i = c.s.lineup.indexOf(p.id);
  return i >= 0 ? { role: F[i][0], o: overallAs(p, F[i][0]), where: POS_NAME[F[i][0]] } : { role: p.pos, o: overall(p), where: 'Panchina' };
}

function topControls(ui) {
  const c = ui.c, s = c.s;
  return `<div class="forms">${Object.keys(FORMATIONS).map(f => `<button class="chip ${f === s.formation ? 'on' : ''}" data-a="form" data-v="${f}">${f}</button>`).join('')}</div>
    <div class="sqinfo"><span class="force">Forza squadra <b>${c.myRating()}</b></span><button class="chip best" data-a="auto">Migliori 11</button></div>
    <p class="note sqhint">Tocca un giocatore per vederlo, poi un altro per confrontarli e scambiarli.</p>`;
}

function playerPanel(ui, p, colors) {
  const c = ui.c, F = FORMATIONS[c.s.formation], at = placeOf(c, F, p);
  const keys = p.pos === 'P' ? GK_STATS : STATS;
  return `<div class="spanel"><div class="sph"><span class="fp lg">${faceSvg(lookOf(p), colors[0], colors[1])}</span>
      <div class="spn"><b>${esc(p.name)}</b><span>${POS_NAME[p.pos]}${at.where !== POS_NAME[p.pos] ? ` · in campo ${at.where}` : ''} · ${p.age} anni · ${fmtMoney(value(p))}${p.num ? ` · n. ${p.num}` : ''}</span></div>
      <span class="ovr ${ovrCls(at.o)}">${at.o}</span><button class="sx" data-a="unsel" aria-label="Chiudi">×</button></div>
    <div class="srow" style="--n:${keys.length}">${keys.map(([k, n]) => { const v = statOf(p, k); return `<div class="${ovrCls(v)}"><i>${n}</i><b>${v}</b></div>`; }).join('')}</div>
    <div class="pbtns"><button class="btn sm" data-a="edlook" data-v="${p.id}">Aspetto</button><button class="btn ghost sm" data-a="sell" data-v="${p.id}">Vendi per ${fmtMoney(c.sellPrice(p))}</button></div></div>`;
}

// confronto: valori del giocatore scelto (a) e di quello toccato (b), verde chi è meglio, rosso chi è peggio
function comparePanel(ui, a, b, colors) {
  const c = ui.c, s = c.s, F = FORMATIONS[s.formation], pa = placeOf(c, F, a), pb = placeOf(c, F, b);
  const keys = a.pos === 'P' || b.pos === 'P' ? [['por', 'POR'], ...STATS.filter(([k]) => k !== 'tes')] : STATS;
  const now = lineupSum(c, s.lineup, F), after = now + swapDelta(s.lineup, F, a, b, overallAs);
  const rNow = Math.round(now / 11), rAfter = Math.round(after / 11);
  const cell = (x, y) => `<b class="${x > y ? 'good' : x < y ? 'bad' : ''}">${x}</b>`;
  const side = (p, at, r) => `<div class="cside${r ? ' r' : ''}"><span class="fp">${faceSvg(lookOf(p), colors[0], colors[1])}</span><div><b>${esc(shortName(p.name))}</b><span><i class="dot ${r ? 'b' : 'a'}"></i>${at.where} <em class="${ovrCls(at.o)}">${at.o}</em></span></div></div>`;
  return `<div class="spanel cmp"><div class="cmph">${side(a, pa, false)}<i class="cx" aria-hidden="true">⇄</i>${side(b, pb, true)}</div>
    <div class="cgrid" style="--n:${keys.length}"><span></span>${keys.map(([, n]) => `<i>${n}</i>`).join('')}
      <span class="dot a"></span>${keys.map(([k]) => cell(statOf(a, k), statOf(b, k))).join('')}
      <span class="dot b"></span>${keys.map(([k]) => cell(statOf(b, k), statOf(a, k))).join('')}</div>
    <div class="cbtm"><span class="force">Forza ${rNow} → <b class="${rAfter > rNow ? 'good' : rAfter < rNow ? 'bad' : ''}">${rAfter}</b></span><button class="btn ghost sm" data-a="unsel">Annulla</button><button class="btn sm go" data-a="swp">Scambia</button></div></div>`;
}

export function squadHtml(ui) {
  const c = ui.c, s = c.s, F = FORMATIONS[s.formation], colors = shirtColors(c);
  const sp = ui.sel !== null ? c.player(ui.sel) : null, tp = sp && ui.tgt !== null ? c.player(ui.tgt) : null;
  // badge verde/rosso sulle carte: quanto cambia la squadra scambiandole col giocatore scelto. Si mostra per chi
  // gioca nello stesso ruolo e per ogni scambio che migliora; gli scambi assurdi (attaccante in porta) no
  const roleNow = p => { const i = s.lineup.indexOf(p.id); return i >= 0 ? F[i][0] : p.pos; };
  const delta = p => {
    if (!sp || p.id === sp.id || !canSwap(s.lineup, sp.id, p.id)) return null;
    const d = swapDelta(s.lineup, F, sp, p, overallAs);
    return d > 0 || roleNow(p) === roleNow(sp) ? d : null;
  };
  const top = tp ? comparePanel(ui, sp, tp, colors) : sp ? playerPanel(ui, sp, colors) : topControls(ui);
  const field = s.lineup.map((id, i) => { const p = c.player(id); return p ? card(ui, p, F[i][0], { slot: i, colors, delta: delta(p) }) : ''; }).join('');
  const bench = benchOrder(c.bench());
  return `<div class="sq"><div class="sqtop">${top}</div>
    <div class="field">${PITCH_LINES}${field}</div>
    <div class="bench"><div class="blbl">Panchina <em>${bench.length}</em><span>Rosa ${s.squad.length}/24</span></div>
      <div class="brow">${bench.map(p => card(ui, p, null, { colors, delta: delta(p) })).join('')}</div></div></div>`;
}

// scorrimento della panchina da tenere quando la schermata si ridisegna (prima di cambiare l'HTML)
export function benchScroll(root, keep) {
  const br = keep && root.querySelector ? root.querySelector('.brow') : null;
  return br ? br.scrollLeft : 0;
}

// dopo aver messo l'HTML: misura il campo e mette ogni carta al suo posto (prima che la pagina venga disegnata)
export function placeSquad(ui, bench) {
  const root = ui.root, f = root.querySelector('.field'); if (!f) return;
  const F = FORMATIONS[ui.c.s.formation], L = fieldLayout(F, f.clientWidth, f.clientHeight);
  for (const el of f.querySelectorAll('.fc')) {
    const pos = L.cards[+el.dataset.i]; if (!pos) continue;
    el.style.left = (pos.x - L.w / 2).toFixed(1) + 'px';
    el.style.top = (pos.y - L.h / 2).toFixed(1) + 'px';
    if (L.scale < 1) el.style.transform = `scale(${L.scale.toFixed(3)})`;
  }
  const br = root.querySelector('.brow'); if (br) br.scrollLeft = bench || 0;
  // per le prove: misure usate (le carte sono CARD_W × CARD_H a grandezza piena)
  f.dataset.scale = L.scale.toFixed(3); f.dataset.card = CARD_W + 'x' + CARD_H;
}
