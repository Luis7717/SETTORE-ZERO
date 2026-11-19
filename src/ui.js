// Menu e schermate della carriera (HTML sopra la scena 3D).
import { FORMATIONS } from './sim.js';
import { DIV_NAMES, POS_NAME, KITS, overall, overallAs, value, fmtMoney } from './career.js';

const hex = n => '#' + n.toString(16).padStart(6, '0');
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const STATS = [['vel', 'VEL'], ['tir', 'TIR'], ['pas', 'PAS'], ['dri', 'DRI'], ['dif', 'DIF'], ['fis', 'FIS']];
const ovrCls = o => (o >= 75 ? 'o4' : o >= 65 ? 'o3' : o >= 55 ? 'o2' : 'o1');

export const HOWTO = [
  ['Passaggi e tiri', 'Appoggia il dito sul tuo giocatore con la palla e <b>disegna la traiettoria</b>. Il tempo rallenta mentre disegni. La palla va dove finisce la linea: su un compagno, nello spazio o in porta. Se curvi la linea, la palla gira.'],
  ['Muoversi', '<b>Tieni premuto</b> un punto del campo: il giocatore con la palla corre lì. Tocco veloce su un compagno = passaggio diretto.'],
  ['Difesa', 'Senza palla controlli il difensore con l\'anello giallo. <b>Tieni premuto</b> per portarlo dove vuoi: se arrivi sulla palla la rubi, se tagli la linea di passaggio la intercetti. Tocca un compagno per cambiare giocatore.'],
  ['Scivolata', '<b>Scorri veloce</b> nella direzione in cui vuoi entrare. Se prendi la palla è tua; se prendi prima l\'uomo è fallo, da dietro è cartellino. Se sbagli il tempo resti a terra.'],
  ['Portiere', 'Quando tirano il tempo rallenta: <b>scorri verso il lato del tiro</b>. Più lungo è il gesto, più lungo il tuffo; verso l\'alto per i tiri alti. I tiri centrali li blocca da solo.'],
];

export class UI {
  constructor(root, career, api) {
    this.root = root; this.c = career; this.api = api; this.screen = ''; this.sel = null; this.tabDiv = null; this.mfilter = 'T'; this.kit = 0; this.msg = '';
    root.addEventListener('click', e => {
      const t = e.target.closest('[data-a]'); if (!t) return;
      api.click(); this.act(t.dataset.a, t.dataset.v, t);
    });
  }
  hide() { this.root.style.display = 'none'; this.screen = ''; }
  show(name, arg) { this.screen = name; this.arg = arg; this.root.style.display = 'block'; this.root.innerHTML = '<div class="scr">' + this[name](arg) + '</div>'; this.root.firstChild.scrollTop = this.keepScroll || 0; this.keepScroll = 0; }
  redraw() { const sc = this.root.firstChild ? this.root.firstChild.scrollTop : 0; this.keepScroll = sc; this.show(this.screen, this.arg); }
  toast(m) { this.msg = m; this.redraw(); this.msg = ''; }

