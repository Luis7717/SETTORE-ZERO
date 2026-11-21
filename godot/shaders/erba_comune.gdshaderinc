// Parte comune dell'erba (shaders/erba.gdshader = il prato, shaders/erba_ciuffi.gdshader = i ciuffi in rilievo vicino
// alla telecamera): uniform, disegno del taglio, colore, grana e fili. Chi la include dichiara solo vertex e fragment.
// Misure come src/sim/core.js; colori come src/pitch.js. Coordinate del gioco: x = X di Godot, y = −Z di Godot.

uniform vec3 chiara : source_color = vec3(0.200, 0.508, 0.000);      // giallo-verde vivo (foto di riferimento di Luis)
uniform vec3 scura : source_color = vec3(0.169, 0.450, 0.000);
uniform vec3 chiara_bordo : source_color = vec3(0.208, 0.527, 0.000);
uniform vec3 scura_bordo : source_color = vec3(0.162, 0.431, 0.000);
uniform int taglio = 0;            // ordine di NOMI in scripts/tagli_campo.gd
uniform sampler2D grana : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ciuffi_tex : filter_linear_mipmap_anisotropic, repeat_enable; // grana fitta (ciuffi), da campo.gd
uniform float forza_grana = 0.55;  // era 0,3: Luis "deve sembrare ci sia un pochino di erba"
// fili d'erba visti dall'alto (tools/genera_texture.gd): rg = normale, b = altezza (0 buco scuro, 1 punta; media 0,5)
uniform sampler2D fili : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float forza_fili = 0.42;   // micro-ombre: buchi tra i fili più scuri, punte più chiare (media invariata)
uniform float forza_dettaglio = 0.7; // rilievo dei fili alla luce del sole
uniform float piega_fili = 0.06;   // fili piegati dal taglio: nelle fasce alterne pendono in versi opposti
uniform float bagnato = 0.0;       // pioggia (scripts/partita/meteo.gd): erba più scura e lucida; 0 = asciutta
uniform float neve = 0.0;          // neve: chiazze bianche (0 = niente, 1 = quasi tutto bianco)
const vec3 BIANCO_NEVE = vec3(0.80, 0.83, 0.88);
const float BAGNATO_SCURO = 0.34;  // quanto si scurisce l'erba bagnata
const float NEVE_VELO = 0.25;      // neve: parte bianca anche fuori dalle chiazze
const float BAGNATO_PIATTO = 0.85; // bagnata: quanto rilievo dei fili si toglie (riflessi lisci, niente brillantini)
const float FILI_M = 0.55;        // m coperti da una ripetizione dei fili (scala fine)
const float FILI_M2 = 1.45;       // seconda scala, girata: nasconde la ripetizione
const float FILI_M3 = 4.1;        // terza scala: da qualche metro in là i "fili" diventano ciuffi (grana a media distanza)
const float FILI_VICINO = 3.0;    // m: fin qui solo i fili fini
const float FILI_LONTANO = 14.0;  // m: da qui solo i ciuffi (i fili fini non si leggono più)
const float DETTAGLIO_FINE = 45.0; // m dalla telecamera: oltre, niente rilievo (non si vede e sfarfallerebbe)
const float FILI_FINE = 60.0;     // m dalla telecamera: oltre, niente micro-ombre (la mipmap le spegne già da sola)
const float CIUFFI_M = 3.5;        // m di una ripetizione della grana fine (ciuffi d'erba)
const float CIUFFI_FINE = 34.0;    // m dalla telecamera: oltre, niente grana fine
const float LUCIDO = 0.07;         // erba piegata: le fasce cambiano di chiaro/scuro con la direzione da cui le guardi

