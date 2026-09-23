class_name Mind
extends RefCounted
## A guard's mind, as far as Laya is concerned: port of the web's brain.ts.
##
## Laya does not write, it scores: it reads a state and answers typed
## questions about it — pick one of these, place this on a scale, is this
## true — with calibrated probabilities. So each guard gets:
##   - a state: named fields (me, clue, colleagues, lights, checked);
##   - a menu the game writes afresh: the few things it could actually do now,
##     each worded with the real place it leads to;
##   - five questions answered together: plan, pace, torch, and two hunches
##     about the thief (still close? hiding?) that shape the search.
## The plan is drawn from the probabilities, sharpened, and a guard torn
## between two plans hesitates. Without Laya, fallback() picks by urgency.

## Without a clue, "recently looked over" means within this long.
const RECENT_MS := 40000.0
## Torn: the two best plans this close in probability.
const TORN_MARGIN := 0.06
## How hard the draw leans towards the favourite plan.
const SHARPEN := 3.0
## A clue younger than this is too hot to walk away from.
const HOT_CLUE_MS := 6000.0

const PLAN_LABEL := {
	"chase": "Acudir al grito",
	"cut_off": "Cortarle el paso",
	"follow": "Seguir el rastro",
	"search": "Registrar la pista",
	"check_zone": "Revisar otra zona",
	"cover": "Cubrir el otro lado",
	"patrol": "Seguir la ronda",
	"watch": "Vigilar el cruce",
}
const PLAN_WORDS := {
	"chase": "answer a shout",
	"cut_off": "cut off an escape",
	"follow": "follow a trail",
	"search": "search around a clue",
	"check_zone": "look over another area",
	"cover": "cover the other side",
	"watch": "watch a junction",
	"patrol": "walk the round",
}
const LOOK_LABEL := {
	"sweep": "barre con la linterna",
	"ahead": "linterna al frente",
	"clue": "linterna hacia la pista",
}


## What Laya reads and is asked for one guard right now:
## {id, state, questions, options}. options are Decision.Option, in order.
static func of(g: Guard, others: Array[Guard], now: float) -> Dictionary:
	var options := _menu(g, others, now)
	return {"id": g.id, "state": _state(g, others, now), "questions": _questions(g, options), "options": options}


# --- State ---------------------------------------------------------------------

static func _state(g: Guard, others: Array[Guard], now: float) -> Dictionary:
	var state := {}
	var mood := "It has been a quiet night and you are strolling, not paying much attention."
	if g.alert:
		mood = "You know for certain there is an intruder in the building." if g.calm_in == INF \
			else "Something made you jumpy a moment ago; you are on edge."
	state.me = "You are %s, a night attendant in a closed museum of long galleries, standing in %s. %s" % [g.name, Museum.zone_name(g.x, g.y), mood]

	var m := g.memory
	if m == null:
		state.clue = "You have not seen or heard anything to go on."
	else:
		var ago := int(round((now - m.at) / 1000.0))
		var where := Museum.zone_name(m.x, m.y)
		var what := "you heard something in %s" % where
		if m.kind == "seen":
			what = "you saw the intruder in %s" % where
		elif m.kind == "called":
			what = "a colleague told you the intruder is in %s" % where
		var heading := " They were running %s." % _compass(m.vx, m.vy) if m.has_heading else ""
		var freshness := "It is very fresh." if ago <= 3 else ("It is recent." if ago <= 8 else "It is old; the trail has gone cold.")
		state.clue = "%d seconds ago %s.%s %s" % [ago, what, heading, freshness]

	# The nearest few colleagues and what each is up to.
	var near := others.duplicate()
	near.sort_custom(func(a, b): return Museum.dist(a.x, a.y, g.x, g.y) < Museum.dist(b.x, b.y, g.x, g.y))
	var lines := PackedStringArray()
	for o in near.slice(0, 3):
		var d := Museum.dist(o.x, o.y, g.x, g.y)
		var where := "right next to you" if d < 6 else "in %s" % Museum.zone_name(o.x, o.y)
		var doing := "is walking the round"
		if o.sees_player:
			doing = "is chasing the intruder right now"
		elif o.decision:
			doing = "is going to %s in %s" % [PLAN_WORDS.get(o.decision.plan, "walk the round"), Museum.zone_name(o.decision.target.x + 0.5, o.decision.target.y + 0.5)]
		lines.append("%s is %s and %s." % [o.name, where, doing])
	if not lines.is_empty():
		state.colleagues = " ".join(lines)

	var lit := PackedStringArray()
	for r in Museum.rooms:
		if Museum.lights_left[r.id] > 0:
			lit.append(Museum.zone_name(r.rect.position.x + r.rect.size.x / 2.0, r.rect.position.y + r.rect.size.y / 2.0))
	state.lights = ("The ceiling lights are on in %s: anyone there is plainly visible. Everywhere else is dark." % " and ".join(lit)) \
		if not lit.is_empty() else "All the galleries are dark; only torches light the way."

	var since := m.at if m else now - RECENT_MS
	var done := PackedStringArray()
	for z in Watch.controlled_zones(g, since):
		done.append(z.name)
	if not done.is_empty():
		state.checked = "%s have looked over %s and nobody was there." % ["Since the clue you" if m else "In the last minute you", ", ".join(done)]
	if m and Watch.clue_cleared(g):
		state.clue += " You have searched that area since and the intruder is not there any more."
	return state


