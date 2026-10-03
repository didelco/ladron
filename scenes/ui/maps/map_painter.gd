class_name MapPainter
extends RefCounted
## Dibuja los planos e iconos. Usa el estado compartido de Hud y conserva sus píxeles.

## The map as taken out mid-job, on parchment: the plan, where each thief is
## now, the piece (or where it lies), the door, and the alarm panel for two.
## No guards: a map does not know where they are.
## The map you take out mid-job: the plan with its cases, the things you
## can knock over, the piece, the way out and where the thieves are — the
## important ones as icons, all of them in the legend under it.
static func live_map(thieves: Array[Thief], colours: Array) -> Image:
	var none: Array[Guard] = []
	return draw_map(thieves, colours, none, [])

## The plan on parchment, before the job: the same map, with the route in
## ink dots, where you come in (the thieves' icons) and where each guard
## starts (a red cross). pins: for the plan looked round pin by pin
## (PlanTalk), whose chinchetas already mark the guards and the way in —
## so the picture under them does not print its own, one on top of the
## other. mark: a tile to ring in gold on top of everything else (the item
## the arrows have landed on, in the Atraco Sorpresa's plan — BriefScreens).
static func plan_map(guards: Array[Guard], colours: Array, pins := false, mark := Vector2.INF) -> Image:
	var none: Array[Thief] = []
	Hud.home_map = false
	return draw_map(none, [], guards, colours, pins, mark)

