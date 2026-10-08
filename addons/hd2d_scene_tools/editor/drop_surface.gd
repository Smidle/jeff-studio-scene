@tool
extends Control
var controller: EditorPlugin
var target_viewport: SubViewport

func _notification(what: int) -> void:
	if what==NOTIFICATION_DRAG_BEGIN and is_instance_valid(controller) and is_instance_valid(controller.stage): mouse_filter=Control.MOUSE_FILTER_PASS
	if what==NOTIFICATION_DRAG_END:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
		if is_instance_valid(controller): controller.hide_cursor()

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if not data is Dictionary: return false
	if not is_instance_valid(controller) or not is_instance_valid(controller.stage): return false
	if data.get("type","")=="files":
		var files: PackedStringArray=data.get("files",PackedStringArray())
		if files.is_empty() or files[0].get_extension().to_lower() not in ["png","webp","jpg","svg","glb","gltf","tscn","scn","tres","res"]: return false
	var valid: bool = data.has("hd2d_asset") or (data.get("type","")=="files" and not data.get("files",[]).is_empty())
	if valid and is_instance_valid(controller):
		controller.show_drop_preview(target_viewport,at*Vector2(target_viewport.size)/size,data)
	return valid

func _drop_data(at: Vector2, data: Variant) -> void:
	controller.drop_asset(target_viewport,at*Vector2(target_viewport.size)/size,data)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
