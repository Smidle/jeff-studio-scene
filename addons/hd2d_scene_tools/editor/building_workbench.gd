@tool
extends VBoxContainer
const Generator=preload("building_generator.gd")
const Catalog=preload("building_catalog.gd")
const Presets=preload("building_presets.gd")
const Layout=preload("village_layout.gd")
const STYLES=["jiangnan","forest","desert"]
const SKINS=["","elegant","warm","weathered"]
var controller
var controls := {}
var preview
var status: Label
var place_button: Button
var apply_button: Button
var timer: Timer
var asset: HD2DAsset
var target: HD2DProp
var active := false
var ghost: Node3D
var placement_stage: HD2DStage
var yaw := 0.0
var valid_hit := false
var syncing := false
var generator_version := Catalog.VERSION
var preset_version := Catalog.VERSION
var type_id := "house"
var field_rows := {}
var type_ids: Array=[]

func setup(plugin) -> void:
	controller=plugin;name="BuiltInBuildings"
	size_flags_vertical=Control.SIZE_EXPAND_FILL
	var split := HSplitContainer.new();split.size_flags_vertical=Control.SIZE_EXPAND_FILL;add_child(split)
	var scroll := ScrollContainer.new();scroll.custom_minimum_size.x=240*EditorInterface.get_editor_scale();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;split.add_child(scroll)
	var form := VBoxContainer.new();form.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(form)
	option(form,"style","建筑风格",["江南古镇","欧式风格","沙漠聚落"])
	option(form,"category","建筑大类",[])
	option(form,"type","具体建筑",[])
	controls.category.set_meta("hd2d_managed_text",true);controls.type.set_meta("hd2d_managed_text",true)
	option(form,"kind","旧建筑类型",["民居","商铺","中心建筑"])
	controls.category.item_selected.connect(change_category)
	controls.type.item_selected.connect(func(index): type_id=type_ids[index];load_sample())
	option(form,"look","建筑外观",["原色","素雅","暖色","风化"])
	var variants := VBoxContainer.new();form.add_child(variants)
	controller.ui.button(variants,"随机建筑",randomize_building).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	controller.ui.button(variants,"仅随机细节",randomize_details).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	controller.ui.button(variants,"按种子重现",replay_building).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for spec in [["width","建筑宽度",3,10,0.25,4.5],["depth","建筑深度",0.5,10,0.25,4],["floors","楼层数",1,3,1,1],["pitch","屋顶坡度",15,50,1,32],["eave","屋檐宽度",0.1,1,0.05,0.45],["windows","每面窗列",1,4,1,2],["height","结构高度",0.3,10,0.1,3.2],["bays","分段与栏位",1,6,1,3],["detail_seed","细节种子",0,2147483647,1,101],["shape_seed","外形种子",0,2147483647,1,60421],["appearance_seed","外观种子",0,2147483647,1,101]]:
		var number: SpinBox=controller.ui.number(form,"builtin_"+spec[0],spec[1],spec[2],spec[3],spec[4],spec[5])
		controls[spec[0]]=number;field_rows[spec[0]]=number.get_parent();number.value_changed.connect(func(_v):
			if spec[0]=="windows" and generator_version==2 and not syncing:
				generator_version=3;preset_version=3
			invalidate())
	controller.i18n.watch_property(controls.windows,"tooltip_text","每层、每面墙的窗户数量，不含门和屋顶小窗；窄墙会缩窄窗框，可增加宽度或深度。")
	option(form,"roof","屋顶形态",["按风格","双坡屋顶","平顶露台"])
	controls.porch=controller.ui.check(form,"builtin_porch","门廊",true);field_rows.porch=controls.porch;controls.porch.toggled.connect(func(_v): invalidate())
	for spec in [["balcony","二层栏廊"],["ornament","屋顶附件与装饰"]]:
		controls[spec[0]]=controller.ui.check(form,"builtin_"+spec[0],spec[1],true)
		field_rows[spec[0]]=controls[spec[0]]
		controls[spec[0]].toggled.connect(func(_v): invalidate())
	controls.style.item_selected.connect(func(_i): load_sample())
	var view := VBoxContainer.new();view.size_flags_horizontal=Control.SIZE_EXPAND_FILL;split.add_child(view)
	controller.ui.label(view,"内置建筑 · 无需共享库")
	preview=preload("model_preview.gd").new();preview.size_flags_vertical=Control.SIZE_EXPAND_FILL;view.add_child(preview)
	controller.ui.label(view,"拖动预览旋转；参数只改变草稿，摆放或应用后才修改场景。")
	var footer := PanelContainer.new();footer.theme_type_variation="JeffApplyFrame";add_child(footer)
	var actions := VBoxContainer.new();footer.add_child(actions)
	status=controller.ui.label(actions,"")
	place_button=controller.ui.button(actions,"摆放此建筑",begin_placement);place_button.theme_type_variation="JeffPrimaryButton"
	var row := HBoxContainer.new();actions.add_child(row)
	controller.ui.button(row,"读取选中建筑",read_selected).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	apply_button=controller.ui.button(row,"应用到选中建筑",apply_selected);apply_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	controller.ui.button(row,"加入小镇建筑组合",func():
		if asset: controller.ui.village_panel.add_asset(asset,skin_id());say("已加入小镇建筑组合；进入一键生成查看布局。"))
	timer=Timer.new();timer.wait_time=0.18;timer.one_shot=true;add_child(timer);timer.timeout.connect(rebuild)
	visibility_changed.connect(func():
		if is_visible_in_tree() and asset==null: rebuild.call_deferred()
		if not is_visible_in_tree(): cancel())
	EditorInterface.get_selection().selection_changed.connect(selection_changed)
	tree_exiting.connect(func():
		cancel()
		if EditorInterface.get_selection().selection_changed.is_connected(selection_changed): EditorInterface.get_selection().selection_changed.disconnect(selection_changed))
	place_button.disabled=true;apply_button.disabled=true
	refresh_catalog_names()
	controller.i18n.changed.connect(refresh_catalog_names)
	load_parameters(Catalog.parameters(type_id,"jiangnan"))
	refresh_fields()

