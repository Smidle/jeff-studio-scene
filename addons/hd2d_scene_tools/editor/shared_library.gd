@tool
extends RefCounted
signal location_changed
const DEFAULT_ROOT := "/Volumes/chao_yin_ssd/game/HD2D_Shared_Asset_Library"
const SETTING := "hd2d_scene_tools/shared_asset_library_path"
const Importer = preload("library_import.gd")
var controller
var root_override := "" # Isolated QA may override this without changing real editor preferences.
var preparing := false
var prepare_serial := 0
var active_current := Callable()
var prepare_started_ms := 0
var import_timeout_ms := 90000
var prepared: Dictionary = {}
var prepared_order: Array[String] = []
const PREPARED_LIMIT := 4
const PIXEL_PARAMS := {"compress/mode":0,"mipmaps/generate":false,"detect_3d/compress_to":0,"process/fix_alpha_border":false}
var error := ""
var location_dialog: EditorFileDialog
var lock_token := ""
var lock_root := ""

func root_path() -> String:
	if not root_override.is_empty(): return root_override
	if OS.has_environment("HD2D_SHARED_LIBRARY_TEST_ROOT"): return OS.get_environment("HD2D_SHARED_LIBRARY_TEST_ROOT")
	var settings := EditorInterface.get_editor_settings()
	if not settings.has_setting(SETTING): settings.set_setting(SETTING,DEFAULT_ROOT)
	return str(settings.get_setting(SETTING)).simplify_path()

func choose_location() -> void:
	if not is_instance_valid(location_dialog):
		location_dialog=EditorFileDialog.new(); location_dialog.file_mode=EditorFileDialog.FILE_MODE_OPEN_DIR
		location_dialog.access=EditorFileDialog.ACCESS_FILESYSTEM; location_dialog.title="共享库位置"
		controller.ui.add_child(location_dialog); controller.i18n.watch(location_dialog)
		location_dialog.dir_selected.connect(func(path):
			if ProjectSettings.localize_path(path).begins_with("res://"):
				controller.message("请选择当前工程之外的共享库目录。"); return
			EditorInterface.get_editor_settings().set_setting(SETTING,path)
			recheck_connection())
	location_dialog.current_dir=root_path(); location_dialog.popup_centered_ratio(0.7)

func read_index_document(path: String) -> Variant:
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null:return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text())!=OK:return null
	return parser.data

func connection_status() -> Dictionary:
	var path := root_path()
	var result := {"connected":false,"objects":false,"terrain":false,"invalid":false,"message":"共享库未连接。可稍后设置；本地素材、纯色地形和已准备场景仍可使用。"}
	if not DirAccess.dir_exists_absolute(path):return result
	if ProjectSettings.localize_path(path).begins_with("res://"):
		result.message="共享库位于当前工程内，可能导致大量导入。请改选工程外目录；可继续使用本地资源。";return result
	var errors := PackedStringArray()
	for name in ["preset-index.json","index.json","terrain-index.json"]:
		var file := path.path_join(name)
		if not FileAccess.file_exists(file):continue
		var value: Variant=read_index_document(file)
		var terrain: bool=name=="terrain-index.json"
		var valid: bool=value is Dictionary
		if valid:
			valid=value.get("schema_version")==1 and value.get("textures") is Array and value.get("schemes") is Array if terrain else value.get("schema_version")==2 and value.get("entries") is Array
		if not valid:errors.append(name);continue
		result["terrain" if terrain else "objects"]=true
	result.connected=result.objects or result.terrain
	result.invalid=not errors.is_empty()
	if result.invalid:result.message="共享库索引无法读取，请检查目录或重新安装；本地资源不受影响。"+"\n"+", ".join(errors)
	elif not result.connected:result.message="该目录尚未安装共享库索引。可更改位置或稍后安装，不影响本地素材。"
	else:result.message="已沿用本机设置，无需重复设置。物件库与地表库共用此位置。" if result.terrain else "已沿用本机设置，无需重复设置。此库尚未安装地表预设，可继续使用物件和本地图片。"
	return result

func recheck_connection() -> Dictionary:
	var state := connection_status()
	if is_instance_valid(controller.workbench):controller.workbench.refresh_catalogs()
	location_changed.emit()
	return state

