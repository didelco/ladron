class_name Story
extends RefCounted
## The story mode: ten nights, each a fixed museum and a fixed piece, from
## one sleepy guard in a small museum to five wide-awake ones in a big one.
##
## The tale, for kids: the Banda del Calcetín only steals what was stolen
## first. The Barón Von Bostezo, director of the Museo de Cosas Rarísimas,
## has taken ten things from the town and put them in glass cases; one a
## night, the gang takes them back.

const PROLOGUE := "Esta es la Banda del Calcetín: ladrones que solo roban lo que ya estaba robado.\n\nEl Barón Von Bostezo, director del Museo de Cosas Rarísimas, se ha ido llevando las cosas más raras del pueblo para exponerlas en vitrinas. Diez en total.\n\nEsta noche empieza la operación DEVOLVERLO TODO."

const ENDING := "¡Lo habéis conseguido!\n\nEl abuelo Paco vuelve a masticar turrón, el pato canta a las siete en punto, el yeti tiene los pies calentitos y los lunes vuelven a durar lo normal.\n\nAl Barón Von Bostezo solo le quedó mirar su vitrina vacía... y bostezar. Se quedó dormido de pie. Dicen que todavía ronca.\n\nFIN (de momento)"

## Each night: museum size and shape, how many guards, their senses and pace
## (Sim.tuning keys), and the piece.
const LEVELS := [
	{"size": "small", "shape": "rect", "guards": 1, "view": 0.6, "hearing": 0.55, "speed": 0.55, "calm_after": 5.0, "alarms": 3,
		"loot": {"name": "la dentadura del abuelo Paco", "blurb": "Postiza, de porcelana. Brilla en la oscuridad.", "verb": "DESENROSCANDO EL TARRO", "seconds": 1.5, "colour": "#f4f1e6", "shape": "teeth",
			"story": "Anoche el Barón le quitó la dentadura al abuelo Paco mientras roncaba. Desde entonces el abuelo solo come sopa y a todo contesta «mmmfff». Hoy hay un solo guardia y está medio dormido. Perfecto para empezar."}},
	{"size": "small", "shape": "L", "guards": 1, "view": 0.7, "hearing": 0.65, "speed": 0.62, "calm_after": 6.0, "alarms": 3,
		"loot": {"name": "el pato que canta ópera", "blurb": "Amarillo, de goma, con voz de tenor.", "verb": "CALMANDO AL PATO", "seconds": 2.0, "colour": "#ffd43b", "shape": "duck",
			"story": "Cada mañana este pato cantaba ópera a las siete en punto y despertaba a todo el pueblo. Sin él nadie se levanta y el panadero ya ha quemado cuarenta barras de pan. Cuidado: si lo aprietas, da el do de pecho."}},
	{"size": "small", "shape": "T", "guards": 2, "view": 0.75, "hearing": 0.72, "speed": 0.68, "calm_after": 7.0, "alarms": 3,
		"loot": {"name": "el calcetín del yeti", "blurb": "Talla 98. Huele un poquito.", "verb": "DOBLANDO EL CALCETÍN", "seconds": 2.5, "colour": "#dee2e6", "shape": "sock",
			"story": "Un yeti muy educado se lo dejó en la lavandería y el Barón lo expone como «alfombra prehistórica». Ahora el yeti tiene frío en un pie y cada vez que estornuda provoca una avalancha. Esta noche hay dos guardias."}},
	{"size": "medium", "shape": "U", "guards": 2, "view": 0.82, "hearing": 0.8, "speed": 0.75, "calm_after": 8.0, "alarms": 2,
		"loot": {"name": "la tostada con la cara del Barón", "blurb": "Con mantequilla. El Barón dice que es arte.", "verb": "DESPEGANDO LA TOSTADA", "seconds": 3.0, "colour": "#d4a15a", "shape": "toast",
			"story": "En esta tostada se ve clavadita la cara del Barón. Él dice que es una obra de arte. En realidad era el desayuno del perro Bartolo, que lleva tres días mirando la vitrina y llorando. El museo es más grande: solo te quedan dos ruidos."}},
	{"size": "medium", "shape": "notched", "guards": 2, "view": 0.88, "hearing": 0.88, "speed": 0.8, "calm_after": 9.0, "alarms": 2,
		"loot": {"name": "la corona de la Reina de los Pepinillos", "blurb": "Verde, con granitos. Muy real.", "verb": "DESATORNILLANDO", "seconds": 3.5, "colour": "#7bc043", "shape": "crown",
			"story": "La Reina de los Pepinillos manda en el huerto del pueblo. Sin su corona los pepinillos no le hacen caso, y se pasan la noche bailando la conga por las calles. Nadie consigue dormir."}},
	{"size": "medium", "shape": "cross", "guards": 3, "view": 0.94, "hearing": 0.95, "speed": 0.86, "calm_after": 10.0, "alarms": 2,
		"loot": {"name": "el meteorito que huele a queso", "blurb": "Cayó del cielo sobre la quesería.", "verb": "ENGAÑANDO AL SENSOR", "seconds": 4.0, "colour": "#ffe066", "shape": "rock",
			"story": "Huele tanto a queso que los ratones de tres pueblos se han mudado al museo. Un astrónomo ratón lo necesita para demostrar por fin que la Luna es de queso. Atención: ya son tres guardias."}},
	{"size": "medium", "shape": "L", "guards": 3, "view": 1.0, "hearing": 1.0, "speed": 0.92, "calm_after": 11.0, "alarms": 2,
		"loot": {"name": "la máscara del Pulpo Enmascarado", "blurb": "Del luchador más famoso del mundo.", "verb": "CORTANDO EL SELLO", "seconds": 4.5, "colour": "#9b5de5", "shape": "mask",
			"story": "El Pulpo Enmascarado tiene ocho brazos y ninguna gana de enseñar la cara. Sin su máscara no puede salir al ring, y lleva una semana escondido detrás de una maceta. Sus fans están desesperados."}},
	{"size": "large", "shape": "T", "guards": 3, "view": 1.06, "hearing": 1.07, "speed": 0.98, "calm_after": 12.0, "alarms": 1,
		"loot": {"name": "el reloj que va hacia atrás", "blurb": "Hace tic-tac al revés: cat-cit.", "verb": "PARANDO LAS AGUJAS", "seconds": 5.0, "colour": "#4dabf7", "shape": "clock",
			"story": "Con este reloj el Barón consigue que los lunes duren el doble. Si no lo recuperáis, pronto la semana tendrá nueve lunes y ningún sábado. ¡Eso sí que no! Museo grande y un solo ruido: los guardias se ponen serios."}},
	{"size": "large", "shape": "U", "guards": 4, "view": 1.12, "hearing": 1.14, "speed": 1.04, "calm_after": 13.0, "alarms": 1,
		"loot": {"name": "el huevo del dinosaurio despistado", "blurb": "Setenta millones de años. Aún está calentito.", "verb": "SOLTANDO EL HUEVO", "seconds": 5.5, "colour": "#e8c89a", "shape": "egg",
			"story": "Una mamá diplodocus lo dejó en un aparcamiento hace setenta millones de años y ha vuelto a buscarlo. Está en la puerta del museo, muy seria, pisando coches sin querer. Devolvédselo antes de que pise el vuestro."}},
	{"size": "large", "shape": "cross", "guards": 5, "view": 1.18, "hearing": 1.22, "speed": 1.1, "calm_after": 15.0, "alarms": 1,
		"loot": {"name": "el Diamante Bostezo", "blurb": "Quien lo mira, bosteza y se duerme.", "verb": "ABRIENDO LA CAJA FUERTE", "seconds": 6.0, "colour": "#74c0fc", "shape": "gem",
			"story": "Es el tesoro del Barón y su gran truco: con él dormía a todo el pueblo para llevarse lo que quería. Sin el diamante se le acabaron los trucos. Pero es la última noche, hay cinco guardias bien despiertos... y os están esperando."}},
]

## Each night's museum is always the same one.
const SEED_BASE := 424242

const SAVE := "user://progress.cfg"


static func count() -> int:
	return LEVELS.size()


static func level(n: int) -> Dictionary:
	return LEVELS[clampi(n, 1, LEVELS.size()) - 1]


static func seed_for(n: int) -> int:
	return SEED_BASE + n * 7919


## The senses and pace of the guards on night n, as Sim.custom.
static func tuning(n: int) -> Dictionary:
	var l := level(n)
	var out := {"lock": 1.0}
	for k in ["guards", "view", "hearing", "speed", "calm_after", "alarms"]:
		out[k] = l[k]
	return out


## The furthest night reached, saved between sessions.
static func unlocked() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) != OK:
		return 1
	return clampi(int(cfg.get_value("story", "unlocked", 1)), 1, LEVELS.size())


static func unlock(n: int) -> void:
	if n <= unlocked():
		return
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	cfg.set_value("story", "unlocked", clampi(n, 1, LEVELS.size()))
	cfg.save(SAVE)
