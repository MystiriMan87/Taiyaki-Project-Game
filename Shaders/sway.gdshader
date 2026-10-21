shader_type canvas_item;

uniform float strength : hint_range(0.0, 8.0) = 1.5;
uniform float speed = 1.2;
uniform float phase = 0.0;

void vertex() {
	float bend = (1.0 - UV.y);
	bend *= bend;
	float t = TIME * speed + phase;
	VERTEX.x += (sin(t) + 0.4 * sin(t * 2.3)) * strength * bend;
}