@tool
extends RefCounted
## Editor draft state. Only scalar/value settings are copied; the source graph is shared.
var controller
var target: HD2DProp
var baseline: Dictionary = {}
var patch: Dictionary = {}
var applied_fields: Dictionary = {}
var loading := false
var own_commit := false
var lines := PackedVector3Array()
var confirmation: ConfirmationDialog
var pending: Dictionary = {}
var instance_picker: AcceptDialog
var instance_nodes: Array=[]
const FIELD_CONTROLS := {
	"card_size":["card_width","card_height"], "anchor":["asset_anchor_x","asset_anchor_y"],
	"facing":["asset_facing"], "alpha_cut":["alpha_cut"], "nearest":["asset_nearest"], "wind":["asset_wind"],
	"static_collision":["asset_collision"], "collision_mode":["collision_mode"],
	"collision_size":["collision_x","collision_y","collision_z"], "collision_offset":["collision_offset_x","collision_offset_y","collision_offset_z"],
	"texture_region":["region_x","region_y","region_w","region_h"], "animate_sheet":["animate_sheet"],
	"sheet_columns":["sheet_columns"], "sheet_rows":["sheet_rows"], "sheet_start":["sheet_start"], "sheet_count":["sheet_count"], "sheet_fps":["sheet_fps"],
	"color_key_enabled":["color_key_enabled"], "color_key":["color_key"], "color_key_tolerance":["color_key_tolerance"]}
const FIELD_NAMES := ["贴片尺寸","锚点","朝向","透明裁切","采样","风摆","静态碰撞","碰撞形状","碰撞尺寸","碰撞偏移","图集区域","图集动画","图集列数","图集行数","起始帧","播放帧数","帧速率","底色透明","底色","底色容差"]

func setup(plugin) -> void:
	controller=plugin
	for key in FIELD_CONTROLS:
		for control_key in FIELD_CONTROLS[key]:
			var control: Control=controller.ui.controls[control_key]
			var callback := func(_value): changed()
			if control is SpinBox: control.value_changed.connect(callback)
			elif control is OptionButton: control.item_selected.connect(callback)
			elif control is CheckBox: control.toggled.connect(callback)
			elif control is ColorPickerButton: control.color_changed.connect(callback)
	confirmation=ConfirmationDialog.new(); confirmation.title="应用到当前场景所有相同素材"
	confirmation.ok_button_text="确认应用";confirmation.cancel_button_text="取消"
	confirmation.get_ok_button().set_meta("jeff_icon","apply")
	confirmation.add_theme_constant_override("buttons_min_width",roundi(160*EditorInterface.get_editor_scale()))
	controller.ui.add_child(confirmation); controller.i18n.watch(confirmation)
	confirmation.confirmed.connect(func():
		if pending.get("root")!=EditorInterface.get_edited_scene_root() or pending.get("target")!=target or pending.get("patch")!=patch:
			controller.message("编辑内容已改变，请重新检查批量范围。"); return
		var latest := batch()
		if latest.fingerprint!=pending.get("fingerprint"):
			request_batch(); return
		apply_batch(latest))
	controller.i18n.changed.connect(update_status)
	update_status()

func select_prop(prop: HD2DProp) -> void:
	if prop==target:
		if is_instance_valid(target): controller.ui.selected_asset=target.asset
		return
	var previous := target
	if is_instance_valid(previous) and previous.parameter_values_changed.is_connected(target_changed): previous.parameter_values_changed.disconnect(target_changed)
	target=prop
	if is_instance_valid(target) and not target.parameter_values_changed.is_connected(target_changed): target.parameter_values_changed.connect(target_changed)
	baseline.clear(); patch.clear(); applied_fields.clear(); lines.clear()
	if is_instance_valid(previous): previous.update_gizmos()
	if is_instance_valid(target) and target.asset:
		loading=true
		var effective := target.effective_asset()
		if effective.collision_mode==0 and not target.asset_overrides.has("collision_offset"):
			effective=effective.duplicate(); effective.collision_offset=Vector3.ZERO
		for field in HD2DAsset.OVERRIDE_FIELDS: baseline[field]=effective.get(field)
		controller.ui.selected_asset=target.asset
		controller.ui.fill_asset(effective)
		loading=false
	update_status(); update_lines()

