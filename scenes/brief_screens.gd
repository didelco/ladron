class_name BriefScreens
extends RefCounted
## Before a night: the prologue's tale and the briefing, a page each (the piece's tale, what is new
## tonight, and the plan with the rules for the night, Briefing), and the way to skip them
## or come back out of them.

var host: Game

## the page of the prologue and of the briefing before a night on screen
var prologue_page := 0
var brief_page := 0

## Atraco Sorpresa only: which item of plan_targets() the arrows/WASD have
## landed on, on the plan's own page (there is only the one page in this
## mode — no story, no news, straight to the plan).
var plan_cursor := 0


func _init(game: Game) -> void:
	host = game


## The tale, a paragraph a page, whole at once: turn back, go on, or skip
## the lot and go straight to the night.
func show_prologue(page := 0) -> void:
	host.phase = "prologue"
	prologue_page = page
	var pages := Story.prologue()
	var last := page == pages.size() - 1
	host.hud.show_menu([
		{"title": Text.t("PROLOGUE_TITLE"), "size": 44},
		{"stage": MenuStage.make("story"), "height": 220},
		{"text": pages[page], "size": 19, "wrap": true},
		{"text": dots(page, pages.size()), "colour": Hud.C.dim, "size": 14},
		{"buttons": [
			{"text": Text.t("MENU_BACK") if page == 0 else Text.t("MENU_PREV"), "call": prologue_back, "colour": Hud.C.dim},
			{"text": Text.t("MENU_NEXT"), "call": host._show_city if last else show_prologue.bind(page + 1)},
		], "row": true, "focus": 1},
		{"buttons": [{"text": Text.t("MENU_SKIP"), "call": host._show_city, "colour": Hud.C.dim}], "small": true},
	], "prologue:%d" % page)


## Straight to the night: past the tale and the briefing, into the countdown.
func skip_story() -> void:
	host._start_countdown(Hud.FADE_S)


func prologue_back() -> void:
	if prologue_page > 0:
		show_prologue(prologue_page - 1)
	else:
		host._show_title("story")


## ● ○ ○ : where you are in a run of pages.
func dots(at: int, count: int) -> String:
	var out: Array[String] = []
	for i in count:
		out.append("●" if i == at else "○")
	return " ".join(out)


## Before a night: the piece's tale if it has one (not in the generative,
## straight to the plan there), what is new tonight if anything is (only
## the story teaches), and the plan: the map and the rules for the night
## (Briefing).
func pages() -> Array:
	var pages := []
	if host.mode != "generative" and String(Heist.loot.get("story", "")).strip_edges() != "":
		pages.append("story")
	if host.mode == "story" and not Story.news(host.level, host.players).is_empty():
		pages.append("news")
	pages.append("plan")
	return pages


func show(page: int) -> void:
	var pages := pages()
	page = clampi(page, 0, pages.size() - 1)
	brief_page = page
	host.phase = "brief"
	# In the story, the museum's own picture behind its heists' screens.
	if host.mode == "story":
		host.hud.backdrop(Hud.MUSEUM_FOCUS, "museum_%d" % (Story.museum_of(host.level) + 1))
	var names := {"story": Text.t("BRIEF_TAB_STORY"), "news": Text.t("BRIEF_TAB_NEWS"), "plan": Text.t("BRIEF_TAB_PLAN")}
	var items: Array = []
	match pages[page]:
		"story": items.append_array(story_items())
		"news": items.append_array(news_items())
		"plan": items.append_array(plan_items())
	var last := page == pages.size() - 1
	var plan_nav := plan_nav_active()
	# Along the bottom: back on the left, the next page by name in the middle,
	# and straight to the night on the right (on the last page, the middle
	# one starts it). On Atraco Sorpresa's plan the arrows are busy moving
	# the cursor over the map instead (plan_select), so this row stops
	# looking like it takes them too: no focus ring (unfocusable, mouse
	# only), and a hints row under it says what key or button each one
	# really is (Hud.set_hints_pad keeps it current as the hand changes).
	var row: Array = [
		{"text": Text.t("MENU_BACK"), "call": back, "colour": Hud.C.dim},
		{"text": Text.t("BRIEF_START") if last else Text.t("BRIEF_NEXT_TAB") % names[pages[page + 1]], "call": host._start_countdown.bind(Hud.FADE_S) if last else show.bind(page + 1)},
	]
	if not last:
		row.append({"text": Text.t("BRIEF_SKIP"), "call": skip_story, "colour": Hud.C.dim})
	if plan_nav:
		items.append({"buttons": row, "row": true, "unfocusable": true})
		items.append({"hints": [["accept", Text.t("BRIEF_START")], ["back", Text.t("MENU_BACK")]], "pad": host.hands.last_pad})
	else:
		items.append({"buttons": row, "row": true, "focus": 1})
	host.hud.show_menu(items, "brief:%d" % page)
	if plan_nav:
		# The map's own TextureRect is only laid out once the menu's box has
		# been sized (next idle frame) — the bubble's first position waits
		# for that same beat.
		update_plan_tip.call_deferred()


