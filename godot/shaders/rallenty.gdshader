// Bordo scuro del rallenty (come #slow del web: box-shadow inset 0 0 45px 12px #0b1a3a8c, ridotto il 2026-11-21 su richiesta di Luis): più scuro ai bordi,
// trasparente al centro. dim = misura del rettangolo in punti, forza = 0..1 (si accende e si spegne piano).
shader_type canvas_item;

uniform vec4 colore : source_color = vec4(0.043, 0.102, 0.227, 0.55);
uniform vec2 dim = vec2(390.0, 844.0);
uniform float spessore = 12.0;
uniform float sfumatura = 45.0;
uniform float forza = 0.0;

void fragment() {
	vec2 p = UV * dim;
	float d = min(min(p.x, dim.x - p.x), min(p.y, dim.y - p.y));
	float a = 1.0 - smoothstep(spessore * 0.3, spessore + sfumatura, d);
	COLOR = vec4(colore.rgb, colore.a * a * forza);
}
