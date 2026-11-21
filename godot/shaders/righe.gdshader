// Righe bianche del campo (mesh di scripts/righe_campo.gd): ogni vertice sta sulla linea di mezzo e qui si sposta
// di lato di mezza larghezza. Da lontano la riga si allarga quanto basta per restare larga almeno MIN_PX pixel
// (anche di traverso, dove la prospettiva la schiaccia): così non sparisce e non sfarfalla, su ogni telefono.
// Tutti i conti stanno nel vertex shader (pochi vertici, precisione piena); il fragment dà solo il colore.
// Illuminata come l'erba, così le ombre dei giocatori ci passano sopra.
shader_type spatial;
render_mode world_vertex_coords, cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec3 colore : source_color = vec3(0.93, 0.94, 0.9);   // bianco un po' sporco (gesso sull'erba)
uniform float min_px = 1.5;        // larghezza minima a schermo (pixel del 3D)
const float SCORCIO_MIN = 0.25;    // riga vista quasi di taglio: si allarga al massimo di 1/0,25 = 4 volte

void vertex() {
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 dv = VERTEX - cam;
	float dist = max(length(dv), 0.01);
	vec2 lato = CUSTOM0.xy;
	float lato_len = length(lato);
	vec3 dir = lato_len > 0.0 ? vec3(lato.x, 0.0, lato.y) / lato_len : vec3(1.0, 0.0, 0.0);
	float lungo_vista = dot(dir, dv / dist);
	float scorcio = sqrt(max(1.0 - lungo_vista * lungo_vista, 0.0));
	float px = 2.0 * dist / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);   // m coperti da un pixel a questa distanza
	float mezza = max(UV.x, 0.5 * min_px * px / max(scorcio, SCORCIO_MIN));
	VERTEX += (vec3(lato.x, 0.0, lato.y) + vec3(CUSTOM0.z, 0.0, CUSTOM0.w)) * mezza;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	// normale sempre verso l'alto (in coordinate di vista): con cull_disabled i triangoli girati al contrario
	// (archi, dischetti) avrebbero la normale verso il basso e verrebbero neri
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ALBEDO = colore;
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
}
