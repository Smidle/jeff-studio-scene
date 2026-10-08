@tool
extends RefCounted
## The stable guide group is now an event-driven terrain draft preview.
var controller
var panel
var ui
var preview
var summary: Label
var footer: PanelContainer
var apply_button: Button
var footer_status: Label
var queued := false
var dirty := true
var disposed := false

func setup(plugin, terrain_panel, root: VBoxContainer, dock_ui) -> void:
	controller=plugin;panel=terrain_panel;ui=dock_ui
	var box: VBoxContainer=ui.section(root,"terrain.world","地形制作引导",true)
	summary=ui.label(box,"")
	preview=preload("landform_preview.gd").new();preview.custom_minimum_size=Vector2(230,205)*EditorInterface.get_editor_scale();box.add_child(preview)
	var actions := HBoxContainer.new();box.add_child(actions)
	ui.button(actions,"地图规格…",panel.open_creation)
	footer=PanelContainer.new();footer.name="TerrainApplyFrame";footer.theme_type_variation="JeffApplyFrame";ui.add_child(footer)
	var content := VBoxContainer.new();footer.add_child(content)
	footer_status=ui.label(content,"");footer_status.max_lines_visible=2
	apply_button=ui.button(content,"应用",panel.apply_current)
	apply_button.theme_type_variation="JeffPrimaryButton"
	ui.tabs.tab_changed.connect(page_changed)
	ui.sections["terrain.world"].expanded_changed.connect(func(_on): refresh())
	footer.hide()

func page_changed(_index: int) -> void:
	if disposed:return
	footer.visible=ui.tabs.current_tab==ui.page_index("terrain")
	if footer.visible:refresh()

func refresh() -> void:
	if disposed or not is_instance_valid(footer):return
	var creating: bool=panel.new_map_pending
	var valid := is_instance_valid(panel.target)
	var title := "新地图草稿 · 未应用" if creating else (("地表草稿 · 未应用" if panel.is_dirty() else "当前地形预览") if valid else "设置地图规格后，在这里预览并应用。")
	controller.i18n.text(summary,title)
	controller.i18n.text(apply_button,"应用：创建地图" if creating else "应用地表设置")
	apply_button.disabled=(panel.creation.visible or panel.creation_loading) if creating else not panel.is_dirty()
	controller.i18n.text(footer_status,"正在准备地表…" if panel.creation_loading else ("新地图草稿；应用后创建独立场景。" if creating else ("地表有未应用修改。" if panel.is_dirty() else "雕刻和绘制即时生效；Ctrl / Cmd + S 保存。")))
	footer.visible=ui.tabs.current_tab==ui.page_index("terrain")
	preview.visible=creating or valid
	if dirty and footer.visible and ui.sections["terrain.world"].expanded and not queued:
		queued=true;render.call_deferred()

func invalidate() -> void:
	dirty=true;refresh()

func render() -> void:
	queued=false
	if disposed or not is_instance_valid(preview) or not preview.is_visible_in_tree():return
	if panel.new_map_pending:
		preview.display(panel.map_landform(),panel.template_preset,ui.checked("terrain_create_liquid"),ui.value("terrain_liquid_speed"),panel.map_meters())
	elif is_instance_valid(panel.target):preview.display_terrain(panel.target,panel.draft,panel.convert)
	dirty=false

func dispose() -> void:
	disposed=true
	if ui.tabs.tab_changed.is_connected(page_changed):ui.tabs.tab_changed.disconnect(page_changed)