const float HW = 32.0;
const float HL = 50.0;
const float CERCHIO = 9.15;
const float STRISCIA = 100.0 / 18.0;      // strisce larghe: 18 sulla lunghezza (come il web)
const float STRISCIA_STRETTA = 100.0 / 30.0;
const float STRISCIA_LUNGO = 64.0 / 12.0; // strisce lungo il campo: 12 sulla larghezza
const float QUADROTTO_Y = 100.0 / 14.0;
const float QUADROTTO_X = 64.0 / 9.0;
const float ANELLO = 4.6;                 // larghezza di un anello dei cerchi concentrici (m)
const float ROMBO = 7.0;                  // larghezza di una fascia diagonale (m)
const float SPICCHI = 16.0;               // spicchi nel cerchio di centrocampo (numero pari: si chiudono giusti)
const float UNIFORME = 0.55;              // erba semplice: un po' più verso il chiaro
const float PI2 = 6.2831853;

struct Erba {
	vec3 albedo;
	vec3 normal_map;
	float roughness;
	float specular;
	float filo;     // altezza dei fili alla scala fine (0 buco, 1 punta): i ciuffi in rilievo tengono solo i fili alti
	vec2 asse;      // asse del taglio (X, Z di Godot)
	float verso;    // +1 fascia chiara, −1 scura (verso in cui pendono i fili)
};

// fasce alterne lungo s (una fascia = 1): 1 = chiara, 0 = scura, bordo ammorbidito su `fw` (fasce per pixel)
float onda(float s, float fw) {
	float al_bordo = abs(fract(s + 0.5) - 0.5);           // distanza dal bordo più vicino (in fasce)
	float verso = fract(s * 0.5) < 0.5 ? 1.0 : -1.0;
	return 0.5 + 0.5 * verso * clamp(al_bordo / max(fw, 1e-3), 0.0, 1.0);
}

// "o l'uno o l'altro" morbido: scacchiera da due onde
float incrocia(float a, float b) {
	return a + b - 2.0 * a * b;
}

// asse del taglio (direzione Godot X, Z in cui il tosaerba è passato): i fili pendono avanti o indietro lungo questo
vec2 asse_taglio() {
	if (taglio == 2) {
		return vec2(1.0, 0.0);
	} else if (taglio == 6 || taglio == 8) {
		return vec2(0.70710678, -0.70710678);
	}
	return vec2(0.0, 1.0);
}

// disegno del taglio nel punto p (m, gioco); dp = m per pixel. x = quanto chiaro (0..1), y = posto dentro la
// fascia (0 al bordo, per l'erba piegata delle strisce; 1 = niente sfumatura)
vec2 disegno(vec2 p, vec2 dp) {
	if (taglio == 1) {
		float s = (HL - p.y) / STRISCIA_STRETTA;
		return vec2(onda(s, dp.y / STRISCIA_STRETTA), fract(s));
	} else if (taglio == 2) {
		float s = (p.x + HW) / STRISCIA_LUNGO;
		return vec2(onda(s, dp.x / STRISCIA_LUNGO), fract(s));
	} else if (taglio == 3) {
		float a = onda((HL - p.y) / QUADROTTO_Y, dp.y / QUADROTTO_Y);
		float b = onda((p.x + HW) / QUADROTTO_X, dp.x / QUADROTTO_X);
		return vec2(incrocia(a, b), 1.0);
	} else if (taglio == 4) {
		float r = length(p);
		return vec2(onda(r / ANELLO + 0.5, length(dp) / ANELLO), 1.0);
	} else if (taglio == 5) {
		return vec2(UNIFORME, 1.0);
	} else if (taglio == 6) {
		float k = 0.70710678 / ROMBO;
		float fw = (dp.x + dp.y) * k;
		float a = onda((p.x + p.y) * k, fw);
		float b = onda((p.x - p.y) * k + 0.5, fw);
		return vec2(incrocia(a, b), 1.0);
	}
	if (taglio == 8) {
		float k = 0.70710678 / (STRISCIA * 1.6);
		float s = (p.x + p.y) * k;
		return vec2(onda(s, (dp.x + dp.y) * k), fract(s));
	}
	// 0 strisce larghe (e il fuori del cerchio a spicchi)
	float s = (HL - p.y) / STRISCIA;
	vec2 v = vec2(onda(s, dp.y / STRISCIA), fract(s));
	if (taglio == 7) {
		float r = length(p);
		float a = atan(p.y, p.x) / PI2 * SPICCHI;
		float fw = (dp.x + dp.y) / max(r, 0.5) / PI2 * SPICCHI;
		vec2 dentro = vec2(onda(a, fw), 1.0);
		float k = clamp((CERCHIO - r) / max(length(dp), 1e-3) + 0.5, 0.0, 1.0);
		v = mix(v, dentro, k);
	}
	return v;
}