  act(a, v, el) {
    const c = this.c, s = c.s;
    switch (a) {
      case 'go': this.sel = null; this.show(v); break;
      case 'kit': this.kit = +v; this.nameVal = this.root.querySelector('#club') ? this.root.querySelector('#club').value : ''; this.show('title', 'new'); break;
      case 'new': this.show('title', 'new'); break;
      case 'create': { const n = (this.root.querySelector('#club').value || '').trim().slice(0, 18) || 'FC Tiro a Giro'; c.create(n, this.kit); this.show('howto', 0); break; }
      case 'howto': if (+v >= HOWTO.length) this.show('hub'); else this.show('howto', +v); break;
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
    if (mode !== 'new' && has) return `<div class="hero"><div class="logo">TIRO<span>A</span>GIRO</div><p class="sub">Disegna la giocata. Vinci il campionato.</p></div>
      <button class="btn big" data-a="continue">Continua carriera</button><button class="btn ghost" data-a="new">Nuova carriera</button>`;
    return `<div class="hero small"><div class="logo">TIRO<span>A</span>GIRO</div></div>
      <div class="card"><label>Nome della tua squadra</label><input id="club" maxlength="18" placeholder="es. Atletico Sole" value="${esc(this.nameVal || '')}">
      <label>Colori</label><div class="kits">${KITS.map((k, i) => `<div class="kit ${i === this.kit ? 'on' : ''}" data-a="kit" data-v="${i}" style="background:linear-gradient(135deg,${hex(k[1])} 60%,${hex(k[2])} 60%)"></div>`).join('')}</div></div>
      <button class="btn big" data-a="create">Inizia dalla Terza Divisione</button>${has ? '<button class="btn ghost" data-a="continue">Annulla</button><p class="note">Una nuova carriera sostituisce quella salvata.</p>' : ''}`;
  }

  head(title, back = 'hub') { return `<div class="top"><button class="back" data-a="go" data-v="${back}">‹</button><h2>${title}</h2><div class="money">${fmtMoney(this.c.s.money)}</div></div>${this.msg ? `<div class="flash">${esc(this.msg)}</div>` : ''}`; }

  hub() {
    const c = this.c, s = c.s, nm = c.nextMatch(), d = c.div(), tab = c.table(d), pos = tab.findIndex(t => t.id === 'me') + 1;
    const kit = KITS[s.kit];
    return `<div class="clubbar"><div class="crest" style="background:linear-gradient(135deg,${hex(kit[1])} 55%,${hex(kit[2])} 55%)"></div><div><h1>${esc(s.club)}</h1><div class="dim">${DIV_NAMES[d]} · Stagione ${s.season} · ${pos}° posto</div></div><div class="money">${fmtMoney(s.money)}</div></div>
    ${nm ? `<div class="card next"><div class="dim">Giornata ${nm.day} di 18 · ${nm.home ? 'in casa' : 'in trasferta'}</div>
      <div class="vs"><div><b>${esc(s.club)}</b><span>forza ${c.myRating()}</span></div><i>vs</i><div><b>${esc(nm.opp.name)}</b><span>forza ${nm.opp.rating}</span></div></div>
      <button class="btn big" data-a="play">GIOCA</button></div>` : ''}
    ${s.last ? `<div class="last dim">Ultima: ${esc(s.club)} ${s.last.my} – ${s.last.op} ${esc(s.last.opp)}</div>` : ''}
    <div class="grid"><button class="tile" data-a="go" data-v="squad"><b>Rosa</b><span>Formazione e titolari</span></button>
    <button class="tile" data-a="go" data-v="market"><b>Mercato</b><span>Compra e vendi</span></button>
    <button class="tile" data-a="go" data-v="table"><b>Classifica</b><span>${pos}° su 10</span></button>
    <button class="tile" data-a="go" data-v="calendar"><b>Calendario</b><span>Risultati e prossime</span></button>
    <button class="tile" data-a="go" data-v="friendly"><b>Amichevole</b><span>Allenati senza rischi</span></button>
    <button class="tile" data-a="go" data-v="vsfriend"><b>1 contro 1</b><span>Sfida un amico</span></button>
    <button class="tile" data-a="howto" data-v="0"><b>Come si gioca</b><span>I comandi</span></button>
    <button class="tile" data-a="go" data-v="settings"><b>Impostazioni</b><span>Durata, difficoltà</span></button></div>`;
  }

  prow(p, slotPos, extra = '') {
    const o = slotPos ? overallAs(p, slotPos) : overall(p), off = slotPos && slotPos !== p.pos;
    return `<div class="prow ${this.sel === p.id ? 'sel' : ''}" data-a="pl" data-v="${p.id}"><span class="pos p${slotPos || p.pos}">${POS_NAME[slotPos || p.pos]}</span><span class="pn">${esc(p.name)}${off ? ` <em>(${POS_NAME[p.pos]})</em>` : ''}</span><span class="age">${p.age}a</span><span class="ovr ${ovrCls(o)}">${o}</span>${extra}</div>`;
  }
  pcard(p, btn) {
    return `<div class="pcard"><div class="pc1"><b>${esc(p.name)}</b><span>${POS_NAME[p.pos]} · ${p.age} anni · valore ${fmtMoney(value(p))}${p.apps !== undefined && p.apps > 0 ? ` · ${p.apps} pres. ${p.goals} gol` : ''}</span></div>
      <div class="stats">${(p.pos === 'P' ? [['por', 'POR'], ['pas', 'PAS'], ['fis', 'FIS'], ['vel', 'VEL']] : STATS).map(([k, n]) => `<div><i>${n}</i><b class="${ovrCls(p[k])}">${p[k]}</b></div>`).join('')}</div>${btn || ''}</div>`;
  }

  squad() {
    const c = this.c, s = c.s, F = FORMATIONS[s.formation], sp = this.sel !== null ? c.player(this.sel) : null;
    return this.head('Rosa') + `<div class="chips">${Object.keys(FORMATIONS).map(f => `<button class="chip ${f === s.formation ? 'on' : ''}" data-a="form" data-v="${f}">${f}</button>`).join('')}<button class="chip" data-a="auto">Migliori 11</button></div>
    <p class="note">Tocca due giocatori per scambiarli. Forza della squadra: <b>${c.myRating()}</b></p>
    ${sp ? this.pcard(sp, `<button class="btn ghost sm" data-a="sell" data-v="${sp.id}">Vendi per ${fmtMoney(c.sellPrice(sp))}</button>`) : ''}
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
    <table class="tbl"><tr><th></th><th class="l">Squadra</th><th>G</th><th>V</th><th>N</th><th>P</th><th>DR</th><th>Pt</th></tr>
    ${t.map((r, i) => `<tr class="${r.id === 'me' ? 'me' : ''} ${i < 2 && d > 0 ? 'up' : ''} ${i >= 8 && d < 2 ? 'dn' : ''} ${i === 0 && d === 0 ? 'up' : ''}"><td>${i + 1}</td><td class="l">${esc(c.team(r.id).name)}</td><td>${r.p}</td><td>${r.w}</td><td>${r.d}</td><td>${r.l}</td><td>${r.gf - r.ga > 0 ? '+' : ''}${r.gf - r.ga}</td><td><b>${r.pts}</b></td></tr>`).join('')}</table>
    <p class="note">${d > 0 ? 'Le prime due salgono di divisione. ' : 'La prima vince il titolo. '}${d < 2 ? 'Le ultime due retrocedono.' : ''}</p>`;
  }

  calendar() {
    const c = this.c, s = c.s, d = c.div();
    return this.head('Calendario') + s.fix[d].map((round, i) => {
      const m = round.find(x => x[0] === 'me' || x[1] === 'me'), home = m[0] === 'me', opp = c.team(home ? m[1] : m[0]), r = (s.res || [])[i];
      return `<div class="prow ${i === s.day ? 'sel' : ''}"><span class="pos">${i + 1}</span><span class="pn">${home ? 'Casa' : 'Fuori'} · ${esc(opp.name)}</span><span class="age">forza ${opp.rating}</span><span class="ovr ${r ? (r[0] > r[1] ? 'o4' : r[0] < r[1] ? 'bad' : 'o2') : ''}">${r ? r[0] + '–' + r[1] : ''}</span></div>`;
    }).join('');
  }

  friendly() {
    return this.head('Amichevole') + `<p class="note">Partita di prova: non conta per il campionato e non cambia i soldi.</p>
    <button class="btn" data-a="friendly" data-v="46">Avversario facile</button><button class="btn" data-a="friendly" data-v="58">Avversario medio</button><button class="btn" data-a="friendly" data-v="72">Avversario forte</button>`;
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
    <h3>Carriera</h3><button class="btn ghost" data-a="wipe">Cancella la carriera salvata</button>`;
  }

  howto(i) {
    const [t, x] = HOWTO[i];
    return `<div class="how"><div class="dim">${i + 1} / ${HOWTO.length}</div><h1>${t}</h1><p>${x}</p><button class="btn big" data-a="howto" data-v="${i + 1}">${i + 1 < HOWTO.length ? 'Avanti' : 'Ho capito'}</button>${this.c.s ? '<button class="btn ghost" data-a="go" data-v="hub">Salta</button>' : ''}</div>`;
  }

  // dopo la partita
  post(r) {
    const s = this.c.s, m = r.m;
    const sc = m.goalsLog.map(g => `<div class="${g.team === 0 ? 'gl' : 'gr'}">${g.team === 0 ? `${esc(g.name)} ${g.minute}'` : `${g.minute}' ${esc(g.name)}`}</div>`).join('');
    const st = (n, a, b) => `<div class="st"><b>${a}</b><span>${n}</span><b>${b}</b></div>`, ps = m.stats.poss[0] + m.stats.poss[1] || 1;
    return `<div class="res"><div class="dim">${r.title}</div><div class="score"><span>${esc(m.teams[0].short)}</span><b>${m.score[0]} – ${m.score[1]}</b><span>${esc(m.teams[1].short)}</span></div><div class="scorers">${sc}</div>
    ${st('Tiri', m.stats.shots[0], m.stats.shots[1])}${st('In porta', m.stats.onT[0], m.stats.onT[1])}${st('Possesso', Math.round(m.stats.poss[0] / ps * 100) + '%', Math.round(m.stats.poss[1] / ps * 100) + '%')}${st('Angoli', m.stats.corners[0], m.stats.corners[1])}${st('Falli', m.stats.fouls[0], m.stats.fouls[1])}</div>
    ${r.res ? `<div class="card"><div class="st"><span>Incasso partita</span><b class="good">+${fmtMoney(r.res.income)}</b></div><div class="st"><span>Stipendi</span><b class="bad">−${fmtMoney(r.res.wages)}</b></div><div class="st"><span>Cassa</span><b>${fmtMoney(s.money)}</b></div>
      ${r.res.grown.length ? `<p class="note">Migliorati: ${r.res.grown.map(esc).join(', ')}</p>` : ''}
      ${r.res.others.length ? `<p class="note">Altri risultati: ${r.res.others.map(o => `${o[0]} ${o[1]}–${o[2]} ${o[3]}`).join(' · ')}</p>` : ''}</div>` : ''}
    <button class="btn big" data-a="${r.res && r.res.season ? 'season' : 'continue'}">Continua</button>`;
  }
  season(r) {
    const t = r.outcome === 'up' ? 'PROMOSSI!' : r.outcome === 'down' ? 'Retrocessi' : r.outcome === 'champ' ? 'CAMPIONI!' : 'Stagione finita';
    return `<div class="how"><h1>${t}</h1><p>Hai chiuso al <b>${r.pos}° posto</b> in ${DIV_NAMES[r.div]}.</p><p>Premio di fine stagione: <b>${fmtMoney(r.prize + r.bonus)}</b></p><p>La prossima stagione giochi in <b>${DIV_NAMES[r.newDiv]}</b>. I giocatori hanno un anno in più: controlla la rosa e il mercato.</p><button class="btn big" data-a="continue">Avanti</button></div>`;
  }
}
