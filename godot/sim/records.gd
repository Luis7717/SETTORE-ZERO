# Strutture dati del motore (in JS erano oggetti letterali): giocatore, pallone, calcio, tiro, comandi, duello...
# Classi interne con campi tipizzati: più veloci dei Dictionary e controllate dall'analizzatore.
# I nomi dei campi sono gli stessi del JS (camelCase) per poter confrontare e portare le correzioni riga per riga.
# Niente Vector2: in Godot è a 32 bit, il JS lavora a 64 bit (float di GDScript).
class_name SimRec
extends RefCounted


# statistiche "efficaci" del giocatore nel ruolo in cui gioca (effStats in core.js)
class Stats:
	extends RefCounted
	var vel: float = 0.0
	var tir: float = 0.0
	var pas: float = 0.0
	var dri: float = 0.0
	var dif: float = 0.0
	var fis: float = 0.0
	var por: float = 0.0
	var tes: float = 0.0


# tuffo del portiere in corso
class Dive:
	extends RefCounted
	var tx: float = 0.0
	var th: float = 0.0
	var hx: float = 0.0
	var hh: float = 0.0
	var x0: float = 0.0
	var dirx: float = 0.0


class Player:
	extends RefCounted
	var team: int = 0
	var i: int = 0
	var src: Dictionary = {}
	var name: String = ""
	var pos: String = ""
	var bx: float = 0.0
	var by: float = 0.0
	var st: Stats = null
	var x: float = 0.0
	var y: float = 0.0
	var vx: float = 0.0
	var vy: float = 0.0
	var fx: float = 0.0
	var fy: float = 0.0
	var tx: float = 0.0
	var ty: float = 0.0
	var spdF: float = 1.0
	var state: String = "play"
	var t: float = 0.0
	var stun: float = 0.0
	var protect: float = 0.0
	var contact: float = 0.0
	var tackleCd: float = 0.0
	var kickAnim: float = 0.0
	var energy: float = 1.0
	var sprint: bool = false
	var dribCd: float = 0.0
	var beat: float = 0.0 # saltato col dribbling: tempo che resta prima di riprendersi (s)
	var beatBy: Player = null # ... da chi
	var burst: float = 0.0 # Scatto riuscito: tempo che resta di corsa più veloce (s)
	var wear: Dictionary = {"dri": 1.0, "tes": 1.0}
	var wall: Variant = null  # {x, y} in barriera, altrimenti null
	var yellow: int = 0
	var off: bool = false
	var sdx: float = 0.0
	var sdy: float = 0.0
	var hit: bool = false
	var dive: Dive = null
	var phase: float = 0.0
	var aiT: float = 0.0
	var dx: float = 0.0
	var dy: float = 0.0
	var reactT: float = 0.0
	var decided: bool = true
	var warn: bool = false
	var sox: float = 0.0
	var soy: float = 0.0
	var soT: float = 0.0
	var cele: int = 0
	var look: Variant = null  # aspetto: solo grafica, qui non serve (il numero casuale si consuma lo stesso)
	# campi che in JS nascono "undefined" alla prima scrittura (valgono 0 / null come allora)
	var holdN: int = 0
	var supT: float = 0.0
	var supC: Player = null
	var supX: float = 0.0
	var supY: float = 0.0
	var stickT: float = 0.0


# calcio in volo: chi l'ha calciato, giocatori in fuorigioco al momento del calcio, età
class Kick:
	extends RefCounted
	var team: int = 0
	var kicker: Player = null
	var off: Array = []
	var age: float = 0.0
	var type: String = "ground"
	var human: bool = false

	static func make(team_: int, kicker_: Player, type_: String, age_: float = 0.0, off_: Array = [], human_: bool = false) -> Kick:
		var k := Kick.new()
		k.team = team_
		k.kicker = kicker_
		k.type = type_
		k.age = age_
		k.off = off_
		k.human = human_
		return k


# tiro verso la porta previsto da detectShot
class Shot:
	extends RefCounted
	var team: int = 0
	var cx: float = 0.0
	var ch: float = 0.0
	var tc: float = 0.0
	var on: bool = false
	var gx0: float = 0.0


class Ball:
	extends RefCounted
	var x: float = 0.0
	var y: float = 0.0
	var h: float = 0.0
	var vx: float = 0.0
	var vy: float = 0.0
	var vh: float = 0.0
	var cax: float = 0.0
	var cay: float = 0.0
	var ct: float = 0.0
	var owner: Player = null
	var noP: Player = null
	var noT: float = 0.0
	var last: Player = null
	var prev: Player = null
	var kick: Kick = null
	var shot: Shot = null
	var dbl: Player = null # ha battuto il calcio da fermo e non può ritoccare il pallone finché non lo tocca un altro
	var dblT: float = 0.0  # ... tempo di pallone libero da allora (sicurezza DBL_FREE)

	# copia della sola parte fisica (per le previsioni del volo: { x, y, h, vx, vy, vh, cax, cay, ct } in JS)
	func physCopy() -> Ball:
		var s := Ball.new()
		s.x = x
		s.y = y
		s.h = h
		s.vx = vx
		s.vy = vy
		s.vh = vh
		s.cax = cax
		s.cay = cay
		s.ct = ct
		return s


# comando della persona sul giocatore controllato (dito tenuto, tocco, strada disegnata)
class Move:
	extends RefCounted
	var x: float = 0.0
	var y: float = 0.0
	var ttl: float = 0.0
	var held: bool = false
	var sprint: bool = false
	var path: Variant = null  # Array di {x, y} solo per le strade disegnate (userPath)
	var i: int = 0
	var owner: Player = null


# linea di difesa disegnata da un giocatore senza palla
class Run:
	extends RefCounted
	var p: Player = null
	var path: Array = []
	var i: int = 0
	var ttl: float = 0.0


class Duel:
	extends RefCounted
	var team: int = 0
	var p: Player = null
	var o: Player = null
	var t: float = 0.0
	var side: float = 0.0 # dribbling prenotato: 0 = no, ±1 = lato scelto (+1 = sinistra del portatore)
	var bt: float = 0.0   # ... tempo di partita dal tocco del tasto


class Restart:
	extends RefCounted
	var type: String = ""
	var team: int = 0
	var taker: Player = null
	var x: float = 0.0
	var y: float = 0.0
	var t: float = 0.0
	var wait: float = 0.0
	var wallSide: float = 0.0


class Advantage:
	extends RefCounted
	var team: int = 0
	var x: float = 0.0
	var y: float = 0.0
	var t: float = 0.0


# chi va sul pallone libero (p, il più rapido) e il più rapido di movimento (p2)
class Chase:
	extends RefCounted
	var p: Player = null
	var x: float = 0.0
	var y: float = 0.0
	var t: float = 0.0
	var p2: Player = null
	var x2: float = 0.0
	var y2: float = 0.0
