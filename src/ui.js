// Menu e schermate della carriera (HTML sopra la scena 3D).
import { FORMATIONS, headingOf } from './sim.js';
import { UI_CSS } from './ui-style.js';
import { DIV_NAMES, POS_NAME, KITS, overall, overallAs, value, fmtMoney } from './career.js';
import { Editor } from './editor.js';
import { crestSvg, crestFromSeed } from './crest.js';

const hex = n => '#' + n.toString(16).padStart(6, '0');
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
// statistiche nella scheda giocatore; 'fis' è la resistenza, 'tes' i colpi di testa (calcolati se il salvataggio è vecchio)
const STATS = [['vel', 'VEL'], ['fis', 'RES'], ['tir', 'TIR'], ['pas', 'PAS'], ['dri', 'DRI'], ['dif', 'DIF'], ['tes', 'TES']];
const statOf = (p, k) => (k === 'tes' ? headingOf(p) : p[k]);
const ovrCls = o => (o >= 75 ? 'o4' : o >= 65 ? 'o3' : o >= 55 ? 'o2' : 'o1');


// stemma di una squadra (src/crest.js): sagoma, motivo e simbolo, coi colori della maglia
const crestK = (c, kit, cls = '') => { const k = KITS[kit] || KITS[0]; return crestSvg(c, k[1], k[2], cls); };
const shirt = k => `<svg viewBox="0 0 40 40" aria-hidden="true"><path d="M13 4q7 5 14 0l10 5 4 9-6 3-2-3v18H9V18l-2 3-6-3 4-9z" fill="${hex(k[1])}" stroke="#fff" stroke-opacity=".5" stroke-width="1.4" stroke-linejoin="round"/><path d="M13 4q7 5 14 0" fill="none" stroke="${hex(k[2])}" stroke-width="2.6"/><path d="M1 18l6 3M39 18l-6 3" stroke="${hex(k[2])}" stroke-width="3"/></svg>`;
const ico = d => `<svg viewBox="0 0 24 24" aria-hidden="true">${d}</svg>`;
const ICONS = {
  squad: ico('<path d="M8 3l-5 3 2 4 3-1v11h8V9l3 1 2-4-5-3c-1 2-2 3-4 3S9 5 8 3z"/>'),
  market: ico('<path d="M4 8h14M14 4l4 4-4 4M20 16H6m4-4l-4 4 4 4"/>'),
  table: ico('<path d="M5 20V10M12 20V4M19 20v-7"/>'),
  calendar: ico('<rect x="3.5" y="5" width="17" height="15" rx="3"/><path d="M3.5 10h17M8 3v4M16 3v4"/>'),
  friendly: ico('<circle cx="12" cy="12" r="9"/><path d="M12 8l3.5 2.5-1.3 4h-4.4l-1.3-4z"/>'),
  vs: ico('<circle cx="8" cy="8" r="3"/><circle cx="16" cy="9" r="3"/><path d="M2.5 20c0-4 2.5-6 5.5-6s5.5 2 5.5 6M14 14.5c.7-.3 1.4-.5 2-.5 3 0 5.5 2 5.5 6"/>'),
  howto: ico('<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 115 0c0 1.7-2.5 2-2.5 4M12 17h.01"/>'),
  settings: ico('<path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2.2"/><circle cx="9" cy="17" r="2.2"/>'),
};
const PLAY = '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 4.5v15l13-7.5z" fill="currentColor"/></svg>';
const HOW_ILL = [
  '<path d="M16 62C28 14 58 14 62 48"/><path d="M52 42l10 8 6-12"/><circle cx="16" cy="62" r="6"/>',
  '<circle cx="40" cy="40" r="7"/><circle cx="40" cy="40" r="19" opacity=".6"/><circle cx="40" cy="40" r="31" opacity=".3"/>',
  '<path d="M40 8l25 10v22c0 16-12 26-25 32C27 66 15 56 15 40V18z"/><path d="M28 40l8 8 16-16"/>',
  '<path d="M14 58L60 26"/><path d="M45 24l17 1-6 16"/><circle cx="14" cy="58" r="5"/>',
  '<path d="M10 66V22h60v44"/><path d="M10 34h60M30 22v12M50 22v12" opacity=".35"/><circle cx="40" cy="52" r="8"/>',
];
const TROPHY = '<svg class="trophy" viewBox="0 0 64 64" aria-hidden="true"><path d="M18 8h28v14c0 9-6 16-14 16s-14-7-14-16z" fill="#ffd93d"/><path d="M18 12H8c0 9 4 14 12 15M46 12h10c0 9-4 14-12 15" fill="none" stroke="#ffd93d" stroke-width="3.5"/><path d="M28 38h8v8h-8z" fill="#e0b412"/><rect x="20" y="46" width="24" height="8" rx="3" fill="#ffd93d"/><path d="M24 14v10" stroke="#fff" stroke-opacity=".5" stroke-width="3" stroke-linecap="round"/></svg>';
const BALL = '<svg class="ballmark" viewBox="0 0 64 64" aria-hidden="true"><circle cx="32" cy="32" r="29" fill="#f6f8fc"/><path d="M32 19l11 8-4 13H25l-4-13z" fill="#111827"/><path d="M32 19V6M43 27l13-4M39 40l8 11M25 40l-8 11M21 27L8 23" stroke="#111827" stroke-width="2.4" fill="none" stroke-linecap="round"/><circle cx="32" cy="32" r="29" fill="none" stroke="#ffd93d" stroke-width="3"/></svg>';
const PITCH = '<svg class="pitch" viewBox="0 0 400 300" aria-hidden="true" fill="none" stroke="#ffffff" stroke-opacity=".12" stroke-width="2"><rect x="20" y="10" width="360" height="280" rx="8"/><path d="M20 150h360"/><circle cx="200" cy="150" r="46"/><rect x="120" y="10" width="160" height="56"/><rect x="120" y="234" width="160" height="56"/></svg>';

