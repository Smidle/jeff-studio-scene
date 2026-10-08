@tool
extends "building_architecture_v3.gd"
const Catalog=preload("building_catalog.gd")
var recipe: HD2DBuildingProfile
var definition: Dictionary
var detail_variant := 0

func _init() -> void:
	revision=4

func facade(w: float,h: float,floor_index: int,columns: int,front: bool,kind: int) -> void:
	var before := variant;variant=detail_variant
	super.facade(w,h,floor_index,columns,front,kind)
	variant=before

func build(profile: HD2DBuildingProfile) -> HD2DAsset:
	recipe=profile;definition=Catalog.entry(profile.type_id)
	assert(not definition.is_empty(),"Unknown classified building type")
	style=profile.style
	var rng := RandomNumberGenerator.new();rng.seed=profile.detail_seed+profile.type_id.hash()
	detail_variant=rng.randi_range(0,5)
	if definition.archetype=="house": return super.build(profile)
	var p := profile.parameters;var w := clampf(float(p.get("width",6)),3,10);var d := clampf(float(p.get("depth",4)),0.5 if definition.archetype=="wall" else 2,10)
	var h := clampf(float(p.get("height",3.2)),0.3,10)
	var bays := clampi(int(p.get("bays",3)),1,6)
	variant=posmod(profile.shape_seed,6);ornate=bool(p.get("ornament",true))
	match str(definition.archetype):
		"stall": stall(w,d,h,bays)
		"barn": shelter(w,d,h,bays)
		"greenhouse": greenhouse(w,d,h,bays)
		"wall": wall_section(Vector3.ZERO,w,h)
		"gate": gate(w,d,h,profile.type_id=="checkpoint")
		"fortress": fortress(w,d,h)
		"dock": dock(w,d,h,bays)
		"portal": portal(w,d,h,profile.type_id=="mine")
		"ruin": ruin(w,d,h,bays)
		"tower":
			var floors := clampi(int(p.get("floors",3)),1,3)
			foundation(w,d,0.36)
			for f in floors: storey(Vector3(0,0.36+f*2.8,0),w,d,2.8,f,clampi(int(p.get("windows",2)),1,4),0)
			roof_at(Vector3(0,0.36+floors*2.8,0),w+0.2,d+0.2)
			if profile.type_id=="watchtower":
				for s in [-1,1]: Parts.rail(self,Vector3(-w/2,0.36+floors*2.8,s*d/2),Vector3(w/2,0.36+floors*2.8,s*d/2),0.6,style)
			else:
				cylinder(Vector3(0,0.36+floors*2.8+2.3,0),0.42,0.5,"accent",6)
				for a in 8: beam(Vector3.ZERO+Vector3(0,0.36+floors*2.8+2.7,0),Vector3(cos(a*PI/4)*0.7,0.36+floors*2.8+2.3,sin(a*PI/4)*0.7),0.05,"metal")
	return pack_asset(profile)

func block(c: Vector3,size: Vector3,role: String="stone") -> void:
	box(c,size,role);solid(c,size)

func roof_at(c: Vector3,w: float,d: float) -> void:
	var pitch := float(recipe.parameters.get("pitch",32))
	var rise := tan(deg_to_rad(clampf(pitch,15,50)))*minf(w,d)*0.5
	var eave := float(recipe.parameters.get("eave",0.4))
	var choice := int(recipe.parameters.get("roof",0))
	if choice==2: Roof.terrace(self,c,w,d,eave)
	elif choice==1: Roof.gable(self,c,w,d,rise,eave,false)
	elif style=="jiangnan": Roof.hip(self,c,w,d,rise,eave,false)
	elif style=="forest": Roof.gable(self,c,w,d,rise,eave,false)
	else: Roof.terrace(self,c,w,d,eave)

func post(c: Vector3,h: float) -> void:
	block(c+Vector3.UP*h/2,Vector3(0.16,h,0.16),"wood")
	box(c+Vector3.UP*0.1,Vector3(0.3,0.2,0.3),"stone")