func read_values() -> Dictionary:
	var result := {}
	var controls: Dictionary=controller.ui.controls
	for field in FIELD_CONTROLS:
		var keys: Array=FIELD_CONTROLS[field]
		if field in ["card_size","anchor"]: result[field]=Vector2(controls[keys[0]].value,controls[keys[1]].value)
		elif field in ["collision_size","collision_offset"]: result[field]=Vector3(controls[keys[0]].value,controls[keys[1]].value,controls[keys[2]].value)
		elif field=="texture_region": result[field]=Rect2i(int(controls.region_x.value),int(controls.region_y.value),int(controls.region_w.value),int(controls.region_h.value))
		else:
			var control: Control=controls[keys[0]]
			if control is CheckBox: result[field]=control.button_pressed
			elif control is OptionButton: result[field]=control.selected
			elif control is ColorPickerButton: result[field]=control.color
			else: result[field]=int(control.value) if field in ["sheet_columns","sheet_rows","sheet_start","sheet_count"] else float(control.value)
	return result

func changed() -> void:
	if loading or controller.ui.syncing or not is_instance_valid(target) or baseline.is_empty(): return
	patch.clear()
	var values := read_values()
	for field in values:
		# A field already applied during this selection stays part of the patch,
		# including an explicit reset back to its original value.
		if values[field]!=baseline[field] or applied_fields.has(field): patch[field]=values[field]
	update_status(); update_lines()

func field_names() -> String:
	var names := PackedStringArray()
	var fields: Array=FIELD_CONTROLS.keys()
	for field in patch: names.append(controller.i18n.t(FIELD_NAMES[fields.find(field)]))
	return ", ".join(names)

func update_status() -> void:
	if not controller or not controller.ui: return
	var valid := is_instance_valid(target) and target.asset!=null
	controller.ui.controls.choose_instance.disabled=controller.ui.selected_asset==null
	var card: bool=valid and target.asset.source is Texture2D
	for id in ["assets.card","assets.crop","assets.sheet","assets.material"]:
		if controller.ui.sections.has(id): controller.ui.sections[id].visible=card or not valid
	controller.ui.controls.apply_asset.disabled=not valid or patch.is_empty()
	controller.ui.controls.apply_same.disabled=not valid or patch.is_empty()
	if not valid:
		controller.i18n.text(controller.ui.asset_info,"请选择场景中的物件；素材条目用于摆放，实例用于修改参数。")
		return
	var draft := false
	var current := target.effective_asset()
	for field in patch:
		if current.get(field)!=patch[field]: draft=true
	controller.ui.asset_info.text=controller.i18n.t("当前物件：")+str(target.name)+"\n"+controller.i18n.t("来源素材：")+target.asset.title+"\n"+controller.i18n.t("本次修改：")+(field_names() if not patch.is_empty() else controller.i18n.t("无"))+(" · "+controller.i18n.t("未应用") if draft else "")

static func validate(asset: HD2DAsset) -> String:
	if asset.source is Texture2D:
		var region := asset.texture_region
		var bounds := Rect2i(Vector2i.ZERO,Vector2i(asset.source.get_size()))
		if region.size!=Vector2i.ZERO and (not region.has_area() or not bounds.encloses(region)): return "区域必须在图片范围内且宽高都大于 0；宽高都为 0 表示整图。"
	if asset.animate_sheet:
		if not asset.source is Texture2D: return "循环图集需要图片素材。"
		var pixels := asset.region_rect().size
		if asset.sheet_columns<1 or asset.sheet_rows<1 or pixels.x%asset.sheet_columns!=0 or pixels.y%asset.sheet_rows!=0 or asset.sheet_start+asset.sheet_count>asset.sheet_columns*asset.sheet_rows: return "图集区域必须能被行列整除，起始帧加帧数不能超过格子总数。"
	return ""

func merged(existing: Dictionary) -> Dictionary:
	var result := existing.duplicate(true)
	result.merge(patch,true)
	return result

