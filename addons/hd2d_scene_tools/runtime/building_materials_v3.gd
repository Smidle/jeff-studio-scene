@tool
extends RefCounted
## Original clustered pixel patterns: 20 texels/metre, six shades per semantic role.
const ROLES=preload("building_materials_v2.gd").ROLES
const PALETTES=preload("building_materials_v2.gd").PALETTES
const SHADES := [-0.34,-0.18,-0.07,0.0,0.12,0.22]
static var cache := {}

static func texture(style: String, role: String, look: int, seed_value: int) -> Texture2D:
	var key := "%s/%s/%d/%d"%[style,role,look,seed_value]
	if cache.has(key): return cache[key]
	var base := Color(PALETTES.get(style,PALETTES.jiangnan)[maxi(0,ROLES.find(role))])
	if look==1: base=base.lerp(Color("c2c9bf"),0.20)
	if look==2: base=base.lerp(Color("e5a15e"),0.18)
	if look==3: base=base.lerp(Color("889176"),0.16)
	var palette: Array=[]
	for shade in SHADES: palette.append(base.lightened(shade) if shade>=0 else base.darkened(-shade))
	var rng := RandomNumberGenerator.new();rng.seed=seed_value+role.hash()
	var cells: Array=[]
	for i in 256: cells.append(rng.randi_range(0,9))
	var im := Image.create(32,32,false,Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			var cell: int=cells[(y/2)*16+x/2]
			var index := 2 if cell<2 else (4 if cell==9 else 3)
			match role:
				"roof":
					var tx := (x+(y/8)%2*4)%8
					index=2 if tx<4 else 3
					if y%8==0 or tx==0: index=0
					elif y%8==1: index=4
					elif tx==1: index=5
				"wood":
					var grain := (y+(x/8)%2)%8
					if grain==0: index=0
					elif grain==1: index=4
					elif grain==4 and x%8<5: index=1
				"stone":
					var sx := (x+(y/8)*8)%16
					if y%8==0 or sx==0: index=0
					elif y%8==1 or sx==1: index=4
				"wall":
					# Broad plaster patches; avoid unrelated single-pixel noise.
					index=2 if cells[(y/4)*16+x/4]<2 else 3
					if style=="desert" and y%8==0 and (x+(y/8)*4)%16<12: index=1
				"glass": index=4 if (x/4+y/4)%2==0 else 2
				"cloth": index=1 if x%8<3 else 4
				"metal": index=5 if y%8<2 else 2
				"shadow": index=2
			if look==3 and role in ["roof","wall","stone","wood"] and cells[(y/4)*16+x/4]==0: index=maxi(0,index-1)
			im.set_pixel(x,y,palette[index])
	im.generate_mipmaps()
	var result := ImageTexture.create_from_image(im);result.resource_name="Jeff/v3/"+key
	if cache.size()>256: cache.clear()
	cache[key]=result;return result

static func material(style: String, role: String, look: int, seed_value: int) -> StandardMaterial3D:
	var result := StandardMaterial3D.new();result.resource_name=role
	result.albedo_texture=texture(style,role,look,seed_value)
	result.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	result.vertex_color_use_as_albedo=true;result.roughness=1.0;result.metallic_specular=0.0
	return result
