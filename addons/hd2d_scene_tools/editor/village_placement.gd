@tool
extends RefCounted
## Editor-only mesh blueprint. No owners, physics, asset scripts or terrain writes.
const Layout=preload("village_layout.gd")
var panel
var controller
var active := false
var stage: HD2DStage
var terrain: HD2DTerrain
var root: Node3D
var material: StandardMaterial3D
var timer: Timer
var draft: Dictionary={}
var checked: Dictionary={}
var has_hit := false
var pending := false

func setup(owner_panel) -> void:
	panel=owner_panel;controller=panel.controller
	timer=Timer.new();timer.one_shot=true;timer.wait_time=0.18
	panel.ui.add_child(timer);timer.timeout.connect(validate_position)

func dispose() -> void:
	stop(false)
	if is_instance_valid(timer):
		timer.stop()
		if timer.timeout.is_connected(validate_position): timer.timeout.disconnect(validate_position)
	# Break the RefCounted panel <-> placement cycle on plugin disable.
	panel=null;controller=null;material=null

func begin() -> void:
	if active or panel.busy or panel.loading or not is_instance_valid(controller.stage): return
	var next: HD2DTerrain=controller.stage.terrain()
	if next==null or next.data==null or next is HD2DWorldMap:
		panel.say("请选择普通高度地形；本版村落不写入分区大地图。");return
	draft=Layout.plan(panel.palette,panel.options())
	if not str(draft.get("error","")).is_empty(): panel.say(draft.error);return
	controller.set_tool("village_place")
	controller.hide_cursor();panel.debounce.stop()
	stage=controller.stage;terrain=next;active=true;has_hit=false
	panel.generate_button.disabled=true;panel.replace_button.disabled=true
	material=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	root=Node3D.new();root.name="JeffTownBlueprint"
	# Internal, unowned children stay out of the scene tree, obstacle scans and saves.
	stage.add_child(root,false,Node.INTERNAL_MODE_BACK)
	root.top_level=true;root.global_transform=panel.world_transform(terrain)
	build_visual(draft);move_to(root.global_position)
	panel.say("蓝图摆放：移到地形上选择位置，Q / E 旋转 15°，左键确认，Esc 取消。")
	controller.message("蓝图摆放：移到地形上选择位置，Q / E 旋转 15°，左键确认，Esc 取消。")

func valid_target() -> bool:
	return active and is_instance_valid(stage) and stage.is_inside_tree() and controller.stage==stage and is_instance_valid(terrain) and stage.terrain()==terrain and terrain.data!=null

func stop(notify: bool=true) -> void:
	if not active: return
	active=false;has_hit=false;pending=false;checked.clear();draft.clear()
	if is_instance_valid(timer): timer.stop()
	if is_instance_valid(root): root.free()
	root=null;terrain=null;stage=null
	if is_instance_valid(panel.generate_button): panel.generate_button.disabled=panel.disposed or panel.busy or not is_instance_valid(controller.stage)
	if notify and not panel.disposed:
		panel.say("已取消小镇摆放，场景未修改；可调整草稿后再次应用。")
		controller.message("已取消小镇摆放，场景未修改；可调整草稿后再次应用。")

func handle_input(camera: Camera3D, event: InputEvent) -> int:
	if not valid_target(): controller.set_tool("select");return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventKey:
		var code: int=event.physical_keycode if event.physical_keycode else event.keycode
		if code in [KEY_Q,KEY_E] and not event.alt_pressed and not event.ctrl_pressed and not event.meta_pressed:
			if event.pressed and not event.echo: rotate(-15.0 if code==KEY_Q else 15.0)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if not (event is InputEventMouseMotion or event is InputEventMouseButton): return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event.alt_pressed or (event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_RIGHT): return EditorPlugin.AFTER_GUI_INPUT_PASS
	# Always hit the heightfield, never a building roof or the blueprint itself.
	var hit: Variant=terrain.raycast(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
	if hit is Vector3:
		var local: Vector3=terrain.to_local(hit)
		# The heightfield marcher may enter an edge below the surface after missing
		# the map. Reject that edge hit instead of snapping an off-map pointer back.
		if absf(local.y-terrain.data.height_at(local.x,local.z))>maxf(0.02,terrain.data.cell_size()*0.01): hit=null
	if hit is Vector3: move_to(hit)
	else:
		has_hit=false;pending=false;root.hide();checked.clear();timer.stop()
		panel.say("没有有效地形落点；请将鼠标移回当前地形，Esc 取消。")
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and has_hit: confirm()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_STOP if event is InputEventMouseMotion else EditorPlugin.AFTER_GUI_INPUT_PASS

func move_to(world_point: Vector3) -> void:
	if not valid_target(): return
	var point := terrain.to_local(world_point)
	var moved: bool= not has_hit or (Vector2(point.x,point.z)-panel.placement_center).length()>0.01
	has_hit=true;root.show()
	if not moved: return
	panel.placement_center=Vector2(point.x,point.z)
	position_changed()

func rotate(degrees: float) -> void:
	if not valid_target(): return
	panel.ui.controls.village_yaw.set_value_no_signal(wrapf(panel.ui.value("village_yaw")+degrees,-180,180))
	position_changed()

func position_changed() -> void:
	checked.clear();pending=true
	root.global_transform=panel.world_transform(terrain)
	material.albedo_color=Color(0.25,0.7,1.0,0.48)
	panel.say("蓝图检查中 · Q / E 旋转 15° · 左键确认 · Esc 取消")
	# Throttle heavy grading, rather than rebuilding all resources on every mouse event.
	if timer.is_stopped(): timer.start()

func validate_position() -> void:
	if not valid_target() or not has_hit: return
	pending=false
	draft.options=panel.options()
	checked=Layout.validate(draft,terrain,panel.world_transform(terrain),stage)
	var error := str(checked.get("error",""))
	if error.is_empty():
		build_visual(checked)
		material.albedo_color=Color(0.12,0.75,1.0,0.58)
		panel.say("蓝图可放置 · Q / E 旋转 15° · 左键确认 · Esc 取消")
	else:
		material.albedo_color=Color(1.0,0.22,0.18,0.65)
		panel.say("此处不能放置：%s"%controller.i18n.t(error))
	panel.status.tooltip_text=panel.status.text

func confirm() -> void:
	if not valid_target() or not has_hit: return
	timer.stop();validate_position()
	if not str(checked.get("error","")).is_empty() or checked.is_empty(): return
	panel.prepared=checked;panel.preview_stage=stage
	# commit revalidates current terrain/obstacles; only a successful write ends placement.
	panel.commit(false)

func build_visual(data: Dictionary) -> void:
	for child in root.get_children(): child.free()
	for entry in data.entries:
		var item: Dictionary=panel.palette[entry.palette]
		var transform := Transform3D(entry.basis,entry.position)
		for part in item.asset.mesh_parts(item.skin):
			var mesh := MeshInstance3D.new();mesh.mesh=part.mesh;mesh.transform=transform*part.transform
			root.add_child(mesh)
	preload("village_structures.gd").add_walls(root,data,false)
	var road_data := data.duplicate(false)
	if not road_data.has("draft_terrain"):
		road_data.draft_terrain=terrain.data
		road_data.terrain_transform=root.global_transform.affine_inverse()*terrain.global_transform
	preload("village_roads.gd").add_to(root,road_data)
	style_tree(root)

func style_tree(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override=material
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children(): style_tree(child)
