#!/usr/bin/env node
/* Settore Zero — estrai-asset.js: dai vecchi file "incorporati" (base64 dentro .js) ai file binari veri in www/assets/
 *
 * USO (dalla radice del progetto):
 *   node tools/estrai-asset.js            converte, verifica, cancella i vecchi .js e toglie i loro <script> da www/index.html
 *   node tools/estrai-asset.js --tieni    converte e verifica ma NON cancella i .js e non tocca index.html
 *   node tools/estrai-asset.js --prova    mostra cosa farebbe, senza scrivere niente
 *
 * COSA FA
 *   1. www/models/*.js con righe  ASSET.<nome>="<glb in base64>";   ->  www/assets/models/<nome>.glb
 *   2. www/suoni/*.js  con righe  SUONI.<nome>="<audio in base64>"; ->  www/assets/audio/<nome>.<mp3|ogg|wav|m4a>
 *      (il formato si capisce dai primi byte del file, non dal nome)
 *   3. controlla che ogni file scritto sia byte-identico ai dati base64 originali (ricodifica e confronta)
 *   4. cancella i .js svuotati (quelli che non contengono altro oltre a commenti, 'use strict', il contenitore
 *      "var SUONI=..." e le righe di dati) e toglie i loro tag <script> da www/index.html
 *   5. rigenera www/assets/elenco.js: l'elenco di TUTTI i file in www/assets/models e www/assets/audio con il peso
 *      in byte. js/caricamento.js lo usa per sapere cosa esiste e per la barra di avanzamento.
 *
 * NUOVI MODELLI (per gli altri rami): aggiungete pure models/n_qualcosa.js nel vecchio formato, poi lanciate
 *   questo script: diventa assets/models/n_qualcosa.glb, entra in elenco.js e il caricatore lo trova per nome
 *   (MODELS.n_qualcosa). Ricordatevi di dire al caricatore QUANDO serve (js/caricamento.js, carNeeds()).
 *   Anche senza file .js da convertire lo script è utile: rigenera elenco.js se avete copiato a mano un .glb/.mp3.
 */
'use strict';
const fs = require('fs'), path = require('path');

const RADICE = path.resolve(__dirname, '..'), WWW = path.join(RADICE, 'www');
const ARGS = new Set(process.argv.slice(2)), PROVA = ARGS.has('--prova'), TIENI = ARGS.has('--tieni') || PROVA;
const SORGENTI = [
  { dir: 'models', re: /ASSET\.([A-Za-z0-9_$]+)\s*=\s*"([A-Za-z0-9+/=\s]*)"\s*;?/g, out: 'models', ext: () => '.glb' },
  { dir: 'suoni', re: /SUONI\.([A-Za-z0-9_$]+)\s*=\s*"([A-Za-z0-9+/=\s]*)"\s*;?/g, out: 'audio', ext: estAudio }
];

// formato audio dai primi byte
function estAudio(b) {
  const s = b.slice(0, 12).toString('latin1');
  if (s.startsWith('ID3') || (b[0] === 0xff && (b[1] & 0xe0) === 0xe0)) return '.mp3';
  if (s.startsWith('OggS')) return '.ogg';
  if (s.startsWith('RIFF') && s.slice(8, 12) === 'WAVE') return '.wav';
  if (s.slice(4, 8) === 'ftyp') return '.m4a';
  return '.bin';
}
const pulisci64 = s => s.replace(/\s+/g, '').replace(/=+$/, '');

