@tool
extends Control
signal anchor_picked(value: Vector2)
var texture: Texture2D
var anchor := Vector2(0.5,1)
var image_rect := Rect2()

func _ready() -> void:
	custom_minimum_size=Vector2(240,170)
	mouse_default_cursor_shape=Control.CURSOR_CROSS

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("202830"))
	if texture==null: return
	var scale_value := minf((size.x-24)/texture.get_width(),(size.y-24)/texture.get_height())
	var image_size := texture.get_size()*scale_value
	image_rect=Rect2((size-image_size)*0.5,image_size)
	draw_texture_rect(texture,image_rect,false)
	var p := image_rect.position+anchor*image_rect.size
	draw_line(p-Vector2(10,0),p+Vector2(10,0),Color.YELLOW,2)
	draw_line(p-Vector2(0,10),p+Vector2(0,10),Color.YELLOW,2)
	draw_line(Vector2(0,p.y),Vector2(size.x,p.y),Color(1,1,0,0.3),1)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and texture:
		anchor=((event.position-image_rect.position)/image_rect.size).clamp(Vector2(-0.5,-0.5),Vector2(1.5,1.5))
		anchor_picked.emit(anchor)
		queue_redraw()
