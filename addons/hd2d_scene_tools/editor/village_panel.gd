@tool
extends RefCounted
const Catalog=preload("building_catalog.gd")
const Presets=preload("building_presets.gd")
const Generator=preload("building_generator.gd")
const TerrainPlan=preload("village_terrain.gd")
const Materials=preload("../runtime/building_materials.gd")
const Layout=preload("village_layout.gd")
var placement
var controller
var ui
var palette: Array=[]
var styles: Array=JSON.parse_string(FileAccess.get_file_as_string("res://addons/hd2d_scene_tools/editor/village_styles.json"))
var list: ItemList
var front: SpinBox
var status: Label
var building_list: Label
var preview
var generate_button: Button
var replace_button: Button
var confirmation: ConfirmationDialog
var target: HD2DVillage
var preview_stage: HD2DStage
var prepared: Dictionary={}
var busy := false
var disposed := false
var placement_center := Vector2.ZERO
var loading := false
var request_serial := 0
var loaded_style := ""
var native_generator_version := Catalog.VERSION
var native_preset_version := Catalog.VERSION
var composition
var legacy_shape_controls: Array=[]
var footer: PanelContainer
var debounce: Timer
var generation_serial := 0
var preview_commits := 0
var cached_plan_key := ""
var max_slice_ms := 0.0
var phase_ms := {}
var cached_plan := {}
var cached_layout_key := ""
var cached_layout := {}
var watched_data: Resource
var terrain_revision := 0

