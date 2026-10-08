@tool
extends VBoxContainer
## Two rows keep all seven modules available in the narrow editor dock.
var tabs: TabContainer
var buttons: Array[Button]=[]
var style_signature := ""

func _ready() -> void:
	_style()

func setup(target: TabContainer, i18n) -> void:
	tabs=target
	var group := ButtonGroup.new(); group.allow_unpress=false
	for titles in [["地形","一键生成","素材","铺设"],["角色","镜头","环境","音乐"]]:
		var row := HBoxContainer.new(); row.size_flags_horizontal=Control.SIZE_EXPAND_FILL; add_child(row)
		for title in titles:
			var index := buttons.size()
			var button := Button.new(); button.name="Module"+str(index)
			button.toggle_mode=true; button.button_group=group
			button.alignment=HORIZONTAL_ALIGNMENT_LEFT
			button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			button.size_flags_stretch_ratio=1.0
			row.add_child(button); buttons.append(button)
			i18n.text(button,title); i18n.bind(button,"tooltip_text",title)
			button.pressed.connect(func(): tabs.current_tab=index)
			button.gui_input.connect(func(event): _keyboard(event,index))
	i18n.changed.connect(_fit_labels)
	tree_exiting.connect(func():
		if i18n.changed.is_connected(_fit_labels):i18n.changed.disconnect(_fit_labels))
	tabs.tab_changed.connect(_select)
	theme_changed.connect(_style)
	_style(); _select(tabs.current_tab)

func _fit_labels() -> void:
	for button in buttons:
		var font := button.get_theme_font("font")
		button.size_flags_stretch_ratio=font.get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(12*EditorInterface.get_editor_scale())).x+30*EditorInterface.get_editor_scale()

func _select(index: int) -> void:
	for i in buttons.size(): buttons[i].set_pressed_no_signal(i==index)

func _keyboard(event: InputEvent, index: int) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var next := index
		match event.keycode:
			KEY_RIGHT: next=(index+1)%buttons.size()
			KEY_LEFT: next=posmod(index-1,buttons.size())
			KEY_HOME: next=0
			KEY_END: next=buttons.size()-1
			_: return
		buttons[next].grab_focus(); tabs.current_tab=next; accept_event()

func _style() -> void:
	# Dock setup runs before it enters the editor tree. Resolve theme colors
	# only after inheritance is available, rather than caching black fallbacks.
	if not is_inside_tree() or buttons.is_empty(): return
	var scale := EditorInterface.get_editor_scale()
	var accent := get_theme_color("accent_color","Editor")
	var base := get_theme_color("base_color","Editor")
	var font := get_theme_color("font_color","Editor")
	var signature := str([scale,accent,base,font])
	if signature==style_signature: return
	style_signature=signature
	add_theme_constant_override("separation",roundi(6*scale))
	for row in get_children(): row.add_theme_constant_override("separation",roundi(6*scale))
	for button in buttons:
		button.custom_minimum_size.y=34*scale
		button.add_theme_font_size_override("font_size",roundi(12*scale))
		button.add_theme_constant_override("align_to_largest_stylebox",0)
		for state in ["normal","hover","pressed","hover_pressed","focus"]:
			var style := StyleBoxFlat.new()
			var selected: bool=state in ["pressed","hover_pressed"]
			style.bg_color=base.lerp(accent,0.25 if selected else 0.13 if state=="hover" else 0.04)
			style.border_color=accent if selected or state=="focus" else base.lerp(font,0.17)
			style.set_border_width_all(maxi(1,roundi(scale)))
			style.set_corner_radius_all(roundi(6*scale))
			style.content_margin_left=4*scale; style.content_margin_right=4*scale
			style.content_margin_top=6*scale; style.content_margin_bottom=6*scale
			if state=="focus": style.draw_center=false
			button.add_theme_stylebox_override(state,style)
		for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:
			button.add_theme_color_override(state,font)
	_fit_labels()
