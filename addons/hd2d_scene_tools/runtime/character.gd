@tool
class_name HD2DCharacter
extends CharacterBody3D
@export var profile: HD2DCharacterProfile:
	set(value):
		profile=value
		if is_inside_tree(): rebuild.call_deferred()
## -1 keeps old scenes' keyboard/camera/party behavior unchanged.
@export_enum("Legacy:-1", "Player:0", "Companion:1", "NPC:2") var role: int = -1
@export var preset_id: String = ""
@export_range(0.5,8,0.1) var follow_spacing: float = 1.8
@export var keyboard_control: bool = true
@export var preview_active: bool = false
@export_range(1,80,1) var slope_limit_degrees: float = 46.0
var sprite: AnimatedSprite3D
var projected: AnimatedSprite3D
var facing: String = "s"
var external_input := Vector2.ZERO
var external_control := false
var external_running := false
var is_running := false
var input_enabled := true
var stage_walk_animation := false
var _visual_material: ShaderMaterial
var _visual_texture: Texture2D
var _occlusion_contact_normal := Vector3.ZERO
var _occlusion_contact_position := Vector3.ZERO
var _occlusion_contact_body: WeakRef

func _ready() -> void:
	rebuild()
	floor_snap_length=0.6
	floor_constant_speed=true
	floor_max_angle=deg_to_rad(slope_limit_degrees)

func rebuild() -> void:
	if profile:
		var corrected := profile.calibrated_preset(preset_id)
		if corrected!=profile:
			profile=corrected # Setter schedules one rebuild with the corrected local copy.
			return
	for node in get_children():
		if node.has_meta("hd2d_generated"):
			remove_child(node)
			node.queue_free()
	if profile == null or profile.frames == null: return
	_visual_material=null
	_visual_texture=null
	_occlusion_contact_normal=Vector3.ZERO
	_occlusion_contact_body=null
	sprite=AnimatedSprite3D.new()
	sprite.set_meta("hd2d_generated",true)
	sprite.name="SpriteVisual"
	sprite.sprite_frames=profile.frames
	sprite.pixel_size=profile.pixel_size
	sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded=profile.shaded
	sprite.flip_h=profile.flip_h
	sprite.modulate=profile.color_tint
	sprite.double_sided=true
	sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED if profile.full_billboard or role>=0 else BaseMaterial3D.BILLBOARD_FIXED_Y
	if sprite.billboard==BaseMaterial3D.BILLBOARD_ENABLED:
		_visual_material=ShaderMaterial.new()
		_visual_material.shader=preload("../shaders/character_upright.gdshader")
		_visual_material.set_shader_parameter("use_lighting",profile.shaded)
		_visual_material.set_shader_parameter("occlusion_radius",profile.collider_radius)
		_visual_material.set_shader_parameter("occlusion_margin",profile.pixel_size*2.0)
		sprite.material_override=_visual_material
	add_child(sprite)
	sprite.frame_changed.connect(_align_feet)
	# A new animation can stay on frame 0 without emitting frame_changed.
	# Bind its sheet and offsets before its new atlas UVs are rendered.
	sprite.animation_changed.connect(_align_feet)
	play_action("idle")
	var collision := CollisionShape3D.new()
	collision.name="BodyCollider"
	collision.set_meta("hd2d_generated",true)
	var capsule := CapsuleShape3D.new()
	capsule.radius=profile.collider_radius
	capsule.height=maxf(profile.collider_height,2*profile.collider_radius)
	collision.shape=capsule
	collision.position.y=capsule.height*0.5
	add_child(collision)
	projected=null
	if profile.projected_shadow:
		projected=AnimatedSprite3D.new()
		projected.name="ProjectedShadow"; projected.set_meta("hd2d_generated",true)
		projected.sprite_frames=profile.frames; projected.pixel_size=profile.pixel_size
		projected.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		projected.flip_h=profile.flip_h; projected.modulate=Color(0.14,0.11,0.025,0.34)
		projected.basis=Basis(Vector3(0.88,0,0),Vector3(-0.48,0,3.6),Vector3(0,-1,0))
		projected.position.y=0.02; projected.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(projected)
	if profile.contact_shadow:
		var contact := MeshInstance3D.new(); contact.name="ContactShadow"; contact.set_meta("hd2d_generated",true)
		var plane := PlaneMesh.new(); plane.size=Vector2(profile.collider_radius*2.5,profile.collider_radius*1.4)
		contact.mesh=plane; contact.position.y=0.012
		var mat := ShaderMaterial.new(); mat.shader=preload("../shaders/contact_shadow.gdshader")
		contact.material_override=mat; contact.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(contact)
	_align_feet()
	update_configuration_warnings()