func table(c: Vector3,w: float,d: float) -> void:
	box(c+Vector3.UP*0.8,Vector3(w,0.12,d),"wood")
	for x in [-1,1]:
		for z in [-1,1]: box(c+Vector3(x*(w/2-0.12),0.38,z*(d/2-0.10)),Vector3(0.1,0.76,0.1),"wood")

func crate(c: Vector3,size: float=0.55) -> void:
	box(c+Vector3.UP*size/2,Vector3.ONE*size,"wood")
	for y in [0.12,size-0.1]: box(c+Vector3(0,y,size/2+0.02),Vector3(size,0.07,0.05),"trim")
	beam(c+Vector3(-size/2,0.05,size/2+0.03),c+Vector3(size/2,size-0.05,size/2+0.03),0.055,"trim")

func barrel(c: Vector3,r: float=0.28) -> void:
	cylinder(c+Vector3.UP*0.38,r,0.76,"wood",10)
	for y in [0.12,0.62]: cylinder(c+Vector3.UP*y,r+0.018,0.07,"metal",10)
	cylinder(c+Vector3.UP*0.77,r*0.91,0.03,"trim",10)

func bottle(c: Vector3,role: String="glass") -> void:
	cylinder(c+Vector3.UP*0.15,0.1,0.30,role,6);cylinder(c+Vector3.UP*0.34,0.042,0.12,role,6)

func sword(c: Vector3) -> void:
	box(c+Vector3.UP*0.52,Vector3(0.09,0.82,0.035),"metal")
	box(c+Vector3.UP*0.18,Vector3(0.35,0.07,0.07),"trim")
	box(c+Vector3.UP*0.08,Vector3(0.07,0.2,0.06),"wood")

func shield(c: Vector3) -> void:
	face([c+Vector3(-0.24,0.55,0),c+Vector3(0.24,0.55,0),c+Vector3(0.24,0.18,0),c+Vector3(0,-0.05,0),c+Vector3(-0.24,0.18,0)],"accent")
	box(c+Vector3(0,0.29,0.025),Vector3(0.055,0.47,0.05),"metal")
	box(c+Vector3(0,0.40,0.025),Vector3(0.43,0.06,0.05),"metal")

func canopy(c: Vector3,w: float,d: float,h: float) -> void:
	for x in [-1,1]:
		for z in [-1,1]: post(c+Vector3(x*w/2,0,z*d/2),h)
	for i in 8:
		var x0 := -w/2+w*i/8;var x1 := -w/2+w*(i+1)/8
		face([c+Vector3(x0,h,-d/2),c+Vector3(x0,h-0.2,d/2),c+Vector3(x1,h-0.2,d/2),c+Vector3(x1,h,-d/2)],"cloth" if i%2==0 else "accent")

func stall(w: float,d: float,h: float,bays: int) -> void:
	canopy(Vector3.ZERO,w,d,h)
	table(Vector3(0,0,d*0.23),w*0.84,0.72)
	block(Vector3(0,0.4,d*0.23),Vector3(w*0.84,0.8,0.72),"wood")
	for i in bays: crate(Vector3(-w*0.33+i*w*0.66/maxi(1,bays-1),0.86,d*0.23),0.34)

