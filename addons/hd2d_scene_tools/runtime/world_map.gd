@tool
class_name HD2DWorldMap
extends HD2DTerrain
## Authoring data survives streaming. Generated nodes are never serialized.
signal preparation_changed(remaining: int)
@export var focus_point: Vector3 = Vector3.ZERO
@export var view_radius: float = 72.0
@export var prefetch_tiles: int = 1
var tile_specs := {}
var detail_levels := {}
var content_nodes := {}
var placement_buckets := {}
var collider_buckets := {}
var far_nodes := {}
var far_parts := {}
var material_cache := {}
var asset_cache := {}
var variant_asset_cache := {}
var pending: Array[Vector2i] = []
var elapsed := 0.0
var edit_focus := false
var generated_objects := 0

func world_data() -> HD2DWorldMapData: return data as HD2DWorldMapData

func _ready() -> void:
	if world_data()==null: return
	data.ensure_valid(); rebuild()

func rebuild() -> void:
	_queued=false
	if not is_inside_tree() or world_data()==null: return
	for child in get_children(): remove_child(child); child.queue_free()
	chunks.clear(); detail_levels.clear(); content_nodes.clear(); tile_specs.clear(); far_nodes.clear()
	material_cache.clear(); placement_buckets.clear(); collider_buckets.clear(); pending.clear(); generated_objects=0
	var d := world_data()
	if not d.terrain_enabled: return
	for spec in d.tiles: tile_specs[Vector2i(int(spec.x),int(spec.z))]=spec
	_bucket_placements()
	# Cheap authored convex blockers can span many tiles; retaining them avoids
	# dropping a large hull when the tile containing its center is unloaded.
	if d.collisions_enabled:
		var body := StaticBody3D.new();body.name="OriginalBlockers";add_child(body)
		for source in d.source_colliders:
			for hull in source.hulls:
				var p: Array=hull.position;var shape := ConvexPolygonShape3D.new();var points := PackedVector3Array()
				for point in hull.points: points.append(Vector3(point[0],point[1],point[2]))
				shape.points=points
				var collision := CollisionShape3D.new();collision.shape=shape;collision.position=Vector3(p[0],p[1],p[2]);body.add_child(collision)
	if d.environment_enabled:
		var effects := Node3D.new(); effects.name="EnvironmentEffects"; effects.set_meta("hd2d_world_scenery",true); add_child(effects)
		for record in d.placements:
			if record.has("effect") and record.get("visible",true): _make_prop(record,effects,false)
		for record in d.source_particles: effects.add_child(HD2DWorldParticles.make(record))
		for record in d.source_lights:
			var light: Light3D
			if record.type=="PointLight": light=OmniLight3D.new();light.omni_range=float(record.parameters.get("AttenuationRadius",1000))*0.01
			elif record.type=="SpotLight":
				light=SpotLight3D.new();light.spot_range=float(record.parameters.get("AttenuationRadius",1000))*0.01
				light.spot_angle=float(record.parameters.get("OuterConeAngle",45))
			else: continue
			light.light_energy=clampf(float(record.parameters.get("Intensity",1))*0.01,0.05,2)
			var color: Array=record.parameters.get("LightColor",[255,255,255,255])
			if color.size()>=3: light.light_color=Color(color[0]/255.0,color[1]/255.0,color[2]/255.0)
			light.transform=HD2DWorldMapData.decode_transform(record.transform);effects.add_child(light)
	if d.layout_enabled and not d.source_sprites.is_empty():
		var sprites := Node3D.new();sprites.name="OriginalSprites";sprites.set_meta("hd2d_world_scenery",true);add_child(sprites)
		var cache := {}
		for record in d.source_sprites:
			var sprite := HD2DWorldSprite.new();sprite.data=d;sprite.record=record;sprite.mesh_cache=cache
			sprite.transform=HD2DWorldMapData.decode_transform(record.transform);sprites.add_child(sprite)
	for key in tile_specs: _render_tile(key,false,false)
	if d.layout_enabled:
		for key in placement_buckets: _render_far_content(key)
	update_streaming(true)
	rebuild_count+=1

func _bucket_placements() -> void:
	placement_buckets.clear()
	for record in world_data().placements:
		if record.has("effect"): continue
		var xform: Transform3D=world_data().object_overrides.get(record.id,{}).get("transform",HD2DWorldMapData.decode_transform(record.transform))
		var key := key_for(xform.origin)
		if not placement_buckets.has(key): placement_buckets[key]=[]
		placement_buckets[key].append(record)

