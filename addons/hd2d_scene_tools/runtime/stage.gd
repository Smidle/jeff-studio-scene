@tool
class_name HD2DStage
extends Node3D
@export_enum("自由行走地图", "横向循环舞台") var stage_mode: int = 0
@export var library: HD2DAssetLibrary
@export_category("音乐")
@export var music_library: HD2DMusicLibrary
@export_category("循环舞台")
@export_range(4,256,0.1) var segment_length: float = 40.0
@export_range(-20,20,0.1) var scroll_speed: float = 2.0
@export var paused: bool = false
@export var seam_preview: bool = false
@export_category("环境")
@export var sky_color: Color = Color("72b5cd")
@export var horizon_color: Color = Color("e4e7d0")
@export_enum("程序天空", "背景色 / 天空模型") var sky_mode: int = 0
@export var ambient_color: Color = Color(0.86,0.91,0.76)
@export var sun_color: Color = Color("fff2ca")
@export_range(0,8,0.01) var sun_energy: float = 0.85
@export_range(-180,180,0.5) var sun_yaw: float = -35.0
@export_range(0,90,0.5) var sun_elevation: float = 48.0
@export var shadows: bool = true
@export_range(0,1,0.01) var ambient_energy: float = 0.35
@export_range(0,3,0.01) var wind_strength: float = 0.5
@export_range(0,1,0.01) var cloud_shadows: float = 0.18
@export var fog_enabled: bool = true
@export_range(0,0.1,0.001) var fog_density: float = 0.001
@export_range(0.2,2,0.01) var saturation: float = 1.05
@export_range(0.2,2,0.01) var contrast: float = 1.04
@export_range(0,1,0.01) var depth_blur: float = 0.0
@export var presentation_enabled: bool = false
@export_range(0,1,0.01) var vignette: float = 0.36
@export_range(0,2,0.01) var zone_blur: float = 0.0
@export var grade_tint: Color = Color(1.03,1.01,0.95)
@export_range(1,4,1) var presentation_pixel_size: int = 1
var preview_active := false
var travel_distance := 0.0
var loop_copies: Array[Node3D] = []
var _environment_node: WorldEnvironment
var _sun: DirectionalLight3D
var _loop_source: Node3D
var _seam_nodes: Array[MeshInstance3D]=[]
var _post: CanvasLayer
var _grade: ColorRect
var animated_materials: Array[ShaderMaterial]=[]
var animation_clock := 0.0
var music_player: HD2DMusicPlayer

func _ready() -> void:
	apply_environment()
	if not Engine.is_editor_hint() or preview_active: start_preview(preview_active)

func terrain() -> HD2DTerrain: return get_node_or_null("Terrain") as HD2DTerrain
func foliage() -> HD2DFoliage: return get_node_or_null("Scenery/Foliage") as HD2DFoliage
func camera_rig() -> HD2DCameraRig: return get_node_or_null("CameraRig") as HD2DCameraRig
func character() -> HD2DCharacter:
	for actor in characters():
		if actor.role==0: return actor
	var old := get_node_or_null("Characters/Hero") as HD2DCharacter
	return old if old and old.role<0 else null

func ensure_character_party() -> void:
	if get_node_or_null("GeneratedCharacterParty"): return
	if not characters().any(func(actor): return actor.role==1): return
	var party := preload("character_party.gd").new()
	party.name="GeneratedCharacterParty"; add_child(party)
func characters() -> Array[HD2DCharacter]:
	var result: Array[HD2DCharacter]=[]
	var parent := get_node_or_null("Characters")
	if parent:
		for child in parent.get_children():
			if child is HD2DCharacter: result.append(child)
	return result
func roads() -> Array:
	var result: Array=[]
	var scenery := get_node_or_null("Scenery")
	if scenery:
		for child in scenery.get_children():
			if child is HD2DRoad: result.append(child)
			elif child is HD2DVillage:
				for road in child.get_children():
					if road is HD2DRoad: result.append(road)
	return result