func option(form: Node,key: String,title: String,values: Array) -> void:
	var wrapper := VBoxContainer.new();form.add_child(wrapper);field_rows[key]=wrapper
	controls[key]=controller.ui.option(wrapper,"builtin_"+key,title,values)
	controls[key].item_selected.connect(func(_i): invalidate())

func say(message: String) -> void:
	controller.i18n.text(status,message);status.tooltip_text=controller.i18n.t(message)

func skin_id() -> StringName: return StringName(SKINS[controls.look.selected])

func invalidate() -> void:
	if syncing: return
	cancel();place_button.disabled=true;apply_button.disabled=true
	if is_instance_valid(timer): timer.start()

func rebuild() -> void:
	if not is_inside_tree(): return
	timer.stop()
	var profile := HD2DBuildingProfile.new();profile.style=STYLES[controls.style.selected];profile.kind=controls.kind.selected
	profile.generator_version=generator_version;profile.preset_version=preset_version
	profile.shape_seed=int(controls.shape_seed.value);profile.appearance_seed=int(controls.appearance_seed.value)
	if generator_version>=4:
		profile.type_id=type_id;profile.category_id=Catalog.entry(type_id).category;profile.kind=int(Catalog.entry(type_id).kind);profile.detail_seed=int(controls.detail_seed.value)
		for key in ["height","bays"]: profile.parameters[key]=controls[key].value
	for key in ["width","depth","floors","pitch","eave","windows"]: profile.parameters[key]=snappedf(controls[key].value,0.0001) if generator_version>=2 else controls[key].value
	profile.parameters.roof=controls.roof.selected;profile.parameters.porch=controls.porch.button_pressed
	if generator_version>=2:
		profile.parameters.balcony=controls.balcony.button_pressed;profile.parameters.ornament=controls.ornament.button_pressed
	controls.balcony.disabled=generator_version<2 or profile.style=="desert" or int(controls.floors.value)<2
	controls.ornament.disabled=generator_version<2
	refresh_fields()
	asset=preload("building_cache.gd").obtain(profile);preview.show_asset(asset,skin_id())
	place_button.disabled=false;refresh_apply()
	say("建筑草稿已更新；摆放到场景，或应用到已读取的建筑。")

