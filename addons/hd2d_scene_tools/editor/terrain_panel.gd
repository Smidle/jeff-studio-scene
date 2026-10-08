@tool
extends RefCounted
var controller
var ui
var library
var picker
var target: HD2DTerrain
var draft := {}
var applied := {}
var active_layer := 0
var revision := 0
var syncing := false
var convert := false
var status: Label
var draft_status: Label
var legacy_hint: Label
var cards: Array[Button]=[]
var thumbs: Array[TextureRect]=[]
var apply_button: Button
var reset_button: Button
var conversion_button: Button
var preview_conversion_button: Button
var preset_button: Button
var preview
var creation: Window
var spacing: Label
var create_scheme: Label
var template_preset := {}
var edit_buttons: Array[Button]=[]
var layer_rows: Array[Control]=[]
var add_layer_button: Button
var new_map_hint: Label
var landform_hint: Label
var landform_preview
var recommended_button: Button
var creation_generation := 0
var world_surface: OptionButton
var guide
var new_map_pending := false
var creation_loading := false
var plain_button: Button
var scheme_button: Button

func setup(plugin, root: VBoxContainer, dock_ui) -> void:
	controller=plugin; ui=dock_ui
	library=preload("terrain_library.gd").new(); library.controller=controller
	status=ui.label(ui,""); ui.move_child(status,ui.tabs.get_index())
	status.hide()
	ui.tabs.tab_changed.connect(func(index):
		status.hide()
		if index!=ui.page_index("terrain"): controller.terrain_focus.set_enabled(false))
	guide=preload("terrain_guide.gd").new();guide.setup(controller,self,root,ui)
	var focus: CheckBox=ui.check(root,"terrain_only_view","只显示地形（临时）",false)
	focus.toggled.connect(func(on): controller.terrain_focus.set_enabled(on); focus.set_pressed_no_signal(controller.terrain_focus.enabled))
	controller.terrain_focus.changed.connect(func(): focus.set_pressed_no_signal(controller.terrain_focus.enabled))
	ui.label(root,"选中地形即可雕刻；临时隐藏只影响编辑视图。")
	var box: VBoxContainer=ui.section(root,"terrain.template","新建地图",false)
	ui.label(box,"新建地图 → 雕刻地形 → 选择地表 → 绘制地表 → 贴地维护")
	ui.button(box,"新建地图…",open_creation)
	ui.label(box,"地图规格在新建窗口设置，只作用于新地图。")
	box=ui.section(root,"terrain.brush","地形雕刻",true)
	var tools := GridContainer.new(); tools.columns=2; box.add_child(tools)
	for item in [["raise","升高"],["lower","降低"],["smooth","平滑"],["flatten","平台"],["ramp","坡道"]]: ui.tool(tools,item[0],item[1])
	ui.number(box,"radius","雕刻半径（米）",0.2,64,0.1,4)
	ui.number(box,"strength","雕刻强度 / 秒",0.05,30,0.05,3)
	ui.number(box,"level","平台 / 坡道终点高度（米）",-50,100,0.1,2)
	ui.label(box,"按住持续生效，一笔一次撤销。坡道从按下处高度连接到拖动终点。")
	box=ui.section(root,"terrain.layers","地表层与绘制",false)
	world_surface=OptionButton.new(); box.add_child(world_surface); world_surface.hide()
	world_surface.item_selected.connect(func(index):
		if is_dirty(): controller.message("先应用或还原地表修改，再切换区块材质。"); refresh_draft(); return
		if target is HD2DWorldMap:
			target.world_data().select_surface(str(world_surface.get_item_metadata(index))); sync_target(true))
	ui.label(box,"内置地表无需共享库；选中后预览，应用后生效。")
	preset_button=ui.button(box,"选择整套预设…",func(): open_presets(-1)); edit_buttons.append(preset_button)
	legacy_hint=ui.label(box,"旧复合材质保持原貌；改用四层地表会改变外观，不烘焙原材质。")
	preview_conversion_button=ui.button(box,"预览四层地表",func(): convert=true; refresh_draft())
	ui.label(box,"绘制就是用笔刷增加所选纹理的占比；第 1 层初始铺满，其他层从笔刷处显现。层号不是上下遮挡顺序。")
	for i in range(9):
		var row := HBoxContainer.new(); box.add_child(row); layer_rows.append(row)
		var thumb := TextureRect.new(); thumb.custom_minimum_size=Vector2(64,64)
		thumb.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; thumb.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; row.add_child(thumb); thumbs.append(thumb)
		var card: Button=ui.button(row,"",func(): select_layer(i)); card.toggle_mode=true
		card.size_flags_horizontal=Control.SIZE_EXPAND_FILL; cards.append(card)
		var actions := HBoxContainer.new(); box.add_child(actions); layer_rows.append(actions)
		edit_buttons.append(ui.button(actions,"选择预设纹理…",func(): open_presets(i)))
		edit_buttons.append(ui.button(actions,"选择本地图片…",func(): choose_local(i)))
	add_layer_button=ui.button(box,"增加地表层（最多 8 层）",add_layer)
	ui.label(box,"简单场景可用 1–3 层，默认 4 层；复杂场景按需增加，更多层会增加显存和绘制成本。")
	ui.number(box,"texture_scale","纹理重复周期（米）",0.1,32,0.1,2).value_changed.connect(func(value):
		if not syncing and not draft.is_empty(): draft.texture_scale=value; refresh_draft())
	ui.label(box,"所有层共用周期；数值越大，纹理图案越大。更换纹理保留已绘制的分布。")
	ui.label(box,"原图 · 3×3 重复铺贴 · 独立地表预览")
	preview=preload("terrain_preview.gd").new(); box.add_child(preview)
	draft_status=ui.label(box,"")
	apply_button=guide.apply_button
	conversion_button=Button.new();box.add_child(conversion_button);conversion_button.hide()
	reset_button=ui.button(box,"还原未应用修改",func(): sync_target(true))
	ui.tool(box,"paint","绘制第 1 层")
	ui.number(box,"paint_radius","绘制半径（米）",0.2,64,0.1,4)
	ui.number(box,"paint_strength","绘制强度 / 秒",0.05,30,0.05,3)
	# Retain the original programmatic selection interface for older tooling.
	var layer := OptionButton.new(); for i in range(9): layer.add_item(str(i+1))
	box.add_child(layer); layer.hide(); ui.controls.layer=layer
	layer.item_selected.connect(select_layer)
	box=ui.section(root,"terrain.conform","贴地维护",false)
	var automatic: CheckBox=ui.check(box,"terrain_auto_conform","松开笔刷后自动贴地",bool(EditorInterface.get_editor_settings().get_project_metadata("hd2d_scene_tools","terrain_auto_conform",true)))
	automatic.toggled.connect(func(on): EditorInterface.get_editor_settings().set_project_metadata("hd2d_scene_tools","terrain_auto_conform",on))
	ui.button(box,"重新贴地：植物与道路",func(): controller.conform_scenery())
	ui.label(box,"自动贴地只在高度改变后执行；绘制地表不会移动植物或道路。")
	setup_creation()
	picker=preload("terrain_picker.gd").new(); ui.add_child(picker); picker.setup(controller,library)
	controller.shared_library.location_changed.connect(library_changed)
	controller.i18n.changed.connect(language_changed)
	ui.tree_exiting.connect(dispose,CONNECT_ONE_SHOT)
	var brush_values: Dictionary=EditorInterface.get_editor_settings().get_project_metadata("hd2d_scene_tools","terrain_brush",{})
	for key in ["radius","strength","level","paint_radius","paint_strength"]:
		if brush_values.has(key): ui.controls[key].set_value_no_signal(brush_values[key])
		ui.controls[key].value_changed.connect(func(value):
			var settings: Dictionary=EditorInterface.get_editor_settings().get_project_metadata("hd2d_scene_tools","terrain_brush",{})
			settings[key]=value; EditorInterface.get_editor_settings().set_project_metadata("hd2d_scene_tools","terrain_brush",settings))
	library_changed(); sync_target(true)

