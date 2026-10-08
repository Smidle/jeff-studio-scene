@tool
class_name HD2DRoad
extends Node3D
@export var curve: Curve3D:
	set(value):
		if curve and curve.changed.is_connected(_curve_changed): curve.changed.disconnect(_curve_changed)
		curve=value
		if curve:
			curve.bake_interval=0.4
			curve.changed.connect(_curve_changed)
		if is_inside_tree(): rebuild.call_deferred()
@export_range(0.2,20,0.1) var width: float = 3.0
@export_range(0.2,20,0.1) var tile_length: float = 3.0
@export var texture: Texture2D
@export var tint: Color = Color("bba572")
@export var terrain_path: NodePath
@export var fences: bool = false
@export_range(0.5,10,0.1) var fence_spacing: float = 2.0
@export_range(0.2,3,0.1) var fence_height: float = 1.0

func _ready() -> void:
	if curve == null: curve=Curve3D.new()
	if not curve.changed.is_connected(_curve_changed): curve.changed.connect(_curve_changed)
	rebuild()

func _curve_changed() -> void:
	if is_inside_tree(): rebuild()

func ground_point(p: Vector3) -> Vector3:
	var terrain := get_node_or_null(terrain_path) as HD2DTerrain
	if terrain:
		var world := to_global(p)
		world.y=terrain.world_height(world.x,world.z)+0.045
		return to_local(world)
	return p+Vector3.UP*0.045

func rebuild() -> void:
	if not is_inside_tree(): return
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if curve == null or curve.point_count<2: return
	var points := curve.get_baked_points()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var length := 0.0
	for i in range(points.size()-1):
		var direction := (points[i+1]-points[i]).normalized()
		var side := Vector3(-direction.z,0,direction.x).normalized()*width*0.5
		var next_length := length+points[i].distance_to(points[i+1])
		var a := ground_point(points[i]-side)
		var b := ground_point(points[i]+side)
		var c := ground_point(points[i+1]-side)
		var d := ground_point(points[i+1]+side)
		var vertices := [a,c,b,b,c,d]
		var uvs := [Vector2(0,length/tile_length),Vector2(0,next_length/tile_length),Vector2(1,length/tile_length),Vector2(1,length/tile_length),Vector2(0,next_length/tile_length),Vector2(1,next_length/tile_length)]
		for j in range(6):
			st.set_uv(uvs[j])
			st.add_vertex(vertices[j])
		length=next_length
	st.generate_normals()
	var road := MeshInstance3D.new()
	road.mesh=st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color=tint
	mat.albedo_texture=texture
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	road.material_override=mat
	add_child(road)
	if fences: _build_fences()
	update_gizmos()

func _build_fences() -> void:
	var length := curve.get_baked_length()
	var wood := StandardMaterial3D.new()
	wood.albedo_color=Color("655044")
	for sign_value in [-1.0,1.0]:
		var previous := Vector3.INF
		for i in range(int(length/fence_spacing)+1):
			var distance := minf(i*fence_spacing,length)
			var p := curve.sample_baked(distance)
			var tangent := curve.sample_baked(minf(distance+0.1,length))-curve.sample_baked(maxf(distance-0.1,0))
			var side: Vector3 = Vector3(-tangent.z,0,tangent.x).normalized()*(width*0.5+0.25)*sign_value
			var base := ground_point(p+side)
			_box_between(base,base+Vector3.UP*fence_height,0.1,wood)
			if previous!=Vector3.INF:
				for h in [0.35,0.8]: _box_between(previous+Vector3.UP*fence_height*h,base+Vector3.UP*fence_height*h,0.065,wood)
			previous=base

func _box_between(a: Vector3, b: Vector3, thickness: float, mat: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size=Vector3(thickness,a.distance_to(b),thickness)
	node.mesh=mesh
	node.material_override=mat
	add_child(node)
	node.position=(a+b)*0.5
	var up := (b-a).normalized()
	var axis := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD))<0.98 else Vector3.RIGHT
	var right := up.cross(axis).normalized()
	node.basis=Basis(right,up,right.cross(up))

func contains_world_point(world: Vector3, margin: float) -> bool:
	if curve==null or curve.point_count<2: return false
	var p := to_local(world)
	var points := curve.get_baked_points()
	for i in range(points.size()-1):
		var a := Vector2(points[i].x,points[i].z)
		var b := Vector2(points[i+1].x,points[i+1].z)
		var q := Vector2(p.x,p.z)
		var t := clampf((q-a).dot(b-a)/maxf((b-a).length_squared(),0.0001),0,1)
		if q.distance_to(a.lerp(b,t))<=width*0.5+margin: return true
	return false
