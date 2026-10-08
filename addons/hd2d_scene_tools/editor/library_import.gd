@tool
extends RefCounted
const EXTENSIONS := ["png","webp","jpg","jpeg","svg","glb","gltf","tscn","scn","tres","res"]
const LIMIT := 200

static func collect(paths: PackedStringArray, report: Array[String]) -> PackedStringArray:
	var result := PackedStringArray()
	var visited := {}
	for path in paths: _collect(path,result,report,visited,0)
	return result

static func _collect(path: String, result: PackedStringArray, report: Array[String], visited: Dictionary, depth: int) -> void:
	path=path.simplify_path()
	if visited.has(path): return
	visited[path]=true
	if result.size()>=LIMIT:
		report.append("单次最多导入 200 个素材，请分批导入。")
		return
	if DirAccess.dir_exists_absolute(path):
		if depth>=8: report.append("目录层级过深，已跳过："+path); return
		var dir := DirAccess.open(path)
		if dir==null: report.append("无法读取目录："+path); return
		for entry in dir.get_files():
			if entry.begins_with(".") or dir.is_link(entry): continue
			if entry.get_extension().to_lower() in EXTENSIONS: _collect(path.path_join(entry),result,report,visited,depth+1)
		for entry in dir.get_directories():
			if entry.begins_with(".") or entry=="addons" or dir.is_link(entry): continue
			_collect(path.path_join(entry),result,report,visited,depth+1)
	elif not FileAccess.file_exists(path): report.append("缺失文件："+path)
	elif path.get_extension().to_lower() not in EXTENSIONS: report.append("不支持此格式："+path)
	else: result.append(path)

static func missing_dependencies(path: String, seen: Dictionary = {}) -> Array[String]:
	var result: Array[String]=[]
	path=path.get_slice("::",0)
	if path.is_empty() or seen.has(path): return result
	seen[path]=true
	if not FileAccess.file_exists(path): return [path]
	for entry in ResourceLoader.get_dependencies(path):
		var tokens := entry.split("::")
		var dependency: String=tokens[-1]
		if tokens[0].begins_with("uid://"):
			var uid := ResourceUID.text_to_id(tokens[0])
			if ResourceUID.has_id(uid): dependency=ResourceUID.get_id_path(uid)
		result.append_array(missing_dependencies(dependency,seen))
	return result
