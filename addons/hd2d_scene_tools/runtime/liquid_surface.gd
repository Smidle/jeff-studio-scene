@tool
class_name HD2DLiquidSurface
extends Node3D
## Independent visual surface. No physics, swimming or fluid simulation.
@export_enum("Water", "Lava") var kind: int = 0:
	set(value): kind=value; refresh()
@export var extent := Vector2(64,64):
	set(value): extent=value.max(Vector2(0.1,0.1)); refresh()
@export_range(0,3,0.01) var animation_speed: float = 0.35:
	set(value): animation_speed=value; refresh()
@export var water_color := Color("267d93"):
	set(value): water_color=value; refresh()
@export var lava_color := Color("e75d18"):
	set(value): lava_color=value; refresh()
@export_range(0,3,0.05) var emission_energy: float = 0.7:
	set(value): emission_energy=value; refresh()
var surface: MeshInstance3D
var material: ShaderMaterial

func _ready() -> void:
	refresh()

func refresh() -> void:
	if not is_inside_tree(): return
	if not is_instance_valid(surface):
		surface=MeshInstance3D.new(); surface.name="_Surface"; add_child(surface)
		surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		material=ShaderMaterial.new(); material.shader=preload("../shaders/liquid.gdshader")
		surface.material_override=material
	var plane := PlaneMesh.new(); plane.size=extent; surface.mesh=plane
	material.set_shader_parameter("lava",kind==1)
	material.set_shader_parameter("surface_color",lava_color if kind==1 else water_color)
	material.set_shader_parameter("animation_speed",animation_speed)
	material.set_shader_parameter("emission_energy",emission_energy)
	material.set_shader_parameter("extent",extent)
