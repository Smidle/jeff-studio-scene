@tool
extends RefCounted
const VERSION := 5
const STYLES := ["jiangnan","forest","desert"]
const DEFAULT_TYPES := ["house","farmhouse","inn","tavern","general_store","apothecary","forge","carpenter","town_hall"]
const DEFAULT_WEIGHTS := {"residential":50.0,"hospitality":15.0,"commerce":15.0,"craft":10.0,"public":10.0,"agriculture":0.0}
static var data: Dictionary={}

static func document() -> Dictionary:
	if data.is_empty(): data=JSON.parse_string(FileAccess.get_file_as_string("res://addons/hd2d_scene_tools/editor/building_catalog.json"))
	return data

static func types(category: String="") -> Array:
	return document().types.filter(func(row):return category.is_empty() or row.category==category)

static func entry(id: String) -> Dictionary:
	for row in types():
		if row.id==id: return row
	return {}

static func title(id: String, style: String, language: String="zh") -> String:
	var row := entry(id)
	return id if row.is_empty() else str(row.names.get(style,row.names.jiangnan).get(language,row.names.jiangnan.zh))

static func parameters(id: String, style: String, seed_value: int=60421, random_shape: bool=false, version: int=VERSION) -> Dictionary:
	var row := entry(id);var p: Dictionary=row.defaults.duplicate(true)
	if style=="forest": p.pitch=48;p.eave=0.55
	elif style=="desert": p.pitch=24;p.eave=0.25
	if version>=5 and id in ["house","general_store","inn"]:
		p.merge(preload("building_designs_v5.gd").defaults(id,style),true)
	if random_shape:
		var rng := RandomNumberGenerator.new();rng.seed=seed_value+id.hash()+style.hash()
		p.width=snappedf(clampf(p.width*rng.randf_range(0.82,1.15),3,10),0.25)
		p.depth=snappedf(clampf(p.depth*rng.randf_range(0.85,1.12),0.5 if row.archetype=="wall" else 2,10),0.25)
		if row.archetype=="house":
			p.floors=rng.randi_range(1,3 if row.kind==2 else 2)
			p.porch=rng.randf()>0.25;p.balcony=p.floors>1 and rng.randf()>0.35
			p.roof=0 if rng.randf()>0.22 else (2 if style=="desert" else 1)
		if style!="desert": p.pitch=clampf(p.pitch+rng.randi_range(-6,4),15,50)
		p.height=snappedf(p.height*rng.randf_range(0.90,1.12),0.1)
		p.bays=rng.randi_range(2,5)
	if version>=5 and id=="inn": p.floors=maxi(2,int(p.floors))
	return p

static func profile(id: String, style: String="jiangnan", seed_value: int=60421, detail: int=101, random_shape: bool=false, version: int=VERSION) -> HD2DBuildingProfile:
	var row := entry(id);var result := HD2DBuildingProfile.new()
	result.generator_version=version;result.preset_version=version;result.style=style
	result.type_id=id;result.category_id=row.category;result.kind=int(row.kind)
	result.shape_seed=seed_value;result.detail_seed=detail
	result.parameters=parameters(id,style,seed_value,random_shape,version)
	return result

static func fields(id: String) -> Array:
	var base := ["width","depth","shape_seed","detail_seed","appearance_seed"]
	match str(entry(id).get("archetype","house")):
		"house": base.append_array(["floors","pitch","eave","windows","roof","porch","balcony","ornament"])
		"tower": base.append_array(["floors","pitch","eave","windows","roof"])
		"barn": base.append_array(["height","bays","pitch","eave"])
		"greenhouse": base.append_array(["height","bays"])
		"stall": base.append_array(["height","bays"])
		"wall","dock","ruin": base.append_array(["height","bays"])
		"gate","fortress","portal": base.append("height")
	return base

static func allocate(count: int, selected: Array, weights: Dictionary, seed_value: int, center: bool) -> Dictionary:
	var pools := {};var total := 0.0
	for id in selected:
		var row := entry(str(id));var group: String=row.get("town_group","")
		if group.is_empty() or float(weights.get(group,0))<=0: continue
		if not pools.has(group): pools[group]=[];total+=float(weights[group])
		if not pools[group].has(id): pools[group].append(id)
	if pools.is_empty(): return {"error":"请勾选至少一种可参与生成的小镇建筑。"}
	if center and not pools.has("public"): return {"error":"中心建筑需要勾选至少一种公共建筑。"}
	var quotas := {};var remainders: Array=[];var assigned := 0
	for group in pools:
		var exact := count*float(weights[group])/total
		quotas[group]=floori(exact);assigned+=quotas[group]
		remainders.append({"group":group,"fraction":exact-floorf(exact)})
	remainders.sort_custom(func(a,b):return a.fraction>b.fraction if not is_equal_approx(a.fraction,b.fraction) else a.group<b.group)
	for i in count-assigned: quotas[remainders[i%remainders.size()].group]+=1
	if center and quotas.public==0:
		var largest: String=pools.keys()[0]
		for group in pools:
			if quotas[group]>quotas[largest]: largest=group
		quotas[largest]-=1;quotas.public=1
	var rng := RandomNumberGenerator.new();rng.seed=seed_value
	var ids: Array=[]
	if center:
		ids.append(pools.public[rng.randi_range(0,pools.public.size()-1)]);quotas.public-=1
	var tail: Array=[]
	for group in pools:
		for i in int(quotas[group]): tail.append(pools[group][rng.randi_range(0,pools[group].size()-1)])
	for i in range(tail.size()-1,0,-1):
		var j := rng.randi_range(0,i);var value=tail[i];tail[i]=tail[j];tail[j]=value
	ids.append_array(tail)
	return {"error":"","types":ids}
