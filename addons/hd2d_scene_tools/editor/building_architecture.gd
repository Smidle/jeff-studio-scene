@tool
extends "building_mesh.gd"
const Roof=preload("building_roofs.gd")
const Parts=preload("building_components.gd")
const Materials=preload("../runtime/building_materials_v2.gd")
var material_provider = Materials
var revision := 2
var style := "jiangnan"
var variant := 0
var ornate := true
var solids: Array=[]

func solid(c: Vector3, size: Vector3) -> void:
	solids.append({"transform":xf*Transform3D(Basis.IDENTITY,c),"size":size})

func facade(w: float, h: float, floor_index: int, columns: int, front: bool, kind: int) -> void:
	var band := "wood" if style!="desert" else "trim"
	for y in [0.07,h-0.12]: box(Vector3(0,y,0.06),Vector3(w+0.08,0.15,0.16),band)
	if front and floor_index==0: Parts.door(self,Vector3.ZERO,style,variant)
	var bay_count := maxi(2,mini(columns+1,floori(w/1.35)))
	var bay_width := w/bay_count
	for i in range(bay_count+1):
		var x := -w*0.5+i*bay_width
		if front and floor_index==0 and absf(x)<0.8: continue
		if style!="desert":
			box(Vector3(x,h*0.5,0.08),Vector3(0.14,h,0.16),"wood")
			if style=="jiangnan":
				box(Vector3(x,h-0.28,0.12),Vector3(0.30,0.13,0.24),"wood")
				box(Vector3(x,h-0.13,0.12),Vector3(0.48,0.12,0.30),"trim")
			else:
				for s in [-1,1]:
					if absf(x+s*bay_width*0.31)<w*0.5-0.03:
						beam(Vector3(x,h-0.66,0.09),Vector3(x+s*bay_width*0.31,h-0.15,0.09),0.10,"wood")
		elif i in [0,bay_count]:
			for y in range(5): box(Vector3(x,y*h/5+0.22,0.075),Vector3(0.27,0.19,0.20),"stone")
	for i in bay_count:
		var x := (i+0.5)*bay_width-w*0.5
		if front and floor_index==0 and absf(x)<1.25: continue
		var ww := minf(0.94,bay_width-(0.70 if style=="forest" else 0.28))
		if ww<0.40: continue
		Parts.window(self,Vector3(x,h*0.55,0.025),ww,1.05,style,variant+i)
		if ornate and style=="forest" and floor_index==0 and (i+variant)%2==0: Parts.planter(self,Vector3(x,h*0.55-0.76,0.23),ww+0.2)
	if style=="desert":
		for i in maxi(3,roundi(w/0.45)):
			box(Vector3(-w*0.5+0.22+i*0.45,h-0.34,0.095),Vector3(0.15,0.07,0.10),"accent")
	if front and floor_index==0 and kind==1: Parts.signboard(self,Vector3(0,2.40,0.19),minf(w*0.55,2.5),style)

func storey(c: Vector3, w: float, d: float, h: float, floor_index: int, columns: int, kind: int) -> void:
	box(c+Vector3.UP*h*0.5,Vector3(w,h,d),"wall")
	solid(c+Vector3.UP*h*0.5,Vector3(w,h,d))
	var original := xf
	for side in 4:
		var angle := side*PI*0.5
		var basis := Basis(Vector3.UP,angle)
		var span := w if side%2==0 else d
		var distance := d*0.5 if side%2==0 else w*0.5
		xf=original*Transform3D(basis,c+basis*Vector3(0,0,distance))
		facade(span,h,floor_index,columns,side==0,kind)
	xf=original

func foundation(w: float, d: float, height: float) -> void:
	box(Vector3(0,height*0.5,0),Vector3(w+0.24,height,d+0.24),"stone")
	box(Vector3(0,height-0.035,0),Vector3(w+0.37,0.09,d+0.37),"trim" if style=="desert" else "stone")
	solid(Vector3(0,height*0.5,0),Vector3(w+0.24,height,d+0.24))
	for i in 3:
		var center := Vector3(0,height*(i+1)/6,d*0.5+0.76-i*0.22)
		var size := Vector3(1.65,height*(i+1)/3,0.29)
		box(center,size,"stone");solid(center,size)

