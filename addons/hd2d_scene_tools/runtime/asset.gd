@tool
class_name HD2DAsset
extends Resource
## Library identity is independent of the model/skin family. Legacy assets stay empty.
@export var library_entry_id: StringName
var _mesh_offset_override := false
var _static_collision_override := false
const OVERRIDE_FIELDS := ["card_size","anchor","facing","alpha_cut","nearest","wind","static_collision","collision_mode","collision_size","collision_offset","animate_sheet","sheet_columns","sheet_rows","sheet_start","sheet_count","sheet_fps","texture_region","color_key_enabled","color_key","color_key_tolerance"]

# Resource return/argument types avoid a self-referential GDScript retention cycle.
func with_overrides(values: Dictionary) -> Resource:
	if values.is_empty(): return self
	var copy = duplicate()
	copy._mesh_offset_override=values.has("collision_offset")
	copy._static_collision_override=values.has("static_collision")
	for key in OVERRIDE_FIELDS:
		if values.has(key) and typeof(values[key])==typeof(get(key)): copy.set(key,values[key])
	return copy

func same_entry(other: Resource) -> bool:
	if other==null: return false
	if library_entry_id!=&"" and other.library_entry_id!=&"": return library_entry_id==other.library_entry_id
	return self==other

static func new_entry_id() -> StringName:
	return StringName("user-"+Crypto.new().generate_random_bytes(16).hex_encode())

@export var title: String = "新素材"
@export var category: String = "植物"
@export var source: Resource
@export var source_path: String
@export var material: Material
@export var thumbnail: Texture2D
@export var building_profile: HD2DBuildingProfile
## Empty metadata retains the original generic-asset behavior.
@export var asset_id: StringName
@export var family_id: StringName
@export var skins: Array[HD2DAssetSkin] = []
## Source-root-relative mesh paths -> ordered, stable material slot identifiers.
@export var material_slots: Dictionary = {}
@export var card_size: Vector2 = Vector2(2,2)
@export var anchor: Vector2 = Vector2(0.5,1.0)
@export_enum("固定平面", "绕 Y 轴朝向镜头") var facing: int = 0
@export_range(0,1,0.01) var alpha_cut: float = 0.5
@export var nearest: bool = true
## Keep omitted legacy resource fields unchanged; new imports/placements opt in below.
@export var static_collision: bool = false
## New 3D entries use geometry; image cards use a box with depth.
@export_enum("原网格（贴片无厚度）", "盒体", "胶囊") var collision_mode: int = 0
@export var collision_size: Vector3 = Vector3(1,2,0.5)
@export var collision_offset: Vector3 = Vector3(0,1,0)
@export var animate_sheet: bool = false
@export var sheet_columns: int = 1
@export var sheet_rows: int = 1
@export var sheet_start: int = 0
@export var sheet_count: int = 1
@export var sheet_fps: float = 8.0
@export_range(0,1,0.01) var wind: float = 0.08
## Pixels in the source image; zero size means the full image. Source files stay unchanged.
@export var texture_region: Rect2i = Rect2i()
## Explicit opt-in for RGB art with a known solid background; never guessed on import.
@export var color_key_enabled: bool = false
@export var color_key: Color = Color("212121")
@export_range(0,0.25,0.001) var color_key_tolerance: float = 0.005

func placement_collision_overrides() -> Dictionary:
	# Applied only when authoring a NEW object/record, never on scene load.
	if static_collision: return {}
	if source is Texture2D:
		return {"static_collision":true,"collision_mode":1,
			"collision_size":Vector3(maxf(card_size.x,0.05),maxf(card_size.y,0.05),0.5),
			"collision_offset":Vector3((0.5-anchor.x)*card_size.x,(anchor.y-0.5)*card_size.y,0)}
	return {"static_collision":true,"collision_mode":0}

func enable_default_collision() -> void:
	var settings := placement_collision_overrides()
	for key in settings: set(key,settings[key])

func region_rect() -> Rect2i:
	if not source is Texture2D: return Rect2i()
	var bounds := Rect2i(Vector2i.ZERO, Vector2i((source as Texture2D).get_size()))
	if texture_region.size == Vector2i.ZERO: return bounds
	return texture_region.intersection(bounds)

func preview_texture(frame: int = 0) -> Texture2D:
	if not source is Texture2D: return thumbnail
	if texture_region.size == Vector2i.ZERO and not animate_sheet: return source as Texture2D
	var rect := region_rect()
	if not rect.has_area(): return null
	if animate_sheet:
		var cols := maxi(1,sheet_columns)
		var rows := maxi(1,sheet_rows)
		var cell := Vector2i(rect.size.x/cols,rect.size.y/rows)
		var index := clampi(sheet_start+posmod(frame,maxi(1,sheet_count)),0,cols*rows-1)
		rect=Rect2i(rect.position+Vector2i(index%cols,index/cols)*cell,cell)
	var atlas := AtlasTexture.new()
	atlas.atlas = source as Texture2D
	atlas.region = Rect2(rect)
	atlas.filter_clip=true
	return atlas

