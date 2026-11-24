# Stellina sopra il campione controllato (Luis 2026-11-24): al posto del triangolo, una stella gialla col bordo nero.
extends "test_base.gd"

const TV := preload("res://scripts/partita/texture_vista.gd")


func test_stellina_gialla_al_centro_trasparente_negli_angoli() -> bool:
	var img := TV.stellina().get_image()
	var centro := img.get_pixel(32, 33)
	check(centro.a > 0.9 and centro.r > 0.8 and centro.b < 0.5, "centro giallo (%s)" % centro)
	eq(img.get_pixel(1, 1).a, 0.0, "angolo trasparente")
	eq(img.get_pixel(32, 62).a, 0.0, "sotto, tra le due punte basse, trasparente")
	check(img.get_pixel(32, 5).a > 0.9, "punta in alto disegnata")
	return done()
