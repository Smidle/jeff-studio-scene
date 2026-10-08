@tool
extends SubViewportContainer
## Small independent model of the selected recipe. Never edits the active scene.
var viewport: SubViewport
var model: Node3D
var camera: Camera3D

func _init() -> void:
	custom_minimum_size=Vector2(310,270); stretch=true
	viewport=SubViewport.new(); viewport.size=Vector2i(420,340); viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_WHEN_VISIBLE; add_child(viewport)
	var environment := WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("27313b")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE; environment.environment.ambient_light_energy=0.35
	viewport.add_child(environment)
	var sun := DirectionalLight3D.new(); sun.light_energy=0.65; sun.rotation_degrees=Vector3(-55,-25,0); viewport.add_child(sun)
	camera=Camera3D.new(); viewport.add_child(camera)
	camera.look_at_from_position(Vector3(58,64,70),Vector3.ZERO)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=94

func display(kind: String, preset: Dictionary, liquid: bool, speed: float, meters: float=64.0) -> void:
	if model: model.free()
	model=Node3D.new(); viewport.add_child(model)
	var data := HD2DTerrainData.new(); data.initialize(33,meters)
	if not preset.is_empty():
		data.layer_count=preset.textures.size(); data.textures.assign(preset.textures)
		data.texture_scale=preset.texture_scale; data.ensure_extra_weights()
	HD2DTerrainTemplates.shape_data(data,kind)
	var terrain := HD2DTerrain.new(); terrain.data=data
	terrain.ready.connect(func(): terrain.material.set_shader_parameter("cloud_strength",0.0),CONNECT_ONE_SHOT)
	model.add_child(terrain)
	if liquid and kind!="flat": model.add_child(HD2DTerrainTemplates.make_liquid(kind,meters,speed))

	frame_map(meters,data)

func frame_map(meters: float, data: HD2DTerrainData) -> void:
	var top := 0.0
	for height in data.heights:top=maxf(top,height)
	var center := Vector3(0,top*0.35,0)
	camera.look_at_from_position(center+Vector3(.9,1,1.1)*meters,center)
	camera.size=maxf(meters*1.5,1.5);camera.far=maxf(4000,meters*5)

func display_terrain(source: HD2DTerrain, draft: Dictionary, convert: bool=false) -> void:
	if not source.data:return
	if model:model.free()
	model=Node3D.new();viewport.add_child(model)
	var original := source.data
	var data := HD2DTerrainData.new();data.initialize(33,original.size_m)
	data.layer_count=int(draft.get("layer_count",original.layer_count));data.ensure_extra_weights()
	data.textures.assign(draft.get("textures",original.textures).slice(0,data.layer_count))
	data.colors=original.colors.duplicate();data.texture_scale=float(draft.get("texture_scale",original.texture_scale))
	for z in 33:
		for x in 33:
			var sx := roundi(x*(original.resolution-1)/32.0);var sz := roundi(z*(original.resolution-1)/32.0)
			var idx := sz*original.resolution+sx
			data.heights[z*33+x]=original.sample(sx,sz)
			data.weights[z*33+x]=original.weights[idx]
			if data.layer_count>4 and original.weights_extra.size()>idx:data.weights_extra[z*33+x]=original.weights_extra[idx]
	var terrain := HD2DTerrain.new();terrain.data=data
	terrain.surface_material=source.surface_material.duplicate() if source.surface_material and not convert else null
	terrain.ready.connect(func():terrain.material.set_shader_parameter("cloud_strength",0.0),CONNECT_ONE_SHOT)
	model.add_child(terrain);frame_map(data.size_m,data)