func key_for(point: Vector3) -> Vector2i:
	return Vector2i(((Vector2(point.x,point.z)+Vector2.ONE*data.size_m*0.5)/(data.cell_size()*world_data().tile_cells)).floor())

func _process(delta: float) -> void:
	if world_data()==null or not world_data().terrain_enabled: return
	elapsed+=delta
	if elapsed>=0.2:
		elapsed=0
		var stage := get_parent() as HD2DStage
		if stage and (not Engine.is_editor_hint() or stage.preview_active) and stage.character():
			focus_point=to_local(stage.character().global_position)
			if stage.camera_rig(): view_radius=clampf(stage.camera_rig().frame_size*1.4,45.0,125.0)
		update_streaming()
	if not pending.is_empty():
		var key: Vector2i=pending.pop_front()
		_render_tile(key,true,true); _load_content(key)
		preparation_changed.emit(pending.size())

func update_streaming(immediate: bool = false) -> void:
	var span := world_data().tile_cells*data.cell_size()
	var keep := view_radius+span*(prefetch_tiles+1)
	var desired: Array[Vector2i]=[]
	var keys := tile_specs.duplicate()
	for key in placement_buckets: keys[key]=true
	for key in keys:
		var center := (Vector2(key)+Vector2.ONE*0.5)*span-Vector2.ONE*data.size_m*0.5
		var distance := center.distance_to(Vector2(focus_point.x,focus_point.z))
		if distance<view_radius+span*prefetch_tiles:
			if not detail_levels.get(key,false): desired.append(key)
		elif distance>keep and detail_levels.get(key,false):
			_render_tile(key,false,false); _unload_content(key)
	desired.sort_custom(func(a,b): return a.distance_squared_to(key_for(focus_point))<b.distance_squared_to(key_for(focus_point)))
	pending.assign(desired)
	if immediate:
		var center := key_for(focus_point)
		for key in desired.duplicate():
			if maxi(absi(key.x-center.x),absi(key.y-center.y))<=1:
				pending.erase(key); _render_tile(key,true,true); _load_content(key)
	preparation_changed.emit(pending.size())

func prepare_at(point: Vector3) -> void:
	focus_point=to_local(point); update_streaming(true)

func update_material() -> void:
	if world_data()==null: return
	var d := world_data()
	if not d.active_surface.is_empty():
		d.surface_overrides[d.active_surface]=d.textures.duplicate()
		d.surface_period_overrides[d.active_surface]=d.texture_scale
		d.surface_name_overrides[d.active_surface]=d.layer_names.duplicate()
	material_cache.clear()
	for key in chunks: chunks[key].material_override=_tile_material(key)

func _tile_material(key: Vector2i) -> ShaderMaterial:
	var d := world_data()
	var id: String=tile_specs[key].material
	if material_cache.has(id): return material_cache[id]
	var mat := ShaderMaterial.new(); mat.shader=preload("../shaders/world_map.gdshader")
	var spec: Dictionary=d.surface_specs[id]
	for i in range(9):
		var texture: Texture2D
		if d.surface_overrides.has(id) and i<d.surface_overrides[id].size(): texture=d.surface_overrides[id][i]
		elif i<spec.textures.size() and not str(spec.textures[i]).is_empty(): texture=load(d.recipe_root().path_join(spec.textures[i])) as Texture2D
		if texture: mat.set_shader_parameter("layer_%d"%i,texture)
	mat.set_shader_parameter("tile_scale",float(d.surface_period_overrides.get(id,spec.get("tile_m",2.0))))
	mat.set_shader_parameter("surface_enabled",d.surface_enabled)
	if get_parent() is HD2DStage: mat.set_shader_parameter("cloud_strength",get_parent().cloud_shadows)
	material_cache[id]=mat
	if material==null: material=mat
	return mat