func back() -> void:
	if brief_page > 0:
		show(brief_page - 1)
	elif host.mode == "story" and host.level == 1:
		show_prologue(Story.prologue().size() - 1)
	elif host.mode == "story":
		host._show_museum_tour(host.level)
	elif host.mode == "challenge":
		host._leave_game(host.challenges.show_map.bind(host.challenges.challenge_map))
	else:
		host._show_generative_menu()


## What changes tonight, a card for each, on the diorama that shows it.
func news_items() -> Array:
	var cards: Array = []
	for n in Story.news(host.level, host.players):
		cards.append({"title": n.title, "text": n.text, "stage": MenuStage.make(n.stage), "static": true, "animate": true, "colour": Hud.C.gold})
	return [
		{"title": Text.t("BRIEF_NEWS_TITLE"), "size": 44},
		{"text": Text.t("BRIEF_NEWS_TEXT"), "colour": Hud.C.dim},
		{"cards": cards, "width": 330 if cards.size() < 3 else 290},
	]


## The story's first page: the gang's job sheet, on paper over the museum's
## picture (EndPages.piece_card) — the piece turning in a polaroid, which
## job this is, its name, what it is like and its tale.
func story_items() -> Array:
	# Rebuilt each time: the last round's piece may still be on the stand.
	host.podium.build()
	return [
		{"card": {"name": Heist.first_upper(Heist.loot.name), "blurb": Heist.loot.blurb,
			"story": Heist.loot.get("story", ""), "photo": host.podium.preview.get_texture()}},
		{"gap": 16},
	]


## The plan: the map on the left; on the right, the piece (turning under a
## light, its name and how long it takes — not in the generative, which
## keeps what is stolen out of the briefing) and the rules for the night
## worked out from it (Briefing). In the generative, the right side shows
## instead whatever the arrows have landed on in the map (plan_select).
func plan_items() -> Array:
	var colours := host._thief_colours().slice(0, host.thieves.size())
	var keys := ["thief", "gem", "exit", "guard", "prop", "route"]
	if Heist.team:
		keys.append("panel")
	var legend_loot := Color(Heist.loot.colour)
	var targets: Array = []
	if host.mode == "generative":
		# Fresh every time the plan is drawn (there is only this one page
		# in the mode, so this only runs once a visit): back where the
		# arrows start.
		plan_cursor = 0
		host.reset_plan_nav()
		targets = plan_targets()
	var mark: Vector2 = targets[plan_cursor].pos if not targets.is_empty() else Vector2.INF
	var left: Array = [
		{"map": Hud.plan_map(host.guards, colours, false, mark), "height": 390},
		{"legend": keys.slice(0, 3), "thieves": colours, "loot": legend_loot},
		{"legend": keys.slice(3), "thieves": colours, "loot": legend_loot},
	]
	var right: Array = []
	if host.mode != "generative":
		# Rebuilt each time: the last round's piece may still be on the stand.
		host.podium.build()
		var piece: Array = [
			{"text": Heist.first_upper(Heist.loot.name), "size": 26, "colour": Color(Heist.loot.colour), "wrap": true, "width": 330, "align": "left"},
			{"text": Briefing.takes(), "size": 15, "colour": Hud.C.dim, "wrap": true, "width": 330, "align": "left"},
		]
		right.append({"columns": [
			{"items": [{"picture": host.podium.preview.get_texture(), "smooth": true, "height": 120}], "middle": true},
			{"items": piece, "separation": 4, "middle": true},
		], "separation": 12})
		right.append({"gap": 4})
	else:
		var sel: Dictionary = targets[plan_cursor] if not targets.is_empty() else {"name": "", "tip": ""}
		right.append({"text": String(sel.get("name", "")), "id": "plan_item_name", "size": 24, "colour": Hud.C.gold, "align": "left"})
		right.append({"text": "• " + String(sel.get("tip", "")), "id": "plan_item_tip", "size": 17, "wrap": true, "width": 540, "align": "left"})
		right.append({"gap": 10})
		# This museum's own code (MuseumCode), to play it again or share it —
		# never the piece stolen, which plan_items keeps out of this mode.
		var code := MuseumCode.encode(host.last_map_seed, host.size, host.theme)
		if code != "":
			right.append({"text": Text.t("BRIEF_CODE_LABEL") % code, "size": 20, "colour": Hud.C.gold, "align": "left"})
			right.append({"buttons": [{"text": Text.t("BRIEF_CODE_COPY"), "call": host.copy_museum_code.bind(code)}], "small": true, "align": "left"})
			right.append({"text": "", "id": "code_status", "size": 14, "colour": Hud.C.green, "align": "left"})
			right.append({"gap": 10})
	right.append({"title": Text.t("BRIEF_TIPS_TITLE"), "size": 24, "align": "left"})
	for tip in Briefing.tips(host.guards, host.level if host.mode == "story" else 0):
		right.append({"text": "• " + tip, "size": 17, "wrap": true, "width": 540, "align": "left"})
	return [{"columns": [
		{"items": left, "separation": 6, "middle": true},
		{"items": right, "width": 540, "separation": 8, "middle": true},
	], "separation": 36}]


