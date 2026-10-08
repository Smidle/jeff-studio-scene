@tool
extends EditorPlugin
const DockUI = preload("dock.gd")
const Preview = preload("preview.gd")
const Gizmos = preload("gizmos.gd")
const Inspector = preload("inspector.gd")
const DropSurface = preload("drop_surface.gd")
const LibraryImport = preload("library_import.gd")
var parameters
var shared_library
var terrain_focus
var import_busy := false
var last_import_report: Array[String]=[]
var import_error := ""
var texture_scan_queued := false
var skin
var workbench
var toolbar
var dock: EditorDock
var ui
var stage: HD2DStage
var selection: Node
var active_road: HD2DRoad
var inspector
var gizmos
var preview: Window
var overlays: Array[Control]=[]
var current_tool := "select"
var cursor: MeshInstance3D
var ghost: Node3D
var ghost_asset: HD2DAsset
var last_placed: HD2DProp
var preset_brush_asset: HD2DAsset
var preset_brush_skin: StringName = &""
var stroke := false
var before: Dictionary={}
var stroke_stage: HD2DStage
var last_hit := Vector3.ZERO
var ramp_origin := Vector3.ZERO
var last_time := 0
var last_stamp := Vector3.INF
var rng := RandomNumberGenerator.new()
var external_dirty: Dictionary={}
var qa_runner: RefCounted
var i18n = preload("localization.gd").new()
var palette_drop_completed := false
var last_editor_mouse := Vector2.ZERO
const TERRAIN_TOOLS := ["raise","lower","smooth","flatten","ramp","paint"]
var stroke_rect := Rect2i()
var stroke_indices := {}
var stroke_camera: Camera3D
var stroke_point := Vector2.ZERO
var stroke_hover := false
var stroke_elapsed := 0.0
var world_view_elapsed := 0.0
var world_view_camera: Camera3D

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		_finish_stroke()
		if current_tool in ["village_place","building_place"]: set_tool("select")
	if what==NOTIFICATION_APPLICATION_FOCUS_IN and is_instance_valid(ui) and is_instance_valid(ui.library_connection): ui.library_connection.refresh.call_deferred()

func _process(delta: float) -> void:
	world_view_elapsed+=delta
	if world_view_elapsed>0.25 and is_instance_valid(stage) and stage.terrain() is HD2DWorldMap:
		world_view_elapsed=0
		var camera := world_view_camera
		if not is_instance_valid(camera): camera=EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
		if camera:
			var middle := camera.get_viewport().get_visible_rect().size*0.5
			var hit: Variant=stage.terrain().raycast(camera.project_ray_origin(middle),camera.project_ray_normal(middle))
			if hit is Vector3:
				stage.terrain().focus_point=stage.terrain().to_local(hit)
				stage.terrain().view_radius=clampf(camera.global_position.distance_to(hit)*0.65,45,125)
	if not stroke or current_tool not in TERRAIN_TOOLS: return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): _finish_stroke(); return
	if not stroke_hover or not is_instance_valid(stroke_camera): return
	var container := stroke_camera.get_viewport().get_parent() as Control
	if container and not container.get_global_rect().has_point(last_editor_mouse): return
	stroke_elapsed+=delta
	if stroke_elapsed<0.045: return
	var hit: Variant=pick_world(stroke_camera,stroke_point)
	if hit!=null:
		_stamp(hit,stroke_elapsed)
		show_cursor(hit)
	stroke_elapsed=0.0


func _input(event: InputEvent) -> void:
	if event is InputEventMouse: last_editor_mouse=event.position

func _enter_tree() -> void:
	i18n.load_preference()
	skin=preload("jeff_theme.gd").new();skin.setup(self)
	shared_library=preload("shared_library.gd").new(); shared_library.controller=self
	terrain_focus=preload("terrain_focus.gd").new(); terrain_focus.setup(self)
	ui=DockUI.new()
	ui.setup(self)
	parameters=preload("asset_parameters.gd").new(); parameters.setup(self)
	dock=EditorDock.new()
	dock.title="Jeff Studio 场景"
	dock.layout_key="hd2d_scene_tools"
	dock.default_slot=EditorDock.DOCK_SLOT_RIGHT_UL
	dock.add_child(ui)
	add_dock(dock)
	i18n.watch(ui)
	i18n.bind(dock,"title","Jeff Studio 场景")
	skin.register(ui)
	workbench=preload("asset_workbench.gd").new();workbench.setup(self)
	toolbar=preload("scene_toolbar.gd").new();toolbar.setup(self)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU,toolbar);skin.register(toolbar)
	dock.dock_icon=skin.icons.texture("terrain",skin.palette[2])
	workbench.dock.dock_icon=skin.icons.texture("assets",skin.palette[2])
	inspector=Inspector.new(); inspector.controller=self
	add_inspector_plugin(inspector)
	gizmos=Gizmos.new(); gizmos.controller=self
	add_node_3d_gizmo_plugin(gizmos)
	set_input_event_forwarding_always_enabled()
	scene_changed.connect(_scene_changed)
	EditorInterface.get_selection().selection_changed.connect(_selection_changed)
	_install_overlays.call_deferred()
	_scene_changed(EditorInterface.get_edited_scene_root())
	if "--hd2d-editor-test" in OS.get_cmdline_user_args() and FileAccess.file_exists("res://tools/test_editor.gd"):
		_run_editor_tests.call_deferred()
	if "--hd2d-local-test" in OS.get_cmdline_user_args() and FileAccess.file_exists("res://tools/test_local_editor.gd"):
		_run_local_tests.call_deferred()
	if "--hd2d-music-test" in OS.get_cmdline_user_args() and FileAccess.file_exists("res://tools/test_music_editor.gd"):
		_run_music_tests.call_deferred()
	if "--hd2d-language-test" in OS.get_cmdline_user_args() and FileAccess.file_exists("res://tools/test_localization.gd"):
		_run_language_tests.call_deferred()

func _run_language_tests() -> void:
	qa_runner=load("res://tools/test_localization.gd").new()
	await get_tree().create_timer(1.0).timeout
	qa_runner.run.call_deferred(self)

func _run_music_tests() -> void:
	qa_runner=load("res://tools/test_music_editor.gd").new()
	await get_tree().create_timer(1.0).timeout
	qa_runner.run.call_deferred(self)

func _run_local_tests() -> void:
	qa_runner=load("res://tools/test_local_editor.gd").new()
	await get_tree().create_timer(1.0).timeout
	qa_runner.run.call_deferred(self)

func _run_editor_tests() -> void:
	qa_runner=load("res://tools/test_editor.gd").new()
	await get_tree().create_timer(1.0).timeout
	qa_runner.run.call_deferred(self)

