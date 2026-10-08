@tool
extends Window
## Isolated World3D; no saved-scene camera or source node is driven by this window.
var source: HD2DStage
var stage: HD2DStage
var viewport: SubViewport
var screen: SubViewportContainer
var lock_box: CheckBox
var status: Label
var i18n

func setup(value: HD2DStage) -> void:
	source=value
	title="Jeff Studio 场景预览 · WASD 行走 · 关闭不写回"
	size=Vector2i(1100,700)
	var layout := VBoxContainer.new()
	add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bar := HBoxContainer.new()
	layout.add_child(bar)
	lock_box=CheckBox.new()
	lock_box.text="锁定角度并跟随"
	lock_box.button_pressed=true
	bar.add_child(lock_box)
	lock_box.toggled.connect(func(on: bool):
		stage.camera_rig().set_locked(on)
		i18n.text(status,"WASD / 方向键行走" if on else "左键旋转 · 中/右键平移 · 滚轮缩放"))
	var pause := CheckBox.new()
	pause.text="暂停循环"
	pause.button_pressed=value.paused
	pause.toggled.connect(func(on: bool): stage.paused=on)
	bar.add_child(pause)
	var speed := HSlider.new()
	speed.min_value=-20; speed.max_value=20; speed.step=0.1; speed.value=value.scroll_speed
	speed.custom_minimum_size.x=120
	speed.value_changed.connect(func(v: float): stage.scroll_speed=v)
	bar.add_child(speed)
	status=Label.new()
	status.text="WASD / 方向键行走"
	bar.add_child(status)
	screen=SubViewportContainer.new()
	screen.stretch=true
	screen.size_flags_vertical=Control.SIZE_EXPAND_FILL
	screen.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	layout.add_child(screen)
	viewport=SubViewport.new()
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	screen.add_child(viewport)
	screen.gui_input.connect(_view_input)
	stage=HD2DFactory.isolated_copy(value)
	stage.preview_active=true
	viewport.add_child(stage)
	stage.start_preview(true)
	close_requested.connect(func(): stop_music(); queue_free())
	focus_exited.connect(func():
		if is_instance_valid(stage) and stage.character(): stage.character().input_enabled=false
		if is_instance_valid(stage) and stage.has_node("WorldParty"): stage.get_node("WorldParty").controls_enabled=false)
	focus_entered.connect(func():
		if is_instance_valid(stage) and stage.character(): stage.character().input_enabled=true
		if is_instance_valid(stage) and stage.has_node("WorldParty"): stage.get_node("WorldParty").controls_enabled=true)

func _view_input(event: InputEvent) -> void:
	var rig := stage.camera_rig()
	if event is InputEventMouseMotion:
		if event.button_mask&MOUSE_BUTTON_MASK_LEFT: rig.orbit(event.relative)
		if event.button_mask&(MOUSE_BUTTON_MASK_MIDDLE|MOUSE_BUTTON_MASK_RIGHT): rig.pan(event.relative)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: rig.zoom(-1)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: rig.zoom(1)

func stop_music() -> void:
	if is_instance_valid(stage) and is_instance_valid(stage.music_player): stage.music_player.stop_now()