func setup(plugin, root: VBoxContainer, dock_ui) -> void:
	controller=plugin; ui=dock_ui
	# Basic choices precede the preview; the page-wide fold actions live below it.
	var fold_actions: Node=root.get_child(0)
	root.remove_child(fold_actions)
	var box: VBoxContainer=ui.section(root,"generation.palette","建筑风格",true)
	styles=[{"id":"native-jiangnan","title":"内置 · 江南古镇","native":"jiangnan","color":"b5b0a0"},{"id":"native-forest","title":"内置 · 欧式风格","native":"forest","color":"81715c"},{"id":"native-desert","title":"内置 · 沙漠聚落","native":"desert","color":"b89968"}]+styles
	for style in styles:
		if not style.has("native"): style.title+="（共享库）"
	var titles: Array=[]
	for style in styles: titles.append(style.title)
	titles.append("自定义建筑组合")
	inline_option(box,"village_style","建筑风格",titles).item_selected.connect(select_style)
	ui.check(box,"village_walls","添加围墙（主路两端留门）",false).toggled.connect(func(_v): invalidate())
	box=ui.section(root,"generation.preview","小镇实时预览",true)
	preview=preload("village_model_preview.gd").new(); box.add_child(preview)
	ui.label(box,"拖动旋转，滚轮缩放 · 应用后才写入场景。")
	var row := HBoxContainer.new(); box.add_child(row)
	ui.button(row,"换一个随机种子",func(): ui.controls.village_seed.value=randi_range(0,2147483647)).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	ui.button(row,"刷新预览",func():
		if palette.is_empty(): select_style(ui.controls.village_style.selected)
		else: prepare()).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	root.add_child(fold_actions)
	box=ui.section(root,"generation.layout","布局与自定义建筑",false)
	ui.option(box,"village_layout","小镇排布",["双排街村","单排街村","中心环绕"])
	ui.option(box,"village_center_type","城镇中心",["沿街贯通","中央广场","中心建筑"])
	ui.controls.village_layout.item_selected.connect(func(index):
		ui.controls.village_center_type.set_item_disabled(2,index!=2)
		if index!=2 and ui.controls.village_center_type.selected==2: ui.controls.village_center_type.select(1))
	for key in ["layout","center_type"]: ui.controls["village_"+key].item_selected.connect(func(_index): invalidate())
	for spec in [["count","建筑数量",1,24,1,8],["seed","随机种子",0,2147483647,1,12345],["road_width","主路宽度（米）",1,12,0.5,3],["gap","建筑间隔（米）",0.5,12,0.5,2],["setback","门前退距（米）",0.5,12,0.5,2],["yaw","村落方向（度）",-180,180,5,0],["wall_height","围墙高度（米）",0.5,5,0.1,1.8],["wall_margin","围墙退距（米）",1,10,0.5,2],["max_slope","最大地基高差（米）",0,3,0.05,0.5]]:
		ui.number(box,"village_"+spec[0],spec[1],spec[2],spec[3],spec[4],spec[5]).value_changed.connect(func(_v): invalidate())
	ui.check(box,"village_collision","生成建筑碰撞",true).toggled.connect(func(_on): invalidate())
	ui.label(box,"预览包含局部整地；应用后才修改地形。外部模型保持原尺寸。")
	ui.check(box,"village_style_ground","纯色地表使用配套底材",true).toggled.connect(func(_v): invalidate())
	ui.check(box,"village_grade","预览局部整地",true).toggled.connect(func(_v): invalidate())
	ui.option(box,"village_paving_mode","道路铺装",["地表自动分配空层","使用已有地表层","贴地像素铺装网格"]).item_selected.connect(func(_v): invalidate())
	for spec in [["rings","建筑圈数",1,3,1,2],["spokes","连接道路（2 或 4）",2,4,2,2],["foundation_margin","地基边距（米）",0,2,0.1,0.3],["blend","整地过渡（米）",0.5,8,0.5,2],["paving_layer","铺装使用第几层",1,8,1,1]]:
		ui.number(box,"village_"+spec[0],spec[1],spec[2],spec[3],spec[4],spec[5]).value_changed.connect(func(_v): invalidate())
	ui.label(box,"内置建筑外形与外观；现成模型不受外形参数影响。")
	for spec in [["width","建筑宽度",3,10,0.25,4.5],["depth","建筑深度",3,10,0.25,4],["floors","楼层数",1,3,1,1],["pitch","屋顶坡度",15,50,1,32],["eave","屋檐宽度",0.1,1,0.05,0.45],["windows","每面窗列",1,4,1,2],["shape_seed","外形种子",0,2147483647,1,60421],["detail_seed","细节种子",0,2147483647,1,101],["appearance_seed","外观种子",0,2147483647,1,101]]:
		var control: SpinBox = ui.number(box,"village_"+spec[0],spec[1],spec[2],spec[3],spec[4],spec[5])
		control.value_changed.connect(func(_v): rebuild_native())
		if spec[0] not in ["shape_seed","detail_seed","appearance_seed"]: legacy_shape_controls.append(control.get_parent())
	var roof_control: OptionButton = ui.option(box,"village_roof","屋顶形态",["按风格","双坡屋顶","平顶露台"])
	legacy_shape_controls.append(roof_control);legacy_shape_controls.append(box.get_child(roof_control.get_index()-1))
	roof_control.item_selected.connect(func(_v): rebuild_native())
	var porch_control: CheckBox = ui.check(box,"village_porch","门廊",true)
	legacy_shape_controls.append(porch_control);porch_control.toggled.connect(func(_v): rebuild_native())
	ui.option(box,"village_appearance","建筑外观",["原色","素雅","暖色","风化"]).item_selected.connect(func(_v): rebuild_native())
	ui.controls.village_max_slope.value=2
	ui.controls.village_layout.select(2);ui.controls.village_center_type.select(1)
	composition=preload("building_composition.gd").new();composition.setup(self,box)
	ui.label(box,"自定义建筑：可在预设基础上增删；不会修改共享库。")
	ui.button(box,"选择建筑素材…",func(): controller.workbench.open_objects())
	ui.button(box,"加入工作台选中素材",add_workbench_asset)
	ui.button(box,"加入当前场景建筑",add_scene_assets)
	list=ItemList.new(); list.custom_minimum_size.y=90; box.add_child(list)
	list.item_selected.connect(func(index): front.set_value_no_signal(palette[index].front))
	front=ui.number(box,"village_front","选中素材正面角度（度）",-180,180,90,0)
	front.value_changed.connect(func(value):
		if list.get_selected_items().is_empty(): return
		palette[list.get_selected_items()[0]].front=value; make_custom(); invalidate())
	ui.button(box,"移除选中素材",func():
		if list.get_selected_items().is_empty(): return
		palette.remove_at(list.get_selected_items()[0]); make_custom(); refresh_list(); invalidate())
	building_list=ui.label(box,""); building_list.set_meta("hd2d_managed_text",true)
	# Native VBox sibling of the scrolling operations: always visible on this module.
	footer=PanelContainer.new(); footer.name="VillageApplyFrame"; footer.theme_type_variation="JeffApplyFrame"; ui.add_child(footer)
	var actions := VBoxContainer.new(); footer.add_child(actions)
	status=ui.label(actions,""); status.max_lines_visible=3; status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	generate_button=ui.button(actions,"应用到场景（新建小镇）",func(): placement.begin())
	generate_button.theme_type_variation="JeffPrimaryButton"
	row=HBoxContainer.new(); actions.add_child(row)
	replace_button=ui.button(row,"应用到选中小镇…",request_replace); replace_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	ui.button(row,"读取选中村落",read_selected).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	confirmation=ConfirmationDialog.new(); confirmation.title="重新生成村落"; confirmation.dialog_text="将替换选中村落内的建筑、道路和围墙，包括手动修改。其他物件保持不变；整批可撤销。"; confirmation.ok_button_text="重新生成"
	ui.add_child(confirmation); confirmation.confirmed.connect(func(): commit(true))
	debounce=Timer.new(); debounce.one_shot=true; debounce.wait_time=0.25; ui.add_child(debounce); debounce.timeout.connect(prepare)
	ui.tabs.tab_changed.connect(func(_index): page_changed())
	controller.shared_library.location_changed.connect(library_changed)
	ui.tree_exiting.connect(func():
		dispose()
		if controller.shared_library.location_changed.is_connected(library_changed): controller.shared_library.location_changed.disconnect(library_changed))
	placement=preload("village_placement.gd").new();placement.setup(self)
	footer.hide(); invalidate()

