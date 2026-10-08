@tool
class_name HD2DTerrainTemplates
extends RefCounted
const IDS := ["flat","lake","river","coast","sea","volcano"]
const TITLES := ["平地","湖泊与湖岸","蜿蜒河谷","海岸沙滩","大海与小岛","火山口"]
const SCHEMES := {"lake":"lakeshore","river":"riverbank","coast":"coast","sea":"island","volcano":"volcano"}
const DESCRIPTIONS := [
	"平坦地面，可自由雕刻。",
	"下凹湖盆与缓坡湖岸，生成独立水面。",
	"贯穿地图的弯曲河道，两侧保留可行走河岸。",
	"一侧陆地、一侧海床，生成独立海面。",
	"中央小岛与四周海床，生成独立海面。",
	"环形火山山体与下凹火山口，生成独立熔岩面。"]

static func sample(kind: String, p: Vector2) -> float:
	var r := p.length()
	match kind:
		"lake":
			var edge := Vector2(p.x/0.72,p.y/0.58).length()+0.05*sin(p.x*9)*sin(p.y*7)
			return lerpf(-0.045,0.025,smoothstep(0.65,1.08,edge))+maxf(edge-1.1,0)*0.008
		"river":
			var distance := absf(p.x-0.22*sin(p.y*3.8))
			return lerpf(-0.035,0.025,smoothstep(0.13,0.29,distance))
		"coast":
			return lerpf(0.045,-0.055,smoothstep(-0.4,0.4,p.x+0.07*sin(p.y*7)))
		"sea": return lerpf(0.04,-0.065,smoothstep(0.16,0.52,r+0.035*sin(p.y*11)))
		"volcano": return 0.018+0.14*exp(-pow((r-0.4)/0.18,2))-0.026*exp(-pow(r/0.21,2))
	return 0.0

static func shape_data(data: HD2DTerrainData, kind: String) -> void:
	if kind=="flat" or not IDS.has(kind): return
	if data.textures.is_empty():
		data.layer_count=3
		data.colors=PackedColorArray([Color("718347"),Color("ac9a76"),Color("716d64")])
		if kind=="volcano": data.colors=PackedColorArray([Color("363841"),Color("63574c"),Color("633326")])
	var liquid_height := data.size_m*0.04 if kind=="volcano" else 0.0
	for z in range(data.resolution):
		for x in range(data.resolution):
			var p := Vector2(x,z)/float(data.resolution-1)*2.0-Vector2.ONE
			var i := z*data.resolution+x
			var h := sample(kind,p)*data.size_m; data.heights[i]=h
			# First three slots describe upland, bank and bed. Remaining slots stay available.
			var land := smoothstep(liquid_height,liquid_height+data.size_m*0.02,h)
			var bed := 1.0-smoothstep(liquid_height-data.size_m*0.025,liquid_height,h)
			var values := [land,maxf(0,1-land-bed),bed]
			var weights := Color(0,0,0,0)
			for layer in range(3): weights[mini(layer,data.layer_count-1)]+=values[layer]
			data.weights[i]=weights
	data.emit_changed()

static func make_liquid(kind: String, size_m: float, speed: float=0.35) -> HD2DLiquidSurface:
	var liquid := HD2DLiquidSurface.new()
	liquid.name="Lava" if kind=="volcano" else "Water"
	liquid.kind=1 if kind=="volcano" else 0
	liquid.extent=Vector2.ONE*size_m*(0.58 if kind=="volcano" else 1.0)
	if kind=="lake": liquid.extent=Vector2(0.8,0.68)*size_m
	elif kind=="river": liquid.extent=Vector2(0.6,1.0)*size_m
	liquid.position.y=size_m*0.04 if kind=="volcano" else 0.0
	liquid.animation_speed=speed
	return liquid

static func populate(stage: HD2DStage, kind: String, include_liquid: bool=true, speed: float=0.35) -> void:
	if kind=="flat" or not IDS.has(kind): return
	var data := stage.terrain().data
	shape_data(data,kind)
	if include_liquid: HD2DFactory.attach(stage,make_liquid(kind,data.size_m,speed),stage)
	var hero := stage.get_node("Characters/Hero") as Node3D
	var spawn := Vector2.ZERO if kind=="sea" else Vector2(-0.4,0.38)*data.size_m
	hero.position=Vector3(spawn.x,data.height_at(spawn.x,spawn.y)+0.2,spawn.y)
