class_name BriefScreens
extends RefCounted
## Before a night: the prologue's tale and the briefing, a page each (the piece's tale, what is new
## tonight, and the plan with the rules for the night, Briefing), and the way to skip them
## or come back out of them.

var host: Game

## the page of the prologue and of the briefing before a night on screen
var prologue_page := 0
var brief_page := 0


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


## Before a night, the same in every mode: the piece's tale if it has one,
## what is new tonight if anything is (only the story teaches), and the plan:
## the map and the rules for the night (Briefing).
func pages() -> Array:
	var pages := []
	if String(Heist.loot.get("story", "")).strip_edges() != "":
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
	# Along the bottom: back on the left, the next page by name in the middle,
	# and straight to the night on the right (on the last page, the middle
	# one starts it).
	var row: Array = [
		{"text": Text.t("MENU_BACK"), "call": back, "colour": Hud.C.dim},
		{"text": Text.t("BRIEF_START") if last else Text.t("BRIEF_NEXT_TAB") % names[pages[page + 1]], "call": host._start_countdown.bind(Hud.FADE_S) if last else show.bind(page + 1)},
	]
	if not last:
		row.append({"text": Text.t("BRIEF_SKIP"), "call": skip_story, "colour": Hud.C.dim})
	items.append({"buttons": row, "row": true, "focus": 1})
	host.hud.show_menu(items, "brief:%d" % page)


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
## light, its name and how long it takes) and the rules for the night
## worked out from it (Briefing).
func plan_items() -> Array:
	var colours := host._thief_colours().slice(0, host.thieves.size())
	var keys := ["thief", "gem", "exit", "guard", "prop", "route"]
	if Heist.team:
		keys.append("panel")
	var legend_loot := Color(Heist.loot.colour)
	var left: Array = [
		{"map": Hud.plan_map(host.guards, colours), "height": 390},
		{"legend": keys.slice(0, 3), "thieves": colours, "loot": legend_loot},
		{"legend": keys.slice(3), "thieves": colours, "loot": legend_loot},
	]
	# Rebuilt each time: the last round's piece may still be on the stand.
	host.podium.build()
	var piece: Array = [
		{"text": Heist.first_upper(Heist.loot.name), "size": 26, "colour": Color(Heist.loot.colour), "wrap": true, "width": 330, "align": "left"},
		{"text": Briefing.takes(), "size": 15, "colour": Hud.C.dim, "wrap": true, "width": 330, "align": "left"},
	]
	var right: Array = [{"columns": [
		{"items": [{"picture": host.podium.preview.get_texture(), "smooth": true, "height": 120}], "middle": true},
		{"items": piece, "separation": 4, "middle": true},
	], "separation": 12}]
	right.append({"gap": 4})
	right.append({"title": Text.t("BRIEF_TIPS_TITLE"), "size": 24, "align": "left"})
	for tip in Briefing.tips(host.guards, host.level if host.mode == "story" else 0):
		right.append({"text": "• " + tip, "size": 17, "wrap": true, "width": 540, "align": "left"})
	return [{"columns": [
		{"items": left, "separation": 6, "middle": true},
		{"items": right, "width": 540, "separation": 8, "middle": true},
	], "separation": 36}]
