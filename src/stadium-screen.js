// Maxischermo sopra la tribuna di fondo: nome dello stadio, squadre col loro colore e risultato.
// Si ridisegna solo quando cambia qualcosa (squadre, risultato, scritta GOL).
import * as THREE from 'three';
import { canvasTex, redrawTex, fitText } from './stadium-kit.js';

export const SCREEN_ASPECT = 512 / 192;

function drawScreen(g, w, h, st) {
  g.fillStyle = '#0a0d14'; g.fillRect(0, 0, w, h);
  const gr = g.createLinearGradient(0, 8, 0, h - 8); gr.addColorStop(0, '#12306a'); gr.addColorStop(1, '#061230');
  g.fillStyle = gr; g.fillRect(8, 8, w - 16, h - 16);
  g.textBaseline = 'middle';
  if (st.goal) {
    g.fillStyle = '#ffd43b'; g.fillRect(8, 8, w - 16, h - 16);
    g.fillStyle = '#0b1a3a'; g.textAlign = 'center'; fitText(g, 'GOOOL!', w / 2, h / 2 - 14, w - 60, 96);
    g.font = '800 26px system-ui, Arial, sans-serif'; g.fillText(`${st.names[0]}  ${st.score[0]} - ${st.score[1]}  ${st.names[1]}`, w / 2, h - 34, w - 60);
  } else {
    g.fillStyle = '#ffd43b'; g.textAlign = 'center'; fitText(g, 'STADIO DEI TIGLI', w / 2, 34, w - 80, 24, 800);
    g.fillStyle = 'rgba(255,255,255,0.15)'; g.fillRect(30, 54, w - 60, 2);
    for (const i of [0, 1]) {
      const x = i ? w - 105 : 105;
      g.fillStyle = '#fff'; g.fillRect(x - 62, 72, 124, 22);
      g.fillStyle = st.colors[i][0]; g.fillRect(x - 60, 74, 120, 12); g.fillStyle = st.colors[i][1]; g.fillRect(x - 60, 86, 120, 6);
      g.fillStyle = '#fff'; fitText(g, st.names[i], x, 128, 140, 40);
    }
    g.fillStyle = 'rgba(0,0,0,0.35)'; g.fillRect(w / 2 - 70, 70, 140, 84);
    g.fillStyle = '#fff'; fitText(g, `${st.score[0]} - ${st.score[1]}`, w / 2, 114, 124, 60);
    g.fillStyle = 'rgba(255,255,255,0.55)'; fitText(g, 'TIRO A GIRO', w / 2, 164, 200, 16, 800);
  }
  g.fillStyle = 'rgba(0,0,0,0.18)'; for (let y = 8; y < h - 8; y += 3) g.fillRect(8, y, w - 16, 1);
}

export function makeScreen() {
  const st = { names: ['CASA', 'OSPITI'], colors: [['#d23b3b', '#fff'], ['#2f6fd6', '#f2c230']], score: [0, 0], goal: false };
  let key = '';
  const tex = canvasTex(512, 192, (g, w, h) => drawScreen(g, w, h, st));
  const set = (patch) => {
    Object.assign(st, patch);
    const k = JSON.stringify(st); if (k === key) return; key = k;
    redrawTex(tex, (g, w, h) => drawScreen(g, w, h, st));
  };
  const material = new THREE.MeshBasicMaterial({ map: tex, toneMapped: false });
  return { material, set, state: st };
}