export const HOWTO = [
  ['Correre e tirare', 'Col pallone <b>disegna la strada</b> partendo dal tuo giocatore: lui la segue, e con tanta strada davanti <b>scatta</b>. Se la linea <b>finisce dentro la porta</b> è un tiro; curvala per tirare a giro.'],
  ['Duello e passaggio', 'Quando arrivi addosso a un difensore la visuale si abbassa e il tempo rallenta: <b>disegna fino a un compagno</b> con l’anello verde per passare, oppure tocca <b>Dribbling</b> per saltarlo. Col pallone, <b>scorri veloce di lato</b> per la finta.'],
  ['Difesa', 'In difesa <b>disegna una linea dai tuoi giocatori</b> (tutti tranne il portiere): corrono lungo la strada che tracci, per chiudere l’avversario o tagliare la linea del passaggio. Ogni difensore intercetta in un piccolo raggio: più largo se è bravo in difesa, più stretto se chi passa è bravo nei passaggi. Tocca un compagno per comandarlo.'],
  ['Scivolata', '<b>Scorri veloce</b> nella direzione in cui vuoi entrare. Se prendi la palla è tua; se prendi prima l\'uomo è fallo, da dietro è cartellino. Se sbagli il tempo resti a terra.'],
  ['Portiere', 'Quando tirano la visuale va dietro la tua porta e il tempo rallenta: <b>tira una linea dal portiere al punto della porta</b> dove arriva la palla e alza il dito al momento giusto. Più la palla è lontana dal portiere, più è difficile arrivarci.'],
];

export class UI {
  constructor(root, career, api) {
    this.ed = new Editor(this);
    this.root = root; this.c = career; this.api = api; this.screen = ''; this.sel = null; this.tabDiv = null; this.mfilter = 'T'; this.kit = 0; this.msg = '';
    if (typeof document !== 'undefined') { const st = document.createElement('style'); st.textContent = UI_CSS; document.head.appendChild(st); }
    root.addEventListener('click', e => {
      const t = e.target.closest('[data-a]'); if (!t) return;
      api.click(); this.act(t.dataset.a, t.dataset.v, t);
    });
  }
  hide() { this.ed.unmount(); this.root.style.display = 'none'; this.screen = ''; }
  tcrest(t, cls) { return crestK(this.c.teamCrest(t), t.kit, cls); }
  editor() { return this.ed.html(); }
  show(name, arg) {
    if (name !== 'editor') this.ed.unmount();
    this.screen = name; this.arg = arg; this.root.style.display = 'block';
    const s = this.c.s, k = s ? KITS[s.kit] : KITS[this.kit]; if (k) { this.root.style.setProperty('--k1', hex(k[1])); this.root.style.setProperty('--k2', hex(k[2])); }
    const fresh = !this.quiet; this.quiet = false;
    this.root.innerHTML = '<div class="scr' + (fresh ? ' in' : '') + '">' + this[name](arg) + '</div>'; this.root.firstChild.scrollTop = this.keepScroll || 0; this.keepScroll = 0;
    if (name === 'editor') this.ed.mount(this.root); }
  redraw() { this.quiet = true; const sc = this.root.firstChild ? this.root.firstChild.scrollTop : 0; this.keepScroll = sc; this.show(this.screen, this.arg); }
  toast(m) { this.msg = m; this.redraw(); this.msg = ''; }

