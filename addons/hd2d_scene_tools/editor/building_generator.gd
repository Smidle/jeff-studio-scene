@tool
extends RefCounted
## Original mesh construction; +Z is the entrance, Y=0 is the foundation sole.
const Profile=preload("../runtime/building_profile.gd")
const Materials=preload("../runtime/building_materials.gd")
var buckets := {}
func face(points: Array, role: String) -> void:
	if not buckets.has(role): buckets[role]=SurfaceTool.new(); buckets[role].begin(Mesh.PRIMITIVE_TRIANGLES)
	var st: SurfaceTool=buckets[role]
	var normal: Vector3=(points[1]-points[0]).cross(points[2]-points[0]).normalized()
	var axis: Vector3=(points[1]-points[0]).normalized()
	if role=="wood" and (points[2]-points[1]).length()>(points[1]-points[0]).length(): axis=(points[2]-points[1]).normalized()
	var second := normal.cross(axis).normalized()
	for i in range(1,points.size()-1):
		for index in [0,i+1,i]:
			var p: Vector3=points[index]
			st.set_normal(normal); st.set_uv(Vector2(p.dot(axis),p.dot(second))/1.6); st.add_vertex(p)
func box(center: Vector3, size: Vector3, role: String) -> void:
	for side in [-1,1]: _box_sides(center,size*0.5,side,role)
func _box_sides(c: Vector3,h: Vector3,s: int,role: String) -> void:
	var a: Array=[Vector3(-h.x,-h.y,s*h.z),Vector3(h.x,-h.y,s*h.z),Vector3(h.x,h.y,s*h.z),Vector3(-h.x,h.y,s*h.z)]
	if s<0: a.reverse()
	for i in a.size(): a[i]+=c
	face(a,role)
	a=[Vector3(s*h.x,-h.y,h.z),Vector3(s*h.x,-h.y,-h.z),Vector3(s*h.x,h.y,-h.z),Vector3(s*h.x,h.y,h.z)]
	if s<0: a.reverse()
	for i in a.size(): a[i]+=c
	face(a,role)
	a=[Vector3(-h.x,s*h.y,h.z),Vector3(h.x,s*h.y,h.z),Vector3(h.x,s*h.y,-h.z),Vector3(-h.x,s*h.y,-h.z)]
	if s<0: a.reverse()
	for i in a.size(): a[i]+=c
	face(a,role)
func roof(w: float,d: float,y: float,rise: float,eave: float,flat: bool,style: String) -> void:
	if flat:
		box(Vector3(0,y+0.12,0),Vector3(w+eave*2,0.24,d+eave*2),"roof")
		for x in [-1,1]: box(Vector3(x*(w+eave)*0.5,y+0.4,0),Vector3(0.18,0.6,d+eave),"wall")
		return
	var x := w*0.5+eave; var z := d*0.5+eave
	# Layered eaves give the Jiangnan roof an upward tip without stretching UVs.
	for side in [-1,1]:
		var pts: Array=[Vector3(0,y+rise,-z),Vector3(side*x,y+0.12,-z),Vector3(side*x,y+0.12,z),Vector3(0,y+rise,z)]
		if side>0: pts.reverse()
		face(pts,"roof")
		box(Vector3(side*x,y+0.1,0),Vector3(0.14,0.15,d+eave*2),"wood")
		if style=="jiangnan": box(Vector3(side*(x-0.08),y+0.22,0),Vector3(0.14,0.14,d+eave*2+0.25),"roof")
	for side in [-1,1]:
		var pts: Array=[Vector3(-w*0.5,y,side*d*0.5),Vector3(w*0.5,y,side*d*0.5),Vector3(0,y+rise,side*d*0.5)]
		if side<0: pts.reverse()
		face(pts,"wall")
	box(Vector3(0,y+rise+0.06,0),Vector3(0.2,0.15,d+eave*2+0.2),"roof")
func build(profile: HD2DBuildingProfile) -> HD2DAsset:
	if profile.generator_version>=5: return preload("building_architecture_v5.gd").new().build(profile)
	if profile.generator_version>=4: return preload("building_architecture_v4.gd").new().build(profile)
	if profile.generator_version>=3: return preload("building_architecture_v3.gd").new().build(profile)
	if profile.generator_version>=2: return preload("building_architecture.gd").new().build(profile)
	buckets.clear()
	return build_legacy(profile)

