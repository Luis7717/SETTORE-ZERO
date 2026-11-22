# Menu: disegni e dati uguali al web (valori presi da src/ con godot/tools/dati_menu_web.mjs →
# tests/fixtures/menu_ui.json). Visi e stemmi: lo stesso testo SVG di faceSvg / crestSvg; aspetti e stemmi dal seme
# (hash32, seeded, lookFromSeed, crestFromSeed, lookOf): stessi numeri.
extends "test_base.gd"

const D := preload("res://scripts/menu/menu_dati.gd")
const Faccia := preload("res://scripts/menu/faccia.gd")
const Stemma := preload("res://scripts/menu/stemma.gd")

static var _fx: Dictionary = {}


static func fx() -> Dictionary:
	if _fx.is_empty():
		_fx = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/menu_ui.json"))
	return _fx


# i numeri del JSON arrivano come float: interi per confrontarli coi Dictionary di Godot
static func interi(d: Dictionary) -> Dictionary:
	var out := {}
	for k: String in d:
		out[k] = int(d[k])
	return out


func test_visi_uguali_al_web() -> bool:
	var n := 0
	for f: Dictionary in fx().faces:
		var mio := Faccia.svg(interi(f.look), f.shirt, f.collar, true)
		if eq(mio, f.svg, "viso %d" % n):
			n += 1
	note("%d visi identici" % n)
	return done()


func test_stemmi_uguali_al_web() -> bool:
	var n := 0
	for c: Dictionary in fx().crests:
		var mio := Stemma.svg(interi(c.c), int(c.c1), int(c.c2), true, "x", "ID")
		if eq(mio, c.svg, "stemma %d" % n):
			n += 1
	note("%d stemmi identici" % n)
	return done()


func test_aspetto_e_stemma_dal_seme_come_il_web() -> bool:
	for s: Dictionary in fx().seeds:
		eq(D.crest_from_seed(int(s.seed)), interi(s.crest), "crestFromSeed(%d)" % int(s.seed))
		eq(D.look_from_seed(int(s.seed)), interi(s.look), "lookFromSeed(%d)" % int(s.seed))
	for p: Dictionary in fx().players:
		var pl := {"id": int(p.p.id), "name": p.p.name}
		eq(D.look_of(pl), interi(p.look), "lookOf(%s)" % str(pl))
	return done()


func test_svg_di_godot_si_disegna() -> bool:
	var img := Image.new()
	check(img.load_svg_from_string(Stemma.svg({"shape": 9, "pattern": 5, "icon": 2}, 0xf2c200, 0x1b1b1b), 2.0) == OK, "stemma")
	eq(img.get_size(), Vector2i(80, 96), "misura dello stemma a 2x")
	# centro dello stemma Tondo tinta unita rossa = rosso; angolo fuori dalla sagoma = trasparente
	check(img.load_svg_from_string(Stemma.svg({"shape": 1, "pattern": 0, "icon": 6}, 0xc8102e, 0xffffff), 2.0) == OK, "tondo")
	check(img.get_pixel(2, 2).a < 0.05, "fuori dalla sagoma è trasparente")
	var c := img.get_pixel(40, 20)
	check(c.r > 0.6 and c.g < 0.2, "fondo rosso: %s" % c)
	var v := Image.new()
	check(v.load_svg_from_string(Faccia.svg_tondo(D.LOOK_DEFAULT, "#c8102e", "#ffffff", "#2f3a5c"), 3.0) == OK, "viso")
	eq(v.get_size(), Vector2i(120, 120), "misura del viso a 3x")
	check(v.get_pixel(1, 1).a < 0.05, "angolo fuori dal tondo trasparente")
	return done()


func test_soldi_valutazioni_e_fasce() -> bool:
	eq(D.fmt_money(250), "250 k€", "k€")
	eq(D.fmt_money(1234), "1,23 M€", "M€")
	eq(D.fmt_money(-1500), "-1,50 M€", "negativo")
	eq(D.ovr_cls(75), "o4", "o4")
	eq(D.ovr_cls(65), "o3", "o3")
	eq(D.ovr_cls(55), "o2", "o2")
	eq(D.ovr_cls(54), "o1", "o1")
	var p := {"pos": "A", "tir": 70, "vel": 60, "dri": 65, "pas": 50, "fis": 55, "dif": 30, "por": 12, "age": 22}
	eq(D.overall(p), 64, "overall attaccante")
	eq(D.overall_as(p, "D"), 37, "fuori ruolo D")     # valori calcolati con src/career.js
	eq(D.overall_as(p, "P"), 13, "in porta")
	eq(D.value(p), 165, "valore")
	return done()


# avatar tondo coi colori nuovi (2026-11-22): barba del suo colore, occhi particolari ed eterocromia, punte sfumate
func test_avatar_coi_colori_nuovi() -> bool:
	var look := {"skin": 1, "hair": 4, "hairColor": 19, "eyeColor": 10, "beard": 6, "beardColor": 6}
	var s := Faccia.svg_tondo(look, "#c8102e", "#ffffff", "#2f3a5c")
	check(s.contains(str(D.BEARD_COLORS[6][1])), "barba bianca")
	check(s.contains(str(D.EYE_COLORS[10][1])) and s.contains(str(D.EYE_COLORS[10][2])), "eterocromia: due colori")
	check(s.contains("url(#pu)"), "punte sfumate")
	var v := Image.new()
	check(v.load_svg_from_string(s, 3.0) == OK, "l'SVG si disegna")
	check(not Faccia.svg_tondo({"beard": 6}, "#c8102e", "#ffffff", "#2f3a5c").contains("url(#pu)"), "senza sfumato: niente punte")
	return done()
