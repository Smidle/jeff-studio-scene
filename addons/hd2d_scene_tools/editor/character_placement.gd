@tool
extends RefCounted
var controller
var dock
var library
var records: Array=[]
var chooser: OptionButton
var role: OptionButton
var preview
var status: Label
var place_button: Button
var profile: HD2DCharacterProfile
var serial := 0
var prepared_id := ""
var target_stage: HD2DStage
var box: VBoxContainer

func setup(plugin, parent: VBoxContainer, ui) -> void:
	controller=plugin;dock=ui
	library=preload("character_presets.gd").new();library.controller=plugin
	box=dock.section(parent,"character.presets","放置预设角色",true)
	dock.label(box,"选择角色和身份，再点击地面放置。预设自带待机、行走和跑步。")
	chooser=OptionButton.new();chooser.size_flags_horizontal=Control.SIZE_EXPAND_FILL;box.add_child(chooser)
	chooser.item_selected.connect(select_preset)
	preview=preload("character_preset_preview.gd").new();box.add_child(preview)
	var actions := HBoxContainer.new();box.add_child(actions)
	var action := OptionButton.new();actions.add_child(action)
	for title in ["待机","行走","跑步"]: action.add_item(title)
	action.select(1);action.item_selected.connect(func(i): preview.action=["idle","walk","run"][i])
	var direction := OptionButton.new();actions.add_child(direction)
	for title in ["南","西","北","东"]: direction.add_item(title)
	direction.item_selected.connect(func(i): preview.direction=["s","w","n","e"][i])
	role=dock.option(box,"placement_role","角色身份",["主角（唯一）","队友（跟随主角）","NPC（原地待机）"])
	role.item_selected.connect(func(_i): cancel_tool(); refresh_hint())
	place_button=dock.button(box,"在 3D 视图放置角色",begin_placement);place_button.disabled=true
	dock.button(box,"重新读取角色预设",reload_catalog)
	status=dock.label(box,"")
	dock.label(box,"主角：WASD／方向键移动，Shift 跑步；再次放置会替换并移动唯一主角。队友可先放置，添加主角后跟随。")
	controller.shared_library.location_changed.connect(reload_catalog)
	controller.i18n.changed.connect(refresh_names)
	reload_catalog()

func refresh_names() -> void:
	chooser.set_item_text(0,controller.i18n.t("请选择角色预设…"))
	for i in records.size(): chooser.set_item_text(i+1,str(records[i].get("name_"+controller.i18n.language,records[i].id)))
	refresh_hint()

func reload_catalog() -> void:
	context_changed();records=library.catalog();chooser.clear()
	chooser.add_item(controller.i18n.t("请选择角色预设…"))
	for record in records: chooser.add_item(str(record.get("name_"+controller.i18n.language,record.id)))
	chooser.set_meta("hd2d_managed_text",true)
	controller.i18n.text(status,library.error if not library.error.is_empty() else "选择预设后自动准备动作预览。")

func cancel_tool() -> void:
	if controller.current_tool=="character_place": controller.set_tool("select")
	target_stage=null

func context_changed() -> void:
	serial+=1;cancel_tool();profile=null;prepared_id=""
	if is_instance_valid(preview):preview.profile=null;preview.queue_redraw()
	if is_instance_valid(place_button):place_button.disabled=true
	if is_instance_valid(chooser) and chooser.item_count>0:chooser.select(0)

func select_preset(index: int) -> void:
	context_changed();chooser.select(index)
	if index<1 or index>records.size(): refresh_hint();return
	var ticket := serial
	var record: Dictionary=records[index-1]
	controller.i18n.text(status,"正在准备角色及行走／跑步动作…")
	var result: HD2DCharacterProfile=await library.prepare(record,func(): return is_instance_valid(controller) and ticket==serial)
	if ticket!=serial:return
	if result==null:controller.i18n.text(status,library.error);return
	profile=result;prepared_id=str(record.id);preview.profile=profile;preview.clock=0
	place_button.disabled=false;refresh_hint()

func refresh_hint() -> void:
	if not is_instance_valid(status):return
	if not profile and not library.error.is_empty():controller.i18n.text(status,library.error);return
	controller.i18n.text(status,"预设已就绪；放置只影响当前场景，可撤销。" if profile else "请选择内置角色；无需共享库。游戏提取角色仅供学习。")

func begin_placement() -> void:
	if not profile or not controller.require_stage():return
	target_stage=controller.stage;controller.set_tool("character_place")
	controller.i18n.text(status,"点击地面放置角色；Esc 取消。")

func place_at(world_position: Vector3) -> HD2DCharacter:
	if not profile or not is_instance_valid(target_stage) or controller.stage!=target_stage:return null
	var stage: HD2DStage=target_stage
	var parent := stage.get_node_or_null("Characters") as Node3D
	if not parent:controller.message("舞台缺少 Characters 节点，无法放置角色。");return null
	var root: Node=EditorInterface.get_edited_scene_root()
	var actor: HD2DCharacter=stage.character() if role.selected==0 else null
	var fresh := actor==null
	if fresh:
		actor=HD2DCharacter.new();actor.name=["Player","Companion","NPC"][role.selected]
	var undo=controller.get_undo_redo()
	undo.create_action(controller.i18n.t("放置预设角色"),UndoRedo.MERGE_DISABLE,stage)
	if fresh:
		undo.add_do_method(parent,"add_child",actor,true);undo.add_do_method(actor,"set_owner",root)
		undo.add_do_reference(actor);undo.add_undo_method(self,"detach_actor",parent,actor)
	var values := {"profile":profile.duplicate(),"preset_id":prepared_id,"role":role.selected,"position":parent.to_local(world_position)+Vector3.UP*0.03,"keyboard_control":role.selected==0,"collision_layer":2,"collision_mask":1}
	for key in values:
		undo.add_do_property(actor,key,values[key])
		if not fresh:undo.add_undo_property(actor,key,actor.get(key))
	var rig := stage.camera_rig()
	if rig and role.selected==0:
		# Explicit player lookup also survives a later node rename.
		undo.add_do_property(rig,"locked",true);undo.add_undo_property(rig,"locked",rig.locked)
		undo.add_do_property(rig,"orthographic",true);undo.add_undo_property(rig,"orthographic",rig.orthographic)
	undo.add_do_method(actor,"rebuild")
	if not fresh:undo.add_undo_method(actor,"rebuild")
	undo.commit_action();controller.mark_changed();controller.set_tool("select");target_stage=null
	EditorInterface.get_selection().clear();EditorInterface.get_selection().add_node(actor)
	controller.i18n.text(status,"角色已放置。保存场景后，运行或主动预览可测试移动与跟随。")
	return actor

func detach_actor(parent: Node, actor: HD2DCharacter) -> void:
	# Clear the editor's inspected node before undo removes it from the scene tree.
	if EditorInterface.get_selection().get_selected_nodes().has(actor):
		EditorInterface.get_selection().remove_node(actor)
		EditorInterface.inspect_object(null)
	if controller.selection==actor:controller.selection=null
	if actor.get_parent()==parent:parent.remove_child(actor)

func dispose() -> void:
	context_changed()
	if controller.shared_library.location_changed.is_connected(reload_catalog):controller.shared_library.location_changed.disconnect(reload_catalog)
	if controller.i18n.changed.is_connected(refresh_names):controller.i18n.changed.disconnect(refresh_names)
