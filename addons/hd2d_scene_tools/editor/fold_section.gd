@tool
extends PanelContainer
## Editor-only visibility: no scene changes, undo actions, or control reconstruction.
signal expanded_changed(expanded: bool)
var section_id: String
var source_title: String
var header: Button
var content: VBoxContainer
var expanded := true
var activity := ""
var i18n
var source_style: StyleBox

func setup(id: String, title: String, translator, initially_open: bool) -> void:
	section_id=id; source_title=title; i18n=translator
	name=id.replace(".","_")
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",0)
	add_child(stack)
	header=Button.new()
	header.toggle_mode=true
	header.alignment=HORIZONTAL_ALIGNMENT_LEFT
	header.clip_text=true
	header.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	header.focus_mode=Control.FOCUS_ALL
	header.set_meta("hd2d_managed_text",true)
	stack.add_child(header)
	var margin := MarginContainer.new()
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,8)
	stack.add_child(margin)
	content=VBoxContainer.new()
	content.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",8)
	margin.add_child(content)
	header.toggled.connect(func(on: bool): set_expanded(on))
	header.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode in [KEY_LEFT,KEY_RIGHT]:
			set_expanded(event.keycode==KEY_RIGHT); header.accept_event())
	i18n.changed.connect(_refresh_heading)
	theme_changed.connect(_refresh_theme)
	set_expanded(initially_open,false)
	_refresh_theme()

func set_expanded(on: bool, notify: bool=true) -> void:
	var changed := expanded!=on
	# When collapsing programmatically, do not leave keyboard focus in hidden fields.
	if not on and is_inside_tree():
		var focused := get_viewport().gui_get_focus_owner()
		if is_instance_valid(focused) and content.is_ancestor_of(focused): header.grab_focus()
	expanded=on
	header.set_pressed_no_signal(on)
	content.get_parent().visible=on
	_refresh_heading()
	if changed and notify: expanded_changed.emit(on)

func set_activity(value: String) -> void:
	if activity==value: return
	activity=value; _refresh_heading()

func _refresh_heading() -> void:
	if not is_instance_valid(header): return
	header.text=(source_title if i18n.language=="zh" else i18n.t("分组："+source_title))
	header.set_meta("jeff_icon","down" if expanded else "right")
	header.icon=preload("pixel_icons.gd").new().texture("down" if expanded else "right")
	if not activity.is_empty(): header.text+=" · "+i18n.t(activity)
	header.tooltip_text=header.text+"\n"+i18n.t("点击或 Enter / Space 展开收起；左右方向键收起 / 展开。")

func _refresh_theme() -> void:
	if not is_instance_valid(header): return
	# Native editor style, including its light/dark palette and scale.
	var original := get_theme_stylebox("normal","Button")
	if source_style==original: return
	source_style=original
	var style: StyleBox=original.duplicate()
	if style is StyleBoxFlat:
		style.set_border_width_all(1)
		style.border_color=get_theme_color("font_color","Label")*Color(1,1,1,0.22)
	add_theme_stylebox_override("panel",style)
