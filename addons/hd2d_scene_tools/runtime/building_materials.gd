@tool
extends RefCounted
## Original, deterministic 64px tile recipes. No external artwork or Ronin dependency.
const VERSION := 1
const ROLES := ["roof","wall","wood","stone","glass","accent","paving","ground"]
const COLORS := {
 "jiangnan":["405b60","d9d4b8","664431","878f82","e8be6d","a64d39","87928b","708352"],
 "forest":["77543d","decaa0","594233","93908a","edc983","698471","928e81","647947"],
 "desert":["b58456","d6b878","725643","ae8e66","405f68","3e9192","ad9573","c0ac74"]}
static var cache := {}
static func texture(style: String, role: String, look: int=0, seed_value: int=101) -> Texture2D:
	var key := "%s/%s/%s/%s"%[style,role,look,seed_value]
	if cache.has(key): return cache[key]
	var colors: Array=COLORS.get(style,COLORS.jiangnan)
	var base := Color(colors[maxi(0,ROLES.find(role))])
	if look==1: base=base.lerp(Color("c9c9b7"),0.23)
	if look==2: base=base.lerp(Color("e4a454"),0.2)
	if look==3: base=base.lerp(Color("7e8566"),0.3)
	var rng := RandomNumberGenerator.new(); rng.seed=seed_value+role.hash()
	var im := Image.create(64,64,false,Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var shade := rng.randf_range(-0.055,0.055)
			match role:
				"wood": shade+=0.09*sin(float(y)*TAU/8+sin(float(x)*TAU/64)*0.3); shade-=0.2 if y%16==0 else 0.0
				"roof":
					shade+=0.13*cos(float(x%8)*TAU/8); shade-=0.24 if y%16==0 else 0.0
					if look==3 and (x*17+y*7)%47<6: shade-=0.15
				"stone","paving":
					var shifted := x+8*(int(y/16)%2)
					shade-=0.23 if y%16<2 or shifted%32<2 else 0.0
					shade+=0.10 if y%16==2 else 0.0
				"wall":
					if style=="desert": shade-=0.09 if y%16==0 else 0.0
					if look==3 and (x*19+y*13)%67<5: shade-=0.22
				"ground": shade+=0.07 if (x*7+y*3)%13<4 else -0.02
				"glass": shade-=0.45 if x%16<2 or y%16<2 else 0.0
			im.set_pixel(x,y,base.lightened(shade) if shade>=0 else base.darkened(-shade))
	im.generate_mipmaps()
	var t := ImageTexture.create_from_image(im); t.resource_name="Jeff/v1/"+key
	if cache.size()>128: cache.clear()
	cache[key]=t
	return t
static func material(style: String, role: String, look: int=0, seed_value: int=101) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.resource_name=role
	m.albedo_texture=texture(style,role,look,seed_value)
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.roughness=0.9
	return m
