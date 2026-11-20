# Carriera finta per provare i menu senza la carriera vera (scripts/carriera/carriera.gd, altro lavoro):
# stessi nomi di metodi e campi di src/career.js (stato in `s`), dati presi da una carriera vera del web
# (tests/fixtures/carriera_menu.json, fatta da godot/tools/dati_menu_web.mjs: "Atletico Sole", 3 giornate giocate).
# Solo per le prove: non salva niente.
extends RefCounted

const D := preload("res://scripts/menu/menu_dati.gd")
const Rosa := preload("res://scripts/menu/rosa_logica.gd")
const C := preload("res://sim/core.gd")
const FIXTURE := "res://tests/fixtures/carriera_menu.json"

var s: Variant = null
var ultimo_risultato: Dictionary = {}
var salvataggi := 0


func _init(carica := true) -> void:
	if carica:
		self.load()


func load() -> bool:
	var dati: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not (dati is Dictionary):
		return false
	dati = interi(dati)
	s = dati.s
	ultimo_risultato = dati.lastRes
	return true


## i numeri interi del JSON (float in Godot) tornano interi: id, statistiche, soldi
static func interi(v: Variant) -> Variant:
	if v is Dictionary:
		var out := {}
		for k: Variant in v:
			out[k] = interi(v[k])
		return out
	if v is Array:
		return (v as Array).map(func(x: Variant) -> Variant: return interi(x))
	if typeof(v) == TYPE_FLOAT and is_equal_approx(v, roundf(v)) and absf(v) < 1e12:
		return int(v)
	return v


func save() -> void:
	salvataggi += 1


func reset() -> void:
	s = null


func create(name: String, kit: int) -> void:
	self.load()
	s.club = name
	s.kit = kit
	s.teams.me.name = name
	s.teams.me.kit = kit
	s.money = 250
	s.day = 0
	s.res = []
	s.last = null


func div() -> int:
	for d in s.divs.size():
		if s.divs[d].has("me"):
			return d
	return 2


func team(id: Variant) -> Variant:
	return s.teams.get(id)


func player(id: Variant) -> Variant:
	for p: Dictionary in s.squad:
		if p.id == id:
			return p
	return null


func table(d: int) -> Array:
	var rows: Array = []
	for id: String in s.divs[d]:
		var r: Dictionary = s.tab[id].duplicate()
		r.id = id
		rows.append(r)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.pts != b.pts:
			return a.pts > b.pts
		if a.gf - a.ga != b.gf - b.ga:
			return a.gf - a.ga > b.gf - b.ga
		if a.gf != b.gf:
			return a.gf > b.gf
		return a.id < b.id)
	return rows


func myRating() -> int:
	var F: Array = C.FORMATIONS[s.formation]
	var t := 0
	for i in s.lineup.size():
		var p: Variant = player(s.lineup[i])
		t += D.overall_as(p, F[i][0]) if p != null else 30
	return D._round_js(t / 11.0)


func nextMatch() -> Variant:
	var d := div()
	if s.day >= 18:
		return null
	for m: Array in s.fix[d][s.day]:
		if m[0] == "me" or m[1] == "me":
			var home: bool = m[0] == "me"
			return {"home": home, "opp": team(m[1] if home else m[0]), "day": s.day + 1, "div": d}
	return null


func autoLineup() -> void:
	var F: Array = C.FORMATIONS[s.formation]
	var order: Array = range(F.size())
	order.sort_custom(func(a: int, b: int) -> bool: return "PADC".find(F[a][0]) < "PADC".find(F[b][0]))
	var used := {}
	var l: Array = []
	l.resize(F.size())
	for i: int in order:
		var best: Variant = null
		var bo := -1
		for p: Dictionary in s.squad:
			if not used.has(p.id):
				var o := D.overall_as(p, F[i][0])
				if o > bo:
					bo = o
					best = p
		l[i] = best.id
		used[best.id] = true
	s.lineup = l


func fixLineup() -> void:
	var ids := {}
	for p: Dictionary in s.squad:
		ids[p.id] = true
	var used := {}
	var l: Array = []
	for id: Variant in s.lineup:
		if ids.has(id) and not used.has(id):
			used[id] = true
			l.append(id)
		else:
			l.append(null)
	var F: Array = C.FORMATIONS[s.formation]
	for i in l.size():
		if l[i] != null:
			continue
		var best: Variant = null
		var bo := -1
		for p: Dictionary in s.squad:
			if not used.has(p.id):
				var o := D.overall_as(p, F[i][0])
				if o > bo:
					bo = o
					best = p
		if best != null:
			l[i] = best.id
			used[best.id] = true
	s.lineup = l


func bench() -> Array:
	return s.squad.filter(func(p: Dictionary) -> bool: return not s.lineup.has(p.id))


func swap(a: Variant, b: Variant) -> void:
	if not Rosa.can_swap(s.lineup, a, b):
		return
	s.lineup = Rosa.swap_lineup(s.lineup, a, b)
	save()


func sellPrice(p: Dictionary) -> int:
	return D._round_js(D.value(p) * 0.8)


func sell(id: Variant) -> Variant:
	var p: Variant = player(id)
	if p == null:
		return "Giocatore non trovato"
	if s.squad.size() <= 14:
		return "Servono almeno 14 giocatori in rosa"
	if p.pos == "P" and s.squad.filter(func(q: Dictionary) -> bool: return q.pos == "P").size() <= 1:
		return "Serve almeno un portiere"
	s.money += sellPrice(p)
	s.squad = s.squad.filter(func(q: Dictionary) -> bool: return q.id != id)
	fixLineup()
	save()
	return null


func buy(id: Variant) -> Variant:
	var i := -1
	for k in s.market.size():
		if s.market[k].id == id:
			i = k
	if i < 0:
		return "Giocatore non più disponibile"
	var p: Dictionary = s.market[i]
	if s.squad.size() >= 24:
		return "Rosa al completo (massimo 24)"
	if s.money < p.price:
		return "Soldi insufficienti"
	s.money -= p.price
	s.market.remove_at(i)
	p.erase("price")
	s.squad.append(p)
	save()
	return null


func crest() -> Dictionary:
	return D.normalize_crest(s.get("crest"), D.crest_from_seed(D.hash32(["club", s.club])))


func setCrest(c: Dictionary) -> void:
	s.crest = D.normalize_crest(c)
	save()


func teamCrest(t: Variant) -> Dictionary:
	if t == null or t.id == "me":
		return crest()
	var seed_value: int = t.seed if t.has("seed") else D.hash32([t.id, t.name])
	return D.normalize_crest(t.get("crest"), D.crest_from_seed(seed_value))


func kitStyle() -> Dictionary:
	return D.normalize_kit_style(s.get("kitStyle"))


func setKitStyle(st: Dictionary) -> void:
	s.kitStyle = D.normalize_kit_style(st)
	save()


func setLook(id: Variant, look: Dictionary) -> bool:
	var p: Variant = player(id)
	if p == null:
		return false
	p.look = D.normalize_look(look)
	save()
	return true


func addChampion(d: Dictionary) -> Dictionary:
	var p := {"id": s.nextId, "name": str(d.get("name", "Campione")), "pos": d.get("pos", "A"), "age": 18, "goals": 0, "assists": 0, "apps": 0,
		"vel": 66, "fis": 60, "tir": 68, "pas": 60, "dri": 66, "dif": 40, "por": 12, "look": D.normalize_look(d.get("look")), "champ": true, "num": d.get("num", 9)}
	s.nextId += 1
	s.squad.push_front(p)
	autoLineup()
	save()
	return p
