@tool
extends Control
## Non-destructive pixel-region selection. Origin is the source image's top-left.
signal region_picked(rect: Rect2i)
var texture: Texture2D
var region := Rect2i()
var image_rect := Rect2()
var dragging := false
var start := Vector2i.ZERO

func _ready() -> void:
	custom_minimum_size = Vector2(240,190)
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	tooltip_text = "在图片上拖框选取一株花草。像素坐标从左上角开始；点击应用素材参数后生效。原 PNG 不会改变。"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("273336"))
	if texture == null or texture.get_width() == 0 or texture.get_height() == 0: return
	var ratio := minf((size.x-16)/texture.get_width(),(size.y-16)/texture.get_height())
	var dimensions := texture.get_size()*ratio
	image_rect = Rect2((size-dimensions)*0.5,dimensions)
	draw_texture_rect(texture,image_rect,false)
	if region.has_area():
		var box := Rect2(image_rect.position+Vector2(region.position)*ratio,Vector2(region.size)*ratio)
		draw_rect(box,Color(1,0.8,0.15),false,2.0)

func pixel_at(point: Vector2) -> Vector2i:
	var normalized := ((point-image_rect.position)/image_rect.size).clamp(Vector2.ZERO,Vector2.ONE)
	return Vector2i((normalized*texture.get_size()).round())

func _gui_input(event: InputEvent) -> void:
	if texture == null or not image_rect.has_area(): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and image_rect.has_point(event.position):
			dragging = true
			start = pixel_at(event.position)
		elif not event.pressed and dragging:
			dragging = false
			if region.has_area(): region_picked.emit(region)
		accept_event()
	if event is InputEventMouseMotion and dragging:
		var endpoint := pixel_at(event.position)
		region = Rect2i(start.min(endpoint),(endpoint-start).abs())
		queue_redraw()
		accept_event()
