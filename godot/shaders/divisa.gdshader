// Divisa, pelle, capelli e viso del giocatore (modello athlete.glb, Quaternius CC0), dipinti per zone del corpo come
// fa src/athlete3d.js nel gioco web, ma calcolati qui per pixel invece che in una texture.
// CUSTOM0.xyz = posizione del vertice nella posa di riposo (a T), scritta da scripts/giocatore.gd: le zone
// (maglia, maniche, pantaloncini, calzettoni, scarpe, testa, capelli) seguono il corpo anche mentre corre.
// I colori e lo stile cambiano per giocatore con le "instance uniform" (un solo materiale per tutti i 22):
//   stile  = maniche (0 corte, 1 lunghe, 2 senza), colletto (0 girocollo, 1 a V, 2 polo), motivo (0 tinta unita,
//            1 righe verticali, 2 orizzontali, 3 banda diagonale, 4 metà e metà), calzettoni (0 alti, 1 bassi, 2 ripiegati)
//   stile2 = taglio dei capelli (0..16 come HAIR_STYLES di src/looks.js), barba (0..6), sopracciglia (0..5),
//            pantaloncini (0 corti, 1 lunghi)
//   numero = cella (x, y) del cognome e numero nell'atlante "schiene" (scripts/partita/schiene.gd), z = 1 se c'è,
//            w = maglia larga (1) o aderente (0)
//   corsa  = 0..1 quanto corre (la maglia ondeggia)
// I capelli non sono mesh a parte (il web ne costruisce una per taglio): la zona coperta cambia col taglio e i vertici
// della testa si gonfiano lungo la normale (spessore del taglio, ricci, punte, cresta, chignon). Code e capelli
// lunghi che pendono non si possono fare così: restano più corti che nel web.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;   // lambert: più leggero di burley sul telefono

instance uniform vec4 maglia : source_color = vec4(0.78, 0.06, 0.18, 1.0);
instance uniform vec4 calzoncini : source_color = vec4(1.0);
instance uniform vec4 calzettoni : source_color = vec4(0.78, 0.06, 0.18, 1.0);
instance uniform vec4 bordino : source_color = vec4(1.0);
instance uniform vec4 pelle : source_color = vec4(0.94, 0.79, 0.65, 1.0);
instance uniform vec4 capelli : source_color = vec4(0.11, 0.08, 0.06, 1.0);
instance uniform vec4 iride : source_color = vec4(0.25, 0.17, 0.1, 1.0);
instance uniform vec4 scarpe : source_color = vec4(0.08, 0.08, 0.09, 1.0);
instance uniform vec4 stile = vec4(0.0);
instance uniform vec4 stile2 = vec4(2.0, 0.0, 0.0, 0.0);
instance uniform vec4 numero = vec4(0.0);
instance uniform float corsa = 0.0;

// misure del corpo in posa di riposo (m), dalle ossa: le imposta scripts/giocatore.gd
uniform float anca_y = 0.97;
uniform float caviglia_y = 0.09;
uniform float collo_y = 1.52;
uniform float collo_z = -0.041;
uniform float petto_y = 1.38;
uniform float spalla_x = 0.17;
uniform float gomito_x = 0.45;
uniform float polso_x = 0.68;
uniform float testa_alto = 1.81;
uniform vec3 testa = vec3(0.0, 1.6, 0.0);
uniform vec3 occhi = vec3(0.034, 1.698, 0.07);   // centro dell'occhio sinistro (x > 0)
uniform vec2 davanti = vec2(0.0, 1.0);   // verso del viso nella posa di riposo (piano xz)
uniform sampler2D schiene : source_color, hint_default_transparent, filter_linear_mipmap, repeat_disable;

const float COLLO_R = 0.085;      // mezza larghezza del collo (m)
const float SCOLLO_R = 0.078;     // raggio dello scollo attorno al collo (m)
const float BORDO = 0.014;        // bordini (colletto, maniche, calzettoni) (m)
const float AA = 0.005;           // bordi morbidi dei motivi (m)
const vec2 OCCHI_UV = vec2(0.875); // tassello degli occhi nell'atlante (come EYE_PX del web: 896/1024)
const vec2 CELLA = vec2(0.125, 0.25); // atlante delle schiene: 8 × 4 celle
const float SCHIENA = 0.4;        // m di schiena coperti da una cella (come il canvas 256 px del web)
const float ALZA_BOCCA = -0.058;  // bocca rispetto agli occhi (m)

