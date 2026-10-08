@tool
class_name HD2DFactory
extends RefCounted

static func create_stage(loop: bool = false, meters: float = 256, samples: int = 257) -> HD2DStage:
	var stage := HD2DStage.new()
	stage.name="HD2D_LoopStage" if loop else "HD2D_FreeWalk"
	stage.stage_mode=1 if loop else 0
	stage.library=HD2DAssetLibrary.new()
	stage.music_library=HD2DMusicLibrary.new()
	var terrain := HD2DTerrain.new()
	terrain.name="Terrain"
	terrain.data=HD2DTerrainData.new()
	terrain.data.initialize(samples,meters)
	attach(stage,terrain,stage)
	var scenery := Node3D.new()
	scenery.name="Scenery"
	attach(stage,scenery,stage)
	var plants := HD2DFoliage.new()
	plants.name="Foliage"
	attach(scenery,plants,stage)
	var characters := Node3D.new()
	characters.name="Characters"
	attach(stage,characters,stage)
	var hero := HD2DCharacter.new()
	hero.name="Hero"
	hero.position.y=0.2
	attach(characters,hero,stage)
	var rig := HD2DCameraRig.new()
	rig.name="CameraRig"
	rig.target_path=NodePath("../Characters/Hero")
	if not loop:
		for key in HD2DCameraRig.preset_settings(1):rig.set(key,HD2DCameraRig.preset_settings(1)[key])
	attach(stage,rig,stage)
	return stage

static func attach(parent: Node, node: Node, scene_owner: Node) -> void:
	parent.add_child(node)
	node.owner=scene_owner

static func isolated_copy(stage: HD2DStage) -> HD2DStage:
	# Packing persists only owned authoring nodes, NOT transient MM/camera/physics children.
	var packed := PackedScene.new()
	packed.pack(stage)
	var copy := packed.instantiate() as HD2DStage
	copy.music_library=stage.music_library.copy_settings() if stage.music_library else HD2DMusicLibrary.new()
	# Deep-copy mutable resources explicitly; source edits/preview movement never share data.
	copy.library=stage.library.duplicate() if stage.library else HD2DAssetLibrary.new()
	copy.library.assets=[]
	if stage.library:
		for asset in stage.library.assets: copy.library.assets.append(asset.duplicate() if asset else null)
	if copy.terrain(): copy.terrain().data=stage.terrain().data.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	if copy.terrain() and copy.terrain().surface_material: copy.terrain().surface_material=copy.terrain().surface_material.duplicate()
	for actor in copy.characters():
		if actor.profile: actor.profile=actor.profile.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	if copy.foliage():
		# Dictionary.duplicate(true) does not isolate referenced Resources.
		var asset_copies: Dictionary = {}
		for i in range(stage.library.assets.size() if stage.library else 0):
			asset_copies[stage.library.assets[i]]=copy.library.assets[i]
		copy.foliage().records.clear()
		for original in stage.foliage().records:
			var record: Dictionary=original.duplicate(true)
			var asset: HD2DAsset=original.get("asset")
			if asset:
				if not asset_copies.has(asset): asset_copies[asset]=asset.duplicate()
				record.asset=asset_copies[asset]
			copy.foliage().records.append(record)
	for road in copy.roads(): road.curve=road.curve.duplicate()
	_isolate_props(copy,{})
	_unique_materials(copy)
	return copy

static func _isolate_props(node: Node, copies: Dictionary) -> void:
	if node is HD2DProp and node.asset:
		if not copies.has(node.asset): copies[node.asset]=node.asset.duplicate()
		node.asset=copies[node.asset]
		if node.material_override: node.material_override=node.material_override.duplicate()
	for child in node.get_children(): _isolate_props(child,copies)

static func _unique_materials(node: Node) -> void:
	if node is GeometryInstance3D and node.material_override: node.material_override=node.material_override.duplicate()
	for child in node.get_children(): _unique_materials(child)
