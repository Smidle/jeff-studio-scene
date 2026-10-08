@tool
extends TextureRect
var asset: HD2DAsset
var playing := true
var elapsed := 0.0
var last_frame := -1

func _init() -> void:
	custom_minimum_size=Vector2(100,130)
	expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func display(value: HD2DAsset) -> void:
	asset=value; elapsed=0; last_frame=-1
	texture=asset.preview_texture() if asset else null
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST if asset and asset.nearest else CanvasItem.TEXTURE_FILTER_LINEAR

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not playing or asset==null or not asset.animate_sheet: return
	elapsed+=delta
	var frame := int(elapsed*asset.sheet_fps)%maxi(1,asset.sheet_count)
	if frame!=last_frame:
		last_frame=frame
		texture=asset.preview_texture(frame)