// tagli: attaccatura (gradi di elevazione sopra il centro della testa) davanti, ai lati e dietro; spessore (m)
const vec4 TAGLI[17] = vec4[17](
	vec4(95.0, 95.0, 95.0, 0.0),      // 0 calvo
	vec4(42.0, 6.0, -38.0, 0.002),    // 1 rasato
	vec4(38.0, 8.0, -34.0, 0.011),    // 2 corti
	vec4(40.0, 10.0, -32.0, 0.014),   // 3 spazzola
	vec4(36.0, 8.0, -34.0, 0.012),    // 4 ciuffo
	vec4(36.0, 6.0, -36.0, 0.012),    // 5 riga di lato
	vec4(42.0, 6.0, -38.0, 0.002),    // 6 cresta (lati rasati)
	vec4(38.0, 8.0, -34.0, 0.014),    // 7 a punte
	vec4(34.0, 4.0, -38.0, 0.024),    // 8 ricci
	vec4(30.0, -2.0, -42.0, 0.048),   // 9 afro
	vec4(30.0, -26.0, -58.0, 0.02),   // 10 caschetto
	vec4(32.0, -38.0, -75.0, 0.022),  // 11 lunghi
	vec4(36.0, 6.0, -30.0, 0.009),    // 12 coda
	vec4(36.0, 6.0, -30.0, 0.009),    // 13 chignon
	vec4(34.0, -6.0, -45.0, 0.015),   // 14 treccine
	vec4(14.0, 2.0, -40.0, 0.015),    // 15 frangia
	vec4(40.0, 10.0, -34.0, 0.011)    // 16 indietro
);
const float SOPRACCIGLIA[6] = float[6](0.008, 0.005, 0.011, 0.008, 0.008, 0.01);

varying vec3 riposo;

// direzione dal centro della testa: x = elevazione, y = |azimut| (gradi, 0 = davanti), z = distanza (m)
vec3 testa_dir(vec3 p) {
	vec3 c = vec3(0.0, occhi.y, 0.0) + vec3(davanti.x, 0.0, davanti.y) * (dot(occhi.xz, davanti) - 0.075);
	vec3 d = p - c;
	float r = max(length(d), 1e-4);
	float fr = dot(d.xz, davanti);
	float lat = d.x * davanti.y - d.z * davanti.x;
	return vec3(degrees(asin(clamp(d.y / r, -1.0, 1.0))), abs(degrees(atan(lat, fr))), r);
}

float attaccatura(vec4 t, float az) {
	return az < 95.0 ? mix(t.x, t.y, smoothstep(25.0, 95.0, az)) : mix(t.y, t.z, smoothstep(100.0, 170.0, az));
}

// spessore dei capelli (m) nel punto p del taglio `taglio`; copertura (0..1) in cop
float capelli_spessore(int taglio, vec3 p, out float cop) {
	vec3 h = testa_dir(p);
	float el = h.x;
	float az = h.y;
	vec4 t = TAGLI[taglio];
	float linea = attaccatura(t, az);
	cop = smoothstep(linea - 1.5, linea + 1.5, el);
	float s = t.w * smoothstep(linea, linea + 10.0, el);
	float lat = abs(p.x);
	if (taglio == 3) {
		s *= 1.0 + 0.7 * smoothstep(50.0, 80.0, el);
	} else if (taglio == 4) {
		s += 0.02 * smoothstep(60.0, 15.0, az) * smoothstep(30.0, 60.0, el);
	} else if (taglio == 6) {
		float k = smoothstep(0.03, 0.012, lat) * smoothstep(10.0, 30.0, el);
		s = max(s, 0.035 * k);
		cop = max(cop, k);
	} else if (taglio == 7) {
		s *= 0.55 + 0.9 * max(0.0, sin(radians(az) * 9.0) * sin(radians(el) * 7.0));
	} else if (taglio == 8 || taglio == 9) {
		s *= 0.8 + 0.35 * sin(radians(az) * 14.0 + radians(el) * 17.0) * sin(radians(el) * 23.0 - radians(az) * 8.0);
	} else if (taglio == 12) {
		s += 0.05 * exp(-(pow((180.0 - az) / 20.0, 2.0) + pow((el + 5.0) / 18.0, 2.0)));
	} else if (taglio == 13) {
		s += 0.06 * exp(-(pow((180.0 - az) / 22.0, 2.0) + pow((el - 40.0) / 18.0, 2.0)));
	} else if (taglio == 14) {
		s *= 0.5 + 0.9 * pow(abs(sin(radians(az) * 6.0)), 0.6);
	} else if (taglio == 16) {
		s += 0.012 * smoothstep(100.0, 170.0, az);
	}
	// orecchie: colorate ma non gonfiate (spunterebbero di lato)
	if (az > 70.0 && az < 120.0 && el < 20.0 && el > -45.0) {
		s *= 0.15;
	}
	return s;
}