func _render_tile(key: Vector2i, detailed: bool, collision: bool) -> void:
	if not tile_specs.has(key): detail_levels[key]=detailed;return
	var d := world_data(); var q := d.tile_cells
	var stride_step := 1 if detailed else (9 if q%9==0 else (5 if q%5==0 else 1))
	var count := q/stride_step; var side := count+1; var start := key*q
	var vertices := PackedVector3Array(); var normals := PackedVector3Array()
	var uv := PackedVector2Array(); var uv2 := PackedVector2Array(); var colors := PackedColorArray()
	var extra := PackedFloat32Array(); var indices := PackedInt32Array()
	var cell := d.cell_size()
	var add_vertex := func(gx: int, gz: int) -> int:
		var index := gz*d.resolution+gx
		vertices.append(Vector3(gx*cell-d.size_m*0.5,d.sample(gx,gz),gz*cell-d.size_m*0.5))
		normals.append(Vector3(d.sample(gx-1,gz)-d.sample(gx+1,gz),cell*2,d.sample(gx,gz-1)-d.sample(gx,gz+1)).normalized())
		var channels := d.tile_weight(index,key)
		uv.append(Vector2(gx*cell,gz*cell));uv2.append(Vector2(channels[2],0));colors.append(channels[0])
		var w: Color=channels[1];extra.append_array(PackedFloat32Array([w.r,w.g,w.b,w.a]))
		return vertices.size()-1
	for z in range(side):
		for x in range(side): add_vertex.call(start.x+x*stride_step,start.y+z*stride_step)
	for z in range(count):
		for x in range(count):
			var a := z*side+x
			if stride_step==1 or (x>0 and z>0 and x<count-1 and z<count-1):
				indices.append_array(PackedInt32Array([a,a+1,a+side,a+1,a+side+1,a+side]));continue
			# Keep EVERY authored edge sample in distant tiles. Fan the outer
			# cells into the coarse interior: no cracks or skirts at LOD borders.
			var gx := start.x+x*stride_step;var gz := start.y+z*stride_step
			var boundary := PackedInt32Array()
			for offset in range(0,stride_step,1 if z==0 else stride_step): boundary.append(add_vertex.call(gx+offset,gz))
			for offset in range(0,stride_step,1 if x==count-1 else stride_step): boundary.append(add_vertex.call(gx+stride_step,gz+offset))
			for offset in range(stride_step,0,-1 if z==count-1 else -stride_step): boundary.append(add_vertex.call(gx+offset,gz+stride_step))
			for offset in range(stride_step,0,-1 if x==0 else -stride_step): boundary.append(add_vertex.call(gx,gz+offset))
			var center: int=add_vertex.call(gx+stride_step/2,gz+stride_step/2)
			for j in boundary.size(): indices.append_array(PackedInt32Array([center,boundary[j],boundary[(j+1)%boundary.size()]]))
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_TEX_UV2]=uv2
	arrays[Mesh.ARRAY_COLOR]=colors; arrays[Mesh.ARRAY_CUSTOM0]=extra; arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	var node: MeshInstance3D=chunks.get(key)
	if node==null:
		node=MeshInstance3D.new(); node.name="Tile_%d_%d"%[key.x,key.y]; add_child(node); chunks[key]=node
		var body := StaticBody3D.new(); body.name="GroundCollision"; node.add_child(body)
		body.add_child(CollisionShape3D.new())
	node.mesh=mesh; node.material_override=_tile_material(key); detail_levels[key]=detailed
	var shape: CollisionShape3D=node.get_child(0).get_child(0)
	if collision and d.collisions_enabled: shape.shape=mesh.create_trimesh_shape(); collision_build_count+=1
	elif not detailed: shape.shape=null
	chunk_build_count+=1

func _asset(id: String) -> HD2DAsset:
	if asset_cache.has(id): return asset_cache[id]
	var spec: Dictionary=world_data().model_specs[id]
	var asset: HD2DAsset
	if spec.has("asset"): asset=load(str(spec.asset))
	else:
		asset=HD2DAsset.new()
		asset.asset_id=StringName(id);asset.library_entry_id=StringName("case06:"+id);asset.title=id
		if spec.get("engine_primitive","")=="plane":
			var mesh := PlaneMesh.new(); mesh.size=Vector2.ONE*float(spec.size_m); asset.source=mesh
		elif spec.get("engine_primitive","")=="box":
			var mesh := BoxMesh.new(); mesh.size=Vector3.ONE*float(spec.size_m); asset.source=mesh
		elif spec.has("gltf"): asset.source=load(world_data().recipe_root().path_join(spec.gltf))
	asset_cache[id]=asset
	return asset

func _make_prop(record: Dictionary, parent: Node3D, collision: bool) -> HD2DProp:
	var asset := _record_asset(record)
	if asset==null: return null
	var prop := HD2DProp.new(); prop.name="Object_"+str(record.id).replace(":","_")
	prop.asset=asset
	var overrides: Dictionary=world_data().object_overrides.get(record.id,{})
	prop.transform=overrides.get("transform",HD2DWorldMapData.decode_transform(record.transform))
	prop.asset_overrides=overrides.get("asset_overrides",{}).duplicate(true)
	if not prop.asset_overrides.has("static_collision"): prop.asset_overrides.static_collision=collision
	prop.set_meta("world_source_id",record.id); parent.add_child(prop)
	HD2DWorldMaterials.apply(prop,record,world_data())
	return prop