func source_missing() -> bool:
	return source==null or (not source_path.is_empty() and not FileAccess.file_exists(source_path.get_slice("::",0)))

func collision_parts() -> Array[Dictionary]:
	if not static_collision: return []
	if collision_mode==0:
		var result: Array[Dictionary]=[]
		if source is PackedScene:
			var instance := (source as PackedScene).instantiate()
			_collect_authored_collision(instance,Transform3D.IDENTITY,result)
			instance.free()
		if not result.is_empty():
			if _mesh_offset_override:
				for part in result: part.transform.origin+=collision_offset
			return result
		for part in mesh_parts():
			var xform: Transform3D=part.transform
			if _mesh_offset_override: xform.origin+=collision_offset
			result.append({"shape":part.mesh.create_trimesh_shape(),"transform":xform})
		return result
	var shape: Shape3D
	if collision_mode==2:
		var capsule := CapsuleShape3D.new()
		capsule.radius=maxf(0.025,collision_size.x*0.5)
		capsule.height=maxf(collision_size.y,capsule.radius*2)
		shape=capsule
	else:
		var box := BoxShape3D.new()
		box.size=collision_size.max(Vector3.ONE*0.05)
		shape=box
	var source_transform := Transform3D.IDENTITY
	if source is PackedScene:
		var root := (source as PackedScene).instantiate()
		if root is Node3D: source_transform=root.transform
		root.free()
	return [{"shape":shape,"transform":source_transform*Transform3D(Basis.IDENTITY,collision_offset)}]

