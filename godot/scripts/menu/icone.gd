# Icone e disegni dei menu (gli stessi SVG di src/ui.js): icone delle caselle, maglia per la scelta dei colori,
# pallone e campo del titolo, coppa di fine stagione, disegni di "Come si gioca".
class_name MenuIcone
extends RefCounted

const D := preload("res://scripts/menu/menu_dati.gd")
const NS := 'xmlns="http://www.w3.org/2000/svg"'

# icone a tratto 24×24 (ICONS di ui.js)
const ICONS := {
	"squad": '<path d="M8 3l-5 3 2 4 3-1v11h8V9l3 1 2-4-5-3c-1 2-2 3-4 3S9 5 8 3z"/>',
	"market": '<path d="M4 8h14M14 4l4 4-4 4M20 16H6m4-4l-4 4 4 4"/>',
	"table": '<path d="M5 20V10M12 20V4M19 20v-7"/>',
	"calendar": '<rect x="3.5" y="5" width="17" height="15" rx="3"/><path d="M3.5 10h17M8 3v4M16 3v4"/>',
	"friendly": '<circle cx="12" cy="12" r="9"/><path d="M12 8l3.5 2.5-1.3 4h-4.4l-1.3-4z"/>',
	"vs": '<circle cx="8" cy="8" r="3"/><circle cx="16" cy="9" r="3"/><path d="M2.5 20c0-4 2.5-6 5.5-6s5.5 2 5.5 6M14 14.5c.7-.3 1.4-.5 2-.5 3 0 5.5 2 5.5 6"/>',
	"howto": '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 115 0c0 1.7-2.5 2-2.5 4M12 17h.01"/>',
	"settings": '<path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2.2"/><circle cx="9" cy="17" r="2.2"/>',
}
# disegni di "Come si gioca" (HOW_ILL), 80×80 a tratto
const HOW_ILL := [
	'<path d="M16 62C28 14 58 14 62 48"/><path d="M52 42l10 8 6-12"/><circle cx="16" cy="62" r="6"/>',
	'<circle cx="40" cy="40" r="7"/><circle cx="40" cy="40" r="19" opacity=".6"/><circle cx="40" cy="40" r="31" opacity=".3"/>',
	'<path d="M40 8l25 10v22c0 16-12 26-25 32C27 66 15 56 15 40V18z"/><path d="M28 40l8 8 16-16"/>',
	'<path d="M14 58L60 26"/><path d="M45 24l17 1-6 16"/><circle cx="14" cy="58" r="5"/>',
	'<path d="M10 66V22h60v44"/><path d="M10 34h60M30 22v12M50 22v12" opacity=".35"/><circle cx="40" cy="52" r="8"/>',
]


static func icona(nome: String, colore := "#ffffff", spessore := 1.9) -> String:
	return '<svg %s width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % [NS, colore, spessore, ICONS.get(nome, "")]


static func illustrazione(i: int) -> String:
	return '<svg %s width="80" height="80" viewBox="0 0 80 80" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round">%s</svg>' % [NS, HOW_ILL[clampi(i, 0, HOW_ILL.size() - 1)]]


static func play(colore := "#15130a") -> String:
	return '<svg %s width="24" height="24" viewBox="0 0 24 24"><path d="M7 4.5v15l13-7.5z" fill="%s"/></svg>' % [NS, colore]


## maglia coi colori di un elemento di KITS (scelta dei colori nella nuova carriera)
static func maglia(k: Array) -> String:
	var a := D.hex(int(k[1]))
	var b := D.hex(int(k[2]))
	return ('<svg %s width="40" height="40" viewBox="0 0 40 40"><path d="M13 4q7 5 14 0l10 5 4 9-6 3-2-3v18H9V18l-2 3-6-3 4-9z" fill="%s" stroke="#fff" stroke-opacity=".5" stroke-width="1.4" stroke-linejoin="round"/>'
		+ '<path d="M13 4q7 5 14 0" fill="none" stroke="%s" stroke-width="2.6"/><path d="M1 18l6 3M39 18l-6 3" stroke="%s" stroke-width="3"/></svg>') % [NS, a, b, b]


static func coppa() -> String:
	return ('<svg %s width="64" height="64" viewBox="0 0 64 64"><path d="M18 8h28v14c0 9-6 16-14 16s-14-7-14-16z" fill="#ffd93d"/>'
		+ '<path d="M18 12H8c0 9 4 14 12 15M46 12h10c0 9-4 14-12 15" fill="none" stroke="#ffd93d" stroke-width="3.5"/>'
		+ '<path d="M28 38h8v8h-8z" fill="#e0b412"/><rect x="20" y="46" width="24" height="8" rx="3" fill="#ffd93d"/>'
		+ '<path d="M24 14v10" stroke="#fff" stroke-opacity=".5" stroke-width="3" stroke-linecap="round"/></svg>') % NS


static func pallone() -> String:
	return ('<svg %s width="64" height="64" viewBox="0 0 64 64"><circle cx="32" cy="32" r="29" fill="#f6f8fc"/>'
		+ '<path d="M32 19l11 8-4 13H25l-4-13z" fill="#111827"/>'
		+ '<path d="M32 19V6M43 27l13-4M39 40l8 11M25 40l-8 11M21 27L8 23" stroke="#111827" stroke-width="2.4" fill="none" stroke-linecap="round"/>'
		+ '<circle cx="32" cy="32" r="29" fill="none" stroke="#ffd93d" stroke-width="3"/></svg>') % NS


static func campo_titolo() -> String:
	return ('<svg %s width="400" height="300" viewBox="0 0 400 300" fill="none" stroke="#ffffff" stroke-opacity=".12" stroke-width="2">'
		+ '<rect x="20" y="10" width="360" height="280" rx="8"/><path d="M20 150h360"/><circle cx="200" cy="150" r="46"/>'
		+ '<rect x="120" y="10" width="160" height="56"/><rect x="120" y="234" width="160" height="56"/></svg>') % NS
