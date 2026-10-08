@tool
extends RefCounted
## Seeded street village, authored from existing assets. No source mesh mutation.
const VERSION := 2

static func bounds_for(asset: HD2DAsset) -> AABB:
	var box := AABB()
	var first := true
	for part in asset.mesh_parts():
		var bounds: AABB=part.transform*part.mesh.get_aabb()
		box=bounds if first else box.merge(bounds)
		first=false
	return box

static func rect(box: AABB) -> Rect2:
	return Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))

static func plan(palette: Array, options: Dictionary) -> Dictionary:
	if palette.is_empty(): return {"error":"请至少加入一种建筑素材。"}
	var bounds: Array[AABB]=[]
	for item in palette:
		var asset: HD2DAsset=item.get("asset")
		if asset==null or asset.source_missing() or asset.source is Texture2D:
			return {"error":"村落需要依赖完整的实体模型；图片贴片不能作为建筑。"}
		var box := bounds_for(asset)
		if not box.has_volume() or not box.position.is_finite() or not box.size.is_finite():
			return {"error":"建筑没有有效的三维占地。"}
		bounds.append(box)
	if int(options.layout)==2: return radial(palette,bounds,options)
	var rng := RandomNumberGenerator.new(); rng.seed=int(options.seed)
	var count := clampi(int(options.count),1,24)
	var rows := 1 if int(options.layout)==1 else 2
	var gap := maxf(0.5,float(options.gap))
	var width := maxf(1.0,float(options.road_width))
	var setback := maxf(0.5,float(options.setback))
	var entries: Array=[]
	var cursor := 0.0
	var plaza := float(options.get("center_type",0))>0
	var plaza_size := maxf(6.0,width+setback*2)
	var plaza_center := 0.0
	var plaza_column := int(ceili(float(count)/rows))/2
	for column in range(ceili(float(count)/rows)):
		if plaza and column==plaza_column:
			plaza_center=cursor+plaza_size*0.5; cursor+=plaza_size
		var batch: Array=[]
		var span := 0.0
		for row in range(mini(rows,count-column*rows)):
			var pick := pick_for(options,column*rows+row,rng,palette.size())
			var angle := (0.0 if row==0 else PI)-deg_to_rad(float(palette[pick].get("front",0.0)))
			var basis := Basis(Vector3.UP,angle)
			var box: AABB=Transform3D(basis,Vector3.ZERO)*bounds[pick]
			span=maxf(span,box.size.x)
			batch.append({"palette":pick,"row":row,"basis":basis,"bounds":box})
		for entry in batch:
			var box: AABB=entry.bounds
			var center := cursor+span*0.5
			var z := -width*0.5-setback-box.end.z if entry.row==0 else width*0.5+setback-box.position.z
			entry["position"]=Vector3(center-box.get_center().x,-box.position.y,z)
			entry["footprint"]=rect(AABB(box.position+entry.position,box.size))
			entry["path"]=PackedVector3Array([Vector3(center,0,0),Vector3(center,0,(-1 if entry.row==0 else 1)*(width*0.5+setback+0.02))])
			entries.append(entry)
		cursor+=span+gap
	var length := cursor-gap+gap*2
	var shift := plaza_center if plaza else (cursor-gap)*0.5
	var start := -shift-gap
	var end := cursor-shift
	var extent := Rect2(Vector2(start,-width*0.5),Vector2(length,width))
	var roads: Array=[{"points":PackedVector3Array([Vector3(start,0,0),Vector3(end,0,0)]),"width":width}]
	for entry in entries:
		entry.position.x-=shift
		entry.footprint.position.x-=shift
		for i in entry.path.size(): entry.path[i].x-=shift
		roads.append({"points":entry.path,"width":minf(1.4,width*0.5)})
		extent=extent.merge(entry.footprint)
	if plaza:
		roads.append({"points":PackedVector3Array([Vector3(-plaza_size*0.5,0.008,0),Vector3(plaza_size*0.5,0.008,0)]),"width":plaza_size})
		extent=extent.merge(Rect2(Vector2(-plaza_size*0.5,-plaza_size*0.5),Vector2.ONE*plaza_size))
	var walls: Array=[]
	if bool(options.get("walls",false)):
		var edge := extent.grow(float(options.get("wall_margin",2)))
		var gate := width*0.5+0.75
		for z in [edge.position.y,edge.end.y]:
			wall_run(walls,Vector3(edge.position.x,0,z),Vector3(edge.end.x,0,z),options)
		for x in [edge.position.x,edge.end.x]:
			wall_run(walls,Vector3(x,0,edge.position.y),Vector3(x,0,-gate),options)
			wall_run(walls,Vector3(x,0,gate),Vector3(x,0,edge.end.y),options)
		roads[0].points=PackedVector3Array([Vector3(edge.position.x-1,0,0),Vector3(edge.end.x+1,0,0)])
		extent=edge.grow(1)
	var gates: Array=[]
	if not walls.is_empty():
		for x in [extent.position.x+1,extent.end.x-1]: gates.append({"position":Vector3(x,0,0),"yaw":PI*0.5,"width":width+1.5})
	return {"entries":entries,"roads":roads,"walls":walls,"gates":gates,"extent":extent,"options":options.duplicate(true),"error":""}

