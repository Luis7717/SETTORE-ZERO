// Telo della bandierina d'angolo che sventola (come waveFlags di src/props.js): onde che corrono dall'asta verso
// il bordo libero, più ampie lontano dall'asta. "asta" = x locale del lato attaccato all'asta.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

uniform vec4 colore : source_color = vec4(1.0, 0.8, 0.1, 1.0);
instance uniform float asta = 0.21;
instance uniform float fase = 0.0;
const float LUNGO = 0.42;

void vertex() {
	float u = clamp(abs(VERTEX.x - asta) / LUNGO, 0.0, 1.0);
	float onda = sin(TIME * 7.5 - u * 4.2 + fase + UV.y * 0.6) * 0.075 * u + sin(TIME * 13.0 - u * 7.0 + fase) * 0.02 * u;
	VERTEX.z += onda;
	VERTEX.x += sign(asta) * u * LUNGO * 0.06 * abs(onda) / 0.075;
	VERTEX.y -= u * u * 0.05;
}

void fragment() {
	ALBEDO = colore.rgb;
}