func porch(w: float, d: float, base: float, balcony: bool, kind: int, flat: bool) -> void:
	mark("supported_porch")
	var pw := minf(w-0.1,w*0.88 if style=="jiangnan" or kind==1 else 2.9)
	var depth := 1.1;var top := base+2.6
	for s in [-1,1]:
		var foot := Vector3(s*pw*0.5,base*0.5,d*0.5+depth)
		box(foot,Vector3(0.35,base,0.35),"stone");solid(foot,Vector3(0.35,base,0.35))
		var post := Vector3(foot.x,(base+top)*0.5,foot.z)
		box(post,Vector3(0.16,top-base,0.16),"wood");solid(post,Vector3(0.16,top-base,0.16))
		beam(Vector3(foot.x,top-0.60,foot.z),Vector3(foot.x-s*0.50,top-0.12,foot.z),0.11,"wood")
		beam(Vector3(foot.x,top-0.60,foot.z),Vector3(foot.x,top-0.12,foot.z-0.50),0.11,"wood")
		box(Vector3(foot.x,top-0.07,foot.z),Vector3(0.36,0.16,0.30),"trim")
	beam(Vector3(-pw*0.5,top,d*0.5+depth),Vector3(pw*0.5,top,d*0.5+depth),0.18,"wood")
	if balcony:
		var floor_y := base+2.8
		box(Vector3(0,floor_y,d*0.5+depth*0.48),Vector3(pw+0.35,0.18,depth+0.32),"wood")
		Parts.rail(self,Vector3(-pw*0.5,floor_y+0.10,d*0.5+depth),Vector3(pw*0.5,floor_y+0.10,d*0.5+depth),0.75,style)
		for s in [-1,1]: Parts.rail(self,Vector3(s*pw*0.5,floor_y+0.1,d*0.5),Vector3(s*pw*0.5,floor_y+0.1,d*0.5+depth),0.75,style)
	elif style=="forest" and not flat:
		Roof.gable(self,Vector3(0,top,d*0.5+0.51),pw+0.12,1.14,0.60,0.18,false)
	elif style=="jiangnan" and not flat:
		Roof.hip(self,Vector3(0,top,d*0.5+0.51),pw+0.1,1.18,0.47,0.22,false)
	else:
		# Woven awning is a shallow folded surface; rafters remain visible beneath it.
		var rows := maxi(3,roundi(pw/0.28))
		for i in range(rows+1): beam(Vector3(-pw/2+pw*i/rows,top+0.02,d/2),Vector3(-pw/2+pw*i/rows,top-0.1,d/2+depth+0.14),0.09,"wood")
		for i in rows:
			var x0 := -pw/2+pw*i/rows;var x1 := -pw/2+pw*(i+1)/rows
			face([Vector3(x0,top+0.09,d/2),Vector3(x0,top-0.06,d/2+depth+0.2),Vector3(x1,top-0.06,d/2+depth+0.2),Vector3(x1,top+0.09,d/2)],"cloth")
		box(Vector3(0,top-0.16,d/2+depth+0.2),Vector3(pw,0.19,0.05),"cloth")
	if ornate:
		for s in [-1,1]: Parts.lantern(self,Vector3(s*(pw*0.5-0.24),top-0.50,d*0.5+depth+0.1),style)

func chimney(w: float, d: float, y: float, rise: float) -> void:
	mark("capped_chimney")
	var c := Vector3(-w*0.28,y+rise*0.48,-d*0.25)
	box(c+Vector3.UP*0.65,Vector3(0.65,1.65,0.69),"stone")
	box(c+Vector3.UP*1.5,Vector3(0.84,0.17,0.86),"stone")
	box(c+Vector3.UP*1.60,Vector3(0.45,0.03,0.46),"shadow")
	for s in [-1,1]: box(c+Vector3(s*0.28,1.83,0),Vector3(0.12,0.47,0.55),"stone")
	box(c+Vector3.UP*2.08,Vector3(0.93,0.12,0.88),"roof")

func roof_dormer(w: float, d: float, y: float, rise: float) -> void:
	mark("roof_dormer")
	# Right slope; the chimney owns the opposite slope. Keep both footprints bounded.
	var before := xf
	var x := w*0.30;var bottom := y+rise*(1-x/(w*0.5+0.55))
	xf=xf*Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(x,bottom,d*(-0.22+(variant%3)*0.17)))
	box(Vector3(0,0.4,-0.35),Vector3(1.25,0.80,1.2),"wall")
	Parts.window(self,Vector3(0,0.43,0.27),0.72,0.55,"forest",variant)
	Roof.gable(self,Vector3(0,0.85,-0.30),1.30,1.35,0.50,0.13,false)
	xf=before