func inline_option(parent: VBoxContainer, key: String, title: String, choices: Array) -> OptionButton:
	var row := HBoxContainer.new(); parent.add_child(row)
	var label: Label=ui.label(row,title); label.custom_minimum_size.x=72*EditorInterface.get_editor_scale(); label.autowrap_mode=TextServer.AUTOWRAP_OFF
	var choice := OptionButton.new(); choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL; choice.fit_to_longest_item=false; choice.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	for item in choices:
		choice.add_item(item); choice.set_item_metadata(choice.item_count-1,item)
	row.add_child(choice); ui.controls[key]=choice
	return choice

func dispose() -> void:
	disposed=true; request_serial+=1; generation_serial+=1; loading=false
	if is_instance_valid(watched_data) and watched_data.changed.is_connected(terrain_changed): watched_data.changed.disconnect(terrain_changed)
	if composition: composition.panel=null;composition=null
	cancel_placement()
	if placement: placement.dispose()
	if is_instance_valid(debounce): debounce.stop()
	if is_instance_valid(preview): preview.clear_preview()

func say(text: String) -> void:
	controller.i18n.text(status,text)
	status.tooltip_text=controller.i18n.t(text)

func page_changed() -> void:
	cancel_placement()
	footer.visible=ui.tabs.current_tab==ui.page_index("generation")
	if not footer.visible:
		request_serial+=1; generation_serial+=1; loading=false; debounce.stop(); return
	if palette.is_empty(): select_style(ui.controls.village_style.selected)
	else: invalidate()

func library_changed() -> void:
	cancel_placement()
	request_serial+=1; loading=false
	if ui.controls.village_style.selected<styles.size():
		palette.clear(); loaded_style=""; refresh_list(); preview.clear_preview()
	invalidate()
	if footer.visible and palette.is_empty(): select_style(ui.controls.village_style.selected)

