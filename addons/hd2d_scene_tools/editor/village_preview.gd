@tool
extends Control
var layout: Dictionary={}
func show_layout(value: Dictionary) -> void:
	layout=value; queue_redraw()
func _draw() -> void:
	if layout.is_empty() or not layout.has("extent"): return
	var area: Rect2=layout.extent.grow(2)
	var factor := minf(size.x/area.size.x,size.y/area.size.y)
	var origin := (size-area.size*factor)*0.5-area.position*factor
	var accent := get_theme_color("accent_color","Editor")
	for road in layout.roads:
		var points: PackedVector3Array=road.points
		for i in range(points.size()-1):
			draw_line(origin+Vector2(points[i].x,points[i].z)*factor,origin+Vector2(points[i+1].x,points[i+1].z)*factor,Color("bba572"),maxf(1,road.width*factor))
	for i in layout.entries.size():
		var entry: Dictionary=layout.entries[i]
		var box := Rect2(origin+entry.footprint.position*factor,entry.footprint.size*factor)
		draw_rect(box,Color(accent,0.3)); draw_rect(box,accent,false,1)
		draw_string(get_theme_font("font","Label"),box.position+Vector2(2,13),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,get_theme_color("font_color","Label"))
