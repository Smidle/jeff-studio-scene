@tool
extends RefCounted
const Materials=preload("../runtime/building_materials.gd")
const Builder=preload("building_generator.gd")
static func add_walls(parent: Node3D, data: Dictionary, collision: bool) -> void:
	var style := str(data.options.get("material_style","jiangnan"))
	var look := int(data.options.get("appearance",0)); var seed_value := int(data.options.get("appearance_seed",101))
	var materials := {"wall":Materials.material(style,"wall",look,seed_value),"stone":Materials.material(style,"stone",look,seed_value),"roof":Materials.material(style,"roof",look,seed_value)}
	for i in data.get("walls",[]).size():
		var item: Dictionary=data.walls[i];var size: Vector3=item.size
		var builder := Builder.new()
		builder.box(Vector3.UP*size.y*0.5,size,"wall")
		builder.box(Vector3.UP*0.13,Vector3(size.x+0.08,0.26,size.z+0.08),"stone")
		builder.box(Vector3.UP*(size.y+0.06),Vector3(size.x+0.15,0.16,size.z+0.15),"roof")
		if i%3==0:
			builder.box(Vector3.UP*(size.y+0.16)*0.5,Vector3(0.55,size.y+0.16,0.55),"stone")
			builder.box(Vector3.UP*(size.y+0.25),Vector3(0.72,0.18,0.72),"roof")
		var mesh := ArrayMesh.new()
		for role in builder.buckets:
			var part: ArrayMesh=builder.buckets[role].commit()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.surface_get_arrays(0));mesh.surface_set_material(mesh.get_surface_count()-1,materials[role])
		var node := MeshInstance3D.new(); node.name="Wall_%03d"%i;node.mesh=mesh;node.set_meta("village_wall",true)
		node.position=item.position; node.rotation.y=float(item.get("yaw",0));parent.add_child(node)
		if collision:
			var body := StaticBody3D.new();node.add_child(body)
			var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=size+Vector3.UP*0.18;shape.shape=box;shape.position.y=(size.y+0.18)*0.5;body.add_child(shape)
	for i in data.get("gates",[]).size():
		var item: Dictionary=data.gates[i]
		var gate := Node3D.new();gate.name="Gate_%02d"%i;parent.add_child(gate);gate.position=item.position;gate.rotation.y=item.yaw
		var height := maxf(2.8,float(data.options.get("wall_height",1.8))+0.5)
		var pieces := [{"center":Vector3(0,height,0),"size":Vector3(item.width+0.9,0.3,0.8),"role":"roof"}]
		for side in [-1,1]:pieces.append({"center":Vector3(side*(item.width*0.5+0.2),height*0.5,0),"size":Vector3(0.4,height,0.55),"role":"stone"})
		for piece in pieces:
			var node := MeshInstance3D.new();var mesh := BoxMesh.new();mesh.size=piece.size;node.mesh=mesh;node.position=piece.center;node.material_override=materials[piece.role];gate.add_child(node)
			if collision:
				var body := StaticBody3D.new();node.add_child(body);var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=piece.size;shape.shape=box;body.add_child(shape)
static func add_paving(parent: Node3D,data: Dictionary) -> void:
	if int(data.options.get("paving_mode",0))!=2: return
	preload("village_roads.gd").add_to(parent,data)