func read_index(at: String = "") -> Dictionary:
	var base := root_path() if at.is_empty() else at
	var result := {"schema_version":2,"entries":[]}
	var entries := {}
	for name in ["index.json","preset-index.json"]:
		var path := base.path_join(name)
		if not FileAccess.file_exists(path): continue
		var data: Variant=read_index_document(path)
		if not data is Dictionary or data.get("schema_version")!=2 or not data.get("entries") is Array:
			error="共享库索引损坏；已停止写入。"; return {}
		for record in data.entries:
			if not record is Dictionary or not record.has("id"): error="共享库索引损坏；已停止写入。"; return {}
			entries[str(record.id)]=record
	result.entries=entries.values()
	return result

func thumbnail(record: Dictionary, skin: String = "") -> Texture2D:
	var relative: String=record.get("thumbnail","") if skin.is_empty() else record.get("previews",{}).get(skin,"")
	if relative.is_empty(): return null
	if relative.begins_with("res://"): return load(relative) as Texture2D if ResourceLoader.exists(relative) else null
	if not safe_relative(relative): return null
	var path := root_path().path_join(relative)
	if not FileAccess.file_exists(path): return null
	var image := Image.load_from_file(path)
	if image==null or image.is_empty(): return null
	var largest := maxi(image.get_width(),image.get_height())
	if largest>128:
		var ratio := 128.0/largest
		image.resize(maxi(1,roundi(image.get_width()*ratio)),maxi(1,roundi(image.get_height()*ratio)),Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

static func safe_relative(path: String) -> bool:
	return not path.is_empty() and not path.is_absolute_path() and not path.contains("..") and not path.contains(":") and not path.begins_with(".")

static func copy_phase(path: String) -> int:
	if path.ends_with(".import"): return 0
	if path.get_extension() in ["res","tres","tscn","scn"]: return 2
	return 1

func acquire(at: String) -> bool:
	if not lock_token.is_empty(): error="共享库写入忙，请稍后重试。"; return false
	if DirAccess.make_dir_recursive_absolute(at)!=OK: error="无法创建共享库："+at; return false
	var path := at.path_join(".write-lock")
	var deadline := Time.get_ticks_msec()+15000
	while DirAccess.make_dir_absolute(path)!=OK:
		if Time.get_ticks_msec()>deadline: error="共享库写入锁忙；另一工程正在写入，请稍后重试。"; return false
		await controller.get_tree().create_timer(0.1).timeout
	lock_token=Crypto.new().generate_random_bytes(12).hex_encode(); lock_root=at
	write_json(path.path_join("owner.json"),{"pid":OS.get_process_id(),"host":OS.get_unique_id(),"token":lock_token})
	return true

func release_lock() -> void:
	if lock_token.is_empty(): return
	var path := lock_root.path_join(".write-lock")
	var owner: Variant=JSON.parse_string(FileAccess.get_file_as_string(path.path_join("owner.json")))
	if owner is Dictionary and owner.get("token")==lock_token:
		DirAccess.remove_absolute(path.path_join("owner.json")); DirAccess.remove_absolute(path)
	lock_token=""; lock_root=""

static func write_json(path: String, data: Variant) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(data,"\t")); file.flush(); file.close(); return true

func commit(record: Dictionary, staged_payload: String, at: String) -> Dictionary:
	if not await acquire(at): return {"error":error}
	var index := read_index(at)
	if index.is_empty(): release_lock(); return {"error":error}
	for existing in index.entries:
		if existing.get("source")=="user" and existing.get("content_hash")==record.content_hash:
			release_lock(); return {"record":existing,"duplicate":true}
	var destination := at.path_join(record.payload)
	if DirAccess.dir_exists_absolute(destination):
		# An interrupted writer may leave an unindexed payload. Verify it before reuse.
		for file in record.files:
			if FileAccess.get_sha256(destination.path_join(file.path))!=file.sha256:
				error="未完成的入库文件校验失败："+destination; release_lock(); return {"error":error}
	else:
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		if DirAccess.rename_absolute(staged_payload,destination)!=OK:
			release_lock(); return {"error":"无法提交素材文件。"}
	# The preset manifest stays authoritative; never snapshot it into personal data.
	index.entries=index.entries.filter(func(entry): return entry.get("source")=="user")
	index.entries.append(record)
	var temporary := at.path_join(".index-"+lock_token+".json")
	if not write_json(temporary,index) or DirAccess.rename_absolute(temporary,at.path_join("index.json"))!=OK:
		release_lock(); return {"error":"无法原子更新共享库索引。"}
	release_lock(); return {"record":record,"duplicate":false}

