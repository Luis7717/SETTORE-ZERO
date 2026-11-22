// Capelli del giocatore (mesh di scripts/partita/capelli.gd, porting di src/hair3d.js), un materiale per tutti.
// La tinta è quella del web (paintHairTex): assets/textures/capelli_tinta.png (tools/make-godot-tex.mjs) dice per ogni
// pixel quanto c'è di tre colori, R = capelli, G = lucentezza, B = pelle (il resto è nero), e qui si mescolano col
// colore dei capelli e della pelle del giocatore (per istanza). Le miscele si fanno in sRGB come il canvas del web.
// UV2 = uv della zona della tinta del web (0..1): l'elastico di coda e chignon sta in una fascia fissa.
// Luce come la pelle del web (Lambert, opaco): niente trasparenze.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

instance uniform vec4 colore : source_color = vec4(0.11, 0.08, 0.06, 1.0);
instance uniform vec4 pelle : source_color = vec4(0.94, 0.79, 0.65, 1.0);
instance uniform vec4 punte : source_color = vec4(0.0);   // sfumati (2026-11-22): colore delle punte se a = 1
uniform sampler2D tinta : hint_default_white, filter_linear_mipmap, repeat_disable;

const vec2 EXTRA_U = vec2(0.81, 1.01);    // pezzi in più (TEX_EXTRA del web, col margine)
const float RISVOLTO_V = 0.9;             // risvolto interno (TEX_UNDER del web e oltre)
const vec2 ELASTICO_V = vec2(0.06, 0.14); // TEX_TIE del web

void fragment() {
	vec3 k = texture(tinta, UV).rgb;
	vec3 hs = sqrt(colore.rgb);   // sRGB (circa)
	if (punte.a > 0.5) {
		// sfumato: verso il bordo della calotta (UV2.y in giù) e lungo coda e trecce il colore passa a quello delle punte
		float verso = UV2.x < EXTRA_U.x ? smoothstep(0.5, 0.88, UV2.y) : smoothstep(0.45, 0.98, UV2.y);
		hs = mix(hs, sqrt(punte.rgb), verso);
	}
	vec3 ss = sqrt(pelle.rgb);
	float l = dot(hs, vec3(0.299, 0.587, 0.114));
	vec3 lampo = l > 0.6 ? vec3(1.0) : vec3(1.0, 0.945, 0.863);   // #fff1dc
	vec3 shine = mix(hs, lampo, 0.16 + 0.22 * (1.0 - l));
	vec3 c = k.r * hs + k.g * shine + k.b * ss;
	// risvolto sotto il bordo: nel web è scuro, ma qui dal davanti se ne vedeva un filo (riga scura all'attaccatura):
	// prende il colore del bordo della calotta
	if (UV2.x < EXTRA_U.x && UV2.y > RISVOLTO_V) {
		c = hs * 0.86;
	}
	if (UV2.x > EXTRA_U.x && UV2.y > ELASTICO_V.x && UV2.y < ELASTICO_V.y) {
		c = l < 0.25 ? vec3(0.722, 0.196, 0.227) : vec3(0.149, 0.149, 0.173);   // #b8323a / #26262c
	}
	ALBEDO = c * c;
	ROUGHNESS = 0.78;
	SPECULAR = 0.25;
}
