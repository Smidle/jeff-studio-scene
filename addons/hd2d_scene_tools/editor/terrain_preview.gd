@tool
extends VBoxContainer
## Isolated, event-driven preview: no source scene nodes or collisions.
var original: TextureRect
var repeat_view: TextureRect
var viewport: SubViewport
var surface: MeshInstance3D
var preview_material: ShaderMaterial
var enlarge: Button
var viewer: Window
var large_image: TextureRect
var lighting: OptionButton
var display_count := 4
var lit_shader: Shader

func _init() -> void:
	var images := HBoxContainer.new(); add_child(images)
	for i in range(2):
		var texture := TextureRect.new()
		texture.custom_minimum_size=Vector2(96,96)
		texture.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		texture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		images.add_child(texture)
		if i==0: original=texture
		else: repeat_view=texture
	var shader := Shader.new()
	shader.code="shader_type canvas_item; uniform sampler2D tile : source_color, filter_nearest, repeat_enable; void fragment(){ COLOR=texture(tile,fract(UV*3.0)); }"
	var repeated := ShaderMaterial.new(); repeated.shader=shader
	repeat_view.material=repeated
	enlarge=Button.new(); enlarge.text="放大原图…"; add_child(enlarge)
	viewer=Window.new(); viewer.visible=false; viewer.title="地表纹理原图"; viewer.size=Vector2i(680,680); add_child(viewer)
	large_image=TextureRect.new(); large_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	large_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; large_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	large_image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; viewer.add_child(large_image)
	viewer.close_requested.connect(viewer.hide)
	enlarge.pressed.connect(func(): large_image.texture=original.texture; viewer.popup_centered())
	lighting=OptionButton.new(); lighting.add_item("柔和光照预览"); lighting.add_item("原色预览（无光照）"); add_child(lighting)
	lighting.item_selected.connect(func(_i): update_lighting())
	var container := SubViewportContainer.new(); container.custom_minimum_size=Vector2(180,145)
	container.stretch=true; add_child(container)
	viewport=SubViewport.new(); viewport.size=Vector2i(320,200); viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED; container.add_child(viewport)
	var environment := WorldEnvironment.new(); environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("27313b")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=0.35
	viewport.add_child(environment)
	var light := DirectionalLight3D.new(); light.light_energy=0.65; light.rotation_degrees=Vector3(-55,-25,0); viewport.add_child(light)
	var camera := Camera3D.new(); camera.position=Vector3(7,9,11); viewport.add_child(camera)
	camera.look_at_from_position(camera.position,Vector3.ZERO); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=15
	surface=MeshInstance3D.new(); viewport.add_child(surface)
	build_surface(4)

func build_surface(count: int) -> void:
	display_count=count
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if count>4: st.set_custom_format(0,SurfaceTool.CUSTOM_RGBA_FLOAT)
	for z in range(24):
		for x in range(24):
			for offset in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var p: Vector2=(Vector2(x,z)+offset)/24.0
				var weights := Color(0,0,0,0); var extra := Color(0,0,0,0)
				var mix_position: float=p.x*float(count-1)
				var first := mini(int(mix_position),count-1); var second := mini(first+1,count-1)
				var fraction := mix_position-first
				var ninth := 0.0
				if first<4: weights[first]+=1-fraction
				elif first<8: extra[first-4]+=1-fraction
				else: ninth+=1-fraction
				if second<4: weights[second]+=fraction
				elif second<8: extra[second-4]+=fraction
				else: ninth+=fraction
				if count>4: st.set_custom(0,extra)
				if count==9: st.set_uv2(Vector2(ninth,0))
				st.set_color(weights); st.set_uv(p*12.0)
				st.add_vertex(Vector3((p.x-0.5)*12,sin(p.x*PI)*sin(p.y*PI)*1.6,(p.y-0.5)*12))
	st.generate_normals(); surface.mesh=st.commit()

func display(textures: Array, colors: PackedColorArray, period: float, selected: int=0, source: ShaderMaterial=null) -> void:
	var count := clampi(textures.size(),1,9)
	if count!=display_count: build_surface(count)
	var texture: Texture2D=textures[selected] if textures.size()>selected else null
	original.texture=texture; repeat_view.texture=texture
	enlarge.disabled=texture==null
	(repeat_view.material as ShaderMaterial).set_shader_parameter("tile",texture)
	preview_material=source.duplicate() as ShaderMaterial if source else ShaderMaterial.new()
	if source:
		for i in range(mini(textures.size(),4)):
			if textures[i]: preview_material.set_shader_parameter("soil%d"%i,textures[i])
	else:
		preview_material.shader=preload("../shaders/world_map.gdshader") if count==9 else (preload("../shaders/terrain_8.gdshader") if count>4 else preload("../shaders/terrain.gdshader"))
		var flags := Vector4.ZERO; var extra := Vector4.ZERO
		for i in range(9 if count==9 else (8 if count>4 else 4)):
			preview_material.set_shader_parameter("tint_%d"%i,colors[i] if colors.size()>i else Color.WHITE)
			if textures.size()>i and textures[i]:
				preview_material.set_shader_parameter("layer_%d"%i,textures[i])
				if i<4: flags[i]=1
				elif i<8: extra[i-4]=1
		preview_material.set_shader_parameter("has_texture",flags)
		if count>4: preview_material.set_shader_parameter("has_texture_extra",extra)
		preview_material.set_shader_parameter("tile_scale",period)
		preview_material.set_shader_parameter("cloud_strength",0.0)
	surface.material_override=preview_material
	lit_shader=preview_material.shader
	update_lighting()

func update_lighting() -> void:
	if not preview_material or not lit_shader: return
	if lighting.selected==1:
		var shader := Shader.new()
		shader.code=lit_shader.code.replace("render_mode cull_disabled;","render_mode cull_disabled, unshaded;")
		preview_material.shader=shader
	else: preview_material.shader=lit_shader
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