func shelter(w: float,d: float,h: float,bays: int) -> void:
	var raised: bool = definition.id=="granary"
	var y := 0.7 if raised else 0.1
	block(Vector3(0,y/2,0),Vector3(w,y,d),"stone" if raised else "wood")
	for x in [-1,1]:
		for z in [-1,1]: post(Vector3(x*w/2,y,z*d/2),h)
	block(Vector3(0,y+h*0.4,-d/2),Vector3(w,h*0.8,0.14),"wood")
	if definition.id!="boathouse":
		for i in range(1,bays): block(Vector3(-w/2+w*i/bays,y+0.55,-d*0.15),Vector3(0.1,1.1,d*0.65),"wood")
	roof_at(Vector3(0,y+h,0),w,d)
	match str(definition.id):
		"granary":
			for i in bays: crate(Vector3(-w*0.3+i*w*0.6/maxi(1,bays-1),y,-d*0.25),0.8)
			for i in 4: block(Vector3(0,0.10+i*0.15,d/2+0.8-i*0.2),Vector3(1.3,0.20+i*0.30,0.22),"stone")
		"stable","animal_shed":
			for i in bays:
				var x := -w/2+(i+0.5)*w/bays
				box(Vector3(x,y+0.2,-d*0.3),Vector3(w/bays*0.65,0.4,0.55),"wood")
				box(Vector3(x,y+0.42,-d*0.3),Vector3(w/bays*0.56,0.05,0.43),"cloth")
			if definition.id=="animal_shed": Parts.rail(self,Vector3(-w/2,y,d/2),Vector3(-0.65,y,d/2),0.9,style)
		"boathouse":
			for s in [-1,1]: beam(Vector3(s*0.6,y+0.22,-d*0.3),Vector3(s*0.35,y+0.25,d*0.3),0.16,"wood")
			for i in 5: box(Vector3(0,y+0.23,-d*0.3+i*d*0.15),Vector3(1.1,0.12,0.16),"wood")
		"carriage_station":
			table(Vector3(-w*0.28,y,-d*0.1),1.4,0.6)
			for s in [-1,1]: wheel(Vector3(w*0.26+s*0.36,y+0.55,-d*0.10),0.5)
			box(Vector3(w*0.26,y+0.65,-d*0.10),Vector3(0.75,0.25,1.3),"wood")

func greenhouse(w: float,d: float,h: float,bays: int) -> void:
	block(Vector3(0,0.12,0),Vector3(w,0.24,d),"stone")
	for x in [-1,1]:
		block(Vector3(x*w/2,h/2,0),Vector3(0.06,h,d),"glass")
		for i in range(bays+1): post(Vector3(x*w/2,0,-d/2+d*i/bays),h)
	block(Vector3(0,h/2,-d/2),Vector3(w,h,0.06),"glass")
	for x in [-1,1]: block(Vector3(x*(w/4+0.4),h/2,d/2),Vector3(w/2-0.8,h,0.06),"glass")
	for s in [-1,1]:
		face([Vector3(0,h+1,-d/2),Vector3(s*w/2,h,-d/2),Vector3(s*w/2,h,d/2),Vector3(0,h+1,d/2)],"glass")
		for i in range(bays+1): beam(Vector3(0,h+1,-d/2+i*d/bays),Vector3(s*w/2,h,-d/2+i*d/bays),0.1,"wood")
		for i in bays: Parts.planter(self,Vector3(s*w*0.28,0.55,-d*0.35+i*d*0.7/maxi(1,bays-1)),0.8)

func wall_section(c: Vector3,w: float,h: float) -> void:
	block(c+Vector3.UP*h/2,Vector3(w,h,(float(recipe.parameters.get("depth",0.8)) if definition.archetype=="wall" else 0.55)),"wall" if style=="desert" else "stone")
	block(c+Vector3.UP*(h+0.06),Vector3(w+0.12,0.16,(float(recipe.parameters.get("depth",0.8)) if definition.archetype=="wall" else 0.55)+0.16),"trim")
	var n := maxi(2,int(recipe.parameters.get("bays",3))*2)
	for i in range(n+1):
		var x := -w/2+w*i/n
		block(c+Vector3(x,h+0.35,0),Vector3(0.48,0.6,0.7),"stone")
		if i%3==0: block(c+Vector3(x,(h+0.2)/2,0),Vector3(0.7,h+0.2,0.8),"stone")

