@tool
class_name HD2DTerrain
extends Node3D
## 32-cell chunks; shared-edge normals read the same global height buffer.
const CHUNK := 32
@export var data: HD2DTerrainData:
	set(value):
		if data and data.changed.is_connected(_data_changed): data.changed.disconnect(_data_changed)
		data = value
		if data: data.changed.connect(_data_changed)
		if is_inside_tree(): rebuild.call_deferred()
var chunks: Dictionary = {}
@export var surface_material: ShaderMaterial
var material: ShaderMaterial
var _queued := false
var _material_source: ShaderMaterial
var _material_layers := 4
var rebuild_count := 0
var chunk_build_count := 0
var collision_build_count := 0
var weight_update_count := 0

func _ready() -> void:
	if data == null: data = HD2DTerrainData.new()
	data.ensure_valid()
	rebuild()

func _data_changed() -> void:
	if not _queued and is_inside_tree():
		_queued = true
		rebuild.call_deferred()

func rebuild() -> void:
	_queued = false
	if not is_inside_tree() or data == null: return
	data.ensure_valid()
	rebuild_count+=1
	for child in get_children():
		remove_child(child)
		child.queue_free()
	chunks.clear()
	update_material()
	for z in range(0, data.resolution-1, CHUNK):
		for x in range(0, data.resolution-1, CHUNK): _build_chunk(Vector2i(x/CHUNK,z/CHUNK))
	update_gizmos()

func update_material() -> void:
	if data==null: return
	if surface_material:
		if _material_source!=surface_material or material==null:
			material=surface_material.duplicate() as ShaderMaterial
			_material_source=surface_material
		for i in range(mini(data.textures.size(),4)):
			if data.textures[i]: material.set_shader_parameter("soil%d"%i,data.textures[i])
	else:
		if material==null or _material_source!=null or _material_layers!=data.layer_count:
			material=ShaderMaterial.new()
			material.shader=preload("../shaders/terrain_8.gdshader") if data.layer_count>4 else preload("../shaders/terrain.gdshader")
			_material_layers=data.layer_count
		_material_source=null
		var flags := Vector4.ZERO
		var extra_flags := Vector4.ZERO
		var pixel_flags := Vector4.ZERO;var pixel_extra := Vector4.ZERO
		for i in range(8 if data.layer_count>4 else 4):
			material.set_shader_parameter("tint_%d"%i,data.colors[i] if data.colors.size()>i else Color.WHITE)
			var texture: Texture2D=data.textures[i] if data.textures.size()>i else null
			material.set_shader_parameter("layer_%d"%i,texture)
			if texture and texture.resource_name.begins_with("Jeff/v1/"):
				if i<4: pixel_flags[i]=1
				else: pixel_extra[i-4]=1
			if i<4: flags[i]=1 if texture else 0
			else: extra_flags[i-4]=1 if texture else 0
		material.set_shader_parameter("pixel_layers",pixel_flags)
		material.set_shader_parameter("pixel_layers_extra",pixel_extra)
		material.set_shader_parameter("has_texture",flags)
		if data.layer_count>4: material.set_shader_parameter("has_texture_extra",extra_flags)
		material.set_shader_parameter("tile_scale",data.texture_scale)
	for node in chunks.values(): node.material_override=material

func rebuild_region(rect: Rect2i, collision: bool = true) -> void:
	var lo := (rect.position-Vector2i.ONE).max(Vector2i.ZERO)
	var hi := (rect.end+Vector2i.ONE).min(Vector2i.ONE*(data.resolution-2))
	for z in range(lo.y/CHUNK, hi.y/CHUNK+1):
		for x in range(lo.x/CHUNK, hi.x/CHUNK+1): _build_chunk(Vector2i(x,z), collision)

