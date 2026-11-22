# Carriera (scripts/carriera/*, porting di src/career.js, looks.js, crest.js): confronto col JS a parità di seme.
# I riferimenti sono in tests/fixtures/carriera.json, scritto da `node test/export-carriera.mjs`
# (da rilanciare quando cambia la carriera JS). Uno scenario con risultati a caso (simScore), operazioni di mercato,
# rosa, stile, stemma e campione; uno con tre stagioni tutte vinte (promozioni fino al titolo).
extends "test_base.gd"

const JS := preload("res://scripts/carriera/js.gd")
const Asp := preload("res://scripts/carriera/aspetto.gd")
const Stemma := preload("res://scripts/carriera/stemma_dati.gd")
const CarrieraScript := preload("res://scripts/carriera/carriera.gd")
const FIX := "res://tests/fixtures/carriera.json"
const FILE_PROVA := "user://prove_carriera/fixture.json"

var _ref: Variant = null


func _fixture() -> Dictionary:
	if _ref == null:
		var f := FileAccess.open(FIX, FileAccess.READ)
		_ref = JSON.parse_string(f.get_as_text()) if f != null else {}
	return _ref


## stesso valore del JS (numeri: 1 e 1.0 uguali); al primo errore scrive il percorso della differenza
func same(got: Variant, want: Variant, msg: String) -> bool:
	var d := JS.diff(senza_campi_godot(got), want, msg)
	return check(d == "", d)


## toglie (in copia) il colore della barba dei look, campo solo di Godot (2026-11-22) che il web non ha
static func senza_campi_godot(v: Variant) -> Variant:
	if v is Dictionary:
		var o := {}
		for k: Variant in v:
			if k != "beardColor":
				o[k] = senza_campi_godot(v[k])
		return o
	if v is Array:
		return (v as Array).map(func(x: Variant) -> Variant: return senza_campi_godot(x))
	return v


## stato della carriera senza quello che il web non ha: impostazioni music e vibra, chiavi della fase B
## (CHIAVI_GODOT: forma, infortuni, obiettivo, rivale, ...)
static func come_web(s: Dictionary) -> Dictionary:
	var c: Dictionary = s.duplicate(true)
	c.settings.erase("music")
	c.settings.erase("vibra")
	for k: String in CarrieraScript.CHIAVI_GODOT:
		c.erase(k)
	return c


func test_pezzi_come_il_js() -> bool:
	var P: Dictionary = _fixture().get("pieces", {})
	if not check(not P.is_empty(), "manca fixtures/carriera.json: node test/export-carriera.mjs"):
		return done()
	for x: Dictionary in P.players:
		var a: Array = x.args
		var r := JS.rng32(int(a[0]))
		var p := CarrieraScript.genPlayer(r, a[1], float(a[2]), int(a[3]), a[4])
		same(p, x.p, "genPlayer %s" % str(a))
		same(r.call(), x.next, "numeri usati da genPlayer %s" % str(a))
		same(CarrieraScript.overall(p), x.overall, "overall")
		same(CarrieraScript.value(p), x.value, "value")
		same(["P", "D", "C", "A"].map(func(q: String) -> int: return CarrieraScript.overallAs(p, q)), x.as, "overallAs")
	var rn := JS.rng32(17)
	same(range(5).map(func(_i: int) -> String: return CarrieraScript.randomName(rn)), P.names, "randomName")
	for m: Array in P.money:
		same(CarrieraScript.fmtMoney(m[0]), m[1], "fmtMoney(%s)" % m[0])
	for h: Array in P.hash32:
		same(Callable(Asp, "hash32").callv(h[0]), h[1], "hash32%s" % str(h[0]))
	for l: Array in P.looks:
		same(Asp.lookFromSeed(l[0]), l[1], "lookFromSeed(%s)" % l[0])
	for l: Array in P.lookOf:
		same(Asp.lookOf(JS.int_numbers(l[0])), l[1], "lookOf(%s)" % str(l[0]))
	for k: Array in P.kitStyles:
		same(Asp.kitStyleFromSeed(k[0]), k[1], "kitStyleFromSeed(%s)" % k[0])
	for k: Array in P.crests:
		same(Stemma.crestFromSeed(k[0]), k[1], "crestFromSeed(%s)" % k[0])
	for n: Array in P.normLook:
		same(Asp.normalizeLook(n[0]), n[1], "normalizeLook")
	for n: Array in P.normKit:
		same(Asp.normalizeKitStyle(n[0]), n[1], "normalizeKitStyle")
	for n: Array in P.normCrest:
		same(Stemma.normalizeCrest(n[0]), n[1], "normalizeCrest")
	for cc: Array in P.crestColors:
		same(Stemma.crestColors(int(cc[0]), int(cc[1])), cc[2], "crestColors")
	var squad: Array = JS.int_numbers([{"id": 1, "pos": "P"}, {"id": 2, "pos": "P", "num": 1}, {"id": 3, "pos": "D", "num": 4}, {"id": 4, "pos": "D", "num": 4}, {"id": 5, "pos": "A", "num": 0}, {"id": 6, "pos": "A"}, {"id": 7, "pos": "C", "num": 99}, {"id": 8, "pos": "X"}])
	var nums := Asp.squadNumbers(squad)
	same(nums.keys().map(func(k: int) -> Array: return [k, nums[k]]), P.squadNumbers, "squadNumbers")
	for b: Array in P.backName:
		same(Asp.backName(b[0]), b[1], "backName")
	return done()


