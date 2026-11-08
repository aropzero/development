class_name RoadTile
extends MeshInstance3D
## One auto-tiling road cell. The shader draws asphalt, pavements and markings
## based on the 4-bit neighbour mask.

var cell: Vector2i
var mask: int = 0

static var _shader: Shader


func setup(c: Vector2i) -> void:
	cell = c
	if _shader == null:
		_shader = load("res://scripts/world/road.gdshader")
	var pm := PlaneMesh.new()
	pm.size = Vector2(Cfg.TILE, Cfg.TILE)
	mesh = pm
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	material_override = mat
	position = Cfg.cell_to_world(c, 0.018)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_mask(0)


func set_mask(m: int) -> void:
	mask = m
	if material_override is ShaderMaterial:
		(material_override as ShaderMaterial).set_shader_parameter("mask", m)