func select_style(index: int) -> void:
	generation_serial+=1
	cancel_placement()
	if disposed: return
	debounce.stop()
	request_serial+=1
	var serial := request_serial
	loading=false; loaded_style=""; prepared={}
	generate_button.disabled=true; replace_button.disabled=true
	if index>=styles.size(): invalidate(); return
	palette.clear(); refresh_list()
	loading=true; say("正在准备建筑风格…")
	if styles[index].has("native"):
		loaded_style=styles[index].id;native_generator_version=Catalog.VERSION;native_preset_version=Catalog.VERSION;loading=false
		composition.reset()
		var defaults := Presets.sample(str(styles[index].native))
		for key in ["width","depth","floors","pitch","eave","windows"]: ui.controls["village_"+key].set_value_no_signal(defaults[key])
		ui.controls.village_roof.select(defaults.roof);ui.controls.village_porch.set_pressed_no_signal(defaults.porch)
		rebuild_native();return
	var source_root: String=controller.shared_library.root_path()
	var catalog: Dictionary=controller.shared_library.read_index()
	var chosen: Dictionary=styles[index]
	var next_palette: Array=[]
	var current := func(): return not disposed and is_instance_valid(ui) and ui.is_inside_tree() and serial==request_serial and source_root==controller.shared_library.root_path()
	for id in chosen.assets:
		var records: Array=catalog.get("entries",[]).filter(func(record): return record.id==id)
		if records.is_empty():
			loading=false; say("此风格素材未安装；连接完整共享库后刷新预览。缺少：%s"%str(id)); return
		var asset: HD2DAsset=await controller.shared_library.prepare(records[0],current,func(message):
			if current.call(): say(message))
		if not current.call(): return
		if asset==null: loading=false; say(controller.shared_library.error); return
		next_palette.append({"asset":asset,"skin":&"","front":0.0})
	palette=next_palette; loaded_style=chosen.id; loading=false; refresh_list(); prepare()

func make_custom() -> void:
	request_serial+=1; loading=false; loaded_style=""; ui.controls.village_style.select(styles.size())

func cancel_placement() -> void:
	if placement and placement.active: controller.set_tool("select")

func invalidate() -> void:
	generation_serial+=1
	cancel_placement()
	prepared={}
	if generate_button: generate_button.disabled=true; replace_button.disabled=true
	if status: say("草稿更新中；尚未修改场景。")
	if debounce and footer.visible and not loading: debounce.start()

func context_changed() -> void:
	request_serial+=1; loading=false
	target=null; preview_stage=null; placement_center=Vector2.ZERO; confirmation.hide(); invalidate()
	if footer.visible and palette.is_empty(): select_style.call_deferred(ui.controls.village_style.selected)

func refresh_list() -> void:
	list.clear()
	for item in palette: list.add_item(item.asset.title,item.asset.thumbnail)

func add_asset(asset: HD2DAsset, skin: StringName=&"") -> void:
	if asset==null: say("请先在素材工作台选中模型并等待预览完成。"); return
	if asset.source is Texture2D or asset.source_missing(): say("村落需要依赖完整的实体模型；图片贴片不能作为建筑。"); return
	for item in palette:
		if item.asset.same_entry(asset) and item.skin==skin: say("该素材和皮肤已经加入。"); return
	make_custom(); palette.append({"asset":asset,"skin":skin,"front":0.0}); refresh_list(); invalidate()

func add_workbench_asset() -> void: add_asset(ui.preset_panel.selected_asset,ui.preset_panel.skin_id)

func add_scene_assets() -> void:
	if not controller.require_stage(): return
	if controller.stage.library:
		for asset in controller.stage.library.assets:
			if asset and asset.category.to_lower() in ["建筑","building","buildings","architecture"]: add_asset(asset)
	if palette.is_empty(): say("当前场景没有建筑分类素材，请从工作台逐项加入。")

func options() -> Dictionary:
	var result := {"layout":ui.controls.village_layout.selected,"center_type":ui.controls.village_center_type.selected,"walls":ui.checked("village_walls"),"collision":ui.checked("village_collision"),"style":loaded_style,"wall_color":"a49b88"}
	for style in styles:
		if style.id==loaded_style: result.wall_color=style.color
	for key in ["count","seed","road_width","gap","setback","yaw","max_slope","wall_height","wall_margin","rings","spokes","foundation_margin","blend","paving_layer","width","depth","floors","pitch","eave","windows","shape_seed","appearance_seed"]: result[key]=ui.value("village_"+key)
	result.x=placement_center.x;result.z=placement_center.y
	result.style_ground=ui.checked("village_style_ground");result.grade=ui.checked("village_grade");result.paving_mode=ui.controls.village_paving_mode.selected
	result.roof=ui.controls.village_roof.selected;result.porch=ui.checked("village_porch");result.appearance=ui.controls.village_appearance.selected
	if native_generator_version>=4 and loaded_style.begins_with("native-"):
		result.building_types=composition.selected.duplicate();result.building_weights=composition.weights.duplicate()
		result.palette_sequence=composition.sequence.duplicate();result.detail_seed=ui.value("village_detail_seed")
	result.material_style=loaded_style.trim_prefix("native-") if loaded_style.begins_with("native-") else "jiangnan"
	return result

