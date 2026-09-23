class_name Mulberry32
extends RefCounted
## Small deterministic PRNG, so a seed always rebuilds the same museum.
##
## A bit-exact port of the web version's mulberry32. JavaScript does this in
## 32-bit integers; GDScript integers are 64-bit, so every step is masked back
## to 32 bits, and the 32x32 multiply is split in 16-bit halves — a straight
## product would overflow 64 bits and give a different museum from the same
## seed. tests/test_rng.gd checks it against numbers exported from the web.

const MASK := 0xFFFFFFFF

var _a: int


func _init(seed: int) -> void:
	_a = seed & MASK


## Next number in [0, 1).
func next() -> float:
	_a = (_a + 0x6D2B79F5) & MASK
	var t := _imul(_a ^ (_a >> 15), 1 | _a)
	# JS adds two int32 results as ordinary numbers, then ^ truncates to int32:
	# in unsigned terms, add and mask.
	t = ((t + _imul(t ^ (t >> 7), 61 | t)) & MASK) ^ t
	return float((t ^ (t >> 14)) & MASK) / 4294967296.0


## Next integer in [0, n).
func below(n: int) -> int:
	return int(floor(next() * n))


## Math.imul: the low 32 bits of a 32x32 product, without overflowing int64.
static func _imul(a: int, b: int) -> int:
	a &= MASK
	b &= MASK
	var al := a & 0xFFFF
	var ah := a >> 16
	var bl := b & 0xFFFF
	var bh := b >> 16
	return (al * bl + (((ah * bl + al * bh) & 0xFFFF) << 16)) & MASK
