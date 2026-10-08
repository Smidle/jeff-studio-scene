@tool
extends "building_architecture_v4.gd"
const Roof5=preload("building_roofs_v5.gd")

func _init() -> void:
	revision=5;material_provider=preload("../runtime/building_materials_v5.gd")

func polygon(points: Array, uvs: Array, role: String, tint: Color=Color.WHITE) -> void:
	if points.size()<3: return
	var n: Vector3=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
	if n.length_squared()<0.5: return
	var normal := (xf.basis.inverse().transposed()*n).normalized()
	if not buckets.has(role): buckets[role]=SurfaceTool.new();buckets[role].begin(Mesh.PRIMITIVE_TRIANGLES)
	var st: SurfaceTool=buckets[role]
	for i in range(1,points.size()-1):
		for j in [0,i+1,i]:
			st.set_color(tint);st.set_normal(normal);st.set_uv(uvs[j]);st.add_vertex(xf*points[j])
		triangles+=1

func face(points: Array, role: String, tint: Color=Color.WHITE) -> void:
	if points.size()<3: return
	var n: Vector3=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
	var u: Vector3=(points[1]-points[0]).normalized()
	if role=="wood" and (points[2]-points[1]).length()>(points[1]-points[0]).length(): u=(points[2]-points[1]).normalized()
	var v := n.cross(u).normalized();u=(xf.basis*u).normalized();v=(xf.basis*v).normalized()
	var uvs: Array=[]
	for p in points:
		var q: Vector3=xf.basis*p;uvs.append(Vector2(q.dot(u),-q.dot(v))/3.2)
	polygon(points,uvs,role,tint)

func roof_face(points: Array, axis: Vector3, origin: Vector3) -> void:
	var uvs: Array=[]
	# A fixed axis for each slope avoids rotated/restarted tiles at triangle boundaries.
	var across := Vector3(-axis.z,0,axis.x)
	for p in points:
		var q: Vector3=p-origin;uvs.append(Vector2(q.dot(axis),q.dot(across))/1.6)
	polygon(points,uvs,"roof")

func panel(c: Vector3,w: float,h: float,role: String,tile_x: bool=false) -> void:
	var repeat := w/3.2 if tile_x else 1.0
	polygon([c+Vector3(-w/2,-h/2,0),c+Vector3(w/2,-h/2,0),c+Vector3(w/2,h/2,0),c+Vector3(-w/2,h/2,0)],[Vector2(0,1),Vector2(repeat,1),Vector2(repeat,0),Vector2(0,0)],role)

func window(c: Vector3,w: float,h: float) -> void:
	mark("layered_window")
	box(c,Vector3(w+0.12,h+0.15,0.09),"wood" if style!="desert" else "stone")
	panel(c+Vector3(0,0,0.053),w,h,"window")
	box(c+Vector3(0,-h/2-0.07,0.10),Vector3(w+0.20,0.12,0.28),"stone" if style=="desert" else "wood")
	if style=="forest":
		for s in [-1,1]: panel(c+Vector3(s*(w/2+0.14),0,0.05),0.24,h,"shutter")

func doorway() -> void:
	mark("framed_door")
	box(Vector3(0,1.08,0.075),Vector3(1.48,2.16,0.16),"stone" if style=="desert" else "wood")
	panel(Vector3(0,1.07,0.165),1.30,2.08,"door")
	if style=="desert":
		for i in 8:
			var a := PI*i/8;var b := PI*(i+1)/8
			beam(Vector3(cos(a)*0.8,1.65+sin(a)*0.70,0.18),Vector3(cos(b)*0.8,1.65+sin(b)*0.70,0.18),0.16,"stone")