func gate(w: float,d: float,h: float,checkpoint: bool=false) -> void:
	var gap := minf(2.6,w*0.42);var side := (w-gap)/2
	for x in [-1,1]:
		block(Vector3(x*(gap/2+side/2),h/2,0),Vector3(side,h,d),"stone")
		if checkpoint: roof_at(Vector3(x*(gap/2+side/2),h,0),side,d)
	block(Vector3(0,h-0.2,0),Vector3(gap,0.4,d),"stone")
	if not checkpoint: roof_at(Vector3(0,h,0),w,d)
	for s in [-1,1]: Parts.lantern(self,Vector3(s*(gap/2+0.3),h*0.6,d/2+0.25),style)

func fortress(w: float,d: float,h: float) -> void:
	var before := xf
	for s in [-1,1]:
		xf=Transform3D(Basis(Vector3.UP,PI/2),Vector3(s*w/2,0,0));wall_section(Vector3.ZERO,d,h)
	xf=before;wall_section(Vector3(0,0,-d/2),w,h)
	for s in [-1,1]:
		wall_section(Vector3(s*(w/4+0.65),0,d/2),w/2-1.3,h)
		for z in [-1,1]:
			block(Vector3(s*w/2,(h+1)/2,z*d/2),Vector3(1.5,h+1,1.5),"stone")
			roof_at(Vector3(s*w/2,h+1,z*d/2),1.5,1.5)
	block(Vector3(0,h-0.15,d/2),Vector3(2.6,0.3,0.7),"stone")

func dock(w: float,d: float,h: float,bays: int) -> void:
	block(Vector3(0,h,0),Vector3(w,0.16,d),"wood")
	for x in [-1,1]:
		for i in range(bays+1):
			var c := Vector3(x*w*0.46,0,-d/2+i*d/bays)
			post(c,h+0.5)
			if i%2==0: cylinder(c+Vector3.UP*(h+0.55),0.14,0.13,"metal",8)
	for i in 4: block(Vector3(0,h*(i+1)/5,d/2+1.0-i*0.25),Vector3(w*0.5,h*(i+1)*0.4,0.28),"wood")

func portal(w: float,d: float,h: float,mine: bool) -> void:
	var gap := minf(2.4,w*0.6)
	for s in [-1,1]: block(Vector3(s*(gap/2+0.22),h/2,0),Vector3(0.44,h,d),"wood" if mine else "stone")
	block(Vector3(0,h,0),Vector3(gap+0.9,0.40,d),"wood" if mine else "stone")
	block(Vector3(0,h*0.5,-d/2),Vector3(gap,h,0.08),"shadow")
	if mine:
		for s in [-1,1]: box(Vector3(s*0.46,0.055,d*0.25),Vector3(0.08,0.11,d*1.2),"metal")
		for i in 7: box(Vector3(0,0.025,-d*0.3+i*d/6),Vector3(1.3,0.05,0.12),"wood")
	else:
		for s in [-1,1]: cylinder(Vector3(s*(gap/2+0.48),h+0.18,0),0.27,0.55,"accent",6)
		box(Vector3(0,h+0.42,0),Vector3(gap*0.6,0.55,d*0.5),"stone")

func ruin(w: float,d: float,h: float,bays: int) -> void:
	block(Vector3(0,0.08,0),Vector3(w,0.16,d),"stone")
	for i in range(bays+1):
		var rise := h*(0.35+float(posmod(recipe.shape_seed+i*7,5))*0.13)
		block(Vector3(-w/2+w*i/bays,rise/2,-d/2),Vector3(w/bays*0.70,rise,0.4),"stone")
	for s in [-1,1]:
		block(Vector3(s*w/2,h*0.28,-d*0.2),Vector3(0.4,h*0.56,d*0.5),"wall")
		if definition.id=="ruins": cylinder(Vector3(s*w*0.34,h*0.4,d*0.22),0.24,h*0.8,"stone",8)
		else: beam(Vector3(s*w/2,h*0.56,-d/2),Vector3(0,h*0.80,-d/2),0.17,"wood")

