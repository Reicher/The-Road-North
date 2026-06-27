shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.88, 1.0, 0.94, 1.0);
uniform float grain_strength : hint_range(0.0, 0.12) = 0.035;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 source = COLOR;
	float grain = hash(floor(FRAGCOORD.xy * 0.45)) - 0.5;
	float soft_band = sin(UV.x * 20.0 + UV.y * 7.0) * 0.012;
	COLOR = vec4(source.rgb * tint.rgb + (grain * grain_strength + soft_band), source.a * tint.a);
}
