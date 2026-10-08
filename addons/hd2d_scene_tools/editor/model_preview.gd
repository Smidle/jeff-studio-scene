@tool
extends SubViewportContainer
var viewport: SubViewport
var world: Node3D
var content: Node3D
var camera: Camera3D
var center := Vector3.ZERO
var extent := 2.0
var yaw := 0.0
var model_bounds := AABB()

func _ready() -> void:
	stretch=true
	custom_minimum_size=Vector2(300,240)
	viewport=SubViewport.new(); viewport.size=Vector2i(420,320); viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	add_child(viewport)
	world=Node3D.new(); viewport.add_child(world)
	var environment := WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0.13,0.15,0.18)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=0.65
	world.add_child(environment)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees=Vector3(-45,-30,0); sun.light_energy=1.0; world.add_child(sun)
	camera=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; world.add_child(camera)
	camera.current=true
	viewport.size_changed.connect(_resize_preview)

func _resize_preview() -> void:
	if is_instance_valid(content): frame_model()

func show_asset(asset: HD2DAsset, skin_id: StringName) -> void:
	if content:
		world.remove_child(content); content.queue_free(); content=null
	if asset==null:
		viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
		return
	# Preset inspection needs meshes/materials; avoid constructing expensive
	# triangle physics merely to rotate a library thumbnail.
	if asset.source is PackedScene:
		content=(asset.source as PackedScene).instantiate() as Node3D
		asset.apply_skin(content,skin_id)
	else: content=asset.make_node(skin_id)
	world.add_child(content)
	_disable_physics(content)
	var bounds: Array[AABB] = []
	_bounds(content,Transform3D.IDENTITY,bounds)
	if bounds.is_empty(): return
	var total := bounds[0]
	for box in bounds: total=total.merge(box)
	model_bounds=total
	center=total.get_center(); extent=maxf(total.size.length(),0.5)
	yaw=deg_to_rad(25)
	frame_model()

func _disable_physics(node: Node) -> void:
	if node is CollisionObject3D: node.collision_layer=0; node.collision_mask=0
	if node is AnimationPlayer: node.stop()
	for child in node.get_children(): _disable_physics(child)

func _bounds(node: Node, parent: Transform3D, output: Array[AABB]) -> void:
	var transform_value := parent
	if node is Node3D: transform_value=parent*node.transform
	if node is MeshInstance3D and node.mesh: output.append(transform_value*node.get_aabb())
	for child in node.get_children(): _bounds(child,transform_value,output)

func frame_model() -> void:
	camera.near=maxf(0.001,extent*0.001); camera.far=extent*10.0
	camera.position=center+Vector3(sin(yaw),0.85,cos(yaw)).normalized()*extent*3
	camera.look_at(center)
	var projected := Rect2()
	for index in 8:
		var corner: Vector3=camera.transform.affine_inverse()*model_bounds.get_endpoint(index)
		var point := Vector2(corner.x,corner.y)
		projected=Rect2(point,Vector2.ZERO) if index==0 else projected.expand(point)
	var aspect := float(maxi(1,viewport.size.x))/maxi(1,viewport.size.y)
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.size=maxf(0.1,maxf(projected.size.y,projected.size.x/aspect)*1.15)
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE

func _gui_input(event: InputEvent) -> void:
	if not is_instance_valid(content): return
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_LEFT:
		yaw-=event.relative.x*0.01; frame_model(); accept_event()
