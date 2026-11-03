shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable;
uniform float clear_radius = 0.28;
uniform float softness = 0.25;
uniform float density : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fog_color : source_color = vec4(0.45, 0.5, 0.55, 1.0);

void fragment() {
	float ratio = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = (SCREEN_UV - vec2(0.5)) * vec2(ratio, 1.0);
	float ring = smoothstep(clear_radius, clear_radius + softness, length(p));
	float n = texture(noise_tex, SCREEN_UV * 1.5 + vec2(TIME * 0.02, TIME * 0.01)).r;
	COLOR = vec4(fog_color.rgb, clamp(ring * mix(0.9, 1.0, n) * density, 0.0, 1.0));
}