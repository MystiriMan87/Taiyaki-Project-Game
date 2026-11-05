shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	float ratio = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float blocks = mix(320.0, 6.0, progress);
	vec2 grid = vec2(blocks, blocks * ratio);
	vec2 uv = (floor(SCREEN_UV * grid) + 0.5) / grid;
	vec3 col = texture(screen_tex, uv).rgb;
	float cell = fract(sin(dot(floor(SCREEN_UV * grid), vec2(12.9898, 78.233))) * 43758.5453);
	float cover = smoothstep(0.5, 2.0, progress + (cell - 0.5) * 0.6);
	COLOR = vec4(mix(col, fade_color.rgb, cover), 1.0);
}