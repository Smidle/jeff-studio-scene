@tool
extends "building_architecture.gd"
## Exact facade counts; v2 recipes retain their original builder and materials.

func _init() -> void:
	revision=3;material_provider=preload("../runtime/building_materials_v3.gd")

func face(points: Array, role: String, tint: Color=Color.WHITE) -> void:
	if points.size()<3: return
	var n: Vector3=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
	if n.length_squared()<0.5: return
	var u: Vector3=(points[1]-points[0]).normalized()
	if role=="wood" and (points[2]-points[1]).length()>(points[1]-points[0]).length(): u=(points[2]-points[1]).normalized()
	var v := n.cross(u).normalized()
	# Non-uniformly fitted frames retain unit normals and the same pixel density.
	var normal := (xf.basis.inverse().transposed()*n).normalized()
	u=(xf.basis*u).normalized();v=(xf.basis*v).normalized()
	if not buckets.has(role):
		buckets[role]=SurfaceTool.new();buckets[role].begin(Mesh.PRIMITIVE_TRIANGLES)
	var st: SurfaceTool=buckets[role]
	for i in range(1,points.size()-1):
		for index in [0,i+1,i]:
			var p: Vector3=points[index];var scaled := xf.basis*p
			st.set_color(tint);st.set_normal(normal)
			st.set_uv(Vector2(scaled.dot(u),scaled.dot(v))/1.6);st.add_vertex(xf*p)
		triangles+=1

func facade(w: float, h: float, floor_index: int, columns: int, front: bool, kind: int) -> void:
	var entrance := front and floor_index==0
	var band := "wood" if style!="desert" else "trim"
	for y in [0.07,h-0.12]: box(Vector3(0,y,0.06),Vector3(w+0.08,0.15,0.16),band)
	if entrance: Parts.door(self,Vector3.ZERO,style,variant)
	# A door occupies its own interval. Counts never describe structural bays.
	var intervals: Array=[]
	if entrance:
		intervals.append({"left":-w*0.5+0.16,"right":-0.91,"count":ceili(columns/2.0)})
		intervals.append({"left":0.91,"right":w*0.5-0.16,"count":floori(columns/2.0)})
	else: intervals.append({"left":-w*0.5+0.16,"right":w*0.5-0.16,"count":columns})
	var positions: Array=[];var posts: Array=[-w*0.5,w*0.5]
	var original := xf
	for interval in intervals:
		if interval.count==0: continue
		var span: float=(interval.right-interval.left)/interval.count
		for i in int(interval.count):
			var x: float=interval.left+span*(i+0.5)
			# Scale the complete frame/shutters, including their overhang, together.
			var outer := 1.64 if style=="forest" else 1.30
			var scale_x := minf(1.0,span*0.84/outer)
			xf=original*Transform3D(Basis.from_scale(Vector3(scale_x,1,1)),Vector3(x,h*0.55,0.025))
			Parts.window(self,Vector3.ZERO,0.94,1.05,style,variant+positions.size())
			if ornate and style=="forest" and floor_index==0 and (positions.size()+variant)%2==0:
				Parts.planter(self,Vector3(0,-0.76,0.205),1.14)
			positions.append({"x":x,"outer_width":outer*scale_x})
			if i>0: posts.append(interval.left+span*i)
	xf=original
	for x in posts:
		if style!="desert":
			box(Vector3(x,h*0.5,0.08),Vector3(0.14,h,0.16),"wood")
			if style=="jiangnan":
				box(Vector3(x,h-0.28,0.12),Vector3(0.30,0.13,0.24),"wood")
				box(Vector3(x,h-0.13,0.12),Vector3(0.48,0.12,0.30),"trim")
			else:
				for direction in [-1,1]:
					if absf(x+direction*0.48)<w*0.5-0.03:
						beam(Vector3(x,h-0.66,0.09),Vector3(x+direction*0.48,h-0.15,0.09),0.10,"wood")
		elif absf(x)>=w*0.5-0.01:
			for y in range(5): box(Vector3(x,y*h/5+0.22,0.075),Vector3(0.27,0.19,0.20),"stone")
	if style=="desert":
		for i in maxi(3,roundi(w/0.45)):
			box(Vector3(-w*0.5+0.22+i*0.45,h-0.34,0.095),Vector3(0.15,0.07,0.10),"accent")
	if entrance and kind==1: Parts.signboard(self,Vector3(0,2.40,0.19),minf(w*0.55,2.5),style)