  act(a, v, el) {
    const c = this.c, s = c.s;
    if (a.startsWith('ed') && this.ed.act(a, v, el)) return;
    switch (a) {
      case 'go': this.sel = null; this.show(v); break;
      case 'kit': this.quiet = true; this.kit = +v; this.nameVal = this.root.querySelector('#club') ? this.root.querySelector('#club').value : ''; this.show('title', 'new'); break;
      case 'new': this.show('title', 'new'); break;
      case 'create': { const n = (this.root.querySelector('#club').value || '').trim().slice(0, 18) || 'FC Tiro a Giro'; this.nameVal = n; this.ed.openNew(n, this.kit); this.show('editor'); break; }
      case 'edlook': if (this.ed.openLook(+v)) this.show('editor'); break;
      case 'edkit': this.ed.openKit(); this.show('editor'); break;
      case 'edcrest': this.ed.openCrest(); this.show('editor'); break;
      case 'howto': if (+v >= HOWTO.length) this.show('hub'); else this.show('howto', +v); break;
      case 'tutorial': this.api.play('tutorial'); break;
      case 'play': this.api.play('league'); break;
      case 'friendly': this.api.play('friendly', +v); break;
      case 'form': s.formation = v; c.autoLineup(); c.save(); this.sel = null; this.redraw(); break;
      case 'auto': c.autoLineup(); c.save(); this.sel = null; this.redraw(); break;
      case 'pl': { const id = +v; if (this.sel === null) this.sel = id; else if (this.sel === id) this.sel = null; else { const st = s.lineup.includes(this.sel) || s.lineup.includes(id); if (st) { c.swap(this.sel, id); this.sel = null; } else this.sel = id; } this.redraw(); break; }
      case 'sell': { const p = c.player(+v); if (el.dataset.ok !== '1') { el.dataset.ok = '1'; el.textContent = 'Conferma: vendi per ' + fmtMoney(c.sellPrice(p)); el.classList.add('warn'); return; } const err = c.sell(+v); this.sel = null; if (err) this.toast(err); else this.redraw(); break; }
      case 'buy': { if (el.dataset.ok !== '1') { el.dataset.ok = '1'; el.textContent = 'Conferma'; el.classList.add('warn'); return; } const err = c.buy(+v); if (err) this.toast(err); else this.toast('Acquistato!'); break; }
      case 'mf': this.mfilter = v; this.redraw(); break;
      case 'mrow': this.sel = this.sel === +v ? null : +v; this.redraw(); break;
      case 'tab': this.tabDiv = +v; this.redraw(); break;
      case 'set': { const [k, val] = v.split(':'); s.settings[k] = val === 'true' ? true : val === 'false' ? false : +val; c.save(); this.api.settings(); this.redraw(); break; }
      case 'wipe': if (el.dataset.ok !== '1') { el.dataset.ok = '1'; el.textContent = 'Sicuro? Tocca di nuovo per cancellare tutto'; return; } c.reset(); this.show('title'); break;
      case 'continue': this.show('hub'); break;
      default: this.api.act(a, v, el);
    }
  }

  // ------------------------------------------------ schermate
  title(mode) {
    const has = !!this.c.s;
    if (mode !== 'new' && has) return `<div class="hero">${PITCH}${BALL}<div class="logo">TIRO<span>A</span>GIRO</div><p class="sub">Disegna la giocata. Vinci il campionato.</p><div class="claim"><i>CAMPIONATO</i><i>MERCATO</i><i>A UN DITO</i></div></div>
      <button class="btn big" data-a="continue">Continua carriera</button><button class="btn ghost" data-a="new">Nuova carriera</button>`;
    return `<div class="hero small">${PITCH}${BALL}<div class="logo">TIRO<span>A</span>GIRO</div></div>
      <div class="card"><div class="newhead">${crestK(crestFromSeed(this.kit * 7 + 3), this.kit)}<div class="dim">Crea la tua squadra e parti dalla Terza Divisione.</div></div>
      <label>Nome della tua squadra</label><input id="club" maxlength="18" placeholder="es. Atletico Sole" value="${esc(this.nameVal || '')}" autocomplete="off">
      <label>Colori <b>${KITS[this.kit][0]}</b></label><div class="kits">${KITS.map((k, i) => `<div class="kit ${i === this.kit ? 'on' : ''}" data-a="kit" data-v="${i}" role="button" aria-label="${k[0]}">${shirt(k)}</div>`).join('')}</div></div>
      <button class="btn big" data-a="create">Avanti: stemma e campione</button>${has ? '<button class="btn ghost" data-a="continue">Annulla</button><p class="note">Una nuova carriera sostituisce quella salvata.</p>' : ''}`;
  }

