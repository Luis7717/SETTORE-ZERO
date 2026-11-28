# Nomi dei calciatori (Luis 2026-11-28, "aumenta i nomi, praticamente uno diverso per giocatore, prendi spunto da
# quelli reali"): nomi e cognomi comuni di vari paesi, come se ne leggono nei campionati veri, ma combinati a caso
# (nessun calciatore vero: niente cognomi di campioni famosi). Il cognome decide il paese e il nome si sceglie tra
# quelli dello stesso paese, così "L. Ferrante" o "C. Okafor" e non "S. Esposito" con un nome svedese. Con circa 800
# cognomi e l'iniziale del nome, in un campionato due giocatori con lo stesso nome sono rarissimi.
# Usati da Carriera.randomName (stessi due numeri casuali di prima: la sequenza del seme non cambia).
extends RefCounted

# [nomi, cognomi] per paese; più cognomi = paese più frequente (gli italiani sono la maggior parte)
const PAESI: Array = [
	# Italia
	[["Luca", "Marco", "Matteo", "Andrea", "Davide", "Simone", "Paolo", "Stefano", "Fabio", "Giorgio", "Nicola",
	"Pietro", "Tommaso", "Elia", "Samuele", "Enrico", "Dario", "Michele", "Riccardo", "Daniele", "Emanuele",
	"Cristian", "Alessio", "Filippo", "Gabriele", "Lorenzo", "Mattia", "Edoardo", "Jacopo", "Vittorio", "Federico",
	"Francesco", "Alessandro", "Leonardo", "Giacomo", "Manuel", "Christian", "Antonio", "Giuseppe", "Salvatore",
	"Raffaele", "Vincenzo", "Gianluca", "Roberto", "Massimo", "Claudio", "Sergio", "Mirko", "Ivan", "Diego",
	"Nicolò", "Kevin", "Denis", "Valerio", "Ludovico", "Cesare", "Giovanni", "Alberto", "Carlo", "Fabrizio",
	"Igor", "Marcello", "Ruggero", "Ettore", "Brando", "Luigi", "Tiziano", "Walter", "Gennaro", "Domenico"],
	["Ferrante", "Morandi", "Castoldi", "Bellucci", "Rinaldi", "Sartori", "Galvani", "Pedretti", "Zanella", "Corradi",
	"Mazzoleni", "Tessari", "Bonfanti", "Carrara", "Negri", "Valsecchi", "Lodi", "Fumagalli", "Brambilla", "Ronchi",
	"Pagani", "Stella", "Orlandi", "Vitali", "Marchetti", "Donati", "Ferri", "Gatti", "Monti", "Pellegrini",
	"Barone", "Serra", "Fontana", "Basile", "Caruso", "Rizzi", "Santoro", "Esposito", "Romano", "Colombo",
	"Ricci", "Marino", "Greco", "Bruno", "Gallo", "Conti", "De Luca", "Mancini", "Costa", "Giordano", "Rizzo",
	"Lombardi", "Moretti", "Barbieri", "Fontanella", "Mariani", "Martinelli", "Leone", "Longo", "Gentile",
	"Martini", "Vitale", "Ferrara", "Coppola", "De Santis", "D'Angelo", "Marchi", "Parisi", "Villa", "Conte",
	"Ferraro", "Fabbri", "Bianco", "Marini", "Grasso", "Valentini", "Messina", "Sala", "De Angelis", "Gatto",
	"Pellegrino", "Palumbo", "Sanna", "Farina", "Rinaldo", "Cattaneo", "Silvestri", "Benedetti", "Testa",
	"Bernardi", "Guerra", "Amato", "Fiore", "Grassi", "Neri", "Bellini", "Riva", "Pace", "Cirillo", "Galli",
	"Monaco", "Mazza", "Sorrentino", "Cristiani", "Montanari", "Guidi", "Morelli", "Ruggiero", "Orlando",
	"Bassi", "Rossetti", "Sartorello", "Bonetti", "Carbone", "Melis", "Piras", "Mele", "Ferretti", "Ruggeri",
	"Riccardi", "Bianchini", "Tosi", "Zanotti", "Baldini", "Pozzi", "Brunetti", "Volpe", "Colonna",
	"Vianello", "Zanon", "Bortolotti", "Toffolo", "Dal Bello", "Facchinetti", "Gregori", "Lazzari", "Lupo",
	"Mantovani", "Merlo", "Nava", "Oliva", "Parodi", "Perego", "Pini", "Poli", "Rota", "Salvi", "Scotti",
	"Spinelli", "Tagliaferri", "Tremolada", "Venturi", "Zampieri", "Zoppi", "Albertazzi", "Bonomi", "Cavalli",
	"Cesari", "Corsi", "Crespi", "D'Amico", "Fadda", "Fraschini", "Gamba", "Ghezzi", "Invernizzi", "Locati",
	"Magri", "Manzoni", "Meloni", "Mosca", "Nardi", "Padovani", "Paris", "Peretti", "Pinna", "Porcu", "Raimondi",
	"Rossini", "Santini", "Sassi", "Sciortino", "Spada", "Tedesco", "Trevisan", "Usai", "Vacca", "Zorzi",
	"Abate", "Agostini", "Alessi", "Arena", "Bandini", "Belotto", "Bertolini", "Boschi", "Calabrese", "Capelli",
	"Carta", "Cavaliere", "Colella", "Cozzolino", "Di Lorenzi", "Di Mauro", "Esposti", "Falco", "Ferrandi",
	"Giuliani", "Iacobelli", "La Rosa", "Lanza", "Lo Russo", "Magnani", "Marras", "Miele", "Musumeci",
	"Pagano", "Picone", "Quaranta", "Ranieri", "Russo", "Scala", "Sorrenti", "Tortora", "Vignali", "Zappa"]],
	# Spagna
	[["Pablo", "Sergio", "Álvaro", "Javier", "Adrián", "Iker", "Unai", "Mikel", "Raúl", "Rubén", "Marcos", "Hugo",
	"Dani", "Álex", "Óscar", "Íñigo", "Gonzalo", "Borja", "Jorge", "Víctor", "Aitor", "Carlos", "Nacho", "Pedro"],
	["García", "Fernández", "López", "Martínez", "Sánchez", "Pérez", "Gómez", "Ruiz", "Díaz", "Moreno", "Muñoz",
	"Álvarez", "Romero", "Navarro", "Torres", "Domínguez", "Gil", "Vázquez", "Serrano", "Blanco", "Molina",
	"Ortega", "Delgado", "Castro", "Ortiz", "Rubio", "Marín", "Sanz", "Iglesias", "Medina", "Garrido", "Cortés",
	"Santos", "Guerrero", "Lozano", "Cano", "Prieto", "Méndez", "Calvo", "Vidal", "León", "Herrera", "Peña",
	"Cabrera", "Campos", "Vega", "Fuentes", "Carrasco", "Aguirre", "Etxeberria", "Goikoetxea", "Arrieta"]],
	# Portogallo e Brasile
	[["João", "Rui", "Nuno", "Tiago", "Diogo", "Bruno", "Gonçalo", "André", "Pedro", "Rafael", "Gabriel", "Lucas",
	"Matheus", "Vinícius", "Felipe", "Gustavo", "Caio", "Thiago", "Renan", "Wesley", "Everton", "Douglas"],
	["Silva", "Santos", "Ferreira", "Pereira", "Oliveira", "Costa", "Rodrigues", "Martins", "Jesus", "Sousa",
	"Fernandes", "Gonçalves", "Gomes", "Lopes", "Marques", "Alves", "Almeida", "Ribeiro", "Pinto", "Carvalho",
	"Teixeira", "Moreira", "Correia", "Mendes", "Nunes", "Soares", "Vieira", "Monteiro", "Cardoso", "Rocha",
	"Neves", "Coelho", "Cruz", "Cunha", "Pires", "Ramos", "Reis", "Simões", "Antunes", "Matos", "Fonseca",
	"Barbosa", "Araújo", "Duarte", "Batista", "Freitas", "Campos", "Azevedo", "Machado", "Moura"]],
	# Argentina, Uruguay, Colombia, Messico
	[["Mateo", "Santiago", "Matías", "Nicolás", "Facundo", "Agustín", "Joaquín", "Franco", "Lautaro", "Thiago",
	"Emiliano", "Rodrigo", "Gastón", "Ezequiel", "Julián", "Maximiliano", "Juan", "Sebastián", "Andrés", "Camilo"],
	["González", "Rodríguez", "Gutiérrez", "Acosta", "Benítez", "Flores", "Rojas", "Sosa", "Ramírez", "Giménez",
	"Villalba", "Ledesma", "Paredes", "Cabral", "Figueroa", "Ponce", "Quiroga", "Aguilar", "Correa", "Ojeda",
	"Cáceres", "Arias", "Peralta", "Bustos", "Valdez", "Maidana", "Escobar", "Restrepo", "Mosquera", "Valencia",
	"Hernández", "Jiménez", "Mendoza", "Salazar", "Cárdenas", "Montes"]],
	# Francia e Belgio
	[["Lucas", "Hugo", "Théo", "Antoine", "Maxime", "Killian", "Jules", "Clément", "Benjamin", "Mathis", "Yann",
	"Romain", "Florian", "Adrien", "Quentin", "Baptiste", "Aurélien", "Corentin", "Loïc", "Bastien"],
	["Moreau", "Martin", "Bernard", "Dubois", "Durand", "Leroy", "Lefebvre", "Girard", "Bonnet", "Dupont",
	"Lambert", "Fontaine", "Rousseau", "Vincent", "Muller", "Lefèvre", "Faure", "André", "Mercier", "Blanc",
	"Guérin", "Boyer", "Garnier", "Chevalier", "François", "Legrand", "Gauthier", "Perrin", "Robin", "Clément",
	"Morel", "Fournier", "Roussel", "Masson", "Marchand", "Duval", "Denis", "Lemoine", "Picard", "Renard",
	"Peeters", "Janssens", "Maes", "Claes", "Wouters", "Dupuis"]],
	# Germania, Austria, Svizzera
	[["Lukas", "Jonas", "Leon", "Niklas", "Felix", "Tim", "Jan", "Florian", "Kai", "Julian", "Maximilian", "Moritz",
	"Tobias", "Paul", "Lennart", "Nico", "Timo", "Dominik", "Fabian", "Stefan"],
	["Schmidt", "Schneider", "Fischer", "Weber", "Meyer", "Wagner", "Becker", "Schulz", "Hoffmann", "Koch",
	"Richter", "Klein", "Wolf", "Schröder", "Neumann", "Schwarz", "Zimmermann", "Braun", "Krüger", "Hartmann",
	"Lange", "Werner", "Krause", "Lehmann", "Köhler", "Herrmann", "Walter", "Mayer", "Huber", "Kaiser", "Fuchs",
	"Peters", "Lang", "Scholz", "Möller", "Weiß", "Jung", "Hahn", "Vogel", "Friedrich", "Keller", "Günther",
	"Frank", "Berger", "Winkler", "Roth", "Beck", "Lorenz", "Baumann", "Brunner"]],
	# Olanda
	[["Daan", "Sem", "Bram", "Luuk", "Jesse", "Thijs", "Stijn", "Joris", "Ruben", "Wout", "Teun", "Milan"],
	["de Jong", "Jansen", "de Vries", "van den Berg", "van Dijkman", "Bakker", "Visser", "Smit", "Meijer",
	"de Boer", "Mulder", "de Groot", "Bos", "Vos", "Hendriks", "van Leeuwen", "Dekker", "Brouwer",
	"de Wit", "Dijkstra", "Smits", "de Graaf", "van der Meer", "Kok", "Jacobs", "Vermeulen", "van Beek"]],
	# Inghilterra, Scozia, Irlanda
	[["Jack", "Harry", "Oliver", "George", "Charlie", "James", "Thomas", "Callum", "Connor", "Liam", "Ryan",
	"Jordan", "Mason", "Reece", "Kieran", "Declan", "Ben", "Josh", "Luke", "Aaron"],
	["Smith", "Jones", "Taylor", "Brown", "Williams", "Wilson", "Johnson", "Davies", "Robinson", "Wright",
	"Thompson", "Evans", "Walker", "White", "Roberts", "Green", "Hall", "Wood", "Jackson", "Clarke", "Harris",
	"Lewis", "Hughes", "Turner", "Hill", "Cooper", "Ward", "Morris", "Moore", "Baker", "Murphy", "Kelly",
	"Byrne", "Walsh", "O'Brien", "Doyle", "McCarthy", "Campbell", "Stewart", "Fraser", "McKenzie"]],
	# Scandinavia e Finlandia
	[["Sven", "Erik", "Oscar", "Viktor", "Emil", "Mathias", "Kasper", "Anders", "Mikkel", "Jesper", "Henrik",
	"Magnus", "Rasmus", "Joakim", "Elias", "Axel"],
	["Lindqvist", "Johansson", "Andersson", "Karlsson", "Nilsson", "Eriksson", "Larsson", "Olsson", "Persson",
	"Svensson", "Gustafsson", "Pettersson", "Jonsson", "Hansen", "Nielsen", "Jensen", "Pedersen", "Andersen",
	"Christensen", "Larsen", "Sørensen", "Rasmussen", "Johansen", "Olsen", "Berg", "Haugen", "Dahl", "Lund",
	"Bakke", "Strand", "Virtanen", "Korhonen", "Nieminen", "Mäkinen"]],
	# Balcani ed Europa dell'Est
	[["Luka", "Ivan", "Milan", "Marko", "Nikola", "Stefan", "Filip", "Dušan", "Aleksandar", "Josip", "Mateo",
	"Ante", "Dejan", "Bojan", "Jakub", "Kacper", "Piotr", "Tomáš", "Ondřej", "Andrei", "Bogdan", "Dmytro",
	"Oleksandr", "Artem", "Giorgi", "Arda", "Lirim", "Besnik"],
	["Novak", "Petrov", "Kovač", "Horvat", "Jovanović", "Petrović", "Nikolić", "Marković", "Đorđević", "Stojanović",
	"Ilić", "Pavlović", "Babić", "Knežević", "Vuković", "Popović", "Kovačević", "Perić", "Jurić", "Marić",
	"Božić", "Tomić", "Radić", "Lukić", "Šimić", "Kralj", "Krasniqi", "Berisha", "Gashi", "Hoxha", "Kowalski",
	"Nowak", "Wiśniewski", "Wójcik", "Kamiński", "Lewicki", "Zieliński", "Szymański", "Dvořák", "Svoboda",
	"Novotný", "Procházka", "Kuznetsov", "Popescu", "Ionescu", "Stan", "Savchenko", "Bondarenko", "Kovalenko",
	"Tkachenko", "Melnyk", "Beridze", "Kapanadze", "Ivanov", "Georgiev", "Dimitrov", "Kolev", "Szabó", "Nagy",
	"Tóth", "Varga", "Horváth"]],
	# Turchia, Nord Africa, Medio Oriente
	[["Emre", "Mehmet", "Burak", "Kerem", "Yusuf", "Ömer", "Can", "Hakan", "Karim", "Omar", "Youssef", "Anas",
	"Hakim", "Sofiane", "Rayan", "Ismaël", "Bilal", "Nabil", "Amine", "Mohamed", "Ali", "Hamza"],
	["Yilmaz", "Kaya", "Demir", "Şahin", "Çelik", "Yıldız", "Öztürk", "Aydın", "Arslan", "Doğan", "Kılıç",
	"Aslan", "Çetin", "Koç", "Kurt", "Özdemir", "Benali", "El Amrani", "Bennani", "Zeroual", "Haddad", "Mansour",
	"Belkacem", "Brahmi", "Bensaïd", "Cherif", "Marzouk", "Bouzid", "Saïdi", "Nasser", "Toumi", "Hamdi",
	"El Idrissi", "Ouali", "Khalil", "Said"]],
	# Africa subsahariana
	[["Kofi", "Abdou", "Moussa", "Ibrahima", "Cheikh", "Saliou", "Kwame", "Yaw", "Samuel", "Emmanuel", "Victor",
	"Wilfried", "Franck", "Serge", "Désiré", "Thomas", "Joseph", "Ousmane", "Mamadou", "Idrissa", "Chidi",
	"Obinna", "Tariq", "Yves", "Patrick", "Christopher"],
	["Diallo", "Mensah", "Okoye", "Traoré", "Koné", "Coulibaly", "Diarra", "Touré", "Camara", "Keita", "Sylla",
	"Cissé", "Ndiaye", "Diop", "Fall", "Sarr", "Gueye", "Faye", "Mbaye", "Sow", "Bamba", "Kouassi", "Yao",
	"Konaté", "Fofana", "Bangoura", "Sangaré", "Doumbia", "Diabaté", "Sissoko", "Owusu", "Asante", "Boakye",
	"Appiah", "Amoah", "Agyeman", "Osei", "Adjei", "Okafor", "Eze", "Nwosu", "Okonkwo", "Adeyemi", "Balogun",
	"Ogunleye", "Onyeka", "Nduka", "Musa", "Mbemba", "Kabongo", "Mukendi", "Tshibola", "Nkoulou", "Essomba",
	"Mbarga", "Ondoa", "Aboubakar", "Kamara", "Bah", "Barry", "Conteh", "Mwangi", "Otieno", "Banda"]],
	# Giappone, Corea, Australia e Stati Uniti
	[["Takumi", "Daichi", "Kaoru", "Ritsu", "Hiroki", "Min-ho", "Jae-sung", "Seung-woo", "Tyler", "Brandon",
	"Caleb", "Riley", "Mitchell", "Jackson"],
	["Tanaka", "Suzuki", "Watanabe", "Ito", "Yamamoto", "Nakamura", "Kobayashi", "Kato", "Yoshida", "Yamada",
	"Sasaki", "Matsumoto", "Inoue", "Kim", "Lee", "Park", "Choi", "Jung", "Kang", "Cho", "Yoon", "Miller",
	"Anderson", "Garrett", "Sullivan", "Bennett", "Russell"]],
]


static var _cognomi: Array = []   # [cognome, indice del paese] di tutti i paesi in fila (preparato al primo uso)


static func _prepara() -> void:
	if not _cognomi.is_empty():
		return
	var visti := {}
	for i in PAESI.size():
		for c: String in PAESI[i][1]:
			if not visti.has(c): # lo stesso cognome in due paesi (Costa, Santos, ...) conta una volta sola
				visti[c] = true
				_cognomi.append([c, i])


## nome breve "L. Ferrante" dai due numeri casuali a, b in [0, 1): b sceglie il cognome (e il paese), a il nome tra
## quelli del paese
static func nome(a: float, b: float) -> String:
	_prepara()
	var c: Array = _cognomi[mini(int(floor(b * _cognomi.size())), _cognomi.size() - 1)]
	var nomi: Array = PAESI[c[1]][0]
	var n: String = nomi[mini(int(floor(a * nomi.size())), nomi.size() - 1)]
	return n.left(1) + ". " + String(c[0])


## quanti cognomi in tutto (per i test)
static func quanti_cognomi() -> int:
	_prepara()
	return _cognomi.size()
