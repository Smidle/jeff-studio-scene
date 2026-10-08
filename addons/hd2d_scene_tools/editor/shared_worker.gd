extends SceneTree
## Runs only in a disposable host. Rebinding resource paths never touches the editor's cache.
var job: Dictionary
var seen := {}
var saves := {}
var error := ""
func _initialize() -> void: run.call_deferred()

func relocate(value: Variant) -> Variant:
	if value is Resource:
		if seen.has(value): return value
		seen[value]=true
		var path: String=value.resource_path
		if path.begins_with("res://addons/hd2d_scene_tools/"): return value
		if not path.is_empty() and not path.contains("::"):
			if not job.mapping.has(path): error="Undeclared resource dependency: "+path; return value
			value.resource_path=job.mapping[path]
			if path.get_extension().to_lower() not in ["tscn","scn","tres","res"]: return value
			saves[value.resource_path]=value
		elif path.contains("::"): value.resource_path=""
		for property in value.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and property.name not in ["resource_path","script"]:
				var original: Variant=value.get(property.name)
				var relocated: Variant=relocate(original)
				if relocated!=original: value.set(property.name,relocated)
		return value
	if value is Array:
		var copy: Array=value.duplicate()
		for i in copy.size(): copy[i]=relocate(copy[i])
		return copy
	if value is Dictionary:
		var copy: Dictionary={}
		for key in value: copy[relocate(key)]=relocate(value[key])
		return copy
	if value is String or value is StringName:
		var key := str(value)
		if job.mapping.has(key): return StringName(job.mapping[key]) if value is StringName else job.mapping[key]
	return value

func run() -> void:
	job=JSON.parse_string(FileAccess.get_file_as_string("res://job.json"))
	var resource := load(str(job.source))
	if not (resource is Texture2D or resource is Mesh or resource is PackedScene): finish("Unsupported resource type"); return
	if resource is PackedScene:
		var probe: Node=resource.instantiate()
		var valid := probe is Node3D; probe.free()
		if not valid: finish("Scene root must be Node3D"); return
	resource=relocate(resource)
	if not error.is_empty(): finish(error); return
	for path in saves:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(str(path).get_base_dir()))
		var code := ResourceSaver.save(saves[path],path,ResourceSaver.FLAG_COMPRESS if str(path).get_extension() in ["res","scn"] else 0)
		if code!=OK: finish("Cannot serialize "+path+": "+error_string(code)); return
	var asset := HD2DAsset.new()
	asset.library_entry_id=StringName(job.id); asset.source=resource; asset.source_path=job.mapping[job.source]
	asset.title=job.title; asset.category=job.category; asset.wind=0.0
	if resource is Texture2D: asset.card_size=Vector2(float(resource.get_width())/resource.get_height()*2,2)
	asset.enable_default_collision()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(str(job.asset).get_base_dir()))
	if ResourceSaver.save(asset,job.asset)!=OK: finish("Cannot save library entry"); return
	# Render the actual asset using the same isolated preview as the library panel.
	var preview=load("res://addons/hd2d_scene_tools/editor/model_preview.gd").new()
	root.add_child(preview); preview.size=Vector2(256,256)
	preview.show_asset(asset,&"")
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var view: SubViewport=preview.viewport
	var image := view.get_texture().get_image()
	if image==null or image.is_empty(): finish("Thumbnail render failed"); return
	image.save_png("res://thumbnail.png")
	preview.free()
	finish("")

func finish(reason: String) -> void:
	var file := FileAccess.open("res://result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"error":reason})); file.close()
	quit(0 if reason.is_empty() else 1)
