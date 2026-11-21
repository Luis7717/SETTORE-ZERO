// Esporta i riferimenti di src/looks.js usati dalla grafica Godot (godot/tests/test_aspetto.gd): aspetto di chi è in
// campo (lookOf con id "squadra_posto" o id della carriera, con e senza `look`), stile della divisa dal nome della
// squadra (kitStyleFromSeed(hash32(nome))), cognomi per la schiena (backName), colori degli elenchi.
// Uso: node test/export-aspetto.mjs   → godot/tests/fixtures/aspetto.json
// Va rilanciato quando cambia src/looks.js (e va aggiornato godot/scripts/carriera/aspetto.gd).
import { writeFileSync, mkdirSync } from 'node:fs';
import { SKINS, HAIR_COLORS, EYE_COLORS, BOOTS, hash32, lookOf, kitStyleFromSeed, backName } from '../src/looks.js';

const OUT = 'godot/tests/fixtures';
const names = ['L. Ferrante', 'Mario Rossi', '', 'A.B. De Rossi Lunghissimo', 'Città di Pàlermo', 'x.  y', 'squadra 0', 'FC Tiro a Giro', 'Virtus'];

const players = [];
for (let t = 0; t < 2; t++) for (let i = 0; i < 11; i++) players.push({ id: `${t}_${i}`, name: names[(t * 11 + i) % names.length] });
for (const id of [1, 2, 7, -1, -11, 123456]) players.push({ id, name: names[Math.abs(id) % names.length] });
players.push({ id: 5, name: 'M. Rossi', look: { skin: 9, hair: -1, beard: 3 } });
players.push({ id: 6, name: 'Prova', look: { skin: 2, hair: 16, hairColor: 10, eyes: 5, eyeColor: 6, brows: 5, beard: 6, boots: 5 } });

const fixture = {
  lookOf: players.map(p => [p, lookOf(p)]),
  kitStyle: names.map(n => [n, kitStyleFromSeed(hash32(n))]),
  backName: names.map(n => [n, backName(n)]),
  colori: { skins: SKINS.map(x => x[1]), hair: HAIR_COLORS.map(x => x[1]), eyes: EYE_COLORS.map(x => x[1]), boots: BOOTS.map(x => x[1]) },
};
mkdirSync(OUT, { recursive: true });
writeFileSync(`${OUT}/aspetto.json`, JSON.stringify(fixture, null, 1) + '\n');
console.log(`scritto ${OUT}/aspetto.json: ${fixture.lookOf.length} aspetti, ${fixture.kitStyle.length} stili`);
