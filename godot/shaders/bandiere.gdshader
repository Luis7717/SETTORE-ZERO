// Bandiere dei tifosi (scripts/stadio/bandiere.gd): tutte in un MultiMesh, una chiamata di disegno. Niente fisica:
// l'asta oscilla intorno alle mani del tifoso e il telo ondeggia, tutto calcolato qui nel vertex shader.
// Mesh (spazio locale): asta lungo +Y con UV.x < 0; telo che parte dall'asta verso +X, UV in 0..1 (u = distanza
// dall'asta, v = 0 in alto). Istanza: COLOR.rgb = primo colore della squadra, COLOR.a = tifoseria (0 casa, 1 ospiti);
// INSTANCE_CUSTOM.rgb = secondo colore, .a = numero casuale (fase, disegno del telo).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 stato_casa = vec4(0.15, 0.0, 0.0, 0.0);    // come shaders/pubblico.gdshader: x in piedi, y braccia su
uniform vec4 stato_ospiti = vec4(0.15, 0.0, 0.0, 0.0);
uniform float luce = 0.92;                               // luce generale (la cambia il meteo, come al pubblico)
uniform float tempo = 0.0;
uniform float telo_lungo = 1.7;                          // lunghezza del telo (m), da bandiere.gd

const vec3 ASTA = vec3(0.32, 0.3, 0.28);

varying vec3 primo;
varying vec3 secondo;
varying float piega;
varying float disegno;

vec3 lin(vec3 c) { return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878); }   // sRGB → lineare

void vertex() {
	float n = INSTANCE_CUSTOM.a;
	vec4 st = COLOR.a > 0.5 ? stato_ospiti : stato_casa;
	float foga = 0.4 + 0.6 * clamp(max(st.x, st.y), 0.0, 1.0);   // più su il pubblico, più si sventola
	float w = 2.0 + 1.4 * n + foga * 1.2;
	float ang = sin(tempo * w + n * 40.0) * (0.22 + 0.5 * foga);   // asta che va da una parte all'altra
	vec3 v = VERTEX;
	float telo = step(0.0, UV.x);
	float k = clamp(v.x / telo_lungo, 0.0, 1.0) * telo;           // 0 all'asta, 1 in fondo al telo
	float fase = v.x * 3.2 - tempo * (6.5 + 3.0 * n) + n * 21.0;
	v.z += sin(fase) * 0.22 * k;                                   // onde lungo il telo
	v.y -= k * k * 0.25 * (1.0 - foga);                            // poca foga: il telo pende un po'
	v.x -= abs(sin(fase)) * 0.08 * k;                              // le onde accorciano il telo
	float c = cos(ang);
	float s = sin(ang);
	VERTEX = vec3(v.x * c - v.y * s, v.x * s + v.y * c, v.z);
	piega = mix(1.0, 0.72 + 0.28 * cos(fase), k);
	disegno = floor(fract(n * 13.7) * 3.0);
	primo = telo > 0.5 ? lin(COLOR.rgb) : lin(ASTA);
	secondo = telo > 0.5 ? lin(INSTANCE_CUSTOM.rgb) : lin(ASTA);
}

void fragment() {
	// disegno del telo: 0 striscia orizzontale in mezzo, 1 metà e metà, 2 diagonale
	float d = disegno;
	float sec = d < 0.5 ? step(0.34, UV.y) * step(UV.y, 0.66) : (d < 1.5 ? step(0.5, UV.x) : step(UV.y, UV.x));
	ALBEDO = mix(primo, secondo, sec) * piega * luce;
}
