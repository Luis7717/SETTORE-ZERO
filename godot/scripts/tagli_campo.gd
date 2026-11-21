# Tagli dell'erba (solo grafica, il motore non li vede): come è stato tosato il campo, ispirati a stadi veri.
# Il numero del taglio va allo shader dell'erba (shaders/erba.gdshader, uniform `taglio`): l'ordine di NOMI
# deve restare quello dello shader.
#
# Scelta: ogni squadra ha il suo stadio con un taglio fisso ricavato dal suo seme (da_seme); in campionato conta la
# squadra di casa, in amichevole e allenamento il seme della partita (scripts/partita/gioco.gd). Per le prove:
# `--campo=<nome>` sulla riga di comando vince su tutto (da_riga_comando, letto da scripts/campo.gd).
extends RefCounted

## nomi dei tagli, nell'ordine dello shader
const NOMI: Array[String] = [
	"strisce",     # 0 strisce larghe di traverso (il classico)
	"strette",     # 1 strisce strette di traverso
	"verticali",   # 2 strisce lungo il campo
	"quadrotti",   # 3 scacchiera
	"cerchi",      # 4 cerchi concentrici dal centro
	"uniforme",    # 5 erba semplice, senza disegni
	"rombi",       # 6 diagonali incrociate
	"raggi",       # 7 strisce di traverso + cerchio di centrocampo a spicchi
	"diagonali",   # 8 strisce larghe in diagonale (come San Siro)
]

## manti (colore e tipo d'erba), presi da foto di stadi veri mandate da Luis: colore a schermo della fascia chiara e
## di quella scura (sRGB 0..255, misurato sulle foto); lo shader riceve l'albedo = colore / TARATURA (vedi colori_manto)
const MANTI: Array[Dictionary] = [
	{"nome": "vivo", "chiara": Color8(66, 168, 0), "scura": Color8(56, 149, 0)},        # 0 giallo-verde acceso (stadio torinese, sole)
	{"nome": "milano", "chiara": Color8(133, 192, 84), "scura": Color8(88, 145, 25)},  # 1 strisce molto contrastate (San Siro)
	{"nome": "naturale", "chiara": Color8(125, 152, 70), "scura": Color8(95, 124, 38)}, # 2 erba vera un po' consumata, oliva
	{"nome": "sintetico", "chiara": Color8(60, 150, 70), "scura": Color8(45, 125, 55)}, # 3 sintetico verde-azzurro scuro
	{"nome": "sintetico_chiaro", "chiara": Color8(95, 185, 75), "scura": Color8(78, 160, 60)}, # 4 sintetico brillante
	{"nome": "estivo", "chiara": Color8(150, 165, 75), "scura": Color8(125, 140, 55)}, # 5 erba d'estate, più gialla
]
const TARATURA := 1.29   # colore a schermo / albedo, misurato con la luce della partita (schermate 1170x2532)
const MANTO_CLASSICO := 0
const CLASSICO := 0


## taglio fisso per un seme (squadra o partita): stesso seme = stesso taglio, semi vicini = tagli diversi
static func da_seme(seme: int) -> int:
	var h := (seme * 2654435761 + 40503) & 0x7fffffff   # moltiplicazione di Knuth, tenuta positiva
	h = (h ^ (h >> 15)) & 0x7fffffff
	return h % NOMI.size()


## manto fisso per un seme (diverso dal taglio: altro rimescolamento)
static func manto_da_seme(seme: int) -> int:
	var h := (seme * 2246822519 + 7919) & 0x7fffffff
	h = (h ^ (h >> 13)) & 0x7fffffff
	return h % MANTI.size()


## albedo per lo shader dell'erba: [chiara, scura, chiara_bordo, scura_bordo]
static func colori_manto(i: int) -> Array[Color]:
	var m: Dictionary = MANTI[clampi(i, 0, MANTI.size() - 1)]
	var c: Color = m.chiara
	var d: Color = m.scura
	var a := Color(c.r / TARATURA, c.g / TARATURA, c.b / TARATURA)
	var b := Color(d.r / TARATURA, d.g / TARATURA, d.b / TARATURA)
	return [a, b, a * 1.03, b * 0.96]


## numero del manto dal nome; −1 se non esiste
static func indice_manto(nome: String) -> int:
	var n := nome.strip_edges().to_lower()
	for i in MANTI.size():
		if MANTI[i].nome == n:
			return i
	return int(n) if n.is_valid_int() and int(n) >= 0 and int(n) < MANTI.size() else -1


## `--manto=<nome>` dalla riga di comando; −1 se manca
static func manto_da_riga_comando(args: PackedStringArray = OS.get_cmdline_user_args()) -> int:
	for a in args:
		if a.begins_with("--manto="):
			var i := indice_manto(a.substr(8))
			if i < 0:
				push_warning("--manto: sconosciuto '%s'" % a.substr(8))
			return i
	return -1


## numero del taglio dal nome (anche il numero scritto come testo); −1 se non esiste
static func indice(nome: String) -> int:
	var n := nome.strip_edges().to_lower()
	if n.is_valid_int():
		var i := int(n)
		return i if i >= 0 and i < NOMI.size() else -1
	return NOMI.find(n)


## `--campo=<nome>` dalla riga di comando (dopo "--"); −1 se manca o il nome non esiste
static func da_riga_comando(args: PackedStringArray = OS.get_cmdline_user_args()) -> int:
	for a in args:
		if a.begins_with("--campo="):
			var i := indice(a.substr(8))
			if i < 0:
				push_warning("--campo: taglio sconosciuto '%s' (validi: %s)" % [a.substr(8), ", ".join(NOMI)])
			return i
	return -1
