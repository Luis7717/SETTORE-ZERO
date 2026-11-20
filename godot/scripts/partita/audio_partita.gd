# Suoni della partita (porting di src/audio.js): file veri di assets/audio/ agganciati agli eventi del motore.
# Un file che manca non blocca nulla: quel suono si salta (il palo, che non ha un file, è un tono generato qui).
# Pubblico di sottofondo in loop, più forte quando il pallone si avvicina a una porta e subito dopo un gol.
extends Node

const CARTELLA := "res://assets/audio/"
const CROWD_SAMPLE_GAIN := 3.5   # il file del pubblico è piano: lo si alza (come nel web)
const KICK_SAMPLE_GAIN := 3.0    # la registrazione del calcio è molto piano
const FOLLA_BASE := 0.16         # livello del pubblico durante la partita (web: sfx.crowd(0.16))
const FOLLA_PORTA := 0.14        # in più col pallone vicino a una porta (cresce dagli ultimi 25 m)
const FOLLA_GOL := 0.5           # livello subito dopo un gol ...
const FOLLA_GOL_TIENI := 2.0     # ... tenuto per tanti secondi, poi torna giù
const FOLLA_TAU := 0.4           # costante di tempo del cambio di livello (s), come setTargetAtTime del web
const FOLLA_TAU_GOL := 1.0
const VOCI := 6                  # suoni brevi che possono suonare insieme
const DB_MAX := 12.0

var acceso := true
var _flussi := {}                # id → AudioStream
var _voci: Array[AudioStreamPlayer] = []
var _folla: AudioStreamPlayer
var _folla_liv := 0.0
var _folla_meta := 0.0
var _gol_t := -10.0              # tempo dal gol: > 0 = folla tenuta alta, 0..−3 = sta tornando giù


func _ready() -> void:
	# senza schermo (prove, build su GitHub) niente suoni: non si sentono, e i suoni ancora in corso all'uscita
	# resterebbero in memoria col driver audio finto
	if DisplayServer.get_name() == "headless":
		acceso = false
	for id: String in ["crowd", "goal", "ooh", "whistle", "whistle_long", "kick"]:
		var percorso := CARTELLA + id + ".mp3"
		if ResourceLoader.exists(percorso):
			_flussi[id] = load(percorso)
	_flussi["post"] = _tono_palo()
	for i in VOCI:
		var v := AudioStreamPlayer.new()
		add_child(v)
		_voci.append(v)
	_folla = AudioStreamPlayer.new()
	add_child(_folla)
	if _flussi.has("crowd"):
		var s: AudioStream = (_flussi["crowd"] as AudioStream).duplicate()
		if s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = true
		_folla.stream = s
		_folla.volume_db = -80.0
		if acceso:
			_folla.play()


func _process(delta: float) -> void:
	if _gol_t > -10.0:
		_gol_t -= delta
	var tau := FOLLA_TAU_GOL if _gol_t > -3.0 and _gol_t <= 0.0 else FOLLA_TAU
	var meta := FOLLA_GOL if _gol_t > 0.0 else _folla_meta
	_folla_liv += (meta - _folla_liv) * (1.0 - exp(-delta / tau))
	if _folla.stream != null:
		_folla.volume_db = _db(_folla_liv * CROWD_SAMPLE_GAIN if acceso else 0.0)


# a fine scena (o all'uscita) si fermano tutti i suoni: un suono che sta ancora suonando resterebbe in memoria
func _exit_tree() -> void:
	ferma()


func ferma() -> void:
	for v in _voci:
		v.stop()
		v.stream = null
	if _folla != null:
		_folla.stop()
		_folla.stream = null


## livello del pubblico (0 = zitto); eccitazione 0..1 = pallone vicino a una porta
func folla(livello: float, eccitazione: float = 0.0) -> void:
	_folla_meta = 0.0 if livello <= 0.0 else livello + FOLLA_PORTA * clampf(eccitazione, 0.0, 1.0)


## eccitazione del pubblico come lo stadio del web: dagli ultimi 25 m prima di una porta fino alla linea
static func eccitazione(ball_y: float) -> float:
	return clampf((absf(ball_y) - 25.0) / 25.0, 0.0, 1.0)


func play(id: String, vol: float = 1.0, rate: float = 1.0) -> bool:
	if not acceso or not _flussi.has(id):
		return false
	var v := _voce_libera()
	v.stream = _flussi[id]
	v.volume_db = _db(vol)
	v.pitch_scale = rate
	v.play()
	return true


func kick(v: float) -> void:
	var k := minf(1.0, (v if v > 0.0 else 15.0) / 30.0)
	play("kick", (0.4 + k * 0.6) * KICK_SAMPLE_GAIN, 0.9 + k * 0.2)


func whistle(lungo: bool = false) -> void:
	play("whistle_long" if lungo else "whistle", 0.7)


func post() -> void:
	play("post", 0.8)


func goal() -> void:
	play("goal", 1.0)
	_folla_liv = FOLLA_GOL
	_gol_t = FOLLA_GOL_TIENI


func ooh() -> void:
	play("ooh", 0.9)


func _voce_libera() -> AudioStreamPlayer:
	for v in _voci:
		if not v.playing:
			return v
	var v: AudioStreamPlayer = _voci.pop_front() # la più vecchia
	_voci.append(v)
	return v


static func _db(lineare: float) -> float:
	return -80.0 if lineare <= 0.0001 else minf(DB_MAX, linear_to_db(lineare))


# palo: tono a triangolo che scende da 820 a 760 Hz in 0,35 s (come Sfx.post del web senza file)
static func _tono_palo() -> AudioStreamWAV:
	var hz := 22050
	var durata := 0.35
	var n := int(hz * durata)
	var dati := PackedByteArray()
	dati.resize(n * 2)
	var fase := 0.0
	for i in n:
		var t := float(i) / hz
		var f := 820.0 * pow(760.0 / 820.0, t / durata)
		fase = fmod(fase + f / hz, 1.0)
		var tri := 4.0 * absf(fase - 0.5) - 1.0
		var inv := 0.3 * exp(-t * 14.0)
		dati.encode_s16(i * 2, int(clampf(tri * inv, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = hz
	w.stereo = false
	w.data = dati
	return w