func prepare(record: Dictionary, still_current: Callable = Callable(), progress: Callable = Callable()) -> HD2DAsset:
	var queued_at := Time.get_ticks_msec()
	while preparing:
		if not is_current(still_current): return null
		# A closed/replaced selection must not hold up the next request, even
		# if its coroutine was interrupted during an editor script reload.
		if not is_current(active_current) or Time.get_ticks_msec()-prepare_started_ms>import_timeout_ms+5000:
			prepare_serial+=1; preparing=false; break
		report_progress(progress,"等待上一项素材准备结束…")
		if Time.get_ticks_msec()-queued_at>import_timeout_ms:
			error="素材准备等待超时。请重试；仍失败时检查 Godot 的输出和导入面板。"; return null
		await controller.get_tree().create_timer(0.05).timeout
	if not is_current(still_current): return null
	preparing=true; prepare_serial+=1; prepare_started_ms=Time.get_ticks_msec()
	var serial := prepare_serial
	var root := root_path()
	var current := func(): return serial==prepare_serial and root==root_path() and is_current(still_current)
	active_current=current
	error=""
	var result := await prepare_files(record,current,progress)
	if serial==prepare_serial: preparing=false; active_current=Callable()
	return result if current.call() else null

func is_current(current: Callable) -> bool:
	return not current.is_valid() or bool(current.call())

func report_progress(progress: Callable, value: String) -> void:
	if progress.is_valid(): progress.call(value)
	else: controller.message(value)

func prepare_files(record: Dictionary, current: Callable, progress: Callable) -> HD2DAsset:
	var key := str(record.id)+":"+str(record.get("content_hash",""))
	if prepared.has(key):
		prepared_order.erase(key); prepared_order.append(key)
		return prepared[key]
	if not record.has("files"):
		# Read-only compatibility for previously installed project-local catalogs.
		return load(str(record.asset)) as HD2DAsset if ResourceLoader.exists(str(record.asset)) else null
	var at := root_path()
	var files: Array=record.files.duplicate()
	# Install source settings before their images/models. Focus-triggered editor
	# scans can run between copy yields; a late sidecar must not erase a remap
	# that the editor has just generated for the source file.
	files.sort_custom(func(a,b): return copy_phase(str(a.path))<copy_phase(str(b.path)))
	var imports_ready := false
	var imported_dependencies: Array[Resource]=[]
	for i in files.size():
		if not current.call(): return null
		var file: Dictionary=files[i]
		var relative := str(file.path)
		if not safe_relative(relative) or not safe_relative(str(record.payload)):
			error="无效的共享库资源路径。"; break
		# Native resource thumbnails can load a .res as soon as it appears.
		# Finish its raw texture/model imports before exposing linked resources.
		if copy_phase(relative)==2 and not imports_ready:
			for dependency in files:
				if str(dependency.path).get_extension() not in ["png","webp","jpg","jpeg","svg","glb","gltf"]: continue
				var imported := await wait_import("res://"+str(dependency.path),files,current,progress)
				if not current.call(): return null
				if imported==null: break
				imported_dependencies.append(imported)
				break # wait_import checks every raw dependency in files in one scan.
			imports_ready=true
			if not error.is_empty(): break
		var destination := ProjectSettings.globalize_path("res://"+relative)
		if FileAccess.file_exists(destination):
			if relative.ends_with(".import"): continue
			if FileAccess.get_sha256(destination)!=file.sha256: error="工程已有不同内容，未覆盖："+relative; break
			continue
		var source := at.path_join(record.payload).path_join(relative)
		# Godot may regenerate .import sidecars if an extracted folder was scanned.
		# New preset manifests retain the exact authoring configuration independently.
		var config_text: String=str(file.get("import_config","")) if relative.ends_with(".import") else ""
		if not config_text.is_empty() and config_text.sha256_text()!=str(file.sha256):
			error="共享库索引中的导入配置校验失败，请重新解压共享素材库："+relative; break
		if config_text.is_empty():
			if not FileAccess.file_exists(source):
				error="共享库缺少文件，请重新解压共享素材库："+relative; break
			if FileAccess.get_sha256(source)!=file.sha256:
				error=("共享库导入配置已被改写，请重新解压共享素材库到工程外，或更新新版共享包：" if relative.ends_with(".import") else "共享库原始素材校验失败，请重新解压共享素材库：")+relative; break
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		var temp := destination.get_base_dir().path_join(".hd2d-copy-"+str(OS.get_process_id()))
		var copied := false
		if not config_text.is_empty():
			var output := FileAccess.open(temp,FileAccess.WRITE)
			if output: output.store_string(config_text); output.close(); copied=true
		else: copied=DirAccess.copy_absolute(source,temp)==OK
		if not copied or FileAccess.get_sha256(temp)!=file.sha256 or DirAccess.rename_absolute(temp,destination)!=OK:
			error="无法准备工程资源："+relative; break
		report_progress(progress,"准备素材 %d / %d"%[i+1,files.size()]+"\n"+relative.get_file())
		# Expose the small linked-resource group together, so a cancelled request
		# cannot leave an asset descriptor pointing at an uncopied material/mesh.
		if copy_phase(relative)<2: await controller.get_tree().process_frame
	if not current.call(): return null
	if error.is_empty():
		var resource := await wait_import(str(record.asset),files,current,progress)
		if not current.call(): return null
		if resource is HD2DAsset:
			# Older preset files may not yet contain a library ID. Copy settings in memory only.
			if resource.library_entry_id==&"": resource=resource.duplicate(); resource.library_entry_id=StringName(record.id)
			preload("asset_thumbnails.gd").store_preview(resource,thumbnail(record))
			prepared[key]=resource
			prepared_order.append(key)
			while prepared_order.size()>PREPARED_LIMIT: prepared.erase(prepared_order.pop_front())
		elif error.is_empty(): error="素材依赖未完成导入，无法预览。"
	return prepared.get(key)

