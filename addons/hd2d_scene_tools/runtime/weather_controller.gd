@tool
class_name HD2DWeatherController
extends Node3D
## Transient simulation. HD2DStage remains the only authoring settings/clock owner.
const Cycle=preload("environment_cycle.gd")
const Legacy=preload("weather_legacy_bridge.gd")
const Surface=preload("weather_surface.gd")
const FIELDS=["weather_mode","weather_intensity","weather_wind_direction","weather_wind_speed","weather_radius","weather_cover_view","weather_particles","weather_rain_size","weather_snow_size","weather_seed","weather_randomize","weather_lightning_frequency","weather_lightning_duration","weather_thunder_volume","weather_transition_seconds","weather_quality","weather_wet_ground","weather_splashes","weather_link_wind","weather_leaf_size","weather_fall_speed","weather_flip_speed","weather_leaf_emission_randomness","weather_leaf_fall_randomness","weather_leaf_drift","weather_audio","weather_audio_volume"]
var stage: Node3D
var settings: Dictionary={}
var weights := PackedFloat32Array([0,0,0,0,0,0,0,0,0,0])
var from_weights := weights.duplicate()
var target_weights := weights.duplicate()
var elapsed := 0.0
var duration := 0.0
var clock := 0.0
var day_paused := false
var wetness := 0.0
var effective_radius := 40.0
var center := Vector3.ZERO
var emitters: Array[GPUParticles3D]=[]
var field: GPUParticlesCollisionHeightField3D
var surface: Node3D
var sand: Node3D
var storm: Node3D
var sound: AudioStreamPlayer
var shelter_boxes: Array[Dictionary]=[]
var materials: Array[ShaderMaterial]=[]
var _material_originals: Array[Dictionary]=[]
var _geometry_signature := 0
var _refresh := 1.0
var _geometry_refresh := 1.0
var _field_center := Vector3.INF
var _field_radius := -1.0
var _warned_shelters := false
var _rng := RandomNumberGenerator.new()
var _random_table: ImageTexture
var _seed := -1
var _seed_source: Array=[]

func configure(owner_stage: Node3D) -> void:
	stage=owner_stage
	var incoming: Dictionary={}
	for key in FIELDS: incoming[key]=stage.get(key)
	if incoming==settings:return
	var first := settings.is_empty()
	settings=incoming
	if emitters.is_empty():_build()
	_seed_particles()
	_set_target(int(settings.weather_mode),float(settings.weather_transition_seconds),first)
	_allocate()
	collect_materials()
	_update_bounds()
	if sound.stream!=settings.weather_audio:
		sound.stop();sound.stream=settings.weather_audio
	sound.volume_db=float(settings.weather_audio_volume)+linear_to_db(maxf(weights_sum(),0.001))
	if sound.stream and not sound.playing and weights_sum()>0:sound.play()

func _set_target(mode: int, seconds: float, immediate: bool=false) -> void:
	if mode in [1,7]:mode=0 # Retired weather IDs remain reserved.
	from_weights=weights.duplicate();target_weights.fill(0)
	if mode>=2 and mode<=9:target_weights[mode]=clampf(settings.weather_intensity,0,1)
	elapsed=0;duration=0 if immediate or (Engine.is_editor_hint() and not stage.preview_active) else maxf(seconds,0)
	if duration==0:weights=target_weights.duplicate()
	if target_weights[5]>0:
		var sand_settings:Dictionary=settings.duplicate()
		# Reserve the GPU emitters' minimum slots only at the authored hard limit.
		# The original sand density, shader and defaults are otherwise unchanged.
		sand_settings.weather_particles=clampi(settings.weather_particles,100,6000)-4
		sand.configure(stage,sand_settings,5)
	if target_weights[6]>0:storm.configure(stage,settings,6)
	if is_instance_valid(sound) and sound.stream and mode>=2 and not sound.playing:
		sound.volume_db=float(settings.weather_audio_volume)+linear_to_db(maxf(weights_sum(),0.001));sound.play()
	_allocate()
	_update_particles()

func set_weather(mode: int, transition_seconds: float=5.0) -> void:
	if mode<0 or mode>9:return
	_set_target(mode,transition_seconds)

func set_time(hour: float) -> void:
	stage.environment_hour=fposmod(hour,24.0);stage.update_environment_lighting()

