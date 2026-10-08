@tool
extends RefCounted
var controller

func targets(skin_id: StringName, whole_scene: bool) -> Dictionary:
	var result := {"props":[],"foliage":[],"skipped":[],"count":0}
	if not is_instance_valid(controller.stage): return result
	var nodes: Array[Node] = []
	if whole_scene:
		var scene := EditorInterface.get_edited_scene_root()
		if scene: nodes.append(scene)
	else:
		for selected in EditorInterface.get_selection().get_selected_nodes():
			var node: Node=selected
			while node and not (node is HD2DProp or node is HD2DFoliage or node==controller.stage): node=node.get_parent()
			var scene := EditorInterface.get_edited_scene_root()
			if node and scene and scene.is_ancestor_of(node) and node!=controller.stage and not nodes.has(node): nodes.append(node)
	var visited: Dictionary = {}
	for node in nodes: _collect(node,skin_id,result,visited,whole_scene)
	return result

func _collect(node: Node, skin_id: StringName, result: Dictionary, visited: Dictionary, recursive: bool) -> void:
	if visited.has(node): return
	visited[node]=true
	if node is HD2DProp:
		if node.asset and node.asset.asset_id!=&"" and node.material_override==null and node.asset.supports_skin(skin_id):
			if node.skin_id!=skin_id: result.props.append(node); result.count+=1
		else: result.skipped.append(str(node.name))
		return
	if node is HD2DFoliage:
		var changed: Array[int] = []
		for index in node.records.size():
			var record: Dictionary=node.records[index]
			var asset: HD2DAsset=record.get("asset")
			if asset and asset.asset_id!=&"" and asset.supports_skin(skin_id):
				if StringName(record.get("skin_id",""))!=skin_id: changed.append(index); result.count+=1
			else: result.skipped.append(str(node.name)+" #"+str(index+1))
		if not changed.is_empty(): result.foliage.append({"node":node,"indices":changed})
		return
	if recursive:
		for child in node.get_children(): _collect(child,skin_id,result,visited,true)

func apply(skin_id: StringName, whole_scene: bool) -> int:
	if not controller.require_stage(): return 0
	controller.set_tool("select")
	var batch := targets(skin_id,whole_scene)
	if batch.count==0: return 0
	var undo: EditorUndoRedoManager=controller.get_undo_redo()
	undo.create_action(controller.i18n.t("应用预设皮肤"),UndoRedo.MERGE_DISABLE,controller.stage)
	for prop in batch.props:
		undo.add_do_property(prop,"skin_id",skin_id)
		undo.add_undo_property(prop,"skin_id",prop.skin_id)
	for item in batch.foliage:
		var before: Array=item.node.records.duplicate(true)
		var after: Array=before.duplicate(true)
		for index in item.indices:
			if skin_id==&"": after[index].erase("skin_id")
			else: after[index].skin_id=skin_id
		undo.add_do_method(item.node,"restore",after)
		undo.add_undo_method(item.node,"restore",before)
	undo.add_do_method(controller,"mark_changed")
	undo.add_undo_method(controller,"mark_changed")
	undo.commit_action()
	return batch.count