func wait_import(path: String, files: Array, current: Callable = Callable(), progress: Callable = Callable()) -> Resource:
	var fs := EditorInterface.get_resource_filesystem()
	# Include the initial busy scan in the deadline; it used to wait forever.
	var started := Time.get_ticks_msec()
	var deadline := started+import_timeout_ms
	var next_scan := started
	var next_progress := started
	var next_probe := started
	var pending := PackedStringArray([path])
	while Time.get_ticks_msec()<deadline:
		if not is_current(current): return null
		await controller.get_tree().process_frame
		if not is_current(current): return null
		if Time.get_ticks_msec()<next_probe: continue
		next_probe=Time.get_ticks_msec()+50
		var ready := not fs.is_scanning() and not fs.is_importing()
		if ready:
			pending.clear()
			for file in files:
				var local := "res://"+str(file.path)
				if local.get_extension() not in ["png","webp","jpg","jpeg","svg","glb","gltf"]: continue
				var dir := fs.get_filesystem_path(local.get_base_dir())
				var i := dir.find_file_index(local.get_file()) if dir else -1
				if i<0 or not dir.get_file_import_is_valid(i): ready=false; pending.append(local); continue
				# The filesystem flag can precede a usable remap after direct file
				# copies. Check the actual cache paths before loading the entry.
				var config := ConfigFile.new()
				var complete := config.load(local+".import")==OK
				var outputs: Variant=config.get_value("deps","dest_files",[]) if complete else []
				complete=complete and not outputs.is_empty()
				for output in outputs: complete=complete and FileAccess.file_exists(str(output))
				if not complete:
					ready=false; pending.append(local)
		if ready and ResourceLoader.exists(path):
			pending=PackedStringArray(Importer.missing_dependencies(path))
			if pending.is_empty(): return load(path)
		if Time.get_ticks_msec()>=next_progress:
			var state := "等待 Godot 扫描／导入（%d 秒）…"%((Time.get_ticks_msec()-started)/1000)
			report_progress(progress,state+"\n"+(pending[0].get_file() if not pending.is_empty() else path.get_file()))
			next_progress=Time.get_ticks_msec()+1000
		if Time.get_ticks_msec()>next_scan and not fs.is_scanning() and not fs.is_importing(): fs.scan(); next_scan=Time.get_ticks_msec()+1000
	error="素材导入超时。请检查 Godot 的输出和导入面板，然后点击重试。"+"\n"+"\n".join(pending.slice(0,5) if not pending.is_empty() else PackedStringArray([path]))
	return null

