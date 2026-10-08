@tool
extends RefCounted
## Editor-only camera draft. Runtime resources remain unchanged until Apply.
const FIELDS := {"camera_yaw":"yaw_degrees", "camera_pitch":"pitch_degrees", "camera_distance":"distance", "camera_fov":"field_of_view", "camera_focus":"focus_height", "camera_size":"frame_size", "orthographic":"orthographic", "bounds":"bounds_enabled"}
var controller
var ui
var target: HD2DCameraRig
var baseline: Dictionary={}
var draft: Dictionary={}
var footer: PanelContainer
var status: Label
var apply_button: Button
var preview_button: Button
var loading := false
var applying := false
var notice := ""

func setup(plugin, dock_ui, scene_preview: Button) -> void:
	controller=plugin;ui=dock_ui;preview_button=scene_preview
	footer=PanelContainer.new();footer.name="CameraApplyFrame";footer.theme_type_variation="JeffApplyFrame";ui.add_child(footer)
	var box := VBoxContainer.new();footer.add_child(box)
	status=ui.label(box,"");status.max_lines_visible=3
	apply_button=ui.button(box,"应用镜头设置",apply)
	apply_button.theme_type_variation="JeffPrimaryButton"
	ui.controls.camera_preset.add_item("自定义")
	ui.controls.camera_preset.set_item_disabled(4,true)
	ui.controls.camera_preset.item_selected.connect(select_preset)
	for key in FIELDS:
		var control: Control=ui.controls[key]
		if control is BaseButton:control.toggled.connect(edited.bind(key))
		else:control.value_changed.connect(edited.bind(key))
	for key in ["bound_x","bound_z","bound_w","bound_d"]:ui.controls[key].value_changed.connect(edited.bind(key))
	ui.tabs.tab_changed.connect(func(_index): refresh())
	controller.scene_saved.connect(scene_saved)
	ui.tree_exiting.connect(func():
		if controller.scene_saved.is_connected(scene_saved):controller.scene_saved.disconnect(scene_saved))
	sync_target()

func read_target(rig: HD2DCameraRig) -> Dictionary:
	var result: Dictionary={}
	for property in FIELDS.values():result[property]=rig.get(property)
	result.follow_bounds=rig.follow_bounds
	return result

func is_dirty() -> bool:
	return is_instance_valid(target) and draft!=baseline

func sync_target() -> void:
	var rig: HD2DCameraRig=controller.stage.camera_rig() if is_instance_valid(controller.stage) else null
	var incoming: Dictionary=read_target(rig) if is_instance_valid(rig) else {}
	var replaced: bool=rig!=target
	if replaced or incoming!=baseline:
		var discarded: bool=not draft.is_empty() and draft!=baseline
		target=rig;baseline=incoming;draft=incoming.duplicate();notice=""
		if discarded and not applying:
			notice="已切换镜头或检测到外部修改；草稿已同步。"
			controller.message(notice)
		write_controls()
	refresh()

func write_controls() -> void:
	loading=true
	if not draft.is_empty():
		var world: bool=is_instance_valid(controller.stage) and controller.stage.terrain() is HD2DWorldMap
		ui.controls.camera_distance.max_value=maxf(1500 if world else 100,float(draft.distance))
		ui.controls.camera_size.max_value=maxf(760 if world else 100,float(draft.frame_size))
		ui.controls.camera_focus.max_value=maxf(10,float(draft.focus_height))
		for key in FIELDS:
			var control: Control=ui.controls[key]
			if control is BaseButton:control.set_pressed_no_signal(draft[FIELDS[key]])
			else:control.set_value_no_signal(draft[FIELDS[key]])
			if ui.controls.has(key+"_slider"):ui.controls[key+"_slider"].set_value_no_signal(draft[FIELDS[key]])
		var bounds: Rect2=draft.follow_bounds
		for pair in [["bound_x",bounds.position.x],["bound_z",bounds.position.y],["bound_w",bounds.size.x],["bound_d",bounds.size.y]]:
			var field: Range=ui.controls[pair[0]]
			var origin: bool=pair[0] in ["bound_x","bound_z"]
			field.min_value=minf(-512 if origin else 1,pair[1])
			field.max_value=maxf(512 if origin else 1024,pair[1])
			field.step=1.0 if is_equal_approx(pair[1],roundf(pair[1])) else 0.01
			field.set_value_no_signal(pair[1])
	update_preset_name()
	loading=false

func update_preset_name() -> void:
	var index := 4
	for candidate in 4:
		var values := HD2DCameraRig.preset_settings(candidate)
		var matches := not draft.is_empty()
		for key in values:
			if not draft.has(key) or not is_equal_approx(float(draft[key]),float(values[key])):matches=false
		if matches:index=candidate;break
	ui.controls.camera_preset.select(index)

func select_preset(index: int) -> void:
	if loading or index>=4:return
	sync_target()
	if not is_instance_valid(target):return
	for key in HD2DCameraRig.preset_settings(index):draft[key]=HD2DCameraRig.preset_settings(index)[key]
	notice="";write_controls();refresh()

func edited(value: Variant, key: String) -> void:
	if loading or ui.syncing or not is_instance_valid(target):return
	# Preserve untouched values, including imported bounds outside slider ranges.
	if FIELDS.has(key):draft[FIELDS[key]]=value
	else:
		var bounds: Rect2=draft.follow_bounds
		match key:
			"bound_x":bounds.position.x=value
			"bound_z":bounds.position.y=value
			"bound_w":bounds.size.x=value
			"bound_d":bounds.size.y=value
		draft.follow_bounds=bounds
	notice="";update_preset_name();refresh()

func apply() -> void:
	# Detect a removed/replaced/externally changed target before committing.
	sync_target()
	if not is_dirty():return
	applying=true
	controller.set_properties(target,draft.duplicate(),"应用镜头设置")
	controller.stage.apply_environment()
	applying=false
	notice="已应用镜头设置；可预览当前场景，Ctrl / Cmd + S 保存。"
	controller.message(notice)
	refresh()

func scene_saved(path: String) -> void:
	if not is_dirty() and is_instance_valid(controller.stage) and controller.stage.scene_file_path==path:
		notice="镜头设置已保存。";refresh()

func refresh() -> void:
	footer.visible=ui.tabs.current_tab==ui.page_index("camera")
	var valid := is_instance_valid(target)
	apply_button.disabled=not is_dirty()
	ui.controls.camera_preset.disabled=not valid
	preview_button.disabled=not is_instance_valid(controller.stage)
	var text := "未应用修改；先应用，再预览与保存。" if is_dirty() else (notice if not notice.is_empty() else "镜头设置与场景一致。")
	if not valid:text="场景缺少镜头节点。" if is_instance_valid(controller.stage) else "请先创建或选择场景，再设置镜头。"
	controller.i18n.text(status,text)
	preview_button.tooltip_text=controller.i18n.t("预览使用已应用的镜头设置；草稿请先应用。")
