@tool
extends PanelContainer
## Internal FileSystem dragging. OS file drops use our own native Window so the
## editor's root-window handler cannot copy/overwrite the same files a second time.
var controller

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type","") in ["files","files_and_dirs"] and not data.get("files",[]).is_empty()

func _drop_data(_at: Vector2, data: Variant) -> void:
	controller.import_assets(PackedStringArray(data.files),controller.ui.category.text)