func refresh() -> void:
	apply_environment()
	if camera_rig(): camera_rig().reset_view()
	for road in roads(): road.rebuild()
	update_gizmos()

func conform_scenery() -> void:
	if terrain():
		if terrain() is HD2DWorldMap: terrain().conform_records()
		if foliage(): foliage().conform_to(terrain())
		for road in roads(): road.rebuild()

func apply_environment() -> void:
	if not is_inside_tree(): return
	if not is_instance_valid(_environment_node):
		_environment_node=WorldEnvironment.new()
		_environment_node.name="GeneratedEnvironment"
		add_child(_environment_node)
		_sun=DirectionalLight3D.new()
		_sun.name="GeneratedSun"
		add_child(_sun)
	var env: Environment=_environment_node.environment
	if env==null: env=Environment.new()
	env.background_mode=Environment.BG_SKY if sky_mode==0 else Environment.BG_COLOR
	env.background_color=sky_color
	if sky_mode==0:
		var sky := env.sky if env.sky else Sky.new()
		var sky_mat := sky.sky_material as ProceduralSkyMaterial if sky.sky_material else ProceduralSkyMaterial.new()
		sky_mat.sky_top_color=sky_color
		sky_mat.sky_horizon_color=horizon_color
		sky_mat.ground_horizon_color=horizon_color
		sky_mat.ground_bottom_color=Color("46533b")
		sky.sky_material=sky_mat
		env.sky=sky
	else:
		env.sky=null
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=ambient_color
	env.ambient_light_energy=ambient_energy
	env.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	env.fog_enabled=fog_enabled
	env.fog_density=fog_density
	env.fog_sky_affect=0.1
	env.fog_light_color=horizon_color
	env.adjustment_enabled=not presentation_enabled
	env.adjustment_saturation=saturation
	env.adjustment_contrast=contrast
	_environment_node.environment=env
	_sun.rotation_degrees=Vector3(-sun_elevation,sun_yaw,0)
	_sun.light_color=sun_color
	_sun.light_energy=sun_energy
	_sun.shadow_enabled=shadows
	_sun.shadow_opacity=0.78
	_sun.shadow_bias=0.025
	_sun.shadow_normal_bias=0.5
	_sun.directional_shadow_max_distance=160
	if terrain() and terrain().material:
		terrain().material.set_shader_parameter("cloud_strength",cloud_shadows)
	if terrain() is HD2DWorldMap:
		for palette in terrain().material_cache.values(): palette.set_shader_parameter("cloud_strength",cloud_shadows)
	if camera_rig() and is_instance_valid(camera_rig().camera):
		var attributes := CameraAttributesPractical.new()
		if RenderingServer.get_current_rendering_method() != "gl_compatibility":
			attributes.dof_blur_far_enabled=depth_blur>0
			attributes.dof_blur_far_distance=camera_rig().distance+8
			attributes.dof_blur_far_transition=25
			attributes.dof_blur_amount=depth_blur
		camera_rig().camera.attributes=attributes
	animated_materials.clear()
	apply_card_environment(self)
	_apply_presentation()

func _apply_presentation() -> void:
	# Screen-reading effects belong to game/isolated-preview viewports, never the editor UI.
	if Engine.is_editor_hint() and not preview_active: return
	if not is_instance_valid(_post):
		_post=CanvasLayer.new(); _post.layer=10; _post.name="HD2DPresentation"
		add_child(_post)
		_grade=ColorRect.new(); _grade.mouse_filter=Control.MOUSE_FILTER_IGNORE
		_post.add_child(_grade); _grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var mat := ShaderMaterial.new(); mat.shader=preload("../shaders/presentation.gdshader"); _grade.material=mat
	_post.visible=presentation_enabled
	var material := _grade.material as ShaderMaterial
	material.set_shader_parameter("vignette_amount",vignette)
	material.set_shader_parameter("zone_blur",zone_blur)
	material.set_shader_parameter("contrast",contrast)
	material.set_shader_parameter("saturation",saturation)
	material.set_shader_parameter("tint",Vector3(grade_tint.r,grade_tint.g,grade_tint.b))
	material.set_shader_parameter("pixel_size",float(presentation_pixel_size))