func wheel(c: Vector3,r: float) -> void:
	for i in 12:
		var a := TAU*i/12;var z := TAU*(i+1)/12
		beam(c+Vector3(cos(a)*r,sin(a)*r,0),c+Vector3(cos(z)*r,sin(z)*r,0),0.11,"wood")
		if i%2==0: beam(c,c+Vector3(cos(a)*r,sin(a)*r,0),0.07,"trim")

func house_identity(w: float,d: float) -> void:
	var f := d/2+0.4;var left := -w*0.34;var right := w*0.34
	# Mandatory type structures and fixed envelopes; detail seed changes only decoration.
	match str(definition.id):
		"house": Parts.planter(self,Vector3(right,0.5,f),0.8)
		"farmhouse":
			canopy(Vector3(left,0,f+0.4),1.7,1.0,2.1)
			for i in 3: beam(Vector3(left-0.45+i*0.30,0.4,f),Vector3(left-0.45+i*0.30,1.8,f),0.06,"wood")
			crate(Vector3(right,0.36,f),0.65)
		"villa","manor":
			for s in [-1,1]:
				block(Vector3(s*(w/2+0.75),1.5,0),Vector3(1.5,3,d*0.65),"wall")
				roof_at(Vector3(s*(w/2+0.75),3,0),1.5,d*0.65)
				Parts.rail(self,Vector3(s*w/2,0.36,f+1.8),Vector3(s*0.8,0.36,f+1.8),0.85,style)
			if definition.id=="manor":
				for s in [-1,1]: block(Vector3(s*0.9,1.2,f+1.8),Vector3(0.35,2.4,0.35),"stone")
				roof_at(Vector3(0,2.4,f+1.8),2.6,0.9)
		"general_store":
			table(Vector3(left,0.36,f),1.7,0.7)
			for i in 3: crate(Vector3(left-0.55+i*0.5,1.22,f),0.36)
			barrel(Vector3(right,0.36,f))
		"weaponsmith","armorer":
			table(Vector3(left,0.36,f),1.8,0.6)
			for i in 3:
				if definition.id=="weaponsmith": sword(Vector3(left-0.6+i*0.55,1.2,f))
				else: shield(Vector3(left-0.55+i*0.55,1.2,f+0.30))
		"apothecary":
			box(Vector3(left,1.25,f),Vector3(1.5,1.7,0.45),"wood")
			for row in 4:
				for col in 3:
					var c := Vector3(left-0.5+col*0.5,0.60+row*0.38,f+0.24)
					box(c,Vector3(0.42,0.30,0.05),"trim");box(c+Vector3(0,0,0.04),Vector3(0.11,0.035,0.05),"metal")
			bottle(Vector3(right,0.36,f))
		"inn":
			Parts.signboard(self,Vector3(left,2.55,f+0.2),1.5,style)
			for s in [-1,1]: Parts.lantern(self,Vector3(s*w*0.38,2.25,f+0.1),style)
			box(Vector3(left,1.35,f+0.30),Vector3(1.4,0.22,0.8),"wood")
		"tavern":
			for i in 3: barrel(Vector3(left+(i%2)*0.6,0.36+(i/2)*0.8,f))
			table(Vector3(right,0.36,f),1.3,0.75)
		"teahouse":
			for s in [-1,1]:
				table(Vector3(s*w*0.32,0.36,f),1.2,0.65)
				bottle(Vector3(s*w*0.32,1.22,f),"accent")
				box(Vector3(s*w*0.32,0.65,f+0.65),Vector3(1.1,0.12,0.3),"wood")
		"posthouse":
			canopy(Vector3(w/2+0.9,0,0),1.8,d*0.8,2.5)
			Parts.rail(self,Vector3(w/2,0.1,d*0.35),Vector3(w/2+1.8,0.1,d*0.35),0.9,style)
		"forge":
			# Open furnace with masonry sides, lintel and a black rear; no solid box across mouth.
			for s in [-1,1]: block(Vector3(left+s*0.47,1.0,f),Vector3(0.26,1.3,0.85),"stone")
			block(Vector3(left,1.65,f),Vector3(1.2,0.22,0.85),"stone")
			box(Vector3(left,0.9,f-0.39),Vector3(0.65,0.7,0.05),"shadow")
			box(Vector3(left,0.60,f),Vector3(0.62,0.12,0.4),"accent")
			block(Vector3(left,2.45,f-0.2),Vector3(0.55,1.6,0.55),"stone")
			box(Vector3(right,0.85,f),Vector3(0.8,0.25,0.4),"metal");box(Vector3(right,0.55,f),Vector3(0.30,0.6,0.30),"wood")
		"carpenter":
			table(Vector3(left,0.36,f),1.8,0.8)
			for i in 4: box(Vector3(right,0.45+i*0.14,f),Vector3(1.2,0.11,0.5),"wood")
			sword(Vector3(left,1.2,f))
		"tailor":
			for i in 3: cylinder(Vector3(left-0.45+i*0.40,0.9,f),0.17,1.0,"cloth" if i%2 else "accent",8)
			table(Vector3(right,0.36,f),1.3,0.6);box(Vector3(right,1.24,f),Vector3(0.8,0.04,0.5),"cloth")
		"alchemy":
			table(Vector3(left,0.36,f),1.5,0.75)
			for i in 3: bottle(Vector3(left-0.4+i*0.4,1.22,f))
			cylinder(Vector3(right,1.0,f),0.42,0.9,"metal",10)
			beam(Vector3(right,1.5,f),Vector3(right-0.5,1.5,f),0.08,"metal");bottle(Vector3(right-0.5,0.9,f))
		"mill": wheel(Vector3(w/2+0.22,1.5,0),1.3)
		"magistrate":
			for s in [-1,1]: block(Vector3(s*1.0,1.65,f+0.75),Vector3(0.28,3.3,0.28),"wood")
			roof_at(Vector3(0,3.3,f+0.75),2.6,1.0)
		"town_hall":
			box(Vector3(0,float(recipe.parameters.floors)*2.8+1.0,d*0.30),Vector3(1.3,1.4,1.0),"wall")
			cylinder(Vector3(0,float(recipe.parameters.floors)*2.8+1.3,d*0.30),0.22,0.35,"metal",8)
			roof_at(Vector3(0,float(recipe.parameters.floors)*2.8+1.7,d*0.30),1.6,1.3)
		"guild":
			Parts.signboard(self,Vector3(left,2.25,f),1.5,style);shield(Vector3(left,2.0,f+0.16))
			box(Vector3(right,1.55,f),Vector3(1.2,1.4,0.1),"wood")
			for i in 4: box(Vector3(right-0.28+(i%2)*0.55,1.25+(i/2)*0.55,f+0.08),Vector3(0.38,0.42,0.04),"cloth")
		"escort_hall":
			for s in [-1,1]:
				beam(Vector3(s*w*0.34,0.36,f),Vector3(s*w*0.34,2.9,f),0.10,"wood")
				box(Vector3(s*w*0.34+0.35,2.5,f),Vector3(0.7,0.6,0.035),"accent")
			wheel(Vector3(left,0.9,f+0.25),0.5)
		"clan_hall":
			for s in [-1,1]:
				cylinder(Vector3(s*w*0.30,0.75,f+0.6),0.28,0.8,"stone",8)
				cylinder(Vector3(s*w*0.30,1.25,f+0.6),0.4,0.24,"metal",8)
		"temple":
			for s in [-1,1]: canopy(Vector3(s*(w/2+0.8),0,-0.2),1.6,d*0.7,2.5)
			cylinder(Vector3(left,1.0,f),0.35,0.6,"metal",8)
		"ancestral_hall":
			block(Vector3(left,0.65,f),Vector3(1.0,0.6,0.5),"stone")
			for i in 3: box(Vector3(left-0.3+i*0.3,1.15,f),Vector3(0.15,0.4,0.08),"wood")
			Parts.signboard(self,Vector3(0,2.65,f),1.6,style)
		"cathedral":
			var tower := Vector3(-w/2-0.75,0,-d*0.20)
			block(tower+Vector3.UP*2.8,Vector3(1.6,5.6,1.8),"wall")
			roof_at(tower+Vector3.UP*5.6,1.7,1.9)
			if style=="desert":
				for i in 6: cylinder(Vector3(0,3.3+i*0.18,0),1.15*(1-float(i)/8),0.22,"roof",12)
		"academy":
			for s in [-1,1]:
				table(Vector3(s*w*0.32,0.36,f),1.5,0.7)
				box(Vector3(s*w*0.32,1.24,f),Vector3(0.65,0.06,0.4),"cloth")
			Parts.signboard(self,Vector3(0,2.65,f),2.0,style)
		"library":
			for s in [-1,1]:
				box(Vector3(s*w*0.34,1.45,f),Vector3(1.3,2.0,0.45),"wood")
				for row in 3:
					for i in 5: box(Vector3(s*w*0.34-0.48+i*0.24,0.82+row*0.53,f+0.26),Vector3(0.15,0.35,0.20),"cloth" if i%2 else "accent")
		"barracks":
			canopy(Vector3(left,0.36,f+0.4),1.8,1.0,2.0)
			for i in 3: sword(Vector3(left-0.5+i*0.5,0.6,f+0.5))
			shield(Vector3(right,1.1,f))

