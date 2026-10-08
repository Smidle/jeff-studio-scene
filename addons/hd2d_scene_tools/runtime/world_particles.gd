@tool
class_name HD2DWorldParticles
extends RefCounted
static func make(record: Dictionary) -> MultiMeshInstance3D:
 var node := MultiMeshInstance3D.new();var mm := MultiMesh.new()
 mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true
 var quad := QuadMesh.new();quad.size=Vector2(0.10,0.10)
 var mat := ShaderMaterial.new();mat.shader=preload("../shaders/world_particles.gdshader")
 var source: String=record.source;var rise := -1.0;var color := Color(0.92,0.64,0.65,0.72)
 if source.contains("LuoYe"): color=Color(0.65,0.58,0.30,0.70)
 if source.contains("LuoXue"): color=Color(0.95,0.98,1,0.7)
 if source.contains("水花"): color=Color(0.83,0.94,0.94,0.6);rise=0.35
 if source.contains("HuoDui"): color=Color(1,0.5,0.1,0.8);rise=0.7
 if source.contains("MiFeng"): color=Color(0.3,0.25,0.07,0.8);rise=0
 mat.set_shader_parameter("tint",color);mat.set_shader_parameter("rise",rise);quad.material=mat
 mm.mesh=quad;mm.instance_count=18
 var rng := RandomNumberGenerator.new();rng.seed=int(record.seed)
 var center := HD2DWorldMapData.decode_transform(record.transform).origin
 for i in mm.instance_count:
  mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,center+Vector3(rng.randf_range(-2,2),rng.randf_range(0,2),rng.randf_range(-2,2))))
  mm.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),rng.randf(),rng.randf()))
 node.multimesh=mm;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 node.custom_aabb=AABB(center-Vector3(4,4,4),Vector3(8,8,8))
 return node
