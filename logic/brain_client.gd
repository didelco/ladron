class_name BrainClient
extends Node
## Talks to the brain service (brain/server.py) over HTTP.
##
## One request carries every guard that has something to decide — the service
## answers them all in one forward pass of Laya — and the answers come back as
## Decisions read against the very menus they were asked about. When the
## service is not there, `failed` fires and the game uses the fallback rules;
## it keeps trying, less often, so starting the brain mid-game just works.

signal decided(decisions: Dictionary, ms: int)
signal failed(reason: String)

const URL := "http://127.0.0.1:8000/decide"
## Longer than a batch of a few guards takes; past this, the rules decide.
const TIMEOUT_S := 4.0
## After a failure, wait this long before asking again.
const RETRY_MS := 5000.0

var busy := false
## "laya" once it has answered, "rules" while it cannot be reached
var status := "rules"
var last_ms := 0
var _http: HTTPRequest
var _minds := {}
var _failed_at := -INF


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_S
	add_child(_http)
	_http.request_completed.connect(_on_completed)


## Ask about these guards, if not already asking and not in the back-off
## after a failure. Returns false when nothing was sent.
func ask(guards: Array[Guard], all_guards: Array[Guard], now: float) -> bool:
	if busy or guards.is_empty() or now - _failed_at < RETRY_MS:
		return false
	_minds.clear()
	var payload: Array = []
	for g in guards:
		var others: Array[Guard] = all_guards.filter(func(o): return o != g)
		var mind := Mind.of(g, others, now)
		_minds[g.id] = mind
		payload.append({"id": mind.id, "state": mind.state, "questions": mind.questions})
	var err := _http.request(URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"guards": payload}))
	if err != OK:
		_fail("no se pudo enviar (%d)" % err, now)
		return false
	busy = true
	return true


func _on_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	var now := Sim.now_ms()
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("sin conexión con el cerebro" if result == HTTPRequest.RESULT_CANT_CONNECT else "error de red %d" % result, now)
		return
	if code != 200:
		_fail("el cerebro respondió %d" % code, now)
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY or not data.has("decisions"):
		_fail("respuesta ilegible", now)
		return
	var out := {}
	for d in data.decisions:
		var mind: Dictionary = _minds.get(d.id, {})
		if not mind.is_empty():
			out[d.id] = Mind.decide(mind, d.answers, int(d.get("ms", 0)))
	status = "laya"
	last_ms = int(data.get("ms", 0))
	decided.emit(out, last_ms)


func _fail(reason: String, now: float) -> void:
	status = "rules"
	_failed_at = now
	failed.emit(reason)
