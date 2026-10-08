@tool
extends RefCounted
## Immutable templates. Appearance-only changes reuse geometry, never modify its materials.
const Generator=preload("building_generator.gd")
static var entries := {}
static var builds := 0
static var hits := 0
static var max_build_ms := 0.0
const LIMIT := 64

static func clear() -> void:
	entries.clear();builds=0;hits=0;max_build_ms=0.0

static func geometry_key(profile: HD2DBuildingProfile) -> String:
	var shape: HD2DBuildingProfile=profile.duplicate(true);shape.appearance_seed=0
	return shape.identity()

static func obtain(profile: HD2DBuildingProfile) -> HD2DAsset:
	# Legacy material algorithms and special glazing remain exactly versioned.
	if profile.generator_version<5: return Generator.new().build(profile)
	var key := geometry_key(profile)
	if not entries.has(key):
		var start := Time.get_ticks_usec()
		var source: HD2DBuildingProfile=profile.duplicate(true);source.appearance_seed=0
		entries[key]=Generator.new().build(source);builds+=1
		max_build_ms=maxf(max_build_ms,(Time.get_ticks_usec()-start)/1000.0)
		if entries.size()>LIMIT: entries.erase(entries.keys()[0])
	else: hits+=1
	var cached: HD2DAsset=entries[key]
	var result: HD2DAsset=cached.duplicate(true)
	result.building_profile=profile.duplicate(true)
	result.library_entry_id=StringName("generated-"+profile.identity());result.asset_id=result.library_entry_id
	var provider=preload("../runtime/building_materials_v5.gd")
	var root: Node3D=result.source.instantiate()
	for role in result.material_slots:
		var node: MeshInstance3D=root.get_node(NodePath(role))
		if profile.type_id=="greenhouse" and role=="glass": continue
		node.set_surface_override_material(0,provider.material(profile.style,str(role),0,profile.appearance_seed))
		for index in result.skins.size(): result.skins[index].materials[role]=provider.material(profile.style,str(role),index+1,profile.appearance_seed)
	var packed := PackedScene.new();packed.pack(root);root.free();result.source=packed
	return result
