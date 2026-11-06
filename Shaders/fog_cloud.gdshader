shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable;
uniform vec2 rect_size = vec2(1000.0, 600.0);
uniform float edge_px = 120.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
// copy this value from fog_color in fog.gdshader so both fogs match
uniform vec4 fog_color : source_color = vec4(0.45, 0.5, 0.55, 1.0);

void fragment() {
	vec2 d = min(UV, vec2(1.0) - UV) * rect_size;
	float edge = smoothstep(0.0, edge_px, min(d.x, d.y));
	vec2 p = UV * rect_size * 0.0015;
	float n = texture(noise_tex, p + vec2(TIME * 0.025, TIME * 0.012)).r;
	float n2 = texture(noise_tex, p * 2.3 - vec2(TIME * 0.03, TIME * 0.01)).r;
	float cloud = smoothstep(0.25, 0.85, (n + n2) * 0.5);
	COLOR = vec4(fog_color.rgb, clamp(edge * mix(0.75, 1.0, cloud) * 1.1 * strength, 0.0, 1.0));
}