// Carriera: squadre, giocatori, campionato a tre divisioni, mercato, soldi, salvataggio.
import { rng32, FORMATIONS, headingOf } from './sim.js';
import { lookFromSeed, normalizeLook, normalizeKitStyle, kitStyleFromSeed, squadNumbers, hash32 } from './looks.js';
import { crestFromSeed, normalizeCrest } from './crest.js';
import { canSwap, swapLineup } from './squad-layout.js';

const KEY = 'tag_save_v1';
export const DIV_NAMES = ['Prima Divisione', 'Seconda Divisione', 'Terza Divisione'];
const DIV_LVL = [[70, 82], [60, 70], [50, 60]];
const DIV_INCOME = [300, 140, 70];
// abilità in più della squadra del computer per divisione (oltre a quella che viene dalla forza dei giocatori)
export const DIV_SKILL = [0.08, 0.04, 0];
export const POS_NAME = { P: 'POR', D: 'DIF', C: 'CEN', A: 'ATT' };
export const KITS = [
  ['Rosso', 0xc8102e, 0xffffff], ['Blu', 0x1746a2, 0xffffff], ['Verde', 0x0b7a3e, 0xffffff], ['Giallo', 0xf2c200, 0x1b1b1b], ['Nero', 0x1c1c22, 0xe8e8e8],
  ['Bianco', 0xf2f2f2, 0x1b2a5c], ['Arancio', 0xe8650a, 0x1b1b1b], ['Viola', 0x5b2a86, 0xffffff], ['Celeste', 0x4aa3df, 0xffffff], ['Granata', 0x7a1230, 0xf0d9a0],
];
const NOMI = ['Luca', 'Marco', 'Matteo', 'Andrea', 'Davide', 'Simone', 'Paolo', 'Stefano', 'Fabio', 'Giorgio', 'Nicola', 'Pietro', 'Tommaso', 'Elia', 'Samuele', 'Enrico', 'Dario', 'Michele', 'Riccardo', 'Daniele', 'Emanuele', 'Cristian', 'Alessio', 'Filippo', 'Gabriele', 'Lorenzo', 'Mattia', 'Edoardo', 'Jacopo', 'Vittorio', 'Omar', 'Karim', 'Diego', 'Rui', 'Milan', 'Yann', 'Kofi', 'Ivan', 'Jonas', 'Mateo', 'Thiago', 'Emre', 'Luka', 'Sven', 'Nuno', 'Abdou'];
const COGNOMI = ['Ferrante', 'Morandi', 'Castoldi', 'Bellucci', 'Rinaldi', 'Sartori', 'Galvani', 'Pedretti', 'Zanella', 'Corradi', 'Mazzoleni', 'Tessari', 'Bonfanti', 'Carrara', 'Negri', 'Valsecchi', 'Lodi', 'Fumagalli', 'Brambilla', 'Ronchi', 'Pagani', 'Stella', 'Orlandi', 'Vitali', 'Marchetti', 'Donati', 'Ferri', 'Gatti', 'Monti', 'Pellegrini', 'Barone', 'Serra', 'Fontana', 'Basile', 'Caruso', 'Rizzi', 'Santoro', 'Diallo', 'Novak', 'Petrov', 'Silva', 'Moreau', 'Jansen', 'Kovac', 'Mensah', 'Okoye', 'Yilmaz', 'Lindqvist', 'Duarte', 'Benali'];
const PRE = ['Atletico', 'Sporting', 'Real', 'Virtus', 'Olimpia', 'Dinamo', 'Unione', 'Pro', 'Fortitudo', 'Aurora', 'Audace', 'Robur', 'Libertas', 'Polisportiva', 'Città di'];
const TOWN = ['Borgoalto', 'Roccamarina', 'Valdoro', 'Monteluce', 'Pietrafina', 'Castelvento', 'Fontechiara', 'Portosole', 'Collebruno', 'Torrelunga', 'Rivabianca', 'Selvascura', 'Pontenero', 'Campofiore', 'Acquadolce', 'Vignarossa', 'Poggiosereno', 'Lagoverde', 'Serralta', 'Montefalco Nuovo', 'Pratolungo', 'Casalbruna', 'Villastella', 'Costadoro', 'Fiumechiaro', 'Roveredo Alto', 'Sassoforte', 'Terranova Ligure', 'Marebello', 'Querciagrande', 'Boscofermo', 'Pianoro Sole'];

