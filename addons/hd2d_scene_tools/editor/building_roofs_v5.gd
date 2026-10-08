@tool
extends RefCounted
## Shape-bearing bands, never a mesh for every tile. Tile detail belongs to the atlas.
const Old=preload("building_roofs.gd")
static func hip(b,c: Vector3,w: float,d: float,rise: float,eave: float) -> void:
	b.mark("curved_hip_roof")
	var x := w/2+eave;var z := d/2+eave;var ridge := maxf(0.3,x-z*0.60)
	var outer := [Vector3(-x,0,z),Vector3(x,0,z),Vector3(x,0,-z),Vector3(-x,0,-z)]
	var inner := [Vector3(-ridge,0,0),Vector3(ridge,0,0),Vector3(ridge,0,0),Vector3(-ridge,0,0)]
	var lift := minf(0.28,rise*0.18)
	for side in 4:
		var axis: Vector3=(outer[(side+1)%4]-outer[side]).normalized()
		for row in 5:
			for col in 6:
				var a := Old.hip_point(c,outer,inner,side,col/6.0,row/5.0,rise,lift)
				var q := Old.hip_point(c,outer,inner,side,(col+1)/6.0,row/5.0,rise,lift)
				var r := Old.hip_point(c,outer,inner,side,(col+1)/6.0,(row+1)/5.0,rise,lift)
				var s := Old.hip_point(c,outer,inner,side,col/6.0,(row+1)/5.0,rise,lift)
				b.roof_face([a,q,r,s],axis,c)
		for col in 6:
			var a := Old.hip_point(c,outer,inner,side,col/6.0,0,rise,lift)
			var q := Old.hip_point(c,outer,inner,side,(col+1)/6.0,0,rise,lift)
			b.beam(a-Vector3.UP*0.13,q-Vector3.UP*0.13,0.18,"wood")
		for row in 5:
			b.beam(Old.hip_point(c,outer,inner,side,0,row/5.0,rise,lift)+Vector3.UP*0.06,Old.hip_point(c,outer,inner,side,0,(row+1)/5.0,rise,lift)+Vector3.UP*0.06,0.17,"roof")
		b.face([c+outer[(side+1)%4]-Vector3.UP*0.03,c+outer[side]-Vector3.UP*0.03,c+inner[side]+Vector3.UP*(rise-0.1),c+inner[(side+1)%4]+Vector3.UP*(rise-0.1)],"wood")
	b.beam(c+Vector3(-ridge-0.14,rise+0.07,0),c+Vector3(ridge+0.14,rise+0.07,0),0.22,"roof")
	for s in [-1,1]: b.beam(c+Vector3(s*ridge,rise+0.08,0),c+Vector3(s*(ridge+0.38),rise+0.34,0),0.16,"roof")

static func gable(b,c: Vector3,w: float,d: float,rise: float,eave: float) -> void:
	b.mark("layered_gable_roof")
	var x := w/2+eave;var z := d/2+eave
	for s in [-1,1]:
		var points := [c+Vector3(0,rise,-z),c+Vector3(s*x,0,-z),c+Vector3(s*x,0,z),c+Vector3(0,rise,z)]
		if s>0: points.reverse()
		b.roof_face(points,Vector3.BACK if s<0 else Vector3.FORWARD,c)
		b.beam(c+Vector3(s*x,-0.08,-z),c+Vector3(s*x,-0.08,z),0.19,"wood")
		for front in [-1,1]: b.beam(c+Vector3(0,rise,front*z),c+Vector3(s*x,-0.06,front*z),0.20,"wood")
		var underside := points.duplicate();underside.reverse()
		for i in underside.size(): underside[i]-=Vector3.UP*0.10
		b.face(underside,"wood")
	for front in [-1,1]:
		var points := [c+Vector3(-w/2,0,front*d/2),c+Vector3(w/2,0,front*d/2),c+Vector3(0,rise,front*d/2)]
		if front<0: points.reverse()
		b.face(points,"wall")
		b.beam(c+Vector3(-w/2,0.05,front*(d/2+0.04)),c+Vector3(w/2,0.05,front*(d/2+0.04)),0.17,"wood")
		for s in [-1,1]: b.beam(c+Vector3(0,0.1,front*(d/2+0.04)),c+Vector3(s*w*0.24,rise*0.48,front*(d/2+0.04)),0.12,"wood")
	b.beam(c+Vector3(0,rise+0.07,-z),c+Vector3(0,rise+0.07,z),0.18,"roof")

static func terrace(b,c: Vector3,w: float,d: float,eave: float) -> void:
	b.mark("parapet_terrace")
	b.box(c+Vector3.UP*0.10,Vector3(w+eave*2,0.2,d+eave*2),"wall")
	for s in [-1,1]:
		b.box(c+Vector3(s*w*0.5,0.42,0),Vector3(0.22,0.64,d+0.18),"wall")
		b.box(c+Vector3(0,0.42,s*d*0.5),Vector3(w,0.64,0.22),"wall")
		b.box(c+Vector3(s*w*0.5,0.76,0),Vector3(0.34,0.12,d+0.35),"stone")
		b.box(c+Vector3(0,0.76,s*d*0.5),Vector3(w+0.32,0.12,0.34),"stone")
