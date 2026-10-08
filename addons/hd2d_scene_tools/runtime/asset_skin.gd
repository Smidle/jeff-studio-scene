@tool
class_name HD2DAssetSkin
extends Resource
## Authored once by the catalogue builder. Materials are loaded on demand.
@export var skin_id: StringName
@export var title: String
@export var family_id: StringName
@export var materials: Dictionary = {}

func material_for(slot: String) -> Material:
	var value: Variant = materials.get(slot)
	if value is Material: return value
	if value is String and ResourceLoader.exists(value): return load(value) as Material
	return null

func complete_for(slots: Array[String]) -> bool:
	for slot in slots:
		if material_for(slot)==null: return false
	return not slots.is_empty()
