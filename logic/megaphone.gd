class_name Megaphone
extends RefCounted
## La megafonía del museo: avisos de una frase, absurdos, que salen por el
## altavoz de vez en cuando. Solo texto: aquí se decide qué aviso toca y
## cuándo, y quien pinta (Hud.megaphone) solo lo enseña. Es algo especial,
## no un hilo musical: habla poco, y cada aviso debe sorprender.
##
## Dos clases de aviso, los dos con su tipo (KINDS) y su prioridad:
##  - Sucesos del robo (say): una luz, la alarma, un estornudo... Salen
##    cuando toca el hueco (GAP_S), y los de peligro (URGENT) cortan tras
##    CUT_S. Sin sucesos, con calma, salen ocurrencias raras (idle, pistas
##    del museo y frases sueltas).
##  - Reacciones a lo que hace el ladrón (act): una voltereta, chocar con la
##    pared, tirar una papelera, esconderse en una armadura... Llegan pronto
##    (ACT_DELAY_S), pero solo a veces (su probabilidad en ACTS), con su
##    enfriamiento propio, si ya ha pasado el hueco general y sin pasar del
##    tope por robo. Cuanto más se repite la acción, distinta frase (las de
##    "otra vez"), y las rachas (3 choques...) tienen las suyas.
##
## La megafonía no ve a nadie: comenta lo que nota (un choque, un estornudo,
## una papelera que cae) sin llamar ninja, ladrón ni banda a nadie, ni
## nombrarlo por su color, ni hablarle de tú (alguien, algo, un bulto...).
##
## Las frases son MEGA_<TIPO>_<NN> en locale/texts.csv; POOLS dice cuántas hay
## de cada tipo (tests/test_megafonia.gd lo comprueba con el CSV).
##
## Ninguna frase se repite: ni en el mismo robo ni en el siguiente (la
## memoria es estática, de la sesión). Si a un tipo no le quedan frases
## nuevas, calla antes que repetir.

## Como poco, tantos segundos entre dos avisos normales (reacciones y
## sucesos): la megafonía es especial, no un hilo musical.
const GAP_S := 40.0
## Como poco, tantos entre dos avisos de peligro (URGENT): te ven, alarma.
const CUT_S := 15.0
## Un suceso que espera el hueco se olvida pasados estos segundos.
const STALE_S := 6.0
## Una reacción sale tantos segundos tras lo que la causa (pronto, pero
## después del golpe), y se olvida si no ha salido en ACT_STALE_S.
const ACT_DELAY_S := 1.2
const ACT_STALE_S := 3.0
## Al empezar el robo la megafonía calla un buen rato: se elige al azar (con
## la semilla) un retardo entre INTRO_MIN_S y INTRO_MAX_S, y hasta entonces
## no sale nada: ni el saludo (que sale al acabar el retardo), ni reacciones,
## ni ocurrencias. Los avisos de peligro (URGENT: te ven, alarma...) solo
## esperan INTRO_MIN_S, no el resto del retardo. En el primer robo, más.
const INTRO_MIN_S := 20.0
const INTRO_MAX_S := 60.0
const TUTORIAL_INTRO_MIN_S := 40.0
const TUTORIAL_INTRO_MAX_S := 90.0
## Sin nada que contar: cada cuánto sale como mucho una ocurrencia, cuánto
## quieto hasta que se comenta, y cada cuánto se repite eso. Cuentan desde
## el final del retardo inicial o desde el último aviso.
const CALM_EVERY_S := 120.0
const IDLE_AFTER_S := 25.0
const IDLE_EVERY_S := 90.0
## El primer robo (sin guardias, para aprender): mucho más callada (los
## huecos se multiplican, las probabilidades se dividen y el tope es menor).
const TUTORIAL_FACTOR := 2.0
## Tope de avisos por robo: CAP_MIN al empezar, uno más cada CAP_EVERY_S de
## robo, hasta CAP_MAX; en el primer robo, TUTORIAL_CAP. Los de peligro
## pueden pasarse URGENT_EXTRA.
const CAP_MIN := 2
const CAP_MAX := 5
const CAP_EVERY_S := 60.0
const TUTORIAL_CAP := 2
const URGENT_EXTRA := 2
## A partir de esta prioridad un aviso es de peligro y puede cortar (CUT_S).
const URGENT := 60
## Tantas palabras como mucho por frase (sin contar lo que se rellene).
const MAX_WORDS := 12
## Las cosas que se hacen de seguido (a gatas, correr, ir de puntillas):
## tantos segundos sin parar hasta que se comentan.
const HOLD_S := 6.0