static func _compass(vx: float, vy: float) -> String:
	if absf(vy) > absf(vx):
		return "south" if vy > 0 else "north"
	return "east" if vx > 0 else "west"


# --- Menu ----------------------------------------------------------------------

## What the guard could do right now, each with the tile it leads to. Only what
## makes sense is offered: an option on the menu is one Laya may take.
static func _menu(g: Guard, others: Array[Guard], now: float) -> Array[Decision.Option]:
	var out: Array[Decision.Option] = []
	var m := g.memory
	var age := now - m.at if m else INF
	var add := func(plan: String, target: Vector2i, text: String, key: String = "") -> void:
		if target.x < 0:
			return
		# One option per destination: two wordings of one walk split the vote.
		for o in out:
			if o.target == target:
				return
		var busy: Guard = null
		for o in others:
			if o.decision and Museum.dist(o.decision.target.x, o.decision.target.y, target.x, target.y) < 3:
				busy = o
				break
		var opt := Decision.Option.new()
		opt.key = key if key != "" else plan
		opt.plan = plan
		opt.target = target
		opt.text = "%s (%s is already heading there)" % [text, busy.name] if busy else text
		opt.label = PLAN_LABEL[plan]
		out.append(opt)

	if m:
		var clue := Vector2i(int(floor(m.x)), int(floor(m.y)))
		var done := func(t: Vector2i) -> bool:
			var z := Museum.zone_at(t.x + 0.5, t.y + 0.5)
			return z != null and Watch.controlled(g, z, m.at)
		var where := Museum.zone_name(m.x, m.y)
		if m.kind == "called" and age < 8000:
			add.call("chase", clue, "run straight to %s, where a colleague shouted the intruder is" % where)
		if m.has_heading and age < 12000:
			var ahead := _projected_spot(g, now)
			if not done.call(ahead):
				add.call("follow", ahead, "follow the way the intruder was running, %s towards %s" % [_compass(m.vx, m.vy), Museum.zone_name(ahead.x + 0.5, ahead.y + 0.5)])
		if age < 12000:
			var exit := _cut_off_spot(g, now)
			if exit.x >= 0 and not done.call(exit):
				add.call("cut_off", exit, "go round the other way to %s and block the intruder's way out of %s" % [Museum.zone_name(exit.x + 0.5, exit.y + 0.5), where])
		if not Watch.clue_cleared(g):
			add.call("search", g.search_spot if g.search_spot.x >= 0 else clue, "search the hiding places around %s, where the clue came from" % where)

	# Areas it has not looked over: the two most promising, as separate options.
	var i := 0
	for z in _zones_to_check(g, others, now):
		i += 1
		add.call("check_zone", z.tile, z.text, "zone%d" % i)

	# With colleagues busy, the rest of the museum is unwatched.
	var busy_tiles: Array[Vector2i] = []
	for o in others:
		if o.memory or o.sees_player:
			busy_tiles.append(o.decision.target if o.decision else Vector2i(int(floor(o.x)), int(floor(o.y))))
	if not busy_tiles.is_empty():
		var far := _farthest_stop(busy_tiles)
		add.call("cover", far, "cover %s, the part of the museum your colleagues are not watching" % Museum.zone_name(far.x + 0.5, far.y + 0.5))

	# Walking away from a hot clue is not a real option, so it is not offered.
	if age > HOT_CLUE_MS or out.is_empty():
		var nxt := next_stop(g)
		add.call("patrol", nxt, "carry on the round to the junction in %s" % Museum.zone_name(nxt.x + 0.5, nxt.y + 0.5))
		var here := nearest_stop(g)
		add.call("watch", here, "stand at the junction in %s and watch the galleries that meet there" % Museum.zone_name(here.x + 0.5, here.y + 0.5))
	return out.slice(0, 6)