const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
const pick = (r, a) => a[Math.floor(r() * a.length)];
// campione creato nell'editor: un buon giovane della Terza Divisione (le squadre lì stanno tra 50 e 60)
export const CHAMP_LEVEL = 62;
export const randomName = r => pick(r, NOMI)[0] + '. ' + pick(r, COGNOMI);

export function overallAs(p, pos) {
  const pen = p.pos === pos ? 1 : ((p.pos === 'P') !== (pos === 'P') ? 0.55 : (p.pos + pos === 'DA' || p.pos + pos === 'AD' ? 0.82 : 0.92));
  let o;
  if (pos === 'P') o = p.por * 0.72 + p.fis * 0.14 + p.pas * 0.14;
  else if (pos === 'D') o = p.dif * 0.45 + p.fis * 0.2 + p.vel * 0.15 + p.pas * 0.1 + p.dri * 0.1;
  else if (pos === 'C') o = p.pas * 0.35 + p.dri * 0.25 + p.dif * 0.12 + p.vel * 0.12 + p.tir * 0.16;
  else o = p.tir * 0.4 + p.vel * 0.22 + p.dri * 0.23 + p.pas * 0.1 + p.fis * 0.05;
  return Math.round(o * pen);
}
export const overall = p => overallAs(p, p.pos);
export function value(p) {
  const o = overall(p), a = p.age;
  const af = a <= 21 ? 1.35 : a <= 25 ? 1.2 : a <= 29 ? 1 : a <= 31 ? 0.75 : a <= 33 ? 0.5 : 0.3;
  return Math.max(5, Math.round(30 * Math.pow(1.115, o - 50) * af));
}
export const fmtMoney = k => (Math.abs(k) >= 1000 ? (k / 1000).toFixed(2).replace('.', ',') + ' M€' : Math.round(k) + ' k€');

export function genPlayer(r, pos, level, id, young) {
  const g = () => (r() + r() + r() - 1.5) * 2;
  const b = level + g() * 3.5, v = d => Math.round(clamp(b + d + (r() - 0.5) * 8, 18, 99));
  const p = { id, name: pick(r, NOMI)[0] + '. ' + pick(r, COGNOMI), pos, age: young ? 17 + Math.floor(r() * 5) : 18 + Math.floor(r() * 16), goals: 0, assists: 0, apps: 0 };
  if (pos === 'P') Object.assign(p, { por: v(5), pas: v(-12), fis: v(-2), vel: v(-12), tir: v(-30), dri: v(-22), dif: v(-22) });
  else if (pos === 'D') Object.assign(p, { dif: v(5), fis: v(3), vel: v(-2), pas: v(-6), dri: v(-10), tir: v(-18), por: 12 });
  else if (pos === 'C') Object.assign(p, { pas: v(5), dri: v(1), vel: v(-2), dif: v(-6), tir: v(-5), fis: v(-2), por: 12 });
  else Object.assign(p, { tir: v(5), vel: v(2), dri: v(2), pas: v(-6), fis: v(-3), dif: v(-22), por: 12 });
  p.tes = headingOf(p); // colpi di testa: stessa formula usata per i giocatori dei salvataggi vecchi (nessun numero casuale in più)
  p.pot = overall(p) + (p.age < 22 ? 4 + Math.floor(r() * 12) : p.age < 26 ? Math.floor(r() * 6) : 0);
  return p;
}

function roundRobin(ids) {
  const n = ids.length, a = ids.slice(), rounds = [];
  for (let r = 0; r < n - 1; r++) {
    const m = [];
    for (let i = 0; i < n / 2; i++) m.push(r % 2 ? [a[n - 1 - i], a[i]] : [a[i], a[n - 1 - i]]);
    rounds.push(m); a.splice(1, 0, a.pop());
  }
  return rounds.concat(rounds.map(m => m.map(([h, w]) => [w, h])));
}