func build_legacy(profile: HD2DBuildingProfile) -> HD2DAsset:
	var p := profile.parameters
	var rng := RandomNumberGenerator.new(); rng.seed=profile.shape_seed+profile.kind*113
	var w := float(p.get("width",4.5))*(1.25 if profile.kind==2 else 1.0)
	var d := float(p.get("depth",4.0))*(1.2 if profile.kind==2 else 1.0)
	var floors := clampi(int(p.get("floors",1)),1,3)
	var h := floors*2.5; var foundation := 0.3
	box(Vector3(0,foundation*0.5,0),Vector3(w+0.3,foundation,d+0.3),"stone")
	box(Vector3(0,h*0.5+foundation,0),Vector3(w,h,d),"wall")
	for x in [-1,1]:
		for z in [-1,1]: box(Vector3(x*(w*0.5+0.035),h*0.5+foundation,z*(d*0.5+0.035)),Vector3(0.16,h,0.16),"wood")
	for floor_index in range(floors+1):
		for side in [-1,1]: box(Vector3(0,foundation+floor_index*2.5,side*(d*0.5+0.045)),Vector3(w+0.16,0.14,0.15),"wood")
	var columns := clampi(int(p.get("windows",2)),1,4)
	for floor_index in floors:
		for side in [-1,1]:
			for i in columns:
				var x := (float(i+1)/(columns+1)-0.5)*w
				if floor_index==0 and side==1:
					var left := i<int(ceil(columns*0.5))
					var slots := maxi(1,int(ceil(columns*0.5)) if left else int(floor(columns*0.5)))
					var slot := i if left else i-int(ceil(columns*0.5))
					x=(-1.0 if left else 1.0)*(0.78+(slot+0.5)*(w*0.5-1.1)/slots)
				var pos := Vector3(x,foundation+floor_index*2.5+1.5,side*(d*0.5+0.075))
				box(pos,Vector3(0.9,1.15,0.16),"wood"); box(pos+Vector3(0,0,side*0.09),Vector3(0.69,0.93,0.045),"glass")
	for floor_index in floors:
		for side in [-1,1]:
			for index in 2:
				var pos := Vector3(side*(w*0.5+0.07),foundation+floor_index*2.5+1.45,(index-0.5)*d*0.48)
				box(pos,Vector3(0.16,1.12,0.9),"wood")
				box(pos+Vector3(side*0.09,0,0),Vector3(0.045,0.9,0.68),"glass")
	box(Vector3(0,foundation+0.96,d*0.5+0.08),Vector3(1.05,1.92,0.17),"wood")
	box(Vector3(0.3,foundation+0.95,d*0.5+0.18),Vector3(0.08,0.12,0.06),"accent")
	for i in 3: box(Vector3(0,0.05*(i+1),d*0.5+0.7-i*0.18),Vector3(1.5,0.1*(i+1),0.22),"stone")
	var eave := clampf(float(p.get("eave",0.45)),0.1,1.0)
	var flat := int(p.get("roof",0))==2 or (int(p.get("roof",0))==0 and profile.style=="desert")
	roof(w,d,h+foundation,tan(deg_to_rad(float(p.get("pitch",32))))*w*0.5,eave,flat,profile.style)
	if bool(p.get("porch",true)) or profile.kind==1:
		var pw := minf(w,2.8 if profile.kind!=1 else w)
		for x in [-1,1]: box(Vector3(x*pw*0.5,1.15,d*0.5+1.1),Vector3(0.13,2.3,0.13),"wood")
		box(Vector3(0,2.35,d*0.5+0.65),Vector3(pw+0.3,0.15,1.55),"roof")
		if profile.kind==1: box(Vector3(0,2.05,d*0.5+1.4),Vector3(pw*0.6,0.36,0.1),"accent")
	if profile.style=="forest": box(Vector3(w*0.28,h+foundation+0.5,-d*0.28),Vector3(0.6,1.7,0.65),"stone")
	# Seeded individual beam placement varies shape while remaining reproducible.
	for i in rng.randi_range(1,3): box(Vector3((i-1)*w*0.24,h*0.5+foundation,-d*0.5-0.04),Vector3(0.12,h,0.1),"wood")
	var asset := HD2DAsset.new(); var root := Node3D.new(); root.name="Architecture"
	asset.building_profile=profile; asset.library_entry_id=StringName("generated-"+profile.identity())
	asset.asset_id=asset.library_entry_id; asset.family_id=StringName("jeff-building-"+profile.style)
	asset.title=["江南","森林木屋","沙漠"][maxi(0,["jiangnan","forest","desert"].find(profile.style))]+" · "+["民居","商铺","中心建筑"][profile.kind]
	asset.category="建筑"; asset.wind=0; asset.static_collision=true
	for role in buckets:
		var mesh: ArrayMesh=buckets[role].commit(); mesh.surface_set_material(0,Materials.material(profile.style,role,0,profile.appearance_seed))
		var node := MeshInstance3D.new(); node.name=role; node.mesh=mesh; root.add_child(node); node.owner=root
		asset.material_slots[str(node.name)]=[role]
	var body := StaticBody3D.new(); body.name="BuildingCollision"; root.add_child(body); body.owner=root
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size=Vector3(w,h+foundation,d)
	collision.shape=shape; collision.position.y=(h+foundation)*0.5; body.add_child(collision); collision.owner=root
	var scene := PackedScene.new(); scene.pack(root); root.free(); asset.source=scene
	for look in range(1,4):
		var skin := HD2DAssetSkin.new(); skin.skin_id=StringName(["","elegant","warm","weathered"][look]); skin.title=["","素雅","暖色","风化"][look]; skin.family_id=asset.family_id
		for role in buckets: skin.materials[role]=Materials.material(profile.style,role,look,profile.appearance_seed)
		asset.skins.append(skin)
	return asset