func _exit_tree() -> void:
	if ui and ui.village_panel: ui.village_panel.dispose()
	if ui and ui.character_placement: ui.character_placement.dispose()
	_finish_stroke()
	if ui and ui.terrain_panel:ui.terrain_panel.dispose()
	if is_instance_valid(toolbar):remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU,toolbar);toolbar.queue_free()
	if is_instance_valid(workbench):workbench.dispose()
	if skin:skin.dispose()
	if terrain_focus: terrain_focus.dispose()
	if ui and is_instance_valid(ui.music_panel): ui.music_panel.stop_now()
	if is_instance_valid(preview): preview.stop_music()
	if is_instance_valid(preview): preview.queue_free()
	if ui and is_instance_valid(ui.os_drop_window): ui.os_drop_window.queue_free()
	_clear_cursor()
	for overlay in overlays:
		if is_instance_valid(overlay): overlay.queue_free()
	if EditorInterface.get_selection().selection_changed.is_connected(_selection_changed): EditorInterface.get_selection().selection_changed.disconnect(_selection_changed)
	remove_inspector_plugin(inspector)
	remove_node_3d_gizmo_plugin(gizmos)
	remove_dock(dock)
	dock.queue_free()

func _install_overlays() -> void:
	for i in range(4):
		var viewport := EditorInterface.get_editor_viewport_3d(i)
		if viewport==null or not viewport.get_parent() is Control: continue
		var overlay := DropSurface.new()
		overlay.controller=self; overlay.target_viewport=viewport
		overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
		viewport.get_parent().add_child(overlay)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlays.append(overlay)

func _handles(object: Object) -> bool: return object is Node3D
func _edit(object: Object) -> void:
	if object is Node: selection=object
	if object is HD2DRoad: active_road=object

func _scene_changed(scene_root: Node) -> void:
	if ui and ui.character_placement: ui.character_placement.context_changed()
	if ui and ui.village_panel: ui.village_panel.context_changed()
	if is_instance_valid(workbench):workbench.scene_changed()
	_finish_stroke()
	if terrain_focus: terrain_focus.set_enabled(false)
	last_placed=null
	if ui and ui.controls.has("edit_last"): ui.controls.edit_last.disabled=true
	preset_brush_asset=null; preset_brush_skin=&""
	if ui and is_instance_valid(ui.music_panel): ui.music_panel.stop_now()
	if is_instance_valid(preview):
		preview.stop_music()
		preview.queue_free()
	_clear_cursor()
	stage=_find_stage(scene_root)
	selection=null; active_road=null
	if parameters: parameters.select_prop(null)
	if ui:
		ui.status.hide()
		if ui.camera_panel: ui.camera_panel.sync_target()
		# A search belongs to the previous editing context, not the new scene's library.
		ui.search.clear()
		ui.category_filter.select(0)
		ui.selected_asset=null
		ui.asset_region_preview.texture=null
		ui.asset_region_preview.queue_redraw()
		if stage: ui.sync_stage()
		else:
			ui.refresh_library()
			ui.music_panel.sync_stage()
		if is_instance_valid(ui.preset_panel): ui.preset_panel.refresh_impact()
		ui.terrain_panel.sync_target()

func _find_stage(node: Node) -> HD2DStage:
	if node==null: return null
	if node is HD2DStage: return node
	for child in node.get_children():
		var found := _find_stage(child)
		if found: return found
	return null

func _selection_changed() -> void:
	var nodes := EditorInterface.get_selection().get_selected_nodes()
	if not nodes.is_empty(): select_context(nodes[0])
	else:
		selection=null; active_road=null
		parameters.select_prop(null)
	if nodes.size()!=1: parameters.select_prop(null)

func select_context(object: Object) -> void:
	if not object is Node: return
	selection=object
	if object is HD2DRoad: active_road=object
	var ancestor: Node=object
	while ancestor:
		if ancestor is HD2DStage:
			if stage!=ancestor and ui and ui.village_panel: ui.village_panel.context_changed()
			if stage!=ancestor and ui and ui.character_placement: ui.character_placement.context_changed()
			stage=ancestor
			if ui:
				ui.sync_stage()
				var prop: Node=object
				while prop and not prop is HD2DProp: prop=prop.get_parent()
				parameters.select_prop(prop as HD2DProp)
			return
		ancestor=ancestor.get_parent()
	parameters.select_prop(null)

func current_character() -> HD2DCharacter:
	if is_instance_valid(selection) and selection is HD2DCharacter: return selection
	return stage.character() if is_instance_valid(stage) else null

func require_stage() -> bool:
	if is_instance_valid(stage): return true
	message("请先新建 HD2D 模板，或选中包含 HD2DStage 的场景。")
	return false

func message(text: String) -> void:
	if ui:
		i18n.text(ui.status,text)
		ui.status.visible=not text.begins_with("工具：")
		ui.status.tooltip_text=i18n.t(text)

func mark_changed() -> void:
	if ui and ui.terrain_panel and ui.terrain_panel.guide: ui.terrain_panel.guide.invalidate()
	EditorInterface.mark_scene_as_unsaved()
	if is_instance_valid(stage) and stage.terrain():
		var resource := stage.terrain().data
		if not resource.resource_path.is_empty() and not resource.resource_path.contains("::"): external_dirty[resource]=true

func _get_unsaved_status(_for_scene: String) -> String:
	return i18n.t("Jeff Studio 有未保存的外部资源（地形 / 素材）。") if not external_dirty.is_empty() else ""

func _save_external_data() -> void:
	for resource in external_dirty.keys():
		if ResourceSaver.save(resource)==OK: external_dirty.erase(resource)
		else: push_error(i18n.t("HD2D 无法保存："+resource.resource_path))

