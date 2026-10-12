@tool
extends "building_architecture_v5.gd"
## Six original architectural dialects. Shared functional parts retain the 46-type contract.

func _init() -> void:
	revision=6;material_provider=preload("../runtime/building_materials_v6.gd")

func roof_at(c: Vector3,w: float,d: float) -> void:
	var p := recipe.parameters
	var e := float(p.get("eave",0.6));var pitch := float(p.get("pitch",35))
	var rise := tan(deg_to_rad(pitch))*w*0.5
	if int(p.get("roof",0))==2:
		Roof5.terrace(self,c,w,d,e);return
	if int(p.get("roof",0))==1:
		Roof5.gable(self,c,w,d,rise,e);return
	match style:
		"machiya":
			mark("machiya_cross_ridge")
			var before := xf;xf=xf*Transform3D(Basis(Vector3.UP,PI/2),c)
			Roof5.gable(self,Vector3.ZERO,d,w,tan(deg_to_rad(pitch))*d/2,e)
			xf=before
			for s in [-1,1]: beam(c+Vector3(s*w/2,-0.18,-d/2-e),c+Vector3(s*w/2,-0.18,d/2+e),0.18,"wood")
		"nordic":
			mark("snow_capped_gable");Roof5.gable(self,c,w,d,rise,e)
			# Broad snow planes follow the roof pitch; leave visible tile at the eaves.
			for s in [-1,1]:
				var x := (w/2+e)*0.93;var z := d/2+e-0.05
				var points := [c+Vector3(0,rise+0.05,-z),c+Vector3(s*x,rise*0.07+0.05,-z),c+Vector3(s*x,rise*0.07+0.05,z),c+Vector3(0,rise+0.05,z)]
				if s>0: points.reverse()
				face(points,"snow")
			if w>3: chimney(w,d,c.y,rise)
		"harbor":
			mark("harbor_hip_and_vent");Roof5.hip(self,c,w,d,minf(rise,2.3),e)
			var vent := c+Vector3(0,minf(rise,2.3)+0.15,0)
			box(vent+Vector3.UP*0.22,Vector3(1.0,0.44,0.65),"wood")
			Roof5.gable(self,vent+Vector3.UP*0.44,1.2,0.9,0.38,0.10)
		"palace":
			mark("palace_double_eaves")
			Roof5.hip(self,c,w,d,tan(deg_to_rad(pitch))*d*0.38,e)
			var upper := c+Vector3.UP*(tan(deg_to_rad(pitch))*d*0.38+0.28)
			box(upper,Vector3(w*0.5,0.45,d*0.48),"accent")
			Roof5.hip(self,upper+Vector3.UP*0.24,w*0.58,d*0.54,0.7,e*0.4)
			for s in [-1,1]:
				for i in 3: box(c+Vector3(s*w*0.42,-0.18-i*0.13,d*0.35),Vector3(0.38+i*0.18,0.12,0.5-i*0.08),"trim")
		"gothic":
			mark("gothic_pinnacles");Roof5.gable(self,c,w,d,rise,e)
			for s in [-1,1]:
				var point := c+Vector3(0,rise,s*(d/2+e))
				cylinder(point+Vector3.UP*0.32,0.10,0.64,"metal",6)
				beam(point+Vector3(-0.17,0.42,0),point+Vector3(0.17,0.42,0),0.055,"metal")
		"steamworks":
			mark("industrial_sawtooth")
			# Three sloped rooflights form a sawtooth silhouette, with closed gable ends.
			var span := (w+2*e)/3;var h := maxf(0.7,tan(deg_to_rad(pitch))*span)
			for i in 3:
				var x := -w/2-e+i*span
				roof_face([c+Vector3(x,h,d/2+e),c+Vector3(x+span,0,d/2+e),c+Vector3(x+span,0,-d/2-e),c+Vector3(x,h,-d/2-e)],Vector3.BACK,c)
				box(c+Vector3(x,h/2,0),Vector3(0.05,h,d+2*e),"glass")
				for s in [-1,1]:
					var points := [c+Vector3(x,0,s*(d/2+e)),c+Vector3(x+span,0,s*(d/2+e)),c+Vector3(x,h,s*(d/2+e))]
					if s<0: points.reverse()
					face(points,"wall")
					beam(points[2],points[1],0.13,"metal")

