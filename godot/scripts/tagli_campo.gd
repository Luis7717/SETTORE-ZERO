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
]
const CLASSICO := 0


## taglio fisso per un seme (squadra o partita): stesso seme = stesso taglio, semi vicini = tagli diversi
static func da_seme(seme: int) -> int:
	var h := (seme * 2654435761 + 40503) & 0x7fffffff   # moltiplicazione di Knuth, tenuta positiva
	h = (h ^ (h >> 15)) & 0x7fffffff
	return h % NOMI.size()


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
