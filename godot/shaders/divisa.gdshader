// Divisa, pelle, capelli e viso del giocatore (modello athlete.glb, Quaternius CC0), dipinti per zone del corpo come
// fa src/athlete3d.js nel gioco web, ma calcolati qui per pixel invece che in una texture.
// CUSTOM0.xyz = posizione del vertice nella posa di riposo (a T), scritta da scripts/giocatore.gd: le zone
// (maglia, maniche, pantaloncini, calzettoni, scarpe, testa, capelli) seguono il corpo anche mentre corre.
// I colori e lo stile cambiano per giocatore con le "instance uniform" (un solo materiale per tutti i 22):
//   stile  = maniche (0 corte, 1 lunghe, 2 senza), colletto (0 girocollo, 1 a V, 2 polo), motivo (0 tinta unita,
//            1 righe verticali, 2 orizzontali, 3 banda diagonale, 4 metà e metà), calzettoni (0 alti, 1 bassi, 2 ripiegati)
//   stile2 = taglio dei capelli (0..16 come HAIR_STYLES di src/looks.js), barba (0..6), sopracciglia (0..5),
//            pantaloncini (0 corti, 1 lunghi)
//   numero = cella (x, y) del cognome e numero nell'atlante "schiene" (scripts/partita/schiene.gd), z = 1 se c'è
//            (+2 = fascia da capitano: niente uniform nuova, il limite è 16 e sono tutte usate), w = maglia larga (1)
//            o aderente (0)
//   corsa  = 0..1 quanto corre (la maglia ondeggia)
//   occhi_forma = forma degli occhi (0..5 come EYE_SHAPES di src/looks.js)
// Colletto (2026-11-22; prima i tre erano quasi uguali: la V restava dentro il cilindro del collo e la polo era solo
// una riga): girocollo = bordino tondo; a V = la pelle scende sul petto (V_FONDO) col bordino lungo i lati; polo =
// colletto rialzato sul collo (anche spostando i vertici, si vede di profilo), due risvolti sul petto, abbottonatura
// con due bottoni. Vestibilità: CUSTOM2.x = profondità della "valle" del corpo (scripts/partita/vestibilita.gd).
// Larga = la stoffa riempie le valli invece di gonfiare il corpo in proporzione, si svasa verso l'orlo, che scende
// sopra i pantaloncini (con l'ombra), maniche più lunghe e ampie, pieghe e stoffa opaca; aderente = niente stacco,
// valli un filo più scure e stoffa più lucida: si vedono i muscoli.
// Testa (dal 2026-11-21, seconda versione, come il web: src/athlete3d.js e src/body/testa.js): cos'è testa, collo o
// busto lo dice l'osso che muove di più il vertice (CUSTOM0.w = 1 se è la testa, CUSTOM1.w = 1 se è il collo), non
// l'altezza: prima la parte sotto il mento finiva nella maglia (fascia del colore del bordino sotto il mento). Il collo
// resta pelle fin sotto il mento (scollo "rilassato" sulla gola, neckSkin del web); il colletto resta dov'è.
// Sul viso: toni della pelle, linea delle ciglia, barba, sopracciglia e labbra del web (maschere disegnate col canvas
// in assets/textures/viso_maschere.png, proiettate dalla "zona viso" con le misure di scripts/partita/viso.gd), con
// la grana; sotto i capelli la tinta della cute (scalpPaint di src/hair3d.js, riferimento di capelli.gd); occhi con le
// 6 forme dell'editor (src/body/occhi.js) dipinti in millimetri dentro la parte del bulbo che si vede.
// CUSTOM1.xyz = normale nella posa di riposo. I conti del viso si fanno in sRGB (circa: radice quadrata) come il web.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;   // lambert: più leggero di burley sul telefono

instance uniform vec4 maglia : source_color = vec4(0.78, 0.06, 0.18, 1.0);
instance uniform vec4 calzoncini : source_color = vec4(1.0);
instance uniform vec4 calzettoni : source_color = vec4(0.78, 0.06, 0.18, 1.0);
instance uniform vec4 bordino : source_color = vec4(1.0);
instance uniform vec4 pelle : source_color = vec4(0.94, 0.79, 0.65, 1.0);
instance uniform vec4 capelli : source_color = vec4(0.11, 0.08, 0.06, 1.0);
instance uniform vec4 iride : source_color = vec4(0.25, 0.17, 0.1, 1.0);
instance uniform vec4 scarpe : source_color = vec4(0.08, 0.08, 0.09, 1.0);
instance uniform vec4 stile = vec4(0.0);
instance uniform vec4 stile2 = vec4(2.0, 0.0, 0.0, 0.0);
instance uniform vec4 numero = vec4(0.0);
instance uniform float corsa = 0.0;
instance uniform float occhi_forma = 0.0;
instance uniform vec4 barba : source_color = vec4(0.0);   // colore della barba (Aspetto.colore_barba); a = 0: capelli
instance uniform vec4 iride2 : source_color = vec4(0.0);  // eterocromia: colore dell'occhio sinistro (x > 0) se a = 1
instance uniform vec4 sopracciglia : source_color = vec4(0.0);   // a = 1: colore delle sopracciglia (capelli particolari)

// contorno di luce (2026-11-24): i bordi della figura visti di taglio si schiariscono un po' (luce da dietro), così i
// giocatori si staccano dall'erba anche piccoli. rgb = colore, a = forza (0 = niente); lo cambia l'ora della partita
// (Giocatore.set_contorno da scripts/partita/meteo.gd). Costo: qualche conto per pixel, niente letture di texture.
uniform vec4 contorno = vec4(1.0, 0.97, 0.9, 0.5);
const float CONTORNO_ESP = 3.0;   // più alto = bordo più sottile

