# Mercato con le squadre (Luis 2026-11-25, logica in scripts/carriera/mercato_squadre.gd). Due schede:
# - Compra: i giocatori delle squadre della CPU (divisione scelta in alto, predefinita la mia, e ruolo), con sigla
#   della squadra, ruolo, età, valutazione e prezzo chiesto. Un tocco apre la scheda: offerta da −20% a +20% del
#   prezzo a passi del 5%, "Fai l'offerta"; la squadra accetta, fa una controfferta (si può accettare) o rifiuta
#   (si riprova la giornata dopo).
# - Offerte: quelle delle squadre per i miei giocatori, con Accetta (vendi a quel prezzo) e Rifiuta.
# Per mettere in vendita un giocatore: Rosa → "Cerca acquirenti". Il vecchio mercato generico (s.market) non si
# mostra più. arg (prove): {filtro, div, scheda: "offerte", aperto: indice nella lista, statistiche: true}
# Nella scheda, "Statistiche" apre le statistiche dettagliate del giocatore (statistiche_giocatore.gd).
extends MenuSchermata

const Fisico := preload("res://scripts/carriera/fisico.gd")
const Mercato := preload("res://scripts/carriera/mercato_squadre.gd")
const StatG := preload("res://scripts/menu/statistiche_giocatore.gd")
const FILTRI := [["T", "Tutti"], ["P", "POR"], ["D", "DIF"], ["C", "CEN"], ["A", "ATT"]]
const DIV_CORTI := ["Prima", "Seconda", "Terza"]

var filtro := "T"
var divisione := -1               # divisione mostrata (-1 = la mia)
var vista := "compra"             # "compra" o "offerte"
var aperto: Variant = null        # chiave "id squadra:indice" del giocatore con la scheda aperta
var parte := 1.0                  # offerta = prezzo chiesto × parte (0,8 .. 1,2)
var _stat_velo: Control = null    # statistiche dettagliate aperte sopra la lista
var _stat_subito := false         # arg {"statistiche": true}: aprile sul giocatore aperto (prove)


func prepara() -> void:
	titolo = "Mercato"
	if divisione < 0:
		divisione = maxi(0, carriera().div()) if not stato().is_empty() else 2
	if arg is Dictionary:
		filtro = str(arg.get("filtro", "T"))
		vista = "offerte" if arg.get("scheda") == "offerte" else "compra"
		if _intero(arg.get("div")):
			divisione = clampi(int(arg.div), 0, 2)
		var a: Variant = arg.get("aperto")
		if a is int and not stato().is_empty():
			var l := _lista()
			if a < l.size():
				aperto = Mercato.chiave(str(l[a].squadra.id), int(l[a].i))
				_stat_subito = bool(arg.get("statistiche", false))


static func _intero(v: Variant) -> bool:
	return v is int or (v is float and v == floorf(v))


func _lista() -> Array:
	var l: Array = Mercato.lista(carriera(), divisione).filter(func(g: Dictionary) -> bool: return filtro == "T" or g.p.pos == filtro)
	return D.ordina(l, func(a: Dictionary, b: Dictionary) -> int: return D.overall(b.p) - D.overall(a.p))


