// Costruisce il gioco a più file (offline):
//   www/index.html          codice del gioco e menu (deve restare sotto 1 MB)
//   www/assets/three.min.js three.js e gli addons usati (GLTFLoader, ...), caricato prima del codice del gioco
//   www/assets/...          modelli, texture e audio, copiati da assets/ secondo assets/manifest.json
// Opzioni:
//   --single              versione a file unico in dist/tiro-a-giro.html (file e three incorporati), solo per il browser
//   --manifest <file>     manifesto alternativo (per le prove)
import { build } from 'esbuild';
import { readFileSync, writeFileSync, mkdirSync, existsSync, statSync, copyFileSync, rmSync } from 'node:fs';
import { dirname, join, extname } from 'node:path';

const MAX_INDEX = 1024 * 1024;        // www/index.html sotto 1 MB
const WARN_INDEX = 800 * 1024;        // oltre questo si avvisa: il margine si sta consumando
const MAX_FILE = 20 * 1024 * 1024;    // nessun file sopra 20 MB
const MIME = { '.glb': 'model/gltf-binary', '.gltf': 'model/gltf+json', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.mp3': 'audio/mpeg', '.m4a': 'audio/mp4', '.wav': 'audio/wav', '.json': 'application/json', '.bin': 'application/octet-stream' };

// three.js in un file a parte: il codice del gioco lo legge dai globali che questo file crea
const THREE_FILE = 'three.min.js';             // dentro www/assets/
const THREE_GLOBAL = '__THREE';                // window.__THREE = tutto 'three'
const ADDONS_GLOBAL = '__THREE_ADDONS';        // window.__THREE_ADDONS['examples/jsm/...'] = modulo addon
const THREE_IN_BUNDLE = /node_modules[\\/]three[\\/]/;
const THREE_CORE = ['build/three.module.js', 'build/three.core.js', 'build/three.cjs']; // = 'three' (es. three/webgpu no)

const args = process.argv.slice(2);
const opt = n => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : null; };
const single = args.includes('--single');
const manPath = opt('--manifest') || 'assets/manifest.json';
const srcDir = dirname(manPath);
const fail = msg => { console.error('ERRORE: ' + msg); process.exit(1); };
const kb = n => (n / 1024 | 0) + ' KB';

// manifesto: tiene solo i file che esistono, e si ferma se uno supera il limite
const raw = existsSync(manPath) ? JSON.parse(readFileSync(manPath, 'utf8')) : {};
const manifest = {}, files = [];
for (const [stage, list] of Object.entries(raw)) {
  if (stage.startsWith('_') || !Array.isArray(list)) continue;
  manifest[stage] = [];
  for (const it of list) {
    const p = join(srcDir, it.file);
    if (it.file === THREE_FILE) fail(`il nome ${THREE_FILE} è riservato a three.js, rinomina il file nel manifesto`);
    if (!existsSync(p)) { console.warn(`ATTENZIONE: manca ${p} (tappa ${stage}), il gioco partirà senza`); continue; }
    const size = statSync(p).size;
    if (size > MAX_FILE) fail(`${p} pesa ${(size / 1048576).toFixed(1)} MB, oltre il limite di 20 MB`);
    manifest[stage].push({ id: it.id, file: it.file });
    files.push({ src: p, file: it.file, size });
  }
}

// Plugin del bundle del gioco: 'three' e 'three/...' diventano moduli ponte che leggono i globali.
// Gli addons (GLTFLoader, SkeletonUtils, ...) finiscono nel file di three, così usano la stessa istanza di three.
// La chiave di un addon è il suo percorso dentro il pacchetto: 'three/addons/x.js' e 'three/examples/jsm/x.js'
// sono lo stesso file e diventano la stessa chiave.
function threeBridge(addons) {
  return {
    name: 'three-globale',
    setup(b) {
      b.onResolve({ filter: /^three(\/.*)?$/ }, async (a) => {
        if (a.pluginData === 'three-vero') return undefined;
        if (a.path === 'three') return { path: 'three', namespace: 'three-globale' };
        const r = await b.resolve(a.path, { kind: a.kind, resolveDir: a.resolveDir, pluginData: 'three-vero' });
        if (r.errors.length) return { errors: r.errors };
        const key = r.path.replace(/\\/g, '/').split('/node_modules/three/').pop();
        if (THREE_CORE.includes(key)) return { path: 'three', namespace: 'three-globale' }; // three stesso
        if (key.startsWith('build/')) return { errors: [{ text: `${a.path} (${key}) non è previsto nel file di three: aggiungilo in build.mjs` }] };
        addons.set(key, r.path);
        return { path: key, namespace: 'three-globale' };
      });
      b.onLoad({ filter: /.*/, namespace: 'three-globale' }, (a) => ({
        loader: 'js',
        contents: a.path === 'three'
          ? `module.exports = globalThis.${THREE_GLOBAL};`
          : `module.exports = globalThis.${ADDONS_GLOBAL}[${JSON.stringify(a.path)}];`,
      }));
    },
  };
}

