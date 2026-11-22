// Rete della porta (scripts/campo.gd): maglie dalla texture, trasparenza diversa per la porta di fronte e quella alle
// spalle. Il telo si muove con la rete a molle (scripts/rete_molle.gd): ogni vertice legge il suo spostamento verso
// fuori dalla texture "spostamenti" (un float per nodo, UV2 = posto del vertice) e si sposta lungo la sua normale.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D maglia : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D spostamenti : hint_default_black, filter_linear, repeat_disable;
uniform vec4 colore : source_color = vec4(0.95, 0.95, 0.95, 1.0);
uniform float opacita = 0.78;

void vertex() {
	VERTEX += NORMAL * textureLod(spostamenti, UV2, 0.0).r;
}

void fragment() {
	vec4 t = texture(maglia, UV);
	ALBEDO = colore.rgb * t.rgb;
	ALPHA = t.a * colore.a * opacita;
}
