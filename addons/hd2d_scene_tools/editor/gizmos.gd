@tool
extends EditorNode3DGizmoPlugin
var controller: EditorPlugin

func _init() -> void:
	create_material("line",Color(0.3,0.9,0.85))
	create_material("boundary",Color(1,0.7,0.2))
	create_handle_material("handles")

func _has_gizmo(node: Node3D) -> bool: return node is HD2DRoad or node is HD2DStage or node is HD2DCameraRig or node is HD2DProp
func _get_gizmo_name() -> String: return "HD2D Scene Handles"

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d()
	var lines := PackedVector3Array()
	var handles := PackedVector3Array()
	if node is HD2DProp:
		if controller.parameters and controller.parameters.target==node: lines=controller.parameters.lines
	elif node is HD2DRoad and node.curve:
		var points: PackedVector3Array=node.curve.get_baked_points()
		for i in range(points.size()-1): lines.append_array(PackedVector3Array([node.ground_point(points[i]),node.ground_point(points[i+1])]))
		for i in range(node.curve.point_count):
			var p: Vector3=node.curve.get_point_position(i)
			handles.append(p)
			handles.append(p+node.curve.get_point_in(i))
			handles.append(p+node.curve.get_point_out(i))
			lines.append_array(PackedVector3Array([p+node.curve.get_point_in(i),p,p,p+node.curve.get_point_out(i)]))
	elif node is HD2DStage:
		var half: float=node.segment_length*0.5
		if node.stage_mode==1:
			lines.append_array(PackedVector3Array([Vector3(-half,0,-12),Vector3(-half,0,12),Vector3(half,0,-12),Vector3(half,0,12),Vector3(-half,0,-12),Vector3(half,0,-12),Vector3(-half,0,12),Vector3(half,0,12)]))
			handles.append(Vector3(half,0,0))
	elif node is HD2DCameraRig:
		var r: Rect2=node.follow_bounds
		if node.bounds_enabled:
			var a := Vector3(r.position.x,0,r.position.y)
			var b := Vector3(r.end.x,0,r.position.y)
			var c := Vector3(r.end.x,0,r.end.y)
			var d := Vector3(r.position.x,0,r.end.y)
			lines.append_array(PackedVector3Array([a,b,b,c,c,d,d,a]))
	if not lines.is_empty(): gizmo.add_lines(lines,get_material("line",gizmo),false)
	if not handles.is_empty(): gizmo.add_handles(handles,get_material("handles",gizmo),[])

func _get_handle_name(gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> String:
	if gizmo.get_node_3d() is HD2DStage: return controller.i18n.t("循环段长度")
	return controller.i18n.t("道路 %d · %s") % [id/3,controller.i18n.t(["位置","入切线","出切线"][id%3])]

func _get_handle_value(gizmo: EditorNode3DGizmo, id: int, _secondary: bool) -> Variant:
	var node := gizmo.get_node_3d()
	if node is HD2DStage: return node.segment_length
	if id%3==0: return node.curve.get_point_position(id/3)
	return node.curve.get_point_in(id/3) if id%3==1 else node.curve.get_point_out(id/3)

func _set_handle(gizmo: EditorNode3DGizmo, id: int, _secondary: bool, camera: Camera3D, point: Vector2) -> void:
	var node := gizmo.get_node_3d()
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var hit: Variant=Plane(Vector3.UP,node.global_position.y).intersects_ray(origin,direction)
	if hit==null: return
	var local := node.to_local(hit)
	if node is HD2DStage:
		node.segment_length=clampf(absf(local.x)*2,4,256)
		node.update_gizmos()
	elif node is HD2DRoad:
		if id%3==0: node.curve.set_point_position(id/3,local)
		elif id%3==1: node.curve.set_point_in(id/3,local-node.curve.get_point_position(id/3))
		else: node.curve.set_point_out(id/3,local-node.curve.get_point_position(id/3))

func _commit_handle(gizmo: EditorNode3DGizmo, id: int, secondary: bool, restore: Variant, cancel: bool) -> void:
	var node := gizmo.get_node_3d()
	var current: Variant=_get_handle_value(gizmo,id,secondary)
	if cancel:
		_apply(node,id,restore)
		return
	var undo := controller.get_undo_redo()
	undo.create_action(controller.i18n.t("HD2D 控制柄"),UndoRedo.MERGE_DISABLE,node)
	undo.add_do_method(self,"_apply",node,id,current)
	undo.add_undo_method(self,"_apply",node,id,restore)
	undo.commit_action(false)
	controller.mark_changed()

func _apply(node: Node3D, id: int, value: Variant) -> void:
	if node is HD2DStage: node.segment_length=value; node.update_gizmos()
	elif id%3==0: node.curve.set_point_position(id/3,value)
	elif id%3==1: node.curve.set_point_in(id/3,value)
	else: node.curve.set_point_out(id/3,value)