func selected_prop() -> HD2DProp:
	var nodes := EditorInterface.get_selection().get_selected_nodes()
	if nodes.size()!=1: return null
	var node: Node=nodes[0]
	while node and not node is HD2DProp: node=node.get_parent()
	return node as HD2DProp

func selection_changed() -> void:
	if selected_prop()!=target: target=null
	refresh_apply()

func refresh_apply() -> void:
	apply_button.disabled=not is_instance_valid(target) or not target.is_inside_tree() or selected_prop()!=target or asset==null
	if not apply_button.disabled:
		apply_button.disabled=target.asset.same_entry(asset) and target.skin_id==skin_id()

func read_selected() -> void:
	var node := selected_prop()
	if not node or not node.asset or not node.asset.building_profile:
		say("请选择一个内置生成建筑；普通模型没有可重建的建筑参数。");return
	cancel();timer.stop();target=node;syncing=true
	var profile := node.asset.building_profile
	generator_version=profile.generator_version;preset_version=profile.preset_version
	controls.balcony.set_pressed_no_signal(bool(profile.parameters.get("balcony",true)));controls.ornament.set_pressed_no_signal(bool(profile.parameters.get("ornament",true)))
	controls.style.select(maxi(0,STYLES.find(profile.style)));controls.kind.select(profile.kind)
	type_id=profile.type_id if profile.generator_version>=4 else ["house","general_store","town_hall"][clampi(profile.kind,0,2)]
	controls.detail_seed.set_value_no_signal(profile.detail_seed)
	for key in ["height","bays"]: controls[key].set_value_no_signal(profile.parameters.get(key,3))
	refresh_catalog_names()
	controls.look.select(maxi(0,SKINS.find(str(node.skin_id))))
	controls.shape_seed.set_value_no_signal(profile.shape_seed);controls.appearance_seed.set_value_no_signal(profile.appearance_seed)
	for key in ["width","depth","floors","pitch","eave","windows"]: controls[key].set_value_no_signal(profile.parameters.get(key,{"width":4.5,"depth":4.0,"floors":1,"pitch":32,"eave":0.45,"windows":2}[key]))
	controls.roof.select(int(profile.parameters.get("roof",0)));controls.porch.set_pressed_no_signal(bool(profile.parameters.get("porch",true)))
	syncing=false
	# Reading is an exact snapshot, including old optional fields and numeric types.
	# Rebuild only after an explicit parameter change; never normalize old identities on read.
	asset=node.asset;preview.show_asset(asset,skin_id());refresh_fields();place_button.disabled=false;refresh_apply()
	say("已读取：%s。修改草稿后应用，只改变此建筑。"%node.name)

func save_asset() -> bool:
	var directory := "res://hd2d_generated/buildings"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path := directory.path_join(asset.building_profile.identity()+".res")
	# Generated identities are immutable; do not overwrite a resource used by another instance.
	if FileAccess.file_exists(path):
		var saved := load(path) as HD2DAsset
		if saved: asset=saved;return true
	if ResourceSaver.save(asset,path,ResourceSaver.FLAG_CHANGE_PATH)==OK:
		asset.take_over_path(path);return true
	say("生成资源保存失败，请检查工程目录权限。");return false

