@tool
extends Node3D
## Read-only settings view for the unchanged Sandstorm and thunder implementation.
class Effect extends "weather.gd":
	func create_precipitation() -> void:
		if stage.weather_mode==5: super.create_precipitation()

var source: Node3D
var settings: Dictionary={}
var effect: Node3D
var gain := 1.0

func _get(property: StringName) -> Variant:
	if property==&"weather_intensity": return float(settings.get("weather_intensity",0.65))*gain
	if settings.has(property): return settings[property]
	return source.get(property) if is_instance_valid(source) else null

func camera_rig(): return source.camera_rig()
func character(): return source.character()
func terrain(): return source.terrain()

func configure(stage: Node3D, values: Dictionary, mode: int) -> void:
	source=stage;settings=values.duplicate();settings.weather_mode=mode
	global_position=source.global_position
	if not is_instance_valid(effect):
		effect=Effect.new();add_child(effect)
	gain=1.0;effect.configure(self)

func set_gain(value: float) -> void:
	gain=clampf(value,0,1)
	if is_instance_valid(effect) and is_instance_valid(effect.particles):
		effect.particles.color=Color(1,1,1,gain)

func stop() -> void:
	if not is_instance_valid(effect):return
	settings.weather_mode=0;effect.configure(self)