export class Career {
  constructor() { this.s = null; }
  load() { try { const t = localStorage.getItem(KEY); if (t) { this.s = JSON.parse(t); this.upgrade(); return true; } } catch (e) { } return false; }
  // salvataggi vecchi: numeri di maglia mancanti assegnati (senza doppioni). Stile della divisa, stemma e aspetto
  // dei giocatori non si scrivono: se mancano si calcolano sempre uguali (kitStyle(), crest(), lookOf()).
  upgrade() { const s = this.s; if (s && Array.isArray(s.squad)) this.ensureNums(); }
  ensureNums() { const nums = squadNumbers(this.s.squad); for (const p of this.s.squad) p.num = nums.get(p.id); }
  save() { try { localStorage.setItem(KEY, JSON.stringify(this.s)); } catch (e) { } }
  reset() { try { localStorage.removeItem(KEY); } catch (e) { } this.s = null; }
  rnd() { const s = this.s; s.seed = (s.seed * 1664525 + 1013904223) >>> 0; return s.seed / 4294967296; }

  create(name, kit) {
    const seed = (Date.now() ^ (Math.random() * 1e9)) >>> 0, r = rng32(seed);
    const s = this.s = { v: 1, seed, club: name, kit, crest: crestFromSeed(seed), kitStyle: { ...normalizeKitStyle(null) }, money: 250, season: 1, day: 0, nextId: 1, teams: {}, divs: [[], [], []], squad: [], market: [], settings: { half: 150, diff: 1, sound: true, autoGk: false }, tut: 0, history: [], last: null };
    const towns = TOWN.slice().sort(() => r() - 0.5);
    let k = 0;
    for (let d = 0; d < 3; d++) for (let i = 0; i < 10; i++) {
      if (d === 2 && i === 0) { s.teams.me = { id: 'me', name, short: name.replace(/[^A-Za-zÀ-ú]/g, '').slice(0, 3).toUpperCase() || 'MIA', kit, rating: 0 }; s.divs[d].push('me'); continue; }
      const id = 't' + k, town = towns[k++], [lo, hi] = DIV_LVL[d];
      let kk = Math.floor(r() * KITS.length);
      s.teams[id] = { id, name: pick(r, PRE) + ' ' + town, short: town.replace(/[^A-Za-z]/g, '').slice(0, 3).toUpperCase(), kit: kk, rating: Math.round(lo + r() * (hi - lo)), seed: Math.floor(r() * 1e9) };
      s.divs[d].push(id);
    }
    const mk = (pos, n, lvl) => { for (let i = 0; i < n; i++) s.squad.push(genPlayer(r, pos, lvl + (i < 2 ? 2 : -1), s.nextId++, i >= n - 1)); };
    mk('P', 2, 54); mk('D', 6, 54); mk('C', 6, 54); mk('A', 4, 54);
    this.ensureNums();
    s.formation = '4-4-2'; s.lineup = []; this.autoLineup(); s.teams.me.rating = this.myRating();
    this.newSeason(true); this.refreshMarket(20);
    this.save();
  }

  // ------------------------------------------------ stile della divisa, stemma, aspetto, campione
  kitStyle() { return normalizeKitStyle(this.s.kitStyle); }
  setKitStyle(st) { this.s.kitStyle = normalizeKitStyle(st); this.save(); }
  crest() { return normalizeCrest(this.s.crest, crestFromSeed(hash32('club', this.s.club))); }
  setCrest(c) { this.s.crest = normalizeCrest(c); this.save(); }
  // stemma di qualunque squadra: la mia, oppure deterministico dal seme (stessa squadra = stesso stemma)
  teamCrest(t) { if (!t || t.id === 'me') return this.crest(); return normalizeCrest(t.crest, crestFromSeed(t.seed !== undefined ? t.seed : hash32(t.id, t.name))); }
  setLook(id, look) { const p = this.player(id); if (!p) return false; p.look = normalizeLook(look); this.save(); return true; }
  // campione dell'editor: entra in rosa con ruolo, aspetto e numero scelti; se il numero era di un altro, l'altro ne riceve uno libero
  addChampion({ name, pos, look, num }) {
    const s = this.s, p = genPlayer(() => this.rnd(), pos, CHAMP_LEVEL, s.nextId++, true);
    p.name = String(name || '').trim().slice(0, 20) || p.name; p.look = normalizeLook(look); p.champ = true;
    if (Number.isInteger(num) && num >= 1 && num <= 99) { for (const q of s.squad) if (q.num === num) delete q.num; p.num = num; }
    s.squad.unshift(p); this.ensureNums();
    this.autoLineup(); s.teams.me.rating = this.myRating(); this.save();
    return p;
  }

  div() { return this.s.divs.findIndex(d => d.includes('me')); }
  team(id) { return this.s.teams[id]; }
  player(id) { return this.s.squad.find(p => p.id === id); }