// misure del corpo in posa di riposo (m), dalle ossa: le imposta scripts/giocatore.gd
uniform float anca_y = 0.97;
uniform float caviglia_y = 0.09;
uniform float collo_y = 1.52;
uniform float collo_z = -0.041;
uniform float petto_y = 1.38;
uniform float spalla_x = 0.17;
uniform float gomito_x = 0.45;
uniform float polso_x = 0.68;
uniform float testa_alto = 1.81;
uniform vec3 testa = vec3(0.0, 1.6, 0.0);
uniform vec3 occhi = vec3(0.034, 1.698, 0.07);   // centro dell'occhio sinistro (x > 0)
uniform vec2 davanti = vec2(0.0, 1.0);   // verso del viso nella posa di riposo (piano xz)
uniform sampler2D schiene : source_color, hint_default_transparent, filter_linear_mipmap, repeat_disable;
// riferimento dei capelli (scripts/partita/capelli.gd): centro e assi
uniform vec3 cap_c = vec3(0.0, 1.72, 0.0);
uniform vec3 cap_up = vec3(0.0, 0.985, -0.174);
uniform vec3 cap_fwd = vec3(0.0, 0.174, 0.985);
uniform vec3 cap_right = vec3(1.0, 0.0, 0.0);
// viso (scripts/partita/viso.gd)
uniform vec4 viso_proiezione = vec4(0.0, 1.698, 1100.0, 900.0);   // mezzo degli occhi x, occhi y, px/m in x e in y
uniform float viso_mento = 1.6;
uniform vec4 viso_guance = vec4(0.038, -0.032, 0.018, -0.03);      // guance x, y, raggio; naso y
uniform vec4 viso_naso_orecchie = vec4(0.012, 0.07, 0.01, 0.033);   // naso raggio; orecchie x, z; mezza distanza occhi
uniform vec4 viso_occhio = vec4(0.034, 1.698, 0.07, 0.012);        // centro dell'occhio sinistro, raggio dell'apertura
uniform vec3 occhio_f = vec3(0.034, 1.698, 0.08);                  // punto più avanti del bulbo sinistro
uniform vec4 occhio_finestra = vec4(0.0, 0.0, 13.0, 5.0);          // parte visibile: centro x, y, semilarghezza, semialtezza (mm)
uniform sampler2D viso_maschere : hint_default_black, filter_linear_mipmap, repeat_disable;

const float COLLO_R = 0.085;      // mezza larghezza del collo (m)
const float SCOLLO_R = 0.078;     // raggio dello scollo attorno al collo (m)
const float BORDO = 0.014;        // bordini (colletto, maniche, calzettoni) (m)
const float AA = 0.005;           // bordi morbidi dei motivi (m)
// fascia da capitano (Luis 2026-11-27, "basta una striscia gialla sul braccio"): sul braccio sinistro (x > 0), sopra il
// gomito, tra queste frazioni del tratto spalla → gomito (sopra l'orlo della manica corta, che finisce da 0,55 in giù)
const vec2 FASCIA_T = vec2(0.2, 0.47);
const vec3 FASCIA_COLORE = vec3(1.0, 0.72, 0.02);   // giallo (lineare)
const float FASCIA_ORLO = 0.15;   // bordi un po' più scuri (frazione della larghezza): si vede anche su una maglia gialla
const vec2 OCCHI_UV = vec2(0.875); // tassello degli occhi nell'atlante (come EYE_PX del web: 896/1024)
const vec2 CELLA = vec2(0.125, 0.25); // atlante delle schiene: 8 × 4 celle
const float SCHIENA = 0.4;        // m di schiena coperti da una cella (come il canvas 256 px del web)
const float NECK_FRONT = 0.03;    // gola: scollo misurato come se fosse più vicina (neckSkin di src/body/testa.js)
const float NECK_RELAX = 0.75;
const vec2 BEARD_UNDER = vec2(0.012, 0.034);   // m: sotto il mento la barba sfuma tra queste distanze
const vec2 BEARD_UNDER_PIENA = vec2(0.03, 0.065); // barba piena: scende sul collo
// barbe 1..6 (2026-11-22): x = quanti peli (1 = fitta, meno = si vede la pelle in mezzo), y = copertura massima
const vec2 BARBA_PELO[6] = vec2[6](vec2(0.5, 0.6), vec2(1.0, 0.95), vec2(1.0, 0.95), vec2(1.0, 0.95), vec2(0.62, 0.8), vec2(1.0, 1.0));
const vec2 LASH = vec2(0.0024, 0.75);          // linea delle ciglia: larghezza (m), intensità
// maschere del viso (tools/make-godot-tex.mjs): zona FACE_CROP del web, celle 4 × 2
const vec4 FACE_CROP = vec4(200.0, 150.0, 240.0, 260.0);
const vec2 MASCHERE = vec2(960.0, 520.0);
const float AA_MM = 0.35;
const float PALPEBRA_MAX = 1.2;   // occhi: apertura massima sopra e sotto (frazioni della semialtezza della finestra);
                                  // 0,9 fino al 2026-11-22: occhi socchiusi, sguardo assonnato
const float V_FONDO = 0.10;        // scollo a V: quanto scende sul petto sotto lo scollo tondo (m)
const float V_MEZZA = 0.055;       // scollo a V: mezza larghezza in alto (m)
const float POLO_ALTO = 0.04;      // polo: altezza del colletto rialzato dietro (davanti POLO_ALTO_DAVANTI) (m)
const float POLO_ALTO_DAVANTI = 0.028;
const float POLO_RIALZO = 0.011;   // polo: di quanto il colletto si stacca dal collo (m)
const float POLO_LISTA = 0.013;    // polo: mezza larghezza dell'abbottonatura (m)
const float POLO_LISTA_GIU = 0.11; // polo: lunghezza dell'abbottonatura sotto lo scollo (m)
const float LARGA_ORLO = 0.06;     // maglia larga: l'orlo scende di tanto sopra i pantaloncini (m)
const float LARGA_BASE = 0.006;    // maglia larga: stacco minimo dal corpo (m)
const float LARGA_SVASO = 0.024;   // maglia larga: stacco in più all'orlo (m)
const float LARGA_MANICA = 0.016;  // maglia larga: manica più ampia in fondo (m)
const float LARGA_VALLE = 0.015;   // maglia larga: valle più profonda che si riempie (m)
const float LARGA_PIEGHE = 0.13;   // maglia larga: quanto scuriscono le pieghe
// stoffa (2026-11-26): sulla maglia la luce segue un po' la superficie levigata (TANGENT = normale levigata, messa da
// scripts/giocatore.gd) invece di ogni muscolo: la larga quasi del tutto ("gonfia", a bozzi), l'aderente poco
const float LISCIA_LARGA = 0.85;
const float LISCIA_ADERENTE = 0.3;
// calzoncini (2026-11-26): non più una seconda pelle da ciclista: si staccano un po' dalla coscia e si svasano verso
// l'orlo (non nell'interno coscia: le gambe si toccherebbero), con la luce della superficie levigata
const float CALZ_BASE = 0.004;     // stacco minimo (m)
const float CALZ_SVASO = 0.02;     // stacco in più all'orlo (m)
const float CALZ_LISCIA = 0.7;
const float RILIEVO = 0.55;        // viso: forza delle ombre del rilievo
const float RILIEVO_LUCE = 0.3;    // viso: forza delle luci del rilievo
const float COLLO_OMBRA = 0.88;    // collo: sotto il mento la pelle è in ombra (stacca il viso, il collo sembra meno lungo)
const float ADERENTE_MUSCOLI = 9.0; // maglia aderente: scurimento per metro di valle (al massimo 0,2)
const float IRIDE_K = 1.15;       // occhi: iride più grande del web (la finestra misurata qui è più piccola)
const float IRIDE_SU = 0.1;       // occhi: iride al centro dell'apertura, un filo in alto (sguardo dritto, non in basso)