static func draw_map(thieves: Array[Thief], colours: Array, guards: Array[Guard], start_colours: Array, pins := false, mark := Vector2.INF) -> Image:
	var s := clampi(int(Hud.MAP_WIDTH / Museum.w), 8, 32)
	var img := Image.create(Museum.w * s, Museum.h * s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# The plan in three tones: floor, the cases on it, walls; and what can be
	# knocked over, still standing, a tile a shade off the cases.
	for y in Museum.h:
		for x in Museum.w:
			if Museum.is_outside(x, y):
				continue
			var t := Museum.grid[y * Museum.w + x]
			var tone: Color = Hud.MAP_WALL if t == Tiles.WALL else (Hud.MAP_CASE if t == Tiles.COVER else Hud.MAP_FLOOR)
			# In the house, a dark room is only its shape: no furniture.
			if Hud.home_map and t != Tiles.WALL and Hud.dark_rooms.has(Den.tile_room(Vector2i(x, y))):
				tone = Hud.MAP_FOG
			img.fill_rect(Rect2i(x * s, y * s, s, s), tone)
	if Hud.home_map:
		# The doors: floor when open, wood in the wall when shut.
		for d in Den.DOORS:
			var r := Den.door_rect(d.id)
			var tone: Color = Hud.MAP_FLOOR if Den.is_open(d.id) else Hud.MAP_DOOR
			img.fill_rect(Rect2i(r.position.x * s, r.position.y * s, r.size.x * s, r.size.y * s), tone)
	# A challenge's own doors (Museum.doors): the same wood tone shut, floor
	# open — wall and floor already say as much, this just makes it read as
	# a door and not just a gap in the plan.
	for d in Museum.doors:
		img.fill_rect(Rect2i(d.x * s, d.y * s, s, s), Hud.MAP_FLOOR if Museum.is_door_open(d) else Hud.MAP_DOOR)
	for p in Props.list:
		if Hud.home_map and Hud.dark_rooms.has(Den.tile_room(p.tile)):
			continue
		if not p.fallen:
			img.fill_rect(Rect2i(p.tile.x * s, p.tile.y * s, s, s), Hud.MAP_PROP)
	var at := func(p: Vector2) -> Vector2i: return Vector2i(int(p.x * s), int(p.y * s))
	var mid := func(t: Vector2i) -> Vector2: return Vector2(t.x + 0.5, t.y + 0.5)
	# The plan, before the job: the way from the way in to the piece to the door.
	if not start_colours.is_empty():
		var d := maxi(6, s / 2)
		for i in Heist.route.size():
			if i % 2 == 0:
				var t: Vector2i = Heist.route[i]
				img.fill_rect(Rect2i(t.x * s + s / 2 - d / 2, t.y * s + s / 2 - d / 2, d, d), Hud.MAP_ROUTE)
	# The door, in green, and its sign just inside it.
	var door: Vector2i = Heist.exit + Heist.exit_face
	img.fill_rect(Rect2i(door.x * s, door.y * s, s, s), Hud.C.green)
	if Heist.team and not Heist.taken and not Hud.home_map:
		stamp(img, Hud.ICON_PANEL, at.call(mid.call(Heist.panel)), 4, {"#": Color("#ff922b"), "w": Hud.MAP_INK})
		if Heist.panel2.x >= 0:
			stamp(img, Hud.ICON_PANEL, at.call(mid.call(Heist.panel2)), 4, {"#": Color("#ff922b"), "w": Hud.MAP_INK})
	# The piece: a gem in its colour, sparkling, wherever it is.
	# The piece: a diamond in its colour, giving off light.
	var gem := func(p: Vector2, r: int) -> void:
		var c: Vector2i = (at.call(p) as Vector2i).clamp(Vector2i(r * 2, r * 2), img.get_size() - Vector2i(r * 2, r * 2))
		diamond(img, c, r, Color(Heist.loot.colour))
	# (In the house there is no piece to steal: the dojo's case is sealed.)
	if Hud.home_map:
		pass
	elif not Heist.taken:
		gem.call(mid.call(Heist.at), 20)
	elif Heist.dropped != Vector2.INF:
		gem.call(Heist.dropped, 16)
	if not pins:
		for g in guards:
			square(img, at.call(Vector2(g.x, g.y)), 12, Hud.MAP_GUARD)
	# The way out: the kunai that points the way in play, green, through the
	# door and pointing out.
	kunai(img, at.call(mid.call(Heist.exit) + Vector2(Heist.exit_face) * 0.3), Vector2(Heist.exit_face), 1.6, Hud.C.green)
	# Where you come in: a dot for each thief who will, side by side. Not
	# with the pins: the "start" chincheta already says as much.
	if not pins:
		for i in start_colours.size():
			var off := Vector2((i - (start_colours.size() - 1) / 2.0) * 34.0 / s, 0)
			dot(img, at.call(mid.call(Heist.start) + off), 14, start_colours[i], Hud.MAP_INK)
	for i in thieves.size():
		var p := thieves[i]
		if p.out:
			continue
		var c: Vector2i = at.call(Vector2(p.x, p.y))
		# The piece rides along with whoever has it, glowing behind them.
		if Heist.carrier == p.id:
			glow(img, c, 44, Color(Heist.loot.colour))
		dot(img, c, 14, colours[i], Color.WHITE)
	if mark != Vector2.INF:
		ring(img, at.call(mark), maxi(18, s), maxi(3, s / 6), Color("#ffe066"))
	return img

## A ring in the given colour, nothing filled inside: round whatever the
## cursor has landed on (BriefScreens.plan_select), on top of the rest.
static func ring(img: Image, c: Vector2i, r: int, thickness: int, colour: Color) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d := Vector2(dx, dy).length()
			if d > r or d < r - thickness:
				continue
			var x := c.x + dx
			var y := c.y + dy
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, colour)

## A thief: a disc in its colour with a ring round it.
static func dot(img: Image, c: Vector2i, r: int, colour: Color, ring: Color) -> void:
	disc(img, c, r + 3, Hud.MAP_INK)
	disc(img, c, r + 1, ring)
	disc(img, c, r - 2, colour)

## A guard: a red square, outlined.
static func square(img: Image, c: Vector2i, half: int, colour: Color) -> void:
	img.fill_rect(Rect2i(c.x - half - 3, c.y - half - 3, half * 2 + 6, half * 2 + 6), Hud.MAP_INK)
	img.fill_rect(Rect2i(c.x - half, c.y - half, half * 2, half * 2), colour)

