class_name PlanBeats
extends RefCounted
## What is told over the plan before a story heist (Tour, PlanTalk), in
## order, each pinned to where it happens on the plan, as a film's gang
## plans a job over the map: the piece and its tale, what is new tonight
## (Story.news), the rules for the night (Briefing.tips), and the way in
## and out. Worked out from the round laid out (Heist, the guards, Props,
## Museum), like the rules themselves.
##
## A beat is {"kind", "at", "title", "text", "icon"} and maybe more:
##   kind   "piece", "news", "rule", "start" or "exit"
##   at     where on the plan, in tiles (x across, y down), a tile's middle
##   icon   the plan's own mark for it (Hud.legend_icon keys, or "news")
##   stage  news: its little scene (MenuStage.make)
## The piece's tale itself (the job sheet) is the Tour's to show.

## Which way each lesson points (Story.LESSONS keys): at the way in, a
## guard, the guard with a post, the second guard, a thing to knock over,
## the case, a light switch or the door out.
const NEWS_AT := {
	"heist": "start", "heist2": "panel", "heist3": "panel", "heist4": "panel",
	"guard": "guard", "torch": "post", "noise": "post", "props": "prop",
	"games": "piece", "case_alarm": "piece", "two": "guard2", "lights": "switch",
	"big": "exit", "finale": "piece",
}


## Everything told before heist n, in order.
static func build(n: int, players: int, guards: Array[Guard]) -> Array:
	var out: Array = []
	out.append({"kind": "piece", "at": _mid(Heist.at), "title": Heist.first_upper(Heist.loot.get("name", "")),
		"text": Heist.loot.get("blurb", ""), "icon": "gem"})
	var teach := String(Story.LEVELS[clampi(n, 1, Story.count()) - 1].get("teach", ""))
	if teach == "heist" and players >= 2:
		teach = "heist%d" % mini(players, 4)
	for card in Story.news(n, players):
		out.append({"kind": "news", "at": _where(NEWS_AT.get(teach, "piece"), guards), "title": card.title,
			"text": card.text, "stage": card.stage, "icon": "news"})
	for line in Briefing.tips(guards, n):
		var where := rule_at(line, guards)
		out.append({"kind": "rule", "at": _where(where, guards), "title": "", "text": line, "icon": _icon(where)})
	var many := "_MANY" if players > 1 else "_ONE"
	out.append({"kind": "start", "at": _mid(Heist.start), "title": "", "text": Text.t("TOUR_MARK_START" + many), "icon": "thief"})
	out.append({"kind": "exit", "at": _mid(Heist.exit), "title": "", "text": Text.t("TOUR_MARK_EXIT" + many), "icon": "exit"})
	return out


## What a rule of Briefing.tips is about, to point at it: "guard", "post",
## "guard2", "panel", "exit", "piece", "switch", "prop" or "start".
static func rule_at(line: String, guards: Array[Guard]) -> String:
	var said := func(keys: Array) -> bool:
		for k in keys:
			for tail in ["", "_ONE", "_MANY"]:
				if Text.t(k + tail) == line:
					return true
		return false
	if said.call(["BRIEF_TEAM_ONE_LOCK", "BRIEF_TEAM_TWO_LOCKS", "BRIEF_TEAM_TWO_PANELS"]):
		return "panel"
	if said.call(["BRIEF_TEAM_ALL_OUT", "TIP_MAP"]):
		return "exit"
	if said.call(["TIP_CASE_ALARM", "TIP_GAMES"]):
		return "piece"
	if said.call(["TIP_LIGHTS"]):
		return "switch"
	if said.call(["BRIEF_PROPS"]):
		return "prop"
	if said.call(["TIP_POST"]):
		return "post"
	if said.call(["TIP_TWO"]):
		return "guard2"
	if said.call(["TIP_GUARDS_NONE"]):
		return "start"
	# A big job's own line: its guard on post, if it has one.
	for k in Story.LEVELS.size():
		if Text.t(String(Story.LEVELS[k].get("tip", "_"))) == line:
			return "post"
	return "guard"