  head(title, back = 'hub') { const k = this.c.s.kit; return `<div class="top"><button class="back" data-a="go" data-v="${back}" aria-label="Indietro">‹</button><h2>${title}</h2><div class="money">${fmtMoney(this.c.s.money)}</div></div>${this.msg ? `<div class="flash">${esc(this.msg)}</div>` : ''}`; }

  hub() {
    const c = this.c, s = c.s, nm = c.nextMatch(), d = c.div(), tab = c.table(d), pos = tab.findIndex(t => t.id === 'me') + 1;
    const tile = (a, v, ic, t, sub) => `<button class="tile" data-a="${a}" data-v="${v}"><span class="ic">${ICONS[ic]}</span><b>${t}</b><span>${sub}</span></button>`;
    const me = s.teams.me, last = s.last ? (s.last.my > s.last.op ? 'w' : s.last.my < s.last.op ? 'l' : 'd') : '';
    return `<div class="clubbar">${this.tcrest(me)}<div><h1>${esc(s.club)}</h1><div class="dim">${DIV_NAMES[d]} · Stagione ${s.season} · <b style="color:var(--gold)">${pos}°</b> posto</div></div></div>
    ${nm ? `<div class="card next"><div class="nx-top"><span class="lbl">Giornata ${nm.day} di 18</span><span class="pill ${nm.home ? 'gold' : ''}">${nm.home ? 'In casa' : 'In trasferta'}</span></div>
      <div class="vs"><div>${this.tcrest(me, 'lg')}<b>${esc(s.club)}</b><span>forza <em>${c.myRating()}</em></span></div><i>VS</i><div>${this.tcrest(nm.opp, 'lg')}<b>${esc(nm.opp.name)}</b><span>forza <em>${nm.opp.rating}</em></span></div></div>
      <div class="prog"><i style="width:${Math.round((nm.day - 1) / 18 * 100)}%"></i></div>
      <button class="btn big play" data-a="play">${PLAY}Gioca</button></div>` : ''}
    ${s.last ? `<div class="last"><span class="wl ${last}">${last === 'w' ? 'V' : last === 'l' ? 'S' : 'P'}</span><span>Ultima: ${esc(s.club)} <b style="color:var(--txt)">${s.last.my} – ${s.last.op}</b> ${esc(s.last.opp)}</span></div>` : ''}
    <div class="grid">${tile('go', 'squad', 'squad', 'Rosa', 'Formazione e titolari')}${tile('go', 'market', 'market', 'Mercato', 'Compra e vendi')}${tile('go', 'table', 'table', 'Classifica', pos + '° su 10')}${tile('go', 'calendar', 'calendar', 'Calendario', 'Risultati e prossime')}${tile('go', 'friendly', 'friendly', 'Amichevole', 'Allenati senza rischi')}${tile('go', 'vsfriend', 'vs', '1 contro 1', 'Sfida un amico')}${tile('howto', 0, 'howto', 'Come si gioca', 'I comandi')}${tile('go', 'settings', 'settings', 'Impostazioni', 'Durata, difficoltà')}</div>`;
  }