func pack_asset(_profile: HD2DBuildingProfile) -> HD2DAsset:
	if definition.archetype=="house":
		var w := clampf(float(recipe.parameters.width),3,10)*(1.12 if recipe.kind==2 else 1.0)
		var d := clampf(float(recipe.parameters.depth),3,10)*(1.08 if recipe.kind==2 else 1.0)
		house_identity(w,d)
		# Small details remain inside the fixed facade envelope and carry no collisions.
		if detail_variant%2==0: Parts.signboard(self,Vector3(w*0.34,2.3,d/2+0.22),0.7,style)
	if definition.archetype!="house":
		# A local emblem adds seeded relief without changing the structural envelope.
		var w := float(recipe.parameters.width);var d := float(recipe.parameters.depth)
		var y := minf(float(recipe.parameters.get("height",3))*0.6,1.8)
		for i in range(2+detail_variant%3):
			box(Vector3(-w*0.5+0.02+i*0.02,y+(i%2)*0.15,-d*0.5+0.085),Vector3(0.08,0.11+(detail_variant%2)*0.06,0.04),"trim")
	mark("type_"+recipe.type_id)
	var result := super.pack_asset(recipe)
	result.title=Catalog.title(recipe.type_id,recipe.style)
	if definition.id=="greenhouse":
		for part in result.mesh_parts():
			if part.mesh.surface_get_material(0).resource_name=="glass": part.mesh.surface_set_material(0,glazing(0))
		for skin in result.skins: skin.materials["glass"]=glazing(["","elegant","warm","weathered"].find(str(skin.skin_id)))
	return result

func glazing(look: int) -> StandardMaterial3D:
	# Original translucent pixel panes; window-light colors are inappropriate for greenhouse roofs.
	var pixels := Image.create(32,32,false,Image.FORMAT_RGBA8)
	var tint := Color("93bdc3") if look!=2 else Color("c9c59a")
	for y in 32:
		for x in 32:
			var glint := posmod(x+y+recipe.appearance_seed,16)<2
			var color := tint.lightened(0.2) if glint else tint
			color.a=0.48 if glint else 0.26;pixels.set_pixel(x,y,color)
	pixels.generate_mipmaps()
	var material := StandardMaterial3D.new();material.resource_name="glass"
	material.albedo_texture=ImageTexture.create_from_image(pixels)
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.roughness=0.65
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return material