static func wall_run(walls: Array, a: Vector3, b: Vector3, options: Dictionary) -> void:
	var n := maxi(1,ceili(a.distance_to(b)/2))
	var size := Vector3(0.4,float(options.get("wall_height",1.8)),0.4)
	if absf(a.x-b.x)>0.01: size.x=a.distance_to(b)/n
	else: size.z=a.distance_to(b)/n
	for i in n:
		var position := a.lerp(b,(i+0.5)/n)
		walls.append({"position":position,"size":size})

static func descendants(node: Node, type_name: String, skip: Node=null) -> Array:
	var result: Array=[]
	if node==skip: return result
	if (type_name=="prop" and node is HD2DProp) or (type_name=="liquid" and node is HD2DLiquidSurface) or (type_name=="wall" and node is MeshInstance3D and node.has_meta("village_wall")):
		return [node]
	for child in node.get_children(): result.append_array(descendants(child,type_name,skip))
	return result

static func validate(plan_data: Dictionary, terrain: HD2DTerrain, world: Transform3D, stage: HD2DStage, skip: Node=null) -> Dictionary:
	if terrain==null or terrain.data==null or terrain is HD2DWorldMap:
		return {"error":"请选择普通高度地形；本版村落不写入分区大地图。"}
	if not terrain.global_basis.y.is_equal_approx(Vector3.UP) or not terrain.global_basis.get_scale().is_equal_approx(Vector3.ONE):
		return {"error":"请将地形缩放设为 1，且不要绕 X / Z 轴倾斜。"}
	if bool(plan_data.options.get("grade",false)):
		return load("res://addons/hd2d_scene_tools/editor/village_terrain.gd").prepare(plan_data,terrain,world,stage,skip)
	var result: Dictionary=plan_data.duplicate(true)
	var obstacles: Array=[]
	var measured: Dictionary={}
	for node: HD2DProp in descendants(stage,"prop",skip):
		if node.asset==null: continue
		if not measured.has(node.asset): measured[node.asset]=bounds_for(node.asset)
		obstacles.append(rect(node.global_transform*measured[node.asset]))
	for wall: MeshInstance3D in descendants(stage,"wall",skip): obstacles.append(rect(wall.global_transform*wall.get_aabb()))
	var liquids: Array=descendants(stage,"liquid")
	for entry in result.entries:
		var local_bounds: AABB=entry.bounds
		local_bounds.position+=entry.position
		var footprint := rect(world*local_bounds)
		for obstacle: Rect2 in obstacles:
			if footprint.grow(0.15).intersects(obstacle): return {"error":"生成范围与已有物件重叠，请调整中心或方向。"}
		var low := INF; var high := -INF
		var area: Rect2=entry.footprint
		# Sample the whole foundation, not only its corners (hills can peak inside).
		var nx := maxi(1,ceili(area.size.x)); var nz := maxi(1,ceili(area.size.y))
		if nx*nz>20000: return {"error":"单栋建筑占地过大，请换用较小的模型。"}
		for z in range(nz+1):
			for x in range(nx+1):
				var p := world*Vector3(area.position.x+area.size.x*x/nx,0,area.position.y+area.size.y*z/nz)
				var sample := ground_sample(p,terrain,liquids)
				if sample.has("error"): return sample
				low=minf(low,sample.height); high=maxf(high,sample.height)
		if high-low>float(result.options.max_slope): return {"error":"地基高差超过限制，请先整平地形或调整生成位置。"}
		entry.position.y+=(world.affine_inverse()*Vector3(world.origin.x,high,world.origin.z)).y
	for road in result.roads:
		var points: PackedVector3Array=road.points
		var distance := points[0].distance_to(points[-1])
		var steps := maxi(1,ceili(distance/0.5))
		var tangent := (points[-1]-points[0]).normalized()
		var side := Vector3(-tangent.z,0,tangent.x)*float(road.width)*0.5
		var previous := NAN
		for i in range(steps+1):
			var p := points[0].lerp(points[-1],float(i)/steps)
			for offset in [Vector3.ZERO,side,-side]:
				var sample := ground_sample(world*(p+offset),terrain,liquids)
				if sample.has("error"): return sample
				if offset==Vector3.ZERO:
					if is_finite(previous) and absf(sample.height-previous)>distance/steps*0.5:
						return {"error":"道路过陡，请先平滑地形或调整生成位置。"}
					previous=sample.height
				for obstacle: Rect2 in obstacles:
					var q: Vector3=world*(p+offset)
					if obstacle.grow(0.15).has_point(Vector2(q.x,q.z)): return {"error":"生成范围与已有物件重叠，请调整中心或方向。"}
	for wall in result.get("walls",[]):
		var box := AABB(wall.position-wall.size*0.5,wall.size)
		for obstacle: Rect2 in obstacles:
			if rect(world*box).grow(0.1).intersects(obstacle): return {"error":"围墙与已有物件重叠，请调整中心或围墙退距。"}
		var low := INF; var high := -INF
		for i in 8:
			var sample := ground_sample(world*box.get_endpoint(i),terrain,liquids)
			if sample.has("error"): return sample
			low=minf(low,sample.height); high=maxf(high,sample.height)
		if high-low>float(result.options.max_slope): return {"error":"围墙处高差超过限制，请先整平地形或调整位置。"}
		# Segment extends down to the lowest sample; top follows the highest.
		wall.position.y=low-world.origin.y
		wall.size.y+=high-low
	return result

