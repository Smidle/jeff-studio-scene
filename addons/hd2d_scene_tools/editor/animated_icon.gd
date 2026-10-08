@tool
extends Control
## Aseprite-exported frames, retaining GIF timing and transparency. Editor UI only.
const ART := "res://addons/hd2d_scene_tools/editor/art/"
static var cache: Dictionary={}
var sheet: Texture2D
var frames: Array=[]
var duration := 0.0
var playhead := 0.0
var frame_index := 0
var rendered_frames := 0
func setup(animation: String, pixels: int, phase: float=0.0) -> void:
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 clip_contents=true
 custom_minimum_size=Vector2.ONE*pixels*EditorInterface.get_editor_scale()
 size_flags_vertical=Control.SIZE_SHRINK_CENTER
 if not cache.has(animation):
  var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ART+animation+".json"))
  cache[animation]={"frames":data.frames,"sheet":ImageTexture.create_from_image(Image.load_from_file(ART+animation+".png"))}
 frames=cache[animation].frames;sheet=cache[animation].sheet
 for frame in frames:duration+=float(frame.duration_ms)/1000.0
 playhead=fposmod(phase,duration)
 resized.connect(queue_redraw)
 visibility_changed.connect(func():set_process(is_visible_in_tree()))
 _update_frame();set_process(is_visible_in_tree())
func _process(delta: float) -> void:
 if not is_visible_in_tree() or not get_window().visible:return
 playhead=fposmod(playhead+delta,duration);_update_frame()
func _update_frame() -> void:
 var elapsed := 0.0
 for i in frames.size():
  elapsed+=float(frames[i].duration_ms)/1000.0
  if playhead<elapsed:
   if frame_index!=i:frame_index=i;rendered_frames+=1;queue_redraw()
   return
func _draw() -> void:
 if not sheet or frames.is_empty():return
 var frame: Dictionary=frames[frame_index]
 var target := Rect2((size-custom_minimum_size)*0.5,custom_minimum_size)
 draw_texture_rect_region(sheet,target,Rect2(frame.x,frame.y,frame.w,frame.h))
