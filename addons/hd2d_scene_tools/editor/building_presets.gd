@tool
extends RefCounted
## Stable v3 sample recipes and constrained random parameters. No external assets.
const VERSION := 3
const STYLES := ["jiangnan","forest","desert"]
const SAMPLE_NAMES := ["江南 · 听雨木楼","欧式 · 松影小屋","沙漠 · 绿洲商宅"]

static func sample(style: String, kind: int=0) -> Dictionary:
	var result := {"width":6.0,"depth":4.75,"floors":2,"pitch":30,"eave":0.65,"windows":2,"roof":0,"porch":true,"balcony":true,"ornament":true}
	if style=="forest": result.merge({"width":5.25,"depth":4.75,"floors":1,"pitch":48,"eave":0.55,"balcony":false},true)
	if style=="desert": result.merge({"width":5.75,"depth":5.0,"floors":2,"pitch":24,"eave":0.25,"balcony":true},true)
	if kind==1: result.width+=0.5
	if kind==2: result.width+=1.0;result.depth+=0.5;result.floors=2
	return result

static func random_parameters(style: String, kind: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new();rng.seed=seed_value+kind*971+STYLES.find(style)*7919
	var p := sample(style,kind)
	p.width=snappedf(rng.randf_range(4.5,7.0)+(0.75 if kind==2 else 0.0),0.25)
	p.depth=snappedf(rng.randf_range(4.0,6.0),0.25)
	p.floors=rng.randi_range(1,2) if kind!=2 else rng.randi_range(2,3)
	p.pitch=rng.randi_range(25,36) if style=="jiangnan" else rng.randi_range(40,50)
	p.eave=snappedf(rng.randf_range(0.45,0.75),0.05)
	if style=="desert": p.pitch=24;p.eave=0.25
	p.windows=2 if p.width<6.25 else 3
	p.porch=true if kind==1 else rng.randf()>0.2
	p.balcony=p.floors>1 and rng.randf()>0.2;p.ornament=true
	return p

static func profile(style: String, kind: int=0, seed_value: int=60421, random_shape: bool=false) -> HD2DBuildingProfile:
	var result := HD2DBuildingProfile.new()
	result.generator_version=VERSION;result.preset_version=VERSION
	result.style=style;result.kind=kind;result.shape_seed=seed_value
	result.parameters=random_parameters(style,kind,seed_value) if random_shape else sample(style,kind)
	return result
