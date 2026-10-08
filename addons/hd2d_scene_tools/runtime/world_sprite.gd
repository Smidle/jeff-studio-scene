@tool
class_name HD2DWorldSprite
extends MeshInstance3D
var data: HD2DWorldMapData
var record: Dictionary
var mesh_cache: Dictionary
var clock := 0.0
var current_frame := ""

func _ready() -> void:
 clock=float(record.get("phase",0.0));cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 _process(0)

func _process(delta: float) -> void:
 if data==null: return
 clock+=delta
 var id: String=record.sprite
 var spec: Dictionary=data.sprite_specs[id]
 if spec.has("frames"):
  var duration := 0.0
  for frame in spec.frames: duration+=float(frame.duration)
  var position := fmod(clock,maxf(duration,0.001))
  for frame in spec.frames:
   id=frame.sprite;position-=float(frame.duration)
   if position<0: break
 if id==current_frame: return
 current_frame=id
 if not mesh_cache.has(id):
  var frame: Dictionary=data.sprite_specs[id]
  var vertices := PackedVector3Array();var uv := PackedVector2Array();var normals := PackedVector3Array()
  for v in frame.vertices:
   vertices.append(Vector3(v[0]*0.01,v[1]*0.01,0));uv.append(Vector2(v[2],v[3]));normals.append(Vector3.FORWARD)
  var arrays := [];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_NORMAL]=normals
  var generated := ArrayMesh.new();generated.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var material := StandardMaterial3D.new();material.albedo_texture=load(data.recipe_root().path_join(frame.texture))
  material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;material.alpha_scissor_threshold=0.33
  material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
  material.roughness=1.0;generated.surface_set_material(0,material);mesh_cache[id]=generated
 mesh=mesh_cache[id]