func language_changed() -> void:
	if not is_instance_valid(status): return
	refresh_draft(); refresh_status(); library_changed(); update_spacing(); update_creation_scheme()

func dispose() -> void:
	if guide: guide.dispose();guide=null
	if is_instance_valid(target) and target.data.changed.is_connected(terrain_data_changed): target.data.changed.disconnect(terrain_data_changed)
	if controller.i18n.changed.is_connected(language_changed): controller.i18n.changed.disconnect(language_changed)
	if controller.shared_library.location_changed.is_connected(library_changed): controller.shared_library.location_changed.disconnect(library_changed)

func setup_creation() -> void:
	creation=Window.new();creation.visible=false;creation.title="新建地图";creation.size=Vector2i(880,580);creation.min_size=Vector2i(800,540);creation.transient=true;creation.exclusive=true;ui.add_child(creation)
	var margin := MarginContainer.new();creation.add_child(margin);margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+edge,16)
	var content := VBoxContainer.new();margin.add_child(content)
	var columns := HBoxContainer.new();columns.size_flags_vertical=Control.SIZE_EXPAND_FILL;columns.add_theme_constant_override("separation",18);content.add_child(columns)
	var box := VBoxContainer.new();box.custom_minimum_size.x=380;box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(box)
	var right := VBoxContainer.new();right.custom_minimum_size.x=300;right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;columns.add_child(right)
	landform_preview=preload("landform_preview.gd").new(); right.add_child(landform_preview)
	landform_hint=ui.label(right,"")
	
	
	ui.option(box,"terrain_map_type","地图类型",["自由地图","循环舞台"]).item_selected.connect(func(index):
		if index==1: ui.controls.terrain_landform.select(0); update_landform())
	ui.option(box,"terrain_landform","地形形状",HD2DTerrainTemplates.TITLES).item_selected.connect(func(_i):
		if map_landform()!="flat": ui.controls.terrain_map_type.select(0)
		update_landform())
	ui.check(box,"terrain_create_liquid","生成独立水面／熔岩",true).toggled.connect(func(_v): update_landform())
	ui.number(box,"terrain_liquid_speed","水面／熔岩动画速度",0,3,0.05,0.35).value_changed.connect(func(_v): update_landform())
	ui.option(box,"terrain_size","地图每边长度（米）",[64,128,256,512,"自定义…"]).item_selected.connect(func(_i): update_spacing())
	ui.option(box,"terrain_resolution","每边高度点数",[129,257,513,"自定义…"]).item_selected.connect(func(_i): update_spacing())
	ui.number(box,"terrain_size_custom","自定义每边长度",1,4096,0.5,64).value_changed.connect(func(_v): update_spacing())
	ui.number(box,"terrain_resolution_custom","自定义高度点数",3,513,1,129).value_changed.connect(func(_v): update_spacing())
	spacing=ui.label(box,"")
	new_map_hint=ui.label(box,"边长是地图每边长度；高度点越多，雕刻越细。")
	create_scheme=ui.label(box,"初始地表：纯色"); create_scheme.set_meta("hd2d_managed_text",true)
	recommended_button=Button.new();box.add_child(recommended_button);recommended_button.hide()
	var actions := HBoxContainer.new();content.add_child(actions)
	plain_button=ui.button(actions,"使用纯色地表",use_plain_surface)
	scheme_button=ui.button(actions,"选择预设方案…",choose_creation_scheme)
	creation.close_requested.connect(cancel_creation)

	update_spacing(); update_landform()

