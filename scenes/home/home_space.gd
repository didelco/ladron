class_name HomeSpace
extends DenView
## Each PackedScene owns its floor plan, furniture and entrances. Coordinates
## are local to this scene; neighbouring spaces are never built in its world.
@export var space_id := "salon"
@export var map_size := Vector2i(21, 25)
@export var rooms: Dictionary = {}
@export var doors: Array = []
@export var sensors: Dictionary = {}
@export var spawn := Vector2i(9, 19)
@export var arrivals: Dictionary = {}
@export var exit_tile := Vector2i(9, 22)
@export var case_tile := Vector2i(9, 18)
@export var front_door: Array = [9, 23, 2, 1]
@export var furniture: Array = []
@export var gallery: Array = []
@export var dojo_plan: Array = []
@export var dojo_zones: Dictionary = {}
## {target: scene id, rect: [x,y,w,h], label: translation key}.
@export var portals: Array = []

func configure(from := "") -> void:
	Den.W = map_size.x
	Den.H = map_size.y
	Den.ROOMS = rooms.duplicate(true)
	Den.ORDER = rooms.keys()
	Den.DOORS = doors.duplicate(true)
	Den.DOOR_SENSORS = sensors.duplicate(true)
	Den.SPAWN = arrivals.get(from, spawn)
	Den.EXIT = exit_tile
	Den.CASE_AT = case_tile
	Den.FRONT_DOOR = front_door.duplicate()
	Den.DOJO_PLAN = dojo_plan.duplicate()
	Den.DOJO_ZONES = dojo_zones.duplicate(true)
	Den.PORTALS = portals.duplicate(true)
	Den.scoped = true
	Den._furniture = furniture.duplicate(true)
	Den._stands = gallery.duplicate(true)

func build() -> void:
	super.build()
	for p in portals:
		var r: Array = p.rect
		var horizontal: bool = r[2] >= r[3]
		var length := float(maxi(r[2], r[3]))
		var gate := _pivot(self, to_world(r[0] + r[2] / 2.0, r[1] + r[3] / 2.0), 0.0 if horizontal else PI / 2.0)
		for side in [-1.0, 1.0]:
			_mesh(gate, _box(Vector3(0.12, 1.1, 0.25)), WOOD, Vector3(side * (length / 2.0 - 0.06), 0.55, 0))
		_mesh(gate, _box(Vector3(length, 0.12, 0.25)), WOOD, Vector3(0, 1.15, 0))
		var sign := Label3D.new()
		sign.text = Text.t(p.label)
		sign.font_size = 32
		sign.pixel_size = 0.012
		sign.position.y = 1.65
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		gate.add_child(sign)