func apply_single() -> void:
	if not is_instance_valid(target) or target.asset==null or patch.is_empty(): return
	var next := merged(target.asset_overrides)
	var error := validate(target.asset.with_overrides(next))
	if not error.is_empty(): controller.message(error); return
	for field in patch: applied_fields[field]=true
	var world_node := target.get_parent()
	while world_node and not world_node is HD2DWorldMap: world_node=world_node.get_parent()
	if world_node and target.has_meta("world_source_id"):
		var id: String=target.get_meta("world_source_id")
		var before: Dictionary=world_node.world_data().object_overrides.get(id,{}).duplicate(true)
		var after := before.duplicate(true);after.asset_overrides=next
		var manager: EditorUndoRedoManager=controller.get_undo_redo()
		manager.create_action(controller.i18n.t("应用素材参数"),UndoRedo.MERGE_DISABLE,controller.stage)
		manager.add_do_method(self,"apply_world",world_node,{id:after});manager.add_undo_method(self,"apply_world",world_node,{id:before})
		manager.commit_action();return
	var undo: EditorUndoRedoManager=controller.get_undo_redo()
	undo.create_action(controller.i18n.t("应用素材参数"),UndoRedo.MERGE_DISABLE,target)
	undo.add_do_property(target,"asset_overrides",next)
	undo.add_undo_property(target,"asset_overrides",target.asset_overrides.duplicate(true))
	undo.add_do_method(self,"refresh"); undo.add_undo_method(self,"refresh")
	own_commit=true;undo.commit_action();own_commit=false;controller.mark_changed()

func batch() -> Dictionary:
	var result := {"props":[],"foliage":[],"worlds":[],"skipped":[],"count":0,"fingerprint":""}
	if not is_instance_valid(target) or target.asset==null: return result
	collect(EditorInterface.get_edited_scene_root(),result)
	var identities := []
	for prop in result.props: identities.append([prop.get_instance_id(),prop.asset.get_instance_id(),prop.asset_overrides])
	for item in result.foliage: identities.append([item.node.get_instance_id(),item.node.records])
	for item in result.worlds: identities.append([item.node.get_instance_id(),item.before])
	result.fingerprint=var_to_str(identities)
	return result

func collect(node: Node, result: Dictionary) -> void:
	if node==null: return
	if node is HD2DWorldMap:
		var before := {};var after := {}
		for record in node.world_data().placements:
			if str(record.model)!=str(target.asset.asset_id): continue
			var current: Dictionary=node.world_data().object_overrides.get(record.id,{}).duplicate(true)
			var updated := current.duplicate(true);updated.asset_overrides=merged(current.get("asset_overrides",{}))
			var reason := validate(target.asset.with_overrides(updated.asset_overrides))
			if not reason.is_empty(): result.skipped.append(str(record.id)+": "+controller.i18n.t(reason));continue
			before[record.id]=current;after[record.id]=updated;result.count+=1
		if not after.is_empty(): result.worlds.append({"node":node,"before":before,"after":after})
		return
	if node is HD2DProp and target.asset.same_entry(node.asset):
		var reason := validate(node.asset.with_overrides(merged(node.asset_overrides)))
		if reason.is_empty(): result.props.append(node); result.count+=1
		else: result.skipped.append(str(node.name)+": "+controller.i18n.t(reason))
	if node is HD2DFoliage:
		var records: Array=node.records.duplicate(true)
		var count := 0
		for i in records.size():
			var asset: HD2DAsset=records[i].get("asset")
			if not target.asset.same_entry(asset): continue
			var overrides := merged(records[i].get("asset_overrides",{}))
			var reason := validate(asset.with_overrides(overrides))
			if not reason.is_empty(): result.skipped.append("%s[%d]: %s"%[node.name,i,controller.i18n.t(reason)]); continue
			records[i].asset_overrides=overrides; count+=1
		if count>0: result.foliage.append({"node":node,"records":records}); result.count+=count
	# Generated prop and foliage children are not authored entries.
	if node is HD2DProp or node is HD2DFoliage: return
	for child in node.get_children(): collect(child,result)

func request_batch() -> void:
	if patch.is_empty(): return
	var items := batch()
	pending={"root":EditorInterface.get_edited_scene_root(),"target":target,"patch":patch.duplicate(true),"fingerprint":items.fingerprint}
	confirmation.dialog_text=controller.i18n.t("将修改 %d 项；不兼容 %d 项。"%[items.count,items.skipped.size()])+"\n"+field_names()+"\n"+"\n".join(PackedStringArray(items.skipped))
	confirmation.get_ok_button().disabled=items.count==0
	confirmation.popup_centered(Vector2i(620,300))

