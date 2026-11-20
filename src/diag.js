// Diagnostica per l'iPhone (dove non c'è la console): registro degli errori in window.__errs, conteggio della memoria
// dei canvas e una riga di testo da mostrare in pausa, così Luis può fotografarla.
// Nessuna dipendenza grafica: gira anche in Node (i test passano un finto window).

export const MAX_ERRS = 12;           // errori tenuti in memoria (i più vecchi escono)
export const IOS_CANVAS_MB = 224;     // memoria dei canvas oltre la quale Safari iOS (nei casi peggiori) nega nuovi canvas

const g = () => (typeof window !== 'undefined' ? window : null);

function errList(win) {
  if (!win) return [];
  if (!Array.isArray(win.__errs)) win.__errs = [];
  return win.__errs;
}

// testo breve di un errore qualsiasi (Error, stringa, evento)
export function errText(e) {
  if (e == null) return 'errore sconosciuto';
  if (typeof e === 'string') return e;
  const msg = e.message || e.reason && (e.reason.message || String(e.reason)) || String(e);
  return String(msg).slice(0, 160);
}

// registra un errore: dove (es. 'stadio/pubblico') e cosa. Due errori uguali di fila diventano uno con il conto.
export function logError(where, e, win = g()) {
  const list = errList(win), msg = errText(e), last = list[list.length - 1];
  if (last && last.where === where && last.msg === msg) last.n = (last.n || 1) + 1;
  else {
    list.push({ where, msg, n: 1 });
    while (list.length > MAX_ERRS) list.shift();
  }
  if (typeof console !== 'undefined' && console.error) console.error(`[${where}]`, e);
  return list;
}

// errori globali (script che si rompono, promesse rifiutate senza catch). Il template ne cattura già i primi
// (script in testa a index.html); qui si aggiungono solo se mancano.
export function installErrorLog(win = g()) {
  if (!win || win.__errLog) return;
  win.__errLog = true;
  errList(win);
  win.addEventListener('error', ev => logError('pagina', ev.error || ev.message, win));
  win.addEventListener('unhandledrejection', ev => logError('promessa', ev.reason, win));
}

// memoria dei canvas (byte): larghezza × altezza × 4 di ogni canvas
export function canvasBytes(canvases) {
  let b = 0;
  for (const c of canvases) if (c) b += (c.width | 0) * (c.height | 0) * 4;
  return b;
}

// Tiene d'occhio tutti i canvas creati con document.createElement (anche quelli non più usati ma non ancora
// raccolti dal garbage collector: Safari li conta lo stesso). Serve WeakRef; senza, niente conteggio.
export function trackCanvases(win = g()) {
  if (!win || win.__cvRefs || typeof win.WeakRef !== 'function' || !win.Document) return;
  const refs = win.__cvRefs = [], proto = win.Document.prototype, make = proto.createElement;
  proto.createElement = function (name, o) {
    const el = make.call(this, name, o);
    if (String(name).toLowerCase() === 'canvas') {
      if (refs.length > 400) for (let i = refs.length - 1; i >= 0; i--) if (!refs[i].deref()) refs.splice(i, 1);
      refs.push(new win.WeakRef(el));
    }
    return el;
  };
}
export function canvasStats(win = g()) {
  if (!win || !win.__cvRefs) return null;
  const live = [];
  for (const r of win.__cvRefs) { const c = r.deref(); if (c && c.width && c.height) live.push(c); }
  return { n: live.length, mb: canvasBytes(live) / 1048576 };
}

// riga "Diagnostica" (testo semplice, già pronto per textContent)
export function diagLines(info, win = g()) {
  const st = canvasStats(win), errs = errList(win);
  const head = [`stadio: ${info.stadium || '?'}`];
  if (st) head.push(`canvas: ${st.n} · ${st.mb.toFixed(0)} MB`);
  if (info.gl) head.push(info.gl);
  const lines = [head.join(' · ')];
  if (!errs.length) lines.push('nessun errore');
  // il primo errore (di solito la causa) e gli ultimi tre
  else for (const e of errs.length > 4 ? [errs[0], ...errs.slice(-3)] : errs) lines.push(`${e.where}: ${e.msg}${e.n > 1 ? ` (×${e.n})` : ''}`);
  return lines;
}