## Whether WASD/flechas move a cursor over the plan's items instead of the
## row of buttons below it — only in Atraco Sorpresa (the piece's tale and
## the news are both out of this mode, so "plan" is the only page there,
## always at brief_page 0).
func plan_nav_active() -> bool:
	return host.mode == "generative" and pages()[brief_page] == "plan"


## What the arrows can land on, on the plan, this round: the piece's case,
## the way out, each guard and the alarm panels (if the job wants two
## hands). Name and clue reuse Tour's own words for them (PlanBeats), never
## the piece's own name, photo or time — those stay out of the generative's
## briefing on purpose (see plan_items). pos: the tile to ring on the map.
func plan_targets() -> Array:
	var many := host.thieves.size() > 1
	var out: Array = [
		{"name": Text.t("TOUR_TAG_PIECE"), "tip": Text.t("PLAN_ITEM_PIECE"), "pos": _mid(Heist.at)},
		{"name": Text.t("TOUR_TAG_EXIT"), "tip": Text.t("TOUR_MARK_EXIT_MANY" if many else "TOUR_MARK_EXIT_ONE"), "pos": _mid(Heist.exit)},
	]
	for g in host.guards:
		var tip := Text.t("TOUR_MARK_GUARD_POST" if g.post.x >= 0 else "TOUR_MARK_GUARD_ROUND")
		var ear := PlanBeats.guard_hearing_trait(g)
		out.append({"name": "%s · %s" % [Text.t("TOUR_TAG_GUARD"), g.name], "tip": tip + (" " + ear if ear != "" else ""), "pos": Vector2(g.x, g.y)})
	if Heist.team:
		for p in [Heist.panel, Heist.panel2]:
			if p.x >= 0:
				out.append({"name": Text.t("TOUR_TAG_PANEL"), "tip": Text.t("TOUR_MARK_PANEL_MANY" if many else "TOUR_MARK_PANEL_ONE"), "pos": _mid(p)})
	return out


func _mid(t: Vector2i) -> Vector2:
	return Vector2(t.x + 0.5, t.y + 0.5)


## The cursor a step on (-1 or 1), round the ends: the detail card and the
## ring on the map both move to it, the menu itself untouched (Hud.set_text,
## Hud.set_menu_map — no rebuild, no refocus).
func plan_select(delta: int) -> void:
	var targets := plan_targets()
	if targets.is_empty():
		return
	plan_cursor = posmod(plan_cursor + delta, targets.size())
	var t: Dictionary = targets[plan_cursor]
	host.hud.set_text("plan_item_name", String(t.name), Hud.C.gold)
	host.hud.set_text("plan_item_tip", "• " + String(t.tip), Hud.C.text)
	var colours := host._thief_colours().slice(0, host.thieves.size())
	host.hud.set_menu_map(Hud.plan_map(host.guards, colours, false, t.pos))
	update_plan_tip()
	host.sfx.ui("nav")


## The same detail as the fixed card beside the map (plan_item_name/
## plan_item_tip), floating over the item itself instead — a Prompt-style
## bubble (Hud.set_menu_tip), at the spot menu_map_point works out for it
## on the folded paper. The card stays too: on a small map, close to an
## edge, the bubble can only do so much to stay clear of the ring and of
## its neighbours, and it is an approximation of where the paper's own
## camera puts things (Hud.menu_map_point) rather than read off it — the
## card is the one of the two always right.
func update_plan_tip() -> void:
	var targets := plan_targets()
	if targets.is_empty():
		host.hud.set_menu_tip("", "", Vector2.ZERO, Hud.C.gold)
		return
	var t: Dictionary = targets[plan_cursor]
	host.hud.set_menu_tip(String(t.name), String(t.tip), host.hud.menu_map_point(t.pos), Hud.C.gold)
