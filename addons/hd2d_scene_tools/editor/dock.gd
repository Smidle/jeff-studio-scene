@tool
extends VBoxContainer
const Grid = preload("asset_grid.gd")
const AnchorPreview = preload("anchor_preview.gd")
const RegionPreview = preload("region_preview.gd")
const MusicPanel = preload("music_panel.gd")
const FoldSection = preload("fold_section.gd")
var sections: Dictionary = {}
var section_pages: Dictionary = {}
var section_state: Dictionary = {}
var activity_elapsed := 0.0
var music_panel
var controller
var i18n
var language_picker: OptionButton
var status: Label
var tabs: TabContainer
var navigation
var navigation_frame: PanelContainer
var operations_frame: PanelContainer
const PAGE_IDS := ["terrain","generation","assets","scatter","character","camera","environment","music"]
var character_placement
var village_panel
var grid: ItemList
var search: LineEdit
var category: LineEdit
var category_filter: OptionButton
var selected_asset: HD2DAsset
var controls: Dictionary = {}
var foot_preview: Control
var asset_region_preview: Control
var file_dialog: EditorFileDialog
var picker_callback: Callable
var warnings_label: Label
var syncing := false
var tool_buttons: Dictionary={}
var os_drop_window: Window
var import_report_dialog: AcceptDialog
var import_report_text: TextEdit
var asset_info: Label
var library_count: Label
var sheet_preview
var preset_panel
var terrain_panel
var camera_panel
var library_connection
var thumbnails
var library_generation := 0

func setup(plugin) -> void:
	controller=plugin
	i18n=plugin.i18n
	var saved: Variant=EditorInterface.get_editor_settings().get_project_metadata("hd2d_scene_tools","sections",{})
	section_state=saved.duplicate() if saved is Dictionary else {}
	var preferences := EditorInterface.get_editor_settings()
	if not preferences.get_project_metadata("hd2d_scene_tools","asset_layout_shared_v1",false):
		for id in ["assets.import","assets.library","assets.scene"]: section_state[id]=false
		preferences.set_project_metadata("hd2d_scene_tools","sections",section_state)
		preferences.set_project_metadata("hd2d_scene_tools","asset_layout_shared_v1",true)
	if not preferences.get_project_metadata("hd2d_scene_tools","terrain_guide_layout_v1",false):
		section_state["terrain.world"]=true
		preferences.set_project_metadata("hd2d_scene_tools","sections",section_state)
		preferences.set_project_metadata("hd2d_scene_tools","terrain_guide_layout_v1",true)
	custom_minimum_size.x=390
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	var brand := preload("brand_header.gd").new()
	add_child(brand);brand.setup(controller);language_picker=brand.language
	library_connection=preload("library_connection.gd").new()
	add_child(library_connection); library_connection.setup(controller)
	status=Label.new()
	status.text="新建模板，或选中已有 HD2D 场景。"
	status.autowrap_mode=TextServer.AUTOWRAP_OFF
	status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(status);status.hide()
	operations_frame=PanelContainer.new();operations_frame.name="ModuleOperationsFrame"
	operations_frame.theme_type_variation="JeffFrame"
	operations_frame.size_flags_vertical=Control.SIZE_EXPAND_FILL
	add_child(operations_frame)
	tabs=TabContainer.new()
	tabs.tabs_visible=false
	tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL
	operations_frame.add_child(tabs)
	tabs.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	tabs.tab_changed.connect(func(_index): library_connection.refresh())
	_terrain_tab(page("地形"))
	village_panel=preload("village_panel.gd").new()
	village_panel.setup(controller,page("一键生成"),self)
	_assets_tab(page("素材"))
	_scatter_tab(page("铺设"))
	_character_tab(page("角色"))
	_camera_tab(page("镜头"))
	_environment_tab(page("环境"))
	music_panel=MusicPanel.new()
	page("音乐").add_child(music_panel)
	music_panel.setup(self)
	navigation=preload("module_navigation.gd").new()
	navigation_frame=PanelContainer.new();navigation_frame.name="ModuleNavigationFrame"
	navigation_frame.theme_type_variation="JeffFrame"
	add_child(navigation_frame);move_child(navigation_frame,operations_frame.get_index())
	navigation_frame.add_child(navigation);navigation.setup(tabs,i18n)
	file_dialog=EditorFileDialog.new()
	file_dialog.access=EditorFileDialog.ACCESS_FILESYSTEM
	add_child(file_dialog)
	file_dialog.files_selected.connect(func(paths: PackedStringArray): picker_callback.call(paths))
	file_dialog.file_selected.connect(func(path: String): picker_callback.call(PackedStringArray([path])))
	preset_panel=preload("preset_panel.gd").new()
	add_child(preset_panel); preset_panel.setup(controller)
	thumbnails=preload("asset_thumbnails.gd").new();add_child(thumbnails)

func page_index(id: String) -> int:
	return PAGE_IDS.find(id)

func select_page(id: String) -> void:
	var index := page_index(id)
	if index>=0: tabs.current_tab=index

func page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name=title
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",8)
	scroll.add_child(box)
	var page_index := tabs.get_tab_count()-1
	box.set_meta("hd2d_page",page_index)
	var actions := HBoxContainer.new(); box.add_child(actions)
	button(actions,"全部展开",func(): set_page_expanded(page_index,true))
	button(actions,"全部收起",func(): set_page_expanded(page_index,false))
	return box

