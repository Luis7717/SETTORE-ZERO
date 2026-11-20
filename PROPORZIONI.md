# Proporzioni del calciatore (date dal coordinatore — valgono per tutte le parti del corpo)

Unità: **T = altezza della testa** (dal mento alla cima del cranio, senza capelli). Altezza totale **8 T** (≈ 1,80 m → T ≈ 22,5 cm).
Corporatura: **calciatore professionista**, atletico e asciutto, non culturista né supereroe.

| Misura | Valore |
|---|---|
| Altezza totale | 8 T |
| Testa: alta / larga / profonda | 1 T / 0,68 T / 0,82 T |
| Collo visibile (mento → attaccatura spalle) | 0,35 T; larghezza collo 0,5 T |
| Spalle (da deltoide a deltoide) | 1,9 T |
| Petto: larghezza / profondità | 1,45 T / 0,95 T |
| Vita: larghezza / profondità | 1,15 T / 0,8 T (busto a V leggera) |
| Bacino (anche) | 1,35 T |
| Ombelico | a 4,9 T da terra |
| Cavallo (inizio gambe) | a 4 T da terra (gambe = metà altezza) |
| Ginocchio (centro) | a 2,05 T da terra |
| Caviglia | a 0,35 T da terra |
| Piede: lungo / largo | 1,15 T / 0,42 T |
| Coscia: larghezza massima | 0,72 T (muscolosa, il punto più largo delle gambe) |
| Polpaccio: larghezza massima | 0,5 T, a 1,35 T da terra |
| Braccio: spalla → gomito → polso | 1,45 T / 1,2 T; gomito all'altezza della vita |
| Mano | 0,75 T; con le braccia lungo i fianchi la punta delle dita arriva a metà coscia (≈ 3,3 T da terra) |
| Braccio: larghezza bicipite / avambraccio | 0,42 T / 0,36 T (tonico, non gonfio) |

Divisa: maglia leggermente morbida sul busto (non dipinta sulla pelle), maniche corte fino a metà bicipite;
pantaloncini fino a 0,6 T sopra il ginocchio, larghi 0,1 T oltre la coscia; calzettoni fino a 0,3 T sotto il ginocchio
(con parastinchi: stinco appena più pieno); scarpe da calcio basse e affusolate.

Regole per chi rifinisce una parte:
- Si tocca solo la propria parte; i punti di giunzione (collo, spalle/ascelle, vita, caviglie) restano dove sono e senza buchi.
- Si lavora sul modello `assets/models/athlete.glb` già in uso (Quaternius Universal Base Characters, CC0) senza rigenerarlo:
  le correzioni si applicano a codice al caricamento (deformazione dei vertici della propria zona, pittura della propria zona),
  in un file proprio `src/body/<parte>.js`, chiamato da `src/athlete3d.js` con una riga sola.
- Animazioni, pose (`players3d.js` e `trickPose`), editor e formato dei salvataggi restano compatibili.
