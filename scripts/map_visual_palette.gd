class_name MapVisualPalette
extends RefCounted

const GRASS := Color(0.46, 0.56, 0.36)
const GRASS_DARK := Color(0.31, 0.42, 0.28)
const ROAD := Color(0.32, 0.235, 0.17)
const ROAD_EDGE := Color(0.27, 0.21, 0.16)
const WOOD_DARK := Color(0.25, 0.13, 0.06)
const WOOD := Color(0.48, 0.28, 0.12)
const STONE := Color(0.34, 0.36, 0.34)
const STONE_LIGHT := Color(0.58, 0.61, 0.57)
const WATER := Color(0.12, 0.34, 0.49)
const WATER_CURRENT := Color(0.62, 0.84, 0.86)
const FOLIAGE := Color(0.11, 0.31, 0.16)
const BERRY := Color(0.67, 0.10, 0.18)
const ENEMY := Color(0.78, 0.12, 0.10)
const PLAYER := Color(0.38, 0.72, 0.86)
const FIRE := Color(1.0, 0.36, 0.06)
const MAGIC := Color(0.63, 0.95, 0.45)

static var _ground_shader: Shader
static var _road_shader: Shader
static var _water_shader: Shader
static var _foliage_wind_shader: Shader


static func make_material(color: Color, unshaded := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


static func make_ground_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_ground_shader()
	material.set_shader_parameter("base_color", color)
	return material


static func make_road_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_road_shader()
	material.set_shader_parameter("base_color", color)
	return material


static func make_water_material(color: Color, flow_direction := Vector2.RIGHT) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_water_shader()
	material.set_shader_parameter("deep_color", color.darkened(0.12))
	material.set_shader_parameter("surface_color", color.lightened(0.12))
	material.set_shader_parameter("foam_color", WATER_CURRENT)
	material.set_shader_parameter("flow_direction", flow_direction.normalized())
	return material


static func make_foliage_wind_material(color: Color, crown_height: float, wind_strength := 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_foliage_wind_shader()
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("crown_height", crown_height)
	material.set_shader_parameter("wind_strength", wind_strength)
	return material


static func _get_ground_shader() -> Shader:
	if _ground_shader == null:
		_ground_shader = Shader.new()
		_ground_shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color;
varying vec3 map_position;
void vertex() { map_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float grain(vec2 point) { return fract(sin(dot(point, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float broad = grain(floor(map_position.xz * 0.055));
	float fine = grain(floor(map_position.xz * 0.16));
	float variation = mix(0.91, 1.06, broad * 0.65 + fine * 0.35);
	ALBEDO = base_color.rgb * variation;
	ROUGHNESS = 1.0;
}
"""
	return _ground_shader


static func _get_road_shader() -> Shader:
	if _road_shader == null:
		_road_shader = Shader.new()
		_road_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 base_color : source_color;
varying vec3 map_position;
void vertex() { map_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float grain(vec2 point) { return fract(sin(dot(point, vec2(41.17, 19.73))) * 15731.743); }
void fragment() {
	float texture_value = grain(floor(map_position.xz * 0.22));
	ALBEDO = base_color.rgb * mix(0.86, 1.08, texture_value);
	ALPHA = base_color.a;
	ROUGHNESS = 1.0;
}
"""
	return _road_shader


static func _get_water_shader() -> Shader:
	if _water_shader == null:
		_water_shader = Shader.new()
		_water_shader.code = """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 deep_color : source_color;
uniform vec4 surface_color : source_color;
uniform vec4 foam_color : source_color;
uniform vec2 flow_direction = vec2(1.0, 0.0);
varying vec3 map_position;

float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), local.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), local.x),
		local.y
	);
}

void vertex() {
	map_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 flow = normalize(flow_direction);
	vec2 across = vec2(-flow.y, flow.x);
	float along = dot(map_position.xz, flow);
	float cross_position = dot(map_position.xz, across);
	vec2 flowing_position = vec2(along * 0.030 - TIME * 0.34, cross_position * 0.052);
	float slow_warp = value_noise(flowing_position * 0.72 + vec2(TIME * 0.025, -TIME * 0.018));
	float side_warp = value_noise(flowing_position * 1.63 + vec2(17.2, -8.4) - vec2(TIME * 0.06, 0.0));
	float broken_ripples = sin(along * 0.102 - TIME * 0.91 + slow_warp * 5.2 + side_warp * 2.1) * 0.5 + 0.5;
	float crossing_wave = value_noise(vec2(along * 0.041 - TIME * 0.21, cross_position * 0.083 + TIME * 0.035) + slow_warp);
	float surface_mix = slow_warp * 0.38 + crossing_wave * 0.34 + broken_ripples * 0.28;
	float foam_breakup = value_noise(flowing_position * 2.25 + vec2(31.7, 9.1));
	float current_line = smoothstep(0.82, 0.97, broken_ripples) * smoothstep(0.48, 0.76, foam_breakup);
	vec3 water_color = mix(deep_color.rgb, surface_color.rgb, surface_mix);
	ALBEDO = mix(water_color, foam_color.rgb, current_line * 0.46);
	ROUGHNESS = 0.58;
	SPECULAR = 0.32;
}
"""
	return _water_shader


static func _get_foliage_wind_shader() -> Shader:
	if _foliage_wind_shader == null:
		_foliage_wind_shader = Shader.new()
		_foliage_wind_shader.code = """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color;
uniform float crown_height = 32.0;
uniform float wind_strength = 1.0;
varying float wind_light;

void vertex() {
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float height_factor = clamp((VERTEX.y + crown_height * 0.5) / crown_height, 0.0, 1.0);
	height_factor *= height_factor;
	float position_phase = world_position.x * 0.021 + world_position.z * 0.017;
	float breeze = sin(TIME * 1.05 + position_phase);
	float cross_breeze = sin(TIME * 0.73 + position_phase * 1.37 + 1.8);
	float gust = 0.62 + (sin(TIME * 0.23 + position_phase * 0.42) * 0.5 + 0.5) * 0.38;
	vec3 wind_direction = vec3(breeze, 0.0, cross_breeze * 0.42);
	vec3 world_offset = wind_direction * gust * crown_height * 0.095 * wind_strength * height_factor;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(world_offset, 0.0)).xyz;
	wind_light = breeze * height_factor;
}

void fragment() {
	ALBEDO = base_color.rgb * (1.0 + wind_light * 0.018);
	ROUGHNESS = 0.94;
}
"""
	return _foliage_wind_shader