func pause_day_night(value: bool=true) -> void: day_paused=value

func get_weather_state() -> Dictionary:
	return {"hour":stage.environment_hour,"wetness":wetness,"wind":wind(),"weights":weights.duplicate(),"capacity":particle_capacity(),"seed":_seed,"emitter_counts":emitters.map(func(p):return p.amount)}

func _build() -> void:
	field=GPUParticlesCollisionHeightField3D.new();field.name="LocalRoofHeightField"
	field.update_mode=GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED;add_child(field)
	for i in 4:
		var p:=GPUParticles3D.new();p.name=["Rain","Snow","Maple","Sakura"][i]
		p.emitting=false;p.local_coords=false;p.fixed_fps=30;p.use_fixed_seed=true
		p.lifetime=[4.0,14.0,22.0,26.0][i];p.collision_base_size=0.05
		p.draw_order=GPUParticles3D.DRAW_ORDER_VIEW_DEPTH;p.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var process:=ShaderMaterial.new();process.shader=preload("../shaders/weather_process.gdshader")
		process.set_shader_parameter("kind",float(i+1));p.process_material=process
		var mesh:=QuadMesh.new();mesh.size=[Vector2(0.11,0.9),Vector2(0.22,0.22),Vector2(0.68,0.68),Vector2(0.5,0.5)][i]
		var draw:=ShaderMaterial.new();draw.shader=preload("../shaders/weather_draw.gdshader")
		draw.set_shader_parameter("kind",float(i+1));draw.set_shader_parameter("particle_lifetime",p.lifetime)
		if i>=2:draw.set_shader_parameter("atlas",load("res://addons/hd2d_scene_tools/assets/weather/"+(["maple","sakura"][i-2])+".png"))
		mesh.material=draw;p.draw_pass_1=mesh;add_child(p);emitters.append(p)
	sand=Legacy.new();sand.name="OriginalSandstorm";add_child(sand)
	storm=Legacy.new();storm.name="Thunder";add_child(storm)
	surface=Surface.new();surface.name="SurfaceResponse";add_child(surface);surface.setup(self)
	sound=AudioStreamPlayer.new();sound.name="WeatherAudio";add_child(sound)
	sound.finished.connect(func():
		if is_instance_valid(stage) and sound.stream and not stage.paused and weights_sum()>0:sound.play())

func _seed_particles() -> void:
	var source:Array=[int(settings.weather_seed),bool(settings.weather_randomize)]
	if source==_seed_source:return
	_seed_source=source
	if settings.weather_randomize:
		_rng.randomize();_seed=_rng.randi_range(0,2147483643)
	else:_seed=int(settings.weather_seed)
	_rng.seed=_seed
	var noise:=Image.create(8192,1,false,Image.FORMAT_RGBAF)
	for i in 8192:noise.set_pixel(i,0,Color(_rng.randf(),_rng.randf(),_rng.randf(),_rng.randf()))
	_random_table=ImageTexture.create_from_image(noise)
	for i in 4:
		emitters[i].seed=_seed+i;emitters[i].process_material.set_shader_parameter("random_table",_random_table)
	surface.set_seed(_seed)

func _allocate() -> void:
	var quality:int=clampi(settings.weather_quality,0,2)
	var budget:int=clampi(settings.weather_particles,100,6000)
	var live:Array[bool]=[]
	for ids in [[2,6],[3],[8],[9]]:
		var active:=false
		for id in ids:active=active or target_weights[id]>0.0001 or (elapsed<duration and from_weights[id]>0.0001)
		live.append(active)
	var sand_count:int=0
	if is_instance_valid(sand.effect) and is_instance_valid(sand.effect.particles):sand_count=sand.effect.particles.amount
	var splash_budget:int=mini(mini([64,128,256][quality],budget/8),maxi(0,budget-sand_count-4)) if live[0] and settings.weather_splashes else 0
	surface.set_capacity(splash_budget)
	# Inactive pools reserve only their required one slot. Current/transitioning
	# weather shares the remainder; quality no longer silently caps the user's budget.
	var remaining:=maxi(0,budget-splash_budget-sand_count-4)
	var active_count:int=live.count(true)
	var rank:=0
	for i in 4:
		var count:=1
		if live[i]:
			count+=remaining/active_count+(1 if rank<remaining%active_count else 0);rank+=1
		if emitters[i].amount!=count:emitters[i].amount=count
	field.resolution=[GPUParticlesCollisionHeightField3D.RESOLUTION_256,GPUParticlesCollisionHeightField3D.RESOLUTION_512,GPUParticlesCollisionHeightField3D.RESOLUTION_1024][quality]