func import_paths(paths: PackedStringArray, category: String) -> void:
	if controller.import_busy: controller.message("素材正在导入，请等待本批完成。"); return
	controller.import_busy=true
	var report: Array[String]=[controller.i18n.t("导入目标：本机共享素材库")+"\n"+root_path()]
	paths=Importer.collect(paths,report)
	var success := 0; var duplicates := 0; var failed := 0
	var at := root_path()
	for path in paths:
		controller.message("检查并入库："+path.get_file())
		var result := await import_one(path,category,at)
		if result.has("error"): report.append(path+"\n"+controller.i18n.t(result.error)); failed+=1
		elif result.get("duplicate",false): report.append(controller.i18n.t("已有素材，跳过重复：")+path); duplicates+=1
		else: report.append(controller.i18n.t("已添加：")+path); success+=1
	controller.import_busy=false
	var summary := "入库 %d 项；重复 %d 项；失败 %d 项。"%[success,duplicates,failed]
	report.push_front(controller.i18n.t(summary)); controller.last_import_report=report
	controller.ui.update_import_report(report); controller.message(summary)
	controller.ui.preset_panel.reload_catalog()

func closure(path: String, base: String, found: Dictionary) -> bool:
	path=path.simplify_path()
	if found.has(path): return true
	if not FileAccess.file_exists(path): error="缺失依赖："+path; return false
	if not path.begins_with(base+"/"): error="依赖超出素材工程目录："+path; return false
	var relative := path.trim_prefix(base+"/")
	if relative.begins_with("addons/hd2d_scene_tools/"): return true
	var ext := path.get_extension().to_lower()
	if ext in ["gd","cs","gdextension"]: error="含脚本的素材无法确认运行时依赖，请使用原有工程导入："+path; return false
	found[path]=relative
	if ext in ["gltf","glb"]:
		var json_text := FileAccess.get_file_as_string(path) if ext=="gltf" else ""
		if ext=="glb":
			var file := FileAccess.open(path,FileAccess.READ)
			if file.get_32()!=0x46546c67: error="无效 GLB"; return false
			file.get_32(); file.get_32(); var length := file.get_32()
			if file.get_32()!=0x4e4f534a: error="GLB 缺少 JSON 块"; return false
			json_text=file.get_buffer(length).get_string_from_utf8()
		var data: Variant=JSON.parse_string(json_text)
		if not data is Dictionary: error="无效 glTF"; return false
		for item in data.get("buffers",[])+data.get("images",[]):
			var uri: String=item.get("uri","")
			if uri.is_empty() or uri.begins_with("data:"): continue
			if uri.contains(":") or not closure(path.get_base_dir().path_join(uri.uri_decode()),base,found):
				if error.is_empty(): error="不支持远程 glTF 依赖："+uri
				return false
	elif ext in ["tscn","scn","tres","res","gdshader","gdshaderinc"]:
		for entry in ResourceLoader.get_dependencies(path):
			var dependency: String=entry.split("::")[-1]
			if dependency.begins_with("uid://"): error="无法解析 UID 依赖："+dependency; return false
			if dependency.begins_with("res://addons/hd2d_scene_tools/"): continue
			dependency=base.path_join(dependency.trim_prefix("res://")) if dependency.begins_with("res://") else path.get_base_dir().path_join(dependency) if not dependency.is_absolute_path() else dependency
			if not closure(dependency,base,found): return false
	return true

func run_process(arguments: PackedStringArray, deadline_seconds: int) -> bool:
	var pid := OS.create_process(OS.get_executable_path(),arguments,false)
	if pid<0: error="无法启动素材验证进程。"; return false
	var deadline := Time.get_ticks_msec()+deadline_seconds*1000
	while OS.is_process_running(pid):
		if Time.get_ticks_msec()>deadline: OS.kill(pid); error="素材验证超时；已保留暂存文件供检查。"; return false
		await controller.get_tree().create_timer(0.1).timeout
	return true