void vertex() {
	riposo = CUSTOM0.xyz;
	vec3 p = riposo;
	int taglio = clamp(int(stile2.x + 0.5), 0, 16);
	if (p.y > collo_y - 0.02 && abs(p.x) < 0.16 && taglio > 0) {
		float cop;
		float s = capelli_spessore(taglio, p, cop);
		VERTEX += NORMAL * s * cop;
	}
	float maglia_bassa = anca_y + 0.035;
	float ax = abs(p.x);
	if (p.y > maglia_bassa - 0.03 && p.y < collo_y && ax < spalla_x + 0.06) {
		// maglia: larga = un filo più gonfia; mentre corre ondeggia, di più verso l'orlo
		float orlo = 1.0 - smoothstep(maglia_bassa, collo_y - 0.12, p.y);
		float onda = sin(TIME * 13.0 + p.y * 38.0 + p.x * 21.0) * 0.5 + sin(TIME * 21.0 - p.y * 55.0) * 0.25;
		VERTEX += NORMAL * (numero.w * 0.007 * (0.4 + orlo) + corsa * 0.006 * onda * (0.25 + orlo));
	}
}

float banda(float d, float meta) {
	return clamp(0.5 + (meta - abs(d)) / AA, 0.0, 1.0);
}

// motivo della maglia (pattern di src/athlete3d.js): quanto colore secondario in p
float motivo(int m, vec3 p, float zf, bool braccio) {
	if (m == 1 && !braccio) {
		float u = fract((p.x + 0.0175) / 0.07) * 0.07;
		return banda(u - 0.0175, 0.0175);
	}
	if (m == 2) {
		float u = fract((p.y - petto_y) / 0.085) * 0.085;
		return banda(u - 0.0204, 0.0204);
	}
	if (m == 3 && !braccio) {
		float d = p.x * (zf > 0.0 ? 1.0 : -1.0) + (p.y - petto_y) * 0.9;
		return banda(d + 0.02, 0.04);
	}
	if (m == 4) {
		float d = p.x * (zf < 0.0 ? -1.0 : 1.0);
		return clamp(0.5 - d / AA, 0.0, 1.0);
	}
	return 0.0;
}

// scollo (neckline di src/athlete3d.js): > 0 dentro lo scollo (pelle), vicino a 0 il bordino
float scollo(int collar, vec3 p, float zf) {
	float ax = abs(p.x);
	float base = collo_y - 0.012;
	float radiale = SCOLLO_R - length(vec2(p.x, (zf - collo_z) * 1.15));
	float y;
	if (zf <= collo_z) {
		y = p.y - (base + 0.004 + 4.0 * ax * ax);
	} else if (collar == 1) {
		float vy = base - 0.075 + min(1.0, ax / 0.05) * 0.06;
		y = p.y - max(vy, base - 0.02 + 3.0 * ax * ax - (ax < 0.05 ? 1.0 : 0.0));
	} else {
		y = p.y - (base - 0.028 + 5.0 * ax * ax);
	}
	return min(y, radiale);
}

