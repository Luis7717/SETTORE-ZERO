# 1 contro 1 (vsfriend() di src/ui.js): la sfida tra due iPhone vicini arriva più avanti.
extends MenuSchermata


func prepara() -> void:
	titolo = "1 contro 1"


func costruisci() -> void:
	var carta := U.pannello("Carta")
	var v := U.vbox(10)
	v.add_child(U.paragrafo("La sfida tra due iPhone vicini (senza internet) arriva con il prossimo aggiornamento.", 16, T.TXT, T.PESO_MEDIO))
	v.add_child(U.paragrafo("Il motore di gioco è già pronto per due giocatori: manca il collegamento tra i telefoni.", 15, T.DIM, T.PESO_MEDIO))
	carta.add_child(v)
	corpo.add_child(carta)
