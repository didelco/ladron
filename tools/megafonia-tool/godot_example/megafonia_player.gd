## Ejemplo (Godot 4): reproduce avisos de megafonía por id.
##
## Lee res://audio/megafonia/megafonia_index.json. Vale con los dos formatos que escribe build.py:
## el del juego ({clave: {file, seconds, tags}}, solo wet, lo copia --godot-dir) y el de out/
## ({"frases": {id: {ruta, ruta_dry, duracion, ...}}}, con versión dry).
## - Versión "wet": el ogg ya lleva la sala; suena en el bus `bus_wet` (Master por defecto).
## - Versión "dry": el ogg lleva solo la bocina; suena en el bus "Megafonia", que este script
##   crea al arrancar con un AudioEffectReverb (y un delay corto), para ajustar la sala en Godot.
##
## Uso: añade este nodo a la escena (o como autoload «Megafonia») y llama
##   $Megafonia.reproducir("cierre_15")            # wet
##   $Megafonia.reproducir("cierre_15", true)      # dry + reverb de Godot
## Un aviso nuevo espera a que acabe el anterior (cola); `interrumpir = true` corta el que suena.
extends Node

signal aviso_terminado(id: String)

@export var indice_path := "res://audio/megafonia/megafonia_index.json"
@export var usar_dry := false          ## true: versión dry + la reverb del bus de Godot
@export var interrumpir := false
@export var bus_wet := &"Master"
@export var bus_dry := &"Megafonia"
@export_range(-40.0, 6.0) var volumen_db := 0.0

## Reverb del bus dry: una sala grande (ajustable desde el inspector o el mezclador de audio).
@export var reverb_room_size := 0.8
@export var reverb_damping := 0.5
@export var reverb_wet := 0.3
@export var reverb_predelay_ms := 40.0

var _frases := {}
var _cola: Array = []
var _player: AudioStreamPlayer
var _actual := ""


func _ready() -> void:
	_carga_indice()
	_crea_bus_dry()
	_player = AudioStreamPlayer.new()
	_player.volume_db = volumen_db
	add_child(_player)
	_player.finished.connect(_al_terminar)


func _carga_indice() -> void:
	var f := FileAccess.open(indice_path, FileAccess.READ)
	if f == null:
		push_warning("Megafonía: no encuentro %s" % indice_path)
		return
	var datos = JSON.parse_string(f.get_as_text())
	if datos is Dictionary:
		_frases = datos.get("frases", datos)


func _crea_bus_dry() -> void:
	if AudioServer.get_bus_index(bus_dry) != -1:
		return  # ya existe (p. ej. definido en el default_bus_layout): se respeta
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_dry)
	AudioServer.set_bus_send(i, &"Master")
	var delay := AudioEffectDelay.new()  # eco corto de megafonía (como el delay del preset)
	delay.tap1_delay_ms = 150.0
	delay.tap1_level_db = -16.0
	delay.tap2_active = false
	delay.feedback_active = false
	AudioServer.add_bus_effect(i, delay)
	var reverb := AudioEffectReverb.new()
	reverb.room_size = reverb_room_size
	reverb.damping = reverb_damping
	reverb.wet = reverb_wet
	reverb.dry = 1.0
	reverb.predelay_msec = reverb_predelay_ms
	reverb.hipass = 0.2
	AudioServer.add_bus_effect(i, reverb)


func tiene(id: String) -> bool:
	return _frases.has(id)


func duracion(id: String) -> float:
	var e: Dictionary = _frases.get(id, {})
	return float(e.get("seconds", e.get("duracion", 0.0)))


## Encola (o reproduce ya) un aviso. dry = null usa `usar_dry`.
func reproducir(id: String, dry = null) -> void:
	if not _frases.has(id):
		push_warning("Megafonía: id desconocido «%s»" % id)
		return
	var seco: bool = usar_dry if dry == null else dry
	if _player.playing and not interrumpir:
		_cola.append([id, seco])
		return
	_suena(id, seco)


func para() -> void:
	_cola.clear()
	_player.stop()
	_actual = ""


func _suena(id: String, seco: bool) -> void:
	var entrada: Dictionary = _frases[id]
	seco = seco and entrada.has("ruta_dry")  # el índice del juego solo trae la versión wet
	var ruta: String = entrada["ruta_dry"] if seco else entrada.get("file", entrada.get("ruta", ""))
	var stream := load(ruta) as AudioStream
	if stream == null:
		push_warning("Megafonía: no puedo cargar el audio de «%s»" % id)
		return
	_player.stream = stream
	_player.bus = bus_dry if seco else bus_wet
	_actual = id
	_player.play()


func _al_terminar() -> void:
	var id := _actual
	_actual = ""
	aviso_terminado.emit(id)
	if not _cola.is_empty():
		var siguiente: Array = _cola.pop_front()
		_suena(siguiente[0], siguiente[1])
