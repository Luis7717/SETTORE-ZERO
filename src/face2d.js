// Ritratto piccolo per le carte della Rosa: viso disegnato in SVG (niente WebGL), dai colori di `look`
// (pelle, capelli e barba col loro colore, taglio approssimato) e con la maglia della squadra.
// Puro: ritorna una stringa SVG, gira anche in Node.
import { SKINS, HAIR_COLORS, normalizeLook } from './looks.js';

// colore #rrggbb scurito (f < 1) o schiarito (f > 1)
export function shade(hex, f) {
  const n = parseInt(hex.slice(1), 16), ch = s => Math.max(0, Math.min(255, Math.round(((n >> s) & 255) * f)));
  return '#' + ((ch(16) << 16) | (ch(8) << 8) | ch(0)).toString(16).padStart(6, '0');
}

// calotta di capelli che copre la parte alta della testa (attaccatura intorno a y = 11..16)
const CAP = 'M11.2 16C11 9 15 6.5 20 6.5S29 9 28.8 16C27 12.5 24 11 20 11S13 12.5 11.2 16Z';
const CAP_HIGH = 'M11.2 14.5C11 8.5 15 6.2 20 6.2S29 8.5 28.8 14.5C27.5 11 24 9.6 20 9.6S12.5 11 11.2 14.5Z';
const CURLS = [[12.4, 12.4], [13.8, 8.8], [16.6, 6.7], [20, 6], [23.4, 6.7], [26.2, 8.8], [27.6, 12.4]];
const JAW = 'M11.6 18.5C11.8 25 15.5 27.4 20 27.4S28.2 25 28.4 18.5L27 19.2C26.4 22.6 24 23 20 23S13.6 22.6 13 19.2Z';
const MOUSTACHE = 'M16.6 22.7Q20 21.2 23.4 22.7Q20 23.5 16.6 22.7Z';
const GOATEE = '<ellipse cx="20" cy="25.7" rx="2.2" ry="1.6"';

// capelli per ogni taglio di HAIR_STYLES: [dietro la testa, davanti]
function hairParts(style, c) {
  const p = (d, extra = '') => `<path d="${d}" fill="${c}"${extra}/>`;
  switch (style) {
    case 0: return ['', ''];                                                     // calvo
    case 1: return ['', p(CAP, ' opacity=".45"')];                              // rasato
    case 3: return ['', p('M11.2 15L11.4 7.6Q20 4.8 28.6 7.6L28.8 15C27 12 24 10.6 20 10.6S13 12 11.2 15Z')]; // spazzola
    case 4: return ['', p(CAP) + p('M14.6 9.6Q20.5 2 27.4 7.8Q23.2 6.6 19 10.4Z')]; // ciuffo
    case 5: return ['', p(CAP) + `<path d="M15.4 7.4L14.2 11.6" stroke="${shade(c, 1.9)}" stroke-width=".8" opacity=".6"/>`]; // riga di lato
    case 6: return ['', p(CAP, ' opacity=".3"') + p('M17.6 12Q17 4.2 20 2.4Q23 4.2 22.4 12Z')]; // cresta
    case 7: return ['', p('M11.2 15L11 9L13.5 9.6L14 5L16.8 7.6L18.5 3.4L20.6 7L23 3.8L24.2 7.7L27 5.5L27.2 9.6L29 9.6L28.8 15C27 12 24 10.8 20 10.8S13 12 11.2 15Z')]; // a punte
    case 8: return ['', p(CAP) + CURLS.map(([x, y]) => `<circle cx="${x}" cy="${y}" r="2.7" fill="${c}"/>`).join('')]; // ricci
    case 9: return [`<circle cx="20" cy="13.5" r="12.6" fill="${c}"/>`, p(CAP)]; // afro
    case 10: return ['', p('M10.6 20C10 9 14.5 5.8 20 5.8S30 9 29.4 20L27.8 20C27.6 15 25 12.6 20 12.6S12.4 15 12.2 20Z')]; // caschetto
    case 11: return [p('M10.5 15C10 7 15 5.5 20 5.5S30 7 29.5 15L30.2 31L26 31L27 18L13 18L14 31L9.8 31Z'), p(CAP)]; // lunghi
    case 12: return [p('M26.6 11.6Q33.6 15.6 31.4 27.4Q29.4 21 26.2 16.4Z'), p(CAP)]; // coda
    case 13: return [`<circle cx="20" cy="5.4" r="3.7" fill="${c}"/>`, p(CAP)]; // chignon
    case 14: return [[10.8, 12.4, 27.6, 29.2].map(x => `<path d="M${x} 12V27" stroke="${c}" stroke-width="1.5" stroke-linecap="round"/>`).join(''), p(CAP)]; // treccine
    case 15: return ['', p(CAP) + p('M11.6 14.6Q16 11 20 13.6Q24 11 28.4 14.6L28.6 11Q20 6.8 11.4 11Z')]; // frangia
    case 16: return ['', p(CAP_HIGH) + `<path d="M15 8.6Q20 7 25 8.6" stroke="${shade(c, 1.6)}" stroke-width=".7" fill="none" opacity=".7"/>`]; // all'indietro
    default: return ['', p(CAP)];                                                // corti
  }
}

function beard(kind, c) {
  const jaw = o => `<path d="${JAW}" fill="${c}" opacity="${o}"/>`;
  const mou = `<path d="${MOUSTACHE}" fill="${c}"/>`, goat = `${GOATEE} fill="${c}"/>`;
  return ['', jaw(0.25), goat, mou, mou + goat, jaw(0.7), jaw(1) + mou][kind] || '';
}

// viso: look (anche incompleto o vecchio: si normalizza), maglia e colletto coi colori #rrggbb della squadra
export function faceSvg(look, shirt, collar, cls = 'face') {
  const l = normalizeLook(look), skin = SKINS[l.skin][1], hair = HAIR_COLORS[l.hairColor][1];
  const [back, front] = hairParts(l.hair, hair), dark = shade(skin, 0.82);
  return `<svg class="${cls}" viewBox="0 0 40 40" aria-hidden="true">${back}`
    + `<path d="M3.5 40C4.5 32 11 29.2 20 29.2S35.5 32 36.5 40Z" fill="${shirt}"/>`
    + `<path d="M15 29.6Q20 34.4 25 29.6" fill="none" stroke="${collar}" stroke-width="2"/>`
    + `<path d="M16.6 23.5h6.8v6.6Q20 32 16.6 30.1Z" fill="${dark}"/>`
    + `<ellipse cx="11.4" cy="18.6" rx="1.7" ry="2.5" fill="${dark}"/><ellipse cx="28.6" cy="18.6" rx="1.7" ry="2.5" fill="${dark}"/>`
    + `<ellipse cx="20" cy="17" rx="8.6" ry="10.2" fill="${skin}"/>`
    + beard(l.beard, hair)
    + `<circle cx="16.6" cy="17.8" r="1.05" fill="#1a1412"/><circle cx="23.4" cy="17.8" r="1.05" fill="#1a1412"/>`
    + `<path d="M15 15.4h3.2M21.8 15.4H25" stroke="${hair}" stroke-width="1" stroke-linecap="round"/>`
    + `<path d="M18 23.6Q20 24.6 22 23.6" fill="none" stroke="${shade(skin, 0.6)}" stroke-width=".8" stroke-linecap="round"/>`
    + front + '</svg>';
}
