@tool
extends RefCounted
## Generated data lives in project-owned binary files, never in editor caches.
static func is_external(value: Resource) -> bool:
	return value != null and value.resource_path.begins_with("res://") and not value.resource_path.contains("::") and FileAccess.file_exists(value.resource_path)

static func save_binary(value: Resource, path: String) -> Error:
	var error := ResourceSaver.save(value,path,ResourceSaver.FLAG_COMPRESS)
	# FLAG_CHANGE_PATH only changes the path during serialization. Bind the live
	# resource too, otherwise the next PackedScene embeds it again as text.
	if error==OK: value.take_over_path(path)
	return error

static func new_directory() -> String:
	var base := "res://hd2d_generated/"+str(Time.get_unix_time_from_system()).replace(".","_")
	var directory := base
	var suffix := 1
	while DirAccess.dir_exists_absolute(directory):
		directory=base+"_"+str(suffix);suffix+=1
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))!=OK: return ""
	return directory

var directory := ""
var saved := 0
var error: Error = OK
var visited := {}

func store(value: Resource, prefix: String) -> void:
	if error!=OK or value==null or visited.has(value) or is_external(value): return
	visited[value]=true
	error=save_binary(value,directory.path_join(prefix+"_%04d.res"%saved))
	if error==OK: saved+=1

func asset(value: HD2DAsset) -> void:
	if value and value.building_profile: store(value,"building")

func village_visuals(node: Node) -> void:
	# Prop/Road children are disposable render data and must not be authored.
	if node is HD2DProp or node is HD2DRoad: return
	if node is MeshInstance3D:
		store(node.mesh,"mesh")
		store(node.material_override,"material")
	for child in node.get_children(): village_visuals(child)

func collect(node: Node) -> void:
	if node is HD2DStage and node.library:
		for entry in node.library.assets: asset(entry)
	if node is HD2DTerrain:
		store(node.data,"terrain")
		return
	if node is HD2DProp:
		asset(node.asset)
		return
	if node is HD2DVillage:
		for entry in node.recipe.get("palette",[]): asset(entry.get("asset"))
		village_visuals(node)
	for child in node.get_children(): collect(child)

func optimize(stage: HD2DStage) -> Dictionary:
	directory=new_directory()
	if directory.is_empty(): return {"error":ERR_CANT_CREATE,"saved":0}
	collect(stage)
	return {"error":error,"saved":saved,"directory":directory}