func apply_selected() -> void:
	if apply_button.disabled or selected_prop()!=target or not save_asset(): return
	var stage: HD2DStage=controller.stage
	if not is_instance_valid(stage) or not stage.is_ancestor_of(target): return
	var undo: EditorUndoRedoManager=controller.get_undo_redo()
	undo.create_action(controller.i18n.t("应用到选中建筑"),UndoRedo.MERGE_DISABLE,stage)
	undo.add_do_property(target,"asset",asset);undo.add_undo_property(target,"asset",target.asset)
	undo.add_do_property(target,"skin_id",skin_id());undo.add_undo_property(target,"skin_id",target.skin_id)
	var library := stage.library.duplicate() as HD2DAssetLibrary if stage.library else HD2DAssetLibrary.new()
	library.assets=library.assets.duplicate()
	if not library.assets.any(func(item):return item and item.same_entry(asset)): library.assets.append(asset)
	undo.add_do_property(stage,"library",library);undo.add_undo_property(stage,"library",stage.library)
	undo.add_do_method(controller,"refresh_scene_assets");undo.add_undo_method(controller,"refresh_scene_assets")
	undo.add_do_method(self,"sync_applied");undo.add_undo_method(self,"sync_applied")
	undo.commit_action();controller.mark_changed()
	say("建筑已应用；位置与实例参数保留，Ctrl+S / Cmd+S 保存。")

func sync_applied() -> void:
	if is_instance_valid(target) and selected_prop()==target: read_selected.call_deferred()

func begin_placement() -> void:
	if asset==null or not controller.require_terrain(): return
	controller.set_tool("building_place");controller.hide_cursor()
	placement_stage=controller.stage;active=true;valid_hit=false;yaw=0
	ghost=Node3D.new();ghost.name="JeffBuildingBlueprint";placement_stage.add_child(ghost,false,Node.INTERNAL_MODE_BACK)
	ghost.top_level=true;ghost.hide()
	var material := StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.albedo_color=Color(0.1,0.75,1,0.6)
	for part in asset.mesh_parts(skin_id()):
		var node := MeshInstance3D.new();node.mesh=part.mesh;node.transform=part.transform;node.material_override=material
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;ghost.add_child(node)
	say("建筑蓝图：鼠标选位置，Q / E 旋转，左键摆放，Esc 取消。")

func cancel() -> void:
	if active: controller.set_tool("select")

func end_placement() -> void:
	active=false;valid_hit=false;placement_stage=null
	if is_instance_valid(ghost): ghost.free()
	ghost=null

func context_changed() -> void:
	cancel();target=null;refresh_apply()