func section(parent: VBoxContainer, id: String, title: String, default_open: bool=false) -> VBoxContainer:
	var group := FoldSection.new()
	parent.add_child(group)
	group.setup(id,title,i18n,bool(section_state.get(id,default_open)))
	sections[id]=group
	var ancestor: Node=parent
	while ancestor and not ancestor.has_meta("hd2d_page"): ancestor=ancestor.get_parent()
	section_pages[id]=int(ancestor.get_meta("hd2d_page")) if ancestor else -1
	group.expanded_changed.connect(func(on: bool):
		section_state[id]=on
		EditorInterface.get_editor_settings().set_project_metadata("hd2d_scene_tools","sections",section_state))
	return group.content

func set_page_expanded(page_index: int, on: bool, persist: bool=true) -> void:
	for id in sections:
		if section_pages[id]==page_index: sections[id].set_expanded(on,persist)

func reveal_control(control: Control, persist: bool=false) -> void:
	for id in sections:
		if sections[id].is_ancestor_of(control):
			tabs.current_tab=section_pages[id]
			sections[id].set_expanded(true,persist)
	var scroll := tabs.get_current_tab_control() as ScrollContainer
	if scroll: scroll.ensure_control_visible.call_deferred(control)

func _process(delta: float) -> void:
	activity_elapsed+=delta
	if activity_elapsed<0.15: return
	activity_elapsed=0
	if camera_panel: camera_panel.sync_target()
	for id in sections:
		var active := false
		for key in tool_buttons:
			if key==controller.current_tool and sections[id].is_ancestor_of(tool_buttons[key]): active=true
		var state := "工具使用中" if active else ""
		if id=="music.audition" and is_instance_valid(music_panel) and is_instance_valid(music_panel.audition) and is_instance_valid(music_panel.audition.player) and music_panel.audition.player.playing:
			state="试听已暂停" if music_panel.audition.manual_paused else "试听中"
		sections[id].set_activity(state)

func label(parent: Node, text: String) -> Label:
	var item := Label.new()
	item.text=text
	item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(item)
	return item

