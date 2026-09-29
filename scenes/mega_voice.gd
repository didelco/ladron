class_name MegaVoice
extends Node
## La voz de la megafonía: cada frase MEGA_X suena desde
## res://audio/megafonia/<clave en minúsculas>.ogg (mono, con reverb y efectos
## ya puestos, a -16 LUFS; los genera tools/megafonia-tool), a la vez que sale
## su rótulo. Es opcional: si el fichero no está, no pasa nada (silencio, y no
## se vuelve a buscar).
##
## Una sola voz a la vez: si llega otra frase mientras habla la anterior, la
## nueva la sustituye (corte seco; con los huecos de Megaphone casi no ocurre).
## Al pausar la partida se pausa (el nodo es pausable) y sigue al reanudar; al
## salir de la ronda o acabar la noche, stop() la apaga con un fundido corto.
## Mientras habla baja un poco la música (Sfx.duck).
## Va por el bus «Voice» (lo crea Sfx, con el volumen de los efectos).

const DIR := "res://audio/megafonia/"
const INDEX := DIR + "megafonia_index.json"
const BUS := &"Voice"
## Lo que baja la música mientras habla (dB) y el fundido de salida (s).
const DUCK_DB := -6.0
const FADE_S := 0.25
## El rótulo dura Hud.MEGA_S (5,5 s) y, si la voz es más larga, lo que ella dura
## más la cola y el fundido de Hud: la voz que cuenta llega hasta MAX_HOLD_S,
## así que el rótulo no pasa de unos 8 s.
const MAX_HOLD_S := 6.8

## Las claves cuyo fichero no existe (o no carga): no se buscan otra vez.
static var _missing := {}
## Segundos por clave, del índice (se lee una vez, si existe).
static var _seconds: Dictionary = {}
static var _index_read := false

## Para pruebas: clave -> AudioStream que se usa en vez del fichero.
var preset := {}
## La clave que suena ahora ("" si nada).
var current := ""
var _player: AudioStreamPlayer
var _tween: Tween
var _sfx: Sfx


func _init(sfx: Sfx = null) -> void:
	_sfx = sfx
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = BUS if AudioServer.get_bus_index(BUS) >= 0 else &"Master"
	add_child(_player)
	_player.finished.connect(_done)


## La ruta del audio de una clave: MEGA_ACT_ROLL_WALL_10 -> ...mega_act_roll_wall_10.ogg
static func path_for(key: String) -> String:
	return DIR + key.to_lower() + ".ogg"


## ¿Debe sonar la voz? Modo de megafonía con sonido («both» o «sound»), y no
## en la práctica.
static func allowed(megaphone_mode: String, mode: String) -> bool:
	return Settings.megaphone_sound(megaphone_mode) and mode != "practica"


## ¿Hay fichero de esa clave? (Sin cargarlo; el resultado negativo se recuerda.)
static func has_file(key: String) -> bool:
	if _missing.has(key):
		return false
	if ResourceLoader.exists(path_for(key)):
		return true
	_missing[key] = true
	return false


## Segundos de una clave según el índice (0.0 si no consta).
static func index_seconds(key: String) -> float:
	if not _index_read:
		_index_read = true
		if FileAccess.file_exists(INDEX):
			var data = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
			if data is Dictionary:
				for k in data:
					if data[k] is Dictionary:
						_seconds[k] = float(data[k].get("seconds", 0.0))
	return float(_seconds.get(key, 0.0))


## Cuánto debe durar el rótulo para cubrir la voz: 0.0 si no hay que alargar
## nada (voz corta), o los segundos de audio con un tope de MAX_HOLD_S.
static func hold_for(seconds: float) -> float:
	return clampf(seconds, 0.0, MAX_HOLD_S)


## Dice la frase `key` si toca. Devuelve los segundos que dura (0.0 si no suena:
## apagada, en práctica, sin fichero o sin cargar).
func speak(key: String, megaphone_mode: String, mode: String) -> float:
	if not allowed(megaphone_mode, mode):
		return 0.0
	var stream: AudioStream = preset.get(key)
	if stream == null:
		if not has_file(key):
			return 0.0
		stream = load(path_for(key)) as AudioStream
		if stream == null:
			_missing[key] = true
			return 0.0
	_cut()
	current = key
	_player.stream = stream
	_player.volume_db = 0.0
	_player.play()
	if _sfx:
		_sfx.duck(DUCK_DB)
	var secs := stream.get_length()
	return secs if secs > 0.0 else index_seconds(key)


## Calla la voz (al salir de la ronda, acabar la noche o apagar el ajuste),
## con un fundido corto, o de golpe si `now`.
func stop(now := false) -> void:
	if current == "":
		return
	current = ""
	if _sfx:
		_sfx.duck(0.0)
	if _tween:
		_tween.kill()
	if now or not is_inside_tree():
		_player.stop()
		return
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", -40.0, FADE_S)
	_tween.tween_callback(_player.stop)


func is_speaking() -> bool:
	return current != ""


## Sustituir una voz por otra: sin fundido, sin tocar la música.
func _cut() -> void:
	if _tween:
		_tween.kill()
	_player.stop()


func _done() -> void:
	current = ""
	if _sfx:
		_sfx.duck(0.0)