## A place on the plan by what it is (rule_at), falling back on what there
## is: no guard, the way in; no switch or prop, the piece.
static func _where(what: String, guards: Array[Guard]) -> Vector2:
	match what:
		"start": return _mid(Heist.start)
		"exit": return _mid(Heist.exit)
		"piece": return _mid(Heist.at)
		"panel":
			return _mid(Heist.panel) if Heist.panel.x >= 0 else _mid(Heist.at)
		"guard", "guard2", "post":
			if guards.is_empty():
				return _mid(Heist.start)
			var g: Guard = guards[0]
			if what == "guard2" and guards.size() > 1:
				g = guards[1]
			if what == "post":
				for k in guards:
					if k.post.x >= 0:
						g = k
						break
			return Vector2(g.x, g.y)
		"prop":
			var best := _mid(Heist.at)
			var near := INF
			for p in Props.list:
				var d := Vector2(p.x, p.y).distance_to(_mid(Heist.at))
				if d < near:
					near = d
					best = Vector2(p.x, p.y)
			return best
		"switch":
			var best := _mid(Heist.at)
			var near := INF
			for r in Museum.rooms:
				var d := _mid(r.switch_at).distance_to(_mid(Heist.at))
				if d < near:
					near = d
					best = _mid(r.switch_at)
			return best
	return _mid(Heist.at)


## The plan's mark for what a rule points at.
static func _icon(what: String) -> String:
	return {"exit": "exit", "piece": "gem", "panel": "panel", "prop": "prop", "start": "thief", "switch": "switch"}.get(what, "guard")


static func _mid(t: Vector2i) -> Vector2:
	return Vector2(t.x + 0.5, t.y + 0.5)


## What can be picked on the plan while looking round, each pinned where it
## is: the piece's case, what is new, every guard, the alarm panels, the way
## in and the way out, and any rule about somewhere else (a switch, a thing
## to knock over). Each rule of the night (the "rule" beats, in order) goes
## with the mark it is about, to light it up in the list beside the plan.
## A mark is {"kind", "at", "tag", "text", "rules": [rule index], "beat"}:
##   kind   "piece", "news", "guard", "panel", "start", "exit" or "rule"
##   tag    its name over its pin; text, what it is about
##   beat   the beat it tells again (piece, news), or -1
static func marks(beats: Array, guards: Array[Guard]) -> Array:
	var out: Array = []
	var many := false
	for b in beats:
		if b.kind == "start" and b.text == Text.t("TOUR_MARK_START_MANY"):
			many = true
	for i in beats.size():
		var b: Dictionary = beats[i]
		if b.kind == "piece":
			out.append(_mark("piece", b.at, Text.t("TOUR_TAG_PIECE"), Text.t("TOUR_MARK_PIECE"), i))
		elif b.kind == "news":
			out.append(_mark("news", b.at, Text.t("TOUR_TAG_NEWS"), b.title, i))
	for g in guards:
		var still := g.post.x >= 0
		out.append(_mark("guard", Vector2(g.x, g.y), Text.t("TOUR_TAG_GUARD"), Text.t("TOUR_MARK_GUARD_POST" if still else "TOUR_MARK_GUARD_ROUND")))
	if Heist.team:
		for p in [Heist.panel, Heist.panel2]:
			if p.x >= 0:
				out.append(_mark("panel", _mid(p), Text.t("TOUR_TAG_PANEL"), Text.t("TOUR_MARK_PANEL" + ("_MANY" if many else "_ONE"))))
	for b in beats:
		if b.kind in ["start", "exit"]:
			out.append(_mark(b.kind, b.at, Text.t("TOUR_TAG_" + String(b.kind).to_upper()), b.text))
	# Each rule with what it is about; on its own where nothing else is.
	var r := 0
	for b in beats:
		if b.kind != "rule":
			continue
		var best := -1
		var near := 0.9
		for k in out.size():
			if out[k].kind == "news":
				continue
			var d: float = (out[k].at as Vector2).distance_to(b.at)
			if d < near:
				near = d
				best = k
		if best < 0:
			out.append(_mark("rule", b.at, Text.t("TOUR_TAG_RULE"), b.text))
			best = out.size() - 1
		out[best].rules.append(r)
		r += 1
	return out


static func _mark(kind: String, at: Vector2, tag: String, text: String, beat := -1) -> Dictionary:
	return {"kind": kind, "at": at, "tag": tag, "text": text, "rules": [], "beat": beat}
