@tool
class_name HD2DWorldEnvironment
extends Node
## Preserved UE volumes select a deliberately bounded Godot grade adapter.
@export var regional_grading: bool = true
@export_range(0,1,0.01) var region_strength: float = 0.35
@export_range(0,3,0.01) var effect_speed: float = 1.0
var regions: Array[Dictionary]=[]
var clock := 0.0
var data_id := 0
var last_effect_speed := -1.0
var adapted_tint := Vector3.ONE
func _process(delta: float) -> void:
 var stage := get_parent() as HD2DStage
 if not stage or (Engine.is_editor_hint() and not stage.preview_active): return
 var world := stage.terrain() as HD2DWorldMap
 if not world: return
 clock+=delta
 if clock<0.25: return
 clock=0
 if data_id!=world.data.get_instance_id():
  regions.clear();data_id=world.data.get_instance_id()
  for record in world.world_data().source_regions:
   if record.type!="postprocess": continue
   var boxes: Array[AABB]=[]
   for hull in record.hulls:
    var p: Array=hull.position;var center := Vector3(p[0],p[1],p[2]);var bounds := AABB();var first := true
    for xyz in hull.points:
     var point := center+Vector3(xyz[0],xyz[1],xyz[2])
     if first: bounds=AABB(point,Vector3.ZERO);first=false
     else: bounds=bounds.expand(point)
    boxes.append(bounds)
   regions.append({"settings":record.settings,"bounds":boxes,"unbound":record.unbound,"priority":record.priority})
  regions.sort_custom(func(a,b): return a.priority<b.priority)
 var selected := {}
 if regional_grading and stage.character() and world.world_data().environment_enabled:
  var point := world.to_local(stage.character().global_position)
  for region in regions:
   var contains: bool=region.unbound
   for bounds in region.bounds: contains=contains or bounds.has_point(point)
   if contains: selected=region.settings
 if is_instance_valid(stage._grade):
  var mat: ShaderMaterial=stage._grade.material
  mat.set_shader_parameter("region_strength",region_strength if not selected.is_empty() else 0.0)
  mat.set_shader_parameter("region_saturation",channels(selected,"ColorSaturation"))
  mat.set_shader_parameter("region_contrast",channels(selected,"ColorContrast"))
  mat.set_shader_parameter("region_gamma",channels(selected,"ColorGamma"))
  mat.set_shader_parameter("region_gain",channels(selected,"ColorGain"))
  mat.set_shader_parameter("region_shadow_gamma",channels(selected,"ColorGammaShadows"))
  var cold := false
  if regional_grading and stage.character():
   var key := world.key_for(world.to_local(stage.character().global_position))
   cold=str(world.tile_specs.get(key,{}).get("material","")).contains("_TS_")
  adapted_tint=adapted_tint.lerp(Vector3(0.91,0.97,1.2) if cold else Vector3.ONE,0.3)
  mat.set_shader_parameter("region_tint",adapted_tint)
 # New streamed effects receive the same rate; this walks only the small effects root.
 if world.has_node("EnvironmentEffects"): apply_speed(world.get_node("EnvironmentEffects"))
func channels(settings: Dictionary, key: String) -> Vector3:
 var value: Array=settings.get(key,[1.0,1.0,1.0,1.0])
 return Vector3(value[0],value[1],value[2])
func apply_speed(node: Node) -> void:
 if node is MeshInstance3D and node.mesh:
  for slot in node.mesh.get_surface_count():
   var mat := node.get_surface_override_material(slot) as ShaderMaterial
   if mat and mat.shader==preload("../shaders/world_effect.gdshader"): mat.set_shader_parameter("animation_rate",effect_speed)
 for child in node.get_children(): apply_speed(child)
