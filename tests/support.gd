## Helper común para tests/test_*.gd (extends SceneTree, así que esto va por
## composición, no por herencia). Centraliza lo que estaba copiado en casi
## todos los tests: imprimir cada comprobación, acumular los fallos y dar el
## resumen final que lee tests/run_all.sh.
##
## `indent` reproduce las dos variantes que había ("  ok   "/"  FALLO " y
## "ok   "/"FALLO "); `quiet_ok` es para el caso especial que no decía nada
## cuando la comprobación pasaba (test_procedencia.gd).
##
## Cada test lo carga con preload (no class_name, para no depender de que
## Godot haya rehecho la caché de clases globales al lanzar el script suelto):
##   const Support := preload("res://tests/support.gd")
##   var qa := Support.new("  ")
##   func check(ok: bool, what: String) -> void:
##       qa.check(ok, what)
##   ...
##   quit(qa.summary())
extends RefCounted

var failures: Array[String] = []
var indent: String
var quiet_ok: bool


func _init(p_indent := "", p_quiet_ok := false) -> void:
	indent = p_indent
	quiet_ok = p_quiet_ok


func check(ok: bool, what: String) -> void:
	if ok:
		if not quiet_ok:
			print(indent + "ok   " + what)
	else:
		print(indent + "FALLO " + what)
		failures.append(what)


## Como check(), pero solo habla la primera vez que falla cada "what" (para
## comprobaciones que se repiten, p. ej. una por fotograma).
func check_quiet(ok: bool, what: String) -> void:
	if not ok and not failures.has(what):
		check(false, what)


func count() -> int:
	return failures.size()


## Imprime el resumen ("FALLOS: N", que cubre los patrones BAD y GOOD de
## tests/run_all.sh) y devuelve el código que toca pasarle a quit().
func summary() -> int:
	print("FALLOS: %d" % failures.size())
	return 1 if not failures.is_empty() else 0
