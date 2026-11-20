// Rete della porta (scripts/campo.gd): maglie dalla texture, trasparenza diversa per la porta di fronte e quella
// alle spalle, e il telo che si gonfia attorno al punto dove arriva il pallone (come la rete a molle di src/props.js,
// semplificata: un solo spostamento "gonfia" che la vista fa oscillare, distribuito con una campana attorno a "colpo").
// COLOR.r = quanto il vertice è libero di muoversi (0 sui bordi attaccati a pali, traversa e terreno).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D maglia : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 colore : source_color = vec4(0.95, 0.95, 0.95, 1.0);
uniform float opacita = 0.78;
uniform vec2 colpo = vec2(0.0, 1.0);        // punto d'impatto: x (larghezza) e altezza, coordinate locali
uniform float gonfia = 0.0;                 // spostamento del telo nel punto d'impatto (m), verso fuori
uniform vec3 fuori = vec3(0.0, 0.0, -1.0);  // verso "fuori dal campo" per questa porta
const float LARGO = 1.1;                    // larghezza della campana (m²), come kickNet nel web

void vertex() {
	vec2 d = VERTEX.xy - colpo;
	VERTEX += fuori * gonfia * COLOR.r * exp(-dot(d, d) / LARGO);
}

void fragment() {
	vec4 t = texture(maglia, UV);
	ALBEDO = colore.rgb * t.rgb;
	ALPHA = t.a * colore.a * opacita;
}