## Prioridad de cada aviso. Los act_* son reacciones: por debajo de URGENT
## (nunca tapan un peligro), por encima de las ocurrencias, y los de cada
## cosa por encima del suceso general que sale a la vez (knocked, sneeze...).
const KINDS := {
	"seen": 90, "alarm": 80, "stolen": 70, "near_exit": 65, "suspect": 60,
	"knocked": 55, "sneeze": 50, "dizzy": 45, "lights_on": 40, "lights_off": 40,
	"hide": 35, "smoke": 30, "panel": 30, "waiting": 30, "start": 20,
	"idle": 15, "calm": 10, "piece": 10, "team": 10,
	"act_roll": 32, "act_roll_streak": 40, "act_roll_wall": 47, "act_roll_case": 47,
	"act_crash_streak": 48,
	"act_knock_bin": 56, "act_knock_bust": 56, "act_knock_armour": 56, "act_knock_panel": 56,
	"act_knock_streak": 57,
	"act_hide_armour": 36, "act_hide_other": 36, "act_hide_seen": 37,
	"act_sneeze": 51, "act_smoke": 31, "act_smoke_last": 31, "act_smoke_empty": 31,
	"act_panel": 31, "act_case": 34, "act_switch_streak": 41,
	"act_plinth": 34, "act_plinth_fall": 46, "act_arcade": 30, "act_phew": 39,
	"act_crawl": 22, "act_run": 22, "act_sneak": 22,
}
## Los que hablan de guardias: sin guardias (el primer robo) no salen.
const GUARD_KINDS := ["seen", "suspect", "hide", "lights_on", "lights_off", "act_hide_seen", "act_phew"]
## Reacciones: [probabilidad de comentarla, enfriamiento propio en segundos].
## Más alta para lo raro o gracioso (rodar y chocar), más baja para lo que
## pasa a cada rato (esconderse, un humo, una voltereta). 0: solo cuenta
## para la racha.
const ACTS := {
	"roll": [0.08, 90.0], "roll_streak": [0.8, 120.0], "roll_wall": [0.6, 60.0],
	"roll_case": [0.6, 60.0], "crash_streak": [0.8, 120.0],
	"knock_bin": [0.3, 60.0], "knock_bust": [0.3, 60.0], "knock_armour": [0.3, 60.0],
	"knock_panel": [0.3, 60.0], "knock_streak": [0.7, 120.0],
	"hide_armour": [0.4, 90.0], "hide_other": [0.2, 90.0], "hide_seen": [0.4, 90.0],
	"sneeze": [0.7, 60.0], "smoke": [0.2, 60.0], "smoke_last": [0.4, 90.0],
	"smoke_empty": [0.5, 90.0], "panel": [0.25, 90.0], "case": [0.35, 90.0],
	"switch": [0.0, 0.0], "switch_streak": [0.7, 120.0],
	"plinth": [0.35, 90.0], "plinth_fall": [0.6, 60.0], "arcade": [0.3, 120.0],
	"phew": [0.4, 120.0], "crawl": [0.4, 180.0], "run": [0.4, 180.0], "sneak": [0.4, 180.0],
}
## A qué racha suma cada reacción, y la racha: [reacción, cuántas, en cuántos
## segundos]. La tercera vuelta, el tercer choque... es la racha.
const GROUPS := {
	"roll": "roll", "roll_wall": "crash", "roll_case": "crash",
	"knock_bin": "knock", "knock_bust": "knock", "knock_armour": "knock", "knock_panel": "knock",
	"switch": "switch",
}
const STREAKS := {
	"roll": ["roll_streak", 3, 15.0], "crash": ["crash_streak", 3, 60.0],
	"knock": ["knock_streak", 3, 30.0], "switch": ["switch_streak", 3, 30.0],
}
## Frases de cada tipo (las pistas del museo m, 1 a 5, son hint_m). De las
## reacciones, X_again (la acción repetida).
const POOLS := {
	"start": 5, "lights_on": 4, "lights_off": 4, "alarm": 5, "knocked": 5,
	"sneeze": 4, "stolen": 5, "piece": 6, "seen": 5, "suspect": 5, "hide": 4,
	"dizzy": 4, "smoke": 3, "panel": 3, "near_exit": 4, "idle": 6,
	"waiting": 3, "calm": 14, "team": 5,
	"hint_1": 8, "hint_2": 8, "hint_3": 8, "hint_4": 8, "hint_5": 8,
	"act_roll": 5, "act_roll_again": 6, "act_roll_streak": 6,
	"act_roll_wall": 11, "act_roll_wall_again": 7,
	"act_roll_case": 8, "act_roll_case_again": 5,
	"act_crash_streak": 6,
	"act_knock_bin": 5, "act_knock_bust": 5, "act_knock_armour": 5, "act_knock_panel": 5,
	"act_knock_again": 7, "act_knock_streak": 6,
	"act_hide_armour": 6, "act_hide_armour_again": 4, "act_hide_other": 6,
	"act_hide_other_again": 4, "act_hide_seen": 5,
	"act_sneeze": 8, "act_sneeze_again": 5,
	"act_smoke": 6, "act_smoke_last": 5, "act_smoke_empty": 6,
	"act_panel": 5, "act_case": 6, "act_switch_streak": 5,
	"act_plinth": 5, "act_plinth_fall": 5, "act_arcade": 5, "act_phew": 5,
	"act_crawl": 5, "act_run": 5, "act_sneak": 5,
}