func handle_input(camera: Camera3D,event: InputEvent) -> int:
	if not active or not is_instance_valid(placement_stage) or controller.stage!=placement_stage:
		cancel();return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventKey:
		var code: int=event.physical_keycode if event.physical_keycode else event.keycode
		if code in [KEY_Q,KEY_E] and not event.alt_pressed and not event.ctrl_pressed and not event.meta_pressed:
			if event.pressed and not event.echo:
				yaw=wrapf(yaw+(-15 if code==KEY_Q else 15),-180,180)
				ghost.global_basis=Basis(Vector3.UP,deg_to_rad(yaw))
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if not (event is InputEventMouseMotion or event is InputEventMouseButton): return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event.alt_pressed or (event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_RIGHT): return EditorPlugin.AFTER_GUI_INPUT_PASS
	var terrain := placement_stage.terrain()
	if not terrain or not terrain.data: cancel();return EditorPlugin.AFTER_GUI_INPUT_PASS
	var hit: Variant=terrain.raycast(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
	valid_hit=false
	if hit is Vector3:
		var local: Vector3=terrain.to_local(hit)
		valid_hit=absf(local.y-terrain.data.height_at(local.x,local.z))<=maxf(0.02,terrain.data.cell_size()*0.01)
	ghost.visible=valid_hit
	if valid_hit: ghost.global_transform=Transform3D(Basis(Vector3.UP,deg_to_rad(yaw)),hit)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and valid_hit:
			if save_asset():
				controller.place_asset(asset,hit,ghost.global_basis,skin_id())
				cancel();say("建筑已摆放；选中后可读取并修改参数。")
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_STOP if event is InputEventMouseMotion else EditorPlugin.AFTER_GUI_INPUT_PASS

func load_parameters(values: Dictionary) -> void:
	syncing=true
	for key in values:
		if not controls.has(key): continue
		if controls[key] is SpinBox: controls[key].set_value_no_signal(values[key])
		elif controls[key] is OptionButton: controls[key].select(values[key])
		elif controls[key] is CheckBox: controls[key].set_pressed_no_signal(values[key])
	syncing=false

func refresh_catalog_names() -> void:
	if not controls.has("category"): return
	var category: String=Catalog.entry(type_id).category
	controls.category.clear()
	for item in Catalog.document().categories:
		controls.category.add_item(item.get(controller.i18n.language,item.zh))
		if item.id==category: controls.category.select(controls.category.item_count-1)
	controls.type.clear();type_ids.clear()
	for item in Catalog.types(category):
		type_ids.append(item.id);controls.type.add_item(Catalog.title(item.id,STYLES[controls.style.selected],controller.i18n.language))
		if item.id==type_id: controls.type.select(controls.type.item_count-1)

func change_category(index: int) -> void:
	if syncing: return
	type_id=Catalog.types(Catalog.document().categories[index].id)[0].id
	load_sample()

func refresh_fields() -> void:
	var applicable: Array=Catalog.fields(type_id) if generator_version>=4 else ["width","depth","floors","pitch","eave","windows","roof","porch","balcony","ornament","shape_seed","appearance_seed"]
	for key in field_rows:
		field_rows[key].visible=key in applicable or key in ["style","look","category","type"] or (key=="kind" and generator_version<4)
	controls.type.disabled=generator_version<4
	var special: bool = generator_version>=4 and Catalog.entry(type_id).archetype!="house"
	var width_label := "城墙长度" if type_id=="wall" and special else ("平台宽度" if type_id=="dock" and special else ("结构宽度／长度" if special else "建筑宽度"))
	controller.i18n.bind(field_rows.width.get_child(0),"text",width_label)
	var depth_label := "城墙厚度" if type_id=="wall" and special else ("栈桥长度" if type_id=="dock" and special else ("结构深度" if special else "建筑深度"))
	controller.i18n.bind(field_rows.depth.get_child(0),"text",depth_label)

func load_sample() -> void:
	cancel();generator_version=Catalog.VERSION;preset_version=Catalog.VERSION
	load_parameters(Catalog.parameters(type_id,STYLES[controls.style.selected]))
	controls.shape_seed.set_value_no_signal(60421);controls.detail_seed.set_value_no_signal(101)
	refresh_catalog_names();rebuild()
	say("风格与类型已切换；参数只改变草稿，摆放或应用后生效。")

func randomize_building() -> void:
	controls.shape_seed.set_value_no_signal((int(controls.shape_seed.value)+randi_range(1,2147483646))%2147483647)
	controls.detail_seed.set_value_no_signal((int(controls.detail_seed.value)+randi_range(1,2147483646))%2147483647)
	replay_building()

func randomize_details() -> void:
	if generator_version<4:
		say("旧配方保留原貌；重新选择建筑类型后可使用两级随机。")
		return
	controls.detail_seed.set_value_no_signal((int(controls.detail_seed.value)+randi_range(1,2147483646))%2147483647)
	rebuild();say("细节已变化；主体、入口、窗列数量和碰撞保持不变。")

func replay_building() -> void:
	cancel()
	if generator_version>=4:
		load_parameters(Catalog.parameters(type_id,STYLES[controls.style.selected],int(controls.shape_seed.value),true,generator_version))
	refresh_catalog_names();rebuild()
	say("已按结构和细节种子重现；手工调参后的结果请保存完整配方。")
