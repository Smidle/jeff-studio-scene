@tool
class_name HD2DWorldMapData
extends HD2DTerrainData
## A complete authoring grid; HD2DWorldMap streams its render/physics tiles.
## Ordinary HD2DTerrainData retains its 513-sample / eight-layer limits.
@export var recipe_path: String
@export var terrain_enabled: bool = true
@export var party_enabled: bool = true
@export var presentation_enabled: bool = true
@export var variant_id: String = "LV_World_S"
@export var tile_cells: int = 63
@export var tiles: Array[Dictionary] = []
@export var weights_ninth: PackedFloat32Array
@export var weight_boundaries: Dictionary = {}
@export var coverage: PackedByteArray
@export var placements: Array[Dictionary] = []
@export var model_specs: Dictionary = {}
@export var mesh_material_specs: Dictionary = {}
@export var source_colliders: Array[Dictionary] = []
@export var source_sprites: Array[Dictionary] = []
@export var source_lights: Array[Dictionary] = []
@export var source_particles: Array[Dictionary] = []
@export var source_regions: Array[Dictionary] = []
@export var sprite_specs: Dictionary = {}
@export var environment_enabled: bool = true
@export var surface_specs: Dictionary = {}
@export var surface_overrides: Dictionary = {}
@export var surface_period_overrides: Dictionary = {}
@export var surface_name_overrides: Dictionary = {}
@export var active_surface: String
@export var bookmarks: Array[Dictionary] = []
@export var completed_steps: PackedStringArray
@export var layout_enabled: bool = true
@export var collisions_enabled: bool = true
@export var surface_enabled: bool = true
@export var object_overrides: Dictionary = {}
@export var reconstruction_id: String
var edit_revision := 0

func _init() -> void:
	layer_count=9

func initialize(samples: int = 1135, meters: float = 688.5) -> void:
	resolution=maxi(3,samples); size_m=meters; layer_count=9
	heights.resize(samples*samples); heights.fill(0)
	weights.resize(heights.size()); weights.fill(Color(1,0,0,0))
	weights_extra.resize(heights.size()); weights_extra.fill(Color(0,0,0,0))
	weights_ninth.resize(heights.size()); weights_ninth.fill(0)
	coverage.resize(heights.size()); coverage.fill(1)
	emit_changed()

func ensure_valid() -> void:
	# Never discard a full-world buffer through the base class's small-map clamp.
	assert(resolution>=3 and heights.size()==resolution*resolution)
	assert(weights.size()==heights.size() and weights_extra.size()==heights.size())
	assert(weights_ninth.size()==heights.size())
	layer_count=9

func weight_sample(index: int) -> Variant:
	return [weights[index],weights_extra[index],weights_ninth[index],weight_boundaries.get(str(index),{}).duplicate(true)]

func set_weight_sample(index: int, value: Variant) -> void:
	weights[index]=value[0]; weights_extra[index]=value[1]; weights_ninth[index]=value[2]
	if value.size()>3 and not value[3].is_empty(): weight_boundaries[str(index)]=value[3].duplicate(true)
	else: weight_boundaries.erase(str(index))

func tile_weight(index: int, key: Vector2i) -> Array:
	var boundary: Dictionary=weight_boundaries.get(str(index),{})
	var id := "%d,%d"%[key.x,key.y]
	if not boundary.has(id): return [weights[index],weights_extra[index],weights_ninth[index]]
	var channels: Array=boundary[id];var a := Color(0,0,0,0);var b := Color(0,0,0,0);var c := 0.0
	for i in channels.size():
		if i<4: a[i]=channels[i]/255.0
		elif i<8: b[i-4]=channels[i]/255.0
		else: c=channels[i]/255.0
	return [a,b,c]

func snapshot() -> Dictionary:
	var result := super.snapshot()
	result.weights_ninth=weights_ninth.duplicate()
	result.weight_boundaries=weight_boundaries.duplicate(true)
	return result

func restore(state: Dictionary) -> void:
	heights=state.heights.duplicate(); weights=state.weights.duplicate()
	weights_extra=state.weights_extra.duplicate(); weights_ninth=state.weights_ninth.duplicate()
	weight_boundaries=state.get("weight_boundaries",{}).duplicate(true)
	emit_changed()

func brush(center: Vector3, radius: float, amount: float, mode: String, layer: int = 0,
		level: float = 0.0, ramp_origin: Vector3 = Vector3.ZERO, originals: Dictionary = {}) -> Rect2i:
	if mode!="paint":
		edit_revision+=1
		return super.brush(center,radius,amount,mode,layer,level,ramp_origin,originals)
	var step := cell_size()
	var gc := Vector2(center.x,center.z)/step+Vector2.ONE*((resolution-1)*0.5)
	var lo := Vector2i((gc-Vector2.ONE*radius/step).floor()).max(Vector2i.ZERO)
	var hi := Vector2i((gc+Vector2.ONE*radius/step).ceil()).min(Vector2i.ONE*(resolution-1))
	for z in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			var index := z*resolution+x
			if not coverage.is_empty() and coverage[index]==0: continue
			var distance := Vector2(x,z).distance_to(gc)*step
			if distance>radius: continue
			if not originals.has(index): originals[index]=weight_sample(index)
			weight_boundaries.erase(str(index))
			var blend := clampf(amount*(1.0-distance/radius),0,1)
			var target_a := Color(0,0,0,0); var target_b := Color(0,0,0,0)
			if layer<4: target_a[clampi(layer,0,3)]=1
			elif layer<8: target_b[layer-4]=1
			weights[index]=weights[index].lerp(target_a,blend)
			weights_extra[index]=weights_extra[index].lerp(target_b,blend)
			weights_ninth[index]=lerpf(weights_ninth[index],1.0 if layer==8 else 0.0,blend)
	edit_revision+=1
	return Rect2i(lo,hi-lo+Vector2i.ONE)

