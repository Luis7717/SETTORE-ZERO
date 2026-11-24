# Calcio d'inizio con l'opzione "rifiniture" (Luis 2026-11-24): nel cerchio di centrocampo (raggio 9,15 m) c'è solo
# il battitore; tutti gli altri, compagni e avversari, fuori dal cerchio e ognuno nella propria metà finché il
# pallone non è calciato. Vale all'inizio, all'inizio del secondo tempo e dopo ogni gol. Senza l'opzione il motore
# resta quello del JS (i confronti di test_equivalence non cambiano).
extends "test_base.gd"

const TOL := 0.05          # margine di misura (m)
const ATTESA_MAX := 16.0   # la squadra umana batte da sola dopo 14 s (match.gd)


# chi sta dove non dovrebbe (fuori dal cerchio e nella propria metà), stringa vuota se tutto a posto
static func fuori_posto(m: SimMatchScript) -> String:
	var tk: R.Player = m.restart.taker
	for p: R.Player in m.players:
		if p.off or p == tk:
			continue
		var d: float = -1.0 if p.team else 1.0
		if C.hyp(p.x, p.y) < C.CIRCLE - TOL:
			return "%s (squadra %d) nel cerchio a %.2f m" % [p.name, p.team, C.hyp(p.x, p.y)]
		if p.y * d > TOL:
			return "%s (squadra %d) nella metà avversaria (y %.2f)" % [p.name, p.team, p.y]
	return ""


# passi finché il calcio d'inizio aspetta; ogni passo controlla le posizioni. dito = la persona tiene il dito sul
# centro del campo (il suo giocatore controllato prova a entrare nel cerchio)
func _attesa(m: SimMatchScript, dito: bool, nome: String) -> int:
	var passi := 0
	var t := 0.0
	var primo := fuori_posto(m)
	check(primo == "", "%s, appena messi in campo: %s" % [nome, primo])
	while m.phase == "restart" and m.restart.type == "kickoff" and t < ATTESA_MAX:
		if dito:
			m.userMove(0, 0.0, 0.0, true)
		m.step(DT)
		t += DT
		passi += 1
		if m.phase != "restart":
			break
		var f := fuori_posto(m)
		if f != "":
			check(false, "%s dopo %.2f s: %s" % [nome, t, f])
			return passi
	check(m.phase == "play", "%s: il calcio d'inizio è stato battuto" % nome)
	return passi


func _partita(sd: int, ko: int, umani: Array, rif := true) -> SimMatchScript:
	return H.newMatch(sd, 9999.0, umani, H.mkTeam("A", 60.0, sd * 7 + 1), H.mkTeam("B", 60.0, sd * 13 + 5), "",
		{"rifiniture": rif, "kickoff": ko})


func test_all_inizio_solo_il_battitore_nel_cerchio() -> bool:
	for sd in 6:
		for ko in 2:
			_attesa(_partita(sd + 1, ko, [false, false]), false, "seme %d, batte %d (CPU)" % [sd + 1, ko])
			_attesa(_partita(sd + 1, ko, [true, false]), false, "seme %d, batte %d (umano)" % [sd + 1, ko])
	return done()


func test_il_dito_non_porta_dentro_il_cerchio() -> bool:
	for sd in 4:
		for ko in 2:
			_attesa(_partita(sd + 1, ko, [true, false]), true, "seme %d, batte %d, dito sul centro" % [sd + 1, ko])
	return done()


# dopo un gol (o col secondo tempo) il calcio d'inizio riparte dal gioco in corso: stessa regola
func test_dopo_un_gol_stessa_regola() -> bool:
	for sd in 5:
		var m := _partita(sd + 11, 0, [true, false])
		for i in 600: # 10 s di gioco
			m.step(DT)
		m.setupKickoff(sd % 2)
		_attesa(m, false, "seme %d, dopo il gol" % [sd + 11])
	return done()


# il battitore c'è, è nel cerchio, e il calcio d'inizio resta giocabile (pallone a un compagno)
func test_il_battitore_resta_al_centro() -> bool:
	var m := _partita(3, 0, [false, false])
	var tk: R.Player = m.restart.taker
	check(tk != null and C.hyp(tk.x, tk.y) < 1.0, "battitore al centro")
	_attesa(m, false, "seme 3")
	check(m.ball.kick != null or m.ball.owner != null, "pallone calciato o già di qualcuno")
	return done()


# senza l'opzione: il compagno del battitore può stare nel cerchio come nel motore JS (niente cambia)
func test_senza_rifiniture_come_prima() -> bool:
	var dentro := 0
	for sd in 6:
		var m := _partita(sd + 1, 0, [false, false], false)
		if fuori_posto(m) != "":
			dentro += 1
	note("partite con qualcuno nel cerchio senza l'opzione: %d su 6" % dentro)
	check(dentro > 0, "senza l'opzione la regola nuova non deve valere")
	return done()