func copy_tree(from: String, to: String) -> bool:
	var dir := DirAccess.open(from)
	if dir==null: return false
	DirAccess.make_dir_recursive_absolute(to)
	for file in dir.get_files():
		if dir.is_link(file) or DirAccess.copy_absolute(from.path_join(file),to.path_join(file))!=OK: return false
	for child in dir.get_directories():
		if dir.is_link(child) or not copy_tree(from.path_join(child),to.path_join(child)): return false
	return true

func import_one(path: String, category: String, at: String) -> Dictionary:
	error=""
	path=ProjectSettings.globalize_path(path).simplify_path()
	var base := path.get_base_dir()
	var ancestor := base
	while ancestor!="/" and not ancestor.is_empty():
		if FileAccess.file_exists(ancestor.path_join("project.godot")): base=ancestor; break
		ancestor=ancestor.get_base_dir()
	var found := {}
	if not closure(path,base,found): return {"error":error}
	var protect: bool=controller.ui.checked("protect_pixels")
	var hashes := PackedStringArray()
	for file in found:
		hashes.append(FileAccess.get_sha256(file))
		if FileAccess.file_exists(file+".import"):
			var config := ConfigFile.new()
			if config.load(file+".import")!=OK: return {"error":"无法读取素材导入设置："+file}
			var params := {}
			if config.has_section("params"):
				for key in config.get_section_keys("params"): params[key]=config.get_value("params",key)
			if protect and str(file).get_extension().to_lower() in ["png","webp","jpg","jpeg","svg"]: params.merge(PIXEL_PARAMS,true)
			var ordered := {}; var keys := params.keys(); keys.sort()
			for key in keys: ordered[key]=params[key]
			var signature := var_to_str(ordered)
			# Custom import recipes can refer to scripts or resources not declared by
			# the source file. Reject these instead of silently dropping dependencies.
			if signature.contains("res://") or signature.contains("uid://"):
				return {"error":"导入设置含外部资源或脚本；请先在原工程导出自包含 GLB。"}
			# Images deduplicate by source pixels and the selected pixel policy, even
			# when one copy has Godot-generated sidecars and another is an external file.
			if str(file).get_extension().to_lower() not in ["png","webp","jpg","jpeg","svg"]: hashes.append(signature.sha256_text())
	hashes.sort()
	var digest := (FileAccess.get_sha256(path)+"|"+"|".join(hashes)+"|pixels="+str(protect)).sha256_text()
	var existing := read_index(at)
	if existing.is_empty(): return {"error":error}
	for record in existing.entries:
		if record.get("source")=="user" and record.get("content_hash")==digest: return {"record":record,"duplicate":true}
	var id := "user-"+digest.substr(0,32)
	var staging := at.path_join(".staging/"+id+"-"+Crypto.new().generate_random_bytes(6).hex_encode())
	var prefix := "hd2d_imports/shared/"+id+"/"
	DirAccess.make_dir_recursive_absolute(staging)
	var mapping := {}; var files := []
	for from in found:
		var relative: String=found[from]
		var destinations := [staging.path_join(relative)]
		if from.get_extension().to_lower() not in ["tscn","scn","tres","res"]: destinations.append(staging.path_join(prefix+relative))
		for dest in destinations:
			DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
			if DirAccess.copy_absolute(from,dest)!=OK: return {"error":"复制失败："+from}
		if path.get_extension().to_lower() in ["png","webp","jpg","jpeg","svg"] or from.get_extension().to_lower() in ["png","webp","jpg","jpeg","svg"]:
			for relative_image in [relative,prefix+relative]:
				var config := ConfigFile.new()
				if FileAccess.file_exists(from+".import"): config.load(from+".import")
				if config.has_section("remap"): config.erase_section("remap")
				if config.has_section("deps"): config.erase_section("deps")
				config.set_value("remap","importer","texture"); config.set_value("remap","type","CompressedTexture2D")
				if relative_image==relative and FileAccess.file_exists(from+".import"):
					var original_config := ConfigFile.new(); original_config.load(from+".import")
					if original_config.has_section_key("remap","uid"): config.set_value("remap","uid",original_config.get_value("remap","uid"))
				if protect:
					for parameter in PIXEL_PARAMS: config.set_value("params",parameter,PIXEL_PARAMS[parameter])
				config.save(staging.path_join(relative_image)+".import")
		mapping["res://"+relative]="res://"+prefix+relative
		files.append(prefix+relative)
		# Keep pixel/import policy but let the isolated host regenerate cache paths.
		if FileAccess.file_exists(from+".import") and from.get_extension().to_lower() not in ["png","webp","jpg","jpeg","svg"]:
			DirAccess.copy_absolute(from+".import",staging.path_join(relative)+".import")
			var config := ConfigFile.new(); config.load(from+".import")
			for key in ["path","uid","metadata"]:
				if config.has_section_key("remap",key): config.erase_section_key("remap",key)
			if config.has_section("deps"): config.erase_section("deps")
			config.save(staging.path_join(prefix+relative)+".import")
	if not copy_tree(ProjectSettings.globalize_path("res://addons/hd2d_scene_tools"),staging.path_join("addons/hd2d_scene_tools")): return {"error":"无法准备素材验证器。"}
	FileAccess.open(staging.path_join("project.godot"),FileAccess.WRITE).store_string('config_version=5\n[application]\nconfig/name="HD2D Asset Check"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
	var asset_path := "res://"+prefix+"entry.tres"
	write_json(staging.path_join("job.json"),{"id":id,"source":"res://"+found[path],"mapping":mapping,"asset":asset_path,"title":path.get_file().get_basename(),"category":category})
	if not await run_process(["--headless","--path",staging,"--editor","--import","--log-file",staging.path_join("import.log")],90): return {"error":error}
	if not await run_process(["--path",staging,"--minimized","--resolution","320x320","--script","res://addons/hd2d_scene_tools/editor/shared_worker.gd","--log-file",staging.path_join("worker.log")],60): return {"error":error}
	for log_name in ["import.log","worker.log"]:
		var log_text := FileAccess.get_file_as_string(staging.path_join(log_name))
		if log_text.contains("ERROR:") or log_text.contains("SCRIPT ERROR"): return {"error":"素材验证报告错误，请查看："+staging.path_join(log_name)}
	var result: Variant=JSON.parse_string(FileAccess.get_file_as_string(staging.path_join("result.json"))) if FileAccess.file_exists(staging.path_join("result.json")) else null
	if not result is Dictionary: return {"error":"素材验证失败，请查看："+staging}
	if not str(result.get("error","")).is_empty(): return {"error":result.error}
	files.append(prefix+"entry.tres")
	var payload := staging.path_join("payload")
	DirAccess.make_dir_recursive_absolute(payload)
	var manifest := []
	for relative in files:
		var from := staging.path_join(relative)
		var destination := payload.path_join(relative)
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		if DirAccess.copy_absolute(from,destination)!=OK: return {"error":"无法保存依赖："+relative}
		manifest.append({"path":relative,"sha256":FileAccess.get_sha256(destination)})
		# Save only importer parameters with fresh per-project cache names on preparation.
		if FileAccess.file_exists(from+".import"):
			var config := ConfigFile.new(); config.load(from+".import")
			for key in ["path","uid","metadata"]:
				if config.has_section_key("remap",key): config.erase_section_key("remap",key)
			if config.has_section("deps"): config.erase_section("deps")
			config.save(destination+".import")
			manifest.append({"path":relative+".import","sha256":FileAccess.get_sha256(destination+".import")})
	DirAccess.copy_absolute(staging.path_join("thumbnail.png"),payload.path_join("thumbnail.png"))
	var record := {"id":id,"source":"user","title":path.get_file().get_basename(),"category":category,"series":"my-assets","series_title":"我的素材","type":"image" if path.get_extension().to_lower() in ["png","jpg","jpeg","webp","svg"] else "model","asset":asset_path,"content_hash":digest,"payload":"objects/"+id,"files":manifest,"thumbnail":"objects/"+id+"/thumbnail.png"}
	return await commit(record,payload,at)
