# Musiche dei menu (Luis 2026-11-28, "aggiungi altre canzoni"): una lista di brani CC0 (crediti in CREDITI.md) che
# suonano uno dopo l'altro in ordine sparso, senza ripetere lo stesso brano due volte di fila. La partita resta senza
# musica (app.gd); tornando al menu parte il brano dopo.
extends RefCounted

const BRANI: Array[String] = [
	"res://assets/audio/music.mp3",            # Race song loop (neko_4444), quella di prima
	"res://assets/audio/music_uplifting.mp3",  # Free Uplifting Music (Seth_Makes_Sounds)
	"res://assets/audio/music_commercial.mp3", # Free Commercial Song (Seth_Makes_Sounds)
	"res://assets/audio/music_summer.mp3",     # Summer [Guitar Hip-Hop Beat] (Seth_Makes_Sounds)
	"res://assets/audio/music_pop.mp3",        # Bubblegum Pop Song (Seth_Makes_Sounds)
	"res://assets/audio/music_dance.mp3",      # fun dancetrack (evanjones4)
	"res://assets/audio/music_rock.mp3",       # rock music loop (Prime45)
]


## indice del brano dopo `attuale` su `n` brani, scelto con `caso` in [0, 1): mai lo stesso di prima (se ce n'è più
## di uno); `attuale` < 0 = primo brano, uno qualsiasi
static func prossimo(attuale: int, n: int, caso: float) -> int:
	if n <= 0:
		return -1
	if n == 1:
		return 0
	var c := clampf(caso, 0.0, 0.999999)
	if attuale < 0 or attuale >= n:
		return int(c * n)
	# si sceglie tra gli altri n-1 e si salta quello attuale
	var i := int(c * (n - 1))
	return i + 1 if i >= attuale else i


## brani che ci sono davvero tra i file del gioco (uno che manca si salta, come in assets.js del web)
static func disponibili() -> Array[String]:
	var r: Array[String] = []
	for b in BRANI:
		if ResourceLoader.exists(b):
			r.append(b)
	return r