  prow(p, slotPos, extra = '') {
    const o = slotPos ? overallAs(p, slotPos) : overall(p), off = slotPos && slotPos !== p.pos;
    return `<div class="prow ${this.sel === p.id ? 'sel' : ''}" data-a="pl" data-v="${p.id}"><span class="pos p${slotPos || p.pos}">${POS_NAME[slotPos || p.pos]}</span><span class="pn">${esc(p.name)}${off ? ` <em>(${POS_NAME[p.pos]})</em>` : ''}</span><span class="age">${p.age}a</span><span class="ovr ${ovrCls(o)}">${o}</span>${extra}</div>`;
  }
  pcard(p, btn) {
    return `<div class="pcard"><div class="pc1"><b>${esc(p.name)}</b><span>${POS_NAME[p.pos]} · ${p.age} anni · valore ${fmtMoney(value(p))}${p.num ? ` · n. ${p.num}` : ''}${p.apps !== undefined && p.apps > 0 ? ` · ${p.apps} pres. ${p.goals} gol` : ''}</span></div>
      <div class="stats">${(p.pos === 'P' ? [['por', 'POR'], ['pas', 'PAS'], ['fis', 'RES'], ['vel', 'VEL']] : STATS).map(([k, n]) => { const v = statOf(p, k); return `<div class="${ovrCls(v)}"><i>${n}</i><b>${v}</b><u style="--w:${Math.max(6, Math.min(100, v))}%"></u></div>`; }).join('')}</div>${btn || ''}</div>`;
  }

  squad() {
    const c = this.c, s = c.s, F = FORMATIONS[s.formation], sp = this.sel !== null ? c.player(this.sel) : null;
    return this.head('Rosa') + `<div class="chips">${Object.keys(FORMATIONS).map(f => `<button class="chip ${f === s.formation ? 'on' : ''}" data-a="form" data-v="${f}">${f}</button>`).join('')}<button class="chip" data-a="auto">Migliori 11</button></div>
    <p class="note">Tocca due giocatori per scambiarli. Forza della squadra: <b style="color:var(--gold)">${c.myRating()}</b></p>
    ${sp ? this.pcard(sp, `<div class="pbtns"><button class="btn sm" data-a="edlook" data-v="${sp.id}">Aspetto</button><button class="btn ghost sm" data-a="sell" data-v="${sp.id}">Vendi per ${fmtMoney(c.sellPrice(sp))}</button></div>`) : ''}
    <h3>Titolari</h3>${s.lineup.map((id, i) => this.prow(c.player(id), F[i][0])).join('')}
    <h3>Panchina</h3>${c.bench().sort((a, b) => 'PDCA'.indexOf(a.pos) - 'PDCA'.indexOf(b.pos) || overall(b) - overall(a)).map(p => this.prow(p)).join('')}`;
  }

  market() {
    const c = this.c, s = c.s, f = this.mfilter;
    const list = s.market.filter(p => f === 'T' || p.pos === f).sort((a, b) => overall(b) - overall(a));
    return this.head('Mercato') + `<div class="chips">${[['T', 'Tutti'], ['P', 'POR'], ['D', 'DIF'], ['C', 'CEN'], ['A', 'ATT']].map(([k, n]) => `<button class="chip ${f === k ? 'on' : ''}" data-a="mf" data-v="${k}">${n}</button>`).join('')}</div>
    <p class="note">Rosa: ${s.squad.length}/24. Ogni giornata arrivano giocatori nuovi. Per vendere vai in <b>Rosa</b> e tocca un giocatore.</p>
    ${list.map(p => { const o = overall(p), open = this.sel === p.id, can = s.money >= p.price; return `<div class="prow ${open ? 'sel' : ''}" data-a="mrow" data-v="${p.id}"><span class="pos p${p.pos}">${POS_NAME[p.pos]}</span><span class="pn">${esc(p.name)}</span><span class="age">${p.age}a</span><span class="ovr ${ovrCls(o)}">${o}</span><span class="price ${can ? '' : 'no'}">${fmtMoney(p.price)}</span></div>${open ? this.pcard(p, can ? `<button class="btn sm" data-a="buy" data-v="${p.id}">Compra per ${fmtMoney(p.price)}</button>` : '<p class="note">Non hai abbastanza soldi.</p>') : ''}`; }).join('')}`;
  }

