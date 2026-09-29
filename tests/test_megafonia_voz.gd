extends SceneTree
## La voz de la megafonía (MegaVoice): la ruta sale de la clave, sin fichero se
## calla sin errores, el ajuste y la práctica la apagan, salir de la ronda la
## corta, y el rótulo se alarga si la voz dura más. Y si la carpeta de audios
## (res://audio/megafonia) tiene ficheros, que estén todas las frases: aviso
## mientras está vacía, fallo en cuanto tenga alguno y falte alguna.
var fails := 0
func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FALLO ") + what)
	if not ok: fails += 1


## Un tono de medio segundo en memoria, en vez de un .ogg.
func tone(secs: float) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	var n := int(22050 * secs)
	var data := PackedByteArray()
	data.resize(n * 2)
	w.data = data
	return w


func _init() -> void:
	check(MegaVoice.path_for("MEGA_ACT_ROLL_WALL_10") == "res://audio/megafonia/mega_act_roll_wall_10.ogg", "la ruta sale de la clave en minúsculas")
	check(MegaVoice.path_for("MEGA_HINT_5_07") == "res://audio/megafonia/mega_hint_5_07.ogg", "…también las pistas del museo")
	check(MegaVoice.allowed("both", "story") and MegaVoice.allowed("sound", "story") and not MegaVoice.allowed("text", "story") and not MegaVoice.allowed("off", "story") and not MegaVoice.allowed("both", "practica") and not MegaVoice.allowed("sound", "practica"), "suena en «cartel y sonido» y «solo sonido», y no en la práctica")
	check(Settings.DEFAULTS.megaphone_mode == "both" and Settings.MEGAPHONE_MODES == ["both", "text", "sound", "off"], "el modo viene en «cartel y sonido», y cicla both, text, sound, off")
	check(Settings.megaphone_text("both") and Settings.megaphone_text("text") and not Settings.megaphone_text("sound") and not Settings.megaphone_text("off"), "el cartel sale en «cartel y sonido» y «solo cartel»")
	check(Settings.megaphone_sound("both") and Settings.megaphone_sound("sound") and not Settings.megaphone_sound("text") and not Settings.megaphone_sound("off"), "la voz suena en «cartel y sonido» y «solo sonido»")
	check(MegaVoice.hold_for(2.0) == 2.0 and MegaVoice.hold_for(30.0) == MegaVoice.MAX_HOLD_S and MegaVoice.hold_for(-1.0) == 0.0, "el alargue del rótulo tiene tope")
	check(MegaVoice.MAX_HOLD_S + Hud.MEGA_VOICE_TAIL_S + Hud.MEGA_OUT_S <= 8.01, "…y el rótulo no pasa de unos 8 s")

	# Los ajustes viejos (megaphone y megaphone_voice) pasan al modo nuevo.
	var was_path := Settings.path
	Settings.path = "user://test_megafonia_voz.cfg"
	var migrations := [[false, false, "off"], [false, true, "off"], [true, false, "text"], [true, true, "both"]]
	for m in migrations:
		var cfg := ConfigFile.new()
		cfg.set_value(Settings.SECTION, "megaphone", m[0])
		cfg.set_value(Settings.SECTION, "megaphone_voice", m[1])
		cfg.save(Settings.path)
		check(Settings.read().megaphone_mode == m[2], "migración: megaphone=%s, voz=%s -> %s" % [m[0], m[1], m[2]])
	var only_on := ConfigFile.new()
	only_on.set_value(Settings.SECTION, "megaphone", true)
	only_on.save(Settings.path)
	check(Settings.read().megaphone_mode == "both", "migración: megaphone=true sin voz guardada -> both")
	var mixed := ConfigFile.new()
	mixed.set_value(Settings.SECTION, "megaphone", false)
	mixed.set_value(Settings.SECTION, "megaphone_mode", "sound")
	mixed.save(Settings.path)
	check(Settings.read().megaphone_mode == "sound", "con el modo nuevo guardado, manda sobre las claves viejas")
	var junk := ConfigFile.new()
	junk.set_value(Settings.SECTION, "megaphone_mode", "loud")
	junk.save(Settings.path)
	check(Settings.read().megaphone_mode == "both", "un modo que no existe vuelve al de por defecto")
	Settings.write({"megaphone_mode": "text"})
	var saved := ConfigFile.new()
	saved.load(Settings.path)
	check(saved.get_value(Settings.SECTION, "megaphone_mode") == "text" and not saved.has_section_key(Settings.SECTION, "megaphone") and not saved.has_section_key(Settings.SECTION, "megaphone_voice") and Settings.read().megaphone_mode == "text", "al escribir queda el modo y no las dos claves viejas")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.path = was_path

	var v := MegaVoice.new()
	root.add_child(v)
	await process_frame
	check(v.speak("MEGA_NO_EXISTE_99", "both", "story") == 0.0 and v.current == "", "una clave sin fichero se calla, sin error")
	check(v.speak("MEGA_NO_EXISTE_99", "both", "story") == 0.0, "…y no la busca otra vez (recordada)")
	check(MegaVoice._missing.has("MEGA_NO_EXISTE_99"), "…en la caché de faltantes")

	v.preset["MEGA_UNO"] = tone(0.5)
	v.preset["MEGA_DOS"] = tone(1.5)
	var secs := v.speak("MEGA_UNO", "text", "story")
	check(secs == 0.0 and v.current == "", "«solo cartel»: no hay voz")
	secs = v.speak("MEGA_UNO", "off", "story")
	check(secs == 0.0 and v.current == "", "«no»: ni voz")
	secs = v.speak("MEGA_UNO", "both", "practica")
	check(secs == 0.0 and v.current == "", "en la práctica no suena")
	secs = v.speak("MEGA_UNO", "sound", "story")
	check(absf(secs - 0.5) < 0.05 and v.current == "MEGA_UNO", "«solo sonido»: suena")
	v.stop(true)
	secs = v.speak("MEGA_UNO", "both", "story")
	check(absf(secs - 0.5) < 0.05 and v.current == "MEGA_UNO" and v.is_speaking(), "suena y dice cuánto dura (%.2f s)" % secs)
	secs = v.speak("MEGA_DOS", "both", "story")
	check(v.current == "MEGA_DOS" and absf(secs - 1.5) < 0.05, "una voz nueva sustituye a la anterior")
	v.stop(true)
	check(v.current == "" and not v.is_speaking(), "al salir de la ronda se corta")
	check(not v._player.playing, "…y el reproductor calla")

	# Los audios: todos, o un aviso mientras no haya.
	var files := {}
	var dir := DirAccess.open(MegaVoice.DIR)
	if dir:
		for f in dir.get_files():
			var base := f.trim_suffix(".import")
			if base.ends_with(".ogg"):
				files[base] = true
	# Las frases con el nombre de la pieza (%s) se quedan solo en texto: no llevan voz.
	var keys := Megaphone.all_keys().filter(func(k): return not "%s" in Text.t(k))
	var lacking := []
	for k in keys:
		if not files.has(MegaVoice.path_for(k).get_file()):
			lacking.append(k)
	if files.is_empty():
		print("AVISO aún no hay audios en %s (faltan %d frases); con la carpeta llena, un faltante será fallo" % [MegaVoice.DIR, keys.size()])
	else:
		check(lacking.is_empty(), "cada una de las %d frases tiene su .ogg (faltan %d %s)" % [keys.size(), lacking.size(), lacking.slice(0, 8)])
		if FileAccess.file_exists(MegaVoice.INDEX):
			var idx = JSON.parse_string(FileAccess.get_file_as_string(MegaVoice.INDEX))
			var short := []
			if idx is Dictionary:
				for k in keys:
					if not idx.has(k) or not idx[k].has("file") or float(idx[k].get("seconds", 0)) <= 0.0:
						short.append(k)
			check(idx is Dictionary and short.is_empty(), "el índice describe todas las frases (file, seconds) %s" % [short.slice(0, 8)])
		else:
			print("AVISO hay .ogg pero no megafonia_index.json")
		# Uno cualquiera carga de verdad, importado.
		for k in keys:
			if files.has(MegaVoice.path_for(k).get_file()):
				check(load(MegaVoice.path_for(k)) is AudioStream, "%s carga como AudioStream (¿importado?)" % k)
				break
	print("%d fallos" % fails)
	quit(1 if fails > 0 else 0)
