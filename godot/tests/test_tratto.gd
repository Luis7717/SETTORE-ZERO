# Forma del tratto (Luis 2026-11-22): dritto = rasoterra, curvo = a effetto e alto; potenza giusta per arrivare
# dove finisce la linea; calcio di prima preparato mentre il passaggio viaggia (sim/match.gd: launch, userQueue).
extends "test_base.gd"

var m: SimMatchScript
var c: R.Player
var mate: R.Player


func prepara() -> void:
	m = H.scene(4)
	c = m.team(0)[9]
	mate = m.team(0)[10]
	H.wake(c, 0.0, 0.0)
	c.fx = 0.0
	c.fy = 1.0
	H.give(m, c)
	m.ctrl[0] = c


func volo(spec: Dictionary, sec: float = 4.0) -> Array:
	spec.tratto = true
	return m.predictKick(c, spec, sec)


static func picco(pts: Array) -> float:
	var hm := 0.0
	for q: Dictionary in pts:
		hm = maxf(hm, q.h)
	return hm


## primo punto in cui il pallone, dopo essersi alzato, ritocca terra
static func atterraggio(pts: Array) -> Variant:
	var su := false
	for q: Dictionary in pts:
		if q.h > 0.3:
			su = true
		elif su and q.h == 0.0:
			return q
	return null


## punto del volo più vicino a (x, y): [distanza, indice]
static func piu_vicino(pts: Array, x: float, y: float) -> Array:
	var bd := INF
	var bi := -1
	for i in pts.size():
		var d := C.hyp(pts[i].x - x, pts[i].y - y)
		if d < bd:
			bd = d
			bi = i
	return [bd, bi]


static func velocita(pts: Array, i: int) -> float:
	var a: Dictionary = pts[maxi(0, i - 1)]
	var b: Dictionary = pts[mini(pts.size() - 1, i + 1)]
	return C.hyp(b.x - a.x, b.y - a.y) / maxf(1e-6, b.t - a.t)


func test_soglia_della_curva_tiene_dritti_i_passaggi_corti_storti() -> bool:
	check(not SimMatchScript.curveIsCurved(3.0, 0.9), "3 m storto di 0,9 m = dritto")
	check(not SimMatchScript.curveIsCurved(2.0, -1.0), "2 m storto di 1 m (dall'altro lato) = dritto")
	check(not SimMatchScript.curveIsCurved(20.0, 2.5), "20 m con 2,5 m di pancia = ancora dritto (sotto il 15%)")
	check(SimMatchScript.curveIsCurved(20.0, 4.0), "20 m con 4 m di pancia = curvo")
	check(SimMatchScript.curveIsCurved(8.0, -1.5), "8 m con 1,5 m = curvo")
	near(SimMatchScript.curveK(20.0, 6.0), 1.0, 1e-6, "30% della lunghezza = effetto pieno")
	return done()


func test_passaggio_corto_storto_resta_rasoterra() -> bool:
	prepara()
	var pts := volo({"type": "auto", "tx": 0.5, "ty": 3.0, "curve": 0.9})
	check(picco(pts) < 0.05, "rasoterra (picco %.2f m)" % picco(pts))
	eq(m.launch(c, {"type": "auto", "tx": 0.5, "ty": 3.0, "curve": 0.9, "tratto": true}, false).type, "ground", "tipo rasoterra")
	return done()


func test_passaggio_dritto_rasoterra_arriva_al_compagno() -> bool:
	prepara()
	H.wake(mate, 6.0, 22.0)
	var pts := volo({"type": "auto", "tx": mate.x, "ty": mate.y, "curve": 0.4})
	check(picco(pts) < 0.05, "rasoterra")
	var pv := piu_vicino(pts, mate.x, mate.y)
	check(pv[0] < 0.3, "passa dal punto dove finisce la linea (%.2f m)" % pv[0])
	var v := velocita(pts, pv[1])
	check(v > 2.0 and v < SimMatchScript.GROUND_ARRIVE + 1.5, "arriva al compagno piano ma ci arriva (%.1f m/s)" % v)
	return done()


func test_passaggio_dritto_lungo_resta_rasoterra() -> bool:
	prepara()
	H.wake(mate, 0.0, 38.0)
	var pts := volo({"type": "auto", "tx": mate.x, "ty": mate.y, "curve": 0.0})
	check(picco(pts) < 0.05, "anche oltre 30 m il tratto dritto è rasoterra")
	check(piu_vicino(pts, mate.x, mate.y)[0] < 0.3, "e arriva fin lì")
	return done()


func test_passaggio_dritto_nello_spazio_si_ferma_dove_finisce_la_linea() -> bool:
	prepara()
	var pts := volo({"type": "auto", "tx": -8.0, "ty": 14.0, "curve": 0.0})
	var fine: Dictionary = pts[-1]
	check(C.hyp(fine.x + 8.0, fine.y - 14.0) < 1.3, "si ferma vicino alla fine della linea (%.2f m)" % C.hyp(fine.x + 8.0, fine.y - 14.0))
	return done()


func test_passaggio_curvo_si_alza_gira_dal_lato_della_curva_e_atterra_li() -> bool:
	prepara()
	H.wake(mate, 0.0, 20.0)
	for lato: float in [1.0, -1.0]:
		var pts := volo({"type": "auto", "tx": 0.0, "ty": 20.0, "curve": 5.0 * lato})
		check(picco(pts) > 2.2, "si alza sopra chi sta in mezzo (picco %.2f m)" % picco(pts))
		var a: Variant = atterraggio(pts)
		check(a != null and C.hyp(a.x, a.y - 20.0) < 0.8, "atterra dove finisce la linea")
		# a metà strada il pallone sta dal lato della curva disegnata (normale a sinistra della corda = x negativa)
		var meta := piu_vicino(pts, -5.0 * lato, 10.0)
		var q: Dictionary = pts[meta[1]]
		check(signf(-q.x) == lato and absf(q.x) > 2.5, "segue la curva (x a metà = %.2f)" % q.x)
	return done()