// barba (BEARDS di src/looks.js): quanta tinta dei capelli sul viso in p
float barba(int b, vec3 p, float zf) {
	if (b == 0) {
		return 0.0;
	}
	float y = p.y - occhi.y;
	float ax = abs(p.x);
	float fr = zf - dot(occhi.xz, davanti);   // 0 al piano degli occhi, < 0 verso le orecchie
	float bocca = y - ALZA_BOCCA;
	float labbra = (abs(bocca) < 0.0065 && ax < 0.02) ? 0.0 : 1.0;
	float mascella = smoothstep(-0.03, -0.042, y) * smoothstep(-0.11, -0.07, fr) * labbra;
	float guance = smoothstep(-0.012, -0.03, y) * smoothstep(0.03, 0.05, ax) * smoothstep(-0.1, -0.07, fr);
	float pizzetto = (ax < 0.024 && bocca < -0.007 && fr > -0.03) ? 1.0 : 0.0;
	float baffi = (ax < 0.03 - bocca * 0.6 && bocca > 0.005 && bocca < 0.016 && fr > -0.02) ? 1.0 : 0.0;
	if (b == 1) return 0.32 * max(mascella, guance * 0.6);
	if (b == 2) return 0.9 * pizzetto;
	if (b == 3) return 0.9 * baffi;
	if (b == 4) return 0.9 * max(pizzetto, baffi);
	if (b == 5) return 0.72 * max(max(mascella, guance * 0.7), baffi);
	return 0.92 * max(max(mascella, guance), baffi);
}

float sopracciglia(int s, vec3 p, float zf) {
	float y = p.y - occhi.y;
	float ax = abs(p.x);
	if (zf - dot(occhi.xz, davanti) < -0.012 || ax < 0.011 || ax > 0.055) {
		return 0.0;
	}
	float k = (ax - occhi.x) / 0.022;
	float arco = s == 3 ? 0.006 * (1.0 - k * k) : (s == 4 ? 0.0 : 0.003 * (1.0 - k * k));
	float basso = 0.016 + arco - (s == 5 ? 0.003 * k : 0.0);
	float th = SOPRACCIGLIA[s] * (1.0 - 0.35 * smoothstep(0.2, 1.1, k));
	return step(basso, y) * step(y, basso + th);
}