func world_transform(terrain: HD2DTerrain) -> Transform3D:
	var settings := options()
	return terrain.global_transform*Transform3D(Basis(Vector3.UP,deg_to_rad(settings.yaw)),Vector3(settings.x,0,settings.z))

func checked_plan() -> Dictionary:
	if not is_instance_valid(controller.stage): return {"error":"请先新建或选择地形。"}
	var terrain: HD2DTerrain=controller.stage.terrain()
	if terrain==null: return {"error":"请先新建或选择地形。"}
	var layout := Layout.plan(palette,options())
	if not layout.error.is_empty(): return layout
	return Layout.validate(layout,terrain,world_transform(terrain),controller.stage,target if is_instance_valid(target) and controller.stage.is_ancestor_of(target) else null)

func terrain_changed() -> void:
	terrain_revision+=1;cached_plan_key=""
	invalidate()

func prepare() -> void:
	if disposed or (placement and placement.active) or loading: return
	debounce.stop();generation_serial+=1
	max_slice_ms=0.0;phase_ms={}
	var serial := generation_serial
	var current := func(): return not disposed and is_instance_valid(ui) and ui.is_inside_tree() and serial==generation_serial and footer.visible
	prepared={};generate_button.disabled=true;replace_button.disabled=true
	var classified := native_generator_version>=4 and loaded_style.begins_with("native-")
	composition.root.visible=classified
	for control in legacy_shape_controls: control.visible=not classified
	if classified:
		var ready: bool=await composition.prepare(current)
		if not current.call(): return
		if not ready: say(composition.error);return
	if not current.call(): return
	var terrain: HD2DTerrain=controller.stage.terrain() if is_instance_valid(controller.stage) else null
	var data: Resource=terrain.data if terrain else null
	if data!=watched_data:
		if is_instance_valid(watched_data) and watched_data.changed.is_connected(terrain_changed): watched_data.changed.disconnect(terrain_changed)
		watched_data=data;terrain_revision+=1;cached_plan_key=""
		if watched_data: watched_data.changed.connect(terrain_changed)
	var settings := options().duplicate(true)
	for field in ["appearance","appearance_seed"]: settings.erase(field)
	var identities: Array=[]
	for item in palette:
		identities.append([preload("building_cache.gd").geometry_key(item.asset.building_profile) if item.asset.building_profile else item.asset.get_instance_id(),item.get("front",0.0)])
	var key := var_to_str([settings,identities,terrain_revision,terrain.global_transform if terrain else Transform3D.IDENTITY,target.get_instance_id() if is_instance_valid(target) else 0])
	var draft: Dictionary
	var checked: Dictionary
	if key==cached_plan_key:
		draft=cached_plan.draft;checked=cached_plan.checked
	else:
		var start := Time.get_ticks_usec()
		var layout_options := {}
		for field in ["count","layout","seed","center_type","gap","road_width","setback","rings","spokes","walls","wall_margin","wall_height","palette_sequence"]:
			layout_options[field]=settings.get(field)
		var layout_key := var_to_str([identities,layout_options])
		if layout_key==cached_layout_key:
			draft=cached_layout.duplicate(true);draft.options=options()
		else:
			draft=Layout.plan(palette,options());phase_ms.layout=(Time.get_ticks_usec()-start)/1000.0
			max_slice_ms=maxf(max_slice_ms,phase_ms.layout)
			if str(draft.error).is_empty(): cached_layout=draft.duplicate(true);cached_layout_key=layout_key
		if not str(draft.error).is_empty(): say(draft.error);return
		# Yield before terrain planning; stale requests cannot publish their result.
		await ui.get_tree().process_frame
		if not current.call(): return
		start=Time.get_ticks_usec()
		checked=Layout.validate(draft,terrain,world_transform(terrain),controller.stage,target if is_instance_valid(target) and controller.stage.is_ancestor_of(target) else null) if terrain and terrain.data else {"error":"请先新建或选择地形。"}
		phase_ms.terrain=(Time.get_ticks_usec()-start)/1000.0;max_slice_ms=maxf(max_slice_ms,phase_ms.terrain)
		cached_plan_key=key;cached_plan={"draft":draft,"checked":checked}
	if not current.call(): return
	# Cached planning owns private draft resources; refresh only their generated materials.
	var look_settings := options()
	for plan in [draft,checked]:
		if plan.has("options"):
			plan.options.appearance=look_settings.appearance;plan.options.appearance_seed=look_settings.appearance_seed
	if checked.has("draft_terrain"):
		var terrain_draft: HD2DTerrainData=checked.draft_terrain
		for i in terrain_draft.layer_preset_ids.size():
			var id: String=terrain_draft.layer_preset_ids[i]
			var prior_textures: Array=checked.terrain_patch.layers_before.textures
			if id.begins_with("builtin-v1/") and i<terrain_draft.textures.size() and (i>=prior_textures.size() or prior_textures[i]!=terrain_draft.textures[i]):
				terrain_draft.textures[i]=Materials.texture(look_settings.material_style,id.get_slice("/",2),int(look_settings.appearance),int(look_settings.appearance_seed))
		checked.terrain_patch.layers_after.textures=terrain_draft.textures.duplicate()
	var ok := str(checked.get("error","")).is_empty()
	var preview_start := Time.get_ticks_usec()
	preview.show_village(checked if ok else draft,palette,key);preview_commits+=1
	phase_ms.preview=(Time.get_ticks_usec()-preview_start)/1000.0;max_slice_ms=maxf(max_slice_ms,phase_ms.preview)
	var names := PackedStringArray()
	for i in draft.entries.size(): names.append("%d. %s"%[i+1,palette[draft.entries[i].palette].asset.title])
	building_list.text="\n".join(names)
	generate_button.disabled=terrain==null or terrain.data==null or terrain is HD2DWorldMap
	if not ok: say(checked.error);return
	prepared=checked;preview_stage=controller.stage;generate_button.disabled=false
	replace_button.disabled=not is_instance_valid(target) or not target.is_inside_tree()
	say(("%d 栋建筑 · %.1f × %.1f 米 · 尚未应用"%[draft.entries.size(),draft.extent.size.x,draft.extent.size.y])+("\n"+str(checked.road_notice) if checked.has("road_notice") else ""))

