@tool
extends RefCounted
## Exact segment distances within the blend radius, bucketed once per draft.
var buckets := {}
var step := 4.0
func _init(roads: Array,radius: float) -> void:
	step=maxf(4.0,radius*2)
	for road in roads:
		var points: PackedVector3Array=road.points
		for i in range(points.size()-1):
			var a := Vector2(points[i].x,points[i].z);var b := Vector2(points[i+1].x,points[i+1].z)
			var half := float(road.width)*0.5
			var area := Rect2(a,Vector2.ZERO).expand(b).grow(half+radius)
			var lo := Vector2i((area.position/step).floor());var hi := Vector2i((area.end/step).floor())
			for z in range(lo.y,hi.y+1):
				for x in range(lo.x,hi.x+1):
					var key := Vector2i(x,z)
					if not buckets.has(key): buckets[key]=[]
					buckets[key].append([a,b,half])
func sample(p: Vector2) -> Dictionary:
	var distance := INF;var center := p;var nearest_center := INF
	for segment in buckets.get(Vector2i((p/step).floor()),[]):
		var nearest := Geometry2D.get_closest_point_to_segment(p,segment[0],segment[1])
		var d: float=p.distance_to(nearest)-segment[2]
		distance=minf(distance,d)
		if p.distance_squared_to(nearest)<nearest_center: nearest_center=p.distance_squared_to(nearest);center=nearest
	return {"distance":distance,"center":center}
