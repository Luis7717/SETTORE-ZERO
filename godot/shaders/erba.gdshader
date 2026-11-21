// Erba del campo: disegno del taglio (strisce, quadrotti, cerchi... scelto con `taglio`, scripts/tagli_campo.gd),
// grana e fili d'erba da vicino. Niente texture grande: il disegno è calcolato per pixel con bordi ammorbiditi
// (fwidth), così da lontano non sfarfalla. Le righe bianche NON stanno qui: sono una mesh a parte
// (scripts/righe_campo.gd + shaders/righe.gdshader), perché calcolate per pixel sull'iPhone non si vedevano.
// Misure come src/sim/core.js; colori come src/pitch.js. Coordinate del gioco: x = X di Godot, y = −Z di Godot.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec3 chiara : source_color = vec3(0.298, 0.671, 0.251);      // #4cab40
uniform vec3 scura : source_color = vec3(0.235, 0.573, 0.208);       // #3c9235
uniform vec3 chiara_bordo : source_color = vec3(0.325, 0.702, 0.271); // #53b345
uniform vec3 scura_bordo : source_color = vec3(0.216, 0.541, 0.192);  // #378a31
uniform int taglio = 0;            // ordine di NOMI in scripts/tagli_campo.gd
uniform sampler2D grana : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ciuffi_tex : filter_linear_mipmap_anisotropic, repeat_enable; // grana fitta (ciuffi), da campo.gd
uniform float forza_grana = 0.55;  // era 0,3: Luis "deve sembrare ci sia un pochino di erba"
uniform sampler2D dettaglio_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;   // fili d'erba (normal map)
uniform float forza_dettaglio = 0.55;
const float DETTAGLIO_M = 0.9;     // m coperti da una ripetizione dei fili
const float DETTAGLIO_FINE = 40.0; // m dalla telecamera: oltre, niente fili (non si vedono e sfarfallerebbero)
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

varying vec2 pos_mondo;

void vertex() {
	pos_mondo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

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

void fragment() {
	vec2 p = vec2(pos_mondo.x, -pos_mondo.y);
	vec2 dp = fwidth(p);
	vec2 d = disegno(p, dp);
	// dentro ogni fascia una sfumatura leggera dal bordo (erba piegata), come il web
	float piega = smoothstep(0.0, 0.45, d.y);
	vec3 c = mix(mix(scura_bordo, scura, piega), mix(chiara_bordo, chiara, piega), d.x);
	float g = texture(grana, pos_mondo / 1.6).r * 0.55 + texture(grana, pos_mondo / 4.3 + vec2(0.37, 0.11)).r * 0.45;
	c *= 1.0 + forza_grana * (g - 0.5);
	float dist = length(VERTEX);
	// ciuffi: grana fine che si vede da vicino e a media distanza, sfuma da lontano (niente sfarfallio)
	float ciuffi = texture(ciuffi_tex, pos_mondo / CIUFFI_M).r * 0.6 + texture(ciuffi_tex, pos_mondo / (CIUFFI_M * 3.1) + vec2(0.53, 0.17)).r * 0.4;
	c *= 1.0 + 0.8 * (ciuffi - 0.5) * (1.0 - smoothstep(CIUFFI_FINE * 0.5, CIUFFI_FINE, dist));
	// da vicino una grana ancora più fitta (i singoli ciuffi)
	float fitti = texture(ciuffi_tex, pos_mondo / 0.8 + vec2(0.31, 0.77)).r;
	c *= 1.0 + 0.5 * (fitti - 0.5) * (1.0 - smoothstep(9.0, 20.0, dist));
	// verde un po' meno acceso, come l'erba vera
	c = mix(vec3(dot(c, vec3(0.299, 0.587, 0.114))), c, 0.88) * 0.95;
	// colore che varia un po': qua più giallo, là più azzurro (erba vera non è mai di un verde solo)
	float tono = texture(grana, pos_mondo / 9.0 + vec2(0.19, 0.83)).r - 0.5;
	c *= vec3(1.0 + 0.10 * tono, 1.0 + 0.03 * tono, 1.0 - 0.14 * tono);
	// erba piegata dal taglio: guardando le fasce da un verso o dall'altro il chiaro e lo scuro si scambiano un po'
	vec3 vista = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 0.0)).xyz);
	c *= 1.0 + LUCIDO * (d.x * 2.0 - 1.0) * clamp(-vista.z, -1.0, 1.0);
	// chiazze larghe (erba un po' più gialla o più verde), appena accennate
	float chiazza = texture(grana, pos_mondo / 23.0 + vec2(0.71, 0.29)).r;
	c *= mix(vec3(1.0), vec3(1.05, 1.03, 0.9), smoothstep(0.55, 0.8, chiazza) * 0.6);
	// da vicino: fili d'erba in rilievo, che spariscono piano con la distanza
	float vicino = 1.0 - smoothstep(DETTAGLIO_FINE * 0.35, DETTAGLIO_FINE, dist);
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), texture(dettaglio_n, pos_mondo / DETTAGLIO_M).rgb, vicino);
	NORMAL_MAP_DEPTH = forza_dettaglio;
	ALBEDO = c;
	ROUGHNESS = 0.93;
	SPECULAR = 0.25;
}
