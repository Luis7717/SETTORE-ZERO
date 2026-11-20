// Pubblico 3D (scripts/stadio/pubblico.gd): ogni tifoso è un'istanza di un MultiMesh, un cartoncino rivolto verso la
// telecamera (la persona resta dritta), con un disegno preso da un piccolo atlante fatto a codice (4 tipi × 2 pose:
// braccia giù / braccia su). Animazione tutta qui, per tifoso, con un numero casuale fisso (come CROWD_FRAG del web):
// seduto o in piedi, braccia alzate, salti, dondolio. Lo stato delle due tifoserie arriva da stato_casa / stato_ospiti.
//
// Atlante (dati, non colori): R = luce del disegno, G = 1 maglia / 0,5 sciarpa o cappello (secondo colore della
// squadra), B = pelle, A = sagoma. Il resto (G = B = 0) prende il colore dei capelli, scelto dal numero casuale.
// Istanza: COLOR = maglia; INSTANCE_CUSTOM = (tifoseria 0 casa · 0,1 curva · 0,5 neutri · 1 ospiti, numero casuale,
// tono della pelle, luce del posto: più bassa sotto il tetto).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D atlante : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform vec4 stato_casa = vec4(0.15, 0.0, 0.0, 0.0);    // x in piedi, y braccia su, z salti, w applauso (0..1)
uniform vec4 stato_ospiti = vec4(0.15, 0.0, 0.0, 0.0);
uniform vec3 casa2 : source_color = vec3(1.0);          // secondo colore (sciarpe, cappelli)
uniform vec3 ospiti2 : source_color = vec3(1.0);
uniform float luce = 0.92;                               // luce generale (il pubblico non riceve luci vere)
uniform float tempo = 0.0;                               // tempo della scena (s), lo fa avanzare lo script

const float SEDUTO = 0.34;   // di quanto si abbassa un tifoso seduto (m)

varying vec2 uv_atlante;
varying vec4 dati;

float h1(float x) { return fract(sin(x * 91.345) * 47453.5453); }
vec3 lin(vec3 c) { return c * (c * (c * 0.305306011 + 0.682171111) + 0.012522878); }   // sRGB → lineare

void vertex() {
	float squadra = INSTANCE_CUSTOM.x;
	float n = INSTANCE_CUSTOM.y;
	vec4 st = squadra < 0.25 ? stato_casa : (squadra > 0.75 ? stato_ospiti : (stato_casa + stato_ospiti) * 0.42);
	float curva = step(0.05, squadra) * step(squadra, 0.15);
	st = max(st, vec4(0.55, 0.06, 0.32, 0.0) * curva);                 // la curva canta in piedi
	float alzato = smoothstep(n * 0.6, n * 0.6 + 0.25, st.x);
	float n2 = h1(n + 1.7);
	float braccia = step(n2, st.y * 1.04 - 0.02);
	float applauso = step(n2, st.w);
	float salto = st.z * max(0.0, sin(tempo * (7.0 + 5.0 * n) + n * 60.0)) * 0.24 * step(0.18, h1(n + 3.1));
	float dondola = sin(tempo * (1.2 + n) + n * 40.0) * 0.012 + applauso * abs(sin(tempo * 9.0 + n * 20.0)) * 0.02;
	float alza = -SEDUTO * (1.0 - alzato) + salto + dondola;
	// cartoncino girato verso la telecamera: destra orizzontale, su verso la telecamera (niente persone schiacciate
	// guardate dall'alto)
	vec3 o = MODEL_MATRIX[3].xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 verso = normalize(cam - o);
	vec3 oriz = normalize(vec3(verso.x, 0.0, verso.z) + vec3(1e-4, 0.0, 0.0));
	vec3 destra = vec3(oriz.z, 0.0, -oriz.x);
	vec3 su = normalize(cross(verso, destra));
	su = normalize(mix(vec3(0.0, 1.0, 0.0), su, 0.75));
	float sc = length(MODEL_MATRIX[0].xyz);
	vec3 w = o + (destra * VERTEX.x + su * (VERTEX.y + alza)) * sc;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(w, 1.0);
	// tipo di disegno nel colore dell'istanza (alpha), posa dalle braccia
	float tipo = floor(COLOR.a * 3.99);
	uv_atlante = vec2((tipo + UV.x) * 0.25, (braccia + UV.y) * 0.5);
	dati = vec4(squadra, n, INSTANCE_CUSTOM.z, INSTANCE_CUSTOM.w);
}

void fragment() {
	vec4 t = texture(atlante, uv_atlante);
	float n = dati.y;
	vec3 pelle = mix(vec3(0.95, 0.79, 0.65), vec3(0.33, 0.21, 0.14), dati.z);
	float k = h1(n + 5.3);
	vec3 capelli = k < 0.35 ? vec3(0.09, 0.07, 0.05) : (k < 0.6 ? vec3(0.22, 0.14, 0.08) : (k < 0.8 ? vec3(0.42, 0.27, 0.14) : (k < 0.9 ? vec3(0.75, 0.6, 0.35) : vec3(0.5))));
	pelle = lin(pelle);
	capelli = lin(capelli);
	vec3 secondo = dati.x < 0.25 ? casa2 : (dati.x > 0.75 ? ospiti2 : vec3(0.85));
	vec3 c = capelli;
	c = mix(c, secondo, smoothstep(0.25, 0.4, t.g));
	c = mix(c, lin(COLOR.rgb), smoothstep(0.65, 0.85, t.g));
	c = mix(c, pelle, smoothstep(0.35, 0.65, t.b));
	ALBEDO = c * t.r * dati.w * luce;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