func costruisci() -> void:
	var s := stato()
	if s.is_empty():
		return
	var n_off: int = Mercato.aperte(s).size()
	var schede := U.hbox(8)
	schede.add_child(U.chip("Compra", vista == "compra", _vista.bind("compra")))
	schede.add_child(U.chip("Offerte per i tuoi (%d)" % n_off if n_off > 0 else "Offerte per i tuoi", vista == "offerte", _vista.bind("offerte")))
	corpo.add_child(schede)
	if vista == "offerte":
		_costruisci_offerte(s)
		return
	var divs := U.hbox(8)
	for d in 3:
		divs.add_child(U.chip(DIV_CORTI[d], divisione == d, _divisione.bind(d)))
	corpo.add_child(divs)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 8)
	chips.add_theme_constant_override("v_separation", 8)
	for fk: Array in FILTRI:
		chips.add_child(U.chip(fk[1], filtro == fk[0], _filtra.bind(fk[0])))
	corpo.add_child(chips)
	corpo.add_child(U.ricco("Rosa: %d/24. Tocca un giocatore per fare un'offerta alla sua squadra. Per vendere vai in <b>Rosa</b> e tocca <b>Cerca acquirenti</b>." % s.squad.size(), 13.5, T.NOTE, false))
	var righe := U.vbox(7)
	for g: Dictionary in _lista():
		var k := Mercato.chiave(str(g.squadra.id), int(g.i))
		righe.add_child(_riga(g, s, k))
		if aperto == k:
			var sotto := U.vbox(8)
			sotto.add_child(U.bottone("Statistiche", "BtnFantasma", _apri_statistiche.bind(g), 44))
			sotto.add_child(_pannello_offerta(g, s))
			righe.add_child(scheda(g.p, sotto))
			if _stat_subito:
				_stat_subito = false
				_apri_statistiche.call_deferred(g)
	corpo.add_child(righe)


func _vista(v: String) -> void:
	vista = v
	aperto = null
	ridisegna()


func _divisione(d: int) -> void:
	divisione = d
	aperto = null
	ridisegna()


func _filtra(f: String) -> void:
	filtro = f
	ridisegna()


func _riga(g: Dictionary, s: Dictionary, k: String) -> Control:
	var p: Dictionary = g.p
	var o := D.overall(p)
	var b := U.bottone("", "RigaSel" if aperto == k else "Riga", _apri.bind(k), 56)
	var h := U.hbox(8)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -10
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(U.ruolo(p.pos, D.pos_name(p.pos)))
	var nome := U.vbox(0)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.alignment = BoxContainer.ALIGNMENT_CENTER
	nome.add_child(U.corto(str(p.name), 15, T.TXT, T.PESO_FORTE))
	nome.add_child(U.testo("%s · %d anni" % [str(g.squadra.short), int(p.age)], 11.5, T.DIM, T.PESO_MEDIO))
	h.add_child(nome)
	h.add_child(U.valutazione(o, D.ovr_cls(o)))
	var puo: bool = int(s.money) >= int(g.prezzo)
	var prezzo := U.testo(D.fmt_money(g.prezzo), 13.5, T.GOOD if puo else Color("#ff9aa0"), T.PESO_NERO, HORIZONTAL_ALIGNMENT_RIGHT)
	prezzo.custom_minimum_size.x = 66
	h.add_child(prezzo)
	b.add_child(h)
	return b


## statistiche dettagliate di un giocatore di un'altra squadra, coi colori della sua squadra
func _apri_statistiche(g: Dictionary) -> void:
	_chiudi_statistiche()
	var k := D.kit(g.squadra.get("kit", 0))
	_stat_velo = StatG.vista(g.p, D.overall(g.p), [D.hex(int(k[1])), D.hex(int(k[2]))], int(k[1]), sicura, _chiudi_statistiche)
	add_child(_stat_velo)


func _chiudi_statistiche() -> void:
	if _stat_velo != null and is_instance_valid(_stat_velo):
		_stat_velo.queue_free()
	_stat_velo = null


func _apri(k: String) -> void:
	aperto = null if aperto == k else k
	parte = 1.0
	ridisegna()


