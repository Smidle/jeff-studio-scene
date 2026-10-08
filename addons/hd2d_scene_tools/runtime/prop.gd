@tool
class_name HD2DProp
extends Node3D
signal parameter_values_changed
@export var asset_overrides: Dictionary = {}:
	set(value):
		asset_overrides=value.duplicate(true)
		if is_inside_tree():
			rebuild();parameter_values_changed.emit()

func effective_asset() -> HD2DAsset:
	return asset.with_overrides(asset_overrides) if asset else null

@export var skin_id: StringName = &"":
	set(value):
		skin_id=value
		if is_inside_tree(): refresh_skin()
@export var material_override: Material:
	set(value):
		material_override=value
		if is_inside_tree(): rebuild()
@export_enum("保持素材:-1", "Off:0", "On:1", "Double-sided:2", "Shadows only:3") var cast_shadow: int = -1:
	set(value):
		cast_shadow=value
		if is_inside_tree(): rebuild()
## The asset reference is authored; render/collision children are regenerated, not saved.
@export var asset: HD2DAsset:
	set(value):
		if asset and asset.changed.is_connected(rebuild): asset.changed.disconnect(rebuild)
		asset=value
		if asset: asset.changed.connect(rebuild)
		if is_inside_tree(): rebuild()

func _ready() -> void: rebuild()

func rebuild() -> void:
	if not is_inside_tree(): return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if asset==null or asset.source==null: return
	add_child(effective_asset().make_node(skin_id))
	if Engine.is_editor_hint(): update_gizmos()
	_apply_visual_overrides(self)
	var ancestor := get_parent()
	while ancestor:
		if ancestor is HD2DStage:
			ancestor.apply_card_environment(self)
			break
		ancestor=ancestor.get_parent()

func refresh_skin() -> void:
	# Appearance changes must not recreate physics or alter the authored transform.
	if asset and get_child_count()>0:
		var effective := skin_id if asset.supports_skin(skin_id) else &""
		effective_asset().apply_skin(get_child(0),effective)
		_apply_visual_overrides(self)

func _apply_visual_overrides(node: Node) -> void:
	if node is GeometryInstance3D:
		if material_override: node.material_override=material_override
		if cast_shadow>=0: node.cast_shadow=cast_shadow
	for child in node.get_children(): _apply_visual_overrides(child)