## Where the thief probably is now: down the aisle it was running along, for
## as long as the clue has been going stale, stopping at the first wall.
static func _projected_spot(g: Guard, now: float) -> Vector2i:
	var m := g.memory
	var here := Vector2i(int(floor(m.x)), int(floor(m.y)))
	if not m.has_heading:
		return here
	var age := (now - m.at) / 1000.0
	var lead := minf(7.0, 2.0 + age * 2.6)
	var angle := atan2(m.vy, m.vx)
	var reach := minf(lead, maxf(0.0, Museum.cast_ray(m.x, m.y, angle, lead) - 0.5))
	var px := m.x + cos(angle) * reach
	var py := m.y + sin(angle) * reach
	if Museum.is_wall(px, py):
		return here
	return Museum.nearest_open(px, py)


## The junction on the far side of the clue: the way out a fleeing thief takes.
static func _cut_off_spot(g: Guard, now: float) -> Vector2i:
	var m := g.memory
	var ux := m.vx
	var uy := m.vy
	if not m.has_heading:
		var d := Museum.dist(g.x, g.y, m.x, m.y)
		if d < 2:
			return Vector2i(-1, -1)
		ux = (m.x - g.x) / d
		uy = (m.y - g.y) / d
	var lead := 5.0 + minf(3.0, (now - m.at) / 2000.0)
	var tx := m.x + ux * lead
	var ty := m.y + uy * lead
	var best := Vector2i(-1, -1)
	var best_d := INF
	for wp in Museum.watchpoints:
		# A junction that is really the clue itself cuts nothing off.
		if Museum.dist(wp.x + 0.5, wp.y + 0.5, m.x, m.y) < 3:
			continue
		var d := Museum.dist(wp.x + 0.5, wp.y + 0.5, tx, ty)
		if d < best_d:
			best_d = d
			best = wp
	return best