func _record_asset(record: Dictionary) -> HD2DAsset:
	var base := _asset(record.model)
	if base==null or not record.has("materials") or record.has("effect"): return base
	var key := str(record.model)+":"+str(record.materials)
	if variant_asset_cache.has(key): return variant_asset_cache[key]
	var copy := base.duplicate() as HD2DAsset;copy.static_collision=false
	var source := copy.make_node()
	source.name="PreparedModel"
	HD2DWorldMaterials.apply(source,record,world_data())
	_own_children(source,source)
	var packed := PackedScene.new();packed.pack(source);source.free();copy.source=packed
	variant_asset_cache[key]=copy
	return copy

func _own_children(node: Node, root_node: Node) -> void:
	for child in node.get_children():
		if child.name.is_empty() or str(child.name).begins_with("@"): child.name="Part%d"%child.get_index()
		child.owner=root_node;_own_children(child,root_node)

func is_vegetation(record: Dictionary) -> bool:
	# UE InstancedStaticMeshComponent also stores bridges and buildings.
	# Instancing is a storage format, not a collision/terrain-conformance category.
	return record.get("foliage",false) and world_data().model_specs.get(record.model,{}).get("category","")=="植被"

func _load_content(key: Vector2i) -> void:
	if content_nodes.has(key) or not world_data().layout_enabled: return
	var node := Node3D.new(); node.name="Scenery_%d_%d"%[key.x,key.y]
	if far_nodes.has(key): far_nodes[key].hide()
	node.set_meta("hd2d_world_scenery",true); add_child(node); content_nodes[key]=node
	var foliage := HD2DFoliage.new(); foliage.name="Foliage"
	for record in placement_buckets.get(key,[]):
		if not record.get("visible",true): continue
		var asset := _record_asset(record)
		if asset==null: continue
		var xform := HD2DWorldMapData.decode_transform(record.transform)
		var overrides: Dictionary=world_data().object_overrides.get(record.id,{})
		if overrides.has("transform"): xform=overrides.transform
		if is_vegetation(record):
			var appearance: Dictionary=overrides.get("asset_overrides",{}).duplicate(true)
			if not appearance.has("static_collision"): appearance.static_collision=false
			foliage.records.append({"asset":asset,"position":xform.origin,"transform":xform,"yaw":0.0,"scale":1.0,"asset_overrides":appearance,"source_id":record.id})
		else:
			_make_prop(record,node,world_data().collisions_enabled)
		generated_objects+=1
	node.add_child(foliage)

func _unload_content(key: Vector2i) -> void:
	if not content_nodes.has(key): return
	var node: Node=content_nodes[key]; remove_child(node); node.queue_free(); content_nodes.erase(key)
	if far_nodes.has(key): far_nodes[key].show()

func _render_far_content(key: Vector2i) -> void:
	var root_node := Node3D.new(); root_node.name="Far_%d_%d"%[key.x,key.y]
	root_node.set_meta("hd2d_world_scenery",true); add_child(root_node); far_nodes[key]=root_node
	var groups := {}
	for record in placement_buckets.get(key,[]):
		if not record.get("visible",true): continue
		var overrides: Dictionary=world_data().object_overrides.get(record.id,{})
		var appearance: Dictionary=overrides.get("asset_overrides",{}).duplicate()
		for field in appearance.keys():
			if field=="static_collision" or str(field).begins_with("collision_"): appearance.erase(field)
		var signature := str(record.model)+":"+str(record.get("materials",[]))+":"+var_to_str(appearance)
		if not groups.has(signature): groups[signature]={"record":record,"appearance":appearance,"items":[]}
		groups[signature].items.append(overrides.get("transform",HD2DWorldMapData.decode_transform(record.transform)))
	for id in groups:
		var group: Dictionary=groups[id]
		if not far_parts.has(id):
			var spec: Dictionary=world_data().model_specs[group.record.model]
			var asset: HD2DAsset
			if spec.has("far"):
				var packed: PackedScene=load(world_data().recipe_root().path_join(spec.far))
				var source := packed.instantiate();source.name="FarModel"
				HD2DWorldMaterials.apply(source,group.record,world_data())
				_own_children(source,source)
				var adapted := PackedScene.new();adapted.pack(source);source.free()
				asset=HD2DAsset.new();asset.source=adapted
			else: asset=_record_asset(group.record)
			far_parts[id]=asset.with_overrides(group.appearance).mesh_parts() if asset else []
		for part in far_parts[id]:
			var node := MultiMeshInstance3D.new();var mm := MultiMesh.new()
			mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=part.mesh;mm.instance_count=group.items.size()
			for i in group.items.size(): mm.set_instance_transform(i,group.items[i]*part.transform)
			node.multimesh=mm;node.material_override=part.material;root_node.add_child(node)