func apply_batch(items: Dictionary) -> void:
	if items.count==0 or patch.is_empty(): return
	for field in patch: applied_fields[field]=true
	var undo: EditorUndoRedoManager=controller.get_undo_redo()
	undo.create_action(controller.i18n.t("应用到当前场景所有相同素材"),UndoRedo.MERGE_DISABLE,EditorInterface.get_edited_scene_root())
	for prop in items.props:
		undo.add_do_property(prop,"asset_overrides",merged(prop.asset_overrides))
		undo.add_undo_property(prop,"asset_overrides",prop.asset_overrides.duplicate(true))
	for item in items.foliage:
		undo.add_do_method(item.node,"restore",item.records)
		undo.add_undo_method(item.node,"restore",item.node.records.duplicate(true))
	for item in items.get("worlds",[]):
		undo.add_do_method(self,"apply_world",item.node,item.after)
		undo.add_undo_method(self,"apply_world",item.node,item.before)
	undo.add_do_method(self,"refresh"); undo.add_undo_method(self,"refresh")
	own_commit=true;undo.commit_action();own_commit=false;controller.mark_changed()

func apply_world(world_node: HD2DWorldMap, patches: Dictionary) -> void:
	if not is_instance_valid(world_node): return
	world_node.apply_record_patches(patches)
	controller.external_dirty[world_node.data]=true;controller.mark_changed();refresh()

func refresh() -> void:
	update_status(); update_lines()
	if is_instance_valid(target):
		loading=true;controller.ui.fill_asset(target.effective_asset());loading=false
		controller.ui.sheet_preview.display(target.effective_asset())

func update_lines() -> void:
	lines.clear()
	if not is_instance_valid(target): return
	if controller.ui.checked("selected_collision_lines") and target.asset:
		var asset := target.asset.with_overrides(merged(target.asset_overrides))
		if asset.static_collision:
			for part in asset.collision_parts():
				var mesh: ArrayMesh=part.shape.get_debug_mesh()
				if mesh==null: continue
				for surface in mesh.get_surface_count():
					if mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_LINES: continue
					for point in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]: lines.append(part.transform*point)
	target.update_gizmos()

func focus_instance(node: HD2DProp) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree(): return
	controller.set_tool("select")
	var selection := EditorInterface.get_selection();selection.clear();selection.add_node(node)
	controller.select_context(node);controller.ui.select_page("assets")
	for id in ["assets.scene","assets.collision"]: controller.ui.sections[id].set_expanded(true)

func choose_instance(asset: HD2DAsset) -> void:
	if asset==null: return
	instance_nodes.clear(); find_instances(EditorInterface.get_edited_scene_root(),asset)
	if instance_nodes.is_empty(): controller.message("当前场景没有此素材的可编辑实例，请先摆放。");return
	if instance_nodes.size()==1:focus_instance(instance_nodes[0]);return
	if is_instance_valid(instance_picker): instance_picker.queue_free()
	instance_picker=AcceptDialog.new();instance_picker.title=controller.i18n.t("选择场景实例…")
	var list := ItemList.new();list.custom_minimum_size=Vector2(440,240);instance_picker.add_child(list)
	for node in instance_nodes: list.add_item(str(EditorInterface.get_edited_scene_root().get_path_to(node)))
	list.item_selected.connect(func(index): focus_instance(instance_nodes[index]);instance_picker.hide())
	controller.ui.add_child(instance_picker);instance_picker.popup_centered()
func find_instances(node: Node,asset: HD2DAsset) -> void:
	if node==null: return
	if node is HD2DProp:
		if asset.same_entry(node.asset):instance_nodes.append(node)
		return
	for child in node.get_children():find_instances(child,asset)

func target_changed() -> void:
	if own_commit or not is_instance_valid(target): return
	var node := target
	if node.parameter_values_changed.is_connected(target_changed): node.parameter_values_changed.disconnect(target_changed)
	target=null;select_prop(node)
	controller.message("物件参数已由撤销或其他操作更新，已同步当前值。")
