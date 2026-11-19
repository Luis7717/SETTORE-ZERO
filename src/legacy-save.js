// Recupero del vecchio salvataggio quando l'app passa da file:// allo schema app://.
// L'origine cambia, quindi localStorage della nuova pagina è vuoto: l'app iOS legge il salvataggio
// dalla vecchia origine (pagina App/legacy.html caricata come file://) e lo passa alla nuova pagina
// come stringa in window.__legacySave. Qui lo si copia, senza mai sovrascrivere un salvataggio presente.

export const SAVE_KEY = 'tag_save_v1';

// Ritorna cosa è successo:
//  'none'     nessun vecchio salvataggio da copiare
//  'kept'     nella nuova origine c'era già un salvataggio: lasciato com'è
//  'migrated' copiato
//  'invalid'  il vecchio salvataggio non è JSON valido: ignorato
//  'error'    localStorage non scrivibile (si riproverà al prossimo avvio)
export function migrateLegacySave(storage, legacy, key = SAVE_KEY) {
  if (typeof legacy !== 'string' || legacy === '') return 'none';
  try {
    const cur = storage.getItem(key);
    if (cur !== null && cur !== '') return 'kept';
  } catch (e) { return 'error'; }
  try { const o = JSON.parse(legacy); if (!o || typeof o !== 'object') return 'invalid'; } catch (e) { return 'invalid'; }
  try { storage.setItem(key, legacy); return storage.getItem(key) === legacy ? 'migrated' : 'error'; } catch (e) { return 'error'; }
}

// In pagina: esegue la migrazione e avvisa l'app iOS dell'esito (se c'è), così non la ripete.
export function runLegacyMigration(win) {
  const legacy = win.__legacySave;
  if (legacy === undefined) return null;
  let r;
  try { r = migrateLegacySave(win.localStorage, legacy); } catch (e) { r = 'error'; }
  try { const h = win.webkit && win.webkit.messageHandlers && win.webkit.messageHandlers.legacy; if (h) h.postMessage({ result: r }); } catch (e) { }
  return r;
}