static func ground_sample(point: Vector3, terrain: HD2DTerrain, liquids: Array) -> Dictionary:
	var local := terrain.to_local(point)
	if absf(local.x)>terrain.data.size_m*0.5 or absf(local.z)>terrain.data.size_m*0.5:
		return {"error":"村落超出地形边界，请减少数量或调整中心。"}
	var height := terrain.world_height(point.x,point.z)
	if not is_finite(height): return {"error":"地形高度无效。"}
	for liquid: HD2DLiquidSurface in liquids:
		var p := liquid.to_local(Vector3(point.x,height,point.z))
		if absf(p.x)<=liquid.extent.x*0.5 and absf(p.z)<=liquid.extent.y*0.5 and p.y<0.05:
			return {"error":"生成范围进入水面或熔岩，请调整位置。"}
	return {"height":height}

static func radial(palette: Array, bounds: Array[AABB], options: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new(); rng.seed=int(options.seed)
	var count := clampi(int(options.count),1,24)
	var centered := int(options.get("center_type",1))==2
	var rings := clampi(int(options.get("rings",2)),1,mini(3,maxi(1,count-int(centered))))
	var width := float(options.road_width); var gap := float(options.gap); var setback := float(options.setback)
	var max_size := 0.0
	for box in bounds: max_size=maxf(max_size,Vector2(box.size.x,box.size.z).length())
	var entries: Array=[]; var roads: Array=[]; var walls: Array=[]
	var radius := maxf(4.0,max_size*0.65 if centered else 4.0)
	if centered:
		var pick := int(options.palette_sequence[0]) if options.has("palette_sequence") and not options.palette_sequence.is_empty() else mini(2,palette.size()-1); var box: AABB=bounds[pick]
		entries.append({"palette":pick,"basis":Basis.IDENTITY,"bounds":box,"position":-Vector3(box.get_center().x,box.position.y,box.get_center().z),"footprint":Rect2(Vector2(-box.size.x*0.5,-box.size.z*0.5),Vector2(box.size.x,box.size.z)),"path":PackedVector3Array()})
	else:
		roads.append({"points":PackedVector3Array([Vector3(-radius,0,0),Vector3(radius,0,0)]),"width":radius*2})
	var remaining := count-int(centered)
	var spokes := int(options.get("spokes",2)); spokes=4 if spokes==4 else 2
	for ring_index in rings:
		var n := ceili(float(remaining)/(rings-ring_index)); remaining-=n
		if n<=0: break
		radius=maxf(radius+width+setback+max_size*0.7,float(n)*(max_size*1.45+gap)/TAU+width+gap)
		var circle := PackedVector3Array()
		var road_radius := radius-max_size*0.5-setback-width*0.5
		for i in 65:
			var angle := i*TAU/64.0; circle.append(Vector3(cos(angle)*road_radius,0,sin(angle)*road_radius))
		roads.append({"points":circle,"width":width})
		for i in n:
			var sector := i%spokes
			var sector_count := int((n-1-sector)/spokes)+1
			var slot := int(i/spokes)
			var clearance := asin(clampf((max_size*0.5+width*0.5+gap*0.5)/radius,0.0,0.8))
			var angle := sector*TAU/spokes+clearance+(slot+0.5)*(TAU/spokes-clearance*2)/sector_count
			var pick := pick_for(options,entries.size(),rng,palette.size())
			var center := Vector3(cos(angle)*radius,0,sin(angle)*radius)
			var basis := Basis(Vector3.UP,atan2(-center.x,-center.z)-deg_to_rad(float(palette[pick].get("front",0))))
			var box: AABB=Transform3D(basis,Vector3.ZERO)*bounds[pick]
			var position := center-Vector3(box.get_center().x,box.position.y,box.get_center().z)
			var entrance: Vector3=position+basis*Vector3(0,0,bounds[pick].end.z-0.2)
			var path := PackedVector3Array([center.normalized()*road_radius,Vector3(entrance.x,0,entrance.z)])
			entries.append({"palette":pick,"basis":basis,"bounds":box,"position":position,"footprint":rect(AABB(box.position+position,box.size)),"path":path})
			roads.append({"points":path,"width":minf(1.4,width*0.5)})
		if ring_index==0 and centered:
			var front: float=entries[0].footprint.end.y-0.2
			roads.append({"points":PackedVector3Array([Vector3(0,0,front),Vector3(0,0,road_radius)]),"width":minf(1.4,width*0.5)})
		radius+=max_size*0.5+gap
	var outer := radius+float(options.get("wall_margin",2))
	for i in spokes:
		var a := i*TAU/spokes
		var dir := Vector3(cos(a),0,sin(a))
		roads.append({"points":PackedVector3Array([dir*(max_size*0.65 if centered else 0.0),dir*(outer+1)]),"width":width})
	for a in entries.size():
		for b in range(a+1,entries.size()):
			if entries[a].footprint.grow(gap*0.25).intersects(entries[b].footprint): return {"error":"建筑圈空间不足，请减少数量或增加建筑间隔。"}
		for i in spokes:
			var dir := Vector2(cos(i*TAU/spokes),sin(i*TAU/spokes))
			var center: Vector2=entries[a].footprint.get_center()
			if a==0 and centered: continue
			if center.dot(dir)>0 and absf(center.cross(dir))<width*0.5+entries[a].footprint.size.length()*0.5: return {"error":"连接道路与建筑冲突，请换一个布局或减少圈数。"}
	if bool(options.get("walls",false)):
		var n := maxi(32,ceili(TAU*outer/2.0))
		for i in n:
			var angle := (i+0.5)*TAU/n
			var gate := false
			for j in spokes:
				if absf(wrapf(angle-j*TAU/spokes,-PI,PI))*outer<width*0.5+1.5: gate=true
			if gate: continue
			walls.append({"position":Vector3(cos(angle)*outer,0,sin(angle)*outer),"size":Vector3(2*outer*sin(PI/n)+0.05,float(options.get("wall_height",1.8)),0.4),"yaw":-angle-PI*0.5})
	var gates: Array=[]
	if not walls.is_empty():
		for i in spokes:
			var angle := i*TAU/spokes
			gates.append({"position":Vector3(cos(angle)*outer,0,sin(angle)*outer),"yaw":-angle-PI*0.5,"width":width+1.5})
	return {"entries":entries,"roads":roads,"walls":walls,"gates":gates,"extent":Rect2(Vector2.ONE*(-outer-1),Vector2.ONE*(outer+1)*2),"options":options.duplicate(true),"error":""}

static func pick_for(options: Dictionary,index: int,rng: RandomNumberGenerator,size: int) -> int:
	var sequence: Array=options.get("palette_sequence",[])
	if index<sequence.size(): return clampi(int(sequence[index]),0,size-1)
	return rng.randi_range(0,size-1)