func _build_chunk(key: Vector2i, collision: bool = true) -> void:
	chunk_build_count+=1
	var start := key*CHUNK
	var count := mini(CHUNK, data.resolution-1-start.x)
	var depth := mini(CHUNK, data.resolution-1-start.y)
	var stride := count+1
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var extra := PackedFloat32Array()
	var indices := PackedInt32Array()
	var step := data.cell_size()
	for dz in range(depth+1):
		for dx in range(stride):
			var x := start.x+dx
			var z := start.y+dz
			vertices.append(Vector3(x*step-data.size_m*0.5,data.sample(x,z),z*step-data.size_m*0.5))
			normals.append(Vector3(data.sample(x-1,z)-data.sample(x+1,z),2*step,data.sample(x,z-1)-data.sample(x,z+1)).normalized())
			uvs.append(Vector2(x*step,z*step))
			colors.append(data.weights[z*data.resolution+x])
			if data.layer_count>4:
				var w := data.weights_extra[z*data.resolution+x]
				extra.append_array(PackedFloat32Array([w.r,w.g,w.b,w.a]))
	for z in range(depth):
		for x in range(count):
			var a := z*stride+x
			indices.append_array(PackedInt32Array([a,a+1,a+stride,a+1,a+stride+1,a+stride]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	var flags := Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE
	if data.layer_count>4:
		arrays[Mesh.ARRAY_CUSTOM0]=extra
		flags|=Mesh.ARRAY_CUSTOM_RGBA_FLOAT<<Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	var node: MeshInstance3D
	if chunks.has(key): node = chunks[key]
	else:
		node = MeshInstance3D.new()
		node.name = "Chunk_%d_%d" % [key.x,key.y]
		add_child(node)
		chunks[key] = node
		node.material_override = material
		var body := StaticBody3D.new()
		body.name = "GroundCollision"
		node.add_child(body)
		var shape := CollisionShape3D.new()
		body.add_child(shape)
	node.mesh = mesh
	if collision:
		var shape: CollisionShape3D = node.get_child(0).get_child(0)
		shape.shape = mesh.create_trimesh_shape()
		collision_build_count+=1

func region_keys(rect: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i]=[]
	if not rect.has_area(): return result
	var lo := (rect.position-Vector2i.ONE).max(Vector2i.ZERO)
	var hi := (rect.end+Vector2i.ONE).min(Vector2i.ONE*(data.resolution-2))
	for z in range(lo.y/CHUNK,hi.y/CHUNK+1):
		for x in range(lo.x/CHUNK,hi.x/CHUNK+1): result.append(Vector2i(x,z))
	return result

func update_collision_region(rect: Rect2i) -> void:
	for key in region_keys(rect):
		if not chunks.has(key): continue
		var node: MeshInstance3D=chunks[key]
		var shape: CollisionShape3D=node.get_child(0).get_child(0)
		shape.shape=node.mesh.create_trimesh_shape()
		collision_build_count+=1

func update_weights_region(rect: Rect2i) -> void:
	for key in region_keys(rect):
		if not chunks.has(key): continue
		var mesh: ArrayMesh=chunks[key].mesh
		var format := mesh.surface_get_format(0)
		var count := mesh.surface_get_array_len(0)
		var stride := RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
		var color_offset := RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_COLOR)
		var uv_offset := RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_TEX_UV)
		var extra_offset := RenderingServer.mesh_surface_get_format_offset(format,count,Mesh.ARRAY_CUSTOM0) if data.layer_count>4 else 0
		var bytes := PackedByteArray(); bytes.resize(stride*count)
		var start := key*CHUNK
		var side := mini(CHUNK,data.resolution-1-start.x)+1
		for j in range(count):
			var x := start.x+j%side
			var z := start.y+j/side
			var color := data.weights[z*data.resolution+x]
			for c in range(4): bytes[j*stride+color_offset+c]=clampi(roundi(color[c]*255.0),0,255)
			bytes.encode_float(j*stride+uv_offset,x*data.cell_size())
			bytes.encode_float(j*stride+uv_offset+4,z*data.cell_size())
			if data.layer_count>4:
				var w := data.weights_extra[z*data.resolution+x]
				for c in range(4): bytes.encode_float(j*stride+extra_offset+c*4,w[c])
		mesh.surface_update_attribute_region(0,0,bytes)
		weight_update_count+=1

func world_height(x: float, z: float) -> float:
	var p := to_local(Vector3(x, global_position.y,z))
	return to_global(Vector3(p.x,data.height_at(p.x,p.z),p.z)).y

func raycast(origin: Vector3, direction: Vector3) -> Variant:
	# CPU raycast also works before a new collision shape reaches the physics server.
	var o := to_local(origin)
	var d := global_basis.inverse()*direction
	var previous := o
	var step := maxf(data.cell_size()*0.45,0.15)
	for i in range(1, int(maxf(1600.0,data.size_m*3+o.length())/step)):
		var p := o+d*(i*step)
		if absf(p.x)<=data.size_m*0.5 and absf(p.z)<=data.size_m*0.5:
			if p.y<=data.height_at(p.x,p.z):
				var a := previous
				var b := p
				for j in range(10):
					var middle := (a+b)*0.5
					if middle.y>data.height_at(middle.x,middle.z): a=middle
					else: b=middle
				return to_global((a+b)*0.5)
		previous=p
	return null
