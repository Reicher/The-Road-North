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
