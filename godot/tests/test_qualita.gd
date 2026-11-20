# Livelli di qualità automatici (scripts/partita/qualita.gd): si scende solo se gli FPS restano bassi per qualche
# secondo, uno scalino alla volta, mai sotto il minimo, e niente misure subito dopo un cambio.
extends "test_base.gd"

const Q := preload("res://scripts/partita/qualita.gd")


func corri(q: RefCounted, fps: float, sec: float) -> int:
	var cambi := 0
	var t := 0.0
	while t < sec:
		if q.aggiorna(1.0 / fps):
			cambi += 1
		t += 1.0 / fps
	return cambi


func test_a_60_fps_resta_alto() -> bool:
	var q := Q.new()
	eq(corri(q, 60.0, 30.0), 0, "nessun cambio a 60 fps")
	eq(q.livello, Q.ALTO, "resta alto")
	return done()


func test_sotto_58_scende_di_uno_alla_volta() -> bool:
	var q := Q.new()
	corri(q, 50.0, Q.ATTESA + Q.FINESTRA * Q.LENTE + 0.1)
	eq(q.livello, Q.MEDIO, "dopo la prima finestra lenta: medio")
	corri(q, 50.0, Q.ATTESA * 0.9)
	eq(q.livello, Q.MEDIO, "durante l'attesa non scende ancora")
	corri(q, 50.0, 60.0)
	eq(q.livello, Q.MINIMO, "a lungo lento: fino al minimo, non oltre")
	return done()


func test_un_intoppo_breve_non_basta() -> bool:
	var q := Q.new()
	corri(q, 60.0, Q.ATTESA + 0.5)
	q.aggiorna(0.1)          # un fotogramma lungo (un caricamento)
	corri(q, 60.0, 10.0)
	eq(q.livello, Q.ALTO, "un solo fotogramma lungo non fa scendere")
	return done()


func test_in_pausa_non_conta() -> bool:
	var q := Q.new()
	for i in 1000:
		q.aggiorna(0.0)
	eq(q.livello, Q.ALTO, "dt 0 non conta")
	q.imposta(1)
	eq(q.livello, Q.BASSO, "livello a mano")
	q.imposta(9)
	eq(q.livello, Q.ALTO, "livello a mano limitato")
	return done()
