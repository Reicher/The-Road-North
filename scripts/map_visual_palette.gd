class_name MapVisualPalette
extends RefCounted

const GRASS := Color(0.36, 0.51, 0.30)
const GRASS_DARK := Color(0.20, 0.36, 0.21)
const ROAD := Color(0.46, 0.32, 0.17)
const ROAD_EDGE := Color(0.25, 0.17, 0.10)
const WOOD_DARK := Color(0.34, 0.15, 0.055)
const WOOD := Color(0.68, 0.38, 0.12)
const STONE := Color(0.41, 0.45, 0.36)
const STONE_LIGHT := Color(0.70, 0.75, 0.62)
const WATER := Color(0.06, 0.40, 0.66)
const WATER_CURRENT := Color(0.58, 0.92, 0.94)
const FOLIAGE := Color(0.045, 0.31, 0.13)
const BERRY := Color(0.67, 0.10, 0.18)
const ENEMY := Color(0.78, 0.12, 0.10)
const PLAYER := Color(0.38, 0.72, 0.86)
const FIRE := Color(1.0, 0.36, 0.06)
const MAGIC := Color(0.63, 0.95, 0.45)

static var _ground_shader: Shader
static var _road_shader: Shader
static var _wood_shader: Shader
static var _water_shader: Shader
static var _foliage_wind_shader: Shader
static var _rock_shader: Shader


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


static func make_wood_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_wood_shader()
	material.set_shader_parameter("base_color", color)
	return material


