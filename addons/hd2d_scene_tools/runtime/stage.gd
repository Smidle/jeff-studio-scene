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
@export_category("昼夜系统")
@export var day_night_enabled: bool = false
@export_range(0,23.99,0.01) var time_of_day: float = 12.0
@export var day_night_auto: bool = false
@export_range(30,7200,1) var day_duration: float = 600.0
@export_range(0,1,0.01) var night_brightness: float = 0.12
@export_range(0,2,0.01) var moon_energy: float = 0.18
@export var night_sky_color: Color = Color("0c1733")
@export var night_horizon_color: Color = Color("27314c")
@export_category("天气系统")
@export_enum("晴天:0", "下雨:2", "下雪:3", "雾天:4", "沙尘暴:5", "雷雨:6", "秋日枫叶:8", "春日樱花:9") var weather_mode: int = 0
## Missing properties in old scenes keep the original 0.4.7 renderer.
@export var weather_3d_enabled: bool = false
@export_range(0,30,0.1) var weather_transition_seconds: float = 5.0
@export_enum("低", "中", "高") var weather_quality: int = 1
@export_enum("沿用原环境", "Sky3D 像素天空") var weather_sky_backend: int = 0
@export var weather_wet_ground: bool = true
@export var weather_splashes: bool = true
@export var weather_link_wind: bool = true
@export_range(0.25,4,0.05) var weather_leaf_size: float = 1.0
@export_range(0.2,3,0.05) var weather_fall_speed: float = 1.0
@export_range(0,3,0.05) var weather_flip_speed: float = 1.0
@export_range(0,1,0.05) var weather_leaf_emission_randomness: float = 0.5
@export_range(0,0.9,0.05) var weather_leaf_fall_randomness: float = 0.25
@export_range(0,3,0.05) var weather_leaf_drift: float = 0.7
@export var weather_audio: AudioStream
@export_range(-60,0,1) var weather_audio_volume: float = -24.0
@export_range(0,1,0.01) var weather_intensity: float = 0.65
@export_range(-180,180,1) var weather_wind_direction: float = -30.0
@export_range(0,10,0.1) var weather_wind_speed: float = 2.0
@export_range(8,120,1) var weather_radius: float = 40.0
@export var weather_cover_view: bool = true
@export_range(100,6000,100) var weather_particles: int = 2400
@export_range(0.25,4.0,0.05) var weather_rain_size: float = 1.0
@export_range(0.25,4.0,0.05) var weather_snow_size: float = 1.0
@export_range(0.0,20.0,0.5) var weather_lightning_frequency: float = 6.0
@export_range(0.05,2.0,0.01) var weather_lightning_duration: float = 0.36
@export_range(-40,0,1) var weather_thunder_volume: float = -12.0
@export var weather_seed: int = 4701
## Randomize enhanced precipitation per run; turn off to replay the authored seed.
@export var weather_randomize: bool = true
var environment_hour: float = 12.0
var _lighting_elapsed: float = 0.0
var _moon: DirectionalLight3D
var _weather: Node3D
var weather_controller: Node3D:
	get: return _weather if weather_3d_enabled else null
const EnvironmentCycle = preload("environment_cycle.gd")
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
	# Apply explicitly restarts from the authored time; ticking uses the light-only path.
	environment_hour=fposmod(time_of_day,24.0)
	_lighting_elapsed=0.0
	var use_sky: bool=weather_3d_enabled and weather_sky_backend==1
	if is_instance_valid(_environment_node) and ((_environment_node is JeffSky3D)!=use_sky):
		if is_instance_valid(_sun) and _sun.get_parent()==self: remove_child(_sun);_sun.queue_free()
		if is_instance_valid(_moon) and _moon.get_parent()==self: remove_child(_moon);_moon.queue_free()
		_sun=null;_moon=null
		remove_child(_environment_node);_environment_node.queue_free();_environment_node=null
	if not is_instance_valid(_environment_node):
		_environment_node=JeffSky3D.new() if use_sky else WorldEnvironment.new()
		_environment_node.name="GeneratedEnvironment"
		add_child(_environment_node)
		if use_sky:
			_sun=_environment_node.sun;_moon=_environment_node.moon
		else:
			_sun=DirectionalLight3D.new();_sun.name="GeneratedSun";add_child(_sun)
	var env: Environment=_environment_node.environment
	if env==null: env=Environment.new()
	env.background_mode=Environment.BG_SKY if use_sky or sky_mode==0 else Environment.BG_COLOR
	env.background_color=sky_color
	if use_sky:
		_environment_node.editor_time_enabled=false;_environment_node.game_time_enabled=false;_environment_node.pause()
		_environment_node.sky.process_method=2;_environment_node.sky.fog_visible=false
		_environment_node.sky.moon_texture=load("res://addons/hd2d_scene_tools/assets/weather/pixel_moon.png")
		_environment_node.tod.celestials_calculations=0;env.volumetric_fog_enabled=false
	elif sky_mode==0:
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
		terrain().material.set_shader_parameter("cloud_strength",base_cloud_strength())
	if terrain() is HD2DWorldMap:
		for palette in terrain().material_cache.values(): palette.set_shader_parameter("cloud_strength",base_cloud_strength())
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
	if day_night_enabled and not is_instance_valid(_moon):
		_moon=DirectionalLight3D.new();_moon.name="GeneratedMoon";add_child(_moon)
		_moon.sky_mode=DirectionalLight3D.SKY_MODE_LIGHT_ONLY
		_moon.light_color=Color("a7bce9")
		_moon.shadow_bias=0.025;_moon.shadow_normal_bias=0.5
		_moon.directional_shadow_max_distance=160
	if is_instance_valid(_weather) and ((_weather is HD2DWeatherController)!=weather_3d_enabled):
		if _weather.has_method("reset_materials"): _weather.reset_materials()
		remove_child(_weather);_weather.queue_free();_weather=null
	if (weather_mode>0 or weather_3d_enabled) and not is_instance_valid(_weather):
		_weather=HD2DWeatherController.new() if weather_3d_enabled else preload("weather.gd").new()
		_weather.name="GeneratedWeather";add_child(_weather)
	if is_instance_valid(_weather):_weather.configure(self)
	update_environment_lighting()