function converti() {
  const tolti = [], scritti = [];
  for (const src of SORGENTI) {
    const dir = path.join(WWW, src.dir);
    if (!fs.existsSync(dir)) continue;
    for (const f of fs.readdirSync(dir).filter(n => n.endsWith('.js')).sort()) {
      const file = path.join(dir, f), txt = fs.readFileSync(file, 'utf8');
      let n = 0;
      for (const m of txt.matchAll(src.re)) {
        const nome = m[1], b64 = m[2], buf = Buffer.from(b64.replace(/\s+/g, ''), 'base64');
        if (!buf.length) throw new Error(`${src.dir}/${f}: dati vuoti per ${nome}`);
        if (pulisci64(buf.toString('base64')) !== pulisci64(b64)) throw new Error(`${src.dir}/${f}: base64 non valido per ${nome}`);
        const outDir = path.join(WWW, 'assets', src.out), out = path.join(outDir, nome + src.ext(buf));
        if (!PROVA) {
          fs.mkdirSync(outDir, { recursive: true });
          fs.writeFileSync(out, buf);
          const back = fs.readFileSync(out); // verifica: il file su disco è identico ai dati originali
          if (!back.equals(buf) || pulisci64(back.toString('base64')) !== pulisci64(b64)) throw new Error('verifica fallita: ' + out);
        }
        scritti.push(`${path.relative(WWW, out).replace(/\\/g, '/')} (${buf.length} byte, da ${src.dir}/${f})`);
        n++;
      }
      // il .js è "vuoto" se tolti dati, commenti, 'use strict' e il contenitore SUONI/ASSET non resta niente
      const resto = txt.replace(src.re, '').replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '')
        .replace(/['"]use strict['"]\s*;?/g, '').replace(/var\s+(SUONI|ASSET)\s*=\s*window\.\1\s*\|\|\s*\(\s*window\.\1\s*=\s*\{\s*\}\s*\)\s*;?/g, '').trim();
      if (resto === '') tolti.push(`${src.dir}/${f}`);
      else if (n) console.warn(`ATTENZIONE: ${src.dir}/${f} contiene anche altro codice: non lo cancello`);
    }
  }
  return { tolti, scritti };
}

function togliDaIndex(tolti) {
  const idx = path.join(WWW, 'index.html');
  let h = fs.readFileSync(idx, 'utf8');
  const prima = h;
  for (const f of tolti) {
    const re = new RegExp('[ \\t]*<script\\s+src="' + f.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&') + '(\\?[^"]*)?"\\s*>\\s*</script>[ \\t]*\\r?\\n?', 'g');
    h = h.replace(re, '');
  }
  if (h !== prima) fs.writeFileSync(idx, h);
  return h !== prima;
}

function elenco() {
  const E = { models: {}, audio: {} };
  for (const k of ['models', 'audio']) {
    const dir = path.join(WWW, 'assets', k);
    if (!fs.existsSync(dir)) continue;
    for (const f of fs.readdirSync(dir).sort()) {
      const p = path.join(dir, f), st = fs.statSync(p);
      if (!st.isFile() || f.startsWith('.')) continue;
      const nome = f.replace(/\.[^.]+$/, '');
      E[k][nome] = { f: k + '/' + f, b: st.size };
    }
  }
  const txt = '// Settore Zero — elenco dei file in www/assets (GENERATO da tools/estrai-asset.js: non modificare a mano)\n' +
    '// f = percorso dentro assets/, b = peso in byte (serve alla barra di caricamento)\n' +
    'var ELENCO_ASSET=' + JSON.stringify(E).replace(/\},"/g, '},\n"') + ';\n';
  if (!PROVA) fs.writeFileSync(path.join(WWW, 'assets', 'elenco.js'), txt);
  return E;
}

const { tolti, scritti } = converti();
console.log((PROVA ? '[prova] ' : '') + 'File convertiti: ' + scritti.length);
for (const s of scritti) console.log('  ' + s);
if (!TIENI && tolti.length) {
  for (const f of tolti) fs.unlinkSync(path.join(WWW, f));
  for (const d of ['models', 'suoni']) { const p = path.join(WWW, d); if (fs.existsSync(p) && !fs.readdirSync(p).length) fs.rmdirSync(p); }
  const ch = togliDaIndex(tolti);
  console.log('Vecchi .js cancellati: ' + tolti.join(', ') + (ch ? ' (tag tolti da index.html)' : ''));
}
if (!PROVA) fs.mkdirSync(path.join(WWW, 'assets'), { recursive: true });
const E = elenco();
console.log((PROVA ? '[prova] ' : '') + 'elenco.js: ' + Object.keys(E.models).length + ' modelli, ' + Object.keys(E.audio).length + ' audio');