## Lo dicho en el robo anterior y en este (las claves): no se repite. Estático:
## sobrevive de un robo al siguiente, mismo nivel o no.
static var _prev_round := {}
static var _this_round := {}

var night := 0
var museum := -1
var guards := 0
var players := 1
var piece := ""
## Pruebas: comentar siempre toda reacción (sin tirar la probabilidad).
var always := false
## Pruebas: si no es negativo, el retardo inicial en vez del sorteado.
static var intro_override := -1.0
## El retardo inicial de este robo (segundos de robo sin decir nada).
var intro_s := 0.0
var _rng: Mulberry32
var _luck: Mulberry32
var _last_at := -INF
var _last_prio := 0
var _pending_kind := ""
var _pending_at := 0.0
var _pending_ready := 0.0
var _pending_ctx := {}
var _calm_turn := 0
## Cuántas veces ha hecho cada cosa (reacción), y cada ladrón.
var counts := {}
var counts_by := {}
var _act_at := {}
var _stamps := {}
var _held := {}
## Lo dicho hasta ahora, en orden: (tiempo, clave).
var said: Array = []


## night: la noche de la historia (0 si no es de la historia: sin pistas de
## museo); guards: cuántos guardias tiene; piece: el nombre de la pieza,
## ya en palabras ("la dentadura del abuelo Paco").
func _init(night_ := 0, guards_ := 1, players_ := 1, piece_ := "", seed_ := 1) -> void:
	night = night_
	museum = Story.museum_of(night_) if night_ > 0 else -1
	guards = guards_
	players = players_
	piece = piece_
	_rng = Mulberry32.new(seed_)
	_luck = Mulberry32.new(seed_ ^ 0x5bd1e995)
	var lo := TUTORIAL_INTRO_MIN_S if tutorial() else INTRO_MIN_S
	var hi := TUTORIAL_INTRO_MAX_S if tutorial() else INTRO_MAX_S
	intro_s = intro_override if intro_override >= 0.0 else lo + _luck.next() * (hi - lo)
	# Este robo estrena la memoria; el anterior queda como «el robo de antes».
	if not _this_round.is_empty():
		_prev_round = _this_round
		_this_round = {}


## Olvidar todo lo dicho (los tests; el juego no lo necesita).
static func forget() -> void:
	_prev_round = {}
	_this_round = {}


## El primer robo de la historia: sin guardias, para aprender.
func tutorial() -> bool:
	return night == 1 or (night == 0 and guards == 0)


