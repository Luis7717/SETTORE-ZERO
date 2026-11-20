# Scena principale dell'app (scenes/app.tscn): al primo fotogramma passa la mano all'autoload App
# (scripts/app.gd), che mostra il menu o la partita e da lì gestisce tutto il flusso.
extends Node


func _ready() -> void:
	App.avvio.call_deferred()
