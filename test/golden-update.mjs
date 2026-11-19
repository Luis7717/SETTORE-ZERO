// Rigenera test/fixtures/golden.json. Va lanciato SOLO quando il comportamento del motore
// cambia di proposito (e il commit lo dice); mai per "far passare" un refactoring.
import { writeFileSync, mkdirSync } from 'node:fs';
import { SCENARIOS, fingerprint } from './lib/fingerprint.mjs';

const out = SCENARIOS.map(fingerprint);
mkdirSync('test/fixtures', { recursive: true });
writeFileSync('test/fixtures/golden.json', JSON.stringify(out, null, 1) + '\n');
for (const [i, f] of out.entries()) process.stdout.write(`scenario ${i}: ${f.score} ${f.hash}\n`);