func facade(w: float,h: float,floor_index: int,columns: int,front: bool,kind: int) -> void:
	var entrance := front and floor_index==0
	var band := "wood" if style!="desert" else "stone"
	if entrance: doorway()
	panel(Vector3(0,0.32,0.012),w,0.64,"wall_base",true)
	for y in [0.07,h-0.14]: box(Vector3(0,y,0.045),Vector3(w+0.08,0.14,0.13),band)
	var intervals: Array=[]
	if entrance:
		intervals=[{"left":-w/2+0.12,"right":-0.88,"count":ceili(columns/2.0)},{"left":0.88,"right":w/2-0.12,"count":floori(columns/2.0)}]
	else: intervals=[{"left":-w/2+0.15,"right":w/2-0.15,"count":columns}]
	for interval in intervals:
		if interval.count==0: continue
		var span: float=(interval.right-interval.left)/interval.count
		for i in int(interval.count):
			var x: float=interval.left+(i+0.5)*span
			var ww := minf(1.15,span*(0.59 if style=="forest" else 0.72))
			window(Vector3(x,h*0.55,0.035),maxf(0.16,ww),1.08)
	for s in [-1,1]:
		box(Vector3(s*w/2,h/2,0.04),Vector3(0.16,h,0.13),band)
		if style=="jiangnan":
			box(Vector3(s*(w/2-0.13),h-0.32,0.1),Vector3(0.44,0.15,0.26),"wood")
		elif style=="forest": beam(Vector3(s*w/2,h-0.8,0.06),Vector3(s*(w/2-0.65),h-0.15,0.06),0.14,"wood")
	if kind==1 and entrance:
		panel(Vector3(w*0.28,h-0.5,0.19),minf(1.4,w*0.24),0.50,"sign")

func roof_at(c: Vector3,w: float,d: float) -> void:
	var p := recipe.parameters
	var rise := tan(deg_to_rad(clampf(float(p.get("pitch",32)),15,50)))*(w if style=="forest" else d)*0.5
	var eave := float(p.get("eave",0.5));var choice := int(p.get("roof",0))
	if choice==2 or (choice==0 and style=="desert"): Roof5.terrace(self,c,w,d,eave)
	elif style=="jiangnan" and choice==0: Roof5.hip(self,c,w,d,rise,eave)
	else: Roof5.gable(self,c,w,d,rise,eave)

func porch(w: float,d: float,base: float,balcony: bool,kind: int,flat: bool) -> void:
	mark("supported_porch")
	var wide := recipe.type_id in ["inn","general_store"] or style=="jiangnan"
	var pw := w*0.90 if wide else minf(w*0.8,3.0)
	var depth := 1.15;var top := base+2.62
	for s in [-1,1]:
		var c := Vector3(s*pw/2,base,d/2+depth)
		post(c,2.62)
		beam(c+Vector3(0,2.10,0),c+Vector3(-s*0.50,2.57,0),0.12,"wood")
	beam(Vector3(-pw/2,top,d/2+depth),Vector3(pw/2,top,d/2+depth),0.17,"wood")
	if balcony:
		box(Vector3(0,base+2.8,d/2+depth/2),Vector3(pw+0.20,0.14,depth+0.2),"wood")
		Parts.rail(self,Vector3(-pw/2,base+2.94,d/2+depth),Vector3(pw/2,base+2.94,d/2+depth),0.72,style)
		for s in [-1,1]: Parts.rail(self,Vector3(s*pw/2,base+2.94,d/2),Vector3(s*pw/2,base+2.94,d/2+depth),0.72,style)
	elif style=="desert" or recipe.type_id=="general_store":
		polygon([Vector3(-pw/2,top,d/2),Vector3(-pw/2,top-0.22,d/2+depth+0.25),Vector3(pw/2,top-0.22,d/2+depth+0.25),Vector3(pw/2,top,d/2)],[Vector2(0,0),Vector2(0,1),Vector2(pw/2,1),Vector2(pw/2,0)],"cloth")
	elif style=="jiangnan": Roof5.hip(self,Vector3(0,top,d/2+0.45),pw,1.20,0.40,0.22)
	else: Roof5.gable(self,Vector3(0,top,d/2+0.45),pw,1.3,0.75,0.18)
	if ornate:
		for s in [-1,1]: Parts.lantern(self,Vector3(s*(pw/2-0.23),top-0.45,d/2+depth),style)

