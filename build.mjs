// Costruisce il gioco a più file (offline):
//   www/index.html   codice e menu (deve restare sotto 1 MB)
//   www/assets/...   modelli, texture e audio, copiati da assets/ secondo assets/manifest.json
// Opzioni:
//   --single              versione a file unico in dist/tiro-a-giro.html (file incorporati), solo per il browser
//   --manifest <file>     manifesto alternativo (per le prove)
import { build } from 'esbuild';
import { readFileSync, writeFileSync, mkdirSync, existsSync, statSync, copyFileSync, rmSync } from 'node:fs';
import { dirname, join, extname } from 'node:path';

const MAX_INDEX = 1024 * 1024;        // www/index.html sotto 1 MB
const MAX_FILE = 20 * 1024 * 1024;    // nessun file sopra 20 MB
const MIME = { '.glb': 'model/gltf-binary', '.gltf': 'model/gltf+json', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.mp3': 'audio/mpeg', '.m4a': 'audio/mp4', '.wav': 'audio/wav', '.json': 'application/json', '.bin': 'application/octet-stream' };

const args = process.argv.slice(2);
const opt = n => { const i = args.indexOf(n); return i >= 0 ? args[i + 1] : null; };
const single = args.includes('--single');
const manPath = opt('--manifest') || 'assets/manifest.json';
const srcDir = dirname(manPath);

// manifesto: tiene solo i file che esistono, e si ferma se uno supera il limite
const raw = existsSync(manPath) ? JSON.parse(readFileSync(manPath, 'utf8')) : {};
const manifest = {}, files = [];
for (const [stage, list] of Object.entries(raw)) {
  if (stage.startsWith('_') || !Array.isArray(list)) continue;
  manifest[stage] = [];
  for (const it of list) {
    const p = join(srcDir, it.file);
    if (!existsSync(p)) { console.warn(`ATTENZIONE: manca ${p} (tappa ${stage}), il gioco partirà senza`); continue; }
    const size = statSync(p).size;
    if (size > MAX_FILE) { console.error(`ERRORE: ${p} pesa ${(size / 1048576).toFixed(1)} MB, oltre il limite di 20 MB`); process.exit(1); }
    manifest[stage].push({ id: it.id, file: it.file });
    files.push({ src: p, file: it.file, size });
  }
}

const r = await build({
  entryPoints: ['src/main.js'], bundle: true, minify: true, format: 'iife', target: 'es2020', write: false, legalComments: 'none',
  define: { __MANIFEST__: JSON.stringify(manifest) },
});
const js = r.outputFiles[0].text.replace(/<\/script/g, '<\\/script');
const tpl = readFileSync('src/index.tpl.html', 'utf8');

if (single) {
  const inline = {};
  for (const f of files) inline[f.file] = `data:${MIME[extname(f.file)] || 'application/octet-stream'};base64,` + readFileSync(f.src).toString('base64');
  const pre = `window.__INLINE_ASSETS=${JSON.stringify(inline)};`;
  mkdirSync('dist', { recursive: true });
  const html = tpl.replace('/*BUNDLE*/', () => pre + js);
  writeFileSync('dist/tiro-a-giro.html', html);
  console.log('dist/tiro-a-giro.html (file unico)', html.length / 1024 | 0, 'KB,', files.length, 'file incorporati');
} else {
  const html = tpl.replace('/*BUNDLE*/', () => js);
  if (Buffer.byteLength(html) > MAX_INDEX) { console.error(`ERRORE: www/index.html pesa ${Buffer.byteLength(html) / 1024 | 0} KB, oltre 1 MB`); process.exit(1); }
  mkdirSync('www', { recursive: true });
  writeFileSync('www/index.html', html);
  rmSync('www/assets', { recursive: true, force: true });
  for (const f of files) { const d = join('www/assets', f.file); mkdirSync(dirname(d), { recursive: true }); copyFileSync(f.src, d); }
  const tot = files.reduce((s, f) => s + f.size, 0);
  console.log('www/index.html', Buffer.byteLength(html) / 1024 | 0, 'KB · www/assets:', files.length, 'file,', (tot / 1048576).toFixed(2), 'MB');
}