## Zones it has not looked over, ranked by how likely the thief is there:
## near the clue and ahead of it if it was running; without a clue, near the
## guard and long unwatched. Zones colleagues are heading for are theirs.
static func _zones_to_check(g: Guard, others: Array[Guard], now: float) -> Array[Dictionary]:
	var m := g.memory
	var since := m.at if m else now - RECENT_MS
	var clue_zone := Museum.zone_at(m.x, m.y) if m else null
	var taken := {}
	for o in others:
		if o.decision:
			var z := Museum.zone_at(o.decision.target.x + 0.5, o.decision.target.y + 0.5)
			if z:
				taken[z.id] = true
	var ranked: Array = []
	for z in Museum.zones:
		if z == clue_zone or taken.has(z.id) or Watch.controlled(g, z, since):
			continue
		var c := _centre(z)
		var score: float
		if m:
			var d := Museum.dist(c.x, c.y, m.x, m.y)
			# How far the thief could have got: a brisk walk since the clue.
			var reach := 3.0 + (now - m.at) / 1000.0 * 1.5
			score = -absf(d - minf(reach, 6.0))
			if m.has_heading and d > 0:
				score += ((c.x - m.x) * m.vx + (c.y - m.y) * m.vy) / d * 3
		else:
			var stale := minf(Watch.since_looked(g, z, now), 120000.0) / 1000.0
			score = stale / 10.0 - Museum.dist(c.x, c.y, g.x, g.y) / 3.0
		ranked.append([z, score])
	ranked.sort_custom(func(a, b): return a[1] > b[1])
	var out: Array[Dictionary] = []
	for entry in ranked.slice(0, 2):
		var z: Museum.Zone = entry[0]
		var ago := Watch.since_looked(g, z, now)
		var when := "which you have not looked at tonight" if ago == INF else "which you last looked over %d seconds ago" % int(round(ago / 1000.0))
		var next_to := ", next to where the clue was" if clue_zone and _neighbours(z, clue_zone) else ""
		var lit := " (its lights are on)" if z.room >= 0 and Museum.lights_left[z.room] > 0 else ""
		out.append({"tile": _vantage(g, z, since), "text": "look over %s%s%s, %s" % [z.name, lit, next_to, when]})
	return out


static func _centre(z: Museum.Zone) -> Vector2:
	var sx := 0.0
	var sy := 0.0
	for t in z.tiles:
		sx += t.x
		sy += t.y
	return Vector2(sx / z.tiles.size() + 0.5, sy / z.tiles.size() + 0.5)


static func _neighbours(a: Museum.Zone, b: Museum.Zone) -> bool:
	var in_b := {}
	for t in b.tiles:
		in_b[t] = true
	for t in a.tiles:
		for d in Museum.DIRS:
			if in_b.has(t + d):
				return true
	return false


## The best spot to look a zone over from: the unseen tile that sees most.
static func _vantage(g: Guard, z: Museum.Zone, since: float) -> Vector2i:
	var pool: Array[Vector2i] = []
	for t in z.tiles:
		if g.seen_at[t.y * Museum.w + t.x] < since:
			pool.append(t)
	if pool.is_empty():
		pool = z.tiles
	var best := pool[0]
	for t in pool:
		if Museum.openness(t.x, t.y) > Museum.openness(best.x, best.y):
			best = t
	return best


static func _farthest_stop(from: Array[Vector2i]) -> Vector2i:
	var best := Museum.watchpoints[0]
	var best_d := -1.0
	for wp in Museum.watchpoints:
		var d := INF
		for f in from:
			d = minf(d, Museum.dist(wp.x, wp.y, f.x, f.y))
		if d > best_d:
			best_d = d
			best = wp
	return best


static func next_stop(g: Guard) -> Vector2i:
	return Museum.watchpoints[g.stop % Museum.watchpoints.size()]


static func nearest_stop(g: Guard) -> Vector2i:
	var best := Museum.watchpoints[0]
	var best_d := INF
	for wp in Museum.watchpoints:
		var d := Museum.dist(wp.x + 0.5, wp.y + 0.5, g.x, g.y)
		if d < best_d:
			best_d = d
			best = wp
	return best


# --- Questions and answers -------------------------------------------------------

