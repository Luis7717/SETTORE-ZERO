// Caricamento a pezzi dei file pesanti (modelli, texture, audio) da www/assets/.
// Ordine: menu subito (nessun file), 'match' all'ingresso in partita con barra di avanzamento,
// 'music' in sottofondo. Un file che manca o fallisce viene saltato: il gioco parte lo stesso.
//
// Il manifesto viene da assets/manifest.json (build.mjs lo incorpora nel codice):
//   { "match": [{ "id": "crowd", "file": "audio/crowd.m4a" }], "music": [...] }
// Nella versione a file unico (npm run build:single) i file arrivano già dentro la pagina
// come data: URL in `inline` e non serve nessuna richiesta.

export class Assets {
  constructor({ manifest = {}, base = 'assets/', fetchFn = null, inline = null, timeoutMs = 20000 } = {}) {
    this.manifest = manifest; this.timeoutMs = timeoutMs; this.base = base; this.inline = inline || {};
    this.fetchFn = fetchFn || ((u) => fetch(u));
    this.data = new Map();      // id -> ArrayBuffer
    this.failed = new Map();    // id -> motivo
    this.stages = new Map();    // nome tappa -> Promise del risultato
  }

  items(stage) { return Array.isArray(this.manifest[stage]) ? this.manifest[stage] : []; }
  has(id) { return this.data.has(id); }
  get(id) { return this.data.get(id) || null; }

  async fetchOne(it) {
    const url = this.inline[it.file] || this.base + it.file;
    // una richiesta appesa non deve bloccare l'ingresso in partita
    let timer;
    const late = new Promise((_, no) => { timer = setTimeout(() => no(new Error('tempo scaduto')), this.timeoutMs); });
    try {
      const r = await Promise.race([this.fetchFn(url), late]);
      if (!r || !r.ok) throw new Error('HTTP ' + (r ? r.status : '?'));
      return await Promise.race([r.arrayBuffer(), late]);
    } finally { clearTimeout(timer); }
  }

  // Carica tutti i file di una tappa. onProgress(fatti, totale, id) a ogni file concluso (anche se fallito).
  // Non lancia mai errori: ritorna { ok: [id], failed: [id] }. Chiamate ripetute riusano la stessa promessa;
  // se qualche file è fallito, la volta dopo la tappa si riprova.
  loadStage(stage, onProgress) {
    if (this.stages.has(stage)) return this.stages.get(stage);
    const list = this.items(stage), total = list.length, res = { ok: [], failed: [] };
    let done = 0;
    const tick = (id) => { done++; if (onProgress) { try { onProgress(done, total, id); } catch (_) { } } };
    if (onProgress && total === 0) { try { onProgress(0, 0, null); } catch (_) { } }
    const p = Promise.all(list.map(async (it) => {
      try { this.data.set(it.id, await this.fetchOne(it)); res.ok.push(it.id); }
      catch (e) { this.failed.set(it.id, String(e && e.message || e)); res.failed.push(it.id); }
      tick(it.id);
    })).then(() => { if (res.failed.length) this.stages.delete(stage); return res; });
    this.stages.set(stage, p);
    return p;
  }
}
