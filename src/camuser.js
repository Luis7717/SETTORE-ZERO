// Visuale girata dalla persona nel rallenty in attacco (duello col difensore, area di tiro): conti puri, niente
// three e niente DOM, girano in Node (test/unit/camuser.test.mjs). Usati da src/input.js (gesto) e src/render.js
// (telecamera). L'angolo è un "yaw" nello spazio orientato di src/camfit.js: 0 = verso la porta avversaria,
// + = la telecamera guarda verso destra dello schermo, − = verso sinistra.

const DEG = Math.PI / 180;
export const CAM_USER_DEG_PER_SCREEN = 150; // dito trascinato per tutta la larghezza dello schermo = la visuale gira di tanto (gradi)
export const CAM_USER_MAX = 100 * DEG;       // limite rispetto alla direzione d'attacco (rad): oltre si guarderebbe troppo all'indietro
export const CAM_USER_START = 12;            // px in orizzontale prima che il gesto diventi rotazione (sotto è un tocco)
export const CAM_USER_RETURN = 2.5;          // finito il rallenty l'angolo torna a 0 con questa velocità (1/s, tempo vero)
export const CAM_USER_GRAB = -1;             // verso: −1 = si "afferra" il campo (dito verso destra = campo verso destra,
                                             // quindi la visuale guarda più a sinistra); +1 = il contrario
export const CAM_USER_GOAL_YAW = 40 * DEG;   // area di tiro: oltre questo angolo la porta avversaria non si tiene più a schermo

const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);

/** il pallone è fermo sulla bandierina per un calcio d'angolo (di chiunque): anche lì la visuale si gira col dito */
export function cornerCamOn(m) {
  return !!(m && m.phase === 'restart' && m.restart && m.restart.type === 'corner');
}

/** visuale che si può girare: calcio d'angolo, oppure rallenty (fase di gioco, pallone a un giocatore di T, duello, fuga o area di tiro) */
export function userCamOn(m, T) {
  if (cornerCamOn(m)) return true;
  if (!m || m.phase !== 'play') return false;
  const c = m.ball && m.ball.owner;
  if (!c || c.team !== T) return false;
  return !!((m.duelFor && m.duelFor(T)) || (m.fleeFor && m.fleeFor(T)) || (m.inZone && m.inZone(T)));
}

/**
 * Angolo della visuale mentre si trascina: parte da yaw0 (angolo al momento in cui il dito si è appoggiato)
 * e segue lo spostamento orizzontale dx (px) in proporzione alla larghezza dello schermo w (px), entro ±CAM_USER_MAX.
 */
export function dragYaw(yaw0, dx, w) {
  const k = (CAM_USER_DEG_PER_SCREEN * DEG) / Math.max(1, w);
  return clamp(yaw0 + CAM_USER_GRAB * dx * k, -CAM_USER_MAX, CAM_USER_MAX);
}

/** il dito si è spostato abbastanza, e più di lato che in verticale, per girare la visuale? */
export function isCamDrag(dx, dy) {
  return Math.abs(dx) >= CAM_USER_START && Math.abs(dx) > Math.abs(dy);
}

/**
 * Angolo a ogni fotogramma: nel rallenty (o mentre si disegna una linea) resta quello scelto dalla persona;
 * fuori torna dolcemente a 0 (rdt = tempo vero in secondi). Torna a 0 del tutto: al rallenty dopo si riparte dritti.
 */
export function relaxYaw(yaw, hold, rdt) {
  if (hold) return clamp(yaw, -CAM_USER_MAX, CAM_USER_MAX);
  const y = yaw * Math.exp(-CAM_USER_RETURN * Math.max(0, rdt));
  return Math.abs(y) < 1e-3 ? 0 : y;
}

/** nell'area di tiro la porta avversaria resta a schermo solo con la visuale poco girata */
export function keepGoal(zone, yaw) {
  return !!zone && Math.abs(yaw) <= CAM_USER_GOAL_YAW;
}
