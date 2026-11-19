// Impacchetta tutto in un solo file: www/index.html (funziona offline dentro l'app).
import { build } from 'esbuild';
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';

const r = await build({ entryPoints: ['src/main.js'], bundle: true, minify: true, format: 'iife', target: 'es2020', write: false, legalComments: 'none' });
const js = r.outputFiles[0].text.replace(/<\/script/g, '<\\/script');
const tpl = readFileSync('src/index.tpl.html', 'utf8');
mkdirSync('www', { recursive: true });
writeFileSync('www/index.html', tpl.replace('/*BUNDLE*/', () => js));
console.log('www/index.html', (tpl.length + js.length) / 1024 | 0, 'KB');