func build(profile: HD2DBuildingProfile) -> HD2DAsset:
	style=profile.style;var p := profile.parameters
	var rng := RandomNumberGenerator.new();rng.seed=profile.shape_seed+profile.kind*113
	variant=rng.randi_range(0,5);ornate=bool(p.get("ornament",true))
	var w := clampf(float(p.get("width",5.5)),3,10)*(1.12 if profile.kind==2 else 1.0)
	var d := clampf(float(p.get("depth",4.75)),3,10)*(1.08 if profile.kind==2 else 1.0)
	var floors := clampi(int(p.get("floors",1)),1,3)
	var columns := clampi(int(p.get("windows",2)),1,4)
	var base := 0.36;var h := 2.8;var top := base+floors*h
	var eave := clampf(float(p.get("eave",0.55)),0.1,1)
	var flat := int(p.get("roof",0))==2 or (int(p.get("roof",0))==0 and style=="desert")
	var has_balcony := floors>1 and bool(p.get("balcony",true))
	foundation(w,d,base)
	var roof_c := Vector3(0,top,0);var roof_w := w;var roof_d := d
	for f in floors:
		var c := Vector3(0,base+f*h,0);var sw := w;var sd := d
		if style=="desert" and f>0:
			sw=w*0.76;sd=d*0.72;c+=Vector3(w*0.10,0,-d*0.12)
			if f==1: Roof.terrace(self,Vector3(0,base+h-0.1,0),w,d,eave)
			roof_c=Vector3(c.x,top,c.z);roof_w=sw;roof_d=sd
		storey(c,sw,sd,h,f,columns,profile.kind)
	var rise := tan(deg_to_rad(clampf(float(p.get("pitch",32)),15,50)))*(roof_w if style=="forest" else roof_d)*0.5
	if flat: Roof.terrace(self,roof_c,roof_w,roof_d,eave)
	elif style=="jiangnan" and int(p.get("roof",0))==0: Roof.hip(self,roof_c,roof_w,roof_d,rise,eave)
	else: Roof.gable(self,roof_c,roof_w,roof_d,rise,eave)
	if bool(p.get("porch",true)) or profile.kind==1: porch(w,d,base,has_balcony and style!="desert",profile.kind,flat)
	if style=="forest" and not flat:
		chimney(w,d,top,rise)
		if ornate and rise>1.5: Parts.window(self,Vector3(0,top+rise*0.38,d*0.5+0.035),0.72,0.67,style,variant)
		if ornate and w>=4.5 and d>=4.2 and rise>=1.5: roof_dormer(w,d,top,rise)
	if style=="desert" and ornate:
		mark("rooftop_pergola")
		var py := top+1.36
		var pw := roof_w*0.55;var pd := roof_d*0.60
		for x in [-1,1]:
			for z in [-1,1]: beam(roof_c+Vector3(x*pw*0.5,0.24,z*pd*0.5),roof_c+Vector3(x*pw*0.5,1.36,z*pd*0.5),0.11,"wood")
		for z in [-1,1]: beam(roof_c+Vector3(-pw*0.6,1.36,z*pd*0.5),roof_c+Vector3(pw*0.6,1.36,z*pd*0.5),0.13,"wood")
		for i in 7: beam(Vector3(roof_c.x-pw*0.48+pw*i/6,py+0.10,roof_c.z-pd*0.6),Vector3(roof_c.x-pw*0.48+pw*i/6,py+0.10,roof_c.z+pd*0.6),0.095,"wood")
	if profile.kind==2 and style=="jiangnan" and not flat:
		# A raised central pavilion gives civic buildings a distinct silhouette.
		mark("central_pavilion")
		box(Vector3(0,top+rise+0.36,0),Vector3(w*0.35,0.64,d*0.38),"wall")
		Roof.hip(self,Vector3(0,top+rise+0.67,0),w*0.40,d*0.43,0.67,0.24,false)
	return pack_asset(profile)

func pack_asset(profile: HD2DBuildingProfile) -> HD2DAsset:
	var asset := HD2DAsset.new();var root := Node3D.new();root.name="Architecture"
	root.set_meta("generator_version",revision);root.set_meta("features",features);root.set_meta("triangle_count",triangles)
	asset.building_profile=profile.duplicate(true);asset.library_entry_id=StringName("generated-"+profile.identity())
	asset.asset_id=asset.library_entry_id;asset.family_id=StringName("jeff-building-"+style)
	asset.title=["江南","森林木屋","沙漠"][maxi(0,["jiangnan","forest","desert"].find(style))]+" · "+["民居","商铺","中心建筑"][profile.kind]
	asset.category="建筑";asset.wind=0;asset.static_collision=true
	for role in buckets:
		var mesh: ArrayMesh=buckets[role].commit();mesh.surface_set_material(0,material_provider.material(style,role,0,profile.appearance_seed))
		var node := MeshInstance3D.new();node.name=role;node.mesh=mesh;root.add_child(node);node.owner=root
		asset.material_slots[str(node.name)]=[role]
	var body := StaticBody3D.new();body.name="BuildingCollision";root.add_child(body);body.owner=root
	for part in solids:
		var collision := CollisionShape3D.new();var shape := BoxShape3D.new();shape.size=part.size
		collision.shape=shape;collision.transform=part.transform;body.add_child(collision);collision.owner=root
	var scene := PackedScene.new();scene.pack(root);root.free();asset.source=scene
	for look in range(1,4):
		var skin := HD2DAssetSkin.new();skin.skin_id=StringName(["","elegant","warm","weathered"][look]);skin.title=["","素雅","暖色","风化"][look];skin.family_id=asset.family_id
		for role in buckets: skin.materials[role]=material_provider.material(style,role,look,profile.appearance_seed)
		asset.skins.append(skin)
	return asset