## Cuántos avisos como mucho a estas alturas del robo (los de peligro, más).
func cap(now: float) -> int:
	var c := mini(CAP_MAX, CAP_MIN + int(now / CAP_EVERY_S))
	return mini(c, TUTORIAL_CAP) if tutorial() else c


## Desde cuándo puede salir un aviso: el peligro, pasado INTRO_MIN_S (o el
## retardo si es menor); el resto, pasado todo el retardo inicial.
func _earliest(kind: String) -> float:
	return minf(INTRO_MIN_S, intro_s) if KINDS.get(kind, 0) >= URGENT else intro_s


func _gap() -> float:
	return GAP_S * (TUTORIAL_FACTOR if tutorial() else 1.0)


## Un suceso ha pasado (en el segundo now del robo). Los desconocidos y los
## que no tocan (guardias sin guardias) se ignoran.
func say(kind: String, now: float, ctx := {}) -> void:
	if not KINDS.has(kind) or (guards == 0 and kind in GUARD_KINDS):
		return
	if kind == "team" and players < 2:
		return
	# Nada antes de su hora, salvo el saludo, que espera en la cola.
	if now < _earliest(kind) and kind != "start":
		return
	if _pending_kind == "" or now - _pending_at > _stale(_pending_kind) or KINDS[kind] >= KINDS[_pending_kind]:
		_pending_kind = kind
		_pending_at = now
		_pending_ready = now + (ACT_DELAY_S if kind.begins_with("act_") else 0.0)
		_pending_ctx = ctx


func _stale(kind: String) -> float:
	if kind == "start":
		return INF
	return ACT_STALE_S if kind.begins_with("act_") else STALE_S


## Quien (who, 0 a 3, o -1) ha hecho name (una reacción de ACTS): detail
## no hace falta. Se cuenta siempre (para escalar y para las rachas), pero
## solo a veces se comenta: si ya ha pasado el hueco, no se pasa del tope,
## su enfriamiento ha acabado y le toca la suerte.
func act(name: String, now: float, who := -1) -> void:
	if not ACTS.has(name):
		return
	counts[name] = int(counts.get(name, 0)) + 1
	if who >= 0:
		var by: Dictionary = counts_by.get(name, {})
		by[who] = int(by.get(who, 0)) + 1
		counts_by[name] = by
	var eff := name
	var group: String = GROUPS.get(name, "")
	if group != "":
		var st: Array = _stamps.get(group, [])
		st.append(now)
		var rule: Array = STREAKS[group]
		st = st.filter(func(t): return now - t <= rule[2])
		_stamps[group] = st
		if st.size() >= rule[1]:
			eff = rule[0]
			_stamps[group] = []
	var kind := "act_" + eff
	if not KINDS.has(kind) or (guards == 0 and kind in GUARD_KINDS):
		return
	if now < _earliest("act_" + eff) or now - _last_at < _gap() or said.size() >= cap(now):
		return
	if now - _act_at.get(eff, -INF) < ACTS[eff][1]:
		return
	var chance: float = ACTS[eff][0] / (TUTORIAL_FACTOR if tutorial() else 1.0)
	if not always and (chance <= 0.0 or _luck.next() >= chance):
		return
	_act_at[eff] = now
	say(kind, now, {"name": eff, "base": name, "who": who})


## Algo que se hace sin parar (name en HOLD_S: crawl, run, sneak): on dice
## si lo está haciendo ahora; a los HOLD_S seguidos se comenta, una vez por
## tirada.
func hold(name: String, on: bool, dt: float, now: float, who := 0) -> void:
	var id := "%s%d" % [name, who]
	if not on:
		_held.erase(id)
		return
	var t: float = _held.get(id, 0.0)
	if t < 0.0:
		return
	t += dt
	if t >= HOLD_S:
		_held[id] = -1.0
		act(name, now, who)
	else:
		_held[id] = t


