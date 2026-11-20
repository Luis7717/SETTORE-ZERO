// Memoria dei canvas: Safari iOS ha un tetto alla memoria di tutti i canvas della pagina; oltre, getContext('2d')
// restituisce null e chi disegna si rompe. Le texture disegnate su canvas che non cambiano più (o cambiano di rado)
// si caricano subito sulla GPU e poi il loro canvas si svuota (0×0): sulla GPU la texture resta.
// Se il contesto WebGL si perde e torna, three ricarica le texture da texture.image: prima di quel momento il canvas
// si ridisegna con texture.userData.rebuild (restoreTextures).
// Niente import di three: basta un renderer con initTexture (anche finto, nei test in Node).

const released = new WeakMap(); // renderer → Set di texture col canvas svuotato

function setFor(renderer) {
  let s = released.get(renderer);
  if (!s) { s = new Set(); released.set(renderer, s); }
  return s;
}

// carica la texture sulla GPU e svuota il suo canvas. rebuild() deve ridare un canvas disegnato (lo stesso o uno nuovo):
// serve per i ridisegni (redrawTex) e per il ritorno del contesto. Restituisce i byte liberati.
export function releaseCanvas(renderer, tex, rebuild = tex && tex.userData && tex.userData.rebuild) {
  const c = tex && tex.image;
  if (!renderer || typeof renderer.initTexture !== 'function' || !c || !c.width || typeof c.getContext !== 'function') return 0;
  const gl = renderer.getContext && renderer.getContext();
  if (gl && gl.isContextLost && gl.isContextLost()) return 0; // senza contesto il caricamento non avverrebbe: il canvas resta
  renderer.initTexture(tex);
  const bytes = c.width * c.height * 4;
  tex.userData.rebuild = rebuild || null;
  tex.userData.releasedBy = renderer;
  c.width = 0; c.height = 0; // libera i pixel del canvas (il canvas resta, vuoto)
  const s = setFor(renderer);
  if (!s.has(tex)) {
    s.add(tex);
    if (tex.addEventListener) tex.addEventListener('dispose', () => s.delete(tex));
  }
  return bytes;
}

// ridà alla texture un canvas disegnato (prima di ridisegnarla o ricaricarla); false se non si può
export function reviveCanvas(tex) {
  const c = tex && tex.image;
  if (c && c.width && c.height) return true;
  const rb = tex && tex.userData && tex.userData.rebuild;
  if (!rb) return false;
  const nc = rb();
  if (!nc || !nc.width) return false;
  tex.image = nc;
  return true;
}

// dopo il ritorno del contesto WebGL: ridisegna, ricarica e svuota di nuovo tutte le texture di quel renderer
export function restoreTextures(renderer, onError) {
  const s = released.get(renderer);
  if (!s) return 0;
  let n = 0;
  for (const tex of [...s]) {
    try {
      if (!reviveCanvas(tex)) continue;
      tex.needsUpdate = true;
      releaseCanvas(renderer, tex, tex.userData.rebuild);
      n++;
    } catch (e) { if (onError) onError(e); }
  }
  return n;
}

export function releasedCount(renderer) { const s = released.get(renderer); return s ? s.size : 0; }

// al ritorno del contesto WebGL di quel renderer, ridisegna le sue texture svuotate (dopo il ripristino di three,
// che ascolta lo stesso evento ed è stato registrato prima)
export function watchRestore(renderer, onError) {
  const el = renderer && renderer.domElement;
  if (el && el.addEventListener) el.addEventListener('webglcontextrestored', () => restoreTextures(renderer, onError));
}
