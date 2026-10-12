@tool
class_name HD2DWeatherShelter
extends Node3D
## A precipitation exclusion box. Independent of the camera; outdoors stays visible.
@export var enabled := true
@export var size := Vector3(6, 5, 5):
	set(value):
		size = value.abs().max(Vector3.ONE*0.05)
		if Engine.is_editor_hint(): update_gizmos()

func _enter_tree() -> void:
	add_to_group("hd2d_weather_shelters")

func contains_point(point: Vector3) -> bool:
	return enabled and AABB(-size * 0.5, size).has_point(to_local(point))
