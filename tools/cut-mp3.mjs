// Ritaglia un MP3 tra due tempi senza ricodificarlo (taglia ai bordi dei frame MPEG).
// Uso: node tools/cut-mp3.mjs ingresso.mp3 uscita.mp3 inizio_s fine_s
import { readFileSync, writeFileSync } from 'node:fs';

const BR = { 1: [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320], 2: [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160] };
const SR = { 3: [44100, 48000, 32000], 2: [22050, 24000, 16000], 0: [11025, 12000, 8000] };

export function frames(buf) {
  let i = 0;
  if (buf.toString('latin1', 0, 3) === 'ID3') i = 10 + ((buf[6] & 127) << 21 | (buf[7] & 127) << 14 | (buf[8] & 127) << 7 | (buf[9] & 127));
  const out = [];
  while (i + 4 <= buf.length) {
    if (buf[i] !== 0xff || (buf[i + 1] & 0xe0) !== 0xe0) { i++; continue; }
    const ver = (buf[i + 1] >> 3) & 3, layer = (buf[i + 1] >> 1) & 3, bri = buf[i + 2] >> 4, sri = (buf[i + 2] >> 2) & 3, pad = (buf[i + 2] >> 1) & 1;
    if (ver === 1 || layer !== 1 || bri === 0 || bri === 15 || sri === 3) { i++; continue; }
    const sr = SR[ver][sri], br = BR[ver === 3 ? 1 : 2][bri] * 1000, spf = ver === 3 ? 1152 : 576;
    const len = Math.floor((spf / 8) * br / sr) + pad;
    out.push({ off: i, len, dur: spf / sr });
    i += len;
  }
  return out;
}

if (process.argv[1] && process.argv[1].endsWith('cut-mp3.mjs')) {
  const [, , inp, outp, a, b] = process.argv;
  const buf = readFileSync(inp), fr = frames(buf);
  let t = 0; const keep = [];
  for (const f of fr) { if (t >= +a && t < +b) keep.push(buf.subarray(f.off, f.off + f.len)); t += f.dur; }
  writeFileSync(outp, Buffer.concat(keep));
  console.log(outp, keep.length, 'frame,', (Buffer.concat(keep).length / 1024).toFixed(0), 'KB, durata totale originale', t.toFixed(2), 's');
}