  newSeason(first) {
    const s = this.s; s.day = 0; s.fix = []; s.tab = {}; s.res = [];
    for (let d = 0; d < 3; d++) {
      const ids = s.divs[d].slice().sort(() => this.rnd() - 0.5);
      s.fix.push(roundRobin(ids));
      for (const id of ids) s.tab[id] = { p: 0, w: 0, d: 0, l: 0, gf: 0, ga: 0, pts: 0 };
    }
    if (!first) for (const p of s.squad) { p.goals = 0; p.assists = 0; p.apps = 0; }
  }

  table(d) {
    const s = this.s;
    return s.divs[d].map(id => Object.assign({ id }, s.tab[id])).sort((a, b) => b.pts - a.pts || (b.gf - b.ga) - (a.gf - a.ga) || b.gf - a.gf || (a.id < b.id ? -1 : 1));
  }
  myRating() {
    const s = this.s, F = FORMATIONS[s.formation]; let t = 0;
    s.lineup.forEach((id, i) => { const p = this.player(id); t += p ? overallAs(p, F[i][0]) : 30; });
    return Math.round(t / 11);
  }
  nextMatch() {
    const s = this.s, d = this.div();
    if (s.day >= 18) return null;
    const m = s.fix[d][s.day].find(x => x[0] === 'me' || x[1] === 'me');
    const home = m[0] === 'me';
    return { home, opp: this.team(home ? m[1] : m[0]), day: s.day + 1, div: d };
  }

  autoLineup() {
    const s = this.s, F = FORMATIONS[s.formation], used = new Set(), l = [];
    const order = F.map((f, i) => i).sort((a, b) => 'PADC'.indexOf(F[a][0]) - 'PADC'.indexOf(F[b][0]));
    for (const i of order) {
      let best = null, bo = -1;
      for (const p of s.squad) if (!used.has(p.id)) { const o = overallAs(p, F[i][0]); if (o > bo) { bo = o; best = p; } }
      l[i] = best.id; used.add(best.id);
    }
    s.lineup = l;
  }
  fixLineup() { // dopo vendite/acquisti: riempie i buchi
    const s = this.s, ids = new Set(s.squad.map(p => p.id)); const used = new Set();
    s.lineup = s.lineup.map(id => (ids.has(id) && !used.has(id) ? (used.add(id), id) : null));
    const F = FORMATIONS[s.formation];
    s.lineup.forEach((id, i) => {
      if (id !== null) return; let best = null, bo = -1;
      for (const p of s.squad) if (!used.has(p.id)) { const o = overallAs(p, F[i][0]); if (o > bo) { bo = o; best = p; } }
      if (best) { s.lineup[i] = best.id; used.add(best.id); }
    });
  }
  bench() { const s = this.s; return s.squad.filter(p => !s.lineup.includes(p.id)); }
  swap(a, b) { // scambia due giocatori (titolare/titolare o titolare/panchina)
    if (!canSwap(this.s.lineup, a, b)) return;
    this.s.lineup = swapLineup(this.s.lineup, a, b);
    this.save();
  }

  // ------------------------------------------------ mercato
  refreshMarket(n) {
    const s = this.s, lvl = (DIV_LVL[this.div()][0] + DIV_LVL[this.div()][1]) / 2, r = () => this.rnd();
    s.market.splice(0, Math.min(n, s.market.length));
    while (s.market.length < 20) {
      const pos = pick(r, ['P', 'D', 'D', 'D', 'C', 'C', 'C', 'A', 'A']);
      const p = genPlayer(r, pos, lvl - 5 + r() * 16, s.nextId++, r() < 0.3);
      p.price = Math.round(value(p) * (1.1 + r() * 0.25));
      s.market.push(p);
    }
  }
  buy(id) {
    const s = this.s, i = s.market.findIndex(p => p.id === id); if (i < 0) return 'Giocatore non più disponibile';
    const p = s.market[i];
    if (s.squad.length >= 24) return 'Rosa al completo (massimo 24)';
    if (s.money < p.price) return 'Soldi insufficienti';
    s.money -= p.price; s.market.splice(i, 1); delete p.price; s.squad.push(p); this.ensureNums(); this.save(); return null;
  }
  sellPrice(p) { return Math.round(value(p) * 0.8); }
  sell(id) {
    const s = this.s, p = this.player(id); if (!p) return 'Giocatore non trovato';
    if (s.squad.length <= 14) return 'Servono almeno 14 giocatori in rosa';
    if (p.pos === 'P' && s.squad.filter(q => q.pos === 'P').length <= 1) return 'Serve almeno un portiere';
    s.money += this.sellPrice(p); s.squad = s.squad.filter(q => q.id !== id); this.fixLineup(); this.save(); return null;
  }

