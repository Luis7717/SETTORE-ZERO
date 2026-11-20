// Cartelloni a led (scripts/stadio/cartelloni.gd, porting di ADS_FRAG di src/stadium-ads.js): una texture con 16
// sponsor inventati (una riga ciascuno, due grafiche: marchio e slogan). Lo shader sceglie la riga: di solito lo stesso
// sponsor su tutta la linea, a volte un mosaico; il cambio scorre in verticale e corre lungo la linea.
// Da vicino si vede la griglia dei led; i colori escono un po' sopra 1 per accendere il bagliore.
// UV: u = metri dall'inizio della linea × U_PER_M (le grafiche corrono da un pannello all'altro), v = 0 in basso.
shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform sampler2D grafiche : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float riga_a = 0.0;      // sponsor di adesso
uniform float riga_b = 5.0;      // sponsor che sta arrivando
uniform float cambio = 0.0;      // 0..1 durante il cambio
uniform float mosaico_a = 0.0;   // 1 = sponsor diversi pannello per pannello
uniform float mosaico_b = 0.0;
uniform float forza = 1.35;      // luminosità dei led (sopra 1 → bagliore)
uniform float led_px = 96.0;     // led per unità di u (griglia visibile da vicino)

const float RIGHE = 16.0;

void fragment() {
	vec2 uv0 = vec2(UV.x, 1.0 - UV.y);
	float pannello = floor(uv0.x * 2.0);
	float p = clamp(cambio * 1.8 - fract(uv0.x * 0.045), 0.0, 1.0);
	p = p * p * (3.0 - 2.0 * p);
	float s = uv0.y + p;
	float usa_b = step(1.0, s);
	float sposta = mod(pannello * 5.0, RIGHE) * mix(mosaico_a, mosaico_b, usa_b);
	float riga = mod(mix(riga_a, riga_b, usa_b) + sposta, RIGHE);
	float ly = clamp(fract(s), 0.03, 0.97);
	vec2 suv = vec2(uv0.x, (riga + 1.0 - ly) / RIGHE);
	vec2 sc = vec2(1.0, 1.0 / RIGHE);
	vec3 c = textureGrad(grafiche, suv, dFdx(uv0) * sc, dFdy(uv0) * sc).rgb;
	float giunta = mix(1.0, smoothstep(0.0, 0.05, fract(s)) * smoothstep(1.0, 0.95, fract(s)), step(0.001, p) * step(p, 0.999));
	// griglia dei led: si vede solo quando un led è più grande di ~3 pixel, poi sfuma (niente sfarfallio da lontano)
	vec2 g = vec2(uv0.x * led_px, uv0.y * 14.0);
	vec2 f = abs(fract(g) - 0.5);
	float punti = 1.0 - smoothstep(0.32, 0.5, max(f.x, f.y));
	float vicino = 1.0 - smoothstep(0.08, 0.3, max(fwidth(g.x), fwidth(g.y)));
	c *= mix(1.0, 0.55 + 0.6 * punti, vicino);
	ALBEDO = c * giunta * forza;
}
