@tool
extends RefCounted
## Temporary renderer visibility, never a serialized Node.visible edit.
signal changed
var controller
var enabled := false
var root: Node
var hidden := {}
var queued := false

func setup(plugin) -> void:
	controller=plugin
	controller.get_tree().node_added.connect(node_added)
	controller.get_tree().node_removed.connect(node_removed)

func dispose() -> void:
	set_enabled(false)
	var tree: SceneTree=controller.get_tree()
	if tree.node_added.is_connected(node_added): tree.node_added.disconnect(node_added)
	if tree.node_removed.is_connected(node_removed): tree.node_removed.disconnect(node_removed)

func set_enabled(value: bool) -> void:
	if enabled==value: return
	if value:
		root=EditorInterface.get_edited_scene_root()
		if not is_instance_valid(root) or not has_terrain(root): return
		enabled=true
		visit(root)
	else:
		enabled=false
		for id in hidden.keys(): restore(id)
		root=null
	changed.emit()

func has_terrain(node: Node) -> bool:
	if node is HD2DTerrain: return true
	for child in node.get_children():
		if child is SubViewport: continue
		if has_terrain(child): return true
	return false

func belongs_to_terrain(node: Node) -> bool:
	var ancestor := node
	while ancestor:
		if ancestor is HD2DTerrain:
			for chunk in ancestor.chunks.values():
				if chunk==node or chunk.is_ancestor_of(node): return true
			return false
		if ancestor==root: break
		ancestor=ancestor.get_parent()
	return false

func eligible(node: Node) -> bool:
	if not is_instance_valid(root) or (node!=root and not root.is_ancestor_of(node)): return false
	if is_instance_valid(controller.cursor) and (node==controller.cursor or controller.cursor.is_ancestor_of(node)): return false
	if belongs_to_terrain(node): return false
	# Preserve lighting/environment; hide actual scenery, including water and decals.
	return node is GeometryInstance3D or node is Decal or node is FogVolume or node is CanvasItem

func visit(node: Node) -> void:
	if node is SubViewport or node is Window: return
	if eligible(node): hide_instance(node)
	for child in node.get_children(): visit(child)

func hide_instance(node: Node) -> void:
	var id := node.get_instance_id()
	if not hidden.has(id):
		hidden[id]=weakref(node)
		node.visibility_changed.connect(visibility_changed.bind(id),CONNECT_DEFERRED)
	if node is VisualInstance3D: RenderingServer.instance_set_visible(node.get_instance(),false)
	elif node is CanvasItem: RenderingServer.canvas_item_set_visible(node.get_canvas_item(),false)

func restore(id: int) -> void:
	if not hidden.has(id): return
	var node: Node=hidden[id].get_ref()
	hidden.erase(id)
	if not is_instance_valid(node): return
	var callback := visibility_changed.bind(id)
	if node.visibility_changed.is_connected(callback): node.visibility_changed.disconnect(callback)
	if not node.is_inside_tree(): return
	if node is VisualInstance3D: RenderingServer.instance_set_visible(node.get_instance(),node.is_visible_in_tree())
	elif node is CanvasItem: RenderingServer.canvas_item_set_visible(node.get_canvas_item(),node.is_visible_in_tree())

func visibility_changed(id: int) -> void:
	if not enabled or not hidden.has(id): return
	var node: Node=hidden[id].get_ref()
	if is_instance_valid(node) and eligible(node): hide_instance(node)

func node_added(node: Node) -> void:
	if not enabled or not is_instance_valid(root) or not root.is_ancestor_of(node): return
	# Ready callbacks may create or restore a native rendering instance.
	if not queued: queued=true; refresh.call_deferred()

func refresh() -> void:
	queued=false
	if enabled and is_instance_valid(root): visit(root)

func node_removed(node: Node) -> void:
	if node==root: set_enabled(false)
	else: restore(node.get_instance_id())