static func make_water_material(color: Color, flow_direction := Vector2.RIGHT, river_half_width := 18.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_water_shader()
	material.set_shader_parameter("deep_color", color.darkened(0.12))
	material.set_shader_parameter("surface_color", color.lightened(0.12))
	material.set_shader_parameter("foam_color", WATER_CURRENT)
	material.set_shader_parameter("flow_direction", flow_direction.normalized())
	material.set_shader_parameter("river_half_width", river_half_width)
	return material


static func make_foliage_wind_material(color: Color, crown_height: float, wind_strength := 1.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_foliage_wind_shader()
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("crown_height", crown_height)
	material.set_shader_parameter("wind_strength", wind_strength)
	return material


static func make_rock_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _get_rock_shader()
	material.set_shader_parameter("base_color", color)
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
void fragment() {
	float broad = value_noise(map_position.xz * 0.018);
	float medium = value_noise(map_position.xz * 0.052 + vec2(17.3, -8.7));
	float fine = value_noise(map_position.xz * 0.14 + vec2(-4.1, 23.9));
	float variation = broad * 0.52 + medium * 0.32 + fine * 0.16;
	float mottling = smoothstep(0.24, 0.78, variation);
	float sparse_wear = smoothstep(0.78, 0.92, medium + fine * 0.18);
	vec3 shadow_grass = base_color.rgb * vec3(0.72, 0.82, 0.74);
	vec3 dry_grass = base_color.rgb * vec3(1.10, 1.03, 0.86);
	ALBEDO = mix(shadow_grass, dry_grass, mottling);
	ALBEDO *= mix(1.0, 0.84, sparse_wear * 0.34);
	ROUGHNESS = 1.0;
}
"""
	return _ground_shader


static func _get_road_shader() -> Shader:
	if _road_shader == null:
		_road_shader = Shader.new()
		_road_shader.code = """
shader_type spatial;
render_mode cull_disabled;
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


static func _get_wood_shader() -> Shader:
	if _wood_shader == null:
		_wood_shader = Shader.new()
		_wood_shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 base_color : source_color;
varying vec3 map_position;
void vertex() { map_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float grain(vec2 point) { return fract(sin(dot(point, vec2(27.17, 91.73))) * 43758.5453); }
void fragment() {
	float long_grain = sin(map_position.z * 0.42 + sin(map_position.x * 0.13) * 1.8) * 0.5 + 0.5;
	float scuffs = grain(floor(map_position.xz * vec2(0.12, 0.28)));
	float wear = long_grain * 0.16 + scuffs * 0.12;
	ALBEDO = base_color.rgb * mix(0.73, 1.06, wear + 0.34);
	ROUGHNESS = 0.98;
}
"""
	return _wood_shader


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
uniform float river_half_width = 18.0;
varying vec3 map_position;
varying float bank_distance;

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
	bank_distance = abs(VERTEX.z) / river_half_width;
}

void fragment() {
	vec2 flow = normalize(flow_direction);
	vec2 across = vec2(-flow.y, flow.x);
	float along = dot(map_position.xz, flow);
	float cross_position = dot(map_position.xz, across);
	vec2 ripple_position = vec2(along * 0.145 - TIME * 0.62, cross_position * 0.19);
	float breakup = value_noise(ripple_position * 0.58 + vec2(13.1, -7.4));
	float ripple_a = sin(along * 0.22 - TIME * 1.15 + cross_position * 0.055 + breakup * 2.4);
	float ripple_b = sin(along * 0.31 - TIME * 0.84 - cross_position * 0.09 + breakup * 1.7);
	float fine_ripples = ripple_a * 0.075 + ripple_b * 0.050;
	float ripple_lines = smoothstep(0.76, 0.96, ripple_a) * smoothstep(0.30, 0.72, breakup);
	ripple_lines += smoothstep(0.84, 0.98, ripple_b) * smoothstep(0.62, 0.88, 1.0 - breakup);
	ripple_lines = clamp(ripple_lines, 0.0, 1.0);
	float bank = smoothstep(0.68, 1.0, bank_distance);
	float irregular_bank = clamp(bank + (breakup - 0.5) * 0.16, 0.0, 1.0);
	vec3 water_color = mix(deep_color.rgb * 0.88, surface_color.rgb, 0.38 + fine_ripples);
	water_color = mix(water_color, surface_color.rgb * 1.16, irregular_bank * 0.62);
	water_color = mix(water_color, foam_color.rgb, ripple_lines * 0.28);
	float edge_ripple = smoothstep(0.70, 0.82, bank_distance) * (1.0 - smoothstep(0.94, 1.0, bank_distance));
	edge_ripple *= smoothstep(0.35, 0.86, breakup + ripple_a * 0.12);
	ALBEDO = mix(water_color, foam_color.rgb, edge_ripple * 0.42);
	ROUGHNESS = 0.66;
	SPECULAR = 0.26;
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
varying vec3 crown_position;

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
	crown_position = VERTEX;
}

void fragment() {
	float normalized_height = clamp((crown_position.y + crown_height * 0.5) / crown_height, 0.0, 1.0);
	float angle = atan(crown_position.z, crown_position.x);
	float branch_tiers = fract(normalized_height * 8.0 + sin(angle * 3.5) * 0.16);
	float twig_slashes = fract(normalized_height * 13.0 + angle * 1.55);
	float hard_branch = step(0.46, branch_tiers) * step(0.30, twig_slashes);
	float deep_needles = step(0.78, fract(normalized_height * 5.0 - angle * 2.15));
	float texture_value = hard_branch * 0.34 - deep_needles * 0.22;
	vec3 dark_needles = base_color.rgb * 0.72;
	vec3 bright_needles = base_color.rgb * 1.22;
	ALBEDO = mix(dark_needles, bright_needles, clamp(0.34 + texture_value, 0.0, 1.0));
	ALBEDO *= 1.0 + wind_light * 0.012;
	ROUGHNESS = 0.94;
}
"""
	return _foliage_wind_shader


static func _get_rock_shader() -> Shader:
	if _rock_shader == null:
		_rock_shader = Shader.new()
		_rock_shader.code = """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 base_color : source_color;
varying vec3 map_position;

float grain(vec3 point) {
	return fract(sin(dot(point, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	map_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float broad = grain(floor(map_position * 0.055));
	float detail = grain(floor(map_position * 0.145));
	float strata = sin(map_position.y * 0.16 + broad * 2.2) * 0.5 + 0.5;
	float variation = mix(0.82, 1.10, broad * 0.52 + detail * 0.30 + strata * 0.18);
	ALBEDO = base_color.rgb * variation;
	ROUGHNESS = 0.96;
}
"""
	return _rock_shader