// Bundle del gioco (src/main.js), senza three dentro.
const addons = new Map();
const r = await build({
  entryPoints: ['src/main.js'], bundle: true, minify: true, format: 'iife', target: 'es2020', write: false, legalComments: 'none',
  define: { __MANIFEST__: JSON.stringify(manifest) }, plugins: [threeBridge(addons)], metafile: true,
});
const leaked = Object.keys(r.metafile.inputs).filter(p => THREE_IN_BUNDLE.test(p));
if (leaked.length) fail(`three.js è finito dentro www/index.html (${leaked.slice(0, 3).join(', ')}): deve stare solo in www/assets/${THREE_FILE}`);

// File di three: tutto three + gli addons importati dal gioco, esposti come globali (oggetti semplici, senza getter).
const addonList = [...addons].sort(([a], [b]) => a.localeCompare(b)); // ordine fisso: file uguale a ogni build
const vendorSrc = [
  `import * as T from 'three';`,
  ...addonList.map(([, p], i) => `import * as a${i} from ${JSON.stringify(p)};`),
  `globalThis.${THREE_GLOBAL} = Object.freeze({ ...T });`,
  `globalThis.${ADDONS_GLOBAL} = Object.freeze({ ${addonList.map(([k], i) => `${JSON.stringify(k)}: Object.freeze({ ...a${i} })`).join(', ')} });`,
].join('\n');
const v = await build({
  stdin: { contents: vendorSrc, resolveDir: process.cwd(), sourcefile: 'three-vendor.js', loader: 'js' },
  bundle: true, minify: true, format: 'iife', target: 'es2020', write: false, legalComments: 'eof',
});
const threeJs = v.outputFiles[0].text;
if (Buffer.byteLength(threeJs) > MAX_FILE) fail(`${THREE_FILE} oltre il limite di 20 MB`);
// incorporato nel file unico, '<!--' dentro <script> cambierebbe il modo in cui la pagina legge lo script
if (single && threeJs.includes('<!--')) fail(`${THREE_FILE} contiene '<!--': non si può incorporare così nel file unico`);

// Se three non c'è (file mancante o rotto) il gioco non parte e si vede un messaggio, non una pagina vuota.
const guard = js => `if(!window.${THREE_GLOBAL}||!window.${ADDONS_GLOBAL}){document.getElementById('nothree').style.display='flex'}else{${js}}`;
const scriptSafe = s => s.replace(/<\/script/gi, '<\\/script');
const js = scriptSafe(guard(r.outputFiles[0].text));
const tpl = readFileSync('src/index.tpl.html', 'utf8');
if (!tpl.includes('<!--THREE-->') || !tpl.includes('/*BUNDLE*/')) fail('src/index.tpl.html senza <!--THREE--> o /*BUNDLE*/');

if (single) {
  const inline = {};
  for (const f of files) inline[f.file] = `data:${MIME[extname(f.file)] || 'application/octet-stream'};base64,` + readFileSync(f.src).toString('base64');
  const pre = `window.__INLINE_ASSETS=${JSON.stringify(inline)};`;
  mkdirSync('dist', { recursive: true });
  const html = tpl.replace('<!--THREE-->', () => `<script>${scriptSafe(threeJs)}</script>`).replace('/*BUNDLE*/', () => pre + js);
  writeFileSync('dist/tiro-a-giro.html', html);
  console.log('dist/tiro-a-giro.html (file unico)', kb(html.length), 'con three,', files.length, 'file incorporati');
} else {
  const html = tpl.replace('<!--THREE-->', () => `<script src="assets/${THREE_FILE}"></script>`).replace('/*BUNDLE*/', () => js);
  const size = Buffer.byteLength(html);
  if (size > MAX_INDEX) fail(`www/index.html pesa ${kb(size)}, oltre 1 MB`);
  if (size > WARN_INDEX) console.warn(`ATTENZIONE: www/index.html pesa ${kb(size)}, vicino al limite di 1 MB`);
  mkdirSync('www', { recursive: true });
  writeFileSync('www/index.html', html);
  rmSync('www/assets', { recursive: true, force: true });
  mkdirSync('www/assets', { recursive: true });
  writeFileSync(join('www/assets', THREE_FILE), threeJs);
  for (const f of files) { const d = join('www/assets', f.file); mkdirSync(dirname(d), { recursive: true }); copyFileSync(f.src, d); }
  const tot = files.reduce((s, f) => s + f.size, 0);
  console.log('www/index.html', kb(size), `· www/assets/${THREE_FILE}`, kb(Buffer.byteLength(threeJs)), `(addons: ${addonList.map(([k]) => k.split('/').pop()).join(', ')})`,
    '· www/assets:', files.length, 'file,', (tot / 1048576).toFixed(2), 'MB');
}
