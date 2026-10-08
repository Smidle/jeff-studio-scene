@tool
class_name HD2DWorldMapRecipe
extends RefCounted
## Runtime/editor reconstruction shares the same prepared inputs and defaults.
const STEPS := ["prepare","project","terrain","surface","layout","collision","environment","presentation","reference","verify"]

const REFERENCE_VIEWS := [
 {"id":"jiangnan","zh":"江南与中原城镇","en":"Southern towns","point":Vector3(53,0,62),"frame":70.0,"pitch":55.0},
 {"id":"snow","zh":"天山雪地","en":"Tianshan snow","point":Vector3(230,0,-211),"frame":78.0,"pitch":55.0},
 {"id":"valley","zh":"云雾山谷","en":"Misty valley","point":Vector3(-25,0,71),"frame":65.0,"pitch":55.0},
 {"id":"desert","zh":"大漠","en":"Desert","point":Vector3(27,0,-200),"frame":85.0,"pitch":55.0}
]

static func create_stage(recipe: String, variant: String = "LV_World_S") -> HD2DStage:
	var d := HD2DWorldMapData.new()
	if d.load_prepared(recipe,variant)!=OK: return null
	var stage := HD2DFactory.create_stage(false,64,65)
	stage.name="Case06_WorldMap"
	var old := stage.terrain(); stage.remove_child(old); old.free()
	var terrain := HD2DWorldMap.new(); terrain.name="Terrain"; terrain.data=d
	HD2DFactory.attach(stage,terrain,stage)
	stage.sky_mode=1; stage.sky_color=Color("33392f"); stage.fog_enabled=false
	stage.sun_color=Color("fff1d2"); stage.sun_energy=0.85; stage.ambient_energy=0.65
	stage.ambient_color=Color("c5c9b1"); stage.sun_elevation=52; stage.sun_yaw=-25
	stage.cloud_shadows=0.1;stage.saturation=0.64;stage.contrast=1.06
	stage.presentation_enabled=true;stage.presentation_pixel_size=2;stage.vignette=0.22;stage.zone_blur=0.0
	stage.grade_tint=Color(1.08,1.02,0.88)
	var hero := stage.character()
	hero.position=Vector3(206,0,166) if variant=="LV_World_S" else Vector3.ZERO
	hero.position.y=d.height_at(hero.position.x,hero.position.z)+0.6
	hero.profile=load("res://local_study/case05/profiles/Actor00.tres").duplicate() as HD2DCharacterProfile
	hero.profile.move_speed=7.0; hero.slope_limit_degrees=52
	hero.profile.pixel_size=0.075;hero.profile.shaded=false
	hero.collision_layer=2; hero.collision_mask=1
	for index in range(2):
		var follower := HD2DCharacter.new(); follower.name="Follower%d"%(index+1)
		follower.profile=load("res://local_study/case05/profiles/Actor%02d.tres"%(index+2)).duplicate() as HD2DCharacterProfile
		follower.keyboard_control=false; follower.position=hero.position
		follower.profile.pixel_size=0.075;follower.profile.shaded=false
		follower.collision_layer=2; follower.collision_mask=1; follower.slope_limit_degrees=52
		HD2DFactory.attach(stage.get_node("Characters"),follower,stage)
	var party := HD2DWorldParty.new(); party.name="WorldParty"; HD2DFactory.attach(stage,party,stage)
	var climate := HD2DWorldEnvironment.new();climate.name="WorldEnvironmentAdapter";HD2DFactory.attach(stage,climate,stage)
	var hud := HD2DWorldHUD.new(); hud.name="WorldHUD"; HD2DFactory.attach(stage,hud,stage)
	terrain.focus_point=hero.position
	var rig := stage.camera_rig()
	rig.orthographic=true; rig.pitch_degrees=55; rig.yaw_degrees=0
	rig.frame_size=75; rig.distance=120; rig.focus_height=0; rig.smoothing=6
	rig.map_zoom_enabled=true
	rig.bounds_enabled=true; rig.follow_bounds=Rect2(Vector2.ONE*(-d.size_m/2),Vector2.ONE*d.size_m)
	d.completed_steps=PackedStringArray(["prepare","project","terrain","surface","layout","collision","environment","presentation"])
	return stage