func window(c: Vector3,w: float,h: float) -> void:
	super.window(c,w,h)
	match style:
		"machiya":
			mark("machiya_lattice")
			for i in 4: box(c+Vector3((i-1.5)*w/4,0,0.12),Vector3(0.035,h,0.045),"wood")
		"nordic","harbor":
			mark("louvered_shutters")
			for s in [-1,1]:
				panel(c+Vector3(s*(w/2+0.14),0,0.075),0.23,h,"shutter")
				if style=="harbor":
					for i in 4: box(c+Vector3(s*(w/2+0.14),-h*0.34+i*h*0.22,0.11),Vector3(0.23,0.055,0.07),"trim")
		"palace":
			mark("palace_window_canopy")
			box(c+Vector3(0,h/2+0.17,0.09),Vector3(w+0.32,0.16,0.24),"trim")
			for s in [-1,1]: box(c+Vector3(s*(w/2+0.1),0,0.10),Vector3(0.12,h+0.2,0.1),"accent")
		"gothic":
			mark("pointed_window_arch")
			for s in [-1,1]: beam(c+Vector3(s*(w/2+0.09),h/2-0.18,0.13),c+Vector3(0,h/2+0.24,0.13),0.11,"stone")
			box(c+Vector3(0,0,0.12),Vector3(0.055,h,0.06),"stone")
		"steamworks":
			mark("industrial_window_frame")
			panel_frame(c+Vector3(0,0,0.10),w+0.10,h+0.08,0.08,"metal")
			for s in [-1,1]: box(c+Vector3(s*w*0.22,0,0.12),Vector3(0.045,h,0.06),"metal")

func facade(w: float,h: float,floor_index: int,columns: int,front: bool,kind: int) -> void:
	super.facade(w,h,floor_index,columns,front,kind)
	match style:
		"machiya":
			if floor_index>0: box(Vector3(0,0.06,0.30),Vector3(w+0.14,0.12,0.65),"roof")
		"palace":
			for s in [-1,1]:
				box(Vector3(s*(w/2-0.18),h/2,0.16),Vector3(0.23,h,0.23),"wood")
				for i in 3: box(Vector3(s*(w/2-0.18),h-0.36+i*0.12,0.18),Vector3(0.28+i*0.15,0.10,0.28+i*0.07),"trim")
		"gothic":
			for s in [-1,1]:
				var c := Vector3(s*(w/2-0.12),h/2,0.20)
				box(c,Vector3(0.23,h,0.32),"stone")
				# Fixed structural projection has matching collision, independent of detail seed.
				solid(c,Vector3(0.23,h,0.32))
		"steamworks":
			for s in [-1,1]:
				beam(Vector3(s*(w/2-0.22),0.1,0.17),Vector3(s*(w/2-0.22),h-0.1,0.17),0.14,"metal")
			box(Vector3(0,h-0.35,0.16),Vector3(w,0.10,0.16),"trim")

func doorway() -> void:
	super.doorway()
	if style=="gothic":
		for s in [-1,1]: beam(Vector3(s*0.78,1.78,0.22),Vector3(0,2.52,0.22),0.16,"stone")
	elif style=="machiya":
		mark("split_noren")
		for s in [-1,1]: panel(Vector3(s*0.34,1.98,0.26),0.64,0.55,"cloth")
	elif style=="steamworks": panel_frame(Vector3(0,1.10,0.23),1.5,2.2,0.12,"metal")

func porch(w: float,d: float,base: float,balcony: bool,kind: int,flat: bool) -> void:
	if style not in ["machiya","palace","harbor"]:
		super.porch(w,d,base,balcony,kind,flat);return
	mark("style_veranda")
	var pw := w*0.87;var top := base+2.55;var front := d/2+1.12
	for s in [-1,1]: post(Vector3(s*pw/2,base,front),2.55)
	beam(Vector3(-pw/2,top,front),Vector3(pw/2,top,front),0.20,"wood")
	if balcony:
		box(Vector3(0,base+2.78,d/2+0.58),Vector3(pw+0.25,0.16,1.3),"wood")
		Parts.rail(self,Vector3(-pw/2,base+2.9,front),Vector3(pw/2,base+2.9,front),0.72,style)
	elif style=="harbor":
		polygon([Vector3(-pw/2,top,d/2),Vector3(-pw/2,top-0.32,front+0.12),Vector3(pw/2,top-0.32,front+0.12),Vector3(pw/2,top,d/2)],[Vector2.ZERO,Vector2(0,1),Vector2(pw/2,1),Vector2(pw/2,0)],"cloth")
	else: Roof5.hip(self,Vector3(0,top,d/2+0.48),pw,1.25,0.38,0.22)

func pack_asset(profile: HD2DBuildingProfile) -> HD2DAsset:
	mark("style_"+style)
	if definition.archetype=="house" and style=="steamworks":
		mark("boiler_stack")
		var w := float(recipe.parameters.width)*(1.12 if recipe.kind==2 else 1.0)
		var d := float(recipe.parameters.depth)*(1.08 if recipe.kind==2 else 1.0)
		var top := 0.36+int(recipe.parameters.floors)*2.8
		cylinder(Vector3(w*0.31,top+0.85,-d*0.25),0.32,2.2,"stone",10)
		for y in [top+0.2,top+1.65]: cylinder(Vector3(w*0.31,y,-d*0.25),0.39,0.18,"metal",10)
		beam(Vector3(-w*0.34,1.1,-d/2-0.15),Vector3(-w*0.34,top+0.4,-d/2-0.15),0.15,"trim")
	return super.pack_asset(profile)