func read_selected() -> void:
	cancel_placement()
	var found: Node=controller.selection
	while is_instance_valid(found) and not found is HD2DVillage: found=found.get_parent()
	if not found is HD2DVillage: say("请在场景树选中村落或它的建筑。 "); return
	if int(found.recipe.get("version",0)) not in [1,Layout.VERSION]: say("此村落配方版本无法读取。"); return
	target=found
	request_serial+=1; loading=false
	palette=target.recipe.palette.duplicate(true)
	native_generator_version=int(target.recipe.get("generator_version",1));native_preset_version=int(target.recipe.get("preset_version",1))
	loaded_style=str(target.recipe.options.get("style",""))
	composition.restore(target.recipe.options)
	if native_generator_version>=4:
		composition.sequence=target.recipe.options.get("palette_sequence",[]).duplicate()
	ui.controls.village_style.select(styles.size())
	for i in styles.size():
		if styles[i].id==loaded_style: ui.controls.village_style.select(i)
	ui.controls.village_walls.set_pressed_no_signal(false); ui.controls.village_center_type.select(0)
	for key in target.recipe.options:
		if key=="style": continue
		var control: Control=ui.controls.get("village_"+key)
		if control is SpinBox: control.set_value_no_signal(target.recipe.options[key])
		elif control is OptionButton: control.select(target.recipe.options[key])
		elif control is CheckBox: control.set_pressed_no_signal(target.recipe.options[key])
	# Preserve a manually moved/rotated village's current placement.
	var relative: Transform3D=controller.stage.terrain().global_transform.affine_inverse()*target.global_transform
	placement_center=Vector2(relative.origin.x,relative.origin.z)
	ui.controls.village_yaw.set_value_no_signal(rad_to_deg(relative.basis.get_euler().y))
	composition.remember_loaded()
	cached_plan_key=""
	refresh_list(); invalidate()

