@tool
extends RefCounted
## Dedicated character catalog. Only selected sheets are prepared inside the project.
var controller
var error := ""
var warning := ""
const BUILTIN_ROOT := "res://addons/hd2d_scene_tools/assets/local_study_characters"

func catalog() -> Array:
	error="";warning=""
	var builtin := read_catalog(BUILTIN_ROOT)
	var builtin_error := error
	error=""
	var external := read_catalog(controller.shared_library.root_path())
	warning=error;error=builtin_error if builtin.is_empty() else ""
	var result: Array=builtin.duplicate();var ids := {}
	for row in result: ids[row.id]=true
	for row in external:
		if not ids.has(row.id): result.append(row);ids[row.id]=true
	if not result.is_empty(): error=""
	return result

func read_catalog(root: String) -> Array:
	var path := root.path_join("character-index.json")
	if not FileAccess.file_exists(path):
		if root==BUILTIN_ROOT: error="内置角色预设缺失，请重新安装学习版插件。"
		return []
	var data: Variant=controller.shared_library.read_index_document(path)
	if not data is Dictionary or data.get("schema_version")!=1 or not data.get("entries") is Array:
		error="角色预设索引损坏；内置角色仍可使用。"; return []
	var ids := {}
	for row in data.entries:
		if not row is Dictionary or str(row.get("id","")).is_empty() or ids.has(row.id) or not row.get("files") is Array or not row.get("animations") is Dictionary:
			error="角色预设索引损坏；内置角色仍可使用。"; return []
		ids[row.id]=true
		var sheets := {}
		for file in row.files:
			if not file is Dictionary or not controller.shared_library.safe_relative(str(file.get("path",""))) or str(file.get("sha256","")).length()!=64 or not file.get("size") is Array or file["size"].size()!=2:
				error="角色预设索引损坏；内置角色仍可使用。"; return []
			sheets[file.key]=file["size"]
		for action in ["idle","walk","run"]:
			for direction in ["s","w","n","e"]:
				var spec: Variant=row.animations.get(action+"_"+direction)
				if not spec is Dictionary or not sheets.has(spec.get("sheet")) or not spec.get("cell") is Array or spec.cell.size()!=2:
					error="角色动作或方向不完整。"; return []
				var size: Array=sheets[spec.sheet]
				if minf(float(spec.cell[0]),float(spec.cell[1]))<=0 or int(spec.get("count",0))<1 or float(spec.get("fps",0))<=0 or int(spec.get("row",-1))<0 or spec.cell[0]*spec.count>size[0] or (spec.row+1)*spec.cell[1]>size[1]:
					error="角色图集裁框超出图片范围。"; return []
	var result: Array=data.entries.duplicate(true)
	for row in result: row["_root"]=root
	return result

func prepare(record: Dictionary, current: Callable) -> HD2DCharacterProfile:
	error=""
	var root: String=record.get("_root",controller.shared_library.root_path())
	var pending: Array=[]
	var paths := {}
	for file in record.files:
		if not current.call(): return null
		var relative := "hd2d_imports/characters/"+str(file.sha256)+".png"
		var local := "res://"+relative
		var source := ProjectSettings.globalize_path(root.path_join(str(file.path)))
		var destination := ProjectSettings.globalize_path(local)
		if FileAccess.file_exists(destination):
			if FileAccess.get_sha256(destination)!=file.sha256:
				error="工程角色图片校验失败，未覆盖已有文件。"; return null
		else:
			if not FileAccess.file_exists(source) or FileAccess.get_sha256(source)!=file.sha256:
				error="角色图片缺失或校验失败："+str(file.path); return null
			DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
			var temp := destination+".copying"
			if DirAccess.copy_absolute(source,temp)!=OK or FileAccess.get_sha256(temp)!=file.sha256 or DirAccess.rename_absolute(temp,destination)!=OK:
				error="无法复制角色图片到当前工程。"; return null
			var config := ConfigFile.new()
			config.set_value("remap","importer","texture"); config.set_value("remap","type","CompressedTexture2D")
			config.set_value("params","compress/mode",0);config.set_value("params","mipmaps/generate",false)
			config.set_value("params","detect_3d/compress_to",0)
			if config.save(local+".import")!=OK: error="无法保存角色导入设置。"; return null
		paths[file.key]=local;pending.append({"path":relative})
	var ready=preload("terrain_library.gd").new()
	if paths.values().any(func(path): return not ready.import_ready(path)):
		await controller.shared_library.wait_import(paths.values()[0],pending,current)
	if not current.call() or (root!=BUILTIN_ROOT and root!=controller.shared_library.root_path()): return null
	var textures := {}
	for key in paths:
		if not ready.import_ready(paths[key]): error="角色图片导入未完成，请重新选择预设。"; return null
		textures[key]=load(paths[key]) as Texture2D
		if textures[key]==null: error="角色图片导入未完成，请重新选择预设。"; return null
	var frames := SpriteFrames.new(); frames.remove_animation("default")
	for animation in record.animations:
		var spec: Dictionary=record.animations[animation]
		frames.add_animation(animation);frames.set_animation_speed(animation,float(spec.fps));frames.set_animation_loop(animation,true)
		for i in int(spec.count):
			var texture := AtlasTexture.new(); texture.atlas=textures[spec.sheet]
			texture.region=Rect2(i*spec.cell[0],spec.row*spec.cell[1],spec.cell[0],spec.cell[1]); frames.add_frame(animation,texture)
	var profile := HD2DCharacterProfile.new()
	profile.title=record.get("name_zh",record.id);profile.frames=frames
	profile.foot_anchor=Vector2(record.foot_anchor[0],record.foot_anchor[1]);profile.pixel_size=float(record.pixel_size)
	profile.move_speed=float(record.move_speed);profile.run_speed=float(record.run_speed)
	profile.mirror_directions=PackedStringArray(record.get("mirror_directions",[]))
	profile.color_tint=Color.WHITE;profile.full_billboard=true
	profile=profile.calibrated_preset(str(record.id))
	profile.set_meta(HD2DCharacterProfile.PRESET_FOOT_REVISION,1)
	return profile
