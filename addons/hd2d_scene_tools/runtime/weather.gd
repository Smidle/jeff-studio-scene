@tool
extends Node3D
## Local bounded weather. Authored settings are never overwritten by camera coverage.
var stage: Node3D
var particles: CPUParticles3D
var material: ShaderMaterial
var lightning: DirectionalLight3D
var thunder: AudioStreamPlayer
var signature: Array=[]
var center := Vector3.ZERO
var effective_radius := 40.0
var lightning_age := -1.0
var until_lightning := 5.0
var thunder_delay := -1.0
var weather_clock := 0.0
var coverage_elapsed := 0.0
var rng := RandomNumberGenerator.new()

func configure(source: Node3D) -> void:
	stage=source
	var next := [stage.weather_mode,stage.weather_intensity,stage.weather_radius,stage.weather_cover_view,
		stage.weather_particles,stage.weather_wind_speed,stage.weather_wind_direction,stage.weather_seed,
		stage.cloud_shadows,stage.shadows,stage.weather_thunder_volume,
		stage.weather_rain_size if stage.weather_mode in [2,6] else 1.0,
		stage.weather_snow_size if stage.weather_mode ==3 else 1.0,
		stage.weather_lightning_frequency if stage.weather_mode==6 else 0.0,
		stage.weather_lightning_duration if stage.weather_mode==6 else 0.0]
	if next==signature:return
	signature=next
	for effect in [particles,lightning,thunder]:
		if is_instance_valid(effect):remove_child(effect);effect.queue_free()
	particles=null;lightning=null;thunder=null
	lightning_age=-1.0;thunder_delay=-1.0;weather_clock=0.0
	rng.seed=stage.weather_seed;until_lightning=next_lightning_interval()
	if stage.weather_mode in [0,1,7] or stage.weather_intensity<=0.0:return
	update_center()
	if stage.weather_mode in [2,3,5,6]:create_precipitation()
	if stage.weather_mode==6 and stage.weather_lightning_frequency>0.0:
		lightning=DirectionalLight3D.new();lightning.name="Lightning";lightning.light_color=Color("c7dcff")
		lightning.sky_mode=DirectionalLight3D.SKY_MODE_LIGHT_ONLY;lightning.light_energy=0
		lightning.rotation_degrees=Vector3(-65,25,0);add_child(lightning)
		thunder=AudioStreamPlayer.new();thunder.name="Thunder";thunder.stream=make_thunder(stage.weather_seed)
		thunder.volume_db=stage.weather_thunder_volume;add_child(thunder)

func create_precipitation() -> void:
	var snow: bool=stage.weather_mode ==3
	var sand: bool=stage.weather_mode==5
	var storm: bool=stage.weather_mode in [5,6]
	particles=CPUParticles3D.new();particles.name="Precipitation";particles.emitting=false
	particles.local_coords=false;particles.use_fixed_seed=true;particles.seed=stage.weather_seed
	particles.lifetime=5.0 if sand else (8.0 if snow else 1.8)
	particles.preprocess=particles.lifetime
	particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
	particles.spread=18.0 if sand else (12.0 if snow else 2.0)
	var angle: float=deg_to_rad(stage.weather_wind_direction)
	var speed: float=maxf(stage.weather_wind_speed,9.0 if sand else (7.0 if storm else 0.0))
	var fall_speed := 0.3 if sand else (2.2 if snow else 18.0)
	var velocity := Vector3(sin(angle)*speed,-fall_speed,cos(angle)*speed)
	particles.direction=velocity.normalized();particles.initial_velocity_min=velocity.length()*0.85
	particles.initial_velocity_max=velocity.length()*1.15;particles.gravity=Vector3.ZERO
	particles.scale_amount_min=0.65;particles.scale_amount_max=1.3;particles.fixed_fps=30
	particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gradient := Gradient.new();gradient.offsets=PackedFloat32Array([0.0,0.08,0.85,1.0])
	gradient.colors=PackedColorArray([Color(1,1,1,0),Color.WHITE,Color.WHITE,Color(1,1,1,0)])
	particles.color_ramp=gradient
	material=ShaderMaterial.new();material.shader=preload("../shaders/weather_particle.gdshader")
	material.set_shader_parameter("snow",snow);material.set_shader_parameter("sand",sand)
	material.set_shader_parameter("fall_velocity",velocity)
	var quad := QuadMesh.new();quad.size=Vector2(5,2.5) if sand else (Vector2(0.34,0.34) if snow else Vector2(0.11,0.9))
	if not sand:quad.size*=clampf(stage.weather_snow_size if snow else stage.weather_rain_size,0.25,4.0)
	quad.material=material;particles.mesh=quad;add_child(particles)
	update_coverage(true);particles.emitting=true

func next_lightning_interval() -> float:
	return 60.0/maxf(stage.weather_lightning_frequency,0.01)*rng.randf_range(0.8,1.2)

