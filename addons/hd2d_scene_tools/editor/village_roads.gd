@tool
extends RefCounted
## Sparse union rasterization: closed rings, junctions and plaza share one surface.
static func mesh(data: Dictionary) -> ArrayMesh:
	var roads: Array=data.get("roads",[])
	if roads.is_empty(): return null
	var narrow := INF
	for road in roads: narrow=minf(narrow,float(road.width))
	var step := clampf(narrow/4.0,0.15,0.4)
	var cells := {}
	for road in roads:
		var points: PackedVector3Array=road.points
		var radius := float(road.width)*0.5
		for i in range(points.size()-1):
			var a := Vector2(points[i].x,points[i].z);var b := Vector2(points[i+1].x,points[i+1].z)
			var lo := Vector2i((a.min(b)-Vector2.ONE*radius)/step-Vector2.ONE)
			var hi := Vector2i((a.max(b)+Vector2.ONE*radius)/step+Vector2.ONE)
			for z in range(lo.y,hi.y+1):
				for x in range(lo.x,hi.x+1):
					var key := Vector2i(x,z)
					if cells.has(key): continue
					var center := (Vector2(key)+Vector2.ONE*0.5)*step
					if center.distance_to(Geometry2D.get_closest_point_to_segment(center,a,b))<=radius: cells[key]=true
	if cells.is_empty(): return null
	var ground: HD2DTerrainData=data.get("draft_terrain")
	var to_local: Transform3D=data.get("terrain_transform",Transform3D.IDENTITY)
	var to_ground := to_local.affine_inverse()
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Deterministic ordering, independent of dictionary hash order.
	var ordered := cells.keys();ordered.sort()
	for key: Vector2i in ordered:
		for delta in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
			var xy := Vector2(key+delta)*step
			var point := Vector3(xy.x,0,xy.y)
			if ground:
				var p := to_ground*point;p.y=ground.height_at(p.x,p.z)
				point=to_local*p
			point.y+=0.045
			st.set_uv(xy/1.6);st.add_vertex(point)
	st.generate_normals()
	return st.commit()

static func add_to(parent: Node3D,data: Dictionary) -> MeshInstance3D:
	var value := mesh(data)
	if value==null: return null
	var node := MeshInstance3D.new();node.name="Paving";node.mesh=value
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.material_override=preload("../runtime/building_materials.gd").material(str(data.options.get("material_style","jiangnan")),"paving",int(data.options.get("appearance",0)),int(data.options.get("appearance_seed",101)))
	parent.add_child(node)
	return node
