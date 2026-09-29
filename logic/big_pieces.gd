class_name BigPieces
extends RefCounted
## Data only: the pieces that take more than one tile, in tiles across and
## along. It lives apart so that whoever needs to know the kinds (Themes, the
## editor) does not need the generator (MapGen) for it.

## The dinosaur skeleton on its platform, the sarcophagus on its bier, the
## bear standing up on its long plinth, arms spread; and three to hide in
## (Hideouts): the Trojan horse on its square wheeled deck, the mammoth and the
## hollow log.
const SIZES := {"dinosaur": Vector2i(2, 3), "sarcophagus": Vector2i(1, 3), "bear": Vector2i(1, 2),
	"trojan_horse": Vector2i(2, 2), "mammoth": Vector2i(2, 3), "log": Vector2i(1, 3), "car": Vector2i(2, 3)}
