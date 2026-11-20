# Rete a molle (scripts/rete_molle.gd): il pallone in fondo alla porta gonfia il telo attorno a sé (non oltre il
# massimo), il bordo resta fermo, uscito il pallone la rete ondeggia e torna a dormire.
extends "test_base.gd"

const ReteMolle := preload("res://scripts/rete_molle.gd")
const Coord := preload("res://scripts/coord.gd")
const R_PALLA := 0.21


# pallone oltre il fondo della rete (come il motore dopo il gol: 1,9 m dietro la linea), a mezza altezza
func palla_in_fondo(lato: float) -> Vector3:
	return Vector3(1.0, lato * (Coord.HL + 1.9), 0.5)


func test_il_pallone_gonfia_il_fondo_attorno_a_se() -> bool:
	var r := ReteMolle.new(1.0)
	for i in 30:
		r.passo(1.0 / 60.0, palla_in_fondo(1.0), R_PALLA, 20.0 if i == 0 else 2.0, true)
	var g := r.gonfiore()
	check(g > 0.25, "il telo si gonfia (%.3f m)" % g)
	var dav := r.gonfiore_in(palla_in_fondo(1.0))
	check(dav > 0.2 and dav <= g + 1e-4, "davanti al pallone il telo è gonfio (%.3f m)" % dav)
	check(g <= ReteMolle.GONFIA_MAX + 0.05, "non oltre il massimo (%.3f m)" % g)
	# vicino al pallone (x = 1, in basso) più che lontano (angolo opposto)
	var t: Dictionary = r.telo("fondo")
	var u_palla := (1.0 - (t.a as Vector3).x) / ((t.b as Vector3).x - (t.a as Vector3).x)
	var vicino := r.spostamento("fondo", u_palla, 0.2)
	var lontano := r.spostamento("fondo", 0.1, 0.8)
	check(vicino > lontano + 0.2, "più gonfio dove sta il pallone (%.3f contro %.3f)" % [vicino, lontano])
	eq(r.spostamento("fondo", 0.0, 0.5), 0.0, "il bordo attaccato al palo resta fermo")
	eq(r.spostamento("fondo", 0.5, 0.0), 0.0, "il bordo a terra resta fermo")
	return done()


func test_uscito_il_pallone_torna_ferma_e_dorme() -> bool:
	var r := ReteMolle.new(-1.0)
	for i in 30:
		r.passo(1.0 / 60.0, palla_in_fondo(-1.0), R_PALLA, 15.0, true)
	check(r.gonfiore() > 0.2, "porta dall'altra parte: si gonfia anche lei")
	var mosso_dopo := 0.0
	for i in 600:   # 10 s senza pallone
		r.passo(1.0 / 60.0, Vector3(0, 0, 0), R_PALLA, 0.0, false)
		if i == 20:
			mosso_dopo = r.gonfiore()
	check(mosso_dopo > 0.0, "subito dopo ondeggia ancora")
	check(r.dorme, "dopo qualche secondo dorme")
	eq(r.gonfiore(), 0.0, "e torna alla forma di riposo")
	return done()


func test_pallone_in_campo_non_tocca_la_rete() -> bool:
	var r := ReteMolle.new(1.0)
	check(not r.passo(1.0 / 60.0, Vector3(0, 40, 0.2), R_PALLA, 10.0, false), "pallone lontano: niente conti")
	check(r.dorme, "la rete dorme")
	# pallone appena dentro la linea di porta, lontano dal fondo: non spinge
	r.passo(1.0 / 60.0, Vector3(0, Coord.HL + 0.3, 0.2), R_PALLA, 10.0, true)
	check(r.gonfiore() < 1e-3, "sulla linea non spinge il fondo (%.4f)" % r.gonfiore())
	return done()


func test_uv2_al_centro_dei_nodi() -> bool:
	var r := ReteMolle.new(1.0)
	var a := r.uv2("fondo", 0.0, 0.0)
	eq(a, Vector2(0.5 / r.larghezza, 0.5 / r.altezza), "primo nodo del fondo")
	var t: Dictionary = r.telo("tetto")
	var b := r.uv2("tetto", 1.0, 1.0)
	eq(b, Vector2((t.off + t.nu - 1 + 0.5) / r.larghezza, (t.nv - 1 + 0.5) / r.altezza), "ultimo nodo del tetto")
	return done()