  // ------------------------------------------------ squadre per la partita
  skillOf(rating, div = 2) { return clamp((rating - 42) / 48 + (this.s.settings.diff - 1) * 0.15 + (DIV_SKILL[div] || 0), 0.1, 0.95); }
  // divisione di una squadra; per chi non è in campionato (amichevoli) la mia
  divOf(t) { const d = t && t.id ? this.s.divs.findIndex(x => x.includes(t.id)) : -1; return d >= 0 ? d : this.div(); }
  kitOf(k, alt) {
    const c = typeof k === 'number' ? KITS[k] : KITS[0];
    return alt ? { shirt: c[2], shorts: c[1], socks: c[2], gk: { shirt: 0x2ad17a, shorts: 0x15803d, socks: 0x15803d } } : { shirt: c[1], shorts: c[2], socks: c[1], gk: { shirt: 0xffa41c, shorts: 0x222222, socks: 0xffa41c } };
  }
  // aggiunge alla divisa lo stile (maglia, maniche, colletto, motivo, calzettoni) e lo stemma coi colori della squadra
  dress(kit, k, style, crest, gk) {
    const c = KITS[k] || KITS[0];
    kit.style = gk ? { ...style, sleeves: 1, pattern: 0, collar: 0 } : { ...style };
    kit.crest = { ...crest, c1: c[1], c2: c[2] };
    if (gk) kit.gloves = true;
    return kit;
  }
  myMatchTeam() {
    const s = this.s, F = FORMATIONS[s.formation];
    const kit = this.dress(this.kitOf(s.kit), s.kit, this.kitStyle(), this.crest()); kit.gk = this.dress({ shirt: 0x27e0c0, shorts: 0x0c5c52, socks: 0x27e0c0 }, s.kit, this.kitStyle(), this.crest(), true);
    return { name: s.club, short: s.teams.me.short, formation: s.formation, players: s.lineup.map(id => this.player(id)), bench: this.bench(), skill: 0.6, kit };
  }
  aiMatchTeam(t) {
    const s = this.s, r = rng32(t.seed + s.season * 977), fs = Object.keys(FORMATIONS), formation = fs[Math.floor(r() * fs.length)], F = FORMATIONS[formation];
    const players = F.map((f, i) => genPlayer(r, f[0], t.rating, -i - 1));
    // aspetto e numero degli avversari: dal seme della squadra, senza consumare i numeri casuali di r
    players.forEach((p, i) => { p.look = lookFromSeed(hash32(t.seed, i)); p.num = i + 1; });
    const same = t.kit === s.kit || Math.abs(colorDist(KITS[t.kit][1], KITS[s.kit][1])) < 110;
    const kit = this.kitOf(t.kit, same), st = kitStyleFromSeed(t.seed), cr = this.teamCrest(t);
    this.dress(kit, t.kit, st, cr); this.dress(kit.gk, t.kit, st, cr, true);
    return { name: t.name, short: t.short, formation, players, skill: this.skillOf(t.rating, this.divOf(t)), kit };
  }