func build(profile: HD2DBuildingProfile) -> HD2DAsset:
	recipe=profile;definition=Catalog.entry(profile.type_id);style=profile.style
	var rng := RandomNumberGenerator.new();rng.seed=profile.detail_seed+profile.type_id.hash();detail_variant=rng.randi_range(0,5)
	if definition.archetype!="house": return super.build(profile)
	variant=posmod(profile.shape_seed,6);ornate=bool(profile.parameters.get("ornament",true))
	var p := profile.parameters;var w := clampf(float(p.width),3,10)*(1.12 if profile.kind==2 else 1.0)
	var d := clampf(float(p.depth),3,10)*(1.08 if profile.kind==2 else 1.0)
	var floors := clampi(int(p.floors),1,3);var columns := clampi(int(p.windows),1,4)
	var base := 0.36;var top := base+floors*2.8
	foundation(w,d,base)
	var rw := w;var rd := d;var rc := Vector3(0,top,0)
	for f in floors:
		var sw := w;var sd := d;var c := Vector3(0,base+f*2.8,0)
		if style=="desert" and f>0:
			sw=w*0.77;sd=d*0.73;c+=Vector3(w*0.10,0,-d*0.12)
			if f==1: Roof5.terrace(self,Vector3(0,base+2.70,0),w,d,0.15)
			rw=sw;rd=sd;rc=Vector3(c.x,top,c.z)
		storey(c,sw,sd,2.8,f,columns,profile.kind)
	roof_at(rc,rw,rd)
	if bool(p.get("porch",true)) or profile.kind==1: porch(w,d,base,floors>1 and bool(p.get("balcony",true)) and style!="desert",profile.kind,style=="desert")
	if style=="forest" and int(p.get("roof",0))!=2:
		chimney(w,d,top,tan(deg_to_rad(float(p.pitch)))*w/2)
	if style=="desert" and ornate:
		mark("rooftop_pergola")
		for x in [-1,1]:
			for z in [-1,1]: beam(rc+Vector3(x*rw*0.28,0.2,z*rd*0.3),rc+Vector3(x*rw*0.28,1.55,z*rd*0.3),0.14,"wood")
		for i in 6: beam(rc+Vector3(-rw*0.32+rw*0.64*i/5,1.55,-rd*0.36),rc+Vector3(-rw*0.32+rw*0.64*i/5,1.55,rd*0.36),0.13,"wood")
		for z in [-1,1]: beam(rc+Vector3(-rw*0.36,1.48,z*rd*0.3),rc+Vector3(rw*0.36,1.48,z*rd*0.3),0.15,"wood")
	return pack_asset(profile)

func house_identity(w: float,d: float) -> void:
	if recipe.type_id not in ["house","general_store","inn"]: super.house_identity(w,d);return
	var f := d/2+0.65;var left := -w*0.30;var right := w*0.30
	if recipe.type_id=="house":
		if style=="desert": barrel(Vector3(right,0.36,f),0.25)
		else: Parts.planter(self,Vector3(right,0.5,f),1.0)
	elif recipe.type_id=="general_store":
		mark("open_shopfront")
		table(Vector3(left,0.36,f),minf(2,w*0.32),0.75)
		for shelf in 2:
			box(Vector3(right,0.8+shelf*0.7,d/2+0.3),Vector3(1.4,0.10,0.65),"wood")
			for i in 3: crate(Vector3(right-0.45+i*0.43,0.86+shelf*0.70,d/2+0.3),0.32)
		for i in 3: crate(Vector3(left-0.45+i*0.45,1.22,f),0.32)
		panel(Vector3(left,2.32,f+0.2),1.4,0.6,"sign")
	else:
		mark("inn_entrance")
		panel(Vector3(left,2.37,f+0.6),1.55,0.7,"sign")
		if style=="jiangnan":
			for s in [-1,1]: post(Vector3(s*1.03,0.36,f+0.65),2.2)
			Roof5.hip(self,Vector3(0,2.75,f+0.45),2.5,1.1,0.5,0.22)
		elif style=="forest": barrel(Vector3(right,0.36,f));table(Vector3(left,0.36,f),1.3,0.6)
		else:
			for s in [-1,1]: block(Vector3(s*0.95,1.1,f+0.3),Vector3(0.24,1.5,0.28),"stone")
			for i in 8:
				var a := PI*i/8;var b := PI*(i+1)/8
				beam(Vector3(cos(a)*0.96,1.8+sin(a)*0.85,f+0.3),Vector3(cos(b)*0.96,1.8+sin(b)*0.85,f+0.3),0.2,"stone")
