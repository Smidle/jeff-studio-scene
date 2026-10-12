@tool
extends Node3D
## Bounded, read-only mesh queries for pooled splashes. Wetness needs no spatial scan.
var controller: Node3D
var geometry_nodes: Array[MeshInstance3D]=[]
var material_nodes: Array[GeometryInstance3D]=[]
var geometry_revision := 1
var capacity := 0
var splashes: MultiMeshInstance3D
var _signature := 0
var _meshes: Dictionary={}
var _records: Array[Dictionary]=[]
var _ages := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _spawn := 0.0
var _slot := 0
var _geometry_dirty := true
var _material_sync_queued := false

func setup(owner_controller: Node3D) -> void:
	controller=owner_controller
	splashes=MultiMeshInstance3D.new();splashes.name="RainSplashes"
	splashes.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var multimesh:=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_colors=true
	var quad:=QuadMesh.new();quad.size=Vector2(0.36,0.36)
	var material:=ShaderMaterial.new();material.shader=preload("../shaders/weather_splash.gdshader");quad.material=material
	multimesh.mesh=quad;splashes.multimesh=multimesh;add_child(splashes)
	_register_tree(controller.stage)
	get_tree().node_added.connect(_node_added);get_tree().node_removed.connect(_node_removed)
	refresh_geometry()

func _register_tree(node: Node) -> void:
	if node==controller:return
	_node_added(node)
	for child in node.get_children():_register_tree(child)

func _node_added(node: Node) -> void:
	if not (node is MeshInstance3D or node is MultiMeshInstance3D) or controller.is_ancestor_of(node) or not controller.stage.is_ancestor_of(node):return
	if not material_nodes.has(node):
		material_nodes.append(node);geometry_revision+=1
		if not _material_sync_queued:
			_material_sync_queued=true;_sync_materials.call_deferred()
	if node is MeshInstance3D and not geometry_nodes.has(node):geometry_nodes.append(node);_geometry_dirty=true

func _sync_materials() -> void:
	_material_sync_queued=false
	if is_instance_valid(controller) and not controller.settings.is_empty():controller.collect_materials()

func _node_removed(node: Node) -> void:
	if not node is GeometryInstance3D:return
	if material_nodes.has(node):material_nodes.erase(node);geometry_revision+=1
	if node is MeshInstance3D and geometry_nodes.has(node):geometry_nodes.erase(node);_geometry_dirty=true

func set_seed(value: int) -> void:_rng.seed=value

func set_capacity(value: int) -> void:
	if value==capacity:return
	capacity=value;splashes.multimesh.instance_count=value;_ages.resize(value);_ages.fill(-1)
	_slot=0;_spawn=0
	for i in value:splashes.multimesh.set_instance_color(i,Color(1,1,1,0))

func refresh_geometry() -> void:
	var signature:Array=[]
	for node in geometry_nodes:
		if not is_instance_valid(node) or not node.mesh:continue
		signature.append([node.get_instance_id(),node.mesh.get_rid(),node.global_transform,node.is_visible_in_tree()])
	var next:int=hash(signature)
	if not _geometry_dirty and next==_signature:return
	_signature=next;_geometry_dirty=false;_records.clear();geometry_revision+=1
	for node in geometry_nodes:
		if not is_instance_valid(node) or not node.mesh or not node.is_visible_in_tree():continue
		if absf(node.global_basis.determinant())<0.000001:continue
		var material:Material=node.material_override
		if material is ShaderMaterial and material.shader and material.shader.resource_path.get_file() in ["card.gdshader","character.gdshader","mesh_foliage.gdshader","water.gdshader","lava.gdshader"]:continue
		_records.append({"node":weakref(node),"mesh":node.mesh,"inverse":node.global_transform.affine_inverse(),"transform":node.global_transform,"aabb":node.global_transform*node.mesh.get_aabb()})
	var live_meshes:Dictionary={}
	for row in _records:live_meshes[row.mesh.get_instance_id()]=true
	for id in _meshes.keys():
		if not live_meshes.has(id):_meshes.erase(id)
	if is_instance_valid(controller.field):RenderingServer.particles_collision_height_field_update(controller.field.get_base())

func _prepare_mesh() -> void:
	# One BVH per unique mesh; preparing at most one per frame avoids a large single scan.
	for row in _records:
		var id:int=row.mesh.get_instance_id()
		if _meshes.has(id):continue
		_meshes[id]=row.mesh.generate_triangle_mesh();return

func surface_hit(x: float, z: float) -> Dictionary:
	var top:float=controller.center.y+80
	var bottom:float=controller.center.y-80
	var result:Dictionary={}
	for row in _records:
		var box:AABB=row.aabb
		if x<box.position.x or x>box.end.x or z<box.position.z or z>box.end.z:continue
		var triangle:TriangleMesh=_meshes.get(row.mesh.get_instance_id())
		if not triangle:continue
		var hit:Dictionary=triangle.intersect_segment(row.inverse*Vector3(x,top,z),row.inverse*Vector3(x,bottom,z))
		if hit.is_empty():continue
		var point:Vector3=row.transform*hit.position
		if not result.is_empty() and point.y<=result.position.y:continue
		var normal:Vector3=(row.inverse.basis.transposed()*hit.normal).normalized()
		if normal.y<0:normal=-normal
		result={"position":point,"normal":normal}
	return result

func tick(delta: float) -> void:
	var radius:float=controller.effective_radius
	var anchor:Vector3=controller.center
	# Use world coordinates for the pool; moving the weather volume cannot drag landed water.
	splashes.global_transform=Transform3D.IDENTITY
	for i in capacity:
		if _ages[i]<0:continue
		_ages[i]+=delta
		if _ages[i]>=0.4:_ages[i]=-1;splashes.multimesh.set_instance_color(i,Color(1,1,1,0))
		else:splashes.multimesh.set_instance_color(i,Color(1,1,1,1-_ages[i]/0.4))
	var rain:float=controller.weights[2]+controller.weights[6]
	if not controller.settings.weather_splashes or rain<=0.001:return
	_prepare_mesh()
	_spawn+=delta*rain*minf(capacity*1.5,180)
	var attempts:int=mini(int(_spawn),4);_spawn-=attempts
	for i in attempts:
		var distance:float=minf(radius,24)
		var hit:=surface_hit(anchor.x+_rng.randf_range(-distance,distance),anchor.z+_rng.randf_range(-distance,distance))
		if hit.is_empty() or hit.normal.y<0.35 or controller.sheltered(hit.position+Vector3.UP*0.1):continue
		spawn_splash(hit.position,hit.normal)

func spawn_splash(point: Vector3, normal: Vector3) -> void:
	if capacity<=0:return
	var right:Vector3=Vector3.RIGHT if absf(normal.dot(Vector3.RIGHT))<0.95 else Vector3.FORWARD
	right=(right-normal*right.dot(normal)).normalized()
	var basis:=Basis(right,normal.cross(right).normalized(),normal)
	var scale:float=_rng.randf_range(0.65,1.25)
	splashes.multimesh.set_instance_transform(_slot,Transform3D(basis.scaled(Vector3.ONE*scale),point+normal*0.025))
	splashes.multimesh.set_instance_color(_slot,Color(1,1,1,0.85));_ages[_slot]=0;_slot=(_slot+1)%capacity

func _exit_tree() -> void:
	if get_tree():
		if get_tree().node_added.is_connected(_node_added):get_tree().node_added.disconnect(_node_added)
		if get_tree().node_removed.is_connected(_node_removed):get_tree().node_removed.disconnect(_node_removed)
