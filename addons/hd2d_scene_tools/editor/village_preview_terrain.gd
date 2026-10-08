@tool
extends "../runtime/terrain.gd"
## Display only the town's sampled area, without constructing collision shapes.
var sample_rect := Rect2i()
func rebuild() -> void:
	if not is_inside_tree() or data==null: return
	update_material()
	rebuild_region(sample_rect,false)
