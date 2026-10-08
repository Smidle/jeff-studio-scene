@tool
extends Button
var signature := ""
## Native theme colors and logical editor scale; the whole card is the hit target.
func _ready() -> void:
	theme_changed.connect(_style)
	_style()

func _style() -> void:
	var scale_factor := EditorInterface.get_editor_scale()
	var accent := get_theme_color("accent_color","Editor")
	var base := get_theme_color("base_color","Editor")
	var next := str([accent,base,scale_factor])
	if next==signature: return
	signature=next
	var style := StyleBoxFlat.new()
	style.bg_color=base.lerp(accent,0.14)
	style.border_color=accent
	style.set_border_width_all(maxi(1,roundi(2*scale_factor)))
	style.set_corner_radius_all(roundi(6*scale_factor))
	style.content_margin_left=16*scale_factor; style.content_margin_right=16*scale_factor
	style.content_margin_top=14*scale_factor; style.content_margin_bottom=14*scale_factor
	for state in ["normal","hover","pressed","focus"]: add_theme_stylebox_override(state,style)
	add_theme_font_size_override("font_size",roundi(18*scale_factor))
	icon=EditorInterface.get_editor_theme().get_icon("MeshLibrary","EditorIcons")
	alignment=HORIZONTAL_ALIGNMENT_LEFT