## Light spilling round something bright: blended over what is under it,
## strongest in the middle and gone at r.
static func glow(img: Image, c: Vector2i, r: int, colour: Color) -> void:
	var lit := colour.lightened(0.35)
	for y in range(maxi(0, c.y - r), mini(img.get_height(), c.y + r + 1)):
		for x in range(maxi(0, c.x - r), mini(img.get_width(), c.x + r + 1)):
			var d := Vector2(x - c.x, y - c.y).length() / r
			if d >= 1.0:
				continue
			var k := pow(1.0 - d, 1.6) * 0.85
			var under := img.get_pixel(x, y)
			var mixed := under.lerp(lit, k)
			mixed.a = maxf(under.a, k)
			img.set_pixel(x, y, mixed)

## The piece: a diamond (a square on its point) in its colour, lighter on
## its upper facets with a white glint, in a halo of its own light with
## four rays.
static func diamond(img: Image, c: Vector2i, r: int, colour: Color) -> void:
	glow(img, c, r * 3, colour)
	for k in 4:
		var dir := Vector2.from_angle(k * PI / 2 + PI / 4)
		for t in range(r + 4, r * 2 + 2):
			var q := Vector2(c) + dir * t
			img.fill_rect(Rect2i(int(q.x) - 1, int(q.y) - 1, 3, 3), Color(1, 1, 0.9).lerp(colour.lightened(0.5), float(t - r) / (r + 2)))
	for pass_n in 2:
		var rr := r + 3 - pass_n * 3
		var fill: Color = Hud.MAP_INK if pass_n == 0 else colour
		for dy in range(-rr, rr + 1):
			var half := rr - absi(dy)
			img.fill_rect(Rect2i(c.x - half, c.y + dy, half * 2 + 1, 1), fill)
	for dy in range(-r + 2, 0):
		var half := r - absi(dy) - 2
		img.fill_rect(Rect2i(c.x - half, c.y + dy, half * 2 + 1, 1), colour.lightened(0.3))
	img.fill_rect(Rect2i(c.x - r / 3, c.y - r / 2, r / 4 + 2, r / 4 + 2), Color.WHITE)

## The HUD's kunai (KUNAI_BLADE) scaled by k, centred on c and pointing
## along dir, outlined.
static func kunai(img: Image, c: Vector2i, dir: Vector2, k: float, colour: Color) -> void:
	var angle := dir.angle()
	var blade := PackedVector2Array()
	for q in Hud.KUNAI_BLADE:
		# Centred on its length: the blade runs from -12 to 30.
		blade.append(((q - Vector2(9, 0)) * k).rotated(angle))
	var ring: PackedVector2Array = Geometry2D.offset_polygon(blade, 3.5)[0]
	var reach := int(30 * k) + 4
	for y in range(maxi(0, c.y - reach), mini(img.get_height(), c.y + reach + 1)):
		for x in range(maxi(0, c.x - reach), mini(img.get_width(), c.x + reach + 1)):
			var p := Vector2(x - c.x, y - c.y)
			if Geometry2D.is_point_in_polygon(p, blade):
				img.set_pixel(x, y, colour)
			elif Geometry2D.is_point_in_polygon(p, ring):
				img.set_pixel(x, y, Hud.MAP_INK)