func test_ordinamento_di_v8_col_confronto_a_caso() -> bool:
	for x: Dictionary in _fixture().get("pieces", {}).get("sort", []):
		var r := JS.rng32(int(x.seed))
		var calls := [0]
		var a: Array = JS.v8_sort(range(int(x.n)), func(_a: Variant, _b: Variant) -> float:
			calls[0] += 1
			return r.call() - 0.5)
		same(a, x.out, "sort seme %d n %d" % [x.seed, x.n])
		same(calls[0], x.calls, "chiamate del confronto, seme %d" % x.seed)
	return done()


func test_scenario_con_mercato_e_risultati_a_caso_come_il_js() -> bool:
	return _scenario(0)


func test_tre_stagioni_vinte_promozioni_e_titolo_come_il_js() -> bool:
	return _scenario(1)


func _scenario(idx: int) -> bool:
	var scs: Array = _fixture().get("scenarios", [])
	if not check(scs.size() > idx, "manca lo scenario %d in fixtures/carriera.json" % idx):
		return done()
	var sc: Dictionary = scs[idx]
	var c := CarrieraScript.new()
	c.percorso = FILE_PROVA
	c.create(sc.name, int(sc.kit), int(sc.seed))
	if not same(come_web(c.s), sc.created, "create"):
		return done()
	if not sc.ops.is_empty():
		_operazioni(c, sc)
		if not same(come_web(c.s), sc.snapshots.afterOps, "dopo le operazioni"):
			return done()
	for i in sc.days.size():
		var want: Dictionary = sc.days[i]
		if idx == 0 and i == 10:
			c.s.settings.diff = 2
		var nm: Dictionary = c.nextMatch()
		same({"home": nm.home, "opp": nm.opp.id, "day": nm.day, "div": nm.div}, want.nm, "giornata %d: nextMatch" % i)
		var my := c.myMatchTeam()
		var opp := c.aiMatchTeam(nm.opp)
		var score: Array = [4, 1] if sc.mode == "win" else c.simScore(c.myRating(), nm.opp.rating)
		var res := c.finishMatch(score[0], score[1], _goals_log(c, score[0]))
		var ok := same(score, want.score, "giornata %d: risultato" % i)
		ok = same(res, want.res, "giornata %d: finishMatch" % i) and ok
		ok = same(_digest(c), want.digest, "giornata %d: stato" % i) and ok
		if want.has("myTeam"):
			ok = same(my, want.myTeam, "giornata %d: myMatchTeam" % i) and ok
			ok = same(opp, want.oppTeam, "giornata %d: aiMatchTeam" % i) and ok
		else:
			var corto := {"formation": opp.formation, "skill": opp.skill, "kit": opp.kit, "p0": opp.players[0], "p10": opp.players[10]}
			ok = same(corto, want.oppTeam, "giornata %d: aiMatchTeam" % i) and ok
		if res.has("season"):
			ok = same(come_web(c.s), sc.snapshots["season%d" % (c.s.season - 1)], "fine stagione %d" % (c.s.season - 1)) and ok
		if not ok:
			return done()
	same(come_web(c.s), sc.final, "stato finale")
	var esiti: Array = []
	for d: Dictionary in sc.days:
		if d.res.has("season"):
			esiti.append(d.res.season.outcome)
	note("%s: %d giornate uguali al JS, esiti di fine stagione %s, soldi %s" % [sc.name, sc.days.size(), str(esiti), CarrieraScript.fmtMoney(c.s.money)])
	c.reset()
	return done()