func choose_creation_scheme() -> void:
	new_map_pending=true;creation_generation+=1
	var token := creation_generation
	creation.hide();ui.select_page("terrain");ui.sections["terrain.world"].set_expanded(true)
	picker.open_picker(true,-2,func(value):
		if token==creation_generation and new_map_pending:
			template_preset=value;update_creation_scheme())
	guide.invalidate()

func use_plain_surface() -> void:
	creation_generation+=1;creation_loading=false;new_map_pending=true;template_preset={}
	if is_instance_valid(picker):picker.cancel_selection()
	creation.hide();ui.select_page("terrain");ui.sections["terrain.world"].set_expanded(true)
	update_creation_scheme();guide.invalidate()

func cancel_creation() -> void:
	creation_generation+=1;creation_loading=false;new_map_pending=false;creation.hide()
	if is_instance_valid(picker):picker.cancel_selection()
	guide.invalidate()

func apply_current() -> void:
	if creation_loading or creation.visible:return
	if new_map_pending:
		if is_instance_valid(picker):picker.cancel_selection()
		creation_loading=true;guide.refresh()
		var created: bool=controller.create_template(ui.controls.terrain_map_type.selected==1)
		creation_loading=false
		if created:new_map_pending=false
		guide.invalidate()
	else:apply_draft()

func context_changed() -> void:
	creation_generation+=1;creation_loading=false;new_map_pending=false
	if is_instance_valid(creation):creation.hide()
	if is_instance_valid(picker):picker.cancel_selection()
	if guide:guide.invalidate()

