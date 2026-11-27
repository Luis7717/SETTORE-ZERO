# I giochetti del dribbling della persona (Luis 2026-11-26: "fanno pena, falli veri e aggiungine"): 29 movimenti del
# calcio vero costruiti con coreo.gd (piedi fermi a terra, passi programmati, pallone mosso solo dai tocchi).
# Quale giochetto e quanto dura lo decide il motore (sim/skill.gd: evento 'dribble' con skill e show); qui si decide
# come si muovono gambe, busto, braccia e pallone. Niente è copiato da altri giochi: sono i gesti del calcio.
#
# Tutti si fanno IN CORSA (Luis 2026-11-26: "si ferma sul posto prima del giochetto"): il motore intanto porta il
# corpo avanti e di lato (`av`, `lat`, `vel` di sim/skill.gd), quindi i piedi fanno passi di corsa (coreo.appoggia_corsa,
# e i passi automatici di coreo.gd) e il pallone viaggia col corpo ("rel").
# Ogni giochetto ha due parti:
#   A (skill/ID.gd → a, dura `g` = show): la finta davanti al difensore;
#   B (skill/ID.gd → b, dall'evento 'dribble_go'): il tocco che porta via il pallone dal lato scelto e i primi passi di corsa nel
#     verso nuovo (il motore scatta oltre il difensore).
# Tunnel, sombrero e bicicletta: dal calcio in poi il pallone è quello staccato del motore (ball.finto: dritto, attrito
# e gravità veri) e il portatore gli corre dietro; qui c'è solo il gesto del calcio.
# Lati: S = lato scelto (+1 = sinistra del portatore), F = −S (finta); pS / pF = piede di quel lato.
# Riferimento del corpo: x sinistra, y su, z avanti, m del modello (a schermo ×1,25).
#
# Questo file è solo il registro: un file per giochetto in skill/<id>.gd (funzioni statiche a(c, S, g) e
# b(c, S, tg)), aiuti e costanti in comune in skill/comune.gd.
extends RefCounted

const Coreo := preload("coreo.gd")
const Corpo := preload("corpo.gd")
const K := preload("skill/comune.gd")

const GIOCHETTI := {
	"finta": preload("skill/finta.gd"),
	"stopgo": preload("skill/stopgo.gd"),
	"suola": preload("skill/suola.gd"),
	"doppiopasso": preload("skill/doppiopasso.gd"),
	"croqueta": preload("skill/croqueta.gd"),
	"fintatiro": preload("skill/fintatiro.gd"),
	"chop": preload("skill/chop.gd"),
	"cruyff": preload("skill/cruyff.gd"),
	"tacco": preload("skill/tacco.gd"),
	"pedalata": preload("skill/pedalata.gd"),
	"elastico": preload("skill/elastico.gd"),
	"tunnel": preload("skill/tunnel.gd"),
	"veronica": preload("skill/veronica.gd"),
	"elastico_inv": preload("skill/elastico_inv.gd"),
	"sombrero": preload("skill/sombrero.gd"),
	"bicicletta": preload("skill/bicicletta.gd"),
	"suola_via": preload("skill/suola_via.gd"),
	"finta_rientro": preload("skill/finta_rientro.gd"),
	"doppiopasso_inv": preload("skill/doppiopasso_inv.gd"),
	"suola_180": preload("skill/suola_180.gd"),
	"ponte": preload("skill/ponte.gd"),
	"elastico3": preload("skill/elastico3.gd"),
	"giro_tocco": preload("skill/giro_tocco.gd"),
	"waka": preload("skill/waka.gd"),
	"colpetto_giro": preload("skill/colpetto_giro.gd"),
	"cucchiaio_finta": preload("skill/cucchiaio_finta.gd"),
	"abracadabra": preload("skill/abracadabra.gd"),
	"veronica_classe": preload("skill/veronica_classe.gd"),
	"tornado": preload("skill/tornado.gd"),
}
const IDS := ["finta", "stopgo", "suola_via", "finta_rientro", "suola", "doppiopasso", "doppiopasso_inv",
	"suola_180", "croqueta", "fintatiro", "chop", "ponte", "elastico3", "cruyff", "tacco", "pedalata", "giro_tocco",
	"elastico", "tunnel", "waka", "veronica", "colpetto_giro", "cucchiaio_finta", "elastico_inv", "abracadabra",
	"veronica_classe", "sombrero", "tornado", "bicicletta"]
const BR_RIPOSO := K.BR_RIPOSO


## parte A del giochetto `id` (sconosciuto: finta di corpo)
static func parte_a(c: Coreo, id: String, S: float, g: float) -> void:
	(GIOCHETTI.get(id, GIOCHETTI.finta) as GDScript).a(c, S, g)


## parte B (arrivato lo scatto del motore, adesso)
static func parte_b(c: Coreo, id: String, S: float) -> void:
	(GIOCHETTI.get(id, GIOCHETTI.finta) as GDScript).b(c, S, c.t)


static func braccia(c: Coreo, tt: float, pS: String, bS: Vector3, bF: Vector3) -> void:
	K.braccia(c, tt, pS, bS, bF)
