@tool
class_name HD2DFoliage
extends Node3D
@export var records: Array[Dictionary] = []
@export var chunk_size: float = 16.0
var rendered_instances := 0

func _ready() -> void: rebuild()

func restore(value: Array) -> void:
	records.assign(value.duplicate(true))
	rebuild()

func rebuild() -> void:
	if not is_inside_tree(): return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	rendered_instances=0
	var groups: Dictionary = {}
	var parts_cache: Dictionary = {}
	for record in records:
		var source_asset: HD2DAsset=record.asset
		var asset: HD2DAsset=source_asset.with_overrides(record.get("asset_overrides",{})) if source_asset else null
		if asset==null or asset.source==null: continue
		var p: Vector3=record.position
		var cell := Vector2i(floor((p.x+chunk_size*0.5)/chunk_size),floor((p.z+chunk_size*0.5)/chunk_size))
		var skin_id: StringName=StringName(record.get("skin_id",""))
		var appearance := {}
		for field in HD2DAsset.OVERRIDE_FIELDS:
			if field!="static_collision" and not field.begins_with("collision_"): appearance[field]=asset.get(field)
		var signature: String=var_to_str(appearance)
		var parts_key := "%d:%s:%s" % [source_asset.get_instance_id(),skin_id,signature]
		var key := "%s:%d:%d" % [parts_key,cell.x,cell.y]
		if not groups.has(key): groups[key]={"asset":asset,"parts_key":parts_key,"skin_id":skin_id,"items":[],"center":Vector3(cell.x*chunk_size,0,cell.y*chunk_size)}
		groups[key].items.append(record)
	for group in groups.values():
		var asset: HD2DAsset=group.asset
		var parts_key: String=group.parts_key
		if not parts_cache.has(parts_key): parts_cache[parts_key]=asset.mesh_parts(group.skin_id)
		var parts: Array=parts_cache[parts_key]
		for part in parts:
			var instance := MultiMeshInstance3D.new()
			instance.position=group.center
			var mm := MultiMesh.new()
			mm.transform_format=MultiMesh.TRANSFORM_3D
			mm.mesh=part.mesh
			mm.instance_count=group.items.size()
			for i in range(group.items.size()):
				var record: Dictionary=group.items[i]
				var basis := Basis(Vector3.UP,record.yaw).scaled(Vector3.ONE*record.scale)
				var xform: Transform3D=record.get("transform",Transform3D(basis,record.position))
				xform.origin=record.position-group.center
				mm.set_instance_transform(i,xform*part.transform)
			instance.multimesh=mm
			instance.material_override=part.material
			add_child(instance)
			rendered_instances+=mm.instance_count
	# Physics follows each record, even when appearance is shared by a MultiMesh.
	var collision_cache := {}
	for record in records:
		var base: HD2DAsset=record.get("asset")
		if base==null: continue
		var effective := base.with_overrides(record.get("asset_overrides",{}))
		if not effective.static_collision: continue
		var settings := {}
		for field in HD2DAsset.OVERRIDE_FIELDS: settings[field]=effective.get(field)
		var key := str(base.get_instance_id())+":"+var_to_str(settings)+":"+str(record.get("asset_overrides",{}).has("collision_offset"))
		if not collision_cache.has(key): collision_cache[key]=effective.collision_parts()
		for part in collision_cache[key]:
			var body := StaticBody3D.new()
			body.transform=record.get("transform",Transform3D(Basis(Vector3.UP,record.yaw).scaled(Vector3.ONE*record.scale),record.position))*part.transform
			var shape := CollisionShape3D.new(); shape.shape=part.shape
			body.add_child(shape); add_child(body)
	var ancestor := get_parent()
	while ancestor:
		if ancestor is HD2DStage:
			ancestor.apply_card_environment(self)
			break
		ancestor=ancestor.get_parent()

func erase(center: Vector3, radius: float) -> void:
	var kept: Array[Dictionary]=[]
	for record in records:
		if Vector2(record.position.x-center.x,record.position.z-center.z).length()>radius: kept.append(record)
	records=kept

func scatter(center: Vector3, radius: float, count: int, palette: Array, terrain: HD2DTerrain,
		rng: RandomNumberGenerator, scale_range: Vector2, yaw_range: Vector2, roads: Array = [], margin: float = 0.5, skin_id: StringName = &"", default_collision: bool = false) -> void:
	if palette.is_empty(): return
	for i in range(count):
		var angle := rng.randf()*TAU
		var r := sqrt(rng.randf())*radius
		var world := to_global(center+Vector3(cos(angle)*r,0,sin(angle)*r))
		if terrain:
			var local := terrain.to_local(world)
			if absf(local.x)>terrain.data.size_m/2 or absf(local.z)>terrain.data.size_m/2: continue
			world.y=terrain.world_height(world.x,world.z)
		var excluded := false
		for road in roads:
			if road.contains_world_point(world,margin): excluded=true; break
		if excluded: continue
		var asset: HD2DAsset=palette[rng.randi_range(0,palette.size()-1)]
		var record := {"asset":asset,"position":to_local(world),"yaw":deg_to_rad(rng.randf_range(yaw_range.x,yaw_range.y)),"scale":rng.randf_range(scale_range.x,scale_range.y)}
		if skin_id!=&"" and asset.supports_skin(skin_id): record.skin_id=skin_id
		if default_collision: record.asset_overrides=asset.placement_collision_overrides()
		records.append(record)

func conform_to(terrain: HD2DTerrain) -> void:
	for record in records:
		var world := to_global(record.position)
		world.y=terrain.world_height(world.x,world.z)+float(record.get("ground_offset",0.0))
		record.position=to_local(world)
		if record.has("transform"): record.transform.origin=record.position
	rebuild()
