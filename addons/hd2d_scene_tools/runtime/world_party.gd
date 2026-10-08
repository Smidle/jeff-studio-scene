@tool
class_name HD2DWorldParty
extends Node
## Followers consume the leader's travelled polyline, including corners and bridges.
@export var spacing: float = 1.7
@export var movement_speed: float = 7.0
var trail := PackedVector3Array()
var overview := false
var previous_frame := 75.0
var settling_frames := 0
var controls_enabled := true

func _ready() -> void:
 process_physics_priority=-10
 reset_trail()

func reset_trail() -> void:
 var stage := get_parent() as HD2DStage
 if not stage or not stage.character(): return
 var point := stage.character().global_position
 trail=PackedVector3Array([point])
 for actor in stage.characters():
  actor.velocity=Vector3.ZERO
  if actor!=stage.character(): actor.global_position=point
 settling_frames=3

func _physics_process(_delta: float) -> void:
 var stage := get_parent() as HD2DStage
 if not stage or (Engine.is_editor_hint() and not stage.preview_active): return
 var hero := stage.character()
 if not hero: return
 if not (stage.terrain().data as HD2DWorldMapData).party_enabled:
  for actor in stage.characters(): actor.visible=false;actor.set_physics_process(false)
  return
 for actor in stage.characters(): actor.visible=true;actor.set_physics_process(true)
 if settling_frames>0:
  settling_frames-=1
  for actor in stage.characters(): actor.input_enabled=false
  return
 hero.input_enabled=not overview and controls_enabled
 if trail.is_empty(): trail.append(hero.global_position)
 if trail[0].distance_to(hero.global_position)>0.1:
  trail.insert(0,hero.global_position)
  if trail.size()>512: trail.resize(512)
 var index := 0
 for actor in stage.characters():
  actor.profile.move_speed=movement_speed
  if actor==hero: continue
  index+=1; actor.input_enabled=not overview and controls_enabled
  var remaining := spacing*index
  var target := trail[trail.size()-1]
  for j in range(1,trail.size()):
   var length := trail[j-1].distance_to(trail[j])
   if remaining<=length:
    target=trail[j-1].lerp(trail[j],remaining/maxf(length,0.001)); break
   remaining-=length
  var delta := Vector2(target.x-actor.global_position.x,target.z-actor.global_position.z)
  actor.set_movement_input(delta.normalized()*minf(delta.length()*4.0,1.0) if delta.length()>0.12 else Vector2.ZERO)

func locate(point: Vector3) -> void:
 var stage := get_parent() as HD2DStage
 var terrain := stage.terrain() as HD2DWorldMap
 if not terrain: return
 terrain.prepare_at(point)
 var local := terrain.to_local(point)
 point.y=terrain.world_height(point.x,point.z)+0.65
 stage.character().global_position=point
 overview=false;stage.camera_rig().frame_size=previous_frame;stage.camera_rig().target_override=null
 stage.camera_rig().reset_view(); reset_trail()

func set_overview(value: bool) -> void:
 var stage := get_parent() as HD2DStage
 var rig := stage.camera_rig()
 overview=value
 if value:
  previous_frame=rig.frame_size
  rig.target_override=stage.terrain(); rig.frame_size=stage.terrain().data.size_m*1.08
 else:
  rig.target_override=null;rig.frame_size=previous_frame
 rig.reset_view()

func _unhandled_input(event: InputEvent) -> void:
 var stage := get_parent() as HD2DStage
 if Engine.is_editor_hint() and not stage.preview_active: return
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP: stage.camera_rig().zoom(-1)
  elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: stage.camera_rig().zoom(1)
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_M:
  set_overview(not overview)
