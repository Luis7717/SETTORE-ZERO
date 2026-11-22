# Diagnosi dei colpi di testa (non è un test: il runner lo ignora).
# Uso:  godot --headless --path godot -s res://tests/diag_testa.gd [-- semi durata modo]
#   semi = quante partite (predefinito 10), durata = secondi per tempo (150), modo = bot | ai (bot = umano simulato),
#   testa = 1 per il colpo di testa controllato (la persona simulata disegna la linea verso la porta),
#   cross = 1 se la persona simulata, col pallone sulla fascia vicino alla porta, disegna un cross a un compagno in area.
# Conta per squadra: lanci alti, lanci alti arrivati in zona di colpo di testa, colpi di testa verso la porta, al volo,
# respinte di testa, contrasti aerei, gol di testa e (per l'umano) fermatempo "di testa" aperti e colpi diretti col dito.
extends SceneTree

const H := preload("harness.gd")
const C := preload("../sim/core.gd")
const TT := preload("test_testa.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var semi: int = int(args[0]) if args.size() > 0 else 10
	var durata: float = float(args[1]) if args.size() > 1 else 150.0
	var modo: String = args[2] if args.size() > 2 else "bot"
	var testa: bool = args.size() > 3 and args[3] == "1"
	var cross: bool = args.size() > 4 and args[4] != "0"
	_curva = float(args[5]) if args.size() > 5 else 0.0
	var esiti := {}
	var tot := {}
	for k in ["loft", "lofti", "header", "volley", "clear", "aerial", "golTesta", "gol", "fermi", "diretti"]:
		tot[k] = [0, 0]
	for sd in range(1, semi + 1):
		var ultimo := {"k": "", "t": -1, "tocco": ""}
		var crossato := {"p": null, "cross": false}
		var conta := func(m: SimMatch) -> void:
			if cross:
				_cross(m, crossato)
			if crossato.cross and not m.events.is_empty():
				# primo tocco dopo il cross: chi e a che altezza (portiere, difensore, compagno), o fuori
				for e: Dictionary in m.events:
					if e.type == "kick" and e.p.team == 0 and e.kind == "loft" and m.ball.kick != null and m.ball.kick.kicker == e.p:
						continue
					var chi := ""
					if e.type in ["control", "punch", "save", "aerial", "head_win"] and e.has("p"):
						chi = e.type + ":" + ("portiere" if e.p.pos == "P" else ("compagno" if e.p.team == 0 else "difensore"))
					elif e.type == "kick" and e.has("p"):
						chi = "kick-" + String(e.kind) + ":" + ("portiere" if e.p.pos == "P" else ("compagno" if e.p.team == 0 else "difensore"))
					elif e.type == "out":
						chi = "fuori-" + String(e.kind)
					if chi != "":
						var key: String = "cross>" + chi + (" h%.0f" % m.ball.h if e.type != "out" else "")
						esiti[key] = esiti.get(key, 0) + 1
						crossato.cross = false
						break
			for e: Dictionary in m.events:
				match e.type:
					"kick":
						var p: Object = e.p
						var k: String = e.kind
						if k == "loft":
							tot.loft[p.team] += 1
						elif k == "header":
							tot["clear" if e.get("clear", false) else "header"][p.team] += 1
						elif k == "volley":
							tot.volley[p.team] += 1
						ultimo.k = k if not e.get("clear", false) else "clear"
						ultimo.t = p.team
						if e.get("guidato", false):
							tot.diretti[p.team] += 1
					"aerial":
						tot.aerial[e.p.team] += 1
					"head_win":
						tot.fermi[e.team] += 1
					"head_aim":
						esiti["linea"] = esiti.get("linea", 0) + 1
					"head_end":
						var key: String = String(e.reason) + (":" + String(ultimo.tocco) if e.reason == "toccato" else "")
						esiti[key] = esiti.get(key, 0) + 1
					"goal":
						tot.gol[e.team] += 1
						if ultimo.k == "header" and ultimo.t == e.team:
							tot.golTesta[e.team] += 1
				if e.type in ["control", "punch", "save", "block", "tackle", "kick", "aerial"] and e.has("p"):
					ultimo.tocco = ("portiere" if e.p.pos == "P" else ("compagno" if e.p.team == 0 else "difensore")) + "-" + e.type + String(e.get("kind", ""))
				elif e.type == "out" or e.type == "restart":
					ultimo.tocco = "fuori/" + String(e.get("kind", ""))
			# lancio alto di una squadra che scende in zona di colpo di testa vicino alla porta avversaria
			var b = m.ball
			if b.kick != null and b.kick.type == "loft" and not b.kick.get_meta("contato", false) and b.owner == null:
				var dir := -1.0 if b.kick.team else 1.0
				if b.vh < 0.0 and b.h < 2.6 and b.h > 1.3 and C.hyp(b.x, b.y - dir * C.HL) < 17.0:
					b.kick.set_meta("contato", true)
					tot.lofti[b.kick.team] += 1
		var res := H.playMatch({"seed": sd, "mode": modo, "halfLen": durata, "testa": testa}, conta)
		res.m.dispose()
	print("partite %d × 2 × %.0f s, modo %s, testa %s, cross %s" % [semi, durata, modo, testa, cross])
	print("  esiti dei fermatempi: %s" % str(esiti))
	for k: String in tot:
		print("  %-9s squadra0 %4d   squadra1 %4d" % [k, tot[k][0], tot[k][1]])
	quit()


# persona simulata che crossa: portatore della squadra 0 sulla fascia negli ultimi 28 m, compagno in area = linea a lui
static var _curva := 0.0


static func _cross(m: SimMatch, fatto: Dictionary) -> void:
	var c = m.ctrl[0]
	var b = m.ball
	if fatto.p != null and b.owner != null and b.owner != fatto.p:
		fatto.p = null # nuovo possesso: si può crossare di nuovo
	if c == null or b.owner != c or m.phase != "play" or fatto.p == c:
		return
	if absf(c.x) < 14.0 or c.y < C.HL - 28.0:
		return
	var q = TT._bersaglio(m, c)
	if q == null:
		return
	fatto.p = c
	var tx: float = q.x + q.vx * 0.6
	var ty: float = q.y + q.vy * 0.6
	if _curva == 0.0:
		m.userKick(0, {"type": "auto", "tx": tx, "ty": ty})
	else: # tratto curvo (a effetto e alto): curvatura di _curva metri, come test_testa.gd
		m.userKick(0, {"type": "auto", "tx": tx, "ty": ty, "curve": _curva * signf(c.x), "tratto": true})
	fatto.cross = true
