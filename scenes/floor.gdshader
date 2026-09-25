shader_type spatial;
// The floor, drawn per pixel instead of painted into an image: sharp at any
// museum size, and nothing to build in GDScript pixel by pixel. Three kinds,
// one per museum style (MuseumView.THEMES):
//   0 marble: slabs two tiles across, each with its own tone and its own run
//     of veins, a cut joint round every one;
//   1 concrete: big polished slabs three tiles across, mottled, fine joints;
//   2 boards: long wooden planks in a staggered bond, grain and seams.
// And, whatever the floor, a soft shadow where it meets a wall or a case,
// read from a one-texel-per-tile map of the plan with linear filtering — the
// blur of that map *is* the contact shadow.
//
// Polished: the slabs are glossy so a torch pool gets a hot glint in it and
// the lamps and the lit exit mirror in the marble; the joints are matt. Plain
// Lambert, not toon: toon's cut-off is tied to roughness, and on a glossy
// floor it turned a torch pool into a flat white slab with a hard far edge.

render_mode diffuse_lambert, specular_schlick_ggx;

// r: how solid the tile is (1 wall, 0.6 case, 0 floor); g: 1 outside the building
uniform sampler2D plan : filter_linear, repeat_disable;
uniform sampler2D veins : filter_linear_mipmap, repeat_enable;
uniform vec2 size = vec2(23.0, 17.0);
uniform int pattern = 0;
uniform vec3 stone = vec3(0.118, 0.110, 0.145);
uniform vec3 stone2 = vec3(0.13, 0.12, 0.16);
uniform vec3 joint = vec3(0.278, 0.263, 0.341);
uniform vec3 night = vec3(0.039, 0.035, 0.094);
uniform float gloss_roughness = 0.22;
uniform float joint_roughness = 0.75;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 g = UV * size;                 // grid coordinates, in tiles
	vec3 base;
	float face;     // 1 on the stone or wood, 0 in a joint or seam
	float wear;     // extra roughness, so reflections do not look like one mirror
	float vein = 0.0;
	if (pattern == 2) {
		// Planks a quarter of a tile wide and a tile and a half long, each
		// row shifted by a random amount; a tone per plank, grain along it.
		vec2 p = vec2(g.x, g.y * 4.0);
		float row = floor(p.y);
		p.x += hash(vec2(row, 1.0)) * 1.5;
		vec2 plank = vec2(floor(p.x / 1.5), row);
		vec2 in_plank = vec2(fract(p.x / 1.5), fract(p.y));
		base = mix(stone, stone2, hash(plank)) * (0.9 + hash(plank + 5.0) * 0.15);
		float grain = texture(veins, vec2(g.x * 0.25, row * 0.37 + in_plank.y * 0.05)).r;
		base *= 0.85 + grain * 0.3;
		float seam = min(min(in_plank.x * 1.5, (1.0 - in_plank.x) * 1.5), min(in_plank.y, 1.0 - in_plank.y) * 0.25) * 4.0;
		face = smoothstep(0.02, 0.06, seam);
		base = mix(joint * 0.5, base, face);
		wear = 0.25 + hash(plank + 11.0) * 0.15;
	} else {
		float across = pattern == 1 ? 3.0 : 2.0;
		vec2 slab = floor(g / across);
		vec2 in_slab = fract(g / across);
		// Each slab a shade of its own, the two tones alternating.
		float checker = mod(slab.x + slab.y, 2.0);
		base = mix(stone, stone2, checker) * (0.96 + (hash(slab) - 0.5) * 0.08);
		float n = texture(veins, g * 0.35 + hash(slab + 3.0) * 10.0).r;
		if (pattern == 1) {
			// Concrete: a soft mottle, no veins.
			base *= 0.9 + n * 0.2;
		} else {
			// Marble veins: thin bright ridges of a noise field, turned and
			// shifted per slab so neighbouring slabs do not line up.
			float turn = hash(slab + 7.0) * 6.2831;
			mat2 rot = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn)));
			n = texture(veins, rot * (g * 0.35) + hash(slab + 3.0) * 10.0).r;
			vein = 1.0 - smoothstep(0.0, 0.035, abs(n - 0.5));
			base = mix(base, base * 1.55 + vec3(0.02), vein * 0.35);
		}
		// The joint: a darker cut (finer on concrete), with a pale lip.
		float edge = min(min(in_slab.x, 1.0 - in_slab.x), min(in_slab.y, 1.0 - in_slab.y)) * across;
		face = smoothstep(pattern == 1 ? 0.008 : 0.012, pattern == 1 ? 0.02 : 0.03, edge);
		base = mix(joint * 0.55, base, face);
		base += vec3(0.02) * (1.0 - smoothstep(0.03, 0.05, min(in_slab.x, in_slab.y) * across));
		wear = hash(slab + 11.0) * 0.12 + vein * 0.1 + (pattern == 1 ? 0.12 : 0.0);
	}

	// Contact shadow: the plan map, blurred by filtering and a few taps.
	vec2 tuv = g / size;
	vec2 px = 1.0 / size;
	float solid = 0.0;
	solid += texture(plan, tuv).r * 0.4;
	solid += texture(plan, tuv + vec2(px.x, 0.0) * 0.35).r * 0.15;
	solid += texture(plan, tuv - vec2(px.x, 0.0) * 0.35).r * 0.15;
	solid += texture(plan, tuv + vec2(0.0, px.y) * 0.35).r * 0.15;
	solid += texture(plan, tuv - vec2(0.0, px.y) * 0.35).r * 0.15;
	base *= 1.0 - smoothstep(0.02, 0.45, solid) * 0.85;

	float outside = texture(plan, tuv).g;
	ALBEDO = mix(base, night, step(0.5, outside));
	ROUGHNESS = mix(joint_roughness, gloss_roughness + wear, face);
	SPECULAR = 0.6;
}