func request_replace() -> void:
	if prepared.is_empty() or not is_instance_valid(target) or controller.stage!=preview_stage: return
	confirmation.popup_centered(Vector2i(500,180))

func build_node(data: Dictionary) -> HD2DVillage:
	var village := HD2DVillage.new(); village.name="Village"
	village.recipe={"version":Layout.VERSION,"palette":palette.duplicate(true),"options":options(),"generator_version":native_generator_version,"preset_version":native_preset_version}
	for i in data.entries.size():
		var entry: Dictionary=data.entries[i]; var item: Dictionary=palette[entry.palette]
		var prop := HD2DProp.new(); prop.name="Building_%02d"%(i+1); prop.asset=item.asset; prop.skin_id=item.skin
		prop.asset_overrides={"wind":0.0,"static_collision":ui.checked("village_collision"),"collision_mode":0}
		prop.transform=Transform3D(entry.basis,entry.position); village.add_child(prop)
	# Terrain paving or a single union mesh replaces overlapping road strips.
	if data.has("draft_terrain"):
		preload("village_structures.gd").add_paving(village,data)
		village.recipe.terrain_patch=data.terrain_patch
	else:
		for i in data.roads.size():
			var entry: Dictionary=data.roads[i];var road := HD2DRoad.new();road.name="Road_%02d"%i
			road.width=entry.width;road.curve=Curve3D.new();road.texture=Materials.texture(str(data.options.get("material_style","jiangnan")),"paving")
			for point in entry.points: road.curve.add_point(point)
			village.add_child(road)
	preload("village_structures.gd").add_walls(village,data,ui.checked("village_collision"))
	return village

func attach(parent: Node3D, village: HD2DVillage, owner: Node, terrain: HD2DTerrain) -> void:
	parent.add_child(village,true); village.owner=owner
	for child in village.get_children():
		set_owner_tree(child,owner)
		if child is HD2DRoad: child.terrain_path=child.get_path_to(terrain); child.rebuild()

func set_owner_tree(node: Node, owner: Node) -> void:
	node.owner=owner
	# Prop / Road render children are generated and must not be serialized.
	if node is HD2DProp or node is HD2DRoad: return
	for child in node.get_children(): set_owner_tree(child,owner)