func button(parent: Node, text: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text=text
	item.pressed.connect(callback)
	parent.add_child(item)
	return item

func number(parent: Node, key: String, title: String, min_value: float, max_value: float, step: float, value: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var caption := label(row,title)
	caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var item := SpinBox.new()
	item.min_value=min_value; item.max_value=max_value; item.step=step; item.value=value
	item.custom_minimum_size.x=110
	row.add_child(item)
	controls[key]=item
	return item

func slider(parent: Node, key: String, title: String, min_value: float, max_value: float, value: float) -> void:
	var spin := number(parent,key,title,min_value,max_value,0.01,value)
	var slide := HSlider.new()
	slide.min_value=min_value; slide.max_value=max_value; slide.step=0.01; slide.value=value
	parent.add_child(slide)
	slide.value_changed.connect(func(v: float): spin.value=v)
	spin.value_changed.connect(func(v: float): slide.set_value_no_signal(v))
	controls[key+"_slider"]=slide

func check(parent: Node, key: String, title: String, value: bool) -> CheckBox:
	var item := CheckBox.new()
	item.text=title; item.button_pressed=value
	parent.add_child(item)
	controls[key]=item
	return item

func option(parent: Node, key: String, title: String, values: Array) -> OptionButton:
	label(parent,title)
	var item := OptionButton.new()
	for value in values:
		item.add_item(str(value))
		item.set_item_metadata(item.item_count-1,str(value))
	parent.add_child(item)
	controls[key]=item
	return item

func color_field(parent: Node, key: String, title: String, value: Color) -> void:
	label(parent,title)
	var item := ColorPickerButton.new()
	item.color=value
	item.custom_minimum_size.y=28
	parent.add_child(item)
	controls[key]=item

func tool(parent: Node, key: String, title: String) -> void:
	var item := button(parent,title,func(): controller.set_tool(key))
	item.toggle_mode=true
	tool_buttons[key]=item

func _assets_tab(root_box: VBoxContainer) -> void:
	var entry := preload("library_header.gd").new()
	entry.text="预设素材库"; entry.pressed.connect(func(): preset_panel.open_catalog()); root_box.add_child(entry)
	asset_info=label(root_box,"先摆放素材，再选中一个场景物件修改参数。")
	var edit_row := HBoxContainer.new();root_box.add_child(edit_row)
	controls.choose_instance=button(edit_row,"选择场景实例…",func(): controller.parameters.choose_instance(selected_asset))
	controls.edit_last=button(edit_row,"编辑刚放置物件",func(): controller.edit_last_placed())
	controls.edit_last.disabled=true
	var box := section(root_box,"assets.import","导入与检查",false)
	var import_target := option(box,"import_target","导入目标",["本机共享素材库","当前场景 → 素材库与摆放"])
	import_target.select(int(EditorInterface.get_editor_settings().get_project_metadata("hd2d_scene_tools","import_target",1)))
	import_target.item_selected.connect(func(index): EditorInterface.get_editor_settings().set_project_metadata("hd2d_scene_tools","import_target",index))
	label(box,"导入 PNG / GLB / glTF / tscn / Mesh。按所选目标复制资源及依赖，保留原文件。")
	var drop := preload("library_drop.gd").new()
	drop.controller=controller; box.add_child(drop)
	var hint := label(drop,"↓ 工程文件拖到这里或缩略图库\nFinder / 文件夹请用下方“拖入接收窗”")
	hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
	hint.custom_minimum_size.y=56
	button(box,"打开文件夹拖入接收窗",open_os_drop_window)
	label(box,"新导入素材的分类（下方筛选不会修改分类）")
	category=LineEdit.new(); category.text=i18n.t("道具"); category.placeholder_text="导入分类"
	box.add_child(category)
	check(box,"protect_pixels","像素图无损导入 / 禁用自动 3D 压缩",true)
	button(box,"＋ 导入素材（可多选）",func(): pick(["*.png,*.webp,*.jpg,*.jpeg,*.svg ; 图片","*.glb,*.gltf,*.tscn,*.scn,*.tres,*.res ; 场景 / 网格"],true,func(paths): controller.import_assets(paths,category.text)))
	var report_row := HBoxContainer.new(); box.add_child(report_row)
	button(report_row,"导入结果",show_import_report)
	button(report_row,"检查缺失资源",func(): controller.inspect_library())
	var scene_box := section(root_box,"assets.scene","当前场景素材修改",false)
	box=section(scene_box,"assets.library","素材库与摆放",false)
	search=LineEdit.new(); search.placeholder_text="搜索名称、分类或路径…"; box.add_child(search)
	search.text_changed.connect(func(_v): refresh_library())
	category_filter=option(box,"category_filter","分类",["全部"])
	category_filter.item_selected.connect(func(_i): refresh_library())
	library_count=label(box,"")
	grid=Grid.new(); grid.controller=controller
	grid.custom_minimum_size=Vector2(280,240)
	grid.icon_mode=ItemList.ICON_MODE_TOP
	grid.fixed_icon_size=Vector2i(72,72)
	grid.fixed_column_width=94
	grid.max_columns=3
	grid.select_mode=ItemList.SELECT_MULTI
	box.add_child(grid)
	grid.item_selected.connect(_select_asset)
	grid.multi_selected.connect(func(index: int, selected: bool):
		if selected: _select_asset(index))
	label(box,"拖到 3D 视口放置，或选择“单株摆放”。Ctrl 多选可组成混合笔刷。")
	tool(box,"place","单株 / 单件摆放")
	box=section(scene_box,"assets.entry","条目管理",false)
	for field in [["asset_title","素材名称"],["asset_category","素材分类"]]:
		label(box,field[1])
		var edit := LineEdit.new(); box.add_child(edit); controls[field[0]]=edit
	button(box,"保存条目名称与分类",func(): controller.apply_entry_settings(selected_asset))
	button(box,"移除素材库条目（不删文件）",func(): controller.remove_asset(selected_asset))
	button(box,"复制条目（共用原文件）",func(): controller.duplicate_asset(selected_asset))
	button(box,"重新关联源文件…",func():
		var target := selected_asset
		pick(["*.png,*.webp,*.jpg,*.jpeg,*.svg,*.glb,*.gltf,*.tscn,*.scn,*.tres,*.res ; 素材"],false,func(paths): controller.relink_asset(target,paths[0])))
	box=section(scene_box,"assets.card","贴片外观与风摆",false)
	number(box,"card_width","贴片宽度（米）",0.05,100,0.05,2)
	number(box,"card_height","贴片高度（米）",0.05,100,0.05,2)
	number(box,"asset_anchor_x","横向锚点",-0.5,1.5,0.01,0.5)
	number(box,"asset_anchor_y","脚底锚点",-0.5,1.5,0.01,1)
	option(box,"asset_facing","贴片朝向",["固定平面","绕 Y 轴朝向镜头"])
	slider(box,"alpha_cut","透明裁切",0,1,0.5)
	check(box,"asset_nearest","像素最近邻采样",true)
	number(box,"asset_wind","此素材风摆幅度",0,1,0.01,0)
	label(box,"0 = 不随风摆动，适合火盆和建筑。植物可设 0.08；最终摆幅还乘以环境页的植物风力。图集动画独立播放。")
	box=section(scene_box,"assets.crop","图集裁切",false)
	label(box,"图集区域 · 拖框只使用一株，不改动原图片；宽高都为 0 使用整图。")
	asset_region_preview=RegionPreview.new()
	box.add_child(asset_region_preview)
	asset_region_preview.region_picked.connect(func(rect: Rect2i):
		controls.region_x.value=rect.position.x; controls.region_y.value=rect.position.y
		controls.region_w.value=rect.size.x; controls.region_h.value=rect.size.y)
	for item in [["region_x","区域起点 X（像素）"],["region_y","区域起点 Y（像素）"],["region_w","区域宽度（像素）"],["region_h","区域高度（像素）"]]:
		number(box,item[0],item[1],0,32768,1,0).value_changed.connect(func(_v): _sync_region_preview())
	button(box,"重置为完整图片",func():
		for key in ["region_x","region_y","region_w","region_h"]: controls[key].value=0)
	box=section(scene_box,"assets.sheet","精灵图集动画",false)
	check(box,"animate_sheet","循环播放规则精灵图集",false)
	label(box,"在上面的图集区域内均匀切格，先从左到右，再从上到下。仅播放已有帧；方向角色请用角色页。")
	for item in [["sheet_columns","精灵图集列数",1,128,1],["sheet_rows","精灵图集行数",1,128,1],["sheet_start","起始帧（从 0 开始）",0,16383,0],["sheet_count","播放帧数",1,16384,1]]:
		number(box,item[0],item[1],item[2],item[3],1,item[4])
	number(box,"sheet_fps","图集帧速率 FPS",0.1,60,0.1,8)
	button(box,"按单帧比例匹配宽度",func():
		if selected_asset and selected_asset.source is Texture2D:
			var pixels: Vector2=Vector2(value("region_w"),value("region_h"))
			if pixels==Vector2.ZERO: pixels=selected_asset.source.get_size()
			if pixels.y>0: controls.card_width.value=value("card_height")*(pixels.x/value("sheet_columns"))/(pixels.y/value("sheet_rows")))
	sheet_preview=preload("sheet_preview.gd").new(); box.add_child(sheet_preview)
	check(box,"sheet_preview_play","播放已应用素材预览",true).toggled.connect(func(on): sheet_preview.playing=on)
	label(box,"预览使用已应用参数。场景图集以引擎时间循环，同种素材同步；不自动暂停于舞台暂停，不支持逐株动作控制。")
	box=section(scene_box,"assets.collision","静态碰撞",false)
	check(box,"asset_collision","启用静态碰撞",true)
	option(box,"collision_mode","碰撞形状",["原网格（贴片无厚度）","盒体","胶囊"])
	label(box,"盒体：宽 / 高 / 厚；胶囊：宽是直径，高至少等于直径，厚度不使用。偏移相对素材落点，Y 向上。透明像素不会挖空碰撞。")
	for axis in ["x","y","z"]:
		number(box,"collision_"+axis,"碰撞尺寸 "+axis.to_upper()+"（米）",0.05,100,0.05,2 if axis=="y" else (1 if axis=="x" else 0.5))
	for axis in ["x","y","z"]:
		number(box,"collision_offset_"+axis,"碰撞偏移 "+axis.to_upper()+"（米）",-100,100,0.05,1 if axis=="y" else 0)
	button(box,"按贴片尺寸匹配盒体",func():
		controls.collision_mode.select(1)
		controls.collision_x.value=value("card_width"); controls.collision_y.value=value("card_height"); controls.collision_z.value=0.5
		controls.collision_offset_x.value=(0.5-value("asset_anchor_x"))*value("card_width")
		controls.collision_offset_y.value=(value("asset_anchor_y")-0.5)*value("card_height"); controls.collision_offset_z.value=0)
	check(box,"collision_preview","摆放时显示碰撞线框",true).toggled.connect(func(_on): controller._clear_cursor())
	var selected_lines := check(box,"selected_collision_lines","显示碰撞参考线",bool(EditorInterface.get_editor_settings().get_project_metadata("hd2d_scene_tools","selected_collision_lines",false)))
	selected_lines.toggled.connect(func(on):
		EditorInterface.get_editor_settings().set_project_metadata("hd2d_scene_tools","selected_collision_lines",on)
		controller.parameters.update_lines())
	box=section(scene_box,"assets.material","底色透明与原生材质",false)
	check(box,"color_key_enabled","按指定底色透明（仅纯色背景 RGB 图）",false)
	color_field(box,"color_key","要去除的底色",Color("212121"))
	number(box,"color_key_tolerance","底色容差（线性颜色差）",0,0.25,0.001,0.005)
	label(box,"底色透明是可选的显示处理，不是原始 Alpha；同色细节也可能被去掉。带真实透明通道的图片保持关闭。")
	button(box,"在 Inspector 编辑当前物件",func():
		if is_instance_valid(controller.parameters.target): EditorInterface.inspect_object(controller.parameters.target))
	controls.apply_asset=button(scene_box,"应用素材参数",func(): controller.parameters.apply_single())
	controls.apply_same=button(scene_box,"应用到当前场景所有相同素材",func(): controller.parameters.request_batch())
	import_report_dialog=AcceptDialog.new(); import_report_dialog.title="导入结果"
	import_report_dialog.min_size=Vector2i(580,360); add_child(import_report_dialog)
	import_report_text=TextEdit.new(); import_report_text.editable=false; import_report_text.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
	import_report_text.custom_minimum_size=Vector2(560,320); import_report_dialog.add_child(import_report_text)

func update_import_report(lines: Array[String]) -> void:
	import_report_text.text="\n\n".join(lines)
	if is_instance_valid(os_drop_window):
		var result := os_drop_window.get_node("Content/Result") as Label
		result.text=i18n.t("本批处理完成；关闭此窗，在素材页查看“导入结果”。")

func show_import_report() -> void:
	if import_report_text.text.is_empty(): import_report_text.text=i18n.t("尚无导入记录。")
	import_report_dialog.popup_centered(Vector2i(660,420))

func open_os_drop_window() -> void:
	if controls.import_target.selected==1 and not controller.require_stage(): return
	if is_instance_valid(os_drop_window): os_drop_window.show(); os_drop_window.grab_focus(); return
	os_drop_window=Window.new()
	os_drop_window.visible=false
	os_drop_window.title="Jeff Studio · 文件夹拖入接收窗"
	os_drop_window.force_native=true
	os_drop_window.size=Vector2i(540,300)
	os_drop_window.min_size=Vector2i(540,300)
	os_drop_window.transient=true
	add_child(os_drop_window)
	var content := VBoxContainer.new(); content.name="Content"
	os_drop_window.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left=20; content.offset_right=-20; content.offset_top=20; content.offset_bottom=-20
	label(content,"↓ 把 Finder / 文件夹中的素材拖到此窗口")
	label(content,"支持多文件及文件夹，最多 200 项。外部图片与 GLB 复制到 hd2d_imports；其他场景格式请先完整复制依赖目录到工程。不会移动或覆盖原文件。")
	var result := label(content,"等待拖入…"); result.name="Result"
	result.size_flags_vertical=Control.SIZE_EXPAND_FILL
	button(content,"完成 / 返回素材库",func(): os_drop_window.hide())
	os_drop_window.close_requested.connect(func(): os_drop_window.hide())
	os_drop_window.files_dropped.connect(func(paths: PackedStringArray):
		result.text=i18n.t("正在处理，请稍候…")
		controller.import_assets(paths,category.text))
	i18n.watch(os_drop_window)
	os_drop_window.popup_centered()

func select_library_asset(asset: HD2DAsset) -> void:
	var index: int=grid.items.find(asset)
	if index>=0:
		grid.select(index)
		_select_asset(index)

func _terrain_tab(root_box: VBoxContainer) -> void:
	terrain_panel=preload("terrain_panel.gd").new()
	terrain_panel.setup(controller,root_box,self)

func _scatter_tab(root_box: VBoxContainer) -> void:
	var box := section(root_box,"scatter.plants","植物铺设与擦除",true)
	label(box,"在素材页多选植物，组成混合笔刷。区域散布：点击一次铺满圆形范围。")
	tool(box,"scatter","植物混合笔刷")
	tool(box,"area","圆形区域散布")
	tool(box,"erase","擦除植物")
	number(box,"density","每平方米数量",0.01,10,0.01,0.3)
	number(box,"scatter_radius","铺设 / 擦除半径",0.2,64,0.1,5)
	box=section(root_box,"scatter.random","随机变化与道路避让",false)
	number(box,"scale_min","随机缩放下限",0.05,10,0.05,0.8)
	number(box,"scale_max","随机缩放上限",0.05,10,0.05,1.2)
	number(box,"yaw_min","随机朝向下限（度）",-180,180,1,-20)
	number(box,"yaw_max","随机朝向上限（度）",-180,180,1,20)
	number(box,"road_margin","道路排除额外距离",0,10,0.1,0.5)
	number(box,"seed","随机种子",0,2147483647,1,42)
	box=section(root_box,"scatter.road","道路曲线",false)
	label(box,"道路：点击添加控制点，Esc 结束。选中道路后拖动位置和两侧切线控制柄。")
	button(box,"新建道路并绘制",func(): controller.create_road())
	tool(box,"road","为当前道路添加点")
	number(box,"road_width","道路宽度",0.2,20,0.1,3)
	button(box,"删除最后一个道路控制点",func(): controller.remove_road_point())
	box=section(root_box,"scatter.fences","道路纹理与栅栏",false)
	number(box,"road_tile","道路纹理周期",0.2,20,0.1,3)
	check(box,"fences","沿两侧生成栅栏",false)
	number(box,"fence_spacing","栅栏间距",0.5,10,0.1,2)
	button(box,"选择道路纹理…",func(): pick(["*.png,*.jpg,*.webp ; 道路纹理"],false,func(paths): controller.set_road_texture(paths[0])))
	button(root_box,"应用道路参数",func(): controller.apply_road_settings())


func _character_tab(root_box: VBoxContainer) -> void:
	character_placement=preload("character_placement.gd").new()
	character_placement.setup(controller,root_box,self)
	var box := section(root_box,"character.action","动作与方向",true)
	label(box,"导入到当前选中角色，未选中时使用 Hero。逐动作/方向导入，不猜测缺失方向。")
	option(box,"directions","方向数量",[2,4,8]).select(1)
	option(box,"action","动作",["idle","walk","run"])
	var custom_action := LineEdit.new(); custom_action.placeholder_text="可选：自定义动作名（如 attack）"; box.add_child(custom_action); controls["custom_action"]=custom_action
	option(box,"direction","素材方向",["s","w","n","e","sw","nw","ne","se"])
	number(box,"fps","每秒帧数",1,60,1,8)
	box=section(root_box,"character.import","素材导入",true)
	button(box,"导入 PNG 序列（按名称自然排序）",func(): pick(["*.png ; PNG 序列"],true,func(paths): controller.import_character(paths,"sequence")))
	number(box,"atlas_columns","图集列数",1,128,1,4)
	number(box,"atlas_rows","图集行数",1,128,1,4)
	number(box,"atlas_row","读取第几行（从 1 开始）",1,128,1,1)
	number(box,"atlas_count","此行有效帧数",1,128,1,4)
	button(box,"导入规则精灵图集的这一行",func(): pick(["*.png ; 精灵图集"],false,func(paths): controller.import_character(paths,"atlas")))
	button(box,"导入现有 SpriteFrames",func(): pick(["*.tres,*.res ; SpriteFrames 资源"],false,func(paths): controller.import_character(paths,"frames")))
	box=section(root_box,"character.mapping","动画映射",false)
	var mapping := LineEdit.new(); mapping.placeholder_text="现有动画名称，如 WalkSouth"; box.add_child(mapping); controls["animation_mapping"]=mapping
	button(box,"将所选动作 / 方向映射到此动画",func(): controller.map_animation())
	box=section(root_box,"character.appearance","脚底锚点与显示",false)
	foot_preview=AnchorPreview.new(); box.add_child(foot_preview)
	label(box,"点击图片设置脚底锚点，黄色水平线是地面。")
	foot_preview.anchor_picked.connect(func(v: Vector2): controls.foot_x.value=v.x; controls.foot_y.value=v.y)
	number(box,"foot_x","横向锚点",-0.5,1.5,0.01,0.5)
	number(box,"foot_y","脚底锚点",-0.5,1.5,0.01,1)
	number(box,"pixel_size","每像素米数",0.001,0.1,0.001,0.025)
	check(box,"character_shaded","角色接受日光明暗",false)
	check(box,"character_face_camera","角色画面正对镜头（预设角色自动启用）",true)
	check(box,"character_flip","手动水平翻转（不补造方向）",false)
	box=section(root_box,"character.movement","行走与碰撞",false)
	number(box,"world_party_spacing","大地图队伍间距（米）",0.5,6,0.1,1.7)
	number(box,"world_party_speed","大地图队伍速度（米／秒）",1,20,0.1,7)
	button(box,"应用大地图队伍参数",func():
		if controller.stage and controller.stage.has_node("WorldParty"):
			controller.set_properties(controller.stage.get_node("WorldParty"),{"spacing":value("world_party_spacing"),"movement_speed":value("world_party_speed")},"大地图队伍参数"))
	number(box,"move_speed","行走速度 米/秒",0,20,0.1,4)
	number(box,"run_speed","跑步速度 米/秒",0,30,0.1,6.5)
	number(box,"collider_radius","碰撞半径",0.1,3,0.05,0.3)
	number(box,"collider_height","碰撞高度",0.2,5,0.05,1.5)
	tool(box,"hero","点击地面放置角色")
	box=section(root_box,"character.shadow","角色阴影",false)
	check(box,"contact_shadow","脚下接触阴影",true)
	check(box,"projected_shadow","平地投影阴影（倾斜坡面慎用）",false)
	button(root_box,"应用角色配置 / 脚底锚点",func(): controller.apply_character_settings())

	warnings_label=label(root_box,"")

func _camera_tab(root_box: VBoxContainer) -> void:
	var scene_preview := button(root_box,"预览当前场景",func(): controller.open_preview())
	var box := section(root_box,"camera.presets","镜头预设与预览锁定",true)
	option(box,"camera_preset","镜头预设",["横向跟随 · 低角度透视","斜俯视 45° · 正交","斜俯视 45° · 透视 25°","斜俯视 45° · 透视 30°"]).select(1)
	label(box,"选择预设后可调整参数，最后在底部应用；预设只填入构图草稿。")
	var locked := check(box,"camera_locked","锁定角度并跟随（隔离测试）",true)
	locked.toggled.connect(func(on: bool): controller.set_preview_locked(on))
	label(box,"取消勾选：测试镜头自由观察。原生编辑视口始终自由。下列参数才会保存到正式场景。")
	box=section(root_box,"camera.framing","正式镜头构图",true)
	slider(box,"camera_yaw","正式镜头朝向",-180,180,0)
	slider(box,"camera_pitch","正式镜头俯角",5,85,22)
	number(box,"camera_distance","镜头距离",2,100,0.1,22)
	number(box,"camera_fov","透视视角 FOV",5,100,0.01,50)
	number(box,"camera_focus","跟随焦点高度",0,10,0.01,1)
	number(box,"camera_size","正交画面高度",2,100,0.1,18)
	check(box,"orthographic","使用正交投影",true)
	box=section(root_box,"camera.bounds","跟随边界",false)
	check(box,"bounds","启用跟随边界",false)
	number(box,"bound_x","边界起点 X",-512,512,1,-120)
	number(box,"bound_z","边界起点 Z",-512,512,1,-120)
	number(box,"bound_w","边界宽度",1,1024,1,240)
	number(box,"bound_d","边界深度",1,1024,1,240)
	box=section(root_box,"camera.loop","循环舞台",false)
	label(box,"循环舞台 · 三段连续复用")
	number(box,"segment_length","单段长度（米）",4,256,0.1,40)
	number(box,"scroll_speed","滚动速度（负数反向）",-20,20,0.1,2)
	check(box,"loop_pause","暂停循环",false)
	check(box,"seams","显示段边界预览",false)
	button(box,"应用循环参数",func(): controller.apply_loop_settings())
	camera_panel=preload("camera_panel.gd").new()
	camera_panel.setup(controller,self,scene_preview)

func _environment_tab(root_box: VBoxContainer) -> void:
	var box := section(root_box,"environment.sky","天空与背景",true)
	var method := RenderingServer.get_current_rendering_method()
	label(root_box,"当前渲染器："+method+"\n插件不会更改项目渲染器。")
	color_field(box,"sky_color","天空",Color("72b5cd"))
	option(box,"sky_mode","天空模式",["程序天空","背景色 / 天空模型"])
	color_field(box,"horizon_color","地平线 / 雾颜色",Color("e4e7d0"))
	box=section(root_box,"environment.sun","日光与阴影",true)
	color_field(box,"sun_color","日光",Color("fff2ca"))
	slider(box,"sun_energy","日光强度",0,8,0.85)
	slider(box,"sun_yaw","太阳方位",-180,180,-35)
	slider(box,"sun_elevation","太阳高度",0,90,48)
	check(box,"shadows","投射阴影",true)
	box=section(root_box,"environment.ambient","环境补光",false)
	color_field(box,"ambient_color","环境补光颜色",Color(0.86,0.91,0.76))
	slider(box,"ambient_energy","环境补光",0,1,0.35)
	box=section(root_box,"environment.wind","风与云影",false)
	slider(box,"wind_strength","植物风力",0,3,0.5)
	slider(box,"cloud_shadows","云影浓度",0,1,0.18)
	box=section(root_box,"environment.fog","距离雾",false)
	check(box,"fog_enabled","距离雾",true)
	number(box,"fog_density","雾浓度",0,0.1,0.001,0.001)
	box=section(root_box,"environment.color","调色",false)
	slider(box,"saturation","饱和度",0.2,2,1.05)
	slider(box,"contrast","对比度",0.2,2,1.04)
	box=section(root_box,"environment.dof","真实景深",false)
	slider(box,"depth_blur","远景景深虚化",0,1,0)
	if method=="gl_compatibility":
		controls.depth_blur.editable=false
		controls.depth_blur_slider.editable=false
		label(root_box,"Compatibility：无真实景深、体积雾。距离雾和云影可用；虚化参数不生效。")
	else: label(root_box,"Forward+ / Mobile：支持真实远景景深；本版使用普通距离雾。")
	box=section(root_box,"environment.post","演出后期",false)
	check(box,"presentation_enabled","演出后期（仅游戏 / 隔离测试）",false)
	slider(box,"vignette","暗角",0,1,0.36)
	slider(box,"zone_blur","画面分区虚化（不是景深）",0,2,0)
	label(box,"分区虚化在 Compatibility 也可用；与真实景深分开，不改变原生编辑视口。")
	label(box,"案例 6 地区环境（原地图调色适配）")
	check(box,"world_region_grade","启用原地图地区调色",true)
	number(box,"world_region_strength","地区调色强度",0,1,0.01,0.35)
	number(box,"world_effect_speed","水面与云雾速度",0,3,0.05,1)
	button(box,"应用大地图环境",func():
		if controller.stage and controller.stage.has_node("WorldEnvironmentAdapter"):
			controller.set_properties(controller.stage.get_node("WorldEnvironmentAdapter"),{"regional_grading":checked("world_region_grade"),"region_strength":value("world_region_strength"),"effect_speed":value("world_effect_speed")},"应用大地图环境")
		else: controller.message("先创建并选中制作副本的舞台。"))
	button(root_box,"应用环境参数",func(): controller.apply_environment_settings())

func pick(filters: Array, multiple: bool, callback: Callable) -> void:
	picker_callback=callback
	var localized := PackedStringArray()
	for filter in filters:
		var parts: PackedStringArray=str(filter).split(" ; ",true,1)
		localized.append(parts[0]+" ; "+i18n.t(parts[1]) if parts.size()==2 else str(filter))
	file_dialog.filters=localized
	file_dialog.file_mode=EditorFileDialog.FILE_MODE_OPEN_FILES if multiple else EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.popup_centered_ratio(0.7)

func value(key: String) -> float: return controls[key].value
func checked(key: String) -> bool: return controls[key].button_pressed
func choice(key: String) -> String:
	if key=="action" and not controls.custom_action.text.strip_edges().is_empty(): return controls.custom_action.text.strip_edges()
	var item: OptionButton=controls[key]
	var original: Variant=item.get_item_metadata(item.selected)
	return str(original) if original!=null else item.get_item_text(item.selected)

func refresh_library(reset_categories: bool = false) -> void:
	if grid==null: return
	library_generation+=1
	var generation := library_generation
	var stage: HD2DStage=controller.stage
	if stage==null:
		grid.clear(); grid.items.clear(); selected_asset=null
		if library_count: i18n.text(library_count,"没有素材库。")
		if sheet_preview: sheet_preview.display(null)
		return
	var entries: Array=controller.scene_assets()
	if selected_asset != null and not entries.has(selected_asset): selected_asset=null
	if reset_categories:
		var previous_category := category_filter.get_item_text(category_filter.selected) if category_filter.selected>0 else ""
		category_filter.clear(); category_filter.add_item("全部")
		i18n.bind(category_filter,"item","全部",0)
		var categories: Array[String]=[]
		for asset in entries:
			if asset==null: continue
			if asset.category not in categories: categories.append(asset.category)
		for item in categories:
			category_filter.add_item(item)
			if not previous_category.is_empty() and item==previous_category: category_filter.select(category_filter.item_count-1)
	grid.clear(); grid.items.clear()
	for asset in entries:
		if asset==null: continue
		if not search.text.strip_edges().is_empty() and not (asset.title+" "+asset.category+" "+asset.source_path).to_lower().contains(search.text.strip_edges().to_lower()): continue
		if category_filter.selected>0 and asset.category!=category_filter.get_item_text(category_filter.selected): continue
		grid.items.append(asset)
		var missing: bool=asset.source_missing()
		var icon: Texture2D=asset.preview_texture() if asset.source is Texture2D else asset.thumbnail
		if missing: icon=EditorInterface.get_editor_theme().get_icon("StatusWarning","EditorIcons")
		if icon==null: icon=EditorInterface.get_editor_theme().get_icon("PackedScene" if asset.source is PackedScene else "Mesh","EditorIcons")
		grid.add_item(asset.title,icon)
		grid.set_item_tooltip(grid.item_count-1,asset.title+"\n"+asset.category+"\n"+asset.source_path+("\n"+i18n.t("资源缺失，请先重新关联文件。") if missing else ""))
		if asset==selected_asset: grid.select(grid.item_count-1)
		if not missing and thumbnails:
			grid.set_item_tooltip(grid.item_count-1,asset.title+"\n"+i18n.t("正在准备缩略图…"))
			thumbnails.request(asset,func(texture: Texture2D, reason: String):
				if generation!=library_generation: return
				var at: int=grid.items.find(asset)
				if at<0: return
				if texture: grid.set_item_icon(at,texture)
				grid.set_item_tooltip(at,asset.title+"\n"+asset.source_path+("\n"+i18n.t(reason) if not reason.is_empty() else "")),controller.shared_library)

	i18n.text(library_count,"显示 %d / %d 项"%[grid.item_count,entries.size()])

func _thumbnail_ready(_path: String, preview: Texture2D, _small: Texture2D, asset: Variant) -> void:
	var index: int=grid.items.find(asset)
	if index>=0 and preview: grid.set_item_icon(index,preview)

func _select_asset(index: int) -> void:
	if index<0 or index>=grid.items.size(): return
	controller.preset_brush_asset=null; controller.preset_brush_skin=&""
	selected_asset=grid.items[index]
	var target: HD2DProp=controller.parameters.target
	if is_instance_valid(target) and target.asset and target.asset.same_entry(selected_asset):
		controller.parameters.update_status();return
	controller.parameters.select_prop(null)
	# A library selection previews NEW placement defaults; scene selections show
	# their saved effective settings through select_prop, including explicit Off.
	fill_asset(selected_asset.with_overrides(selected_asset.placement_collision_overrides()))

func fill_asset(asset: HD2DAsset) -> void:
	var was_syncing := syncing
	syncing=true
	controls.asset_title.text=asset.title
	controls.asset_category.text=asset.category
	controls.card_width.value=asset.card_size.x; controls.card_height.value=asset.card_size.y
	controls.asset_anchor_x.value=asset.anchor.x; controls.asset_anchor_y.value=asset.anchor.y
	controls.asset_facing.select(asset.facing)
	controls.alpha_cut.value=asset.alpha_cut
	controls.asset_nearest.button_pressed=asset.nearest
	controls.asset_collision.button_pressed=asset.static_collision
	controls.collision_mode.select(asset.collision_mode)
	for index_axis in range(3):
		var axis: String=["x","y","z"][index_axis]
		controls["collision_"+axis].value=asset.collision_size[index_axis]
		controls["collision_offset_"+axis].value=asset.collision_offset[index_axis]
	controls.animate_sheet.button_pressed=asset.animate_sheet
	controls.asset_wind.value=asset.wind
	for key in ["sheet_columns","sheet_rows","sheet_start","sheet_count","sheet_fps"]: controls[key].value=asset.get(key)
	controls.region_x.value=asset.texture_region.position.x; controls.region_y.value=asset.texture_region.position.y
	controls.region_w.value=asset.texture_region.size.x; controls.region_h.value=asset.texture_region.size.y
	controls.color_key_enabled.button_pressed=asset.color_key_enabled
	controls.color_key.color=asset.color_key
	controls.color_key_tolerance.value=asset.color_key_tolerance
	asset_region_preview.texture=asset.source as Texture2D
	sheet_preview.display(asset)
	_sync_region_preview()
	syncing=was_syncing

func _sync_region_preview() -> void:
	if not is_instance_valid(asset_region_preview): return
	for key in ["region_x","region_y","region_w","region_h"]:
		if not controls.has(key): return
	asset_region_preview.region=Rect2i(int(value("region_x")),int(value("region_y")),int(value("region_w")),int(value("region_h")))
	asset_region_preview.queue_redraw()

func palette() -> Array:
	if controller.preset_brush_asset: return [controller.preset_brush_asset]
	var result: Array=[]
	for index in grid.get_selected_items(): result.append(grid.items[index])
	if result.is_empty() and selected_asset and is_instance_valid(controller.stage) and controller.stage.library and controller.stage.library.assets.has(selected_asset): result.append(selected_asset)
	return result

func sync_stage() -> void:
	if camera_panel: camera_panel.sync_target()
	if terrain_panel: terrain_panel.sync_target()
	if is_instance_valid(music_panel): music_panel.sync_stage()
	if not controller.stage: return
	syncing=true
	var stage: HD2DStage=controller.stage
	for key in ["sky_color","horizon_color","sun_color","ambient_color"]: controls[key].color=stage.get(key)
	for key in ["sun_energy","sun_yaw","sun_elevation","ambient_energy","wind_strength","cloud_shadows","fog_density","saturation","contrast","depth_blur","segment_length","scroll_speed","vignette","zone_blur"]: controls[key].value=stage.get(key)
	controls.sky_mode.select(stage.sky_mode)
	controls.presentation_enabled.button_pressed=stage.presentation_enabled
	if stage.has_node("WorldEnvironmentAdapter"):
		var climate=stage.get_node("WorldEnvironmentAdapter")
		controls.world_region_grade.set_pressed_no_signal(climate.regional_grading)
		controls.world_region_strength.value=climate.region_strength;controls.world_effect_speed.value=climate.effect_speed
	if stage.has_node("WorldParty"):
		controls.world_party_spacing.value=stage.get_node("WorldParty").spacing
		controls.world_party_speed.value=stage.get_node("WorldParty").movement_speed
	for key in ["shadows","fog_enabled"]: controls[key].button_pressed=stage.get(key)
	controls.loop_pause.button_pressed=stage.paused
	controls.seams.button_pressed=stage.seam_preview
	var hero: HD2DCharacter=controller.current_character()
	if hero and hero.profile:
		var profile := hero.profile
		controls.foot_x.value=profile.foot_anchor.x; controls.foot_y.value=profile.foot_anchor.y
		for key in ["pixel_size","move_speed","run_speed","collider_radius","collider_height"]: controls[key].value=profile.get(key)
		controls.directions.select([2,4,8].find(profile.directions))
		controls.character_face_camera.button_pressed=profile.full_billboard or hero.role>=0
		controls.character_face_camera.disabled=hero.role>=0
		controls.character_shaded.button_pressed=profile.shaded; controls.character_flip.button_pressed=profile.flip_h
		controls.contact_shadow.button_pressed=profile.contact_shadow; controls.projected_shadow.button_pressed=profile.projected_shadow
		i18n.text(warnings_label,"\n".join(profile.warnings()))
		foot_preview.anchor=profile.foot_anchor
		var animation := profile.resolve("idle","s")
		if animation!=&"": foot_preview.texture=profile.frames.get_frame_texture(animation,0)
		foot_preview.queue_redraw()
	refresh_library(true)
	syncing=false
