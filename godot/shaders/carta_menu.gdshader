// Fondo sfumato delle carte coi colori della squadra (linear-gradient(<angolo>, a 0%, b <fine>) del web)
// dentro un rettangolo con gli angoli tondi (bordi morbidi di 1 px). Serve dove la sfumatura si vede davvero
// (prossima partita, tabellone del risultato, anteprima dell'editor, disegni di "Come si gioca").
shader_type canvas_item;

uniform vec4 colore_a : source_color = vec4(0.08, 0.13, 0.23, 1.0);
uniform vec4 colore_b : source_color = vec4(0.06, 0.1, 0.18, 1.0);
uniform float angolo = 180.0;      // gradi come nel CSS: 180 = dall'alto in basso
uniform float fine = 1.0;          // dove arriva colore_b (0..1)
uniform float raggio = 18.0;       // px
uniform vec2 misura = vec2(100.0, 100.0);
uniform vec4 bordo : source_color = vec4(1.0, 1.0, 1.0, 0.08);
uniform float spessore = 1.0;

float rett_tondo(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * misura - misura * 0.5;
	float a = radians(angolo);
	vec2 dir = vec2(sin(a), -cos(a));
	float lung = abs(misura.x * sin(a)) + abs(misura.y * cos(a));
	float t = clamp((dot(p, dir) / lung + 0.5) / max(fine, 0.001), 0.0, 1.0);
	vec4 c = mix(colore_a, colore_b, t);
	float d = rett_tondo(p, misura * 0.5, raggio);
	float dentro = clamp(0.5 - d, 0.0, 1.0);
	float riga = clamp(0.5 - abs(d + spessore * 0.5) + spessore * 0.5, 0.0, 1.0) * step(0.01, spessore);
	c.rgb = mix(c.rgb, bordo.rgb, riga * bordo.a);
	COLOR = vec4(c.rgb, c.a * dentro);
}