  table() {
    const c = this.c, d = this.tabDiv === null ? c.div() : this.tabDiv, t = c.table(d);
    return this.head('Classifica') + `<div class="chips">${DIV_NAMES.map((n, i) => `<button class="chip ${i === d ? 'on' : ''}" data-a="tab" data-v="${i}">${n.split(' ')[0]}</button>`).join('')}</div>
    <table class="tbl"><tr><th></th><th class="l">SQUADRA</th><th>G</th><th>V</th><th>N</th><th>P</th><th>DR</th><th>PT</th></tr>
    ${t.map((r, i) => { const tm = c.team(r.id), dr = r.gf - r.ga; return `<tr class="${r.id === 'me' ? 'me' : ''} ${i < 2 && d > 0 ? 'up' : ''} ${i >= 8 && d < 2 ? 'dn' : ''} ${i === 0 && d === 0 ? 'up' : ''}"><td>${i + 1}</td><td class="l"><span>${this.tcrest(tm, 'xs')}<em>${esc(tm.name)}</em></span></td><td>${r.p}</td><td>${r.w}</td><td>${r.d}</td><td>${r.l}</td><td>${dr > 0 ? '+' : ''}${dr}</td><td><b>${r.pts}</b></td></tr>`; }).join('')}</table>
    <div class="legend">${d > 0 || d === 0 ? `<span><i style="background:var(--good)"></i>${d > 0 ? 'Promozione' : 'Titolo'}</span>` : ''}${d < 2 ? '<span><i style="background:var(--bad)"></i>Retrocessione</span>' : ''}</div>
    <p class="note">${d > 0 ? 'Le prime due salgono di divisione. ' : 'La prima vince il titolo. '}${d < 2 ? 'Le ultime due retrocedono.' : ''}</p>`;
  }

  calendar() {
    const c = this.c, s = c.s, d = c.div();
    return this.head('Calendario') + s.fix[d].map((round, i) => {
      const m = round.find(x => x[0] === 'me' || x[1] === 'me'), home = m[0] === 'me', opp = c.team(home ? m[1] : m[0]), r = (s.res || [])[i];
      return `<div class="prow ${i === s.day ? 'sel' : ''}"><span class="cal">${i + 1}</span><span class="pn cr">${this.tcrest(opp, 'xs')}${home ? 'Casa' : 'Fuori'} · ${esc(opp.name)}</span><span class="age">forza ${opp.rating}</span><span class="ovr ${r ? (r[0] > r[1] ? 'o3' : r[0] < r[1] ? 'bad' : 'o2') : ''}" style="min-width:52px">${r ? r[0] + '–' + r[1] : '·'}</span></div>`;
    }).join('');
  }

  friendly() {
    const opt = (v, n, lv) => `<button class="btn opp" data-a="friendly" data-v="${v}"><span>${n}</span><span class="lv">${[1, 2, 3].map(i => `<i class="${i <= lv ? 'on' : ''}"></i>`).join('')}</span></button>`;
    return this.head('Amichevole') + `<p class="note">Partita di prova: non conta per il campionato e non cambia i soldi.</p>
    ${opt(46, 'Avversario facile', 1)}${opt(58, 'Avversario medio', 2)}${opt(72, 'Avversario forte', 3)}`;
  }
  vsfriend() {
    return this.head('1 contro 1') + `<div class="card"><p>La sfida tra due iPhone vicini (senza internet) arriva con il prossimo aggiornamento.</p><p class="dim">Il motore di gioco è già pronto per due giocatori: manca il collegamento tra i telefoni.</p></div>`;
  }

  settings() {
    const st = this.c.s.settings, opt = (k, vals) => `<div class="chips">${vals.map(([v, n]) => `<button class="chip ${String(st[k]) === String(v) ? 'on' : ''}" data-a="set" data-v="${k}:${v}">${n}</button>`).join('')}</div>`;
    return this.head('Impostazioni') + `<h3>Durata di un tempo</h3>${opt('half', [[90, '1:30'], [150, '2:30'], [240, '4:00'], [360, '6:00']])}
    <h3>Difficoltà avversari</h3>${opt('diff', [[0, 'Facile'], [1, 'Normale'], [2, 'Difficile']])}
    <h3>Portiere</h3>${opt('autoGk', [[false, 'Manuale (tuffo col dito)'], [true, 'Automatico']])}
    <h3>Audio</h3>${opt('sound', [[true, 'Acceso'], [false, 'Spento']])}
    <h3>Squadra</h3><div class="pbtns"><button class="btn" data-a="edkit">Stile della divisa</button><button class="btn" data-a="edcrest">${this.tcrest(this.c.s.teams.me, 'xs')}Stemma</button></div>
    <h3>Carriera</h3><button class="btn ghost" data-a="wipe">Cancella la carriera salvata</button>`;
  }