static func begin_steps(stage: HD2DStage) -> void:
	var d := stage.terrain().data as HD2DWorldMapData
	d.terrain_enabled=false;d.surface_enabled=false;d.layout_enabled=false;d.collisions_enabled=false
	d.environment_enabled=false;d.party_enabled=false;d.presentation_enabled=false
	d.completed_steps=PackedStringArray(["prepare","project"])
	stage.terrain().rebuild()

static func execute_step(stage: HD2DStage, step: String, replace: bool = false) -> Error:
	if not stage or not stage.terrain() is HD2DWorldMap: return ERR_INVALID_PARAMETER
	var d := stage.terrain().data as HD2DWorldMapData
	var index := STEPS.find(step)
	if index<1: return ERR_INVALID_PARAMETER
	if step in d.completed_steps and not replace: return ERR_ALREADY_EXISTS
	if index>1 and not STEPS[index-1] in d.completed_steps: return ERR_UNCONFIGURED
	# Reload exact prepared input only for destructive regeneration. A normal step
	# enables the independent working copy prepared when this scene was created.
	if replace and step in ["terrain","surface","layout","collision"]:
		var original := HD2DWorldMapData.new()
		var err := original.load_prepared(d.recipe_path,d.variant_id)
		if err!=OK: return err
		match step:
			"terrain": d.heights=original.heights;d.coverage=original.coverage
			"surface":
				d.weights=original.weights;d.weights_extra=original.weights_extra;d.weights_ninth=original.weights_ninth
				d.weight_boundaries=original.weight_boundaries
				d.surface_overrides.clear();d.surface_period_overrides.clear();d.surface_name_overrides.clear();d.select_surface(original.active_surface)
			"layout": d.placements=original.placements;d.object_overrides.clear()
			"collision": d.source_colliders=original.source_colliders
	match step:
		"terrain": d.terrain_enabled=true
		"surface": d.surface_enabled=true
		"layout": d.layout_enabled=true
		"collision": d.collisions_enabled=true
		"environment": d.environment_enabled=true
		"party": d.party_enabled=true
		"presentation": d.presentation_enabled=true;d.party_enabled=true
		"reference":
			stage.camera_rig().frame_size=75;stage.camera_rig().pitch_degrees=55
			if stage.is_inside_tree(): stage.camera_rig().reset_view()
		"verify":
			if not check(stage).is_empty(): return ERR_INVALID_DATA
	if not step in d.completed_steps: d.completed_steps.append(step)
	d.emit_changed()
	return OK

static func check(stage: HD2DStage) -> PackedStringArray:
	var errors := PackedStringArray()
	if not stage or not stage.terrain() is HD2DWorldMap: errors.append("No world map");return errors
	var d := stage.terrain().data as HD2DWorldMapData
	if d.heights.size()!=d.resolution*d.resolution: errors.append("Height buffer length mismatch")
	if d.weights_ninth.size()!=d.heights.size(): errors.append("Ninth layer missing")
	if d.tiles.is_empty(): errors.append("No terrain tiles")
	var identifiers := {}
	for record in d.placements:
		if identifiers.has(record.id): errors.append("Duplicate placement: "+str(record.id))
		identifiers[record.id]=true
		if not d.model_specs.has(record.model): errors.append("Missing model: "+str(record.model))
	return errors

static func save_stage(stage: HD2DStage, scene_path: String) -> Error:
	if FileAccess.file_exists(scene_path): return ERR_ALREADY_EXISTS
	var data_path := scene_path.get_basename()+"_world.res"
	if FileAccess.file_exists(data_path): return ERR_ALREADY_EXISTS
	DirAccess.make_dir_recursive_absolute(scene_path.get_base_dir())
	var err := ResourceSaver.save(stage.terrain().data,data_path,ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_CHANGE_PATH)
	if err!=OK: return err
	stage.terrain().data=ResourceLoader.load(data_path,"",ResourceLoader.CACHE_MODE_IGNORE) as HD2DWorldMapData
	if stage.terrain().data==null: return ERR_FILE_CORRUPT
	var packed := PackedScene.new(); err=packed.pack(stage)
	if err!=OK: return err
	return ResourceSaver.save(packed,scene_path)