func active_camera() -> Camera3D:
	# The independent preview has its own viewport camera. Never use the editor's viewport.
	if not Engine.is_editor_hint() or stage.preview_active:return get_viewport().get_camera_3d()
	var rig=stage.camera_rig()
	return rig.camera if is_instance_valid(rig) else null

func update_center() -> void:
	if not is_instance_valid(stage):return
	center=stage.global_position
	var actor=stage.character();var rig=stage.camera_rig()
	if is_instance_valid(actor):center=actor.global_position
	elif is_instance_valid(rig):center=rig.global_position
	var ground=stage.terrain()
	if is_instance_valid(ground):center.y=ground.world_height(center.x,center.z)
	var radius: float=stage.weather_radius
	var camera := active_camera()
	if stage.weather_cover_view and is_instance_valid(camera) and camera.is_inside_tree():
		var size := camera.get_viewport().get_visible_rect().size
		# Intersect visible corners with local ground, with a strict upper bound for horizon views.
		for uv in [Vector2.ZERO,Vector2(1,0),Vector2(0,1),Vector2.ONE]:
			var origin := camera.project_ray_origin(uv*size);var direction := camera.project_ray_normal(uv*size)
			if direction.y<-0.05:
				var distance := (center.y-origin.y)/direction.y
				if distance>0.0:
					var point := origin+direction*distance
					radius=maxf(radius,maxf(absf(point.x-center.x),absf(point.z-center.z))+6.0)
	# Four-metre bands avoid allocation churn while smoothly zooming.
	effective_radius=clampf(ceilf(radius/4.0)*4.0,stage.weather_radius,120.0)
	if is_instance_valid(particles):particles.global_position=center+Vector3(0,8 if stage.weather_mode==5 else 12,0)

func update_coverage(force: bool=false) -> void:
	update_center()
	if not is_instance_valid(particles):return
	var sand: bool=stage.weather_mode==5
	var velocity: Vector3=material.get_shader_parameter("fall_velocity")
	# Extra upwind margin keeps gusts from uncovering the viewed area.
	var margin := Vector2(absf(velocity.x),absf(velocity.z))*particles.lifetime*0.5
	particles.emission_box_extents=Vector3(effective_radius+margin.x,7 if sand else 10,effective_radius+margin.y)
	var density: float=pow(effective_radius/24.0,2)
	var amount: int=maxi(1,roundi(minf(stage.weather_particles,(180 if sand else 800)*density)*stage.weather_intensity))
	# Resize only on radius changes large enough to alter the count, never each frame.
	if particles.amount!=amount and (force or absi(particles.amount-amount)>100):
		# Godot clears live particles even when assigning the SAME count. Never reassign it on refresh.
		particles.amount=amount
		if particles.emitting:particles.restart(true)
	particles.visibility_aabb=AABB(Vector3(-240,-100,-240),Vector3(480,220,480))

func advance_weather(delta: float) -> void:
	if stage.paused:return
	weather_clock+=delta
	if not is_instance_valid(lightning):return
	until_lightning-=delta
	if until_lightning<=0.0:
		lightning_age=0.0;thunder_delay=rng.randf_range(0.45,1.1);until_lightning=next_lightning_interval()
	if lightning_age>=0:
		lightning_age+=delta
		var duration: float=clampf(stage.weather_lightning_duration,0.05,2.0)
		var envelope := maxf(0.0,1.0-lightning_age/duration)
		lightning.light_energy=1.7*stage.weather_intensity*envelope*envelope
		if lightning_age>=duration:lightning_age=-1.0;lightning.light_energy=0.0
	if thunder_delay>=0.0:
		thunder_delay-=delta
		if thunder_delay<0.0 and stage.weather_thunder_volume>-40.0:thunder.play()

func _process(delta: float) -> void:
	if not is_instance_valid(stage):return
	var running: bool=(not Engine.is_editor_hint() or stage.preview_active) and not stage.paused
	if is_instance_valid(particles):particles.speed_scale=1.0 if running else 0.0
	if is_instance_valid(thunder):thunder.stream_paused=not running
	if not running:return
	coverage_elapsed+=delta
	if coverage_elapsed>=0.25:coverage_elapsed=0;update_coverage()
	else:update_center()
	advance_weather(delta)

static func make_thunder(seed_value: int) -> AudioStreamWAV:
	# Original deterministic low rumble; no external sound asset or library dependency.
	var random := RandomNumberGenerator.new();random.seed=seed_value
	var data := PackedByteArray();var rate := 22050;var count := rate*3;data.resize(count*2)
	var bass := 0.0;var smooth := 0.0
	for i in count:
		var t := float(i)/rate;var noise := random.randf_range(-1.0,1.0)
		bass=lerpf(bass,noise,0.035);smooth=lerpf(smooth,noise,0.14)
		var attack := minf(1.0,t/0.025);var decay := exp(-t*1.6)*minf(1.0,(3.0-t)*2.0)
		var sample := clampf((bass*2.8+smooth*0.4)*attack*decay,-0.95,0.95)
		data.encode_s16(i*2,roundi(sample*32767))
	var stream := AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=rate;stream.data=data;return stream
