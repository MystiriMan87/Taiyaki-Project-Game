shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float twist = 12.0;
uniform float zoom = 0.6;
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	float ratio = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = SCREEN_UV - vec2(0.5);
	p.x *= ratio;
	
	float dist = length(p);
	float falloff = clamp(1.0 - dist / 0.8, 0.0, 1.0);
	float angle = progress * twist * falloff * falloff;
	
	float s = sin(angle);
	float c = cos(angle);
	p = mat2(vec2(c, s), vec2(-s, c)) * p;
	p *= 1.0 + progress * zoom;
	
	p.x /= ratio;
	vec2 uv = p + vec2(0.5);
	
	vec4 col = texture(screen_tex, uv);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		col = fade_color;
	}
	float f = smoothstep(0.4, 1.0, progress);
	COLOR = vec4(mix(col.rgb, fade_color.rgb, f), 1.0);
}