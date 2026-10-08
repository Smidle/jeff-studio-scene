@tool
extends RefCounted
## Original limited-palette pixel patterns. V1 materials remain immutable for old recipes.
const ROLES := ["roof","wall","wood","stone","glass","accent","metal","shadow","cloth","trim"]
const PALETTES := {
	"jiangnan":["425b61","e1dec8","694334","8c9691","dfbe79","b6543e","756857","343737","b9a77c","b68759"],
	"forest":["556977","ddc59c","644739","929489","e8c47c","617761","706958","303c3c","a35942","af875b"],
	"desert":["c49764","dfbd82","7d573c","b79570","609a9c","3c8989","a98a52","544839","b85840","ead4a1"]}
static var cache := {}

static func texture(style: String, role: String, look: int, seed_value: int) -> Texture2D:
	var key := "%s/%s/%d/%d"%[style,role,look,seed_value]
	if cache.has(key): return cache[key]
	var base := Color(PALETTES.get(style,PALETTES.jiangnan)[maxi(0,ROLES.find(role))])
	if look==1: base=base.lerp(Color("c2c9bf"),0.20)
	if look==2: base=base.lerp(Color("e5a15e"),0.18)
	if look==3: base=base.lerp(Color("889176"),0.16)
	var rng := RandomNumberGenerator.new();rng.seed=seed_value+role.hash()
	var cells := []
	for i in 256: cells.append(rng.randi_range(-2,2))
	var im := Image.create(64,64,false,Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var shade := float(cells[(y/4)*16+x/4])*0.022
			var color := base
			match role:
				"roof":
					var row := y/12;var col := (x+(row%2)*5)%12
					shade+=0.05*float(cells[(row*19+x/12)%256])
					if y%12==0: shade=-0.32
					elif y%12==1: shade=0.16
					elif col==0: shade=-0.22
					elif col==1: shade=0.1
					if style=="jiangnan": shade+=0.08 if x%6 in [1,2] else -0.035
				"wood":
					var grain := posmod(y+int(sin(float(x)*0.12)*1.5),8)
					if grain==0: shade-=0.17
					if grain==1: shade+=0.08
					var knot := Vector2(x-22,y-27)
					if absf(knot.length()-5.0)<0.8: shade-=0.22
					if y%16==0: shade-=0.18
				"stone":
					var sx := (x+int(y/12)*9)%24
					if y%12==0 or sx==0: shade=-0.23
					elif y%12==1 or sx==1: shade=0.12
				"wall":
					if style=="desert" and y%16==0 and (x+int(y/16)*7)%24<20: shade-=0.09
					if cells[(y/4)*16+x/4]==-2 and (x+y)%7<2: shade-=0.07
				"glass":
					shade=0.06 if (x/8+y/8)%2==0 else -0.08
					if x%16==0 or y%16==0: shade=-0.20
				"cloth":
					if x%16<5: color=Color(PALETTES.get(style,PALETTES.jiangnan)[9]);shade=0
				"metal": shade=0.08 if y%8==0 else -0.04
			if look==3 and role in ["roof","wall","stone","wood"]:
				var patch := int(cells[((y/8)*23+x/8)%256])
				if patch==-2 and ((x/2+y/2)%3!=0): color=color.lerp(Color("53684b"),0.30);shade-=0.06
			im.set_pixel(x,y,color.lightened(shade) if shade>=0 else color.darkened(-shade))
	im.generate_mipmaps()
	var result := ImageTexture.create_from_image(im);result.resource_name="Jeff/v2/"+key
	if cache.size()>256: cache.clear()
	cache[key]=result;return result

static func material(style: String, role: String, look: int, seed_value: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new();m.resource_name=role
	m.albedo_texture=texture(style,role,look,seed_value)
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.vertex_color_use_as_albedo=true;m.roughness=0.92
	if role=="glass": m.roughness=0.7
	if role=="metal": m.roughness=0.6
	return m