func apply_card_environment(node: Node) -> void:
	if node is GeometryInstance3D and node.material_override is ShaderMaterial:
		var mat: ShaderMaterial=node.material_override
		if mat.shader==preload("../shaders/card.gdshader"):
			mat.set_shader_parameter("wind_strength",wind_strength)
			mat.set_shader_parameter("cloud_strength",cloud_shadows)
		elif mat.shader in [preload("../shaders/mesh_foliage.gdshader"),preload("../shaders/layered_ground.gdshader")]:
			mat.set_shader_parameter("wind_strength",wind_strength)
			mat.set_shader_parameter("cloud_strength",cloud_shadows)
			if not animated_materials.has(mat): animated_materials.append(mat)
	for child in node.get_children(): apply_card_environment(child)

func start_preview(in_editor: bool = true) -> void:
	preview_active=in_editor
	# This is also called after _ready by the preview: never start a second voice.
	if not is_instance_valid(music_player) and (not Engine.is_editor_hint() or preview_active):
		music_player=HD2DMusicPlayer.new()
		music_player.name="GeneratedMusic"
		add_child(music_player)
		var music := music_library.active_track() if music_library else null
		if music and music.autoplay: music_player.play_track(music)
	ensure_character_party()
	for actor in characters():
		actor.preview_active=in_editor
		actor.keyboard_control=stage_mode==0 and actor==character()
		if actor.role>=0: actor.collision_layer=2; actor.collision_mask=1
		if terrain():
			actor.global_position.y=maxf(actor.global_position.y,terrain().world_height(actor.global_position.x,actor.global_position.z)+0.03)
	if camera_rig():
		camera_rig().preview_active=in_editor
		camera_rig().reset_view()
	if stage_mode==1 and loop_copies.is_empty():
		_loop_source=get_node_or_null("Scenery")
		if _loop_source:
			for i in range(3):
				var copy := _loop_source.duplicate(0) as Node3D
				copy.name="LoopRuntime_%d"%i
				add_child(copy)
				loop_copies.append(copy)
			_loop_source.hide()
			if seam_preview:
				for i in range(3):
					var marker := MeshInstance3D.new()
					var mesh := BoxMesh.new(); mesh.size=Vector3(0.04,0.12,30)
					marker.mesh=mesh
					var mat := StandardMaterial3D.new(); mat.albedo_color=Color(1,0.7,0.1); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
					marker.material_override=mat
					add_child(marker); _seam_nodes.append(marker)
			_update_loop()
	apply_environment()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not preview_active: return
	if is_instance_valid(music_player): music_player.set_stage_pause(paused)
	if not paused:
		animation_clock+=delta
		for mat in animated_materials: mat.set_shader_parameter("clock",animation_clock)
	if stage_mode==1:
		if not paused: travel_distance+=delta*scroll_speed
		_update_loop()
		for actor in characters():
			actor.stage_walk_animation=not paused
			actor.facing="e" if scroll_speed>=0 else "w"

func _update_loop() -> void:
	var phase := fposmod(travel_distance,segment_length)
	for i in range(loop_copies.size()):
		var x := (i-1)*segment_length-phase
		if phase>segment_length*0.5 and i==0: x+=3*segment_length
		loop_copies[i].position.x=x
		if _seam_nodes.size()>i: _seam_nodes[i].position=Vector3(x-segment_length*0.5,0.1,0)
	if terrain() and terrain().material: terrain().material.set_shader_parameter("travel",travel_distance)
