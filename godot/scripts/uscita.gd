# Uscita pulita dal programma (prove da riga di comando e fine programma).
#
#   Uscita.libera_cache_grafiche()   lascia le risorse grafiche tenute in variabili static (materiali, mesh,
#                                     texture, animazioni). Niente attese: va bene anche da _exit_tree (App, partita)
#   Uscita.esci(albero, codice)      uscita delle prove (--esci-dopo, --schermata, --esci-a-fine): toglie la scena,
#                                     aspetta qualche fotogramma che materiali e shader vengano liberati davvero,
#                                     svuota le cache, sincronizza il server grafico e solo dopo esce
#
# Perché: sul Mac della build (Godot 4.7.2, --headless) a volte all'uscita restava uno shader vivo dopo lo
# spegnimento del server grafico ("1 RID allocations of type ...DummyShader... were leaked at exit") e la prova
# falliva. Liberando tutto prima di quit() l'uscita non dipende più dall'ordine e dai tempi di chiusura del motore.
# Sul telefono non cambia niente: l'app non esce da qui (solo App._exit_tree chiama libera_cache_grafiche).
class_name Uscita
extends RefCounted

const FOTOGRAMMI_SCENA := 4     # fotogrammi dopo aver tolto la scena (queue_free, code dei materiali, suoni fermati)
const FOTOGRAMMI_CACHE := 2     # fotogrammi dopo aver svuotato le cache static

# script con risorse grafiche in variabili static: ognuno ha `static func libera_condivisi()`
const CON_CACHE := [
	"res://scripts/giocatore.gd",
	"res://scripts/partita/capelli.gd",
	"res://scripts/partita/figura.gd",
	"res://scripts/partita/figura_mocap.gd",
	"res://scripts/partita/texture_vista.gd",
	"res://scripts/menu/svg.gd",
]

static var _in_corso := false


## lascia le risorse grafiche static. Si toccano solo gli script già caricati (uno non caricato non ha niente da
## lasciare, e caricarlo adesso porterebbe dentro i suoi preload)
static func libera_cache_grafiche() -> void:
	for percorso: String in CON_CACHE:
		if ResourceLoader.has_cached(percorso):
			var s: Script = load(percorso)
			if s != null:
				s.call("libera_condivisi")


## esce dal programma dopo aver tolto la scena e lasciato le risorse grafiche. Da chiamare senza await: gira come
## funzione static (non muore con la scena che toglie). Una seconda chiamata mentre la prima è in corso non fa niente.
static func esci(albero: SceneTree, codice: int = 0) -> void:
	if _in_corso or albero == null:
		return
	_in_corso = true
	# via la scena (partita o menu) e ogni altro nodo che non è un autoload: i loro _exit_tree lasciano vista,
	# stadio, giocatori, HUD
	for n: Node in albero.root.get_children():
		if not ProjectSettings.has_setting("autoload/" + String(n.name)):
			n.queue_free()
	for i in FOTOGRAMMI_SCENA:
		await albero.process_frame
	libera_cache_grafiche()
	for i in FOTOGRAMMI_CACHE:
		await albero.process_frame
	# esegue i comandi grafici rimasti in coda (liberazioni chieste da altri thread)
	RenderingServer.force_sync()
	albero.quit(codice)