void fragment() {
	vec3 p = riposo;
	float ax = abs(p.x);
	float zf = dot(p.xz, davanti);
	int maniche = int(stile.x + 0.5);
	int colletto = int(stile.y + 0.5);
	int disegno = int(stile.z + 0.5);
	int calze = int(stile.w + 0.5);
	int taglio = clamp(int(stile2.x + 0.5), 0, 16);
	float gamba = anca_y - caviglia_y;
	float maglia_bassa = anca_y + 0.035;
	float pantaloncini_fine = anca_y - (stile2.w > 0.5 ? 0.5 : 0.36) * gamba;
	float calzettoni_alto = anca_y - (calze == 1 ? 0.84 : (calze == 2 ? 0.66 : 0.58)) * gamba;
	float scarpa_alto = caviglia_y + 0.035;
	float manica_fine = maniche == 1 ? polso_x - 0.015 : (maniche == 0 ? spalla_x + 0.55 * (gomito_x - spalla_x) : spalla_x - 0.035);

	vec3 c = pelle.rgb;
	float ruvido = 0.62;
	// < 0 dentro il collo (cilindro attorno all'osso: il petto davanti, alto quasi come il collo, resta maglia)
	float collo = max(collo_y - 0.035 - p.y, length(vec2(p.x, (zf - collo_z) * 1.15)) - COLLO_R);
	if (UV.x >= OCCHI_UV.x && UV.y >= OCCHI_UV.y) {
		// occhi: sclera, iride, pupilla (il tassello copre l'occhio intero)
		float d = length((UV - (OCCHI_UV + 0.0625)) / 0.0625);
		c = d < 0.34 ? (d < 0.16 ? vec3(0.02) : iride.rgb) : vec3(0.92, 0.9, 0.87);
		ruvido = 0.15;
	} else if (p.y > collo_y + 0.07 || collo < 0.0) {
		// testa e collo: viso (labbra, barba, sopracciglia), poi i capelli del taglio
		float bocca = p.y - occhi.y - ALZA_BOCCA;
		if (abs(bocca) < 0.006 && ax < 0.019 && zf > dot(occhi.xz, davanti) - 0.02) {
			c = mix(c, vec3(0.62, 0.3, 0.28), 0.22);
		}
		c = mix(c, capelli.rgb, barba(int(stile2.y + 0.5), p, zf));
		c = mix(c, capelli.rgb * 0.9, sopracciglia(clamp(int(stile2.z + 0.5), 0, 5), p, zf));
		if (taglio > 0) {
			float cop;
			float s = capelli_spessore(taglio, p, cop);
			// rasati: cute con la tinta a metà; gli altri: tinta piena, un filo più chiara dove il taglio è spesso
			float a = TAGLI[taglio].w < 0.005 ? 0.62 : 1.0;
			if (taglio == 6 && s > 0.01) {
				a = 1.0;
			}
			vec3 tinta = capelli.rgb * (0.85 + 6.0 * min(s, 0.03));
			if (taglio == 5 && abs(p.x - 0.03) < 0.003 && zf > 0.0) {
				tinta *= 0.6;   // riga
			}
			c = mix(c, tinta, cop * a);
			ruvido = mix(ruvido, 0.85, cop);
		}
	} else if (p.y > maglia_bassa) {
		if (ax > manica_fine) {
			c = pelle.rgb;                       // avambracci e mani
		} else {
			c = maglia.rgb;
			ruvido = 0.82;
			bool braccio = ax > spalla_x - 0.02;
			c = mix(c, bordino.rgb, motivo(disegno, p, zf, braccio));
			if (p.y < maglia_bassa + 0.012) {
				c *= 0.82;   // orlo
			}
			if (braccio && ax > manica_fine - BORDO) {
				c = bordino.rgb;
			}
			if (!braccio) {
				float nl = scollo(colletto, p, zf);
				if (nl > -0.012) {
					c = bordino.rgb;
				}
				if (nl > 0.0) {
					c = pelle.rgb;
					ruvido = 0.62;
				}
				if (colletto == 2 && zf > 0.0 && ax < 0.008 && p.y > collo_y - 0.13 && p.y < collo_y - 0.05) {
					c = bordino.rgb;
				}
				// cognome e numero sulla schiena (letti da dietro: il lato sinistro del giocatore è a sinistra)
				if (numero.z > 0.5 && zf < collo_z - 0.03) {
					vec2 uv = vec2(0.5 - p.x / SCHIENA, (collo_y - 0.02 - p.y) / SCHIENA);
					if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
						vec4 t = texture(schiene, (numero.xy + uv) * CELLA);
						c = mix(c, t.rgb, t.a);
					}
				}
			}
		}
	} else if (p.y > pantaloncini_fine) {
		c = calzoncini.rgb;
		ruvido = 0.82;
		if (p.y < pantaloncini_fine + 0.012) {
			c *= 0.8;
		}
	} else if (p.y > calzettoni_alto) {
		c = pelle.rgb;                           // ginocchia
	} else if (p.y > scarpa_alto) {
		c = calzettoni.rgb;
		ruvido = 0.85;
		if (calze == 2) {
			if (p.y > calzettoni_alto - 0.045) {
				c *= 0.82;
			} else if (p.y > calzettoni_alto - 0.055) {
				c = bordino.rgb;
			}
		} else if (p.y < calzettoni_alto - BORDO && p.y > calzettoni_alto - 2.0 * BORDO) {
			c = bordino.rgb;
		}
	} else {
		c = scarpe.rgb;
		ruvido = 0.4;
		if (p.y < 0.022) {
			c = vec3(0.9);
		} else if (abs(fract((zf * 1.6 + p.y * 3.0) * 6.0) - 0.5) < 0.12 && p.y < scarpa_alto - 0.01 && ax > 0.125) {
			c = dot(scarpe.rgb, vec3(0.3, 0.59, 0.11)) > 0.6 ? vec3(0.1) : vec3(0.92);   // righe sul fianco
		}
	}
	ALBEDO = c;
	ROUGHNESS = ruvido;
	SPECULAR = 0.35;
}
