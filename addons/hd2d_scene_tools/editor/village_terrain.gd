@tool
extends RefCounted
const Layout=preload("village_layout.gd")
const Materials=preload("../runtime/building_materials.gd")
static func clone(source: HD2DTerrainData) -> HD2DTerrainData:
	var result: HD2DTerrainData=source.duplicate(true)
	# Texture inputs are immutable; detach the slot array, retain original resources.
	result.textures=source.textures.duplicate()
	return result
static func layer_state(d: HD2DTerrainData) -> Dictionary:
	return {"textures":d.textures.duplicate(),"layer_names":d.layer_names.duplicate(),"layer_preset_ids":d.layer_preset_ids.duplicate(),"colors":d.colors.duplicate(),"layer_count":d.layer_count}
static func layers_equal(a: Dictionary,b: Dictionary) -> bool:
	for field in ["layer_names","layer_preset_ids","colors","layer_count"]:
		if a.get(field)!=b.get(field): return false
	var first: Array=a.textures;var second: Array=b.textures
	if first.size()!=second.size():return false
	for i in first.size():
		if first[i]==second[i]:continue
		if first[i]==null or second[i]==null:return false
		var image_a: Image=first[i].get_image();var image_b: Image=second[i].get_image()
		if image_a==null or image_b==null or image_a.get_size()!=image_b.get_size() or image_a.get_format()!=image_b.get_format() or image_a.get_data()!=image_b.get_data():return false
	return true
static func set_layers(d: HD2DTerrainData,s: Dictionary) -> void:
	for key in s: d.set(key,s[key].duplicate() if s[key] is Array else s[key])
	d.ensure_extra_weights()
static func distance_to_road(p: Vector2, roads: Array) -> float:
	var dist := INF
	for road in roads:
		var points: PackedVector3Array=road.points
		for i in range(points.size()-1):
			var a := Vector2(points[i].x,points[i].z); var b := Vector2(points[i+1].x,points[i+1].z)
			dist=minf(dist,p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))-float(road.width)*0.5)
	return dist