## sotto la scheda del giocatore: prezzo chiesto, offerta a passi e risposta della squadra
func _pannello_offerta(g: Dictionary, s: Dictionary) -> Control:
	var tid := str(g.squadra.id)
	var i := int(g.i)
	var chiesto := int(g.prezzo)
	var v := U.vbox(8)
	var chi := "il migliore della squadra" if g.migliore else "titolare"
	v.add_child(U.bb("[b]%s[/b] (%s) chiede [color=#ffd93d][b]%s[/b][/color]" % [U.esc(str(g.squadra.name)), chi, D.fmt_money(chiesto)], 13.5, Color("#d7e1f3")))
	var tr: Variant = Mercato.trattativa(s, tid, i)
	if tr is Dictionary and tr.esito == "rifiuta":
		v.add_child(U.paragrafo("Offerta rifiutata. Riprova alla prossima giornata.", 13.5, T.BAD))
		return v
	if tr is Dictionary and tr.esito == "contro":
		v.add_child(U.paragrafo("Controfferta: vogliono %s." % D.fmt_money(float(tr.prezzo)), 13.5, T.GOLD))
		v.add_child(U.bottone("Accetta per %s" % D.fmt_money(float(tr.prezzo)), "", func() -> void:
			var err := D.errore(Mercato.accetta_contro(carriera(), tid, i))
			if err == "":
				aperto = null
			toast(err if err != "" else "%s arriva in rosa!" % str(g.p.name)), 46))
		return v
	var soldi := Mercato.importo(chiesto, parte)
	var passi := U.hbox(8)
	var meno := U.bottone("−5%", "BtnFantasma", _passo.bind(-Mercato.OFFERTA_PASSO), 44)
	meno.custom_minimum_size.x = 64
	meno.disabled = parte <= Mercato.OFFERTA_MIN + 0.001
	passi.add_child(meno)
	var cifra := U.testo("%s (%d%%)" % [D.fmt_money(soldi), roundi(parte * 100.0)], 16, T.TXT if int(s.money) >= soldi else Color("#ff9aa0"), T.PESO_NERO, HORIZONTAL_ALIGNMENT_CENTER)
	cifra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	passi.add_child(cifra)
	var piu := U.bottone("+5%", "BtnFantasma", _passo.bind(Mercato.OFFERTA_PASSO), 44)
	piu.custom_minimum_size.x = 64
	piu.disabled = parte >= Mercato.OFFERTA_MAX - 0.001
	passi.add_child(piu)
	v.add_child(passi)
	if absf(parte - 1.0) > 0.001:
		v.add_child(U.bottone("Prezzo chiesto", "BtnFantasma", func() -> void:
			parte = 1.0
			ridisegna(), 40))
	v.add_child(U.bottone("Fai l'offerta: %s" % D.fmt_money(soldi), "", _offri.bind(tid, i, soldi, str(g.p.name)), 46))
	return v


func _passo(d: float) -> void:
	parte = clampf(snappedf(parte + d, Mercato.OFFERTA_PASSO), Mercato.OFFERTA_MIN, Mercato.OFFERTA_MAX)
	ridisegna()


func _offri(tid: String, i: int, soldi: int, nome: String) -> void:
	var r := Mercato.offri(carriera(), tid, i, soldi)
	if r.errore != "":
		toast(r.errore)
		return
	match r.esito:
		"accetta":
			aperto = null
			toast("Offerta accettata: %s arriva in rosa!" % nome)
		"contro":
			toast("Controfferta: vogliono %s" % D.fmt_money(float(r.prezzo)))
		_:
			toast("Offerta rifiutata")


# ---------------------------------------------------------------- offerte per i miei giocatori
func _costruisci_offerte(s: Dictionary) -> void:
	var off: Array = Mercato.aperte(s)
	if off.is_empty():
		corpo.add_child(U.ricco("Nessuna offerta per ora. Le squadre fanno offerte dopo le partite, soprattutto per chi ha una buona media voti. Per vendere un giocatore: <b>Rosa</b> → <b>Cerca acquirenti</b>, e alla giornata dopo arriva un'offerta.", 13.5, T.NOTE, false))
		return
	corpo.add_child(U.ricco("Le offerte durano 2 giornate. Accetta = il giocatore lascia la squadra per quella cifra.", 13.5, T.NOTE, false))
	for k in off.size():
		corpo.add_child(_carta_offerta(s, off[k], k))


