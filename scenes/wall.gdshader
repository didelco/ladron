shader_type spatial;
// The face of the gallery walls, drawn per pixel in world space, so the
// pattern runs on from one block of wall to the next with no seams: a
// wainscot of framed wooden panels below the dado rail, and above it the
// wallpaper — plain plaster, a damask lattice or broad stripes, whichever
// the museum's style (MuseumView.THEMES) says.
//
// Toon-lit like everything else on the walls; each block's small shade
// (the MultiMesh instance colour) still comes through, so a long wall is
// not one flat colour.

render_mode diffuse_toon, specular_disabled;

uniform vec3 paper = vec3(0.2);
uniform vec3 paper2 = vec3(0.25);
// 0 plaster, 1 damask, 2 stripes
uniform int pattern = 0;
uniform vec3 wainscot = vec3(0.15);
// height of the dado rail; 0 for no wainscot at all
uniform float dado = 0.5;

varying vec3 wpos;
varying vec3 wnorm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Along the wall, whichever way it faces.
	float u = abs(wnorm.x) > 0.5 ? wpos.z : wpos.x;
	float y = wpos.y;
	vec3 c;
	if (y < dado) {
		// Framed panels, half a tile wide: a darker frame round each.
		float pu = fract(u / 0.5);
		float pv = y / dado;
		float inside = step(0.1, pu) * step(pu, 0.9) * step(0.16, pv) * step(pv, 0.86);
		c = mix(wainscot * 0.7, wainscot, inside);
	} else if (pattern == 1) {
		// Damask: a lattice of small diamonds, offset every other column.
		vec2 q = vec2(u, y) * 4.0;
		q.y += 0.5 * mod(floor(q.x), 2.0);
		float d = abs(fract(q.x) - 0.5) + abs(fract(q.y) - 0.5);
		c = mix(paper, paper2, smoothstep(0.3, 0.24, d));
	} else if (pattern == 2) {
		// Stripes, a third of a tile wide, with a thin pale line between.
		float s = fract(u * 3.0);
		c = mix(paper, paper2, step(0.5, s));
		c = mix(c, paper2 * 1.25, smoothstep(0.02, 0.0, abs(s - 0.5)));
	} else {
		// Plaster: a faint mottle, so it is not flat paint.
		c = paper * (0.95 + 0.07 * hash(floor(vec2(u, y) * 6.0)));
	}
	ALBEDO = c * COLOR.rgb;
}
