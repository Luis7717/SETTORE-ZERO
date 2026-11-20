// Sfondo dei menu (ui-style.js, #ui): sfumatura a ellisse dall'alto, colore della squadra al centro,
// blu notte e quasi nero ai bordi. radial-gradient(120% 60% at 50% -5%, k1 0%, #0a1224 48%, #050912 100%).
// Un po' di rumore fisso toglie le bande di colore sui telefoni a 8 bit.
shader_type canvas_item;

uniform vec4 centro : source_color = vec4(0.09, 0.14, 0.27, 1.0);
uniform vec4 mezzo : source_color = vec4(0.039, 0.071, 0.141, 1.0);
uniform vec4 bordo : source_color = vec4(0.02, 0.035, 0.07, 1.0);
uniform float punto_mezzo = 0.48;

float rumore(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 q = vec2((UV.x - 0.5) / 1.2, (UV.y + 0.05) / 0.6);
	float d = length(q);
	vec3 c = d < punto_mezzo ? mix(centro.rgb, mezzo.rgb, d / punto_mezzo)
		: mix(mezzo.rgb, bordo.rgb, clamp((d - punto_mezzo) / (1.0 - punto_mezzo), 0.0, 1.0));
	c += (rumore(FRAGCOORD.xy) - 0.5) / 255.0;
	COLOR = vec4(c, 1.0);
}