static func prepare(plan: Dictionary,t: HD2DTerrain,world: Transform3D,stage: HD2DStage,skip: Node=null) -> Dictionary:
	var d: HD2DTerrainData=clone(t.data)
	var actual := t.data
	var old: Dictionary=skip.recipe.get("terrain_patch",{}) if skip is HD2DVillage else {}
	if not old.is_empty():
		if old.get("terrain_path")!=str(stage.get_path_to(t)) or old.get("resolution")!=actual.resolution or old.get("size_m")!=actual.size_m: return {"error":"原整地目标或规格已改变，不能覆盖；请新建草稿。"}
		for key in old.after:
			var at := int(key); var value: Array=old.after[key]
			if not is_equal_approx(actual.heights[at],value[0]) or actual.weights[at]!=value[1] or (actual.layer_count>4 and actual.weights_extra[at]!=value[2]): return {"error":"原整地范围已被修改；停止覆盖，草稿已保留。"}
		if not layers_equal(layer_state(actual),old.layers_after): return {"error":"原地表设置已改变；停止覆盖，草稿已保留。"}
		set_layers(d,old.layers_before)
		for key in old.before:
			var at := int(key); var value: Array=old.before[key]
			d.heights[at]=value[0]; d.weights[at]=value[1]
			if d.layer_count>4: d.weights_extra[at]=value[2]
	var original: HD2DTerrainData=clone(d)
	var result := plan.duplicate(true)
	var options: Dictionary=plan.options
	var material_style := str(options.get("material_style","jiangnan"))
	var paving_id := "builtin-v1/"+material_style+"/paving"
	var mode := int(options.get("paving_mode",0)) # 0 auto terrain layer; 1 explicit layer; 2 fitted mesh
	if mode==0:
		var narrow := float(options.road_width)
		for road in result.roads: narrow=minf(narrow,float(road.width))
		# Vertex weights cannot resolve a path narrower than two terrain samples.
		if d.cell_size()>narrow*0.5:
			mode=2;result.options.paving_mode=2
			result.road_notice="地形采样较疏，道路自动使用贴地像素网格，保持环路连通。"
	if t.surface_material and mode!=2: return {"error":"复合地表请使用贴地铺装网格，或先改用多层地表。"}
	var layer := -1
	var layers_before := layer_state(d)
	if bool(options.get("style_ground",false)) and not d.textures.any(func(texture):return texture!=null) and t.surface_material==null:
		d.textures.resize(d.layer_count);d.textures[0]=Materials.texture(material_style,"ground",int(options.get("appearance",0)),int(options.get("appearance_seed",101)))
		d.layer_names.resize(d.layer_count);d.layer_preset_ids.resize(d.layer_count)
		d.layer_names[0]="小镇底材";d.layer_preset_ids[0]="builtin-v1/"+material_style+"/ground"
	if mode!=2:
		layer=d.layer_preset_ids.find(paving_id)
		if mode==1: layer=int(options.get("paving_layer",1))-1
		elif layer<0:
			for i in d.layer_count:
				if i<d.textures.size() and d.textures[i]!=null: continue
				var used := false
				for at in d.weights.size():
					if (d.weights[at][i] if i<4 else d.weights_extra[at][i-4])>0.001: used=true; break
				if not used: layer=i; break
			if layer<0 and d.layer_count<8: layer=d.layer_count; d.layer_count+=1; d.ensure_extra_weights()
		if layer<0 or layer>=d.layer_count: return {"error":"地表没有空层；请选择已有层，或改用贴地像素铺装网格。"}
		if mode==0:
			d.textures.resize(d.layer_count); d.layer_names.resize(d.layer_count); d.layer_preset_ids.resize(d.layer_count)
			d.colors.resize(maxi(d.colors.size(),d.layer_count)); d.colors[layer]=Color.WHITE
			d.textures[layer]=Materials.texture(material_style,"paving",int(options.get("appearance",0)),int(options.get("appearance_seed",101)))
			d.layer_names[layer]="小镇铺装"; d.layer_preset_ids[layer]=paving_id
	var rel := t.global_transform.affine_inverse()*world
	var inv := rel.affine_inverse()
	var liquids: Array=Layout.descendants(stage,"liquid")
	var obstacles: Array=[]
	for prop: HD2DProp in Layout.descendants(stage,"prop",skip):
		if prop.asset: obstacles.append(Layout.rect(world.affine_inverse()*prop.global_transform*Layout.bounds_for(prop.asset)))
	var margin := float(options.get("foundation_margin",0.3)); var blend := maxf(d.cell_size(),float(options.get("blend",2)))
	var limit := float(options.get("max_slope",2))
	var pads: Array=[]
	for entry in result.entries:
		var area: Rect2=entry.footprint
		for obstacle: Rect2 in obstacles:
			if area.grow(0.1).intersects(obstacle): return {"error":"生成范围与已有物件重叠，请调整中心或方向。"}
		var center := area.get_center(); var p: Vector3=rel*Vector3(center.x,0,center.y)
		var floor_height := original.height_at(p.x,p.z)
		entry.position.y+=floor_height-rel.origin.y
		pads.append({"area":area.grow(margin),"height":floor_height})
	var extent: Rect2=result.extent.grow(margin+blend+1)
	var lo := Vector2i(d.resolution-1,d.resolution-1); var hi := Vector2i.ZERO
	for corner in [extent.position,extent.end,Vector2(extent.position.x,extent.end.y),Vector2(extent.end.x,extent.position.y)]:
		var p: Vector3=rel*Vector3(corner.x,0,corner.y)
		if absf(p.x)>d.size_m*0.5 or absf(p.z)>d.size_m*0.5: return {"error":"村落超出地形边界，请减少数量或调整中心。"}
		var grid := Vector2i(floor((p.x+d.size_m*0.5)/d.cell_size()),floor((p.z+d.size_m*0.5)/d.cell_size()))
		lo=lo.min(grid);hi=hi.max(grid+Vector2i.ONE)
	lo=lo.max(Vector2i.ZERO);hi=hi.min(Vector2i.ONE*(d.resolution-1))
	# Raster union handles intersections/plazas once; no overlapping road strips.
	var road_cells := {}; var foundation_cells := {}
	var widest := 0.0
	for road in result.roads: widest=maxf(widest,float(road.width)*0.5)
	var road_index := preload("village_road_index.gd").new(result.roads,blend+widest)
	var road_centers := {}
	for z in range(lo.y,hi.y+1):
		for x in range(lo.x,hi.x+1):
			var at := z*d.resolution+x; var p := Vector3(x*d.cell_size()-d.size_m*0.5,0,z*d.cell_size()-d.size_m*0.5)
			var local := inv*p; var q := Vector2(local.x,local.z)
			var road_sample: Dictionary=road_index.sample(q)
			var road_distance: float=road_sample.distance
			var nearest := INF; var floor_height := d.heights[at]
			for pad in pads:
				var area: Rect2=pad.area
				var distance := q.distance_to(q.clamp(area.position,area.end))
				if distance<nearest: nearest=distance;floor_height=pad.height
			if road_distance>blend and nearest>blend: continue
			var check := Layout.ground_sample(t.to_global(p),t,liquids)
			if check.has("error"): return check
			for obstacle: Rect2 in obstacles:
				if road_distance<=0 and obstacle.grow(0.1).has_point(q): return {"error":"道路与已有物件冲突，请调整布局。"}
			if nearest<=blend:
				d.heights[at]=lerpf(original.heights[at],floor_height,1.0-smoothstep(0.0,blend,nearest))
				if nearest<0.001: foundation_cells[at]=true
			if road_distance<=blend: road_cells[at]=road_distance;road_centers[at]=road_sample.center
	# A bounded slope projection keeps road samples connected, pinning foundations.
	for iteration in 80:
		var changed := false
		for key in road_cells:
			var at := int(key)
			if road_cells[at]>0: continue
			for offset in [1,d.resolution]:
				var other: int=at+offset
				if not road_cells.has(other) or road_cells[other]>0: continue
				var delta := d.heights[other]-d.heights[at];var allowed := d.cell_size()*0.12
				if absf(delta)<=allowed+0.001: continue
				var excess := (absf(delta)-allowed)*signf(delta)
				if foundation_cells.has(at) and foundation_cells.has(other): continue
				elif foundation_cells.has(at): d.heights[other]-=excess
				elif foundation_cells.has(other): d.heights[at]+=excess
				else: d.heights[at]+=excess*0.5;d.heights[other]-=excess*0.5
				changed=true
		if not changed: break
	var solved: HD2DTerrainData=clone(d)
	for key in road_cells:
		var at := int(key);var distance: float=road_cells[key]
		if distance>0 and not foundation_cells.has(at):
			var chosen: Vector2=road_centers[at]
			var sample := rel*Vector3(chosen.x,0,chosen.y)
			d.heights[at]=lerpf(original.heights[at],solved.height_at(sample.x,sample.z),1-smoothstep(0.0,blend,distance))
		if distance<=0:
			for offset in [1,d.resolution]:
				if road_cells.has(at+offset) and road_cells[at+offset]<=0 and absf(d.heights[at]-d.heights[at+offset])>d.cell_size()*0.14: return {"error":"道路坡度无法在限制内连通，请增大过渡范围或调整中心。"}
		if mode==2 or foundation_cells.has(at): continue
		var mix := 1.0-smoothstep(-d.cell_size()*0.3,maxf(d.cell_size(),0.55),distance)
		if mix<=0: continue
		var a: Color=d.weights[at];var b := d.weights_extra[at] if d.layer_count>4 else Color(0,0,0,0)
		a*=1-mix;b*=1-mix
		if layer<4: a[layer]+=mix
		else: b[layer-4]+=mix
		d.weights[at]=a
		if d.layer_count>4: d.weights_extra[at]=b
	var before := {};var after := {}
	for at in d.heights.size():
		if absf(d.heights[at]-original.heights[at])>limit+0.001: return {"error":"整地高度超过限制，请调整中心或最大整地高度。"}
		var prior := [original.heights[at],original.weights[at],original.weights_extra[at] if original.layer_count>4 else Color(0,0,0,0)]
		var value := [d.heights[at],d.weights[at],d.weights_extra[at] if d.layer_count>4 else Color(0,0,0,0)]
		if prior!=value: before[at]=prior;after[at]=value
	for wall in result.walls:
		var p: Vector3=rel*wall.position
		var sample := Layout.ground_sample(t.to_global(p),t,liquids)
		if sample.has("error"): return sample
		var low := d.height_at(p.x,p.z);var high := low
		var basis := Basis(Vector3.UP,float(wall.get("yaw",0)))
		for x in [-0.5,0.5]:
			for z in [-0.5,0.5]:
				var corner: Vector3=rel*(wall.position+basis*Vector3(x*wall.size.x,0,z*wall.size.z))
				low=minf(low,d.height_at(corner.x,corner.z));high=maxf(high,d.height_at(corner.x,corner.z))
		wall.position.y=low-rel.origin.y-0.08
		wall.size.y+=high-low+0.08
	for gate in result.get("gates",[]):
		var p: Vector3=rel*gate.position
		gate.position.y=d.height_at(p.x,p.z)-rel.origin.y
	result.terrain_patch={"before":before,"after":after,"layers_before":layers_before,"layers_after":layer_state(d),"resolution":d.resolution,"size_m":d.size_m,"terrain_path":str(stage.get_path_to(t))}
	result.draft_terrain=d; result.terrain_transform=rel.affine_inverse(); result.terrain_source=t
	return result
