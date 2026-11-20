// Erba del campo con strisce di taglio e righe calcolate per pixel (niente texture grande): le righe restano
// nitide e senza scalini a ogni distanza, e sul telefono si risparmiano ~10 MB di texture.
// Misure come src/sim/core.js (e scripts/coord.gd); colori come src/pitch.js. Coordinate del gioco: x = X di
// Godot, y = −Z di Godot. Una grana ripetuta a due scale dà corpo all'erba da vicino.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec3 chiara : source_color = vec3(0.298, 0.671, 0.251);      // #4cab40
uniform vec3 scura : source_color = vec3(0.235, 0.573, 0.208);       // #3c9235
uniform vec3 chiara_bordo : source_color = vec3(0.325, 0.702, 0.271); // #53b345
uniform vec3 scura_bordo : source_color = vec3(0.216, 0.541, 0.192);  // #378a31
uniform vec3 riga : source_color = vec3(0.98, 0.988, 0.965);
uniform sampler2D grana : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float forza_grana = 0.3;
uniform sampler2D dettaglio_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;   // fili d'erba (normal map)
uniform float forza_dettaglio = 0.55;
const float DETTAGLIO_M = 0.9;     // m coperti da una ripetizione dei fili
const float DETTAGLIO_FINE = 26.0; // m dalla telecamera: oltre, niente fili (non si vedono e sfarfallerebbero)

const float HW = 32.0;
const float HL = 50.0;
const float STRISCE = 18.0;
const float RIGA_W = 0.16;
const float BOX_HW = 20.16;   // metà larghezza dell'area di rigore
const float BOX_D = 16.5;
const float SIX_HW = 9.16;
const float SIX_D = 5.5;
const float PEN_D = 11.0;
const float CERCHIO = 9.15;

varying vec2 pos_mondo;

void vertex() {
	pos_mondo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

// distanza dal bordo di un rettangolo (centro c, mezze misure h)
float bordo_rett(vec2 p, vec2 c, vec2 h) {
	vec2 d = abs(p - c) - h;
	return abs(length(max(d, 0.0)) + min(max(d.x, d.y), 0.0));
}

// distanza dalla riga più vicina (m)
float distanza_righe(vec2 p) {
	vec2 q = vec2(p.x, abs(p.y));                 // le due metà del campo sono uguali
	float d = bordo_rett(p, vec2(0.0), vec2(HW, HL));
	d = min(d, abs(p.y) + max(abs(p.x) - HW, 0.0));                       // metà campo
	d = min(d, abs(length(p) - CERCHIO));                                // cerchio
	d = min(d, max(length(p) - 0.22, 0.0));                               // punto del centro
	d = min(d, bordo_rett(q, vec2(0.0, HL - BOX_D * 0.5), vec2(BOX_HW, BOX_D * 0.5)));
	d = min(d, bordo_rett(q, vec2(0.0, HL - SIX_D * 0.5), vec2(SIX_HW, SIX_D * 0.5)));
	vec2 dischetto = vec2(0.0, HL - PEN_D);
	d = min(d, max(length(q - dischetto) - 0.2, 0.0));
	if (q.y < HL - BOX_D) d = min(d, abs(length(q - dischetto) - CERCHIO));  // lunetta
	vec2 a = abs(p);
	if (a.x <= HW && a.y <= HL) d = min(d, abs(length(a - vec2(HW, HL)) - 1.0)); // archi d'angolo
	return d;
}

void fragment() {
	vec2 p = vec2(pos_mondo.x, -pos_mondo.y);
	// strisce: bordo netto, dentro una sfumatura leggera (erba piegata), come il web
	float s = (HL - p.y) / (2.0 * HL / STRISCE);
	float i = floor(s);
	float t = fract(s);
	bool chiara_qui = mod(i, 2.0) > 0.5;
	vec3 c = chiara_qui ? mix(chiara_bordo, chiara, smoothstep(0.0, 0.45, t)) : mix(scura_bordo, scura, smoothstep(0.0, 0.45, t));
	float g = texture(grana, pos_mondo / 1.6).r * 0.55 + texture(grana, pos_mondo / 4.3 + vec2(0.37, 0.11)).r * 0.45;
	c *= 1.0 + forza_grana * (g - 0.5);
	// chiazze larghe (erba un po' più gialla o più verde), appena accennate
	float chiazza = texture(grana, pos_mondo / 23.0 + vec2(0.71, 0.29)).r;
	c *= mix(vec3(1.0), vec3(1.05, 1.03, 0.9), smoothstep(0.55, 0.8, chiazza) * 0.6);
	// da vicino: fili d'erba in rilievo, che spariscono piano con la distanza
	float vicino = 1.0 - smoothstep(DETTAGLIO_FINE * 0.4, DETTAGLIO_FINE, length(VERTEX));
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), texture(dettaglio_n, pos_mondo / DETTAGLIO_M).rgb, vicino);
	NORMAL_MAP_DEPTH = forza_dettaglio;
	// righe con bordo morbido largo un pixel; lontano, quando la riga è più sottile di un pixel, si schiarisce
	// invece di sfarfallare
	float d = distanza_righe(p);
	float px = max(fwidth(d), 1e-4);
	float mezza = RIGA_W * 0.5;
	float mezza_vis = max(mezza, px * 0.5);
	float copre = clamp((mezza_vis - d) / px + 0.5, 0.0, 1.0) * (mezza / mezza_vis);
	c = mix(c, riga, copre);
	ALBEDO = c;
	ROUGHNESS = 0.93;
	SPECULAR = 0.25;
}
