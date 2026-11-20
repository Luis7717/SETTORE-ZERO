# Come si gioca (howto() e HOWTO di src/ui.js): cinque pagine (correre e tirare, duello e passaggio, area di tiro,
# difesa, portiere) con disegno, titolo e testo; puntini in alto, Avanti, Salta; l'ultima porta all'allenamento.
extends MenuSchermata

const I := preload("res://scripts/menu/icone.gd")

const HOWTO := [
	["Correre e tirare", "Col pallone <b>disegna la strada</b> partendo dal tuo giocatore: lui la segue, e con tanta strada davanti <b>scatta</b>. Se la linea <b>finisce dentro la porta</b> è un tiro; curvala per tirare a giro."],
	["Duello e passaggio", "Quando ti avvicini a un difensore la visuale si abbassa e il tempo rallenta: <b>disegna fino a un compagno</b> (uno qualunque) per passare, oppure tocca <b>Scatto</b> per bruciarlo in velocità e proseguire dritto. Trascinando il dito di lato sul campo giri la visuale."],
	["Area di tiro", "Negli <b>ultimi 20 metri</b> il tempo rallenta: linea in porta per <b>tirare</b>, fino a un compagno per <b>passare</b>, altrove per correre."],
	["Difesa", "In difesa <b>disegna una linea dai tuoi giocatori</b> (tutti tranne il portiere): corrono lungo la strada che tracci, per chiudere l’avversario o tagliare la linea del passaggio. Ogni difensore intercetta in un piccolo raggio: più largo se è bravo in difesa, più stretto se chi passa è bravo nei passaggi. Tocca un compagno per comandarlo."],
	["Portiere", "Quando tirano la visuale va dietro la tua porta e il tempo rallenta: <b>tira una linea dal portiere al punto della porta</b> dove arriva la palla e alza il dito al momento giusto. Più la palla è lontana dal portiere, più è difficile arrivarci."],
]

var pagina := 0


func prepara() -> void:
	con_testata = false
	if arg is int or arg is float:
		pagina = clampi(int(arg), 0, HOWTO.size() - 1)


func costruisci() -> void:
	corpo.add_child(U.spazio(maxf(0.0, get_viewport_rect().size.y * 0.05 - 12.0)))
	var barra := U.hbox(7)
	for n in HOWTO.size():
		var on := n == pagina
		var p := U.pannello_stile(T.stile(T.GOLD if on else Color(1, 1, 1, 0.18), 3, Color(0, 0, 0, 0), 0, Vector4.ZERO))
		p.custom_minimum_size = Vector2(26 if on else 6, 6)
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		barra.add_child(p)
	barra.add_child(U.riempi())
	barra.add_child(U.testo("%d / %d" % [pagina + 1, HOWTO.size()], 15, T.DIM, T.PESO_MEDIO))
	corpo.add_child(barra)

	var k1: Color = colori_squadra()[0]
	var cs := U.carta_sfumata(T.mix(k1, 40, Color("#1b2b49")), T.CARD_BOTTOM, 160, 1.0, 30, Vector4.ZERO, T.LINE2, Color(0, 0, 0, 0.45))
	var ill: Control = cs[0]
	ill.custom_minimum_size = Vector2(112, 112)
	ill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var dis := MenuDisegno.nuovo(I.illustrazione(pagina), Vector2(80, 80), Vector2(72, 72))
	dis.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dis.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cs[1].add_child(dis)
	var im := MarginContainer.new()
	im.add_theme_constant_override("margin_top", int(get_viewport_rect().size.y * 0.02))
	im.add_theme_constant_override("margin_bottom", 6)
	im.add_child(ill)
	corpo.add_child(im)

	corpo.add_child(U.testo(HOWTO[pagina][0], 32, T.TXT, T.PESO_NERO))
	corpo.add_child(U.ricco(HOWTO[pagina][1], 17.5, Color("#d7e1f3")))
	corpo.add_child(U.spazio(2))
	var ultima_pagina := pagina + 1 >= HOWTO.size()
	if ultima_pagina:
		corpo.add_child(U.bottone("PROVA IN CAMPO", "BtnGrande", func() -> void: gioca("allenamento")))
		corpo.add_child(U.bottone("Ho capito, vai al menu", "", _avanti))
	else:
		corpo.add_child(U.bottone("AVANTI", "BtnGrande", _avanti))
	if not stato().is_empty():
		corpo.add_child(U.bottone("Salta", "BtnFantasma", func() -> void: vai("hub")))


func _avanti() -> void:
	if pagina + 1 >= HOWTO.size():
		vai("hub")
		return
	pagina += 1
	mostra(true)
