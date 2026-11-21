// Capelli e barbe del giocatore (mesh di scripts/partita/capelli.gd e barbe.gd), un materiale per tutti:
// colore dei capelli e della pelle per istanza. Ciocche finte: striature lungo il verso dei capelli (UV.y lungo,
// UV.x di traverso, in metri), riflesso allungato (anisotropia sulla tangente = verso delle ciocche), radici e bordo
// più scuri, pelle che si intravede dove i capelli sono sottili. Ricci e treccine: rilievo calcolato (bump) e solchi.
// CUSTOM0: x = quanto si è dentro il taglio (m, < 0 fuori: lì si scarta il pixel, con rumore → bordo di peli),
//          y = tipo (0 lisci, 1 ricci, 2 treccine, 3 barba, 4 elastico, 5 lucidi/tirati, 6 riga di lato),
//          z = spessore dei capelli in quel punto (m).
// Niente trasparenza: solo pixel scartati (come un alpha scissor), economico sul telefono.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx, cull_disabled;   // due facce: i capelli che cadono si vedono anche da sotto

instance uniform vec4 colore : source_color = vec4(0.11, 0.08, 0.06, 1.0);
instance uniform vec4 pelle : source_color = vec4(0.94, 0.79, 0.65, 1.0);

const float FRANGIA = 0.0035;   // m: larghezza della fascia di peli sul bordo
const float VICINO = 3.5;       // m: oltre questa distanza i dettagli fini svaniscono (niente sfarfallio)

varying vec3 loc;
varying vec4 dati;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rumore(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float rumore3(vec3 p) {
	return rumore(p.xy + p.z * 1.7) * 0.5 + rumore(p.yz * 1.3 - p.x * 2.1) * 0.5;
}

void vertex() {
	loc = VERTEX;
	dati = CUSTOM0;
}

void fragment() {
	int tipo = int(dati.y + 0.5);
	float dist = length(VERTEX);
	float fine = 1.0 - smoothstep(VICINO * 0.5, VICINO, dist);   // 1 da vicino, 0 da lontano
	// bordo di peli: si scarta dove il campo va sotto una soglia che cambia col rumore
	float peli = rumore(loc.xz * 2600.0 + loc.y * 900.0) * 0.6 + rumore(loc.yx * 700.0) * 0.4;
	float soglia = (peli - 0.25) * FRANGIA * mix(0.5, 1.0, fine);
	if (dati.x < soglia) {
		discard;
	}
	// striature: fini di traverso, lunghe nel verso delle ciocche
	float s1 = rumore(vec2(UV.x * 1400.0, UV.y * 30.0));
	float s2 = rumore(vec2(UV.x * 380.0 + 3.1, UV.y * 9.0));
	float stria = mix(0.5, s1 * 0.55 + s2 * 0.45, 0.35 + 0.65 * fine);
	vec3 c = colore.rgb;
	float luma = dot(c, vec3(0.3, 0.59, 0.11));
	float contrasto = mix(0.55, 0.32, smoothstep(0.1, 0.7, luma));   // i chiari reggono meno contrasto
	c *= 1.0 - contrasto * 0.5 + contrasto * stria;
	float ruvido = 0.62;
	float aniso = 0.5;
	float spec = 0.28;
	vec3 n = FRONT_FACING ? NORMAL : -NORMAL;
	if (!FRONT_FACING) {
		c *= 0.55;   // dentro i capelli: in ombra
	}
	if (tipo == 1 || tipo == 2) {
		// rilievo: ricci (gobbette fitte) o treccine (solchi lungo la testa); bump con le derivate dello schermo
		float h;
		if (tipo == 1) {
			h = rumore3(loc * 260.0) * 0.6 + rumore3(loc * 640.0) * 0.4;
			c *= 0.62 + 0.62 * h;
			ruvido = 0.85;
			aniso = 0.0;
			spec = 0.15;
		} else {
			// solchi lungo la testa, dalla fronte alla nuca: angolo attorno a un asse avanti-dietro basso (1,6 m, sotto
			// l'attaccatura della nuca, così i solchi non si aprono a ventaglio dietro)
			float x = atan(loc.x, loc.y - 1.6) * 11.0;
			float solco = abs(sin(x * 3.14159));
			h = pow(solco, 0.6) + 0.15 * rumore(vec2(x * 4.0, loc.z * 900.0));
			// tra le treccine si vede la pelle
			c = mix(mix(pelle.rgb * 0.7, c * 0.8, 0.45), c * (0.85 + 0.3 * stria), smoothstep(0.15, 0.5, solco));
			ruvido = 0.6;
			aniso = 0.3;
		}
		vec3 dpx = dFdx(VERTEX);
		vec3 dpy = dFdy(VERTEX);
		float dhx = dFdx(h);
		float dhy = dFdy(h);
		vec3 r1 = cross(dpy, n);
		vec3 r2 = cross(n, dpx);
		float det = dot(dpx, r1);
		vec3 grad = sign(det) * (dhx * r1 + dhy * r2);
		n = normalize(abs(det) * n - grad * 0.0025 * fine);
	} else if (tipo == 3) {
		// barba: peli più radi, si vede un po' la pelle; niente riflesso allungato
		float radi = rumore(loc.xy * 1800.0);
		c = mix(c, mix(pelle.rgb, c, 0.55), (1.0 - smoothstep(0.0, 0.006, dati.x)) * 0.6 + (radi - 0.5) * 0.2 * fine);
		ruvido = 0.85;
		aniso = 0.0;
		spec = 0.3;
	} else if (tipo == 4) {
		c = vec3(0.05, 0.05, 0.06);
		ruvido = 0.4;
		aniso = 0.0;
	} else if (tipo == 5) {
		ruvido = 0.55;   // tirati indietro col gel: un po' più lucidi
		aniso = 0.6;
		spec = 0.3;
	} else if (tipo == 6) {
		// riga di lato: una linea di pelle sul davanti, a sinistra
		float riga = 1.0 - smoothstep(0.0012, 0.0028, abs(loc.x - 0.032));
		riga *= step(0.0, loc.z) * smoothstep(1.68, 1.73, loc.y);
		c = mix(c, mix(pelle.rgb, c, 0.5), riga);
	}
	// radici e bordo: più scuri e con la pelle sotto dove i capelli sono sottili (attaccatura, lati corti)
	if (tipo != 4) {
		float sottile = 1.0 - smoothstep(0.0, 0.007, dati.z);
		float bordo = 1.0 - smoothstep(0.0, 0.01, dati.x);
		c = mix(c, mix(pelle.rgb, c, 0.6), sottile * 0.45 * (1.0 - float(tipo == 1)));
		c *= 1.0 - 0.25 * bordo;
	}
	// ombra nelle pieghe: un filo più scuro di taglio (capelli che si coprono a vicenda)
	c *= mix(0.78, 1.0, smoothstep(0.0, 0.6, abs(dot(n, normalize(-VERTEX)))));
	NORMAL = n;
	ALBEDO = c;
	ROUGHNESS = ruvido;
	SPECULAR = spec;
	ANISOTROPY = aniso;
}