# le stesse operazioni di export-carriera.mjs, coi risultati confrontati uno a uno
func _operazioni(c: CarrieraScript, sc: Dictionary) -> void:
	var ops: Array = sc.ops
	var cheapest: Dictionary = c.s.market[0]
	for p: Dictionary in c.s.market:
		if p.price < cheapest.price or (p.price == cheapest.price and p.id < cheapest.id):
			cheapest = p
	same(["buy", cheapest.id, _null(c.buy(cheapest.id))], ops[0], "buy")
	same(["buy", 123456, _null(c.buy(123456))], ops[1], "buy inesistente")
	var b := c.bench()
	var last_id: int = b[b.size() - 1].id
	same(["sell", last_id, _null(c.sell(last_id))], ops[2], "sell")
	same(["sellPrice", c.s.squad[3].id, c.sellPrice(c.s.squad[3])], ops[3], "sellPrice")
	var a_id: int = c.s.lineup[9]
	var b_id: int = c.bench()[0].id
	c.swap(a_id, b_id)
	same(["swap", a_id, b_id, null], ops[4], "swap")
	c.setKitStyle({"fit": 1, "sleeves": 4, "collar": 2, "pattern": 3, "shorts": 1, "socks": 2})
	c.setCrest({"shape": 12, "pattern": -1, "icon": 5})
	var champ := c.addChampion({"name": "  Campione Prova Con Un Nome Lungo  ", "pos": "A", "look": {"skin": 3, "hair": 20, "beard": 2}, "num": 9})
	same(["addChampion", champ], ops[5], "addChampion")
	same(["setLook", c.setLook(c.s.squad[5].id, {"skin": 7, "eyes": 3}), c.setLook(424242, {})], ops[6], "setLook")
	same(["kitStyle", c.kitStyle(), "crest", c.crest(), "teamCrest", c.teamCrest(c.team("t3")), c.teamCrest({"id": "x9", "name": "Senza Seme"})], ops[7], "stile e stemmi")
	same(["myRating", c.myRating(), "divOf", c.divOf(c.team("t0")), c.divOf({"id": "amico"}), "skillOf", c.skillOf(66, 0), c.skillOf(40)], ops[8], "valutazioni")
	c.refreshMarket(7)


static func _null(err: String) -> Variant:
	return null if err == "" else err


static func _goals_log(c: CarrieraScript, n: int) -> Array:
	var log: Array = []
	for k in n:
		var scorer: Dictionary = c.player(c.s.lineup[9 + (k % 2)])
		var assist: Variant = null if k % 3 == 2 else c.player(c.s.lineup[7])
		log.append({"team": 0, "scorer": {"id": scorer.id}, "assist": {"id": assist.id} if assist != null else null})
	log.append({"team": 1, "scorer": {"id": 9999}, "assist": null})
	return log


static func _digest(c: CarrieraScript) -> Dictionary:
	var s: Dictionary = c.s
	var market: Array = []
	for p: Dictionary in s.market:
		market.append([p.id, p.name, p.pos, p.age, p.price, CarrieraScript.overall(p)])
	return {"seed": s.seed, "money": s.money, "day": s.day, "season": s.season, "nextId": s.nextId, "divs": s.divs,
		"tables": [c.table(0), c.table(1), c.table(2)], "lineup": s.lineup, "rating": s.teams.me.rating, "last": s.last,
		"market": market}
