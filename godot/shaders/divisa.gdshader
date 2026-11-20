// Divisa e pelle del giocatore (modello athlete.glb, Quaternius CC0), colorate per zone del corpo come fa
// src/athlete3d.js nel gioco web, ma calcolate qui per pixel invece che in una texture.
// CUSTOM0.xyz = posizione del vertice nella posa di riposo (a T), scritta da scripts/giocatore.gd: le zone
// (maglia, maniche, pantaloncini, calzettoni, scarpe, testa, capelli) seguono il corpo anche mentre corre.
// I colori cambiano per giocatore con le "instance uniform" (un solo materiale per tutti i 22).
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;   // lambert: più leggero di burley sul telefono

instance uniform vec4 maglia : source_color = vec4(0.78, 0.06, 0.18, 1.0);
instance uniform vec4 calzoncini : source_color = vec4(1.0);
instance uniform vec4 calzettoni : source_color = vec4(0.78, 0.06, 0.18, 1.0);
instance uniform vec4 bordino : source_color = vec4(1.0);
instance uniform vec4 pelle : source_color = vec4(0.94, 0.79, 0.65, 1.0);
instance uniform vec4 capelli : source_color = vec4(0.11, 0.08, 0.06, 1.0);

// misure del corpo in posa di riposo (m), dalle ossa: le imposta scripts/giocatore.gd
uniform float anca_y = 0.97;
uniform float caviglia_y = 0.09;
uniform float collo_y = 1.52;
uniform float spalla_x = 0.17;
uniform float gomito_x = 0.45;
uniform float testa_alto = 1.81;
uniform vec3 testa = vec3(0.0, 1.6, 0.0);
uniform vec2 davanti = vec2(0.0, 1.0);   // verso del viso nella posa di riposo (piano xz)
uniform vec3 scarpe : source_color = vec3(0.08, 0.08, 0.09);
uniform vec3 iride : source_color = vec3(0.25, 0.17, 0.1);

const float COLLO_R = 0.085;      // mezza larghezza del collo (m)
const float BORDO = 0.014;        // bordini (colletto, maniche, calzettoni) (m)
const vec2 OCCHI_UV = vec2(0.875); // tassello degli occhi nell'atlante (come EYE_PX del web: 896/1024)

varying vec3 riposo;

void vertex() {
	riposo = CUSTOM0.xyz;
}

void fragment() {
	vec3 p = riposo;
	float ax = abs(p.x);
	float gamba = anca_y - caviglia_y;
	float maglia_bassa = anca_y + 0.035;
	float pantaloncini_fine = anca_y - 0.36 * gamba;
	float calzettoni_alto = anca_y - 0.58 * gamba;
	float scarpa_alto = caviglia_y + 0.035;
	float manica_fine = spalla_x + 0.55 * (gomito_x - spalla_x);

	vec3 c = pelle.rgb;
	float ruvido = 0.62;
	float collo = max(collo_y - 0.035 - p.y, ax - COLLO_R);   // < 0 dentro il collo
	if (UV.x >= OCCHI_UV.x && UV.y >= OCCHI_UV.y) {
		// occhi: sclera, iride, pupilla (il tassello copre l'occhio intero)
		float d = length((UV - (OCCHI_UV + 0.0625)) / 0.0625);
		c = d < 0.34 ? (d < 0.16 ? vec3(0.02) : iride) : vec3(0.92, 0.9, 0.87);
		ruvido = 0.15;
	} else if (p.y > collo_y + 0.07 || collo < 0.0) {
		// testa e collo; capelli corti in cima e dietro
		float dietro = dot(p.xz - testa.xz, davanti);   // < 0 dietro la testa
		if (p.y > testa_alto - 0.075 || (p.y > testa.y + 0.035 && dietro < -0.045)) {
			c = capelli.rgb;
			ruvido = 0.85;
		}
	} else if (p.y > maglia_bassa) {
		if (ax > manica_fine) {
			c = pelle.rgb;                       // avambracci e mani
		} else {
			c = maglia.rgb;
			ruvido = 0.82;
			if (ax > manica_fine - BORDO || collo < BORDO) c = bordino.rgb;
			if (p.y < maglia_bassa + 0.012) c *= 0.82;   // orlo
		}
	} else if (p.y > pantaloncini_fine) {
		c = calzoncini.rgb;
		ruvido = 0.82;
		if (p.y < pantaloncini_fine + 0.012) c *= 0.8;
	} else if (p.y > calzettoni_alto) {
		c = pelle.rgb;                           // ginocchia
	} else if (p.y > scarpa_alto) {
		c = calzettoni.rgb;
		ruvido = 0.85;
		if (p.y < calzettoni_alto - BORDO && p.y > calzettoni_alto - 2.0 * BORDO) c = bordino.rgb;
	} else {
		c = p.y < 0.022 ? vec3(0.9) : scarpe;
		ruvido = 0.4;
	}
	ALBEDO = c;
	ROUGHNESS = ruvido;
	SPECULAR = 0.35;
}