func map_landform() -> String:
	return HD2DTerrainTemplates.IDS[ui.controls.terrain_landform.selected]

func update_landform() -> void:
	if not is_instance_valid(landform_hint): return
	var kind := map_landform()
	ui.controls.terrain_create_liquid.visible=kind!="flat"
	ui.controls.terrain_liquid_speed.get_parent().visible=kind!="flat" and ui.checked("terrain_create_liquid")
	recommended_button.hide()
	recommended_button.disabled=false
	controller.i18n.text(landform_hint,HD2DTerrainTemplates.DESCRIPTIONS[ui.controls.terrain_landform.selected])
	landform_preview.display(kind,template_preset,ui.checked("terrain_create_liquid"),ui.value("terrain_liquid_speed"),map_meters())
	if guide:guide.invalidate()
	fit_creation.call_deferred()

func prepare_recommended() -> void:
	creation_generation+=1; var token := creation_generation
	library.read_catalog()
	var id: String=HD2DTerrainTemplates.SCHEMES.get(map_landform(),"")
	for row in library.catalog.get("schemes",[]):
		if row.id!=id: continue
		recommended_button.disabled=true; creation_loading=true
		controller.i18n.text(create_scheme,"正在准备选中的地表纹理…")
		var value: Dictionary=await library.prepare(row,func(): return creation.visible and token==creation_generation)
		if token!=creation_generation: return
		recommended_button.disabled=false; creation_loading=false
		if value.is_empty(): controller.i18n.text(create_scheme,library.error); return
		template_preset=value; update_creation_scheme(); return
	controller.i18n.text(create_scheme,"此推荐方案尚未安装；可使用纯色或选择其他纹理。请在顶部检查共享素材库。")

func map_meters() -> float:
	return ui.value("terrain_size_custom") if ui.controls.terrain_size.selected==4 else float(ui.choice("terrain_size"))

func map_samples() -> int:
	return int(ui.value("terrain_resolution_custom")) if ui.controls.terrain_resolution.selected==3 else int(ui.choice("terrain_resolution"))

func update_creation_scheme() -> void:
	if not is_instance_valid(create_scheme): return
	var names := PackedStringArray()
	for value in template_preset.get("layer_names",[]): names.append(controller.i18n.t(value))
	create_scheme.text=controller.i18n.t("初始地表：%s")%" / ".join(names) if not names.is_empty() else controller.i18n.t("初始地表：纯色")
	update_landform()

func update_spacing() -> void:
	if not is_instance_valid(spacing): return
	ui.controls.terrain_size_custom.get_parent().visible=ui.controls.terrain_size.selected==4
	ui.controls.terrain_resolution_custom.get_parent().visible=ui.controls.terrain_resolution.selected==3
	var meters := map_meters(); var samples := map_samples()
	controller.i18n.text(spacing,"实际范围：%.1f × %.1f 米\n高度网格：%d × %d 点 · 点间距：%.3f 米"%[meters,meters,samples,samples,meters/(samples-1)])
	if is_instance_valid(landform_hint):update_landform()

func fit_creation() -> void:
	if not is_instance_valid(creation) or not creation.visible: return
	await controller.get_tree().process_frame
	if is_instance_valid(creation) and creation.visible: creation.reset_size()

func open_creation() -> void:
	controller._finish_stroke();new_map_pending=true;creation_generation+=1;creation_loading=false
	if is_instance_valid(picker):picker.cancel_selection()
	ui.select_page("terrain");ui.sections["terrain.world"].set_expanded(true)
	update_spacing();update_creation_scheme();creation.popup_centered(Vector2i(880,580));guide.invalidate()

func library_changed() -> void:
	library.read_catalog()

func capture(terrain: HD2DTerrain) -> Dictionary:
	return {"textures":terrain.data.textures.duplicate(),"layer_names":terrain.data.layer_names.duplicate(),"layer_preset_ids":terrain.data.layer_preset_ids.duplicate(),"texture_scale":terrain.data.texture_scale,"surface_material":terrain.surface_material,"layer_count":terrain.data.layer_count,"world_surface":terrain.world_data().active_surface if terrain is HD2DWorldMap else ""}