func create_template(loop: bool) -> bool:
	var meters: float = ui.terrain_panel.map_meters()
	var samples: int = ui.terrain_panel.map_samples()
	var fresh := HD2DFactory.create_stage(loop,meters,samples)
	var preset: Dictionary=ui.terrain_panel.template_preset
	if not preset.is_empty():
		fresh.terrain().data.layer_count=preset.textures.size()
		fresh.terrain().data.ensure_extra_weights()
		fresh.terrain().data.textures.assign(preset.textures)
		fresh.terrain().data.layer_names=preset.layer_names.duplicate()
		fresh.terrain().data.layer_preset_ids=preset.layer_preset_ids.duplicate()
		fresh.terrain().data.texture_scale=preset.texture_scale
	HD2DTerrainTemplates.populate(fresh,ui.terrain_panel.map_landform(),ui.checked("terrain_create_liquid"),ui.value("terrain_liquid_speed"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://levels"))
	var base := "res://levels/LoopStage" if loop else "res://levels/FreeWalk"
	var path := unique_path(base+".tscn")
	var saved := ResourceSaver.save(fresh.terrain().data,path.get_basename()+"_terrain.res",ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_CHANGE_PATH)
	if saved!=OK: fresh.free(); message("创建失败："+error_string(saved)); return false
	fresh.terrain().data=load(path.get_basename()+"_terrain.res")
	if fresh.terrain().data==null: fresh.free(); message("无法重新加载新建地形资源。"); return false
	var packed := PackedScene.new()
	var error := packed.pack(fresh)
	if error==OK: error=ResourceSaver.save(packed,path)
	fresh.free()
	if error!=OK: message("创建失败："+error_string(error)); return false
	EditorInterface.get_resource_filesystem().scan()
	EditorInterface.open_scene_from_path(path)
	EditorInterface.set_main_screen_editor("3D")
	message("已创建："+path+"。先导入角色与植物。")
	return true

func unique_path(path: String) -> String:
	var output := path
	var index := 2
	while FileAccess.file_exists(output) or (path.get_extension()=="tscn" and FileAccess.file_exists(output.get_basename()+"_terrain.res")):
		output=path.get_basename()+"_%d."%index+path.get_extension()
		index+=1
	return output

func project_resource(path: String) -> Resource:
	import_error=""
	var local := ProjectSettings.localize_path(path)
	if not FileAccess.file_exists(path):
		import_error="缺失文件："+path
		message(import_error); return null
	if not local.begins_with("res://"):
		# glTF/text .tscn/.tres can reference siblings: avoid copying a broken dependency graph.
		if path.get_extension().to_lower() in ["gltf","tscn","tres","scn","res"]:
			import_error="此格式可能引用旁边的文件。请先把它和依赖目录一起放入工程，再从工程内导入。GLB / PNG 可直接复制。"
			message(import_error)
			return null
		# Reuse identical external content. Different content with the same name still
		# goes through unique_path; never overwrite a user's existing import.
		var digest := FileAccess.get_sha256(path)
		var imports := DirAccess.open("res://hd2d_imports")
		if imports and not digest.is_empty():
			for name in imports.get_files():
				var existing := "res://hd2d_imports/"+name
				if name.get_extension().to_lower()==path.get_extension().to_lower() and FileAccess.get_sha256(existing)==digest and ResourceLoader.exists(existing):
					return load(existing)
		var filesystem := EditorInterface.get_resource_filesystem()
		while filesystem.is_scanning() or filesystem.is_importing(): await get_tree().process_frame
		# Register the destination directory BEFORE copying. The empty-directory
		# scan cannot start this file's import. Afterwards a native scan owns it;
		# never combine scan + manual reimport for the same new file.
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://hd2d_imports"))
		if filesystem.get_filesystem_path("res://hd2d_imports")==null:
			filesystem.scan()
			# is_scanning can turn false before the pending directory changes are
			# published. Wait for the directory itself, not only the worker flag.
			var deadline := Time.get_ticks_msec()+15000
			var retry_at := Time.get_ticks_msec()+500
			while filesystem.get_filesystem_path("res://hd2d_imports")==null or filesystem.is_scanning() or filesystem.is_importing():
				if Time.get_ticks_msec()>deadline:
					message("导入目录尚未登记完成，请等待文件系统扫描结束后重试。")
					return null
				if Time.get_ticks_msec()>=retry_at and not filesystem.is_scanning() and not filesystem.is_importing():
					filesystem.scan()
					retry_at=Time.get_ticks_msec()+1000
				await get_tree().create_timer(0.05).timeout
		local=unique_path("res://hd2d_imports/"+path.get_file())
		var err := DirAccess.copy_absolute(path,ProjectSettings.globalize_path(local))
		if err!=OK: message("复制失败："+error_string(err)); return null
		# Let one native scan own this new file's import. update_file + explicit
		# reimport could reenter the same ProgressDialog task during UI callbacks.
		filesystem.scan()
		var import_deadline := Time.get_ticks_msec()+45000
		var next_scan := Time.get_ticks_msec()+500
		while true:
			var directory := filesystem.get_filesystem_path(local.get_base_dir())
			var index := directory.find_file_index(local.get_file()) if directory else -1
			if not filesystem.is_scanning() and not filesystem.is_importing() and index>=0 and directory.get_file_import_is_valid(index) and ResourceLoader.exists(local): break
			if Time.get_ticks_msec()>import_deadline:
				message("音频 / 图片仍在导入或导入失败，请查看 Godot 导入面板后重试："+local)
				return null
			# scan() may silently ignore a call while its finished worker has not
			# been joined, even though is_scanning() is already false. A directory
			# entry can also arrive before its pending import action. Retry the
			# native scan while not yet loadable, never compete with manual import.
			if Time.get_ticks_msec()>=next_scan and not filesystem.is_scanning() and not filesystem.is_importing():
				filesystem.scan()
				next_scan=Time.get_ticks_msec()+1000
			await get_tree().create_timer(0.05).timeout
	if ResourceLoader.exists(local):
		var missing := LibraryImport.missing_dependencies(local)
		if not missing.is_empty():
			import_error="缺失依赖："+"\n".join(missing)
			message(import_error); return null
		return load(local)
	message("资源正在导入，请稍后从工程文件系统中再次选择："+local)
	return null

func import_assets(paths: PackedStringArray, category: String) -> void:
	if ui.controls.import_target.selected==0:
		await shared_library.import_paths(paths,category); return
	if not require_stage(): return
	if import_busy: message("素材正在导入，请等待本批完成。"); return
	import_busy=true
	last_import_report.clear()
	last_import_report.append(i18n.t("导入目标：当前场景 → 素材库与摆放"))
	paths=LibraryImport.collect(paths,last_import_report)
	for i in range(last_import_report.size()): last_import_report[i]=i18n.t(last_import_report[i])
	var destination := stage
	var original_library := stage.library
	var library := stage.library.duplicate() as HD2DAssetLibrary if stage.library else HD2DAssetLibrary.new()
	library.assets=library.assets.duplicate()
	var added := 0
	for path in paths:
		var resource := await project_resource(path)
		if not is_instance_valid(destination) or stage!=destination:
			message("导入期间切换了场景：素材已复制，但没有写入其他场景。请重新导入。")
			import_busy=false
			return
		if not(resource is Texture2D or resource is Mesh or resource is PackedScene):
			last_import_report.append(path+"\n"+(import_error if not import_error.is_empty() else i18n.t("仅支持图片、3D 场景或网格；角色 SpriteFrames 请到角色页导入。")))
			continue
		if resource is PackedScene:
			var probe: Node=(resource as PackedScene).instantiate()
			var is_3d := probe is Node3D
			probe.free()
			if not is_3d: last_import_report.append(i18n.t("不是 3D 场景：")+path); continue
		var duplicate := false
		for existing in library.assets:
			if existing and existing.source_path==resource.resource_path: duplicate=true; break
		if duplicate:
			last_import_report.append(i18n.t("已有素材，跳过重复：")+path); continue
		if resource is Texture2D and ui.checked("protect_pixels"): _protect_texture(resource)
		var asset := HD2DAsset.new()
		# Keep the Resource's legacy default for old flower scenes; new imports are rigid.
		asset.wind=0.0
		asset.library_entry_id=HD2DAsset.new_entry_id()
		asset.source=resource; asset.source_path=resource.resource_path
		asset.title=path.get_file().get_basename(); asset.category=category if not category.is_empty() else "未分类"
		var original_title := asset.title
		var suffix := 2
		while library.assets.any(func(item): return item and item.title==asset.title):
			asset.title=original_title+" (%d)"%suffix; suffix+=1
		if resource is Texture2D: asset.card_size=Vector2(float(resource.get_width())/resource.get_height()*2,2)
		asset.enable_default_collision()
		library.assets.append(asset)
		last_import_report.append(i18n.t("已添加：")+asset.title+" → "+asset.source_path)
		added+=1
	import_busy=false
	if destination.library!=original_library:
		message("导入期间素材库已改变，本批未写入；文件已保留，可重新导入。")
		return
	if added>0:
		set_properties(stage,{"library":library},"导入 HD2D 素材")
		ui.search.clear()
		ui.category_filter.select(0)
		ui.refresh_library(true)
		ui.select_library_asset(library.assets[-1])
	message("新增 %d 个素材；跳过与错误见“导入结果”。"%added)
	ui.update_import_report(last_import_report)

func duplicate_asset(asset: HD2DAsset) -> void:
	if not require_stage() or asset==null or not stage.library.assets.has(asset): return
	var copy := asset.duplicate() as HD2DAsset
	copy.title=asset.title+" (copy)"
	copy.library_entry_id=HD2DAsset.new_entry_id()
	var library := stage.library.duplicate() as HD2DAssetLibrary
	library.assets=library.assets.duplicate(); library.assets.append(copy)
	set_properties(stage,{"library":library},"复制素材条目")
	ui.search.clear(); ui.refresh_library(true); ui.select_library_asset(copy)

func relink_asset(asset: HD2DAsset, path: String) -> void:
	if not require_stage() or asset==null: return
	if str(asset.library_entry_id).begins_with("preset-"): message("预设条目只读；请先复制为新条目。"); return
	var destination := stage
	var source := await project_resource(path)
	if not is_instance_valid(destination) or stage!=destination or not stage.library.assets.has(asset): return
	if not(source is Texture2D or source is Mesh or source is PackedScene): return
	if source is PackedScene:
		var probe: Node=(source as PackedScene).instantiate()
		var is_3d := probe is Node3D; probe.free()
		if not is_3d: message("不是 3D 场景："+path); return
	# New source may have a different layout: do not retain an invalid crop/animation.
	set_properties(asset,{"source":source,"source_path":source.resource_path,"thumbnail":null,"texture_region":Rect2i(),"animate_sheet":false},"重新关联素材")
	ui.select_library_asset(asset)

func inspect_library() -> void:
	if not require_stage(): return
	var report: Array[String]=[]
	if stage.library:
		for asset in stage.library.assets:
			if asset==null: report.append(i18n.t("空素材条目；请在 Inspector 检查素材库。")); continue
			if asset.source_missing(): report.append(asset.title+" · "+i18n.t("资源缺失，请先重新关联文件。")+"\n"+asset.source_path)
			for path in LibraryImport.missing_dependencies(asset.source_path): report.append(asset.title+" → "+path)
	if report.is_empty(): report.append(i18n.t("素材与已声明依赖检查通过。未检查脚本运行时拼接的路径。"))
	ui.update_import_report(report)
	ui.show_import_report()

func remove_asset(asset: HD2DAsset) -> void:
	if not require_stage() or asset==null: return
	var library := stage.library.duplicate() as HD2DAssetLibrary
	library.assets=library.assets.duplicate(); library.assets.erase(asset)
	set_properties(stage,{"library":library},"移除素材条目")
	ui.selected_asset=null
	ui.refresh_library(true)

func apply_asset_settings(_asset: HD2DAsset) -> void:
	parameters.apply_single()

func apply_entry_settings(asset: HD2DAsset) -> void:
	if not require_stage() or asset==null or stage.library==null or not stage.library.assets.has(asset): return
	if not asset.library_entry_id.is_empty() and str(asset.library_entry_id).begins_with("preset-"):
		message("预设条目只读；请先复制为新条目。"); return
	var title: String=ui.controls.asset_title.text.strip_edges()
	if title.is_empty(): message("素材名称不能为空。"); return
	set_properties(asset,{"title":title,"category":ui.controls.asset_category.text.strip_edges()},"保存条目名称与分类")

func scene_assets() -> Array:
	var result: Array=[]
	if not is_instance_valid(stage): return result
	if stage.library: result.assign(stage.library.assets)
	_collect_associated_assets(stage,result)
	return result

func _collect_associated_assets(node: Node, result: Array) -> void:
	if node is HD2DProp:
		if node.asset and not result.any(func(item): return item and node.asset.same_entry(item)): result.append(node.asset)
		return
	if node is HD2DFoliage:
		for record in node.records:
			var asset: HD2DAsset=record.get("asset")
			if asset and not result.any(func(item): return item and asset.same_entry(item)): result.append(asset)
		return
	for child in node.get_children(): _collect_associated_assets(child,result)

func set_properties(object: Object, values: Dictionary, title: String) -> void:
	if not require_stage(): return
	var undo := get_undo_redo()
	undo.create_action(i18n.t(title),UndoRedo.MERGE_DISABLE,stage)
	for key in values:
		undo.add_do_property(object,key,values[key])
		undo.add_undo_property(object,key,object.get(key))
	undo.add_do_method(self,"refresh",object)
	undo.add_undo_method(self,"refresh",object)
	undo.commit_action()
	mark_changed()

func refresh(object: Object) -> void:
	if not is_instance_valid(object): return
	if object is Resource:
		var file: String=object.resource_path.get_slice("::",0)
		if not file.is_empty() and file.get_extension() in ["tres","res"]:
			var container := load(file)
			if container: external_dirty[container]=true
	if object is HD2DStage: object.refresh()
	elif object is HD2DRoad: object.rebuild()
	elif object is HD2DCharacter: object.rebuild()
	elif object is HD2DCameraRig: object.reset_view()
	elif object is HD2DTerrainData:
		object.emit_changed()
	elif object is HD2DAsset:
		object.emit_changed()
		if stage and stage.foliage(): stage.foliage().rebuild()
		if ui: ui.select_library_asset(object)
	if ui and stage: ui.sync_stage()

func set_tool(tool: String) -> void:
	if tool!="building_place" and is_instance_valid(workbench) and is_instance_valid(workbench.buildings): workbench.buildings.end_placement()
	if tool!="village_place" and ui and ui.village_panel and ui.village_panel.placement:
		ui.village_panel.placement.stop()
	_finish_stroke()
	if tool in ["raise","lower","smooth","flatten","ramp","paint"] and not require_terrain():
		tool="select"
	if tool=="paint" and (ui.terrain_panel.is_dirty() or (stage and stage.terrain() and stage.terrain().surface_material)):
		message("请先应用地表设置，或预览并改用四层地表。"); return
	current_tool=tool
	ui.terrain_panel.refresh_status()
	for key in ui.tool_buttons: ui.tool_buttons[key].set_pressed_no_signal(key==tool)
	if tool=="select": hide_cursor()
	else:
		message("工具："+tool+" · 左键操作 / Esc 退出 / Cmd+Z 撤销")
		EditorInterface.set_main_screen_editor("3D")

func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	world_view_camera=camera
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
		set_tool("select")
		return AFTER_GUI_INPUT_STOP
	if current_tool=="building_place": return workbench.buildings.handle_input(camera,event)
	if current_tool=="village_place": return ui.village_panel.placement.handle_input(camera,event)
	if current_tool=="select" or not is_instance_valid(stage): return AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_stroke()
		return AFTER_GUI_INPUT_STOP
	if not(event is InputEventMouseMotion or event is InputEventMouseButton): return AFTER_GUI_INPUT_PASS
	if event.alt_pressed or (event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_RIGHT):
		stroke_hover=false; return AFTER_GUI_INPUT_PASS
	stroke_camera=camera; stroke_point=event.position; stroke_hover=true
	var hit: Variant=pick_world(camera,event.position)
	if hit==null: stroke_hover=false; hide_cursor(); return AFTER_GUI_INPUT_PASS
	last_hit=hit
	show_cursor(hit)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if current_tool=="place": place_asset(placement_asset(),hit); return AFTER_GUI_INPUT_STOP
		if current_tool=="character_place":
			ui.character_placement.place_at(hit);return AFTER_GUI_INPUT_STOP
		if current_tool=="hero":
			var hero := current_character()
			if hero: set_properties(hero,{"position":hero.get_parent().to_local(hit)+Vector3.UP*0.03},"放置角色")
			return AFTER_GUI_INPUT_STOP
		if current_tool=="road": add_road_point(hit); return AFTER_GUI_INPUT_STOP
		_begin_stroke(hit)
		_stamp(hit,1.0/60.0 if current_tool in TERRAIN_TOOLS else 0.12)
		if current_tool=="area": _finish_stroke()
		return AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion and stroke:
		if current_tool in TERRAIN_TOOLS: return AFTER_GUI_INPUT_STOP
		var now := Time.get_ticks_msec()
		if now-last_time>=45:
			_stamp(hit,minf((now-last_time)/1000.0,0.15))
			last_time=now
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS

func pick_world(camera: Camera3D, point: Vector2) -> Variant:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	# Terrain tools always author the selected heightfield, even over collidable props.
	if current_tool in TERRAIN_TOOLS and stage.terrain(): return stage.terrain().raycast(origin,direction)
	# Prefer actual static surfaces for placement.
	var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*1500)
	if current_tool=="character_place":
		query.collision_mask=1
		var excluded: Array[RID]=[]
		for actor in stage.characters():excluded.append(actor.get_rid())
		query.exclude=excluded
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty() and not stroke: return result.position
	if stage.terrain(): return stage.terrain().raycast(origin,direction)
	return Plane(Vector3.UP,0).intersects_ray(origin,direction)

func show_cursor(hit: Vector3) -> void:
	if not is_instance_valid(cursor):
		cursor=MeshInstance3D.new()
		cursor.name="HD2D_BrushPreview"
		cursor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stage.add_child(cursor)
		var mat := StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color=Color(0.3,1,0.7)
		mat.no_depth_test=true
		cursor.material_override=mat
	var radius: float = ui.value("scatter_radius") if current_tool in ["scatter","area","erase"] else ui.value("radius")
	if current_tool=="paint": radius=ui.value("paint_radius")
	if current_tool in ["place","hero","character_place","road"]: radius=0.35
	var line := ImmediateMesh.new()
	line.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(64):
		for angle in [float(i)/64*TAU,float(i+1)/64*TAU]:
			var p := hit+Vector3(cos(angle)*radius,0,sin(angle)*radius)
			if stage.terrain(): p.y=stage.terrain().world_height(p.x,p.z)+0.08
			line.surface_add_vertex(stage.to_local(p))
	line.surface_end()
	cursor.mesh=line
	cursor.show()
	if current_tool=="place" and placement_asset(): _show_ghost(placement_asset(),hit)

func _show_ghost(asset: HD2DAsset, hit: Vector3) -> void:
	if asset.source_missing(): hide_cursor(); return
	if not is_instance_valid(ghost) or ghost_asset!=asset:
		if is_instance_valid(ghost): ghost.queue_free()
		var copy := asset.duplicate() as HD2DAsset
		copy.static_collision=false
		ghost=Node3D.new()
		ghost.add_child(copy.make_node(placement_skin(asset)))
		_disable_ghost_collision(ghost)
		stage.add_child(ghost)
		var effective: HD2DAsset=asset.with_overrides(asset.placement_collision_overrides())
		if effective.static_collision and ui.checked("collision_preview"):
			var mesh := ImmediateMesh.new()
			var mat := StandardMaterial3D.new()
			mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color=Color(0.2,1,0.5); mat.no_depth_test=true
			mesh.surface_begin(Mesh.PRIMITIVE_LINES)
			for part in effective.collision_parts():
				var lines: ArrayMesh=part.shape.get_debug_mesh()
				if lines==null or lines.get_surface_count()==0: continue
				var points: PackedVector3Array=lines.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				for point in points: mesh.surface_add_vertex(part.transform*point)
			mesh.surface_end()
			var outline := MeshInstance3D.new(); outline.mesh=mesh; outline.material_override=mat
			ghost.add_child(outline)
		ghost_asset=asset
	ghost.global_position=hit
	ghost.show()

func _disable_ghost_collision(node: Node) -> void:
	if node is CollisionObject3D:
		node.collision_layer=0; node.collision_mask=0; node.input_ray_pickable=false
	for child in node.get_children(): _disable_ghost_collision(child)

func hide_cursor() -> void:
	if is_instance_valid(cursor): cursor.hide()
	if is_instance_valid(ghost): ghost.hide()

func _clear_cursor() -> void:
	if is_instance_valid(cursor): cursor.queue_free()
	if is_instance_valid(ghost): ghost.queue_free()
	cursor=null; ghost=null; ghost_asset=null

func show_drop_preview(viewport: SubViewport, point: Vector2, data: Dictionary) -> void:
	if not require_stage(): return
	var hit: Variant=pick_world(viewport.get_camera_3d(),point)
	if hit==null: hide_cursor(); return
	if data.has("hd2d_asset"): _show_ghost(data.hd2d_asset,hit)
	else: show_cursor(hit)

func drop_asset(viewport: SubViewport, point: Vector2, data: Dictionary) -> void:
	if not require_stage(): return
	var hit: Variant=pick_world(viewport.get_camera_3d(),point)
	if hit==null: message("没有有效落点，请朝地面拖放。"); return
	var asset: HD2DAsset=data.get("hd2d_asset")
	if asset==null and data.has("files"):
		var resource := await project_resource(data.files[0])
		if resource is Texture2D or resource is Mesh or resource is PackedScene:
			asset=HD2DAsset.new(); asset.source=resource; asset.title=resource.resource_path.get_file().get_basename(); asset.source_path=resource.resource_path
			asset.wind=0.0
	place_asset(asset,hit)
	palette_drop_completed=true
	hide_cursor()

func finish_palette_drag(asset: HD2DAsset) -> void:
	# Native 3D editor event surfaces may sit above a dock plugin's drop Control.
	# Only our own palette drags use this fallback, only inside a visible 3D viewport.
	if palette_drop_completed or not is_instance_valid(stage): return
	for i in range(4):
		var viewport := EditorInterface.get_editor_viewport_3d(i)
		var container := viewport.get_parent() as Control
		if not container.is_visible_in_tree(): continue
		var local := last_editor_mouse-container.global_position
		if Rect2(Vector2.ZERO,container.size).has_point(local):
			drop_asset(viewport,local*Vector2(viewport.size)/container.size,{"hd2d_asset":asset})
			break

func place_asset(asset: HD2DAsset, hit: Vector3, world_basis: Variant=null, skin_override: Variant=null) -> void:
	if asset==null: message("请先在素材库选择一个素材。"); return
	if not require_stage(): return
	if asset.source_missing(): message("资源缺失，请先重新关联文件。"); return
	var node := HD2DProp.new()
	node.asset=asset
	node.asset_overrides=asset.placement_collision_overrides()
	node.skin_id=StringName(skin_override) if skin_override!=null else placement_skin(asset)
	node.name=asset.title.validate_node_name()
	var parent := stage.get_node("Scenery")
	node.position=parent.to_local(hit)
	if world_basis is Basis: node.basis=parent.global_basis.inverse()*world_basis
	var undo := get_undo_redo()
	undo.create_action(i18n.t("放置 "+asset.title),UndoRedo.MERGE_DISABLE,stage)
	if stage.library==null or not stage.library.assets.any(func(item): return item and asset.same_entry(item)):
		var library := stage.library.duplicate() as HD2DAssetLibrary if stage.library else HD2DAssetLibrary.new()
		library.assets=library.assets.duplicate(); library.assets.append(asset)
		undo.add_do_property(stage,"library",library)
		undo.add_undo_property(stage,"library",stage.library)
	undo.add_do_method(self,"refresh_scene_assets")
	undo.add_undo_method(self,"refresh_scene_assets")
	undo.add_do_method(parent,"add_child",node,true)
	undo.add_do_method(self,"_own_recursive",node,EditorInterface.get_edited_scene_root())
	undo.add_undo_method(parent,"remove_child",node)
	undo.add_do_reference(node)
	undo.commit_action()
	ui.refresh_library(true)
	last_placed=node;ui.controls.edit_last.disabled=false
	message("已摆放：%s。可继续摆放，或点击“编辑刚放置物件”修改参数。"%asset.title)
	mark_changed()

func edit_last_placed() -> void:
	if not is_instance_valid(last_placed) or not last_placed.is_inside_tree():
		ui.controls.edit_last.disabled=true;return
	parameters.focus_instance(last_placed)

func refresh_scene_assets() -> void:
	if ui: ui.refresh_library.call_deferred(true)

func placement_asset() -> HD2DAsset:
	# Generic library refresh must not clear an independently chosen preset.
	return preset_brush_asset if preset_brush_asset else ui.selected_asset

func placement_skin(asset: HD2DAsset) -> StringName:
	return preset_brush_skin if asset and asset==preset_brush_asset else &""

func _own_recursive(node: Node, scene_owner: Node) -> void:
	node.owner=scene_owner
	if node is HD2DProp: return
	for child in node.get_children(): _own_recursive(child,scene_owner)

func _begin_stroke(hit: Vector3) -> void:
	if not stage: return
	if current_tool in TERRAIN_TOOLS and not require_terrain(): return
	if current_tool not in TERRAIN_TOOLS and not stage.foliage(): return
	stroke=true; stroke_stage=stage
	stroke_rect=Rect2i(); stroke_indices={}; stroke_elapsed=0.0
	last_time=Time.get_ticks_msec(); last_stamp=Vector3.INF
	ramp_origin=stage.terrain().to_local(hit) if stage.terrain() else hit
	before={"tool":current_tool}
	if current_tool not in TERRAIN_TOOLS:
		rng.seed=int(ui.value("seed"))+stage.foliage().records.size()
		before.merge({"library":stage.library,"foliage":stage.foliage().records.duplicate(true)})

func _stamp(hit: Vector3, dt: float) -> void:
	if not stroke: return
	if current_tool in TERRAIN_TOOLS:
		var terrain := stage.terrain()
		var paint := current_tool=="paint"
		var radius: float=ui.value("paint_radius" if paint else "radius")
		var strength: float=ui.value("paint_strength" if paint else "strength")
		var rect := terrain.data.brush(terrain.to_local(hit),radius,strength*dt,current_tool,ui.controls.layer.selected,ui.value("level"),ramp_origin,stroke_indices)
		if not rect.has_area(): return
		stroke_rect=stroke_rect.merge(rect) if stroke_rect.has_area() else rect
		if paint: terrain.update_weights_region(rect)
		else: terrain.rebuild_region(rect,false)

	elif current_tool in ["scatter","area","erase"]:
		var plants := stage.foliage()
		var radius: float = ui.value("scatter_radius")
		if current_tool=="erase": plants.erase(plants.to_local(hit),radius)
		else:
			if last_stamp!=Vector3.INF and hit.distance_to(last_stamp)<maxf(radius*0.15,0.2): return
			var count := maxi(1,int(PI*radius*radius*ui.value("density")*(1.0 if current_tool=="area" else 0.15)))
			plants.scatter(plants.to_local(hit),radius,mini(count,12000),ui.palette(),stage.terrain(),rng,Vector2(minf(ui.value("scale_min"),ui.value("scale_max")),maxf(ui.value("scale_min"),ui.value("scale_max"))),Vector2(ui.value("yaw_min"),ui.value("yaw_max")),stage.roads(),ui.value("road_margin"),placement_skin(placement_asset()),true)
		plants.rebuild()
		last_stamp=hit

func _finish_stroke() -> void:
	if not stroke: return
	stroke=false; stroke_hover=false
	if not is_instance_valid(stroke_stage): return
	var target := stroke_stage
	if before.tool in TERRAIN_TOOLS:
		var previous := {}; var following := {}
		var terrain := target.terrain()
		if terrain==null: return
		var paint: bool=before.tool=="paint"
		for index in stroke_indices:
			var value: Variant=terrain.data.weight_sample(index) if paint else terrain.data.heights[index]
			if value!=stroke_indices[index]: previous[index]=stroke_indices[index]; following[index]=value
		if previous.is_empty(): return
		var old_scenery := {}; var new_scenery := {}
		if not paint:
			terrain.update_collision_region(stroke_rect)
			if ui.checked("terrain_auto_conform"):
				var conformed := conform_target(target,stroke_rect)
				old_scenery=conformed[0];new_scenery=conformed[1]
		var undo := get_undo_redo()
		undo.create_action(i18n.t("绘制地表" if paint else "雕刻地形"),UndoRedo.MERGE_DISABLE,target)
		undo.add_do_method(self,"restore_terrain_patch",target,following,stroke_rect,paint,new_scenery)
		undo.add_undo_method(self,"restore_terrain_patch",target,previous,stroke_rect,paint,old_scenery)
		undo.commit_action(false)
		mark_changed(); return
	if before.tool in ["scatter","area"]:
		var library := target.library.duplicate() as HD2DAssetLibrary if target.library else HD2DAssetLibrary.new()
		library.assets=library.assets.duplicate()
		for record in target.foliage().records.slice(before.foliage.size()):
			var asset: HD2DAsset=record.get("asset")
			if asset and not library.assets.any(func(item): return item and asset.same_entry(item)): library.assets.append(asset)
		if target.library==null or library.assets.size()!=target.library.assets.size(): target.library=library
	var after := {"library":target.library,"foliage":target.foliage().records.duplicate(true),"tool":before.tool}
	var undo := get_undo_redo()
	undo.create_action(i18n.t("HD2D 笔刷拖动"),UndoRedo.MERGE_DISABLE,target)
	undo.add_do_method(self,"restore_stroke",target,after)
	undo.add_undo_method(self,"restore_stroke",target,before)
	undo.commit_action(false)
	refresh_scene_assets(); mark_changed()

func restore_terrain_patch(target: HD2DStage, values: Dictionary, rect: Rect2i, paint: bool, scenery: Dictionary) -> void:
	if ui and ui.terrain_panel and ui.terrain_panel.guide: ui.terrain_panel.guide.invalidate()
	if not is_instance_valid(target) or not target.terrain(): return
	var terrain := target.terrain()
	for index in values:
		if paint: terrain.data.set_weight_sample(index,values[index])
		else: terrain.data.heights[index]=values[index]
	if paint: terrain.update_weights_region(rect)
	else: terrain.rebuild_region(rect,true)
	if not scenery.is_empty(): restore_conform(target,scenery)
	if not terrain.data.resource_path.is_empty() and not terrain.data.resource_path.contains("::"): external_dirty[terrain.data]=true
	EditorInterface.mark_scene_as_unsaved()

func restore_stroke(target: HD2DStage, state: Dictionary) -> void:
	if not is_instance_valid(target): return
	if state.has("library"): target.library=state.library
	if target.foliage(): target.foliage().restore(state.foliage)
	refresh_scene_assets(); EditorInterface.mark_scene_as_unsaved()

func capture_conform(target: HD2DStage) -> Dictionary:
	var positions := PackedVector3Array()
	if target.foliage():
		for record in target.foliage().records: positions.append(record.position)
	var roads := []
	for road in target.roads():
		var parts := []
		for child in road.get_children():
			if child is MeshInstance3D: parts.append({"mesh":child.mesh,"material":child.material_override,"transform":child.transform})
		roads.append({"road":road,"parts":parts})
	var state := {"positions":positions,"roads":roads}
	return state

func conform_target(target: HD2DStage, rect: Rect2i = Rect2i()) -> Array:
	var old := capture_conform(target)
	var patches := {}
	if target.terrain() is HD2DWorldMap:
		patches=target.terrain().conform_records(rect)
		if target.foliage(): target.foliage().conform_to(target.terrain())
		for road in target.roads(): road.rebuild()
	else: target.conform_scenery()
	var current := capture_conform(target)
	if not patches.is_empty(): old.world_patch=patches.before;current.world_patch=patches.after
	return [old,current]

func restore_conform(target: HD2DStage, state: Dictionary) -> void:
	if not is_instance_valid(target): return
	if state.has("world_patch") and target.terrain() is HD2DWorldMap:
		target.terrain().apply_record_patches(state.world_patch)
	var plants := target.foliage()
	if plants:
		for i in range(mini(plants.records.size(),state.positions.size())):
			plants.records[i].position=state.positions[i]
			if plants.records[i].has("transform"): plants.records[i].transform.origin=state.positions[i]
		plants.rebuild()
	for entry in state.get("roads",[]):
		var road: HD2DRoad=entry.road
		if not is_instance_valid(road): continue
		for child in road.get_children(): road.remove_child(child); child.queue_free()
		for part in entry.parts:
			var node := MeshInstance3D.new(); node.mesh=part.mesh; node.material_override=part.material; node.transform=part.transform
			road.add_child(node)
		road.update_gizmos()
	EditorInterface.mark_scene_as_unsaved()

func conform_scenery() -> void:
	if not require_terrain(): return
	_finish_stroke()
	var conformed := conform_target(stage)
	var old: Dictionary=conformed[0];var now: Dictionary=conformed[1]
	var undo := get_undo_redo()
	undo.create_action(i18n.t("植物与道路重新贴地"),UndoRedo.MERGE_DISABLE,stage)
	undo.add_do_method(self,"restore_conform",stage,now)
	undo.add_undo_method(self,"restore_conform",stage,old)
	undo.commit_action(false); mark_changed()

func require_terrain() -> bool:
	if not require_stage(): return false
	if stage.terrain()==null:
		message("此场景使用网格地面，没有 HD2DTerrain。地形笔刷不修改导入网格；请用素材摆放或原生 Inspector。")
		return false
	return true

func set_terrain_texture(layer: int, path: String) -> void:
	if not require_terrain(): return
	var destination := stage
	var texture := await project_resource(path) as Texture2D
	if texture==null or not is_instance_valid(destination) or stage!=destination: return
	var textures := stage.terrain().data.textures.duplicate()
	textures.resize(stage.terrain().data.layer_count)
	if layer<0 or layer>=textures.size(): return
	textures[layer]=texture
	set_properties(stage.terrain().data,{"textures":textures},"设置地表纹理")

func set_texture_scale(value: float) -> void:
	if require_terrain(): set_properties(stage.terrain().data,{"texture_scale":value},"地表平铺")

func create_road() -> void:
	if not require_stage(): return
	var road := HD2DRoad.new(); road.name="Road"; road.curve=Curve3D.new(); road.terrain_path=NodePath("../../Terrain")
	var parent := stage.get_node("Scenery")
	var undo := get_undo_redo()
	undo.create_action(i18n.t("创建道路"),UndoRedo.MERGE_DISABLE,stage)
	undo.add_do_method(parent,"add_child",road,true)
	undo.add_do_method(road,"set_owner",EditorInterface.get_edited_scene_root())
	undo.add_undo_method(parent,"remove_child",road); undo.add_do_reference(road)
	undo.commit_action()
	active_road=road
	EditorInterface.get_selection().clear(); EditorInterface.get_selection().add_node(road)
	set_tool("road"); mark_changed()

func add_road_point(hit: Vector3) -> void:
	if not is_instance_valid(active_road): message("请先新建或选中一条道路。"); return
	var curve := active_road.curve.duplicate() as Curve3D
	curve.add_point(active_road.to_local(hit))
	set_properties(active_road,{"curve":curve},"添加道路控制点")

func remove_road_point() -> void:
	if not is_instance_valid(active_road) or active_road.curve.point_count==0: return
	var curve := active_road.curve.duplicate() as Curve3D
	curve.remove_point(curve.point_count-1)
	set_properties(active_road,{"curve":curve},"删除道路控制点")

func set_road_texture(path: String) -> void:
	if not is_instance_valid(active_road): message("请先选中道路。"); return
	var texture := await project_resource(path) as Texture2D
	if texture: set_properties(active_road,{"texture":texture},"道路纹理")

func apply_road_settings() -> void:
	if not is_instance_valid(active_road): message("请先选中道路。"); return
	set_properties(active_road,{"width":ui.value("road_width"),"tile_length":ui.value("road_tile"),"fences":ui.checked("fences"),"fence_spacing":ui.value("fence_spacing")},"道路参数")

func working_profile() -> HD2DCharacterProfile:
	var hero := current_character()
	if hero and hero.profile: return hero.profile.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	return HD2DCharacterProfile.new()

func import_character(paths: PackedStringArray, kind: String) -> void:
	if not require_stage() or current_character()==null or paths.is_empty(): return
	var destination := stage
	var target := current_character()
	var profile := working_profile()
	profile.directions=int(ui.choice("directions"))
	var animation: String = ui.choice("action")+"_"+ui.choice("direction")
	if kind=="frames":
		var frames := await project_resource(paths[0]) as SpriteFrames
		if frames==null: message("选中的资源不是 SpriteFrames。"); return
		profile.frames=frames.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	else:
		if profile.frames==null: profile.frames=SpriteFrames.new(); profile.frames.remove_animation("default")
		if profile.frames.has_animation(animation): profile.frames.remove_animation(animation)
		profile.frames.add_animation(animation)
		profile.frames.set_animation_speed(animation,ui.value("fps"))
		profile.frames.set_animation_loop(animation,true)
		if kind=="sequence":
			var sorted: Array[String]=[]; sorted.assign(paths)
			sorted.sort_custom(func(a: String,b: String): return a.naturalnocasecmp_to(b)<0)
			var expected := Vector2.ZERO
			for path in sorted:
				var texture := await project_resource(path) as Texture2D
				if texture==null: continue
				if ui.checked("protect_pixels"): _protect_texture(texture)
				if expected!=Vector2.ZERO and expected!=texture.get_size():
					message("序列尺寸不同：请先统一画布和脚底基线。本次未应用。")
					return
				expected=texture.get_size()
				profile.frames.add_frame(animation,texture)
		else:
			var texture := await project_resource(paths[0]) as Texture2D
			if texture==null: return
			if ui.checked("protect_pixels"): _protect_texture(texture)
			var cols := int(ui.value("atlas_columns")); var rows := int(ui.value("atlas_rows")); var row := int(ui.value("atlas_row"))-1; var count := int(ui.value("atlas_count"))
			if texture.get_width()%cols!=0 or texture.get_height()%rows!=0 or row>=rows or count>cols:
				message("图集尺寸不能整除行列，或行号 / 帧数超出范围。本次未应用。")
				return
			var size := texture.get_size()/Vector2(cols,rows)
			for i in range(count):
				var frame := AtlasTexture.new(); frame.atlas=texture; frame.region=Rect2(Vector2(i,row)*size,size)
				profile.frames.add_frame(animation,frame)
		if profile.frames.get_frame_count(animation)==0: message("没有成功导入任何帧。"); return
		profile.mapping[animation]=animation
	if not is_instance_valid(destination) or stage!=destination or not is_instance_valid(target) or current_character()!=target:
		message("导入期间切换了场景或角色：本次未应用，请重新选择导入目标。")
		return
	set_properties(target,{"profile":profile},"导入角色动画")
	message("角色已导入。请检查下方黄色脚底线，并查看缺失方向提示。")

func map_animation() -> void:
	if not require_stage(): return
	var profile := working_profile()
	var name_value: String=ui.controls.animation_mapping.text
	if profile.frames==null or not profile.frames.has_animation(name_value): message("动画名称不存在，请检查 SpriteFrames。"); return
	profile.mapping[ui.choice("action")+"_"+ui.choice("direction")]=name_value
	set_properties(current_character(),{"profile":profile},"角色方向映射")

func _protect_texture(texture: Texture2D) -> void:
	var path := texture.resource_path
	if path.is_empty() or not FileAccess.file_exists(path+".import"): return
	var config := ConfigFile.new()
	if config.load(path+".import")!=OK: return
	var changed: bool = config.get_value("params","compress/mode",0)!=0 or config.get_value("params","mipmaps/generate",false) or config.get_value("params","detect_3d/compress_to",1)!=0
	if not changed: return
	config.set_value("params","compress/mode",0)
	config.set_value("params","mipmaps/generate",false)
	config.set_value("params","detect_3d/compress_to",0)
	config.save(path+".import")
	# Native import completion can resume an awaited import before its progress
	# task has unwound. Never reenter reimport_files from that callback. A deferred
	# filesystem scan detects the changed import parameters and owns the next pass.
	if not texture_scan_queued:
		texture_scan_queued=true
		_scan_protected_textures.call_deferred()

func _scan_protected_textures() -> void:
	await get_tree().create_timer(0.2).timeout
	var filesystem := EditorInterface.get_resource_filesystem()
	while filesystem.is_scanning() or filesystem.is_importing(): await get_tree().process_frame
	texture_scan_queued=false
	filesystem.scan()

func apply_character_settings() -> void:
	if not require_stage() or current_character()==null: return
	var profile := working_profile()
	profile.directions=int(ui.choice("directions"))
	profile.foot_anchor=Vector2(ui.value("foot_x"),ui.value("foot_y"))
	profile.set_meta(HD2DCharacterProfile.PRESET_FOOT_REVISION,1)
	profile.full_billboard=ui.checked("character_face_camera")
	profile.shaded=ui.checked("character_shaded"); profile.flip_h=ui.checked("character_flip")
	profile.contact_shadow=ui.checked("contact_shadow"); profile.projected_shadow=ui.checked("projected_shadow")
	for key in ["pixel_size","move_speed","run_speed","collider_radius","collider_height"]: profile.set(key,ui.value(key))
	set_properties(current_character(),{"profile":profile},"角色脚底与控制配置")

func apply_camera_preset() -> void:
	if not require_stage(): return
	var rig := stage.camera_rig()
	if rig==null: message("场景缺少 HD2DCameraRig，请先添加镜头节点。"); return
	var values := HD2DCameraRig.preset_settings(ui.controls.camera_preset.selected)
	if values.is_empty(): return
	set_properties(rig,values,"应用镜头预设")
	stage.apply_environment()

func apply_camera_settings() -> void:
	if ui and ui.camera_panel: ui.camera_panel.apply()

func apply_loop_settings() -> void:
	if require_stage(): set_properties(stage,{"segment_length":ui.value("segment_length"),"scroll_speed":ui.value("scroll_speed"),"paused":ui.checked("loop_pause"),"seam_preview":ui.checked("seams")},"循环舞台配置")

func apply_environment_settings() -> void:
	if not require_stage(): return
	var values: Dictionary={}
	for key in ["sky_color","horizon_color","sun_color","ambient_color"]: values[key]=ui.controls[key].color
	for key in ["sun_energy","sun_yaw","sun_elevation","ambient_energy","wind_strength","cloud_shadows","fog_density","saturation","contrast","depth_blur","vignette","zone_blur"]: values[key]=ui.value(key)
	for key in ["shadows","fog_enabled","presentation_enabled"]: values[key]=ui.checked(key)
	values.sky_mode=ui.controls.sky_mode.selected
	set_properties(stage,values,"环境参数")

func open_preview() -> void:
	if ui and is_instance_valid(ui.music_panel): ui.music_panel.stop_now()
	if is_instance_valid(preview): preview.stop_music()
	if not require_stage(): return
	_finish_stroke()
	if is_instance_valid(preview): preview.queue_free()
	preview=Preview.new()
	preview.i18n=i18n
	EditorInterface.get_base_control().add_child(preview)
	preview.setup(stage)
	if preview.stage.has_node("WorldHUD"): preview.stage.get_node("WorldHUD").language=1 if i18n.language=="zh" else 2
	i18n.watch(preview)
	preview.popup_centered()
	preview.lock_box.button_pressed=ui.checked("camera_locked")

func set_preview_locked(value: bool) -> void:
	if ui.syncing: return
	if is_instance_valid(preview): preview.lock_box.button_pressed=value
	else: message("测试镜头已设为"+("固定跟随" if value else "自由观察")+"。点击“预览当前场景”查看。")
