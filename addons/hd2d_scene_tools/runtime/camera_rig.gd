@tool
class_name HD2DCameraRig
extends Node3D

## Presets change framing only, never the target, bounds, stage mode or renderer.
static func preset_settings(index: int) -> Dictionary:
	match index:
		0:
			return {"yaw_degrees":0.0,"pitch_degrees":5.19,"distance":43.9,"field_of_view":15.01,"focus_height":2.02,"frame_size":18.0,"orthographic":false}
		1:
			return {"yaw_degrees":0.0,"pitch_degrees":45.0,"distance":36.0,"field_of_view":50.0,"focus_height":2.0,"frame_size":17.0,"orthographic":true}
		2:
			return {"yaw_degrees":0.0,"pitch_degrees":45.0,"distance":35.0,"field_of_view":25.0,"focus_height":2.0,"frame_size":17.0,"orthographic":false}
		3:
			return {"yaw_degrees":0.0,"pitch_degrees":45.0,"distance":30.0,"field_of_view":30.0,"focus_height":2.0,"frame_size":17.0,"orthographic":false}
	return {}

@export var target_path: NodePath
@export_range(-180,180,0.1) var yaw_degrees: float = 0.0
@export_range(5,85,0.1) var pitch_degrees: float = 22.0
@export_range(2,100,0.1) var distance: float = 22.0
@export var orthographic: bool = true
@export_range(2,100,0.1) var frame_size: float = 18.0
@export_range(0,20,0.1) var smoothing: float = 8.0
@export var follow_bounds: Rect2 = Rect2(-120,-120,240,240)
@export var bounds_enabled: bool = false
@export var focus_height: float = 1.0
@export var map_zoom_enabled: bool = false
@export var map_zoom_range: Vector2 = Vector2(30,760)
@export_range(5,100,0.01) var field_of_view: float = 50.0
var camera: Camera3D
var target_override: Node3D
var locked := true
var preview_active := false
var free_yaw: float
var free_pitch: float
var free_distance: float
var focus := Vector3.ZERO

func _ready() -> void:
	camera=Camera3D.new()
	camera.name="RenderCamera"
	add_child(camera)
	camera.current=true
	reset_view()

func reset_view() -> void:
	free_yaw=yaw_degrees
	free_pitch=pitch_degrees
	free_distance=distance
	var target := get_target()
	focus=(target.global_position if target else global_position)+Vector3.UP*focus_height
	_apply_camera()

func get_target() -> Node3D:
	if is_instance_valid(target_override): return target_override
	var stage := get_parent() as HD2DStage
	if stage:
		var player := stage.character()
		if player and player.role==0: return player
	return get_node_or_null(target_path) as Node3D if not target_path.is_empty() else null

func set_locked(value: bool) -> void:
	locked=value
	if value: reset_view()

func orbit(delta: Vector2) -> void:
	if locked: return
	free_yaw-=delta.x*0.3
	free_pitch=clampf(free_pitch+delta.y*0.3,-80,85)
	_apply_camera()

func pan(delta: Vector2) -> void:
	if locked or camera==null: return
	focus+=(-camera.global_basis.x*delta.x+camera.global_basis.y*delta.y)*free_distance*0.0015
	_apply_camera()

func zoom(amount: float) -> void:
	if map_zoom_enabled and locked:
		frame_size=clampf(frame_size*pow(1.1,amount),map_zoom_range.x,map_zoom_range.y)
		_apply_camera()
		return
	if locked: return
	free_distance=clampf(free_distance*pow(1.1,amount),1,200)
	_apply_camera()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() and not preview_active: return
	if locked:
		var target := get_target()
		if target:
			var desired := target.global_position+Vector3.UP*focus_height
			if bounds_enabled:
				desired.x=clampf(desired.x,follow_bounds.position.x,follow_bounds.end.x)
				desired.z=clampf(desired.z,follow_bounds.position.y,follow_bounds.end.y)
			focus=focus.lerp(desired,1-exp(-smoothing*delta)) if smoothing>0 else desired
	_apply_camera()

func _apply_camera() -> void:
	if not is_instance_valid(camera): return
	var pitch := deg_to_rad(pitch_degrees if locked else free_pitch)
	var yaw := deg_to_rad(yaw_degrees if locked else free_yaw)
	var dist := distance if locked else free_distance
	if map_zoom_enabled and locked: dist=maxf(dist,frame_size*1.2)
	camera.global_position=focus+Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*dist
	camera.look_at(focus,Vector3.UP)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL if orthographic and locked else Camera3D.PROJECTION_PERSPECTIVE
	camera.size=frame_size
	camera.fov=field_of_view
	camera.far=1500