// tagli (HAIR di src/hair3d.js): attaccatura, 5 nodi [|az|, el] per taglio (per rasato e cresta: la nuca rasata)
const vec2 LINEE[85] = vec2[85](
	vec2(0, 95), vec2(45, 95), vec2(85, 95), vec2(105, 95), vec2(180, 95),
	vec2(0, 30), vec2(45, 24), vec2(85, 8), vec2(105, 5), vec2(180, -20),
	vec2(0, 31), vec2(45, 25), vec2(85, 8), vec2(105, 5), vec2(180, -20),
	vec2(0, 33), vec2(45, 27), vec2(85, 9), vec2(105, 6), vec2(180, -18),
	vec2(0, 31), vec2(45, 25), vec2(85, 8), vec2(105, 5), vec2(180, -20),
	vec2(0, 28), vec2(45, 22), vec2(85, 6), vec2(105, 3), vec2(180, -20),
	vec2(0, 30), vec2(45, 24), vec2(85, 8), vec2(105, 5), vec2(180, -20),
	vec2(0, 31), vec2(45, 25), vec2(85, 8), vec2(105, 5), vec2(180, -20),
	vec2(0, 27), vec2(45, 21), vec2(85, 2), vec2(110, -2), vec2(180, -26),
	vec2(0, 23), vec2(45, 17), vec2(85, -6), vec2(110, -9), vec2(180, -30),
	vec2(0, 19), vec2(34, 18), vec2(64, -32), vec2(120, -36), vec2(180, -38),
	vec2(0, 26), vec2(30, 22), vec2(66, -44), vec2(120, -62), vec2(180, -70),
	vec2(0, 30), vec2(45, 24), vec2(85, 7), vec2(105, 5), vec2(180, -18),
	vec2(0, 30), vec2(45, 24), vec2(85, 7), vec2(105, 5), vec2(180, -18),
	vec2(0, 26), vec2(30, 22), vec2(66, -38), vec2(120, -56), vec2(180, -62),
	vec2(0, 4), vec2(32, 6), vec2(68, -6), vec2(100, -8), vec2(180, -22),
	vec2(0, 37), vec2(45, 30), vec2(85, 10), vec2(105, 7), vec2(180, -18)
);
// 1 = attaccatura morbida, 2 = rasato dipinto (puntini), 6 = rasato + cresta
const int TIPO_TAGLIO[17] = int[17](0, 2, 1, 1, 1, 1, 6, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);
const vec3 STRIP = vec3(17.0, 34.0, 200.0);   // cresta: semilarghezza (gradi), da, a (ph)
// forme degli occhi (EYE_FORMS di src/body/occhi.js): (ci, co, yi, yo), (hu, hl, a, pu), (iride, piega)
const vec4 OCCHI_A[6] = vec4[6](vec4(0.8, 0.82, -0.12, 0.02), vec4(0.95, 1.0, -0.42, 0.5), vec4(0.78, 0.8, -0.05, 0.05),
	vec4(1.08, 1.08, -0.12, 0.0), vec4(1.12, 1.15, -0.05, 0.08), vec4(0.95, 0.95, -0.3, -0.36));
const vec4 OCCHI_B[6] = vec4[6](vec4(1.35, 1.3, 0.42, 0.5), vec4(0.78, 0.62, 1.05, 0.4), vec4(0.4, 0.34, 0.8, 0.5),
	vec4(1.45, 1.45, 0.5, 0.5), vec4(0.56, 0.5, 0.5, 0.5), vec4(0.28, 0.95, 0.55, 0.55));
const vec2 OCCHI_C[6] = vec2[6](vec2(0.92, 0.0), vec2(0.86, 0.0), vec2(0.86, 0.25), vec2(1.2, 0.0), vec2(0.86, 0.0), vec2(0.92, 0.4));

varying vec3 riposo;
varying vec3 normale_riposo;
varying vec2 classe;   // x = testa, y = collo (osso che muove di più il vertice)
varying float valle;   // profondità della valle del corpo (m, CUSTOM2.x)

// smoothstep che va bene anche con a > b (come smooth del web)
float sm(float a, float b, float x) {
	float t = clamp((x - a) / (b - a), 0.0, 1.0);
	return t * t * (3.0 - 2.0 * t);
}

// peli della barba: celle di 0,45 mm, hash senza sin (con sin a questi valori venivano righe diagonali)
float pelo_hash(vec3 p, float semi) {
	vec3 q = fract(floor(p * 2200.0) * 0.1031 + semi);
	q += dot(q, q.zyx + 31.32);
	return fract((q.x + q.y) * q.z);
}