func particle_capacity() -> int:
	var count:int=surface.capacity if is_instance_valid(surface) else 0
	for p in emitters:count+=p.amount
	if is_instance_valid(sand.effect) and is_instance_valid(sand.effect.particles):count+=sand.effect.particles.amount
	return count

func weights_sum() -> float:
	var total:=0.0
	for value in weights:total+=value
	return total

func environment_state() -> Dictionary:
	var base:Dictionary=Cycle.sample(stage,stage.environment_hour,0,0)
	var result:Dictionary=base.duplicate()
	for mode in range(2,7):
		if weights[mode]<=0:continue
		var value:Dictionary=Cycle.sample(stage,stage.environment_hour,mode,weights[mode])
		for key in base:
			if key=="fog_enabled":result[key]=result[key] or value[key]
			elif key=="fog_density":result[key]=maxf(result[key],value[key])
			else:result[key]+=value[key]-base[key]
	return result

func cloud_coverage() -> float:
	return clampf(0.05+weights[2]*0.65+weights[3]*0.45+weights[4]*0.6+weights[5]*0.6+weights[6]*0.85,0.05,0.95)

func wind() -> Vector2:
	var angle:float=deg_to_rad(settings.weather_wind_direction)
	var speed:float=settings.weather_wind_speed
	return Vector2(sin(angle),cos(angle))*speed

func active_camera() -> Camera3D:
	if not Engine.is_editor_hint() or stage.preview_active:return get_viewport().get_camera_3d()
	var rig=stage.camera_rig();return rig.camera if is_instance_valid(rig) else null

func _update_bounds() -> void:
	var camera:=active_camera();center=stage.global_position
	var actor=stage.character();var rig=stage.camera_rig()
	if is_instance_valid(actor):center=actor.global_position
	elif is_instance_valid(rig):center=rig.global_position
	if stage.terrain():center.y=stage.terrain().world_height(center.x,center.z)
	var radius:float=settings.weather_radius
	if camera and settings.weather_cover_view:
		var size:=camera.get_viewport().get_visible_rect().size
		for uv in [Vector2.ZERO,Vector2(1,0),Vector2(0,1),Vector2.ONE,Vector2(0.5,0.5)]:
			var origin:=camera.project_ray_origin(uv*size);var direction:=camera.project_ray_normal(uv*size)
			var distance:float=(center.y-origin.y)/direction.y if direction.y<-0.05 else 60.0
			if distance>0:
				var point:=origin+direction*minf(distance,160)
				radius=maxf(radius,maxf(absf(point.x-center.x),absf(point.z-center.z))+6)
	effective_radius=clampf(ceilf(radius/4)*4,settings.weather_radius,120)
	global_position=center;global_basis=Basis.IDENTITY
	var snapped:=Vector3(snappedf(center.x,4),snappedf(center.y,2),snappedf(center.z,4))
	if snapped!=_field_center or effective_radius!=_field_radius:
		_field_center=snapped;_field_radius=effective_radius
		field.global_position=snapped+Vector3(0,20,0);field.size=Vector3(effective_radius*2+12,100,effective_radius*2+12)
		RenderingServer.particles_collision_height_field_update(field.get_base())
	_collect_shelters()
	if weights[5]>0 or target_weights[5]>0:_allocate()
	_update_particles()

