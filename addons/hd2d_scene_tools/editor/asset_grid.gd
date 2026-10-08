@tool
extends ItemList
var controller: EditorPlugin
var items: Array[HD2DAsset]=[]
var dragged_asset: HD2DAsset

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type","") in ["files","files_and_dirs"] and not data.get("files",[]).is_empty()

func _drop_data(_at: Vector2, data: Variant) -> void:
	controller.import_assets(PackedStringArray(data.files),controller.ui.category.text)

func _get_drag_data(position: Vector2) -> Variant:
	var index := get_item_at_position(position,true)
	if index<0 or index>=items.size(): return null
	if items[index].source_missing(): controller.message("资源缺失，请先重新关联文件。"); return null
	var label := Label.new()
	controller.i18n.text(label,"放置："+items[index].title)
	set_drag_preview(label)
	dragged_asset=items[index]
	controller.palette_drop_completed=false
	return {"hd2d_asset":items[index]}

func _notification(what: int) -> void:
	if what==NOTIFICATION_DRAG_END and dragged_asset:
		controller.finish_palette_drag.call_deferred(dragged_asset)
		dragged_asset=null