float grana(vec3 p) {
	return fract(sin(dot(floor(p * 1400.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// fondo della maglia: la larga scende sopra i pantaloncini
float maglia_fine(float larga) {
	return anca_y + 0.035 - larga * LARGA_ORLO;
}

// fine della manica (x di riposo): la larga è più lunga
float manica_fine(int maniche, float larga) {
	if (maniche == 1) {
		return polso_x - 0.015;
	}
	if (maniche == 0) {
		return spalla_x + mix(0.55, 0.72, larga) * (gomito_x - spalla_x);
	}
	return spalla_x - 0.035 + larga * 0.01;
}

// altezza sopra lo scollo tondo (neckline di src/athlete3d.js): dietro più alto, davanti più basso
float scollo_y(vec3 p, float zf) {
	float ax = abs(p.x);
	float base = collo_y - 0.012;
	if (zf <= collo_z) {
		return p.y - (base + 0.004 + 4.0 * ax * ax);
	}
	return p.y - (base - 0.028 + 5.0 * ax * ax);
}

// scollo: > 0 dentro lo scollo (pelle), vicino a 0 il bordino
float scollo(int collar, vec3 p, float zf) {
	float ax = abs(p.x);
	float radiale = SCOLLO_R - length(vec2(p.x, (zf - collo_z) * 1.15));
	float d = min(scollo_y(p, zf), radiale);
	if (collar == 1 && zf > collo_z) {
		// V sul petto (neckline di src/body/busto.js): la pelle scende al centro anche fuori dal cilindro del collo;
		// distanza perpendicolare ai lati, così il bordino è largo uguale in tutta la V
		float fronte = collo_y - 0.04 + 5.0 * ax * ax;
		float vy = fronte - V_FONDO * max(0.0, 1.0 - ax / V_MEZZA);
		float dv = (p.y - vy) * V_MEZZA / length(vec2(V_MEZZA, V_FONDO));
		d = max(d, min(dv, (V_MEZZA - ax) * 0.8));
	}
	return d;
}

// polo: colletto rialzato (dietro più alto), aperto davanti sopra l'abbottonatura
float polo_alto(float zf) {
	return mix(POLO_ALTO, POLO_ALTO_DAVANTI, sm(collo_z - 0.02, collo_z + 0.04, zf));
}

bool polo_aperto(float ax, float yb, float zf) {
	return zf > collo_z + 0.015 && ax < 0.011 + max(yb, 0.0) * 0.5;
}

// quanto il punto è colletto rialzato della polo (0..1); m = margine (più largo per spostare i vertici)
float polo_colletto(vec3 p, float zf, float m) {
	float yb = scollo_y(p, zf);
	if (polo_aperto(abs(p.x), yb, zf)) {
		return 0.0;
	}
	float h = polo_alto(zf);
	return sm(-0.003 - m, 0.001, yb) * sm(h + 0.002 + m, h - 0.002, yb);
}

void vertex() {
	riposo = CUSTOM0.xyz;
	normale_riposo = CUSTOM1.xyz;
	classe = vec2(CUSTOM0.w, CUSTOM1.w);
	valle = CUSTOM2.x;
	vec3 p = riposo;
	if (classe.x < 0.5) {   // la testa (e il mento) non si sposta mai
		float larga = clamp(numero.w, 0.0, 1.0);
		float ax = abs(p.x);
		float zf = dot(p.xz, davanti);
		float fine = maglia_fine(larga);
		float mf = manica_fine(int(stile.x + 0.5), larga);
		bool braccio = ax > spalla_x - 0.02;
		float off = 0.0;
		if (classe.y < 0.5 && p.y > fine - 0.03 && p.y < collo_y && ax < mf + 0.02) {
			// maglia: larga = stacco che riempie le valli e si svasa verso l'orlo e in fondo alle maniche (lo scollo
			// resta aderente); mentre corre ondeggia, di più verso l'orlo e se è larga
			float orlo = 1.0 - smoothstep(fine, petto_y - 0.05, p.y);
			float dentro = sm(fine - 0.025, fine + 0.01, p.y) * (braccio ? sm(mf + 0.02, mf - 0.03, ax) : 1.0);
			float collo = sm(-0.005, -0.05, scollo_y(p, zf));
			float svaso = braccio ? sm(spalla_x, mf, ax) : 0.0;
			float riempi = braccio ? 0.0 : min(valle, LARGA_VALLE) * (1.0 - sm(spalla_x - 0.05, spalla_x - 0.01, ax));
			float onda = sin(TIME * 13.0 + p.y * 38.0 + p.x * 21.0) * 0.5 + sin(TIME * 21.0 - p.y * 55.0) * 0.25;
			NORMAL = normalize(mix(NORMAL, TANGENT, dentro * collo * mix(LISCIA_ADERENTE, LISCIA_LARGA, larga)));
			off = dentro * collo * (larga * (LARGA_BASE + riempi + LARGA_SVASO * orlo * orlo + LARGA_MANICA * svaso)
				+ corsa * 0.006 * onda * (0.25 + orlo) * (1.0 + larga));
		}
		float cf = anca_y - (stile2.w > 0.5 ? 0.5 : 0.36) * (anca_y - caviglia_y);   // orlo dei calzoncini
		if (p.y < fine + 0.02 && p.y > cf - 0.04) {
			float giu = sm(anca_y + 0.03, cf, p.y);
			float dentro = sm(cf - 0.035, cf + 0.005, p.y) * sm(fine + 0.02, fine - 0.02, p.y);
			float fuori = sm(-0.8, -0.25, normale_riposo.x * sign(p.x));
			off += dentro * fuori * (CALZ_BASE + CALZ_SVASO * giu * giu);
			NORMAL = normalize(mix(NORMAL, TANGENT, dentro * CALZ_LISCIA));
		}
		if (int(stile.y + 0.5) == 2) {
			off += POLO_RIALZO * polo_colletto(p, zf, 0.01);   // polo: il colletto si stacca dal collo
		}
		VERTEX += NORMAL * off;
	}
}

float banda(float d, float meta) {
	return clamp(0.5 + (meta - abs(d)) / AA, 0.0, 1.0);
}

// motivo della maglia (pattern di src/athlete3d.js): quanto colore secondario in p
float motivo(int m, vec3 p, float zf, bool braccio) {
	if (m == 1 && !braccio) {
		float u = fract((p.x + 0.0175) / 0.07) * 0.07;
		return banda(u - 0.0175, 0.0175);
	}
	if (m == 2) {
		float u = fract((p.y - petto_y) / 0.085) * 0.085;
		return banda(u - 0.0204, 0.0204);
	}
	if (m == 3 && !braccio) {
		float d = p.x * (zf > 0.0 ? 1.0 : -1.0) + (p.y - petto_y) * 0.9;
		return banda(d + 0.02, 0.04);
	}
	if (m == 4) {
		float d = p.x * (zf < 0.0 ? -1.0 : 1.0);
		return clamp(0.5 - d / AA, 0.0, 1.0);
	}
	return 0.0;
}

// distanza (con segno, > 0 dentro) del punto q dal lato a-b del triangolo abc
float lato(vec2 q, vec2 a, vec2 b, vec2 c) {
	vec2 e = b - a;
	float d = (e.x * (q.y - a.y) - e.y * (q.x - a.x)) / length(e);
	return e.x * (c.y - a.y) - e.y * (c.x - a.x) > 0.0 ? d : -d;
}

float triangolo(vec2 q, vec2 a, vec2 b, vec2 c) {
	return min(min(lato(q, a, b, c), lato(q, b, c, a)), lato(q, c, a, b));
}

// polo: colletto rialzato con la piega in alto, abbottonatura con due bottoni, risvolti sul petto con l'ombra sotto.
// rgb = colore, a = copertura
vec4 polo(vec3 p, float zf) {
	float ax = abs(p.x);
	float yb = scollo_y(p, zf);
	vec3 col = bordino.rgb;
	float a = polo_colletto(p, zf, 0.0);
	if (a > 0.0 && yb > polo_alto(zf) - 0.005) {
		col *= 0.72;
	}
	if (zf > collo_z + 0.015 && yb < 0.004) {
		if (ax < POLO_LISTA && yb > -POLO_LISTA_GIU) {
			a = 1.0;
			col = bordino.rgb * (ax > POLO_LISTA - 0.0025 || yb < 0.0025 - POLO_LISTA_GIU ? 0.7 : 1.0);
			if (length(vec2(p.x, yb + 0.035)) < 0.0045 || length(vec2(p.x, yb + 0.075)) < 0.0045) {
				col = maglia.rgb * 0.6;   // bottoni
			}
		}
		float t = triangolo(vec2(ax, yb), vec2(0.009, 0.004), vec2(0.07, 0.004), vec2(0.03, -0.055));
		if (t > 0.0) {
			a = 1.0;
			col = bordino.rgb * (t < 0.0025 ? 0.7 : 1.0);
		} else if (t > -0.007 && a < 0.5) {
			col = vec3(0.0);                      // ombra del risvolto sulla maglia
			a = 0.35 * (1.0 + t / 0.007);
		}
	}
	return vec4(col, a);
}

// collo: quanto è pelle (1) o maglia (0) (neckSkin di src/body/testa.js): il cilindro che taglia lo scollo sulle
// spalle prendeva anche la gola sotto il mento; lì, e solo lì, lo si allarga
float collo_pelle(int collar, vec3 p, float zf) {
	float k = 1.0 - (1.0 - NECK_RELAX) * sm(NECK_FRONT - 0.01, NECK_FRONT + 0.01, zf - collo_z) * sm(collo_y + 0.005, collo_y + 0.025, p.y) * sm(0.055, 0.035, abs(p.x));
	return sm(0.0, 2.0 * AA, scollo(collar, vec3(p.x * k, p.y, 0.0), collo_z + (zf - collo_z) * k));
}

// busto e maniche (pittura della maglia di src/athlete3d.js)
// pixel = grandezza di un pixel (m): le pieghe della maglia larga spariscono da lontano (niente sfarfallio);
// vl = profondità della valle (varying valle)
vec3 busto(vec3 p, float zf, float pixel, float vl, inout float ruvido) {
	float ax = abs(p.x);
	int maniche = int(stile.x + 0.5);
	int colletto = int(stile.y + 0.5);
	int disegno = int(stile.z + 0.5);
	float larga = clamp(numero.w, 0.0, 1.0);
	float fine = maglia_fine(larga);
	float mf = manica_fine(maniche, larga);
	if (ax > mf) {
		return pelle.rgb;                       // avambracci e mani
	}
	vec3 c = maglia.rgb;
	bool braccio = ax > spalla_x - 0.02;
	c = mix(c, bordino.rgb, motivo(disegno, p, zf, braccio));
	if (larga > 0.5) {
		// larga: stoffa opaca con pieghe morbide, più fitte verso l'orlo; sopra l'orlo si arriccia un poco
		ruvido = 0.9;
		float piega;
		if (braccio) {
			piega = sin(atan(p.y - petto_y - 0.04, zf) * 5.0 + ax * 45.0) * sm(spalla_x, mf, ax);
		} else {
			float giro = atan(p.x, zf + 0.03);
			piega = sin(giro * 8.0 + sin(p.y * 21.0 + giro * 2.0) * 1.2) * (0.35 + 0.65 * (1.0 - sm(fine, petto_y, p.y)));
			piega += 0.5 * sin(p.y * 150.0 + giro * 3.0) * sm(fine + 0.1, fine + 0.03, p.y) * sm(fine, fine + 0.015, p.y);
		}
		piega *= 1.0 - smoothstep(0.004, 0.012, pixel);
		c *= 1.0 - LARGA_PIEGHE * max(piega, 0.0) + 0.04 * max(-piega, 0.0);
	} else {
		// aderente: stoffa tecnica più lucida, le valli tra i muscoli un filo più scure
		ruvido = 0.55;
		if (!braccio) {
			c *= 1.0 - min(vl * ADERENTE_MUSCOLI, 0.2);
		}
	}
	if (p.y < fine + 0.012 + 0.006 * larga) {
		c *= 0.82;   // orlo
	}
	if (braccio && ax > mf - BORDO) {
		c = bordino.rgb;
	}
	if (!braccio) {
		// bordi dello scollo morbidi (larghi un pixel, fwidth): prima erano gradini netti, a scalini sul telefono
		float nl = scollo(colletto, p, zf);
		float px = max(fwidth(nl), 1e-5);
		float soglia_b = colletto == 0 ? -0.015 : -0.012;
		c = mix(c, bordino.rgb, sm(soglia_b - px, soglia_b + px, nl));
		float in_pelle = sm(-px, px, nl);
		c = mix(c, pelle.rgb, in_pelle);
		ruvido = mix(ruvido, 0.62, in_pelle);
		if (colletto == 2) {
			vec4 pc = polo(p, zf);
			c = mix(c, pc.rgb, pc.a);
			ruvido = mix(ruvido, 0.82, pc.a);
		}
		// cognome e numero sulla schiena (letti da dietro: il lato sinistro del giocatore è a sinistra)
		if (mod(numero.z, 2.0) > 0.5 && zf < collo_z - 0.03) {
			vec2 uv = vec2(0.5 - p.x / SCHIENA, (collo_y - 0.02 - p.y) / SCHIENA);
			if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
				vec4 t = texture(schiene, (numero.xy + uv) * CELLA);
				c = mix(c, t.rgb, t.a);
			}
		}
	}
	return c;
}

// attaccatura del taglio s nel giro az (prof di src/hair3d.js)
float prof(int s, float az) {
	float a = min(180.0, abs(az));
	for (int i = 0; i < 4; i++) {
		vec2 k0 = LINEE[s * 5 + i];
		vec2 k1 = LINEE[s * 5 + i + 1];
		if (a <= k1.x) {
			return mix(k0.y, k1.y, sm(k0.x, k1.x, a));
		}
	}
	return LINEE[s * 5 + 4].y;
}

// tinta della cute sotto i capelli (scalpPaint di src/hair3d.js): l = punto nel riferimento dei capelli
float cute(int s, vec3 l, float rumore) {
	int tipo = TIPO_TAGLIO[s];
	if (tipo == 0) {
		return 0.0;
	}
	float el = degrees(atan(l.y, length(l.xz)));
	float az = degrees(atan(l.x, l.z));
	float A = abs(az);
	float a = 0.0;
	float pr = prof(s, az);
	if (tipo == 1) {
		float soft = mix(5.0, 11.0, sm(100.0, 170.0, A));   // sulla nuca la sfumatura è più lunga
		a = sm(pr - soft, pr + 0.5, el);
	} else {
		a = sm(-4.0, 2.0, el - pr) * (0.5 + 0.35 * rumore);
	}
	if (tipo == 6) {
		vec3 L = normalize(l);
		float w = degrees(asin(clamp(L.x, -1.0, 1.0)));
		float ph = degrees(atan(L.y, L.z));
		if (ph < -90.0) {
			ph += 360.0;
		}
		a = max(a, sm(STRIP.x + 3.0, STRIP.x - 3.0, abs(w)) * sm(STRIP.y - 4.0, STRIP.y + 2.0, ph) * sm(STRIP.z + 4.0, STRIP.z - 2.0, ph));
	}
	return a;
}

// maschera del viso: cella k, canale ch, nel punto (u, v) della zona viso del web (0 fuori dalla zona)
vec4 maschera(int k, vec2 uv) {
	vec2 q = uv - FACE_CROP.xy;
	if (q.x < 0.0 || q.y < 0.0 || q.x > FACE_CROP.z || q.y > FACE_CROP.w) {
		return vec4(0.0);
	}
	vec2 cella = vec2(float(k % 4), float(k / 4)) * FACE_CROP.zw;
	return texture(viso_maschere, (cella + q) / MASCHERE);
}

float gauss(float d2, float r) {
	return exp(-d2 / (r * r));
}

// testa: pelle con i toni, ciglia, barba, sopracciglia, labbra, cute dei capelli (repaintHead di src/body/testa.js).
// Colori in sRGB (circa); n = normale di riposo
vec3 viso(vec3 p, vec3 n, float dettaglio, inout float ruvido) {
	vec3 sk = sqrt(pelle.rgb);
	vec3 hc = sqrt(capelli.rgb);
	vec3 col = sk;
	vec3 d = p - cap_c;
	vec3 l = vec3(dot(d, cap_right), dot(d, cap_up), dot(d, cap_fwd));
	float nf = dot(n, cap_fwd);
	float ex = abs(p.x - viso_proiezione.x);
	float ey = p.y - viso_proiezione.y;
	float fronte = clamp(nf * 2.0 + 0.2, 0.0, 1.0);
	float mento = viso_mento;
	// toni: guance, naso e orecchie più caldi; occhiaie un filo più fredde; ombra sotto la mascella
	float caldo = gauss(pow(ex - viso_guance.x, 2.0) + pow(ey - viso_guance.y, 2.0), viso_guance.z) * fronte
		+ gauss(ex * ex * 4.0 + pow(ey - viso_guance.w, 2.0), viso_naso_orecchie.x) * 0.8 * fronte;
	if (abs(p.x) > viso_naso_orecchie.y && abs(ey) < 0.05 && p.z < viso_naso_orecchie.z) {
		caldo += 0.35;
	}
	float lum = dot(sk, vec3(0.299, 0.587, 0.114));
	vec3 caldo_c = vec3(sk.r * 1.03 + 0.0235, sk.g * 0.9, sk.b * 0.88);
	col = mix(col, caldo_c, min(0.6, caldo * (0.22 + 0.22 * lum)));
	float freddo = 0.35 * gauss(pow(ex - viso_naso_orecchie.w, 2.0) * 0.6 + pow(ey + 0.016, 2.0), 0.011) * fronte;
	col = mix(col, sk * vec3(0.86, 0.84, 0.9), freddo);
	// rilievo (2026-11-26, "visi piatti"): ombre morbide nell'orbita, ai lati del naso e sotto lo zigomo, luce sul dorso
	// del naso e in mezzo alla fronte: il viso ha profondità anche con la luce piatta. Sopracciglia dipinte dopo: uguali
	float orbita = gauss(pow(ex - viso_naso_orecchie.w * 0.75, 2.0) + pow(ey - 0.008, 2.0) * 2.5, 0.013);
	float naso_lati = gauss(pow(ex - 0.016, 2.0) * 3.0 + pow(ey + 0.022, 2.0) * 0.5, 0.012);
	float zigomo = gauss(pow(ex - 0.052, 2.0) * 0.5 + pow(ey + 0.062, 2.0), 0.022);
	float ombra = clamp(0.55 * orbita + 0.4 * naso_lati + 0.45 * zigomo, 0.0, 1.0) * fronte;
	col = mix(col, sk * vec3(0.72, 0.64, 0.64), RILIEVO * ombra);
	float luce = gauss(ex * ex * 6.0 + pow(ey + 0.012, 2.0) * 0.25, 0.012) + 0.6 * gauss(ex * ex + pow(ey - 0.042, 2.0) * 1.5, 0.03);
	col = mix(col, min(vec3(1.0), sk * 1.08 + 0.03), RILIEVO_LUCE * min(1.0, luce) * fronte);
	if (p.y < mento + 0.02) {
		float fondo = 0.45 * sm(-0.15, -0.65, n.y) * sm(mento - 0.06, mento - 0.01, p.y) * sm(mento + 0.03, mento, p.y);
		col = mix(col, sk * vec3(0.7, 0.64, 0.66), fondo);
	}
	// linea delle ciglia sopra l'apertura degli occhi (l'occhio destro è lo specchio del sinistro)
	vec3 q = vec3(abs(p.x), p.y, p.z);
	float de = length(q - viso_occhio.xyz) - viso_occhio.w;
	if (de > -0.001 && de < LASH.x * 2.0 && p.y > viso_occhio.y - 0.0015 && p.z > viso_occhio.z - 0.004) {
		col = mix(col, vec3(0.094, 0.063, 0.047), LASH.y * (1.0 - sm(LASH.x * 0.6, LASH.x * 1.6, de)) * sm(viso_occhio.y - 0.0015, viso_occhio.y + 0.002, p.y));
	}
	vec2 uv = vec2(320.0 + (p.x - viso_proiezione.x) * viso_proiezione.z, 222.0 + (viso_proiezione.y - p.y) * viso_proiezione.w);
	// barba: anche sotto la mascella, sfumata. Peli: dove la maschera è piena tutti, verso il bordo sempre più radi
	// (niente bordo netto); la corta e l'ombra hanno meno peli, si vede la pelle. Basette solo davanti all'orecchio.
	int tipo_barba = clamp(int(stile2.y + 0.5), 0, 6);
	if (tipo_barba > 0 && l.z > -0.04) {
		vec2 sotto = tipo_barba == 6 ? BEARD_UNDER_PIENA : BEARD_UNDER;
		float k = sm(-0.55, -0.2, nf) * (p.y < mento ? 1.0 - sm(sotto.x, sotto.y, mento - p.y) : 1.0);
		k *= sm(-0.04, -0.015, l.z);
		k *= mix(1.0, sm(viso_naso_orecchie.z - 0.002, viso_naso_orecchie.z + 0.012, p.z), sm(-0.06, -0.035, ey));
		float a = maschera(tipo_barba - 1, uv).r * k;
		if (a > 0.003) {
			vec2 bp = BARBA_PELO[tipo_barba - 1];
			float g = pelo_hash(p, 0.0);
			float g2 = pelo_hash(p, 0.37);
			float soglia = a * bp.x;
			float peli = sm(g - 0.3, g + 0.3, soglia * 1.25);        // pelo sì / no, con passaggio morbido
			float cop = mix(soglia, peli * (0.75 + 0.25 * g2), dettaglio) * bp.y;
			vec3 bc = barba.a > 0.5 ? sqrt(barba.rgb) : hc;
			col = mix(col, bc * (0.85 + 0.3 * g2 * dettaglio), clamp(cop, 0.0, 1.0));
		}
	}
	// sopracciglia e labbra: solo davanti
	if (nf > -0.15 && l.z > -0.02) {
		float k = sm(-0.15, 0.25, nf);
		vec4 s = maschera(clamp(int(stile2.z + 0.5), 0, 5), uv);
		vec3 bc = hc * (dot(hc, vec3(0.299, 0.587, 0.114)) > 0.6 ? 0.58 : 0.8);
		if (sopracciglia.a > 0.5) {
			bc = sqrt(sopracciglia.rgb);
		}
		col = mix(col, mix(bc, hc * 0.55, s.b), s.g * k);
		vec4 lb = maschera(6, uv);
		col = mix(col, sk * vec3(0.86, 0.6, 0.6), lb.r * k);
		col = mix(col, sk * vec3(0.6, 0.38, 0.38), lb.g * k);
	}
	// cute dei capelli
	int taglio = clamp(int(stile2.x + 0.5), 0, 16);
	if (taglio > 0) {
		float a = cute(taglio, l, mix(0.5, grana(p), dettaglio));
		col = mix(col, hc * 0.85, a);
		ruvido = mix(ruvido, 0.85, a);
	}
	return col;
}

// occhio (paintEyeTile di src/body/occhi.js): bulbo, iride, palpebre della forma con ciglia; in sRGB (circa)
vec3 occhio(vec3 p) {
	vec3 sk = sqrt(pelle.rgb);
	int fi = clamp(int(occhi_forma + 0.5), 0, 5);
	vec4 fa = OCCHI_A[fi];
	vec4 fb = OCCHI_B[fi];
	// l'apertura del modello in Godot è più alta della finestra misurata (la testa non ha le correzioni del web):
	// palpebre sempre dentro la finestra, così come nel web si vedono le palpebre e poco bianco
	fb.xy = min(fb.xy, vec2(PALPEBRA_MAX));
	vec2 fc = OCCHI_C[fi];
	float W = occhio_finestra.z;
	float H = occhio_finestra.w;
	float x = (abs(p.x) - occhio_f.x) * 1000.0 - occhio_finestra.x;
	float y = (p.y - occhio_f.y) * 1000.0 - occhio_finestra.y;
	vec3 lid = sk * vec3(0.74, 0.7, 0.7);
	vec3 c = lid;
	// palpebre alla colonna x
	float xi = -fa.x * W;
	float xo = fa.y * W;
	float t = (x - xi) / (xo - xi);
	if (t <= 0.0 || t >= 1.0) {
		return c;
	}
	float base = (fa.z + (fa.w - fa.z) * t) * H;
	float tu = t < fb.w ? 0.5 * t / fb.w : 0.5 + 0.5 * (t - fb.w) / (1.0 - fb.w);
	float su = base + fb.x * H * pow(4.0 * tu * (1.0 - tu), fb.z);
	float giu = base - fb.y * H * pow(4.0 * t * (1.0 - t), fb.z);
	float dU = su - y;
	float dL = y - giu;
	float aperto = clamp(min(dU, dL) / AA_MM + 0.5, 0.0, 1.0);
	if (aperto > 0.0) {
		float rI = fc.x * H * IRIDE_K;
		// centro dell'iride: a metà dell'apertura nella colonna di mezzo (prima a y = 0: con le palpebre più alte sopra
		// che sotto l'iride finiva in basso e lo sguardo sembrava assonnato)
		float t0 = -xi / (xo - xi);
		float b0 = (fa.z + (fa.w - fa.z) * t0) * H;
		float tu0 = t0 < fb.w ? 0.5 * t0 / fb.w : 0.5 + 0.5 * (t0 - fb.w) / (1.0 - fb.w);
		float su0 = b0 + fb.x * H * pow(4.0 * tu0 * (1.0 - tu0), fb.z);
		float giu0 = b0 - fb.y * H * pow(4.0 * t0 * (1.0 - t0), fb.z);
		y -= (su0 + giu0) * 0.5 + IRIDE_SU * H;
		vec3 e = mix(vec3(0.949, 0.929, 0.902), vec3(0.8, 0.745, 0.714), clamp(pow(x / (W * 1.05), 2.0) + pow(y / (H * 1.6), 2.0), 0.0, 1.0));
		float d = length(vec2(x, y));
		if (d < rI + 0.3) {
			vec3 ir = sqrt(iride2.a > 0.5 && p.x > 0.0 ? iride2.rgb : iride.rgb);
			float k = d / rI;
			float vena = 0.5 + 0.5 * sin(atan(y, x) * 23.0 + k * 3.0);
			vec3 ic = mix(ir, min(vec3(1.0), ir * 1.3 + 0.047), clamp(0.7 - k, 0.0, 1.0) * 0.8);
			ic = mix(ic, ir * 0.55, clamp(clamp((k - 0.72) / 0.28, 0.0, 1.0) * 0.9 + vena * 0.18, 0.0, 1.0));
			ic = k < 0.42 ? vec3(0.043, 0.031, 0.024) : (k < 0.48 ? mix(ic, vec3(0.043, 0.031, 0.024), (0.48 - k) / 0.06) : ic);
			e = mix(e, ic, clamp((rI - d) / 0.3 + 0.5, 0.0, 1.0));
		}
		e = mix(e, vec3(0.275, 0.196, 0.165), 0.3 * clamp(1.0 - dU / (H * 0.35), 0.0, 1.0));   // ombra della palpebra
		vec2 h = vec2(x + rI * 0.3, y - rI * 0.38);   // riflesso in alto, verso il naso
		if (dot(h, h) < pow(rI * 0.2, 2.0)) {
			e = mix(e, vec3(1.0), 0.9);
		}
		c = mix(c, e, aperto);
	}
	// ciglia sul bordo sopra, riga sottile sotto, piega della palpebra
	vec3 scuro = sk * vec3(0.66, 0.6, 0.6);
	if (dU < 0.25 && dU > -0.95) {
		c = mix(c, vec3(0.086, 0.059, 0.043), 0.92 * clamp((dU + 0.95) / 0.3, 0.0, 1.0) * clamp((0.25 - dU) / 0.3, 0.0, 1.0));
	}
	if (dL < 0.15 && dL > -0.5) {
		c = mix(c, scuro, 0.6 * clamp((dL + 0.5) / 0.25, 0.0, 1.0) * clamp((0.15 - dL) / 0.2, 0.0, 1.0));
	}
	if (fc.y > 0.0 && dU < -1.3 && dU > -2.6) {
		c = mix(c, scuro, fc.y * sin(3.14159 * (-dU - 1.3) / 1.3));
	}
	return c;
}

void fragment() {
	vec3 p = riposo;
	float ax = abs(p.x);
	float zf = dot(p.xz, davanti);
	int colletto = int(stile.y + 0.5);
	int calze = int(stile.w + 0.5);
	float gamba = anca_y - caviglia_y;
	float larga = clamp(numero.w, 0.0, 1.0);
	float maglia_bassa = maglia_fine(larga);
	float pixel = length(fwidth(p));
	float pantaloncini_fine = anca_y - (stile2.w > 0.5 ? 0.5 : 0.36) * gamba;
	float calzettoni_alto = anca_y - (calze == 1 ? 0.84 : (calze == 2 ? 0.66 : 0.58)) * gamba;
	float scarpa_alto = caviglia_y + 0.035;

	vec3 c = pelle.rgb;
	float ruvido = 0.62;
	if (UV.x >= OCCHI_UV.x && UV.y >= OCCHI_UV.y) {
		vec3 e = occhio(p);
		c = e * e;
		ruvido = 0.15;
	} else if (classe.x > 0.5) {
		// testa: dettagli fini (grana) solo finché un pixel è più piccolo di un pelo
		float dettaglio = 1.0 - smoothstep(0.0007, 0.0025, length(fwidth(p)));
		vec3 v = viso(p, normalize(normale_riposo), dettaglio, ruvido);
		c = v * v;
	} else if (classe.y > 0.5) {
		// collo: vicino allo scollo si dipinge come il busto, poi pelle fin sotto il mento
		vec3 pc0 = pelle.rgb * mix(1.0, COLLO_OMBRA, sm(collo_y + 0.012, collo_y + 0.04, p.y));
		vec3 b = scollo(colletto, p, zf) < AA ? busto(p, zf, pixel, valle, ruvido) : pc0;
		float a = collo_pelle(colletto, p, zf);
		c = mix(b, pc0, a);
		ruvido = mix(ruvido, 0.62, a);
		if (colletto == 2) {
			vec4 pc = polo(p, zf);   // il colletto rialzato sale sul collo
			c = mix(c, pc.rgb, pc.a);
			ruvido = mix(ruvido, 0.82, pc.a);
		}
	} else if (p.y > maglia_bassa) {
		c = busto(p, zf, pixel, valle, ruvido);
	} else if (p.y > pantaloncini_fine) {
		c = calzoncini.rgb;
		ruvido = 0.82;
		if (p.y < pantaloncini_fine + 0.012) {
			c *= 0.8;
		}
		c *= 1.0 - 0.35 * larga * sm(maglia_bassa - 0.035, maglia_bassa, p.y);   // ombra della maglia larga
	} else if (p.y > calzettoni_alto) {
		c = pelle.rgb;                           // ginocchia
	} else if (p.y > scarpa_alto) {
		c = calzettoni.rgb;
		ruvido = 0.85;
		if (calze == 2) {
			if (p.y > calzettoni_alto - 0.045) {
				c *= 0.82;
			} else if (p.y > calzettoni_alto - 0.055) {
				c = bordino.rgb;
			}
		} else if (p.y < calzettoni_alto - BORDO && p.y > calzettoni_alto - 2.0 * BORDO) {
			c = bordino.rgb;
		}
	} else {
		c = scarpe.rgb;
		ruvido = 0.4;
		if (p.y < 0.022) {
			c = vec3(0.9);
		} else if (abs(fract((zf * 1.6 + p.y * 3.0) * 6.0) - 0.5) < 0.12 && p.y < scarpa_alto - 0.01 && ax > 0.125) {
			c = dot(scarpe.rgb, vec3(0.3, 0.59, 0.11)) > 0.6 ? vec3(0.1) : vec3(0.92);   // righe sul fianco
		}
	}
	if (numero.z > 1.5 && classe.x < 0.5 && p.x > spalla_x && p.y > anca_y) {
		// fascia da capitano: segue il braccio perché è dipinta sulla posa di riposo (a T, braccio lungo x)
		float t = (p.x - spalla_x) / (gomito_x - spalla_x);
		float pt = max(fwidth(t), 1e-4);
		float dentro = sm(FASCIA_T.x - pt, FASCIA_T.x + pt, t) * sm(FASCIA_T.y + pt, FASCIA_T.y - pt, t);
		float e = min(t - FASCIA_T.x, FASCIA_T.y - t) / (FASCIA_T.y - FASCIA_T.x);
		c = mix(c, FASCIA_COLORE * mix(0.45, 1.0, sm(0.0, FASCIA_ORLO, e)), dentro);
		ruvido = mix(ruvido, 0.7, dentro);
	}
	ALBEDO = c;
	ROUGHNESS = ruvido;
	SPECULAR = 0.35;
	float bordo = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), CONTORNO_ESP);
	EMISSION = contorno.rgb * (contorno.a * bordo) * (0.3 + 0.7 * c);   // il colore della stoffa tinge il bordo
}
