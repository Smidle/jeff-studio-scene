@tool
extends RefCounted
## Terrain catalog is separate from placeable HD2DAsset entries.
var controller
var error := ""
var busy := false
var catalog: Dictionary = {}

const BUILTIN_ROOT := "res://addons/hd2d_scene_tools/assets/terrain"
var catalog_generation := 0
var source_mode := 0 # 0: bundled 512px, 1: external originals/extensions

func read_catalog() -> Dictionary:
	catalog_generation+=1; error=""
	catalog={"schema_version":1,"textures":[],"schemes":[]}
	# Sources are explicit: never silently replace an existing 1024px choice
	# with a lightweight texture. IDs remain compatible; hashes distinguish sizes.
	if source_mode==0:
		var builtin: Variant=controller.shared_library.read_index_document(BUILTIN_ROOT.path_join("catalog.json"))
		if valid_catalog(builtin): merge_catalog(builtin,BUILTIN_ROOT)
		else: error="内置地表预设缺失或损坏，请重新安装插件。"
	else:
		var root: String=controller.shared_library.root_path()
		var path := root.path_join("terrain-index.json")
		if FileAccess.file_exists(path):
			var external: Variant=controller.shared_library.read_index_document(path)
			if valid_catalog(external): merge_catalog(external,root)
			else: error="外部地表索引损坏；请切换到内置地表。"
		else: error="未连接外部地表库；请切换到内置地表或设置共享库位置。"
	return catalog

func valid_catalog(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema_version")!=1 or not value.get("textures") is Array or not value.get("schemes") is Array: return false
	var ids := {}; var schemes := {}
	for item in value.textures:
		if not item is Dictionary or not item.get("id") is String or ids.has(item.id) or not controller.shared_library.safe_relative(str(item.get("texture",""))) or not valid_digest(str(item.get("sha256",""))) or not controller.shared_library.safe_relative(str(item.get("thumbnail",""))): return false
		ids[item.id]=true
	for scheme in value.schemes:
		if not scheme is Dictionary or not scheme.get("id") is String or schemes.has(scheme.id) or not controller.shared_library.safe_relative(str(scheme.get("thumbnail",""))) or not scheme.get("layers") is Array or scheme.layers.is_empty() or scheme.layers.size()>8: return false
		schemes[scheme.id]=true
		for id in scheme.layers:
			if not ids.has(id): return false
	return true

func merge_catalog(value: Dictionary, root: String) -> void:
	for kind in ["textures","schemes"]:
		var existing := {}
		for row in catalog[kind]: existing[row.id]=true
		for source in value[kind]:
			if existing.has(source.id): continue
			var row: Dictionary=source.duplicate(true)
			row["_root"]=root; catalog[kind].append(row); existing[row.id]=true

func thumbnail(record: Dictionary) -> Texture2D:
	var root := str(record.get("_root",BUILTIN_ROOT))
	if root!=BUILTIN_ROOT and root!=controller.shared_library.root_path(): return null
	var relative := str(record.get("thumbnail",""))
	if not controller.shared_library.safe_relative(relative): return null
	var path := root.path_join(relative)
	if not FileAccess.file_exists(path): return null
	var image := Image.load_from_file(path)
	return null if image==null or image.is_empty() else ImageTexture.create_from_image(image)

func valid_digest(value: String) -> bool:
	if value.length()!=64: return false
	for character in value:
		if not "0123456789abcdef".contains(character): return false
	return true

func title(record: Dictionary) -> String:
	return str(record.get("name_"+controller.i18n.language,record.get("name_zh",record.get("id",""))))

func records_for(record: Dictionary) -> Array:
	if not record.has("layers"): return [record]
	var result: Array=[]
	for id in record.layers:
		for texture in catalog.get("textures",[]):
			if texture.id==id: result.append(texture); break
	return result

func prepare(record: Dictionary, current: Callable) -> Dictionary:
	var shared_root: String=controller.shared_library.root_path()
	var revision := catalog_generation
	while busy:
		await controller.get_tree().process_frame
		if not current.call() or revision!=catalog_generation: return {}
	if not current.call() or revision!=catalog_generation: return {}
	busy=true; error=""
	var textures: Array[Texture2D]=[]
	var names := PackedStringArray(); var ids := PackedStringArray()
	var records := records_for(record)
	var pending: Array=[]
	var paths: Array[String]=[]
	for item in records:
		if not current.call() or revision!=catalog_generation or shared_root!=controller.shared_library.root_path(): busy=false; return {}
		var root := str(item.get("_root",shared_root))
		if root!=BUILTIN_ROOT and root!=shared_root: busy=false; return {}
		var relative := "hd2d_imports/terrain/"+str(item.sha256)+".png"
		var local := "res://"+relative
		var source := root.path_join(str(item.texture))
		var destination := ProjectSettings.globalize_path(local)
		if FileAccess.file_exists(destination):
			if FileAccess.get_sha256(destination)!=item.sha256:
				error="工程地表纹理校验失败，未覆盖已有文件。"; break
		else:
			if not FileAccess.file_exists(source) or FileAccess.get_sha256(source)!=item.sha256:
				error="地表纹理缺失或校验失败："+title(item); break
			DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
			var temporary := destination.get_base_dir().path_join(".terrain-copy-"+str(OS.get_process_id()))
			if DirAccess.copy_absolute(source,temporary)!=OK or FileAccess.get_sha256(temporary)!=item.sha256 or DirAccess.rename_absolute(temporary,destination)!=OK:
				if FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
				error="无法复制地表纹理到当前工程。"; break
			# Set the intended 3D import policy before the first scan. This avoids
			# automatic reimport when a preview first uses the texture on a mesh.
			var config := ConfigFile.new()
			config.set_value("remap","importer","texture"); config.set_value("remap","type","CompressedTexture2D")
			config.set_value("params","compress/mode",0)
			config.set_value("params","mipmaps/generate",true)
			config.set_value("params","detect_3d/compress_to",0)
			if config.save(local+".import")!=OK: error="无法保存地表纹理导入设置。"; break
		paths.append(local); pending.append({"path":relative})
		names.append(str(item.get("name_zh",item.id))); ids.append(item.id)
	if error.is_empty() and not paths.is_empty() and current.call():
		controller.message("准备地表纹理 %d / %d"%[paths.size(),records.size()])
		# One filesystem scan imports the whole selected scheme together.
		if paths.any(func(path): return not import_ready(path)):
			await controller.shared_library.wait_import(paths[0],pending)
	for local in paths:
		if not error.is_empty() or not current.call(): break
		var texture: Texture2D=load(local) as Texture2D if import_ready(local) else null
		if texture==null: error="地表纹理导入失败，请检查 Godot 导入面板。"; break
		textures.append(texture)
	busy=false
	if not error.is_empty() or not current.call() or revision!=catalog_generation or shared_root!=controller.shared_library.root_path(): return {}
	controller.message("地表纹理已准备：%d 张"%textures.size())
	return {"textures":textures,"layer_names":names,"layer_preset_ids":ids,"texture_scale":float(record.get("repeat_m",2.0))}

func import_ready(path: String) -> bool:
	var config := ConfigFile.new()
	if config.load(path+".import")!=OK: return false
	var outputs: Variant=config.get_value("deps","dest_files",[])
	if outputs.is_empty(): return false
	for output in outputs:
		if not FileAccess.file_exists(str(output)): return false
	return true
