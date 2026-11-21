// Ciuffi d'erba in rilievo ("shell texturing"): pochi strati piatti sopra il prato, solo nei primi metri davanti alla
// telecamera bassa (scripts/campo.gd li sposta e li accende). Ogni strato tiene solo i punti dove i fili della texture
// sono più alti della sua quota: guardando di sbieco i fili si staccano dal prato, coprono un po' le scarpe, il
// pallone e il bordo delle righe. Colore e luce sono quelli del prato (shaders/erba_comune.gdshaderinc), un po' più
// scuri in basso (ombra tra i fili) e più chiari in punta. Sopra le righe bianche i fili sono bianchi (il gesso sta
// sulle punte): campo.gd passa i pezzi di riga vicini (al massimo RIGHE_MAX), così il bordo della riga resta sfrangiato
// dai fili ma la riga non si buca.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, fog_disabled, cull_back;

#include "res://shaders/erba_comune.gdshaderinc"

uniform float raggio = 9.0;        // m dalla telecamera: oltre, niente ciuffi (sfumano prima)
const int RIGHE_MAX = 8;
// pezzi di riga vicini (coordinate del gioco), da scripts/campo.gd (scripts/righe_campo.gd pezzi()):
//   linea: a = (ax, ay, bx, by), b.w = 0 · arco: a = (cx, cy, r, cos mezza apertura), b = (verso di mezzo x, y, 0, 1)
//   punto: a = (cx, cy, r, 0), b.w = 2
uniform vec4 righe_a[RIGHE_MAX];
uniform vec4 righe_b[RIGHE_MAX];
uniform int righe_n = 0;
uniform vec3 colore_righe : source_color = vec3(0.93, 0.94, 0.9);   // come shaders/righe.gdshader
const float RIGA_MEZZA = 0.06;     // mezza larghezza di una riga (m), come scripts/righe_campo.gd
const float PRATO_X = 42.0;        // mezzo prato con i margini (scripts/campo.gd: HW + MX), oltre niente ciuffi
const float PRATO_Z = 62.0;        // (HL + MY)
const float SCALA = 2.2;           // m di una ripetizione dei fili nei ciuffi: fili più grossi del prato, sennò
                                   // da qualche metro sarebbero più fini di un pixel e la mipmap li cancellerebbe
const float PENDE = 0.012;         // m: quanto pendono le punte nel verso del taglio (fasce alterne in versi opposti)
const float SOGLIA_BASSO = 0.52;   // strato più basso: tiene i fili sopra la media
const float SOGLIA_ALTO = 0.40;    // in più per lo strato più alto: solo le punte
const float OMBRA_BASSO = 0.80;    // colore dello strato più basso (ombra tra i fili)
const float LUCE_PUNTA = 1.06;     // colore delle punte

varying vec2 pos_mondo;

// distanza (m) dal pezzo di riga più vicino, nel punto p del gioco (per i punti: dal bordo del dischetto, meno 6 cm)
float dist_righe(vec2 p) {
	float d = 1e3;
	for (int i = 0; i < righe_n; i++) {
		vec4 a = righe_a[i];
		vec4 b = righe_b[i];
		if (b.w < 0.5) {
			vec2 ab = a.zw - a.xy;
			float t = clamp(dot(p - a.xy, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
			d = min(d, length(p - a.xy - ab * t));
		} else if (b.w < 1.5) {
			vec2 v = p - a.xy;
			float l = length(v);
			if (dot(v, b.xy) >= a.w * l) {
				d = min(d, abs(l - a.z));
			}
		} else {
			d = min(d, max(length(p - a.xy) - a.z + RIGA_MEZZA, 0.0));
		}
	}
	return d;
}
varying float strato;              // 0 = strato più basso, 1 = più alto (COLOR.r della mesh)

void vertex() {
	pos_mondo = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	strato = COLOR.r;
}

void fragment() {
	if (abs(pos_mondo.x) > PRATO_X || abs(pos_mondo.y) > PRATO_Z) {
		discard;
	}
	float dist = length(VERTEX);
	vec2 p = vec2(pos_mondo.x, -pos_mondo.y);
	vec2 dp = fwidth(p);
	// prima il taglio (solo conti, niente texture) e un filo solo: chi non serve esce subito
	float verso = disegno(p, dp).x * 2.0 - 1.0;
	vec2 punta = pos_mondo - asse_taglio() * (verso * PENDE * strato);
	float filo = texture(fili, punta / SCALA).b;
	float soglia = SOGLIA_BASSO + SOGLIA_ALTO * strato + smoothstep(raggio * 0.5, raggio, dist);
	if (filo < soglia) {
		discard;
	}
	vec3 vista = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 0.0)).xyz);
	Erba e = erba_colore(pos_mondo, dp, dFdx(pos_mondo), dFdy(pos_mondo), dist, vista);
	float riga = 1.0 - smoothstep(RIGA_MEZZA - dp.x, RIGA_MEZZA + dp.x, dist_righe(p));
	ALBEDO = mix(e.albedo, colore_righe, riga) * mix(OMBRA_BASSO, LUCE_PUNTA, strato);
	NORMAL_MAP = e.normal_map;
	NORMAL_MAP_DEPTH = forza_dettaglio;
	ROUGHNESS = mix(e.roughness, 0.9, riga);
	SPECULAR = mix(e.specular, 0.25, riga);
}