func commit(replace: bool) -> void:
	if busy or prepared.is_empty() or not is_instance_valid(preview_stage) or controller.stage!=preview_stage: invalidate(); return
	if replace and (not is_instance_valid(target) or not target.is_inside_tree() or not controller.stage.is_ancestor_of(target)): invalidate(); return
	# A duplicate new village must not ignore the previously read target.
	var old_target := target
	if not replace: target=null
	var checked := checked_plan()
	target=old_target
	if not str(checked.get("error","")).is_empty():
		if not placement or not placement.active: invalidate()
		say(checked.error); return
	# Recheck terrain/obstacles immediately before committing, even if the preview is old.
	busy=true
	# Saved output is portable runtime data, not an editor cache or source-library mutation.
	var directory := "res://hd2d_generated/"+str(Time.get_unix_time_from_system()).replace(".","_")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for item in palette:
		if item.asset.building_profile:
			var asset_file := directory.path_join(item.asset.building_profile.identity()+".res")
			if ResourceSaver.save(item.asset,asset_file,ResourceSaver.FLAG_CHANGE_PATH)!=OK:
				busy=false;say("生成资源保存失败，请检查工程目录权限。");return
	if checked.has("draft_terrain"):
		if ResourceSaver.save(checked.draft_terrain,directory.path_join("terrain.res"),ResourceSaver.FLAG_CHANGE_PATH)!=OK:
			busy=false;say("生成资源保存失败，请检查工程目录权限。");return
	if placement and placement.active: placement.stop(false)
	controller.set_tool("select")
	var village := build_node(checked)
	var stage: HD2DStage=controller.stage
	var parent := target.get_parent() as Node3D if replace else stage.get_node_or_null("Scenery") as Node3D
	if parent==null: village.free(); busy=false; invalidate(); return
	village.transform=parent.global_transform.affine_inverse()*world_transform(stage.terrain())
	var owner: Node=EditorInterface.get_edited_scene_root()
	var undo: EditorUndoRedoManager=controller.get_undo_redo()
	undo.create_action(controller.i18n.t("生成村落"),UndoRedo.MERGE_DISABLE,stage)
	if replace:
		undo.add_do_method(parent,"remove_child",target)
		undo.add_undo_method(self,"attach",parent,target,owner,stage.terrain())
		undo.add_undo_reference(target)
	var library := stage.library.duplicate() as HD2DAssetLibrary if stage.library else HD2DAssetLibrary.new()
	library.assets=library.assets.duplicate()
	for item in palette:
		if not library.assets.any(func(asset): return asset and asset.same_entry(item.asset)): library.assets.append(item.asset)
	undo.add_do_property(stage,"library",library); undo.add_undo_property(stage,"library",stage.library)
	if checked.has("terrain_patch"):
		var terrain := stage.terrain();var prior := terrain.data
		# Private applied resource avoids changing another scene sharing this data.
		var next: HD2DTerrainData=checked.draft_terrain
		undo.add_do_property(terrain,"data",next);undo.add_undo_property(terrain,"data",prior)
		undo.add_do_method(self,"conform",stage);undo.add_undo_method(controller,"restore_conform",stage,controller.capture_conform(stage))
	undo.add_do_method(self,"attach",parent,village,owner,stage.terrain())
	undo.add_undo_method(parent,"remove_child",village); undo.add_do_reference(village)
	undo.add_do_method(controller,"refresh_scene_assets"); undo.add_undo_method(controller,"refresh_scene_assets")
	undo.commit_action()
	target=village; busy=false; invalidate(); controller.mark_changed()
	EditorInterface.get_selection().clear(); EditorInterface.get_selection().add_node(village)
	say("村落已生成；可逐件编辑。Ctrl+Z / Cmd+Z 撤销整批，Ctrl+S / Cmd+S 保存。")

func conform(stage: HD2DStage) -> void:
	if is_instance_valid(stage): stage.conform_scenery()

func rebuild_native() -> void:
	if not loaded_style.begins_with("native-"): invalidate();return
	if native_generator_version>=4:
		invalidate();return
	palette.clear()
	for index in (9 if native_generator_version>=2 else 3):
		var kind := index%3 if native_generator_version>=2 else index
		var variation := index/3 if native_generator_version>=2 else 0
		var profile := HD2DBuildingProfile.new();profile.style=loaded_style.trim_prefix("native-");profile.kind=kind
		profile.generator_version=native_generator_version;profile.preset_version=native_preset_version
		profile.shape_seed=int(ui.value("village_shape_seed"))+variation*7919;profile.appearance_seed=int(ui.value("village_appearance_seed"))
		for key in ["width","depth","floors","pitch","eave","windows"]:profile.parameters[key]=ui.value("village_"+key)
		profile.parameters.roof=ui.controls.village_roof.selected;profile.parameters.porch=ui.checked("village_porch")
		if native_generator_version>=2:
			profile.parameters.balcony=true;profile.parameters.ornament=true
			# Bounded type variants share materials; the town layout measures their actual envelopes.
			profile.parameters.width=snappedf(float(profile.parameters.width)*(1.0+variation*0.07),0.05)
			profile.parameters.depth=snappedf(float(profile.parameters.depth)*(1.0-variation*0.04),0.05)
		var asset := Generator.new().build(profile)
		palette.append({"asset":asset,"skin":StringName(["","elegant","warm","weathered"][ui.controls.village_appearance.selected]),"front":0.0})
	refresh_list();invalidate()
