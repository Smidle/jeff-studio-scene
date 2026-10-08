@tool
extends Node
## Walk the leader's recorded segments in order; do not steer across later corners.
var trails: Dictionary={}
var leader: HD2DCharacter
var last_point := Vector3.INF

func _ready() -> void: process_physics_priority=-10

func _physics_process(_delta: float) -> void:
	var stage := get_parent() as HD2DStage
	if not stage or (Engine.is_editor_hint() and not stage.preview_active): return
	var hero := stage.character()
	var actors := stage.characters()
	if hero!=leader:
		trails.clear(); leader=hero; last_point=Vector3.INF
	if not hero or not hero.profile:
		for actor in actors:
			if actor.role==1: actor.set_movement_input(Vector2.ZERO)
		return
	var point := hero.global_position
	# Teleport starts a fresh route. Companions approach it physically, never teleport through walls.
	if last_point.is_finite() and point.distance_to(last_point)>12: trails.clear(); last_point=Vector3.INF
	var add_point := not last_point.is_finite() or point.distance_to(last_point)>0.08
	var rank := 0
	for actor in actors:
		if actor.role!=1 or not actor.profile: continue
		rank+=1
		if not trails.has(actor): trails[actor]=[point]
		var route: Array=trails[actor]
		if add_point and route[-1].distance_to(point)>0.02:
			# Merge straight segments, preserving turns. Dense per-frame waypoints
			# otherwise make followers brake at every sample and lag indefinitely.
			if route.size()>1 and (route[-1]-route[-2]).normalized().dot((point-route[-1]).normalized())>0.995:
				route[-1]=point
			else:route.append(point)
		if route.size()>4096: route.resize(4096) # Blocked followers keep the next corner, not a shortcut.
		while route.size()>1 and Vector2(route[0].x-actor.global_position.x,route[0].z-actor.global_position.z).length()<0.13: route.pop_front()
		var distance := actor.global_position.distance_to(route[0])
		for i in range(1,route.size()): distance+=route[i-1].distance_to(route[i])
		var remaining := distance-rank*actor.follow_spacing
		var direction := Vector2(route[0].x-actor.global_position.x,route[0].z-actor.global_position.z)
		var running := hero.is_running or remaining>actor.follow_spacing*2
		var speed := maxf(actor.profile.move_speed,actor.profile.run_speed) if running else actor.profile.move_speed
		var strength := minf(minf(direction.length()*5,remaining*3)/maxf(speed,0.1),1)
		actor.set_movement_input(direction.normalized()*maxf(0,strength) if stage.stage_mode==0 and not stage.paused else Vector2.ZERO,running)
	if add_point: last_point=point
	for actor in trails.keys():
		if not is_instance_valid(actor) or not actors.has(actor): trails.erase(actor)
