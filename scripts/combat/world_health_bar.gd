class_name WorldHealthBar
extends MeshInstance3D
## Billboard health bar quad drawn on top of everything (shader). set_ratio(0..1).

const BAR_SHADER := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, blend_mix;

uniform float ratio = 1.0;
uniform vec4 fill_color : source_color = vec4(0.9, 0.18, 0.12, 1.0);
uniform vec4 back_color : source_color = vec4(0.05, 0.05, 0.05, 0.85);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec4 c = back_color;
	bool inside = UV.x > 0.02 && UV.x < 0.98 && UV.y > 0.18 && UV.y < 0.82;
	if (inside && (UV.x - 0.02) / 0.96 <= ratio) {
		c = fill_color;
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
"""

var _mat: ShaderMaterial


func _init(width: float = 1.6, height: float = 0.22) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	mesh = quad
	var shader := Shader.new()
	shader.code = BAR_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_ratio(r: float) -> void:
	_mat.set_shader_parameter("ratio", clampf(r, 0.0, 1.0))


func set_fill_color(c: Color) -> void:
	_mat.set_shader_parameter("fill_color", c)
