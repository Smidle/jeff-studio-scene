@tool
extends Control
var profile: HD2DCharacterProfile
var action := "walk"
var direction := "s"
var clock := 0.0
func _ready() -> void:
	custom_minimum_size=Vector2(0,140*EditorInterface.get_editor_scale())
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func _process(delta: float) -> void:
	if is_visible_in_tree() and profile:
		clock+=delta; queue_redraw()
func _draw() -> void:
	if not profile or not profile.frames: return
	var animation := profile.resolve(action,direction)
	if animation==&"": return
	var count := profile.frames.get_frame_count(animation)
	var texture := profile.frames.get_frame_texture(animation,int(clock*profile.frames.get_animation_speed(animation))%count)
	var scale_factor := minf(3*EditorInterface.get_editor_scale(),size.y/maxf(texture.get_height(),1))
	var dimensions := texture.get_size()*scale_factor
	var target := Rect2(Vector2((size.x-dimensions.x)*0.5,size.y-dimensions.y),dimensions)
	if profile.mirror_directions.has(direction): target.position.x+=target.size.x;target.size.x=-target.size.x
	draw_texture_rect(texture,target,false)
