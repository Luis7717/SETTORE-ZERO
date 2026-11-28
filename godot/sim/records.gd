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
	## sotto-statistiche (sottostat.gd) già col malus del ruolo, solo se il giocatore le ha (sennò vuoto)
	var sub: Dictionary = {}

	## valore della sotto-statistica k (es. "fin"): senza `sub` quello della sua grande, come prima
	func sv(k: String) -> float:
		if sub.has(k):
			return float(sub[k])
		return float(get(GRANDE_DI[k]))

	## quanto la sotto-statistica k si scosta dalla sua grande (0 senza `sub`): serve dove la formula di prima usa
	## un'altra grande (es. accelerazione con `fis`), così con sotto-statistiche uguali alle grandi niente cambia
	func scarto(k: String) -> float:
		if sub.has(k):
			return float(sub[k]) - float(get(GRANDE_DI[k]))
		return 0.0


## sotto-statistica → sua grande (come Sotto.GRUPPI, al contrario)
const GRANDE_DI := {
	"acc": "vel", "vmax": "vel",
	"fin": "tir", "pot": "tir", "lon": "tir", "vol": "tir", "rig": "tir",
	"pco": "pas", "plu": "pas", "cro": "pas", "eff": "pas", "pun": "pas",
	"agi": "dri", "ctl": "dri", "drb": "dri", "equ": "dri",
	"int": "dif", "ctr": "dif",
	"ele": "fis", "res": "fis", "frz": "fis", "agg": "fis",
	"tuf": "por", "rif": "por", "pre": "por", "pia": "por",
}


# tuffo del portiere in corso
class Dive:
	extends RefCounted
	var tx: float = 0.0
	var th: float = 0.0
	var hx: float = 0.0
	var hh: float = 0.0
	var x0: float = 0.0
	var dirx: float = 0.0
	var auto: bool = false     # parata.gd: tuffo partito da solo, finito il fermatempo senza linea


class Player:
	extends RefCounted
	var team: int = 0
	var i: int = 0
	var src: Dictionary = {}
	var name: String = ""
	var pos: String = ""
	var ruolo: String = "" # ruolo specifico del posto (sim/ruoli.gd): solo per il malus fuori ruolo, l'IA usa pos
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
	var slancio: float = 0.0 # dopo il dribbling riuscito della persona: tempo che resta senza rallentare (s)
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
	var presaT: float = -99.0 # istante (time della partita) in cui ha preso il pallone (give): tiro da girato, ai.gd (2026-11-25)
	var girataDa: float = -98.0 # = presaT se col pallone l'IA l'ha già trovato girato rispetto al tiro (ai.gd girataAspetta)
	var claim: Kick = null # portiere: cross avversario su cui è già uscito (non torna indietro a metà strada)
	# scena della ripresa (riprese.gd): il giocatore va camminando al suo posto (rtx, rty) invece di esserci messo
	var rgo: bool = false
	var rtx: float = 0.0
	var rty: float = 0.0


# calcio in volo: chi l'ha calciato, giocatori in fuorigioco al momento del calcio, età
class Kick:
	extends RefCounted
	var team: int = 0
	var kicker: Player = null
	var off: Array = []
	var age: float = 0.0
	var type: String = "ground"
	var human: bool = false
	# contatti.gd (opzione "contatti"): avversari vicini al calcio che non lo toccano nei primi metri, e da dove è partito
	var shield: Array = []
	var sx: float = 0.0
	var sy: float = 0.0
	# da dove è partito il calcio e se da una ripresa (tipo: "corner", "freekick"...; "" in gioco): testa.gd (headCross)
	var x0: float = 0.0
	var y0: float = 0.0
	var rs: String = ""

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
	# parata.gd (opzione "parata"): bersaglio mostrato sulla porta {x, h, rx, rh}; vuoto senza l'opzione
	var area: Dictionary = {}


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
	var finto: Ball = null # giochetto del dribbling (tunnel, pallonetti; solo "rifiniture"): il pallone che si vede, staccato dal portatore che lo va a riprendere (per le regole resta suo)
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
	var lat: float = 1.0  # giochetto (dribShow): quanto va di lato verso la finta (skill.gd) ...
	var vel: float = 1.0  # ... e a che frazione di DRIB_SHOW_V
	var sk: Dictionary = {} # ... il giochetto (riga di skill.gd)
	var lancio: bool = false # ... il pallone finto è già partito (tunnel, pallonetti)
	var ux: float = 0.0   # inseguimento del pallone finto (dribChase): verso del pallone ...
	var uy: float = 0.0
	var tl: float = 0.0   # ... e tempo che manca alla caduta del pallonetto (s)


