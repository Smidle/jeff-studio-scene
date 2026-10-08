@tool
extends "model_preview.gd"
var zoom := 1.0
var last_plan := ""
var rendered_assets: Array=[]
## Independent real meshes; no terrain writes, scene owners or physics preparation.
func _ready() -> void:
	super._ready()
	yaw=deg_to_rad(25)
	custom_minimum_size=Vector2(160,190)*EditorInterface.get_editor_scale()

func clear_preview() -> void:
	if is_instance_valid(content): world.remove_child(content); content.queue_free(); content=null
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	last_plan="";rendered_assets.clear()

func show_village(data: Dictionary, palette: Array, plan_key: String="") -> void:
	if not plan_key.is_empty() and plan_key==last_plan and is_instance_valid(content):
		# A material-only refresh leaves terrain, roads, framing and building meshes in place.
		for i in data.entries.size():
			var item: Dictionary=palette[data.entries[i].palette]
			var old: Node3D=content.get_node("PreviewBuilding_%d"%i)
			if rendered_assets[i]!=item.asset:
				var replacement: Node3D=item.asset.source.instantiate()
				replacement.transform=old.transform;content.remove_child(old);old.queue_free()
				replacement.name="PreviewBuilding_%d"%i;content.add_child(replacement);_disable_physics(replacement)
				old=replacement;rendered_assets[i]=item.asset
			item.asset.apply_skin(old,item.skin)
		for child in content.get_children():
			if str(child.name).begins_with("PreviewBuilding_"): continue
			refresh_materials(child,data.options)
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		return
	clear_preview()
	last_plan=plan_key
	content=Node3D.new()
	for entry in data.entries:
		var item: Dictionary=palette[entry.palette]
		var asset: HD2DAsset=item.asset
		var node: Node3D
		if asset.source is PackedScene:
			node=asset.source.instantiate(); asset.apply_skin(node,item.skin)
		else:
			var copy := asset.duplicate() as HD2DAsset; copy.static_collision=false; node=copy.make_node(item.skin)
		node.name="PreviewBuilding_%d"%rendered_assets.size();rendered_assets.append(asset)
		node.transform=Transform3D(entry.basis,entry.position); content.add_child(node)
	preload("village_structures.gd").add_walls(content,data,false)
	if data.has("draft_terrain"):
		var ground := preload("village_preview_terrain.gd").new(); ground.data=data.draft_terrain
		var terrain_area := AABB(Vector3(data.extent.position.x,-1,data.extent.position.y),Vector3(data.extent.size.x,2,data.extent.size.y))
		terrain_area=data.terrain_transform.affine_inverse()*terrain_area
		var offset := Vector2.ONE*ground.data.size_m*0.5
		var start := Vector2i((Vector2(terrain_area.position.x,terrain_area.position.z)+offset)/ground.data.cell_size())
		var end := Vector2i((Vector2(terrain_area.end.x,terrain_area.end.z)+offset)/ground.data.cell_size())
		ground.sample_rect=Rect2i(start,end-start).grow(2).intersection(Rect2i(Vector2i.ZERO,Vector2i.ONE*ground.data.resolution))
		ground.transform=data.terrain_transform
		if data.terrain_source: ground.surface_material=data.terrain_source.surface_material
		content.add_child(ground)
		preload("village_structures.gd").add_paving(content,data)
	else:
		var ground := MeshInstance3D.new(); var mesh := PlaneMesh.new(); mesh.size=data.extent.size+Vector2.ONE*3
		ground.mesh=mesh;ground.position=Vector3(data.extent.get_center().x,-0.05,data.extent.get_center().y)
		ground.material_override=preload("../runtime/building_materials.gd").material(str(data.options.get("material_style","jiangnan")),"ground")
		content.add_child(ground)
		preload("village_roads.gd").add_to(content,data)
	world.add_child(content); _disable_physics(content)
	var boxes: Array[AABB]=[]; _bounds(content,Transform3D.IDENTITY,boxes)
	model_bounds=boxes[0]
	for box in boxes: model_bounds=model_bounds.merge(box)
	var area: Rect2=data.extent.grow(2)
	model_bounds=AABB(Vector3(area.position.x,model_bounds.position.y,area.position.y),Vector3(area.size.x,maxf(model_bounds.size.y,3),area.size.y))
	center=model_bounds.get_center(); extent=maxf(model_bounds.size.length(),0.5)
	frame_model()

func frame_model() -> void:
	super.frame_model()
	camera.size*=zoom
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		zoom=clampf(zoom*(0.85 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.18),0.2,2.0)
		frame_model();accept_event()
	else:super._gui_input(event)

func refresh_materials(node: Node, options: Dictionary) -> void:
	if node is HD2DTerrain:
		node.update_material();return
	if node is MeshInstance3D and node.mesh:
		var provider=preload("../runtime/building_materials.gd")
		if node.material_override is StandardMaterial3D:
			node.material_override=provider.material(options.material_style,node.material_override.resource_name,options.appearance,options.appearance_seed)
		else:
			for surface in node.mesh.get_surface_count():
				var material: Material=node.mesh.surface_get_material(surface)
				if material: node.set_surface_override_material(surface,provider.material(options.material_style,material.resource_name,options.appearance,options.appearance_seed))
	for child in node.get_children(): refresh_materials(child,options)