func test_curva_piu_forte_va_piu_alta() -> bool:
	prepara()
	var poca := picco(volo({"type": "auto", "tx": 0.0, "ty": 20.0, "curve": 3.2}))
	var tanta := picco(volo({"type": "auto", "tx": 0.0, "ty": 20.0, "curve": 6.0}))
	check(tanta > poca + 0.5, "più curva = più alta (%.2f contro %.2f m)" % [tanta, poca])
	return done()


func test_tiro_dritto_rasoterra_entra_dove_finisce_la_linea() -> bool:
	prepara()
	H.wake(c, 4.0, 28.0)
	H.give(m, c)
	var pts := volo({"type": "shot", "tx": -2.5, "ty": C.HL, "th": 1.6, "curve": 0.3}, 2.0)
	check(picco(pts) < 0.05, "tiro dritto = rasoterra anche mirando in alto")
	var i := piu_vicino(pts, -2.5, C.HL)
	check(i[0] < 0.4, "arriva alla porta nel punto mirato (%.2f m)" % i[0])
	check(velocita(pts, i[1]) > 20.0, "forte")
	return done()


func test_tiro_curvo_a_giro_si_alza_e_entra_all_altezza_mirata() -> bool:
	prepara()
	H.wake(c, 4.0, 28.0)
	H.give(m, c)
	var pts := volo({"type": "shot", "tx": -2.5, "ty": C.HL, "th": 1.2, "curve": 4.0}, 2.0)
	check(picco(pts) > SimMatchScript.CURL_APEX_MIN - 0.2, "si alza (picco %.2f m)" % picco(pts))
	var i := piu_vicino(pts, -2.5, C.HL)
	check(i[0] < 0.5, "entra nel punto mirato (%.2f m)" % i[0])
	near(pts[i[1]].h, 1.2, 0.4, "all'altezza mirata")
	# corda dal pallone (4, 28.6) a (−2.5, 50): con curve > 0 il pallone sta alla sinistra della corda
	var q: Dictionary = pts[int(i[1] / 2.0)]
	var dx := -2.5 - 4.0
	var dy := C.HL - 28.6
	var lato: float = (q.x - 4.0) * (-dy) + (q.y - 28.6) * dx
	check(lato > 0.0, "gira dal lato della curva")
	return done()


func test_senza_tratto_l_ia_resta_come_prima() -> bool:
	prepara()
	var L := m.launch(c, {"type": "auto", "tx": 0.0, "ty": 38.0, "curve": 0.0}, false)
	eq(L.type, "loft", "l'IA (senza tratto) oltre 30 m alza ancora la palla")
	return done()


func test_di_prima_meno_preciso() -> bool:
	prepara()
	var spec := {"type": "ground", "tx": 0.0, "ty": 20.0, "human": true}
	var prima := spec.duplicate()
	prima.first = true
	var s0 := 0.0
	var s1 := 0.0
	for i in 400:
		var a := m.launch(c, spec, true)
		var b := m.launch(c, prima, true)
		s0 += pow(atan2(a.vx, a.vy), 2.0)
		s1 += pow(atan2(b.vx, b.vy), 2.0)
	check(s1 > s0 * 1.2, "di prima l'errore di direzione cresce (%.5f contro %.5f)" % [s1, s0])
	return done()


func test_di_prima_parte_appena_il_compagno_tocca_il_pallone() -> bool:
	prepara()
	H.wake(mate, 0.0, 16.0)
	m.userKick(0, {"type": "ground", "tx": mate.x, "ty": mate.y})
	m.step(DT)
	check(m.userQueue(0, mate, {"type": "auto", "tx": 10.0, "ty": 30.0, "curve": 0.0, "tratto": true}), "calcio in attesa accettato")
	var kick: Variant = null
	for i in 240:
		m.step(DT)
		for e: Dictionary in m.events:
			if e.type == "kick" and e.p == mate:
				kick = e
		m.events.clear()
		if kick != null:
			break
	check(kick != null and kick.prima, "il compagno calcia di prima")
	check(m.queued[0] == null, "niente più in attesa")
	check(m.ball.owner == null, "senza fermare il pallone")
	return done()


func test_di_prima_rifiutato_senza_passaggio_in_volo() -> bool:
	prepara()
	check(not m.userQueue(0, mate, {"type": "auto", "tx": 10.0, "ty": 30.0}), "pallone tenuto: niente di prima")
	m.userKick(0, {"type": "shot", "tx": 0.0, "ty": C.HL, "th": 1.0})
	check(not m.userQueue(0, mate, {"type": "auto", "tx": 10.0, "ty": 30.0}), "tiro in volo: niente di prima")
	return done()


func test_di_prima_annullato_se_il_volo_cambia() -> bool:
	prepara()
	H.wake(mate, 0.0, 16.0)
	m.userKick(0, {"type": "ground", "tx": mate.x, "ty": mate.y})
	m.step(DT)
	m.userQueue(0, mate, {"type": "auto", "tx": 10.0, "ty": 30.0})
	m.ball.kick = null # deviazione (come in contacts)
	m.step(DT)
	check(m.queued[0] == null, "volo cambiato: calcio di prima annullato")
	return done()