func _collect_shelters() -> void:
	shelter_boxes.clear()
	for shelter in get_tree().get_nodes_in_group("hd2d_weather_shelters"):
		if not shelter.enabled or not stage.is_ancestor_of(shelter):continue
		if stage.stage_mode==1 and is_instance_valid(stage._loop_source) and stage._loop_source.is_ancestor_of(shelter):
			for copy in stage.loop_copies:
				_add_shelter(copy.global_transform*stage._loop_source.global_transform.affine_inverse()*shelter.global_transform,shelter.size)
		else:_add_shelter(shelter.global_transform,shelter.size)
	var camera:=active_camera();var anchor:Vector3=camera.global_position if camera else center
	shelter_boxes.sort_custom(func(a,b):
		var inside_a:bool=AABB(-a.half,a.half*2).has_point(a.inverse*anchor)
		var inside_b:bool=AABB(-b.half,b.half*2).has_point(b.inverse*anchor)
		if inside_a!=inside_b:return inside_a
		return a.transform.origin.distance_squared_to(center)<b.transform.origin.distance_squared_to(center))
	if shelter_boxes.size()>16 and not _warned_shelters:
		push_warning("Weather: more than 16 nearby shelters; camera-containing and nearest regions take priority.");_warned_shelters=true
	shelter_boxes=shelter_boxes.slice(0,16)

func _add_shelter(transform: Transform3D, size: Vector3) -> void:
	if absf(transform.basis.determinant())<0.000001:return
	if transform.origin.distance_to(center)>effective_radius*1.6+size.length()*transform.basis.get_scale().length():return
	shelter_boxes.append({"transform":transform,"inverse":transform.affine_inverse(),"half":size.abs()*0.5})

func sheltered(point: Vector3) -> bool:
	for box in shelter_boxes:
		if AABB(-box.half,box.half*2).has_point(box.inverse*point):return true
	return false

func _update_particles() -> void:
	if emitters.is_empty():return
	var current:Vector4=Vector4(weights[2]+weights[6],weights[3],weights[8],weights[9])
	var wanted:Vector4=Vector4(target_weights[2]+target_weights[6],target_weights[3],target_weights[8],target_weights[9])
	var inverses:Array[Transform3D]=[];var halves:=PackedVector3Array()
	for box in shelter_boxes:inverses.append(box.inverse);halves.append(box.half)
	var count:=inverses.size()
	while inverses.size()<16:inverses.append(Transform3D.IDENTITY);halves.append(Vector3.ZERO)
	var flow:=wind()
	for i in 4:
		var p:=emitters[i];var process:=p.process_material as ShaderMaterial;var draw:=p.draw_pass_1.material as ShaderMaterial
		var active:bool=maxf(current[i],wanted[i])>0.0001
		if p.emitting!=active:p.emitting=active
		p.visibility_aabb=AABB(Vector3(-220,-80,-220),Vector3(440,200,440))
		process.set_shader_parameter("extent",Vector3(effective_radius+absf(flow.x)*2,clampf(effective_radius*0.5,18,50),effective_radius+absf(flow.y)*2))
		process.set_shader_parameter("bottom_y",center.y-40);process.set_shader_parameter("wind",flow)
		process.set_shader_parameter("speed",settings.weather_fall_speed)
		p.randomness=float(settings.weather_leaf_emission_randomness) if i>=2 else 0.0
		process.set_shader_parameter("fall_randomness",float(settings.weather_leaf_fall_randomness) if i>=2 else 0.25)
		process.set_shader_parameter("leaf_drift",settings.weather_leaf_drift)
		process.set_shader_parameter("strength",maxf(current[i],wanted[i]))
		process.set_shader_parameter("shelter_count",count);process.set_shader_parameter("shelter_inverse",inverses);process.set_shader_parameter("shelter_half",halves)
		process.set_shader_parameter("weather_clock",clock)
		draw.set_shader_parameter("visibility",current[i])
		draw.set_shader_parameter("size_scale",settings.weather_rain_size if i==0 else (settings.weather_snow_size if i==1 else settings.weather_leaf_size))
		draw.set_shader_parameter("flip_speed",settings.weather_flip_speed)
		var fall:float=-14.0 if i==0 else -1.9
		draw.set_shader_parameter("fall_velocity",Vector3(flow.x,fall*float(settings.weather_fall_speed),flow.y))
		var night:float=1-smoothstep(-8,20,sin((stage.environment_hour-6)/24*TAU)*75) if stage.day_night_enabled else 0.0
		draw.set_shader_parameter("light_tint",Vector3.ONE.lerp(Vector3(0.46,0.55,0.72),night))
	sand.set_gain(weights[5]/maxf(float(settings.weather_intensity),0.001))
	storm.set_gain(weights[6]/maxf(float(settings.weather_intensity),0.001))
	if weights[5]<0.0001 and target_weights[5]<0.0001 and is_instance_valid(sand.effect) and is_instance_valid(sand.effect.particles):
		sand.stop();_allocate()
	if weights[6]<0.0001 and target_weights[6]<0.0001:storm.stop()