func _align_feet() -> void:
	if not is_instance_valid(sprite) or profile.frames == null: return
	if profile.frames.get_frame_count(sprite.animation)==0: return
	var texture := profile.frames.get_frame_texture(sprite.animation,sprite.frame)
	if texture:
		sprite.offset=Vector2((0.5-profile.foot_anchor.x)*texture.get_width(),(profile.foot_anchor.y-0.5)*texture.get_height())
		if _visual_material:
			# AnimatedSprite3D already supplies atlas UVs, flip and vertex tint.
			var source: Texture2D=texture.atlas if texture is AtlasTexture else texture
			if source!=_visual_texture:
				_visual_texture=source
				_visual_material.set_shader_parameter("texture_albedo",source)
		if is_instance_valid(projected):
			projected.animation=sprite.animation; projected.frame=sprite.frame; projected.offset=sprite.offset

func set_movement_input(value: Vector2, running: bool = false) -> void:
	external_control=true
	external_input=value.limit_length(1.0)
	external_running=running

func release_external_input() -> void:
	external_control=false
	external_running=false
	external_input=Vector2.ZERO

func play_action(action: String) -> void:
	if not is_instance_valid(sprite): return
	var animation := profile.resolve(action,facing)
	sprite.flip_h=profile.flip_h != profile.mirror_directions.has(facing)
	if is_instance_valid(projected): projected.flip_h=sprite.flip_h
	if animation != &"": sprite.play(animation)

func direction_for(value: Vector2) -> String:
	if profile.directions==2: return "e" if value.x>=0 else "w"
	if profile.directions==4:
		if absf(value.x)>absf(value.y): return "e" if value.x>0 else "w"
		return "s" if value.y>0 else "n"
	var index := posmod(int(round(atan2(value.x,value.y)/(PI/4))),8)
	return ["s","se","e","ne","n","nw","w","sw"][index]

func _update_occlusion_contact() -> void:
	if _visual_material==null: return
	var normal := _occlusion_contact_normal
	var body: Node3D=_occlusion_contact_body.get_ref() as Node3D if _occlusion_contact_body else null
	var radius := profile.collider_radius*minf(global_basis.x.length(),global_basis.z.length())
	# Retain the wall while stopped or sliding along it; forget it after moving
	# away, removal, or a scene change. No additional physics queries are needed.
	if not is_instance_valid(body) or not body.is_inside_tree() or absf((global_position-_occlusion_contact_position).dot(normal))>radius*1.5:
		normal=Vector3.ZERO
		_occlusion_contact_body=null
	for i in get_slide_collision_count():
		var contact := get_slide_collision(i)
		var hit_normal := contact.get_normal()
		var collider := contact.get_collider() as Node3D
		if absf(hit_normal.y)>0.3 or not is_instance_valid(collider): continue
		normal=Vector3(hit_normal.x,0,hit_normal.z).normalized()
		_occlusion_contact_position=global_position
		_occlusion_contact_body=weakref(collider)
	if not normal.is_equal_approx(_occlusion_contact_normal):
		_occlusion_contact_normal=normal
		_visual_material.set_shader_parameter("occlusion_contact_normal",normal)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() and not preview_active: return
	if profile==null: return
	var stage := get_parent().get_parent() as HD2DStage if get_parent() else null
	var playable := role<0 or (role==0 and stage and stage.character()==self)
	var movement := external_input if external_control else Vector2.ZERO
	if playable and keyboard_control and not external_control and input_enabled:
		movement=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))).limit_length(1)
	if not input_enabled or role==2 or (role==0 and not playable): movement=Vector2.ZERO
	is_running=role>=0 and movement.length_squared()>0.01 and (external_running if external_control else Input.is_physical_key_pressed(KEY_SHIFT))
	var speed := maxf(profile.move_speed,profile.run_speed) if is_running else profile.move_speed
	if movement.length_squared()>0.01: facing=direction_for(movement)
	velocity.x=movement.x*speed
	velocity.z=movement.y*speed
	velocity.y-=20.0*delta
	move_and_slide()
	_update_occlusion_contact()
	play_action("run" if is_running else ("walk" if movement.length_squared()>0.01 or (stage_walk_animation and role!=2) else "idle"))

func _get_configuration_warnings() -> PackedStringArray:
	return profile.warnings() if profile else PackedStringArray(["请在角色面板导入角色配置。"])
