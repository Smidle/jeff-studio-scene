@tool
extends Node
## Editor-only cache. Never writes thumbnail fields into shared source assets.
const DIRECTORY := "res://.godot/jeff_thumbnails"
var queue: Array=[]
var active := false
var memory := {}
var renderer
static func key(asset: HD2DAsset) -> String:
	var stamp := FileAccess.get_modified_time(asset.source_path) if not asset.source_path.is_empty() and FileAccess.file_exists(asset.source_path) else 0
	var source_id := str(asset.library_entry_id) if asset.library_entry_id!=&"" else asset.resource_path+asset.source_path
	if source_id.is_empty(): source_id=str(asset.get_instance_id())
	return var_to_str([source_id,stamp,asset.texture_region,asset.card_size]).sha256_text()
static func store_preview(asset: HD2DAsset, texture: Texture2D) -> void:
	if texture==null: return
	var image := texture.get_image()
	if image==null or image.is_empty(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	image.save_png(DIRECTORY.path_join(key(asset)+".png"))
func request(asset: HD2DAsset, callback: Callable, shared=null) -> void:
	if asset.source is Texture2D: callback.call(asset.preview_texture(),"");return
	if asset.thumbnail: callback.call(asset.thumbnail,"");return
	var id := key(asset)
	if memory.has(id): callback.call(memory[id],"");return
	var path := DIRECTORY.path_join(id+".png")
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image and not image.is_empty():
			memory[id]=ImageTexture.create_from_image(image);callback.call(memory[id],"");return
	if shared and asset.library_entry_id!=&"":
		for record in shared.read_index().get("entries",[]):
			if str(record.id)!=str(asset.library_entry_id): continue
			var texture: Texture2D=shared.thumbnail(record)
			if texture:
				store_preview(asset,texture);memory[id]=texture;callback.call(texture,"");return
	queue.append({"asset":asset,"callback":callback,"key":id})
	if not active: pump.call_deferred()
func pump() -> void:
	if active: return
	active=true
	while not queue.is_empty() and is_inside_tree():
		var job: Dictionary=queue.pop_front()
		if memory.has(job.key): job.callback.call(memory[job.key],"");continue
		if job.asset.source_missing():job.callback.call(null,"资源缺失，请重新关联。");continue
		if not is_instance_valid(renderer):
			renderer=preload("model_preview.gd").new();add_child(renderer)
			renderer.position=Vector2(-10000,-10000);renderer.size=Vector2(128,128)
		renderer.show_asset(job.asset,&"")
		await get_tree().process_frame
		if not is_inside_tree(): break
		await RenderingServer.frame_post_draw
		var image: Image=renderer.viewport.get_texture().get_image()
		if image and not image.is_empty():
			image.resize(128,128,Image.INTERPOLATE_LANCZOS)
			var texture := ImageTexture.create_from_image(image)
			store_preview(job.asset,texture);memory[job.key]=texture;job.callback.call(texture,"")
		else:job.callback.call(null,"预览生成失败；仍可选择场景实例修改。")
		renderer.show_asset(null,&"")
	active=false