func sync_target(force: bool=false) -> void:
	var next: HD2DTerrain=controller.stage.terrain() if is_instance_valid(controller.stage) else null
	if target!=next:
		new_map_pending=false;creation_generation+=1
		if is_instance_valid(picker):picker.cancel_selection()
		if is_instance_valid(target) and target.data.changed.is_connected(terrain_data_changed): target.data.changed.disconnect(terrain_data_changed)
		if next and not next.data.changed.is_connected(terrain_data_changed): next.data.changed.connect(terrain_data_changed)
	if target!=next or force or (is_instance_valid(next) and capture(next)!=applied):
		revision+=1; target=next; convert=false
		applied=capture(target) if target else {}
		draft=applied.duplicate(); draft.textures=applied.get("textures",[]).duplicate()
		if target:
			draft.textures.resize(9); draft.layer_names.resize(9); draft.layer_preset_ids.resize(9)
			active_layer=mini(active_layer,int(draft.layer_count)-1); ui.controls.layer.select(active_layer)
		refresh_draft()
	refresh_status()

func terrain_data_changed() -> void:
	if is_instance_valid(status): sync_target.call_deferred()

func refresh_status() -> void:
	if guide: guide.refresh()
	ui.controls.terrain_only_view.disabled=not is_instance_valid(target)
	var text := "没有可编辑地形；点击新建地图，或选择包含地形的场景。"
	if is_instance_valid(target): text="当前地形：%s · %.1f 米 · %d×%d 采样\n活动工具：%s"%[target.name,target.data.size_m,target.data.resolution,target.data.resolution,controller.i18n.t({"raise":"升高","lower":"降低","smooth":"平滑","flatten":"平台","ramp":"坡道","paint":"绘制地表","select":"选择","village_place":"小镇蓝图","building_place":"建筑蓝图"}.get(controller.current_tool,controller.current_tool))]
	controller.i18n.text(status,text)
	if is_instance_valid(controller.toolbar):controller.toolbar.refresh()
	ui.controls.level.get_parent().visible=controller.current_tool in ["flatten","ramp"]

func is_dirty() -> bool:
	if not is_instance_valid(target) or applied.is_empty(): return false
	if convert or draft.layer_count!=applied.layer_count or not is_equal_approx(draft.texture_scale,applied.texture_scale): return true
	for i in range(int(draft.layer_count)):
		if layer_changed(i): return true
	return false

func layer_changed(index: int) -> bool:
	if not is_instance_valid(target): return false
	for key in ["textures","layer_names","layer_preset_ids"]:
		var old: Variant=applied[key][index] if applied[key].size()>index else (null if key=="textures" else "")
		if draft[key][index]!=old: return true
	return false

func select_layer(index: int) -> void:
	if controller.stroke: controller._finish_stroke()
	active_layer=clampi(index,0,int(draft.get("layer_count",4))-1); ui.controls.layer.select(active_layer); refresh_draft()

func layer_name(index: int) -> String:
	if not is_instance_valid(target) or not draft.textures[index]: return controller.i18n.t("未设置（纯色）")
	var value: String=draft.layer_names[index]
	if value.is_empty(): value=draft.textures[index].resource_name
	if value.is_empty(): value=draft.textures[index].resource_path.get_file().get_basename()
	return controller.i18n.t(value)

func refresh_draft() -> void:
	if not is_instance_valid(draft_status): return
	syncing=true
	var valid := is_instance_valid(target)
	var legacy := valid and target.surface_material!=null
	var dirty := is_dirty()
	if dirty and controller.current_tool=="paint": controller.set_tool("select")
	world_surface.visible=valid and target is HD2DWorldMap
	if world_surface.visible:
		world_surface.clear()
		for id in target.world_data().surface_specs:
			world_surface.add_item(str(id)); world_surface.set_item_metadata(world_surface.item_count-1,id)
			if id==target.world_data().active_surface: world_surface.select(world_surface.item_count-1)
	for i in range(9):
		layer_rows[i*2].visible=valid and i<int(draft.layer_count)
		layer_rows[i*2+1].visible=valid and i<int(draft.layer_count)
		controller.i18n.text(cards[i],"第 %d 层 · %s"%[i+1,layer_name(i)]+(" · "+controller.i18n.t("未应用") if layer_changed(i) else ""))
		cards[i].set_pressed_no_signal(i==active_layer); cards[i].disabled=not valid
		thumbs[i].texture=draft.textures[i] if valid else null
	add_layer_button.disabled=not valid or legacy or int(draft.get("layer_count",4))>=8
	for button in edit_buttons: button.disabled=not valid or (legacy and not convert)
	ui.controls.texture_scale.editable=valid and (not legacy or convert)
	if valid: ui.controls.texture_scale.set_value_no_signal(draft.texture_scale)
	legacy_hint.visible=legacy; preview_conversion_button.visible=legacy
	conversion_button.hide()
	reset_button.disabled=not dirty
	controller.i18n.text(draft_status,"未应用：先应用或还原，再绘制地表。" if dirty else ("旧复合材质：先预览并转换，才能绘制四层。" if legacy else "已应用；选择一层后点击绘制。"))
	controller.i18n.text(ui.tool_buttons.paint,"绘制第 %d 层"%(active_layer+1))
	ui.tool_buttons.paint.disabled=not valid or dirty or legacy
	if valid: preview.display(draft.textures.slice(0,int(draft.layer_count)),target.data.colors,draft.texture_scale,active_layer,null if convert else target.surface_material)
	preview.visible=valid
	syncing=false
	if guide:guide.invalidate()