## Every question for this guard, answered in one pass together with every
## other guard's. Pace and torch read only me and clue; the plan and the
## hunches read the whole state.
static func _questions(g: Guard, options: Array[Decision.Option]) -> Dictionary:
	var criteria := {}
	for o in options:
		criteria[o.key] = o.text
	var scan := {
		"sweep": "sweep it from side to side to cover more of the galleries",
		"ahead": "keep it on the way ahead",
	}
	if g.memory:
		scan.clue = "keep it pointed towards where the clue came from"
	var q := {
		"plan": {
			"type": "choice",
			"instructions": "Given `clue`, `colleagues` and `checked`, what should the attendant do next to catch the intruder?" if g.memory
				else "Given `me`, `colleagues` and `checked`, what should the attendant do next on the night shift?",
			"criteria": criteria,
		},
		"pace": {
			"type": "score",
			"instructions": "Given `me` and `clue`, how fast should the attendant move?",
			"fields": ["me", "clue"],
			"criteria": [
				"strolling: nothing is happening",
				"brisk: something felt off",
				"hurrying: a strong, recent clue",
				"sprinting: the intruder is close and getting away",
			],
		},
		"scan": {
			"type": "choice",
			"instructions": "Given `me` and `clue`, how should the attendant use the torch while walking?",
			"fields": ["me", "clue"],
			"criteria": scan,
		},
	}
	if g.memory:
		q.near = {"type": "noul", "instructions": "Given `clue`, is the intruder probably still within a few steps of that spot?"}
		q.hiding = {"type": "noul", "instructions": "Given `clue`, is the intruder more likely hiding nearby than running away?"}
	return q


## Turn Laya's answers into a decision. The plan is drawn from the
## probabilities cubed: a clear favourite nearly always, a close runner-up now
## and then, a long shot almost never.
static func decide(mind: Dictionary, answers: Dictionary, ms: int) -> Decision:
	var options: Array[Decision.Option] = mind.options
	var plan_answer: Dictionary = answers.get("plan", {})
	var probs: Dictionary = plan_answer.get("probabilities", {})
	var total := 0.0
	var weights: Array[float] = []
	for o in options:
		var wgt := pow(float(probs.get(o.key, 0.0)), SHARPEN)
		weights.append(wgt)
		total += wgt
	var pick := options[0]
	if total > 0:
		var r := randf() * total
		for i in options.size():
			r -= weights[i]
			if r <= 0:
				pick = options[i]
				break
	var ranked: Array = probs.values()
	ranked.sort()
	ranked.reverse()
	var d := Decision.new()
	d.id = mind.id
	d.plan = pick.plan
	d.option = pick.key
	d.label = pick.label
	d.target = pick.target
	var scan: String = answers.get("scan", {}).get("choice", "ahead")
	d.look = scan if scan in ["sweep", "ahead", "clue"] else "ahead"
	d.probabilities = probs
	for o in options:
		d.labels[o.key] = o.label
	d.confidence = float(plan_answer.get("confidence", 0.5))
	d.torn = ranked.size() > 1 and float(ranked[0]) - float(ranked[1]) < TORN_MARGIN
	# score is the expected rung over 0..3.
	d.aggression = clampf(float(answers.get("pace", {}).get("score", 1.0)) / 3.0, 0.0, 1.0)
	d.near = float(answers.get("near", {}).get("noul", 0.5))
	d.hiding = float(answers.get("hiding", {}).get("noul", 0.5))
	d.ms = ms
	return d


## The same decision without the model: the first option in order of urgency.
## Used until Laya answers and whenever it is not there.
static func fallback(g: Guard, others: Array[Guard], now: float) -> Decision:
	var options := _menu(g, others, now)
	var order := ["chase", "follow", "search", "check_zone", "cover", "patrol", "watch"] if g.alert else ["patrol", "watch"]
	var pick := options[0]
	var found := false
	for p in order:
		for o in options:
			if o.plan == p:
				pick = o
				found = true
				break
		if found:
			break
	var d := Decision.new()
	d.id = g.id
	d.plan = pick.plan
	d.option = pick.key
	d.label = pick.label
	d.target = pick.target
	d.look = "sweep" if g.alert else "ahead"
	d.probabilities = {pick.key: 1.0}
	d.labels = {pick.key: pick.label}
	var hot := pick.plan == "chase" or pick.plan == "follow"
	d.aggression = 0.85 if hot else (0.45 if g.alert else 0.2)
	d.near = 0.6
	return d