func refresh_content() -> void:
	_bucket_placements()
	for key in content_nodes.keys(): _unload_content(key)
	for key in far_nodes.keys(): remove_child(far_nodes[key]);far_nodes[key].queue_free()
	far_nodes.clear()
	if world_data().layout_enabled:
		for key in placement_buckets: _render_far_content(key)
		for key in detail_levels:
			if detail_levels[key]: _load_content(key)

func apply_record_patches(patches: Dictionary) -> void:
	var layout_changed := false
	for id in patches:
		var prior: Dictionary=world_data().object_overrides.get(id,{})
		if prior.get("transform")!=patches[id].get("transform"): layout_changed=true
		if patches[id].is_empty(): world_data().object_overrides.erase(id)
		else: world_data().object_overrides[id]=patches[id].duplicate(true)
	if layout_changed: refresh_content();return
	# Keep selected prop nodes alive when changing appearance or collision.
	# The saved patch, rather than these transient nodes, owns undo state.
	for root_node in content_nodes.values():
		for node in root_node.get_children():
			if node is HD2DProp and patches.has(node.get_meta("world_source_id","")):
				var appearance: Dictionary=world_data().object_overrides.get(node.get_meta("world_source_id"),{}).get("asset_overrides",{}).duplicate(true)
				if not appearance.has("static_collision"): appearance.static_collision=world_data().collisions_enabled
				node.asset_overrides=appearance
			elif node is HD2DFoliage:
				var changed := false
				for record in node.records:
					if not patches.has(record.source_id): continue
					record.asset_overrides=world_data().object_overrides.get(record.source_id,{}).get("asset_overrides",{}).duplicate(true)
					if not record.asset_overrides.has("static_collision"): record.asset_overrides.static_collision=false
					changed=true
				if changed: node.rebuild()
	for key in far_nodes.keys(): remove_child(far_nodes[key]);far_nodes[key].queue_free()
	far_nodes.clear()
	if world_data().layout_enabled:
		for key in placement_buckets:
			_render_far_content(key)
			if content_nodes.has(key): far_nodes[key].hide()

func conform_records(rect: Rect2i = Rect2i()) -> Dictionary:
	var d := world_data();var before := {};var after := {}
	for record in d.placements:
		if not is_vegetation(record): continue
		var source := HD2DWorldMapData.decode_transform(record.transform)
		var previous: Dictionary=d.object_overrides.get(record.id,{})
		var patch := previous.duplicate(true)
		var xform: Transform3D=patch.get("transform",source)
		var cell := Vector2(xform.origin.x,xform.origin.z)/d.cell_size()+Vector2.ONE*(d.resolution-1)*0.5
		if rect.has_area() and not Rect2(rect.grow(1)).has_point(cell): continue
		if not patch.has("ground_offset"): patch.ground_offset=float(record.get("ground_offset",0.0))
		var height := d.height_at(xform.origin.x,xform.origin.z)+float(patch.ground_offset)
		if is_equal_approx(height,xform.origin.y): continue
		xform.origin.y=height;patch.transform=xform
		before[record.id]=previous.duplicate(true);after[record.id]=patch
	if not after.is_empty(): apply_record_patches(after)
	return {"before":before,"after":after}

func region_keys(rect: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]; var q := world_data().tile_cells
	var lo := (rect.position-Vector2i.ONE).max(Vector2i.ZERO)
	var hi := rect.end.min(Vector2i.ONE*(data.resolution-2))
	for z in range(lo.y/q,hi.y/q+1):
		for x in range(lo.x/q,hi.x/q+1):
			var key := Vector2i(x,z)
			if tile_specs.has(key): result.append(key)
	return result

func rebuild_region(rect: Rect2i, collision: bool = true) -> void:
	for key in region_keys(rect): _render_tile(key,detail_levels.get(key,false),collision and detail_levels.get(key,false))

func update_collision_region(rect: Rect2i) -> void:
	for key in region_keys(rect):
		if detail_levels.get(key,false): _render_tile(key,true,true)

func update_weights_region(rect: Rect2i) -> void:
	rebuild_region(rect,false); weight_update_count+=1