func update_environment_lighting() -> void:
	if not is_instance_valid(_environment_node):return
	var state := EnvironmentCycle.sample(self,environment_hour)
	if weather_3d_enabled and is_instance_valid(_weather):state=_weather.environment_state()
	var env := _environment_node.environment
	if _environment_node is JeffSky3D:
		_environment_node.current_time=environment_hour
		# Keep the same authored azimuth/static elevation and day/night trajectory.
		_environment_node.sky.sun_altitude=deg_to_rad(90-state.sun_elevation)
		_environment_node.sky.sun_azimuth=deg_to_rad(sun_yaw)
		_environment_node.sky.moon_altitude=deg_to_rad(90+state.sun_elevation)
		_environment_node.sky.moon_azimuth=deg_to_rad(sun_yaw+180)
		_environment_node.sky.sun_light_energy=state.sun_energy
		_environment_node.sky.sun_light_color=state.sun_color
		_environment_node.sky.moon_light_energy=state.moon_energy
		_environment_node.sky.cumulus_coverage=_weather.cloud_coverage() if is_instance_valid(_weather) else 0.05
	env.background_color=state.sky
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
		sky_mat.sky_top_color=state.sky;sky_mat.sky_horizon_color=state.horizon
		sky_mat.ground_horizon_color=state.horizon
		sky_mat.ground_bottom_color=Color("46533b").lerp(state.sky,0.7) if day_night_enabled else Color("46533b")
	env.ambient_light_color=state.ambient_color;env.ambient_light_energy=state.ambient_energy
	env.fog_enabled=state.fog_enabled;env.fog_density=state.fog_density;env.fog_light_color=state.horizon
	if not _environment_node is JeffSky3D:_sun.rotation_degrees=Vector3(-state.sun_elevation,sun_yaw,0)
	_sun.light_color=state.sun_color;_sun.light_energy=state.sun_energy
	if is_instance_valid(_moon):
		_moon.visible=day_night_enabled
		if not _environment_node is JeffSky3D:_moon.rotation_degrees=Vector3(state.sun_elevation,sun_yaw+180,0)
		_moon.light_energy=state.moon_energy;_moon.shadow_enabled=shadows

func advance_environment(delta: float) -> void:
	if paused or not day_night_enabled or not day_night_auto or (weather_3d_enabled and is_instance_valid(_weather) and _weather.day_paused):return
	environment_hour=fposmod(environment_hour+maxf(delta,0.0)*24.0/maxf(day_duration,30.0),24.0)
	_lighting_elapsed+=delta
	# Update the small lighting state only, never rebuild roads/cameras/particle systems.
	if _lighting_elapsed>=0.1:
		_lighting_elapsed=fmod(_lighting_elapsed,0.1)
		update_environment_lighting()

func _notification(what: int) -> void:
	if not is_instance_valid(_weather) or not _weather is HD2DWeatherController:return
	if what==NOTIFICATION_EDITOR_PRE_SAVE:_weather.reset_materials()
	elif what==NOTIFICATION_EDITOR_POST_SAVE:
		_weather.collect_materials();_weather._update_materials()

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

func base_cloud_strength() -> float:
	# Preserve old Clear scenes; weather supplies its own shadows/haze, without double shading.
	return cloud_shadows if weather_mode in [0,1,7] or weather_intensity<=0.0 else 0.0

func apply_card_environment(node: Node) -> void:
	if node is GeometryInstance3D and node.material_override is ShaderMaterial:
		var mat: ShaderMaterial=node.material_override
		if mat.shader==preload("../shaders/card.gdshader"):
			mat.set_shader_parameter("wind_strength",wind_strength)
			mat.set_shader_parameter("cloud_strength",base_cloud_strength())
		elif mat.shader in [preload("../shaders/mesh_foliage.gdshader"),preload("../shaders/layered_ground.gdshader")]:
			mat.set_shader_parameter("wind_strength",wind_strength)
			mat.set_shader_parameter("cloud_strength",base_cloud_strength())
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
	advance_environment(delta)
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