## A legend icon: the map's own mark, drawn small on its own.
static func legend_icon(key: String, colour := Color.WHITE) -> ImageTexture:
	var img := Image.create(64, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2i(32, 20)
	match key:
		"thief":
			img = Image.create(40, 40, false, Image.FORMAT_RGBA8)
			img.fill(Color(0, 0, 0, 0))
			dot(img, Vector2i(20, 20), 11, colour, Hud.MAP_INK)
		"gem": diamond(img, c, 9, colour)
		"guard": square(img, c, 10, Hud.MAP_GUARD)
		"panel": stamp(img, Hud.ICON_PANEL, c, 4, {"#": Color("#ff922b"), "w": Hud.MAP_INK})
		"prop":
			img.fill_rect(Rect2i(c.x - 12, c.y - 12, 24, 24), Hud.MAP_WALL)
			img.fill_rect(Rect2i(c.x - 10, c.y - 10, 20, 20), Hud.MAP_PROP)
		"route":
			for k in 3:
				img.fill_rect(Rect2i(10 + k * 17, 15, 10, 10), Color("#e8d6b4"))
		"exit": kunai(img, c, Vector2.RIGHT, 1.2, Hud.C.green)
		"door":
			img.fill_rect(Rect2i(c.x - 12, c.y - 12, 24, 24), Hud.MAP_INK)
			img.fill_rect(Rect2i(c.x - 10, c.y - 10, 20, 20), Hud.MAP_DOOR)
		"fog":
			img.fill_rect(Rect2i(c.x - 12, c.y - 12, 24, 24), Hud.MAP_INK)
			img.fill_rect(Rect2i(c.x - 10, c.y - 10, 20, 20), Hud.MAP_FOG)
	return ImageTexture.create_from_image(img)

static func disc(img: Image, c: Vector2i, r: int, colour: Color) -> void:
	for dy in range(-r, r + 1):
		var half := int(sqrt(float(r * r - dy * dy)))
		img.fill_rect(Rect2i(c.x - half, c.y + dy, half * 2 + 1, 1), colour)

## A mask stamped centred on c, k pixels a cell; with an outline (ink by
## default) round every filled cell so it stands off the plan.
static func stamp(img: Image, mask: Array, c: Vector2i, k: int, colours: Dictionary, outline := true, ring := Hud.MAP_INK) -> void:
	var w: int = mask[0].length()
	var h := mask.size()
	var x0 := c.x - w * k / 2
	var y0 := c.y - h * k / 2
	var o := maxi(2, k / 2)
	if outline:
		for y in h:
			for x in w:
				if mask[y][x] != ".":
					img.fill_rect(Rect2i(x0 + x * k - o, y0 + y * k - o, k + o * 2, k + o * 2), ring)
	for y in h:
		for x in w:
			var ch: String = mask[y][x]
			if colours.has(ch):
				img.fill_rect(Rect2i(x0 + x * k, y0 + y * k, k, k), colours[ch])

## The mission map: the plan, the route from the way in to the piece to the
## door, and where each guard starts.
static func mission_map(guards: Array[Guard]) -> ImageTexture:
	var s := 8
	var img := Image.create(Museum.w * s, Museum.h * s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in Museum.h:
		for x in Museum.w:
			if Museum.is_outside(x, y):
				continue
			var t := Museum.grid[y * Museum.w + x]
			var c := Color("#1a1538") if t == Tiles.WALL else (Color("#3a3a5a") if t == Tiles.COVER else Color("#2a2550"))
			img.fill_rect(Rect2i(x * s, y * s, s, s), c)
	for t in Heist.route:
		img.fill_rect(Rect2i(t.x * s + s / 2 - 1, t.y * s + s / 2 - 1, 2, 2), Color("#e8ddc0"))
	var mark := func(t: Vector2i, colour: Color, r: int) -> void:
		img.fill_rect(Rect2i(t.x * s + s / 2 - r, t.y * s + s / 2 - r, r * 2, r * 2), colour)
	# Things to knock over, for planning a distraction.
	for p in Props.list:
		mark.call(p.tile, Color("#c9a15a"), 2)
	# Guards first: the way in, the piece and the door go on top.
	for g in guards:
		mark.call(Vector2i(int(g.x), int(g.y)), Hud.C.alert, 3)
	mark.call(Heist.start, Hud.C.safe, 3)
	mark.call(Heist.at, Color(Heist.loot.colour), 4)
	mark.call(Heist.exit, Hud.C.green, 3)
	if Heist.team:
		mark.call(Heist.panel, Color("#ff922b"), 3)
	return ImageTexture.create_from_image(img)