  howto(i) {
    const [t, x] = HOWTO[i];
    return `<div class="how"><div class="stepbar"><div class="dots">${HOWTO.map((_, n) => `<i class="${n === i ? 'on' : ''}"></i>`).join('')}</div><div class="dim">${i + 1} / ${HOWTO.length}</div></div><div class="ill"><svg viewBox="0 0 80 80">${HOW_ILL[i]}</svg></div><h1>${t}</h1><p>${x}</p>${i + 1 < HOWTO.length ? '' : '<button class="btn big" data-a="tutorial">Prova in campo</button>'}<button class="btn ${i + 1 < HOWTO.length ? 'big' : ''}" data-a="howto" data-v="${i + 1}">${i + 1 < HOWTO.length ? 'Avanti' : 'Ho capito, vai al menu'}</button>${this.c.s ? '<button class="btn ghost" data-a="go" data-v="hub">Salta</button>' : ''}</div>`;
  }

  // dopo la partita
  post(r) {
    const s = this.c.s, m = r.m, vd = m.score[0] > m.score[1] ? ['w', 'VITTORIA'] : m.score[0] < m.score[1] ? ['l', 'SCONFITTA'] : ['d', 'PAREGGIO'];
    const sc = m.goalsLog.map(g => `<div class="${g.team === 0 ? 'gl' : 'gr'}">${g.team === 0 ? `${esc(g.name)} ${g.minute}'` : `${g.minute}' ${esc(g.name)}`}</div>`).join('');
    const st = (n, a, b) => { const fa = parseFloat(a) || 0, fb = parseFloat(b) || 0; return `<div class="st"><b>${a}</b><span>${n}</span><b>${b}</b><div class="bar"><i style="--f:${fa || (fb ? 0.01 : 1)}"></i><i style="--f:${fb || (fa ? 0.01 : 1)}"></i></div></div>`; }, ps = m.stats.poss[0] + m.stats.poss[1] || 1;
    return `<div class="res"><div class="dim">${r.title}</div><div class="scoreboard"><div class="score"><span>${this.mcrest(m.teams[0])}${esc(m.teams[0].short)}</span><b>${m.score[0]} – ${m.score[1]}</b><span>${this.mcrest(m.teams[1])}${esc(m.teams[1].short)}</span></div><div class="verdict ${vd[0]}">${vd[1]}</div><div class="scorers">${sc}</div></div>
    ${st('Tiri', m.stats.shots[0], m.stats.shots[1])}${st('In porta', m.stats.onT[0], m.stats.onT[1])}${st('Possesso', Math.round(m.stats.poss[0] / ps * 100) + '%', Math.round(m.stats.poss[1] / ps * 100) + '%')}${st('Angoli', m.stats.corners[0], m.stats.corners[1])}${st('Falli', m.stats.fouls[0], m.stats.fouls[1])}</div>
    ${r.res ? `<div class="card"><div class="st"><span>Incasso partita</span><b class="good">+${fmtMoney(r.res.income)}</b></div><div class="st"><span>Stipendi</span><b class="bad">−${fmtMoney(r.res.wages)}</b></div><div class="st"><span>Cassa</span><b>${fmtMoney(s.money)}</b></div>
      ${r.res.grown.length ? `<p class="note">Migliorati: ${r.res.grown.map(esc).join(', ')}</p>` : ''}
      ${r.res.others.length ? `<p class="note">Altri risultati: ${r.res.others.map(o => `${o[0]} ${o[1]}–${o[2]} ${o[3]}`).join(' · ')}</p>` : ''}</div>` : ''}
    <button class="btn big" data-a="${r.res && r.res.season ? 'season' : 'continue'}">Continua</button>`;
  }
  mcrest(t) { const c = t.kit && t.kit.crest; return c ? crestSvg(c, c.c1, c.c2, 'sm') : ''; }
  season(r) {
    const t = r.outcome === 'up' ? 'PROMOSSI!' : r.outcome === 'down' ? 'Retrocessi' : r.outcome === 'champ' ? 'CAMPIONI!' : 'Stagione finita';
    return `<div class="how season">${r.outcome === 'down' ? '' : TROPHY}<h1>${t}</h1><p>Hai chiuso al <b>${r.pos}° posto</b> in ${DIV_NAMES[r.div]}.</p><p>Premio di fine stagione: <b>${fmtMoney(r.prize + r.bonus)}</b></p><p>La prossima stagione giochi in <b>${DIV_NAMES[r.newDiv]}</b>. I giocatori hanno un anno in più: controlla la rosa e il mercato.</p><button class="btn big" data-a="continue">Avanti</button></div>`;
  }
}
