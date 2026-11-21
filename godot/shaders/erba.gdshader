// Erba del campo: disegno del taglio (strisce, quadrotti, cerchi... scelto con `taglio`, scripts/tagli_campo.gd),
// grana e fili d'erba da vicino. Niente texture grande: il disegno è calcolato per pixel con bordi ammorbiditi
// (fwidth), così da lontano non sfarfalla. Le righe bianche NON stanno qui: sono una mesh a parte
// (scripts/righe_campo.gd + shaders/righe.gdshader), perché calcolate per pixel sull'iPhone non si vedevano.
// Colore, taglio, grana e fili stanno in shaders/erba_comune.gdshaderinc (condivisi coi ciuffi in rilievo).
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, fog_disabled; // niente nebbia: la nebbia azzurra spegneva il giallo-verde (foto di Luis)

#include "res://shaders/erba_comune.gdshaderinc"

varying vec2 pos_mondo;

void vertex() {
	pos_mondo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 dx = dFdx(pos_mondo);
	vec2 dy = dFdy(pos_mondo);
	vec2 dp = abs(dx) + abs(dy);   // = fwidth (x uguale, y col segno girato non conta)
	vec3 vista = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 0.0)).xyz);
	Erba e = erba_colore(pos_mondo, dp, dx, dy, length(VERTEX), vista);
	ALBEDO = e.albedo;
	NORMAL_MAP = e.normal_map;
	NORMAL_MAP_DEPTH = forza_dettaglio;
	ROUGHNESS = e.roughness;
	SPECULAR = e.specular;
}
