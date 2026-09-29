#!/usr/bin/env bash
# Lanza todos los tests/test_*.gd (menos los que empiezan por _), 4 a la vez.
# Criterio: código de salida 0 y una línea de resumen buena (FALLOS: 0, 0 fallos, OK:, TODO BIEN).
# No se busca "error" en el log: en headless hay ruido conocido (joy_names, leaked at exit,
# Viewport Texture, previously freed instance).
#
# Uso:  tests/run_all.sh [nombre ...]      (sin nombres, todos; p. ej. tests/run_all.sh sim heist)
# Variables: GODOT (ruta de Godot), JOBS (en paralelo, 4), LOGDIR (dónde dejar los logs),
# LIMITE (segundos por test antes de matarlo, 300: un SCRIPT ERROR en headless deja el test colgado).
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
JOBS="${JOBS:-4}"
LIMITE="${LIMITE:-300}"
LOGDIR="${LOGDIR:-$(mktemp -d "${TMPDIR:-/tmp}/ninja-tests.XXXXXX")}"
mkdir -p "$LOGDIR"

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
	echo "No encuentro Godot en '$GODOT'. Pon la ruta en la variable GODOT." >&2
	exit 2
fi

# Algunos Mac tienen un HID de Apple que Godot toma por un mando y pulsa solo.
export SDL_JOYSTICK_IGNORE_DEVICES=0x05ac/0x0004
export SDL_GAMECONTROLLER_IGNORE_DEVICES=0x05ac/0x0004

BAD='FALLOS: *[1-9]|^[1-9][0-9]* +FALLOS|(^|[^0-9])[1-9][0-9]* +fallos'
GOOD='FALLOS: *0|(^|[^0-9])0 +fallos|^OK:|TODO BIEN'

# Un test: deja LOGDIR/<nombre>.log y LOGDIR/<nombre>.res con "OK <s>" o "FALLO <s> <motivo>".
run_one() {
	local name="$1" attempt=1 max=1 start code reason
	[ "$name" = "test_escondite" ] && max=2 # tarda ~80 s y su tramo de la ciudad falla a veces por tiempos
	while :; do
		start=$SECONDS
		( cd "$ROOT" && exec "$GODOT" --headless --script "tests/$name.gd" ) >"$LOGDIR/$name.log" 2>&1 &
		local pid=$! timedout="$LOGDIR/$name.timeout"
		rm -f "$timedout"
		( sleep "$LIMITE"; if kill -0 "$pid" 2>/dev/null; then touch "$timedout"; kill "$pid" 2>/dev/null; fi ) >/dev/null 2>&1 &
		local dog=$!
		wait "$pid"
		code=$?
		pkill -P "$dog" 2>/dev/null
		kill "$dog" 2>/dev/null
		wait "$dog" 2>/dev/null
		reason=""
		if [ -e "$timedout" ]; then
			reason="pasó de ${LIMITE}s (colgado)"
		elif [ $code -ne 0 ]; then
			reason="código de salida $code"
		elif grep -Eq "$BAD" "$LOGDIR/$name.log"; then
			reason="$(grep -Em1 "$BAD" "$LOGDIR/$name.log")"
		elif ! grep -Eq "$GOOD" "$LOGDIR/$name.log"; then
			reason="sin línea de resumen"
		fi
		if [ -z "$reason" ]; then
			echo "OK $((SECONDS - start))s (intento $attempt)" >"$LOGDIR/$name.res"
			return 0
		fi
		if [ $attempt -lt $max ]; then
			attempt=$((attempt + 1))
			continue
		fi
		echo "FALLO $((SECONDS - start))s: $reason" >"$LOGDIR/$name.res"
		return 1
	done
}

if [ "${1:-}" = "--run-one" ]; then
	run_one "$2"
	exit 0
fi

names=()
if [ $# -gt 0 ]; then
	for n in "$@"; do
		n="${n%.gd}"
		n="${n#tests/}"
		n="${n#test_}"
		names+=("test_$n")
	done
else
	for f in "$ROOT"/tests/test_*.gd; do
		n="$(basename "$f" .gd)"
		case "$n" in _*) continue ;; esac
		names+=("$n")
	done
fi

echo "Godot: $GODOT"
echo "Logs:  $LOGDIR"
echo "Tests: ${#names[@]} ($JOBS a la vez)"
echo

# test_escondite es el más lento: primero, para que no quede solo al final.
ordered=()
for n in "${names[@]}"; do [ "$n" = "test_escondite" ] && ordered+=("$n"); done
for n in "${names[@]}"; do [ "$n" != "test_escondite" ] && ordered+=("$n"); done

export GODOT LOGDIR JOBS LIMITE
printf '%s\n' "${ordered[@]}" | xargs -P "$JOBS" -I{} bash "${BASH_SOURCE[0]}" --run-one {}

fails=0
for n in "${names[@]}"; do
	res="$(cat "$LOGDIR/$n.res" 2>/dev/null || echo "FALLO no llegó a ejecutarse")"
	printf '%-28s %s\n' "$n" "$res"
	case "$res" in FALLO*) fails=$((fails + 1)) ;; esac
done
echo
if [ $fails -eq 0 ]; then
	echo "TODO EN VERDE: ${#names[@]} tests"
	exit 0
fi
echo "FALLAN $fails de ${#names[@]} (logs en $LOGDIR)"
exit 1