  // ------------------------------------------------ risultati
  record(h, a, gh, ga) {
    const T = this.s.tab, H = T[h], A = T[a];
    H.p++; A.p++; H.gf += gh; H.ga += ga; A.gf += ga; A.ga += gh;
    if (gh > ga) { H.w++; A.l++; H.pts += 3; } else if (gh < ga) { A.w++; H.l++; A.pts += 3; } else { H.d++; A.d++; H.pts++; A.pts++; }
  }
  simScore(rh, ra) {
    const po = l => { let k = 0, p = Math.exp(-l), s2 = p, u = this.rnd(); while (u > s2 && k < 8) { k++; p *= l / k; s2 += p; } return k; };
    const d = (rh + 2 - ra) / 13;
    return [po(1.35 * Math.exp(d * 0.5)), po(1.2 * Math.exp(-d * 0.5))];
  }
  // applica il risultato della partita giocata e simula il resto della giornata
  finishMatch(my, opp, log) {
    const s = this.s, d = this.div(), nm = this.nextMatch(), res = { income: 0, wages: 0, others: [], grown: [] };
    s.teams.me.rating = this.myRating();
    for (let dd = 0; dd < 3; dd++) for (const [h, a] of s.fix[dd][s.day]) {
      if (h === 'me' || a === 'me') { const gh = h === 'me' ? my : opp, ga = h === 'me' ? opp : my; this.record(h, a, gh, ga); continue; }
      const [gh, ga] = this.simScore(s.teams[h].rating, s.teams[a].rating); this.record(h, a, gh, ga);
      if (dd === d) res.others.push([s.teams[h].short, gh, ga, s.teams[a].short]);
    }
    const base = DIV_INCOME[d];
    res.income = Math.round(base * (nm.home ? 1 : 0.6) + (my > opp ? base * 0.5 : my === opp ? base * 0.2 : 0) + my * base * 0.05);
    res.wages = Math.round(s.squad.reduce((t, p) => t + value(p), 0) * 0.014);
    s.money += res.income - res.wages;
    for (const id of s.lineup) { const p = this.player(id); if (p) p.apps++; }
    for (const g of (log || [])) if (g.team === 0) { const p = g.scorer && this.player(g.scorer.id); if (p) p.goals++; const q = g.assist && this.player(g.assist.id); if (q) q.assists++; }
    // crescita dei giovani che giocano
    for (const p of s.squad) {
      const played = s.lineup.includes(p.id);
      if (overall(p) < p.pot && this.rnd() < (played ? 0.3 : 0.08)) {
        const keys = p.pos === 'P' ? ['por', 'fis', 'pas'] : p.pos === 'D' ? ['dif', 'fis', 'vel', 'pas'] : p.pos === 'C' ? ['pas', 'dri', 'tir', 'vel', 'dif'] : ['tir', 'vel', 'dri', 'pas'];
        const k1 = pick(() => this.rnd(), keys); p[k1] = Math.min(99, p[k1] + 1);
        const k2 = pick(() => this.rnd(), keys); p[k2] = Math.min(99, p[k2] + 1);
        res.grown.push(p.name);
      }
    }
    (s.res = s.res || [])[s.day] = [my, opp];
    s.last = { opp: nm.opp.name, my, op: opp, day: s.day + 1 };
    s.day++;
    this.refreshMarket(5);
    if (s.day >= 18) res.season = this.endSeason();
    this.save();
    return res;
  }

  endSeason() {
    const s = this.s, d = this.div(), tabs = [0, 1, 2].map(x => this.table(x));
    const pos = tabs[d].findIndex(t => t.id === 'me') + 1;
    const prize = Math.round(DIV_INCOME[d] * (11 - pos) * 0.6);
    let outcome = 'stay';
    const nd = [[], [], []];
    for (let x = 0; x < 3; x++) tabs[x].forEach((t, i) => {
      let to = x;
      if (i < 2 && x > 0) to = x - 1; else if (i >= 8 && x < 2) to = x + 1;
      nd[to].push(t.id);
      if (t.id === 'me') outcome = to < x ? 'up' : to > x ? 'down' : (x === 0 && i === 0 ? 'champ' : 'stay');
      else { const tm = s.teams[t.id], [lo, hi] = DIV_LVL[to]; tm.rating = Math.round(clamp(tm.rating + (this.rnd() - 0.5) * 6 + (to < x ? 4 : to > x ? -4 : 0), lo - 2, hi + 2)); }
    });
    const bonus = outcome === 'up' ? DIV_INCOME[d] * 3 : outcome === 'champ' ? 2000 : 0;
    s.money += prize + bonus;
    s.history.push({ season: s.season, div: d, pos, outcome });
    s.divs = nd; s.season++;
    const retired = [];
    for (const p of s.squad) {
      p.age++;
      if (p.age > 30) for (const k of ['vel', 'fis', 'dri', 'tir', 'dif', 'pas', 'por']) if (this.rnd() < 0.5) p[k] = Math.max(15, p[k] - 1 - (p.age > 33 ? 1 : 0));
    }
    this.newSeason(false); s.market = []; this.refreshMarket(20);
    return { pos, prize, bonus, outcome, div: d, newDiv: this.div(), retired };
  }
}

function colorDist(a, b) { return Math.abs((a >> 16) - (b >> 16)) + Math.abs(((a >> 8) & 255) - ((b >> 8) & 255)) + Math.abs((a & 255) - (b & 255)); }