func _add_volume(node: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name="HD2DCollision"
	for part in collision_parts():
		var collision := CollisionShape3D.new()
		collision.shape=part.shape
		# Parts are asset-local for MultiMesh; this body's parent already carries
		# the imported scene root transform. Do not apply that transform twice.
		collision.transform=node.transform.affine_inverse()*part.transform if source is PackedScene else part.transform
		body.add_child(collision)
	node.add_child(body)

static func logical_image(texture: Texture2D) -> Image:
	if not texture is AtlasTexture: return texture.get_image()
	var atlas := texture as AtlasTexture
	if atlas.atlas==null: return Image.create(1,1,false,Image.FORMAT_RGBA8)
	var source_image := logical_image(atlas.atlas)
	if source_image.is_compressed(): source_image.decompress()
	source_image.convert(Image.FORMAT_RGBA8)
	var rect := Rect2i(atlas.region)
	if rect.size.x==0: rect.size.x=atlas.atlas.get_width()
	if rect.size.y==0: rect.size.y=atlas.atlas.get_height()
	var result := Image.create(maxi(1,atlas.get_width()),maxi(1,atlas.get_height()),false,Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	result.blit_rect(source_image,rect,Vector2i(atlas.margin.position.round()))
	return result

func skin_for(id: StringName) -> HD2DAssetSkin:
	for skin in skins:
		if skin and skin.skin_id==id and skin.family_id==family_id: return skin
	return null

func supports_skin(id: StringName) -> bool:
	if id==&"": return true
	var skin := skin_for(id)
	if skin==null: return false
	var slots: Array[String] = []
	for values in material_slots.values():
		for slot in values:
			if not slots.has(str(slot)): slots.append(str(slot))
	return skin.complete_for(slots)

func apply_skin(root: Node3D, id: StringName) -> bool:
	if not supports_skin(id): return false
	var skin := skin_for(id)
	# Validate the whole binding before touching any mesh.
	for path in material_slots:
		var node := root.get_node_or_null(NodePath(path)) as MeshInstance3D
		if node==null or node.mesh==null or node.mesh.get_surface_count()!=material_slots[path].size(): return false
	for path in material_slots:
		var node := root.get_node(NodePath(path)) as MeshInstance3D
		if not node.has_meta("hd2d_source_materials"):
			var originals: Array[Material] = []
			for surface in node.mesh.get_surface_count(): originals.append(node.get_surface_override_material(surface))
			node.set_meta("hd2d_source_materials",originals)
			node.set_meta("hd2d_source_override",node.material_override)
		node.material_override=null if skin else node.get_meta("hd2d_source_override",null)
		for surface in node.mesh.get_surface_count():
			var material_value: Material=skin.material_for(str(material_slots[path][surface])) if skin else node.get_meta("hd2d_source_materials")[surface]
			node.set_surface_override_material(surface,material_value)
	return true

func make_node(skin_id: StringName = &"") -> Node3D:
	if source is PackedScene:
		var instance := (source as PackedScene).instantiate()
		if instance is Node3D:
			if not material_slots.is_empty(): apply_skin(instance,skin_id)
			if static_collision:
				if collision_mode==0 and not _mesh_offset_override:
					if not _has_static_collision(instance): _add_scene_collisions(instance)
				else:
					_disable_static_collision(instance)
					_add_volume(instance)
			elif _static_collision_override: _disable_static_collision(instance)
			return instance
		instance.free()
		return Node3D.new()
	var node := MeshInstance3D.new()
	if source is Texture2D:
		var region := region_rect()
		if not region.has_area(): return node
		var quad := QuadMesh.new()
		quad.size=card_size
		quad.center_offset=Vector3((0.5-anchor.x)*card_size.x,(anchor.y-0.5)*card_size.y,0)
		node.mesh=quad
		var mat := ShaderMaterial.new()
		mat.shader=preload("../shaders/card.gdshader")
		# Shader samplers cannot apply AtlasTexture's region/margins themselves.
		# Flatten an existing AtlasTexture's logical image (including padding) once per material.
		var texture := source as Texture2D
		if texture is AtlasTexture: texture = ImageTexture.create_from_image(logical_image(texture))
		mat.set_shader_parameter("art_nearest",texture)
		mat.set_shader_parameter("art_linear",texture)
		var texture_size := texture.get_size()
		mat.set_shader_parameter("uv_region",Vector4(region.position.x/texture_size.x,region.position.y/texture_size.y,region.size.x/texture_size.x,region.size.y/texture_size.y))
		mat.set_shader_parameter("source_pixel",Vector2.ONE/texture_size)
		mat.set_shader_parameter("color_key_enabled",color_key_enabled)
		mat.set_shader_parameter("key_color",color_key)
		mat.set_shader_parameter("key_tolerance",color_key_tolerance)
		mat.set_shader_parameter("nearest",nearest)
		mat.set_shader_parameter("billboard_y",facing==1)
		mat.set_shader_parameter("cutoff",alpha_cut)
		mat.set_shader_parameter("wind_amount",wind)
		mat.set_shader_parameter("sheet_grid",Vector2(maxi(1,sheet_columns),maxi(1,sheet_rows)) if animate_sheet else Vector2.ONE)
		mat.set_shader_parameter("sheet_start",sheet_start if animate_sheet else 0)
		mat.set_shader_parameter("sheet_count",maxi(1,sheet_count) if animate_sheet else 1)
		mat.set_shader_parameter("sheet_fps",sheet_fps)
		node.material_override=mat
	elif source is Mesh:
		node.mesh=source
		node.material_override=material.duplicate() if material else null
		if not material_slots.is_empty(): apply_skin(node,skin_id)
	if static_collision and node.mesh:
		if collision_mode==0 and not _mesh_offset_override: node.create_trimesh_collision()
		else: _add_volume(node)
	return node

func _collect_authored_collision(node: Node, parent_transform: Transform3D, parts: Array[Dictionary], inside_body: bool = false) -> void:
	var xform: Transform3D = parent_transform*node.transform if node is Node3D else parent_transform
	inside_body=inside_body or node is StaticBody3D
	if inside_body and node is CollisionShape3D and node.shape and not node.disabled:
		parts.append({"shape":node.shape,"transform":xform})
	for child in node.get_children(): _collect_authored_collision(child,xform,parts,inside_body)

func _has_static_collision(node: Node, inside_body: bool = false) -> bool:
	inside_body=inside_body or node is StaticBody3D
	if inside_body and node is CollisionShape3D and node.shape and not node.disabled: return true
	if inside_body and node is CollisionPolygon3D and node.polygon.size()>=3 and not node.disabled: return true
	for child in node.get_children():
		if _has_static_collision(child,inside_body): return true
	return false

func _disable_static_collision(node: Node, inside_body: bool = false) -> void:
	inside_body=inside_body or node is StaticBody3D
	if inside_body and (node is CollisionShape3D or node is CollisionPolygon3D): node.disabled=true
	for child in node.get_children(): _disable_static_collision(child,inside_body)

func _add_scene_collisions(node: Node, inside_body: bool = false) -> void:
	inside_body=inside_body or node is CollisionObject3D
	if node is MeshInstance3D and node.mesh and not inside_body:
		var existing := false
		for child in node.get_children():
			if child is CollisionObject3D and _has_static_collision(child): existing=true
		if not existing: node.create_trimesh_collision()
	for child in node.get_children(): _add_scene_collisions(child,inside_body)

func mesh_parts(skin_id: StringName = &"") -> Array[Dictionary]:
	var settings = duplicate()
	settings.static_collision=false
	var node: Node3D=settings.make_node(skin_id)
	var output: Array[Dictionary] = []
	_collect(node,Transform3D.IDENTITY,output)
	node.free()
	return output

func _collect(node: Node, parent_transform: Transform3D, output: Array[Dictionary]) -> void:
	var xform := parent_transform
	if node is Node3D: xform=parent_transform*node.transform
	if node is MeshInstance3D and node.mesh:
		var rendered_mesh: Mesh=node.mesh
		# MultiMesh has no per-surface override array. Preserve effective overrides
		# on a private mesh resource, never mutate an imported/shared source mesh.
		var has_surface_override := false
		for surface in node.mesh.get_surface_count():
			if node.get_surface_override_material(surface): has_surface_override=true
		if has_surface_override and node.material_override==null:
			rendered_mesh=node.mesh.duplicate()
			for surface in rendered_mesh.get_surface_count(): rendered_mesh.surface_set_material(surface,node.get_active_material(surface))
		output.append({"mesh":rendered_mesh,"material":node.material_override.duplicate() if node.material_override else null,"transform":xform})
	for child in node.get_children(): _collect(child,xform,output)