func recipe_root() -> String:
	return recipe_path.get_base_dir()

func select_surface(id: String) -> void:
	if not surface_specs.has(id): return
	active_surface=id
	textures.clear()
	for path in surface_specs[id].textures:
		textures.append(load(recipe_root().path_join(str(path))) as Texture2D if not str(path).is_empty() else null)
	layer_names.clear()
	for path in surface_specs[id].textures: layer_names.append(str(path).get_file().get_basename().substr(17))
	if surface_overrides.has(id): textures.assign(surface_overrides[id])
	if surface_name_overrides.has(id): layer_names=surface_name_overrides[id].duplicate()
	texture_scale=float(surface_period_overrides.get(id,surface_specs[id].get("tile_m",2.0)))

func load_prepared(path: String, variant: String = "LV_World_S") -> Error:
	var recipe: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not recipe is Dictionary or int(recipe.get("schema_version",0))!=1: return ERR_INVALID_DATA
	var folder := path.get_base_dir()
	var spec: Variant=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("variants/"+variant+"/terrain.json")))
	if not spec is Dictionary: return ERR_FILE_NOT_FOUND
	if spec.layer_ids.size()>9: return ERR_UNAVAILABLE
	recipe_path=path; variant_id=variant; reconstruction_id="case06-0.4.4"
	resolution=int(spec.resolution); size_m=float(spec.size_m); tile_cells=int(spec.tile_cells)
	heights=FileAccess.get_file_as_bytes(folder.path_join(spec.height_file)).to_float32_array()
	var raw := FileAccess.get_file_as_bytes(folder.path_join(spec.weight_file))
	var count := resolution*resolution
	var source_layers: int=spec.layer_ids.size()
	if heights.size()!=count or raw.size()!=count*source_layers: return ERR_FILE_CORRUPT
	weights.resize(count); weights_extra.resize(count); weights_ninth.resize(count)
	for i in range(count):
		var a := Color(0,0,0,0); var b := Color(0,0,0,0); var c := 0.0
		for j in range(source_layers):
			var value := raw[i*source_layers+j]/255.0
			if j<4: a[j]=value
			elif j<8: b[j-4]=value
			else: c=value
		weights[i]=a; weights_extra[i]=b; weights_ninth[i]=c
	coverage=FileAccess.get_file_as_bytes(folder.path_join(spec.coverage_file))
	if spec.has("weight_boundaries_file"): weight_boundaries=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(spec.weight_boundaries_file)))
	tiles.assign(spec.tiles); model_specs=recipe.models.duplicate(true); surface_specs=recipe.materials.duplicate(true)
	mesh_material_specs=recipe.get("mesh_materials",{}).duplicate(true)
	sprite_specs=recipe.get("sprite_specs",{}).duplicate(true)
	layer_names=PackedStringArray(recipe.layer_names); layer_preset_ids=PackedStringArray(recipe.layers)
	placements.clear(); source_colliders.clear(); bookmarks.clear();source_sprites.clear();source_lights.clear();source_particles.clear();source_regions.clear()
	var level: Variant=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("layouts/"+variant+".json")))
	if level is Dictionary: _append_layout(level)
	if variant=="LV_World_S":
		for extra in ["LV_World","LV_World_L"]:
			var more: Variant=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("layouts/"+extra+".json")))
			if more is Dictionary: _append_layout(more)
	elif variant in ["LV_World03_S","LV_World03_S1","LV_World03_ForMap"]:
		# The alternative root references a different terrain: keep it exclusive.
		for extra in ["LV_World_2","LV_World_L"]:
			var more: Variant=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("layouts/"+extra+".json")))
			if more is Dictionary: _append_layout(more)
	if not tiles.is_empty(): select_surface(str(tiles[tiles.size()/2].material))
	for record in placements:
		var p := decode_transform(record.transform).origin
		record.ground_offset=p.y-height_at(p.x,p.z)
	ensure_valid()
	return OK

func _append_layout(layout: Dictionary) -> void:
	placements.append_array(layout.objects)
	source_colliders.append_array(layout.get("colliders",[]))
	bookmarks.append_array(layout.get("markers",[]))
	source_sprites.append_array(layout.get("sprites",[]));source_lights.append_array(layout.get("lights",[]))
	source_particles.append_array(layout.get("particles",[]))
	source_regions.append_array(layout.get("regions",[]))

static func decode_transform(values: Array) -> Transform3D:
	return Transform3D(Basis(Vector3(values[0],values[1],values[2]),Vector3(values[3],values[4],values[5]),Vector3(values[6],values[7],values[8])),Vector3(values[9],values[10],values[11]))