## El aviso que toca ahora (su clave y su texto ya rellenos), o {} si nada.
## still: cuánto lleva quieto el ladrón; tense: algún guardia sospecha (sin
## ocurrencias entonces, ni reacciones de poca monta).
## Devuelve {"key", "text", "kind"} o {}.
func tick(now: float, still := 0.0, tense := false) -> Dictionary:
	var since := now - _last_at
	var gap := _gap()
	if _pending_kind != "":
		var kind := _pending_kind
		if now - _pending_at > _stale(kind):
			_pending_kind = ""
		elif now >= _pending_ready and now >= _earliest(kind) and not (tense and KINDS[kind] < 30 and kind.begins_with("act_")):
			var urgent: bool = KINDS[kind] >= URGENT
			var room := cap(now) + (URGENT_EXTRA if urgent else 0)
			if said.size() < room and (since >= gap or (urgent and since >= CUT_S)):
				var ctx := _pending_ctx
				_pending_kind = ""
				_pending_ctx = {}
				return _speak(kind, now, ctx)
		return {}
	# Las ocurrencias cuentan desde el final del retardo inicial.
	var calm_since := now - maxf(_last_at, intro_s)
	if now < intro_s or tense or calm_since < gap * 1.5 or said.size() >= cap(now) - 1:
		return {}
	# Nada que contar: quieto, o una ocurrencia de vez en cuando.
	var slow := TUTORIAL_FACTOR if tutorial() else 1.0
	if still >= IDLE_AFTER_S and calm_since >= IDLE_EVERY_S * slow:
		return _speak("idle", now)
	if calm_since >= CALM_EVERY_S * slow:
		return _speak(_calm_kind(), now)
	return {}


## Qué ocurrencia toca: por turnos, la pista del museo, una del gato de la
## pieza, la de gente en equipo o una frase suelta. En el primer robo, sin
## pistas de museo (aún no se enseña nada).
func _calm_kind() -> String:
	_calm_turn += 1
	var wheel: Array[String] = ["calm", "piece", "calm"]
	if museum >= 0 and not tutorial():
		wheel = ["hint_%d" % (museum + 1), "calm", "hint_%d" % (museum + 1), "piece"]
	if players > 1:
		wheel.append("team")
	return wheel[_calm_turn % wheel.size()]


## Las frases que puede usar una reacción, por orden: la de «otra vez» si ya
## son varias, y la primera.
func _pools_for(kind: String, ctx: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not kind.begins_with("act_") or ctx.is_empty():
		out.append(kind)
		return out
	var base: String = ctx.base
	# Las rachas (otro nombre que la acción) tienen sus frases y no escalan.
	var plain: bool = ctx.name == base
	var again := "act_knock_again" if base.begins_with("knock_") else kind + "_again"
	var n := int(counts.get(base, 1)) if plain else 0
	if n >= 2 and POOLS.has(again):
		out.append(again)
	out.append(kind)
	if n < 2 and POOLS.has(again):
		out.append(again)
	return out


func _speak(kind: String, now: float, ctx := {}) -> Dictionary:
	var key := ""
	for p in _pools_for(kind, ctx):
		key = next_key(p)
		if key != "":
			break
	if key == "":
		return {}
	_last_at = now
	_last_prio = KINDS.get(kind, 10)
	var text := Text.t(key)
	if "%s" in text:
		text = text % (piece if piece != "" else Text.t("MEGA_SOMETHING"))
	said.append([now, key])
	return {"key": key, "text": text, "kind": kind}


## La clave de la siguiente frase de este tipo, al azar entre las que no han
## salido en este robo ni en el anterior, o "" si ya no queda ninguna (más
## vale callar que repetir). Se da por dicha. Las pistas (hint_m) valen como tipo.
func next_key(pool: String) -> String:
	var free: Array[int] = []
	for i in POOLS[pool]:
		var k := _name(pool, i + 1)
		if not _this_round.has(k) and not _prev_round.has(k):
			free.append(i + 1)
	if free.is_empty():
		return ""
	var n: int = free[int(_rng.next() * free.size())]
	var key := _name(pool, n)
	_this_round[key] = true
	return key


static func _name(pool: String, n: int) -> String:
	return "MEGA_%s_%02d" % [pool.to_upper(), n]


## Todas las claves que existen, para comprobarlas contra el CSV.
static func all_keys() -> Array[String]:
	var out: Array[String] = []
	for pool in POOLS:
		for i in POOLS[pool]:
			out.append(_name(pool, i + 1))
	return out
