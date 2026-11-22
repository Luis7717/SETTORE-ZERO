# Genera assets/audio/cori.wav: coro dello stadio sintetizzato (tools/cori_sintesi.gd), suonato in sottofondo dalla
# partita (scripts/partita/audio_partita.gd). Uso: $G --headless --path godot -s res://tools/genera_cori.gd
# (qualche decina di secondi; poi --import)
extends SceneTree

const Sintesi := preload("res://tools/cori_sintesi.gd")
const FILE := "res://assets/audio/cori.wav"


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var giro := Sintesi.sintetizza()
	var w := Sintesi.a_wav(giro)
	var err := w.save_to_wav(ProjectSettings.globalize_path(FILE))
	print("cori: %.2f s, %d campioni, errore %d, %.1f s di calcolo" % [Sintesi.durata(), giro.size(), err, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0 if err == OK else 1)