# Colpo di testa controllato (testa.gd): pallone alto di un compagno che sta per arrivare a un attaccante della squadra
# umana vicino alla porta avversaria. Fermatempo finché il pallone arriva alla testa o la persona disegna la linea.
class HeadWin:
	extends RefCounted
	var team: int = 0
	var p: Player = null     # chi colpisce (diventa il controllato)
	var kick: Kick = null    # il lancio che ha aperto il fermatempo: se cambia, qualcuno ha toccato il pallone
	var x: float = 0.0       # punto previsto del colpo (m) ...
	var y: float = 0.0
	var h: float = 0.0       # ... e altezza del pallone lì (m)
	var tc: float = 0.0      # tempo di partita previsto dall'apertura al colpo (s)
	var age: float = 0.0     # tempo di partita dall'apertura (s)
	var aimed: bool = false  # la persona ha disegnato la linea
	var lost: bool = false   # tempo del fermatempo finito senza linea: non si disegna più, il pallone è perso
	var goal: bool = false   # ... verso la porta (altrimenti sponda verso un compagno o un punto del campo)
	var ax: float = 0.0      # punto mirato: in porta (x, altezza ah) o nel campo (x, y)
	var ay: float = 0.0
	var ah: float = 0.0
	var kind: String = "att" # "att" cross in attacco (come prima), "pass" passaggio alto conteso, "def" pallone alto
	                         # avversario conteso in difesa (testa.gd)
	var rival: Player = null # "pass"/"def": l'avversario attaccato che se lo contendeva (ha perso il salto, o lo vince
	                         # se la persona non disegna: headGive)


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
	# scena della ripresa (riprese.gd, opzione "riprese"): "" = pronta (come sempre), altrimenti il battitore sta ancora
	# andando a prendere il pallone: "va", "raccogli", "porta", "posa" (lo appoggia), "indietro" (passi di rincorsa)
	var scena: String = ""
	var st: float = 0.0        # tempo nel tratto della scena (s)
	var sT: float = 0.0        # tempo di tutta la scena (s)
	var sx: float = 0.0        # posto del battitore e verso in cui guarda (quelli di setRestart)
	var sy: float = 0.0
	var sfx: float = 0.0
	var sfy: float = 1.0
	var kx: float = 0.0        # posto del pallone da calciare (quello di setRestart)
	var ky: float = 0.0
	var posato: bool = false   # pallone fermo a terra in (kx, ky) anche se è del battitore (appoggiato o da raccogliere)
	var rimando: bool = false  # il raccattapalle ha già rimandato il pallone
	var raccatta: bool = false # il pallone lo va a prendere il raccattapalle (raccatta.gd), non il battitore
	var rinc: bool = false     # il battitore è indietro di qualche passo: al calcio prende la rincorsa
	var pend: Variant = null   # calcio chiesto durante la rincorsa: parte quando arriva sul pallone


	## battitore arrivato al posto col pallone (appoggiato o in mano): da qui si vede come una ripresa ferma
	func sulPosto() -> bool:
		return scena == "" or scena == "posa" or scena == "indietro"


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


# raccattapalle (raccatta.gd, opzione "riprese"): non è un giocatore della partita, sta fuori dal campo. I campi da
# `team` a `src` hanno gli stessi nomi di Player perché la figura della grafica (figura.gd) li legge allo stesso modo
class Raccatta:
	extends RefCounted
	var team: int = -1
	var i: int = 0             # 0 = dietro la porta in basso (y < 0), 1 = in alto
	var name: String = "raccattapalle"
	var pos: String = "R"
	var state: String = "play"
	var src: Dictionary = {}
	var x: float = 0.0
	var y: float = 0.0
	var vx: float = 0.0
	var vy: float = 0.0
	var fx: float = 0.0
	var fy: float = 1.0
	var t: float = 0.0
	var kickAnim: float = 0.0  # lancio appena partito (come il calcio di un giocatore)
	var sprint: bool = false
	var cele: int = 0
	var warn: bool = false
	var off: bool = false
	var dive: Dive = null
	var hx: float = 0.0        # il suo posto (seduto davanti ai cartelloni)
	var hy: float = 0.0
	var spd: float = 0.0       # velocità attuale (m/s)
	# "fermo" al posto, "va" verso il pallone, "raccogli" chinato, "mira" col pallone in mano girato verso il battitore,
	# "lancia" pallone sopra la testa, "dopo" fermo dopo il lancio, "torna" camminando al posto
	var stato: String = "fermo"
	var st: float = 0.0        # tempo nello stato (s)
	var palla: bool = false    # ha il pallone in mano
