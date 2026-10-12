@tool
extends RefCounted
## Six additional original atlases; Godot cuts role tiles once. Each tile owns its mip chain.
const ROLES := ["roof","wood","wall","stone","trim","glass","cloth","metal","shadow","accent","door","window","roof_edge","wall_base","sign","shutter"]
static var atlases := {}
static var tiles := {}
static var loads := 0
const COMPONENTS := ["door","window","sign","shutter","wall_base","roof_edge"]

static func texture(style: String, role: String) -> Texture2D:
	var key := style+"/"+role
	if role=="snow":
		if not tiles.has(key):
			var snow := Image.create(16,16,false,Image.FORMAT_RGB8)
			for y in 16:
				for x in 16:
					var shade := 0.02 if (x/4+y/3)%4==0 else 0.0
					snow.set_pixel(x,y,Color(0.65+shade,0.73+shade,0.79+shade))
			snow.generate_mipmaps()
			tiles[key]=ImageTexture.create_from_image(snow)
		return tiles[key]
	if tiles.has(key): return tiles[key]
	if not atlases.has(style):
		atlases[style]=Image.load_from_file("res://addons/hd2d_scene_tools/assets/buildings/v6/"+style+".png");loads+=1
	var atlas: Image=atlases[style]
	var index := maxi(0,ROLES.find(role));var cell := atlas.get_width()/4.0
	var left := roundi((index%4)*cell);var top := roundi((index/4)*cell)
	var right := roundi((index%4+1)*cell);var bottom := roundi((index/4+1)*cell)
	var tile := atlas.get_region(Rect2i(left,top,right-left,bottom-top))
	var pixels := 64 if role=="roof" else 128
	tile.resize(pixels,pixels,Image.INTERPOLATE_NEAREST)
	# The two border texels meet exactly on repeating tiles. Components retain their frame.
	if role not in COMPONENTS:
		for a in pixels:
			var c := tile.get_pixel(0,a).lerp(tile.get_pixel(pixels-1,a),0.5)
			tile.set_pixel(0,a,c);tile.set_pixel(pixels-1,a,c)
		for a in pixels:
			var c := tile.get_pixel(a,0).lerp(tile.get_pixel(a,pixels-1),0.5)
			tile.set_pixel(a,0,c);tile.set_pixel(a,pixels-1,c)
	tile.generate_mipmaps()
	var result := ImageTexture.create_from_image(tile);result.resource_name="Jeff/v6/"+key
	tiles[key]=result;return result

static func material(style: String, role: String, look: int, seed_value: int) -> StandardMaterial3D:
	var result := StandardMaterial3D.new();result.resource_name=role
	result.albedo_texture=texture(style,role);result.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	result.vertex_color_use_as_albedo=true;result.roughness=0.94;result.metallic_specular=0.05
	var shade := 0.97+float(posmod(seed_value+role.hash(),7))*0.01
	var tint := Color(shade,shade,shade)
	if look==1: tint=Color(0.94,1.02,1.02)
	elif look==2: tint=Color(1.08,1.00,0.88)
	elif look==3: tint=Color(0.80,0.84,0.73)
	result.albedo_color=tint
	return result
