# Due squadre inventate per provare la partita finché non c'è la carriera (fase 3).
# Stessa forma dei dati di src/career.js (myMatchTeam / aiMatchTeam): {name, short, formation, skill, kit, players}.
# kit = colori 0xRRGGBB come nel web: {shirt, shorts, socks, gk: {shirt, shorts, socks}}.
# Giocatori = {name, num, pos, vel, tir, pas, dri, dif, fis, por, tes}: statistiche ricavate come genPlayer di
# src/career.js da un seme fisso (stesse squadre a ogni avvio), nomi inventati scritti a mano.
extends RefCounted

const C := preload("res://sim/core.gd")
const SimRng := preload("res://sim/rng.gd")

const CASA := {
	"name": "Virtus Borgoalto", "short": "VIR", "formation": "4-4-2", "rating": 64.0, "seed": 4101, "skill": 0.6,
	"kit": {"shirt": 0xc8102e, "shorts": 0xffffff, "socks": 0xc8102e, "gk": {"shirt": 0x27e0c0, "shorts": 0x0c5c52, "socks": 0x27e0c0}},
	"nomi": ["T. Carrara", "L. Ferrante", "M. Bellucci", "D. Sartori", "S. Galvani", "A. Pedretti", "F. Zanella",
		"N. Corradi", "E. Mazzoleni", "R. Tessari", "G. Bonfanti"],
}
const OSPITI := {
	"name": "Aurora Portosole", "short": "AUR", "formation": "4-3-3", "rating": 62.0, "seed": 7307, "skill": -1.0,
	"kit": {"shirt": 0x1746a2, "shorts": 0xffffff, "socks": 0x1746a2, "gk": {"shirt": 0xffa41c, "shorts": 0x222222, "socks": 0xffa41c}},
	"nomi": ["K. Mensah", "P. Valsecchi", "O. Lindqvist", "I. Duarte", "J. Novak", "Y. Moreau", "C. Fumagalli",
		"V. Benali", "M. Okoye", "T. Silva", "E. Ronchi"],
}


## squadra di casa (la persona) e ospite (computer)
static func casa() -> Dictionary:
	return _squadra(CASA)


static func ospiti() -> Dictionary:
	return _squadra(OSPITI)


static func _squadra(d: Dictionary) -> Dictionary:
	var r := SimRng.new(int(d.seed))
	var F: Array = C.FORMATIONS[d.formation]
	var giocatori: Array = []
	for i in F.size():
		var p := _giocatore(r, String(F[i][0]), float(d.rating))
		p["name"] = d.nomi[i]
		p["num"] = i + 1
		giocatori.append(p)
	var skill: float = d.skill
	if skill < 0.0:
		skill = clampf((float(d.rating) - 42.0) / 48.0, 0.1, 0.95) # come skillOf di src/career.js, difficoltà normale
	return {"name": d.name, "short": d.short, "formation": d.formation, "skill": skill, "kit": d.kit.duplicate(true), "players": giocatori}


# statistiche come genPlayer di src/career.js: base attorno a `level`, spostata per ruolo
static func _giocatore(r: SimRng, pos: String, level: float) -> Dictionary:
	var g := (r.next() + r.next() + r.next() - 1.5) * 2.0
	var b := level + g * 3.5
	var v := func(d: float) -> int: return int(roundf(clampf(b + d + (r.next() - 0.5) * 8.0, 18.0, 99.0)))
	var p := {"pos": pos}
	match pos:
		"P":
			p.merge({"por": v.call(5.0), "pas": v.call(-12.0), "fis": v.call(-2.0), "vel": v.call(-12.0), "tir": v.call(-30.0), "dri": v.call(-22.0), "dif": v.call(-22.0)})
		"D":
			p.merge({"dif": v.call(5.0), "fis": v.call(3.0), "vel": v.call(-2.0), "pas": v.call(-6.0), "dri": v.call(-10.0), "tir": v.call(-18.0), "por": 12})
		"C":
			p.merge({"pas": v.call(5.0), "dri": v.call(1.0), "vel": v.call(-2.0), "dif": v.call(-6.0), "tir": v.call(-5.0), "fis": v.call(-2.0), "por": 12})
		_:
			p.merge({"tir": v.call(5.0), "vel": v.call(2.0), "dri": v.call(2.0), "pas": v.call(-6.0), "fis": v.call(-3.0), "dif": v.call(-22.0), "por": 12})
	p["tes"] = int(C.headingOf(p))
	return p