// colore e rilievo dell'erba nel punto pos_mondo (X, Z di Godot); dp = fwidth del punto del gioco, dx, dy = derivate
// di pos_mondo sullo schermo (per le texture lette solo a certe distanze: fuori dai rami la mipmap resta giusta),
// dist = m dalla telecamera, vista = direzione telecamera → punto (mondo). Usata dall'erba e dai ciuffi in rilievo.
// Le texture che da una certa distanza non servono più non si leggono proprio (rami su dist, uguali per pixel vicini):
// sull'iPhone ogni lettura conta.
Erba erba_colore(vec2 pos_mondo, vec2 dp, vec2 dx, vec2 dy, float dist, vec3 vista) {
	Erba e;
	vec2 p = vec2(pos_mondo.x, -pos_mondo.y);
	vec2 d = disegno(p, dp);
	// dentro ogni fascia una sfumatura leggera dal bordo (erba piegata), come il web
	float piega = smoothstep(0.0, 0.45, d.y);
	vec3 c = mix(mix(scura_bordo, scura, piega), mix(chiara_bordo, chiara, piega), d.x);
	float g = texture(grana, pos_mondo / 1.6).r * 0.55 + texture(grana, pos_mondo / 4.3 + vec2(0.37, 0.11)).r * 0.45;
	c *= 1.0 + forza_grana * (g - 0.5);
	// ciuffi: grana fine che si vede da vicino e a media distanza, sfuma da lontano (niente sfarfallio)
	if (dist < CIUFFI_FINE) {
		float ciuffi = textureGrad(ciuffi_tex, pos_mondo / CIUFFI_M, dx / CIUFFI_M, dy / CIUFFI_M).r * 0.6
			+ textureGrad(ciuffi_tex, pos_mondo / (CIUFFI_M * 3.1) + vec2(0.53, 0.17), dx / (CIUFFI_M * 3.1), dy / (CIUFFI_M * 3.1)).r * 0.4;
		c *= 1.0 + 0.8 * (ciuffi - 0.5) * (1.0 - smoothstep(CIUFFI_FINE * 0.5, CIUFFI_FINE, dist));
	}
	// colore che varia un po': qua più giallo, là più azzurro (erba vera non è mai di un verde solo)
	float tono = texture(grana, pos_mondo / 9.0 + vec2(0.19, 0.83)).r - 0.5;
	c *= vec3(1.0 + 0.10 * tono, 1.0 + 0.03 * tono, 1.0 - 0.14 * tono);
	// erba piegata dal taglio: guardando le fasce da un verso o dall'altro il chiaro e lo scuro si scambiano un po'
	vec2 asse = asse_taglio();
	float verso = d.x * 2.0 - 1.0;   // +1 fascia chiara, −1 scura
	c *= 1.0 + LUCIDO * verso * clamp(-dot(vista.xz, asse), -1.0, 1.0);
	// chiazze larghe (erba un po' più gialla o più verde), appena accennate
	float chiazza = texture(grana, pos_mondo / 23.0 + vec2(0.71, 0.29)).r;
	c *= mix(vec3(1.0), vec3(1.05, 1.03, 0.9), smoothstep(0.55, 0.8, chiazza) * 0.6);
	// fili d'erba: due scale (la seconda girata, contro la ripetizione). Micro-ombre: tra i fili si vede la terra
	// scura, le punte prendono il sole. Il fattore ha media 1 (altezza media 0,5): il colore medio non cambia.
	// Dall'alto si vede di più tra i fili, di sbieco si vedono solo i fili (meno contrasto).
	mat2 giro2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) / FILI_M2;
	mat2 giro3 = mat2(vec2(0.6, -0.8), vec2(0.8, 0.6)) / FILI_M3;
	vec3 f2 = texture(fili, giro2 * pos_mondo + vec2(0.29, 0.61)).rgb;
	// da vicino i fili veri (scala fine), più in là i ciuffi (scala grossa)
	float lontano = smoothstep(FILI_VICINO, FILI_LONTANO, dist);
	vec3 f1 = vec3(0.5, 0.5, 0.5);
	if (lontano < 1.0) {
		f1 = textureGrad(fili, pos_mondo / FILI_M, dx / FILI_M, dy / FILI_M).rgb;
	}
	float f3 = 0.5;
	if (lontano > 0.0) {
		f3 = textureGrad(fili, giro3 * pos_mondo + vec2(0.71, 0.13), giro3 * dx, giro3 * dy).b;
	}
	float alto = mix(f1.b * 0.6 + f2.b * 0.4, f2.b * 0.4 + f3 * 0.6, lontano);
	float dall_alto = mix(0.5, 1.0, abs(vista.y));
	float vicino_fili = 1.0 - smoothstep(FILI_FINE * 0.4, FILI_FINE, dist);
	c *= 1.0 + forza_fili * 2.0 * (alto - 0.5) * dall_alto * vicino_fili;
	// rilievo dei fili alla luce del sole, che sparisce piano con la distanza; in più i fili pendono nel verso del
	// taglio (fasce alterne in versi opposti): col sole di lato una fascia prende un po' più luce dell'altra
	float vicino = 1.0 - smoothstep(DETTAGLIO_FINE * 0.35, DETTAGLIO_FINE, dist);
	vec2 n = mix(f2.rg, mix(f1.rg, f2.rg, 0.4), 1.0 - lontano) * 2.0 - 1.0;
	n = n * vicino + asse * (piega_fili * verso);
	// bagnata l'erba è lucida: il rilievo fine farebbe brillare punti sparsi (sfarfallio), l'acqua lo spiana
	n *= 1.0 - BAGNATO_PIATTO * bagnato;
	e.normal_map = vec3(n * 0.5 + 0.5, 1.0);
	e.filo = f1.b;
	e.asse = asse;
	e.verso = verso;
	// neve: un velo bianco leggero più chiazze larghe e morbide (le righe bianche, mesh a parte, restano sopra)
	if (neve > 0.0) {
		float fitti = texture(ciuffi_tex, pos_mondo / 0.8 + vec2(0.31, 0.77)).r;
		float chiazze = texture(grana, pos_mondo / 23.0 + vec2(0.13, 0.61)).r * 0.7 + texture(grana, pos_mondo / 6.0 + vec2(0.47, 0.29)).r * 0.3;
		float k = NEVE_VELO + (1.0 - NEVE_VELO) * smoothstep(0.42, 0.78, chiazze);
		c = mix(c, BIANCO_NEVE * (0.95 + 0.1 * fitti), k * neve);
	}
	// bagnato: più scuro, con pozze ancora più scure e lucide (all'asciutto la texture non si legge)
	float pozza = 0.0;
	if (bagnato > 0.0) {
		pozza = smoothstep(0.55, 0.85, texture(grana, pos_mondo / 31.0 + vec2(0.83, 0.07)).r) * bagnato;
	}
	c *= (1.0 - BAGNATO_SCURO * bagnato) * (1.0 - 0.08 * pozza);
	e.albedo = c;
	e.roughness = mix(1.0, 0.32, bagnato) - 0.2 * pozza;
	e.specular = mix(0.06, 0.45, bagnato);  // all'asciutto 0,06: il riflesso del cielo azzurro spegneva il giallo-verde
	return e;
}