func _carta_offerta(s: Dictionary, o: Dictionary, k: int) -> Control:
	var c := carriera()
	var p: Variant = c.player(o.id)
	var t: Variant = s.teams.get(o.squadra)
	var carta := U.pannello("Carta")
	var v := U.vbox(8)
	carta.add_child(v)
	if p == null or not t is Dictionary:
		return carta
	var h := U.hbox(8)
	h.add_child(U.ruolo(p.pos, D.pos_name(p.pos)))
	var nome := U.vbox(0)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.add_child(U.corto(str(p.name), 15.5, T.TXT, T.PESO_FORTE))
	var media: Variant = c.media_voti(p.id)
	var info := "%d anni · valore %s" % [int(p.age), D.fmt_money(D.value(p))]
	if media != null:
		info += " · media %s" % ("%.1f" % float(media)).replace(".", ",")
	nome.add_child(U.testo(info, 11.5, T.DIM, T.PESO_MEDIO))
	h.add_child(nome)
	var o_ := D.overall(p)
	h.add_child(U.valutazione(o_, D.ovr_cls(o_)))
	v.add_child(h)
	var resta := int(o.scade) - Mercato.giorno(s)
	v.add_child(U.bb("[b]%s[/b] offre [color=#4aeb9f][b]%s[/b][/color] · %s" % [U.esc(str(t.name)), D.fmt_money(float(o.soldi)),
		"ultima giornata" if resta <= 1 else "ancora %d giornate" % resta], 13.5, Color("#d7e1f3")))
	var bt := U.griglia(2, 8, 8)
	var si := U.bottone("Accetta", "", _accetta.bind(k, str(p.name)), 44)
	si.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bt.add_child(si)
	var no := U.bottone("Rifiuta", "BtnFantasma", _rifiuta.bind(k), 44)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bt.add_child(no)
	v.add_child(bt)
	return carta


func _accetta(k: int, nome: String) -> void:
	var err := D.errore(Mercato.accetta(carriera(), k))
	toast(err if err != "" else "%s venduto!" % nome)


func _rifiuta(k: int) -> void:
	Mercato.rifiuta(carriera(), k)
	toast("Offerta rifiutata")


## scheda di un giocatore (pcard del web): nome, ruolo, età, valore, statistiche con le barre, pulsante sotto
static func scheda(p: Dictionary, sotto: Control) -> Control:
	var pann := MenuUi.pannello("Pannello")
	var v := MenuUi.vbox(12)
	pann.add_child(v)
	var testa := MenuUi.vbox(4)
	testa.add_child(MenuUi.testo(str(p.name), 18, MenuTema.TXT, MenuTema.PESO_NERO))
	var info := "%s · %s · %d anni · valore %s" % [MenuDati.pos_name(p.pos), Fisico.testo(Fisico.di(p)), int(p.age), MenuDati.fmt_money(MenuDati.value(p))]
	if p.get("num") != null:
		info += " · n. %d" % int(p.num)
	if int(p.get("apps", 0)) > 0:
		info += " · %d pres. %d gol" % [int(p.apps), int(p.get("goals", 0))]
	testa.add_child(MenuUi.paragrafo(info, 12.5, MenuTema.DIM, MenuTema.PESO_MEDIO))
	v.add_child(testa)
	var g := MenuUi.griglia(4, 8, 8)
	for kn: Array in (MenuDati.GK_STATS if p.pos == "P" else MenuDati.STATS):
		var val := MenuDati.stat_of(p, kn[0])
		var cls := MenuDati.ovr_cls(val)
		var cella := MenuUi.pannello("Stat")
		cella.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := MenuUi.vbox(6)
		var r := MenuUi.hbox(2)
		r.add_child(MenuUi.testo(kn[1], 10.5, MenuTema.DIM, MenuTema.PESO_NERO))
		r.add_child(MenuUi.riempi())
		r.add_child(MenuUi.testo(str(val), 18, MenuTema.TXT, MenuTema.PESO_NERO))
		cv.add_child(r)
		cv.add_child(MenuUi.barra(maxf(6.0, minf(100.0, val)) / 100.0, 5.0, MenuTema.STAT[cls]))
		cella.add_child(cv)
		g.add_child(cella)
	v.add_child(g)
	if sotto != null:
		v.add_child(sotto)
	return pann
