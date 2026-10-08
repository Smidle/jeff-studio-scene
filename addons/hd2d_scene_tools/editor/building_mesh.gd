@tool
extends RefCounted
## Jeff's shared construction primitives. Metre-based UVs; clockwise Godot faces.
var buckets := {}
var xf := Transform3D.IDENTITY
var triangles := 0
var features := {}

func mark(key: String) -> void:
	features[key]=int(features.get(key,0))+1

func face(points: Array, role: String, tint: Color=Color.WHITE) -> void:
	if points.size()<3: return
	var n: Vector3=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
	if n.length_squared()<0.5: return
	var u: Vector3=(points[1]-points[0]).normalized()
	# Timber grain follows the long side of each component, not world coordinates.
	if role=="wood" and (points[2]-points[1]).length()>(points[1]-points[0]).length(): u=(points[2]-points[1]).normalized()
	var v := n.cross(u).normalized()
	if not buckets.has(role):
		buckets[role]=SurfaceTool.new();buckets[role].begin(Mesh.PRIMITIVE_TRIANGLES)
	var st: SurfaceTool=buckets[role]
	for i in range(1,points.size()-1):
		for index in [0,i+1,i]:
			var p: Vector3=points[index]
			st.set_color(tint);st.set_normal(xf.basis*n)
			st.set_uv(Vector2(p.dot(u),p.dot(v))/1.6);st.add_vertex(xf*p)
		triangles+=1

func box(c: Vector3, size: Vector3, role: String, tint: Color=Color.WHITE) -> void:
	var h := size*0.5
	for side in [-1,1]:
		var faces := [
			[Vector3(-h.x,-h.y,side*h.z),Vector3(h.x,-h.y,side*h.z),Vector3(h.x,h.y,side*h.z),Vector3(-h.x,h.y,side*h.z)],
			[Vector3(side*h.x,-h.y,h.z),Vector3(side*h.x,-h.y,-h.z),Vector3(side*h.x,h.y,-h.z),Vector3(side*h.x,h.y,h.z)],
			[Vector3(-h.x,side*h.y,h.z),Vector3(h.x,side*h.y,h.z),Vector3(h.x,side*h.y,-h.z),Vector3(-h.x,side*h.y,-h.z)]]
		for vertices in faces:
			if side<0: vertices.reverse()
			for j in vertices.size(): vertices[j]+=c
			face(vertices,role,tint)

func beam(a: Vector3, z: Vector3, width: float, role: String, depth: float=-1.0) -> void:
	var delta := z-a
	if delta.length()<0.0001: return
	var y := delta.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z)<0.9 else Vector3.RIGHT).normalized()
	var before := xf
	xf=xf*Transform3D(Basis(x,y,x.cross(y)),(a+z)*0.5)
	box(Vector3.ZERO,Vector3(width,delta.length(),width if depth<0 else depth),role)
	xf=before

func cylinder(c: Vector3, radius: float, height: float, role: String, sides: int=8) -> void:
	var top := [];var bottom := []
	for i in sides:
		var a := TAU*i/sides;var z := TAU*(i+1)/sides
		var p := c+Vector3(cos(a)*radius,-height*0.5,sin(a)*radius)
		var q := c+Vector3(cos(z)*radius,-height*0.5,sin(z)*radius)
		face([p,p+Vector3.UP*height,q+Vector3.UP*height,q],role)
		bottom.append(p);top.push_front(p+Vector3.UP*height)
	face(top,role);face(bottom,role)

func panel_frame(c: Vector3, w: float, h: float, thickness: float, role: String) -> void:
	for s in [-1,1]:
		box(c+Vector3(s*w*0.5,0,0),Vector3(thickness,h+thickness,thickness),role)
		box(c+Vector3(0,s*h*0.5,0),Vector3(w,thickness,thickness),role)