func tick(delta: float) -> void:
	if not is_instance_valid(stage) or stage.paused:return
	var transitioning:bool=elapsed<duration
	clock+=delta;elapsed+=delta
	if transitioning and elapsed>=duration:_allocate()
	var blend:float=smoothstep(0,1,minf(elapsed/maxf(duration,0.001),1))
	for i in 10:weights[i]=lerpf(from_weights[i],target_weights[i],blend)
	var wet_target:float=weights[2]+weights[6] if settings.weather_wet_ground else 0.0
	wetness=move_toward(wetness,wet_target,delta/(12.0 if wet_target>wetness else 35.0))
	_refresh+=delta;_geometry_refresh+=delta
	if _refresh>=0.15:
		_refresh=0;_update_bounds();stage.update_environment_lighting();_update_materials()
	if _geometry_refresh>=0.5:
		_geometry_refresh=0;surface.refresh_geometry()
		collect_materials()
	surface.tick(delta)
	sound.volume_db=float(settings.weather_audio_volume)+linear_to_db(maxf(weights_sum(),0.001))
	if stage._environment_node is JeffSky3D:
		stage._environment_node.sky.wind_speed=wind().length()*3
		stage._environment_node.sky.wind_direction=wind().angle()-PI*0.5
		stage._environment_node.sky.process_tick(delta)
		stage._environment_node.sky_material.set_shader_parameter("jeff_clock",clock)

func _process(delta: float) -> void:
	if not is_instance_valid(stage) or settings.is_empty():return
	var running:bool=not stage.paused and (not Engine.is_editor_hint() or stage.preview_active)
	for p in emitters:p.speed_scale=1 if running else 0
	sound.stream_paused=not running
	if running:tick(delta)

func collect_materials() -> void:
	# Registration is change-driven by the geometry index, never a full-tree scan each frame.
	if surface.geometry_revision==_geometry_signature:return
	_geometry_signature=surface.geometry_revision
	for i in range(_material_originals.size()-1,-1,-1):
		var row:Dictionary=_material_originals[i]
		var node=row.node.get_ref()
		if not is_instance_valid(node) or node.material_override!=row.clone:
			materials.erase(row.clone);_material_originals.remove_at(i)
	for node in surface.material_nodes:
		if not is_instance_valid(node):continue
		var material:Material=node.material_override
		if not material is ShaderMaterial or not material.shader:continue
		var path:String=material.shader.resource_path
		if not path.begins_with("res://addons/hd2d_scene_tools/shaders/"):continue
		if path.get_file() not in ["terrain.gdshader","terrain_8.gdshader","layered_ground.gdshader","card.gdshader","mesh_foliage.gdshader"]:continue
		if materials.has(material):continue
		var clone:ShaderMaterial=material.duplicate()
		_material_originals.append({"node":weakref(node),"original":material,"clone":clone});node.material_override=clone;materials.append(clone)

	# Newly streamed/created ground receives the same value immediately.
	_update_materials()

func _update_materials() -> void:
	var flow:=wind();var linked:bool=settings.weather_link_wind and weights_sum()>0.001 and weights[5]<0.001
	for material in materials:
		var file:String=material.shader.resource_path.get_file()
		if file in ["terrain.gdshader","terrain_8.gdshader","layered_ground.gdshader"]:
			material.set_shader_parameter("weather_wetness",wetness)
		else:
			if file=="mesh_foliage.gdshader":material.set_shader_parameter("clock",stage.animation_clock)
			material.set_shader_parameter("weather_world_wind",linked)
			material.set_shader_parameter("weather_clock",clock)
			material.set_shader_parameter("weather_wind",flow)

func reset_materials() -> void:
	for row in _material_originals:
		var node=row.node.get_ref()
		if is_instance_valid(node) and node.material_override==row.clone:node.material_override=row.original
	materials.clear();_material_originals.clear();_geometry_signature=-1

func _exit_tree() -> void:reset_materials()