func open_presets(layer: int) -> void:
	if not is_instance_valid(target): return
	new_map_pending=false;creation_generation+=1;creation_loading=false;guide.invalidate()
	var expected := revision
	picker.open_picker(layer<0,layer,func(value):
		if expected!=revision or not is_instance_valid(target): return
		set_draft_textures(layer,value))

func choose_local(layer: int) -> void:
	var expected := revision
	ui.pick(["*.png,*.jpg,*.webp ; 地表纹理"],false,func(paths):
		var texture: Texture2D=await controller.project_resource(paths[0]) as Texture2D
		if texture and expected==revision and is_instance_valid(target):
			set_draft_textures(layer,{"textures":[texture],"layer_names":PackedStringArray([str(paths[0]).get_file().get_basename()]),"layer_preset_ids":PackedStringArray([""])}))

func set_draft_textures(layer: int, value: Dictionary) -> void:
	if layer<0:
		for i in range(value.textures.size()):
			draft.textures[i]=value.textures[i]; draft.layer_names[i]=value.layer_names[i]; draft.layer_preset_ids[i]=value.layer_preset_ids[i]
		draft.layer_count=maxi(int(draft.layer_count),value.textures.size()); draft.texture_scale=value.texture_scale
	else:
		draft.textures[layer]=value.textures[0]; draft.layer_names[layer]=value.layer_names[0]; draft.layer_preset_ids[layer]=value.layer_preset_ids[0]
	refresh_draft()

func apply_draft() -> void:
	if not is_dirty(): return
	controller._finish_stroke()
	var after := draft.duplicate(); after.textures=draft.textures.slice(0,int(draft.layer_count))
	after.layer_names=draft.layer_names.slice(0,int(draft.layer_count)); after.layer_preset_ids=draft.layer_preset_ids.slice(0,int(draft.layer_count))
	if convert: after.surface_material=null
	var undo: EditorUndoRedoManager=controller.get_undo_redo()
	undo.create_action(controller.i18n.t("改用四层地表" if convert else "应用地表设置"),UndoRedo.MERGE_DISABLE,controller.stage)
	undo.add_do_method(self,"apply_state",target,after)
	undo.add_undo_method(self,"apply_state",target,applied)
	undo.commit_action()

func apply_state(terrain: HD2DTerrain, state: Dictionary) -> void:
	if not is_instance_valid(terrain): return
	if terrain is HD2DWorldMap: terrain.world_data().select_surface(state.world_surface)
	var geometry_format_changed: bool=(terrain.data.layer_count>4)!=(int(state.layer_count)>4)
	terrain.data.layer_count=int(state.layer_count); terrain.data.ensure_extra_weights()
	terrain.data.textures.assign(state.textures); terrain.data.layer_names=state.layer_names.duplicate()
	terrain.data.layer_preset_ids=state.layer_preset_ids.duplicate(); terrain.data.texture_scale=state.texture_scale
	terrain.surface_material=state.surface_material; terrain.update_material()
	if geometry_format_changed:
		for key in terrain.chunks: terrain._build_chunk(key,false)
	if not terrain.data.resource_path.is_empty() and not terrain.data.resource_path.contains("::"): controller.external_dirty[terrain.data]=true
	EditorInterface.mark_scene_as_unsaved()
	if target==terrain: sync_target(true)

func add_layer() -> void:
	if not is_instance_valid(target) or int(draft.layer_count)>=8: return
	draft.layer_count+=1; active_layer=int(draft.layer_count)-1; ui.controls.layer.select(active_layer)
	refresh_draft()
