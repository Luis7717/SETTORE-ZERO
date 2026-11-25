# Riepilogo di metà stagione (Luis 2026-11-25: "va bene la schermata riepilogo a metà stagione, fai in modo che le
# statistiche dei giocatori salgano in quel momento"). Si apre dal dopo partita della 9ª giornata.
# arg = res.meta_stagione di Carriera.metaStagione: {rosa: [{id, nome, pos, eta, media, punti, prima, dopo, cambi}],
# cpu: [{id, name, short, media, div}]}. Mia rosa: età nuova, media voti, valutazione prima → dopo e le
# sotto-statistiche cambiate; avversari della mia divisione: chi cresce e chi cala.
extends MenuSchermata

const Sotto := preload("res://sim/sottostat.gd")
const VERDE := "#4aeb9f"
const ROSSO := "#ff7079"


func prepara() -> void:
	titolo = "Metà stagione"


func costruisci() -> void:
	var r: Dictionary = arg if arg is Dictionary else {}
	corpo.add_child(U.bb("Un anno in più per tutti (il campione no). Le statistiche cambiano adesso, una volta a metà stagione: con la [b]media dei voti[/b] e l'[b]età[/b] (i giovani crescono, i più vecchi calano).", 14, Color("#d7e1f3")))
	var rosa: Array = r.get("rosa", []) if r.get("rosa") is Array else []
	rosa = rosa.duplicate()
	rosa.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.dopo) - int(a.prima) > int(b.dopo) - int(b.prima))
	var carta := U.pannello("Carta")
	var v := U.vbox(9)
	carta.add_child(v)
	v.add_child(U.testo("La tua rosa", 16, T.TXT, T.PESO_NERO))
	for g: Dictionary in rosa:
		v.add_child(U.bb(riga_giocatore(g), 13, Color("#d7e1f3")))
	corpo.add_child(carta)
	var cpu := _mia_divisione(r.get("cpu", []) if r.get("cpu") is Array else [])
	if not cpu.is_empty():
		var c2 := U.pannello("Carta")
		var v2 := U.vbox(7)
		c2.add_child(v2)
		v2.add_child(U.testo("Avversari della tua divisione", 16, T.TXT, T.PESO_NERO))
		v2.add_child(U.bb("Anche loro cambiano adesso, secondo come è andato il girone d'andata.", 12.5, T.DIM))
		for t: Dictionary in cpu:
			v2.add_child(U.bb(riga_squadra(t), 13, Color("#d7e1f3")))
		corpo.add_child(c2)
	corpo.add_child(U.spazio(4))
	corpo.add_child(U.bottone("AVANTI", "BtnGrande", func() -> void: vai("hub")))


func _mia_divisione(cpu: Array) -> Array:
	var d: int = int(carriera().div()) if not stato().is_empty() else -1
	return cpu.filter(func(t: Dictionary) -> bool: return d < 0 or int(t.get("div", d)) == d)


static func _num(x: float) -> String:
	return ("%.1f" % x).replace(".", ",")


## "[b]Rossi[/b] CEN · 24 anni · media 6,8 · 67 → 69 (+2) · Finalizzazione +2, Accelerazione −1"
static func riga_giocatore(g: Dictionary) -> String:
	var d: int = int(g.dopo) - int(g.prima)
	var col := VERDE if d > 0 else (ROSSO if d < 0 else "#aab6cc")
	var media := "media %s" % _num(float(g.media)) if g.get("media") != null else "non ha giocato"
	var testo := "[b]%s[/b] %s · %d anni · %s · %d → [color=%s][b]%d[/b] (%s%d)[/color]" % [U.esc(str(g.nome)),
		D.pos_name(str(g.pos)), int(g.eta), media, int(g.prima), col, int(g.dopo), "+" if d >= 0 else "−", absi(d)]
	var pezzi: Array = []
	var cambi: Dictionary = g.get("cambi", {}) if g.get("cambi") is Dictionary else {}
	var chiavi := cambi.keys()
	chiavi.sort_custom(func(a: String, b: String) -> bool: return absi(int(cambi[a])) > absi(int(cambi[b])))
	for k: String in chiavi.slice(0, 4):
		var x := int(cambi[k])
		pezzi.append("[color=%s]%s %s%d[/color]" % [VERDE if x > 0 else ROSSO, Sotto.NOMI.get(k, k), "+" if x > 0 else "−", absi(x)])
	if not pezzi.is_empty():
		testo += "\n   " + ", ".join(pezzi)
	return testo


static func riga_squadra(t: Dictionary) -> String:
	var m := float(t.media)
	var stato := "[color=%s]in crescita[/color]" % VERDE if m > 6.2 else ("[color=%s]in calo[/color]" % ROSSO if m < 5.8 else "stabile")
	return "[b]%s[/b] · %s" % [U.esc(str(t.name)), stato]
