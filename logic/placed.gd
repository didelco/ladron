class_name Placed
extends RefCounted
## Data only: what the night stands on the cases of a museum besides its
## exhibits. The museum forgets it all when it is built anew (Museum.load_grid),
## and it does so through here so that it does not need Plinths or Hideouts,
## which need the museum to do their work.
##
## Those two keep these very objects under their own names (Plinths.list,
## Hideouts.pieces): they are cleared in place, never replaced.

## The cases that are empty pedestals to pose on (Plinths.list).
static var plinths: Array[Vector2i] = []
## The pieces of furniture to hide in: tile -> kind (Hideouts.pieces).
static var furniture := {}


static func clear() -> void:
	plinths.clear()
	furniture.clear()
