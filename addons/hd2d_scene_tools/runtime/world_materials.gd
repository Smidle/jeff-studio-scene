@tool
class_name HD2DWorldMaterials
extends RefCounted
## Parameter translation is explicit; the cooked UE expression graph is unavailable.
static func material_for(record: Dictionary, data: HD2DWorldMapData, slot: int = 0) -> Material:
 var spec: Dictionary={}
 var ids: Array=record.get("materials",[])
 if slot<ids.size(): spec=data.mesh_material_specs.get(ids[slot],{})
 var textures: Dictionary=spec.get("textures",{})
 var kind: String=record.get("effect","")
 var scalars: Dictionary=spec.get("scalars",{})
 var vectors: Dictionary=spec.get("vectors",{})
 var base: Texture2D
 for name in ["BaseColor","DiffuseTexture","Diffuse","Base Color","Albedo","Texture","纹理","贴图","SubColor","Text"]:
  if textures.has(name) and not str(textures[name]).is_empty():
   base=load(data.recipe_root().path_join(textures[name])) as Texture2D
   break
 if kind.is_empty():
  if base==null: return null
  if textures.has("OpacitiyMap") and not str(textures.OpacitiyMap).is_empty():
   var masked := ShaderMaterial.new();masked.shader=preload("../shaders/world_object.gdshader")
   masked.set_shader_parameter("base_texture",base);masked.set_shader_parameter("opacity_texture",load(data.recipe_root().path_join(textures.OpacitiyMap)))
   masked.set_shader_parameter("uv_scale",Vector2(scalars.get("TextureTileX",1.0),scalars.get("TextureTileY",1.0)))
   masked.set_shader_parameter("uv_offset",Vector2(scalars.get("TextureOffsetX",0.0),scalars.get("TextureOffsetY",0.0)))
   masked.set_shader_parameter("opacity",float(scalars.get("Opacity",1.0)))
   return masked
  var mat := StandardMaterial3D.new()
  mat.albedo_texture=base; mat.roughness=1.0
  var color: Array=vectors.get("Color",vectors.get("color",[1.0,1.0,1.0,1.0]))
  mat.albedo_color=Color(color[0],color[1],color[2],color[3] if color.size()>3 else 1.0)
  mat.uv1_scale=Vector3(scalars.get("TextureTileX",1.0),scalars.get("TextureTileY",1.0),1)
  mat.uv1_offset=Vector3(scalars.get("TextureOffsetX",0.0),scalars.get("TextureOffsetY",0.0),0)
  mat.cull_mode=BaseMaterial3D.CULL_DISABLED
  mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR;mat.alpha_scissor_threshold=0.333
  mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
  return mat
 var mat := ShaderMaterial.new(); mat.shader=preload("../shaders/world_effect.gdshader")
 mat.set_shader_parameter("effect_kind",2 if kind=="Water_Blueprint_C" else (3 if kind=="Waterfall" else 0))
 mat.set_shader_parameter("has_texture",base!=null)
 if base: mat.set_shader_parameter("base_texture",base)
 var params: Dictionary=record.get("effect_parameters",{})
 var color := Color(0.88,0.92,0.88,0.55 if kind=="BP_Yun_C" else 0.13)
 var rgb: Array=params.get("Color",vectors.get("Color",vectors.get("color",[])))
 if rgb.size()>=3: color=Color(clampf(rgb[0],0,1),clampf(rgb[1],0,1),clampf(rgb[2],0,1),color.a)
 color.a*=clampf(float(params.get("Opacity",scalars.get("MaxOpacity",scalars.get("Opacity",1.0)))),0.0,2.0)
 mat.set_shader_parameter("tint",color)
 mat.set_shader_parameter("speed",float(params.get("PanningSpeed",scalars.get("PanningSpeed",0.003))))
 return mat

static func apply(node: Node, record: Dictionary, data: HD2DWorldMapData) -> void:
 if node is MeshInstance3D and node.mesh:
  for surface in node.mesh.get_surface_count():
   var mat := material_for(record,data,surface)
   if mat: node.set_surface_override_material(surface,mat)
  if record.has("effect"): node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 for child in node.get_children(): apply(child,record,data)
