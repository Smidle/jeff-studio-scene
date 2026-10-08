@tool
class_name HD2DTerrainData
extends Resource
## CPU authoring data is the source of truth; render/collision data is disposable.
@export_range(1, 4096, 0.5) var size_m: float = 256.0
@export_range(3, 513, 1) var resolution: int = 257
@export var heights: PackedFloat32Array
@export var weights: PackedColorArray
@export_range(1, 8, 1) var layer_count: int = 4
@export var weights_extra: PackedColorArray
@export var textures: Array[Texture2D] = []
@export var layer_names: PackedStringArray = []
@export var layer_preset_ids: PackedStringArray = []
@export var colors: PackedColorArray = PackedColorArray([
	Color("77723d"), Color("aa8954"), Color("52652d"), Color("686b72")])
@export_range(0.1, 32) var texture_scale: float = 2.0

func initialize(samples: int = 257, meters: float = 256.0) -> void:
	samples=clampi(samples,3,513)
	resolution = samples
	size_m = clampf(meters,1,4096)
	heights.resize(samples * samples)
	heights.fill(0.0)
	weights.resize(samples * samples)
	weights.fill(Color(1, 0, 0, 0))
	weights_extra=PackedColorArray()
	ensure_extra_weights()
	emit_changed()

func ensure_valid() -> void:
	resolution=clampi(resolution,3,513)
	size_m=clampf(size_m,1,4096)
	layer_count=clampi(layer_count,1,8)
	if heights.size() != resolution * resolution:
		initialize(resolution, size_m)
	if weights.size() != heights.size():
		weights.resize(heights.size())
		weights.fill(Color(1, 0, 0, 0))

	ensure_extra_weights()

func ensure_extra_weights() -> void:
	if layer_count>4 and weights_extra.size()!=weights.size():
		weights_extra.resize(weights.size()); weights_extra.fill(Color(0,0,0,0))

func weight_sample(index: int) -> Variant:
	return [weights[index],weights_extra[index]] if layer_count>4 else weights[index]

func set_weight_sample(index: int, value: Variant) -> void:
	weights[index]=value[0] if value is Array else value
	if value is Array: weights_extra[index]=value[1]

func cell_size() -> float:
	return size_m / float(resolution - 1)

func sample(x: int, z: int) -> float:
	return heights[clampi(z, 0, resolution - 1) * resolution + clampi(x, 0, resolution - 1)]

func height_at(x: float, z: float) -> float:
	var gx := clampf((x + size_m * 0.5) / cell_size(), 0, resolution - 1)
	var gz := clampf((z + size_m * 0.5) / cell_size(), 0, resolution - 1)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - ix
	var fz := gz - iz
	# Same piecewise planar interpolation as the rendered/collision triangles.
	if fx + fz <= 1.0:
		return sample(ix, iz) + fx * (sample(ix+1, iz)-sample(ix, iz)) + fz * (sample(ix, iz+1)-sample(ix, iz))
	return sample(ix+1, iz+1) + (1-fx)*(sample(ix, iz+1)-sample(ix+1, iz+1)) + (1-fz)*(sample(ix+1, iz)-sample(ix+1, iz+1))

func snapshot() -> Dictionary:
	return {"heights": heights.duplicate(), "weights": weights.duplicate(), "weights_extra": weights_extra.duplicate()}

func restore(state: Dictionary) -> void:
	heights = state.heights.duplicate()
	weights = state.weights.duplicate()
	weights_extra=state.get("weights_extra",PackedColorArray()).duplicate()
	ensure_extra_weights()
	emit_changed()

func brush(center: Vector3, radius: float, amount: float, mode: String, layer: int = 0,
		level: float = 0.0, ramp_origin: Vector3 = Vector3.ZERO, originals: Dictionary = {}) -> Rect2i:
	layer=clampi(layer,0,layer_count-1)
	if mode == "ramp" and Vector2(center.x-ramp_origin.x,center.z-ramp_origin.z).length_squared()<0.0001: return Rect2i()
	var step := cell_size()
	var gc := Vector2(center.x, center.z) / step + Vector2.ONE * ((resolution-1)*0.5)
	var r := radius / step
	var lo := Vector2i(maxi(0, int(floor(gc.x-r))), maxi(0, int(floor(gc.y-r))))
	var hi := Vector2i(mini(resolution-1, int(ceil(gc.x+r))), mini(resolution-1, int(ceil(gc.y+r))))
	var ramp_start := Vector2(ramp_origin.x,ramp_origin.z)/step+Vector2.ONE*((resolution-1)*0.5)
	if mode=="ramp":
		lo=Vector2i((gc.min(ramp_start)-Vector2.ONE*r).floor()).max(Vector2i.ZERO)
		hi=Vector2i((gc.max(ramp_start)+Vector2.ONE*r).ceil()).min(Vector2i.ONE*(resolution-1))
	var before := {}
	if mode == "smooth":
		for z in range(maxi(0,lo.y-1),mini(resolution,hi.y+2)):
			for x in range(maxi(0,lo.x-1),mini(resolution,hi.x+2)): before[z*resolution+x]=heights[z*resolution+x]
	for z in range(lo.y, hi.y+1):
		for x in range(lo.x, hi.x+1):
			var nearest := gc
			if mode=="ramp":
				var segment := gc-ramp_start
				nearest=ramp_start+segment*clampf((Vector2(x,z)-ramp_start).dot(segment)/segment.length_squared(),0,1)
			var distance := Vector2(x,z).distance_to(nearest)/maxf(r,0.001)
			if distance > 1.0: continue
			var falloff := 1.0 - smoothstep(0.0, 1.0, distance)
			var index := z*resolution+x
			if not originals.has(index): originals[index]=weight_sample(index) if mode=="paint" else heights[index]
			var blend := 1.0-exp(-maxf(amount,0.0)*falloff)
			match mode:
				"raise": heights[index] += amount*falloff
				"lower": heights[index] -= amount*falloff
				"smooth":
					var mean := 0.0
					for dz in range(-1, 2):
						for dx in range(-1, 2):
							mean += before[clampi(z+dz,0,resolution-1)*resolution+clampi(x+dx,0,resolution-1)] / 9.0
					heights[index] = lerpf(before[index], mean, blend)
				"flatten": heights[index] = lerpf(heights[index], level, blend)
				"ramp":
					var a := Vector2(ramp_origin.x, ramp_origin.z)
					var b := Vector2(center.x, center.z)
					var p := Vector2(x*step-size_m*0.5, z*step-size_m*0.5)
					var t := clampf((p-a).dot(b-a) / maxf((b-a).length_squared(),0.001),0,1)
					heights[index] = lerpf(heights[index], lerpf(ramp_origin.y,level,t), blend)
				"paint":
					var target := Color(0,0,0,0)
					if layer<4: target[clampi(layer,0,3)] = 1.0
					weights[index] = weights[index].lerp(target, blend)
					if layer_count>4:
						target=Color(0,0,0,0)
						if layer>=4: target[clampi(layer-4,0,3)]=1.0
						weights_extra[index]=weights_extra[index].lerp(target,blend)
	return Rect2i(lo, hi-lo+Vector2i.ONE)
