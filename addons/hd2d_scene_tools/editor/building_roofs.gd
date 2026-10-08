@tool
extends RefCounted
## Original roof construction: broad silhouettes, tile courses, fascia and ridge ends.
static func hip_point(c: Vector3, outer: Array, inner: Array, side: int, u: float, t: float, rise: float, lift: float) -> Vector3:
	var a: Vector3=outer[side].lerp(outer[(side+1)%4],u)
	var z: Vector3=inner[side].lerp(inner[(side+1)%4],u)
	var p := a.lerp(z,t)
	p.y=rise*(0.6*t+0.4*t*t)+lift*pow(1.0-t,6)+lift*0.4*pow(absf(u*2-1),4)*(1-t)
	return c+p

static func hip(b, c: Vector3, w: float, d: float, rise: float, eave: float, detailed: bool=true) -> void:
	b.mark("curved_hip_roof")
	var x := w*0.5+eave;var z := d*0.5+eave
	var outer := [Vector3(-x,0,z),Vector3(x,0,z),Vector3(x,0,-z),Vector3(-x,0,-z)]
	var ridge := maxf(0.25,x-z*0.65)
	var inner := [Vector3(-ridge,0,0),Vector3(ridge,0,0),Vector3(ridge,0,0),Vector3(-ridge,0,0)]
	var lift := minf(0.25,rise*0.16)
	for side in 4:
		var columns := clampi(ceili(outer[side].distance_to(outer[(side+1)%4])/0.3),2,42)
		var rows := clampi(ceili(sqrt(z*z+rise*rise)/0.4),3,20)
		for row in rows:
			for col in columns:
				var a := hip_point(c,outer,inner,side,float(col)/columns,float(row)/rows,rise,lift)
				var q := hip_point(c,outer,inner,side,float(col+1)/columns,float(row)/rows,rise,lift)
				var r := hip_point(c,outer,inner,side,float(col+1)/columns,float(row+1)/rows,rise,lift)
				var s := hip_point(c,outer,inner,side,float(col)/columns,float(row+1)/rows,rise,lift)
				var tint := Color.WHITE.darkened(float((col*7+row*13+side)%7)*0.018)
				b.face([a,q,r,s],"roof",tint)
				if detailed:
					b.face([a-Vector3.UP*0.05,q-Vector3.UP*0.05,q,a],"roof",tint.darkened(0.13))
					# Narrow raised cover tiles follow the curved slope.
					if col%2==0 and row<rows-1: b.beam(a+Vector3.UP*0.027,s+Vector3.UP*0.027,0.04,"roof",0.035)
		for col in columns:
			var a := hip_point(c,outer,inner,side,float(col)/columns,0,rise,lift)
			var z0 := hip_point(c,outer,inner,side,float(col+1)/columns,0,rise,lift)
			b.beam(a-Vector3.UP*0.10,z0-Vector3.UP*0.10,0.14,"wood")
		for row in rows:
			b.beam(hip_point(c,outer,inner,side,0,float(row)/rows,rise,lift)+Vector3.UP*0.08,hip_point(c,outer,inner,side,0,float(row+1)/rows,rise,lift)+Vector3.UP*0.08,0.16,"roof")
		# Opaque underside closes the overhang silhouette.
		var underside := [c+outer[(side+1)%4]-Vector3.UP*0.03,c+outer[side]-Vector3.UP*0.03,c+inner[side]+Vector3.UP*(rise-0.08),c+inner[(side+1)%4]+Vector3.UP*(rise-0.08)]
		b.face(underside,"wood")
	b.beam(c+Vector3(-ridge-0.12,rise+0.08,0),c+Vector3(ridge+0.12,rise+0.08,0),0.22,"roof")
	for sign_value in [-1,1]:
		var end := c+Vector3(sign_value*(ridge+0.05),rise+0.15,0)
		b.beam(end,end+Vector3(sign_value*0.25,0.22,0),0.15,"roof")
		b.box(end+Vector3(sign_value*0.2,0.26,0),Vector3(0.14,0.15,0.2),"trim")

static func gable(b, c: Vector3, w: float, d: float, rise: float, eave: float, detailed: bool=true) -> void:
	b.mark("layered_gable_roof")
	var x := w*0.5+eave;var z := d*0.5+eave
	for side in [-1,1]:
		var rows := clampi(ceili(sqrt(x*x+rise*rise)/0.42),2,24)
		var columns := clampi(ceili(z*2/0.38),2,40)
		for row in rows:
			var t0 := float(row)/rows;var t1 := float(row+1)/rows
			for col in columns:
				var z0 := -z+2*z*col/columns;var z1 := -z+2*z*(col+1)/columns
				var a := c+Vector3(side*x*t0,rise*(1-t0),z0)
				var q := c+Vector3(side*x*t1,rise*(1-t1),z0)
				var r := c+Vector3(side*x*t1,rise*(1-t1),z1)
				var s := c+Vector3(side*x*t0,rise*(1-t0),z1)
				var pts := [a,q,r,s]
				if side>0: pts.reverse()
				var tint := Color.WHITE.darkened(float((row*11+col*3)%6)*0.023)
				b.face(pts,"roof",tint)
				if detailed: b.face([q-Vector3.UP*0.055,r-Vector3.UP*0.055,r,q] if side<0 else [r-Vector3.UP*0.055,q-Vector3.UP*0.055,q,r],"roof",tint.darkened(0.2))
		b.beam(c+Vector3(side*x,-0.04,-z),c+Vector3(side*x,-0.04,z),0.18,"wood")
		for front in [-1,1]:
			b.beam(c+Vector3(0,rise,front*z),c+Vector3(side*x,-0.06,front*z),0.20,"wood")
			b.beam(c+Vector3(0,rise+0.05,front*(z+0.01)),c+Vector3(side*x,0,front*(z+0.01)),0.055,"trim")
		b.face([c+Vector3(0,rise-0.09,z),c+Vector3(side*x,-0.09,z),c+Vector3(side*x,-0.09,-z),c+Vector3(0,rise-0.09,-z)] if side<0 else [c+Vector3(0,rise-0.09,-z),c+Vector3(side*x,-0.09,-z),c+Vector3(side*x,-0.09,z),c+Vector3(0,rise-0.09,z)],"wood")
	for front in [-1,1]:
		var pts := [c+Vector3(-w*0.5,0,front*d*0.5),c+Vector3(w*0.5,0,front*d*0.5),c+Vector3(0,rise,front*d*0.5)]
		if front<0: pts.reverse()
		b.face(pts,"wall")
		b.beam(c+Vector3(-w*0.5,0.03,front*(d*0.5+0.03)),c+Vector3(w*0.5,0.03,front*(d*0.5+0.03)),0.18,"wood")
		b.beam(c+Vector3(0,0,front*(d*0.5+0.04)),c+Vector3(0,rise-0.1,front*(d*0.5+0.04)),0.16,"wood")
		for side in [-1,1]: b.beam(c+Vector3(0,0.08,front*(d*0.5+0.05)),c+Vector3(side*w*0.26,rise*0.44,front*(d*0.5+0.05)),0.10,"wood")
	b.beam(c+Vector3(0,rise+0.08,-z-0.04),c+Vector3(0,rise+0.08,z+0.04),0.22,"roof")

static func terrace(b, c: Vector3, w: float, d: float, eave: float) -> void:
	b.mark("parapet_terrace")
	b.box(c+Vector3.UP*0.10,Vector3(w+eave*2,0.2,d+eave*2),"roof")
	for s in [-1,1]:
		b.box(c+Vector3(s*w*0.5,0.42,0),Vector3(0.22,0.64,d+0.18),"wall")
		b.box(c+Vector3(0,0.42,s*d*0.5),Vector3(w,0.64,0.22),"wall")
		b.box(c+Vector3(s*w*0.5,0.76,0),Vector3(0.34,0.12,d+0.35),"trim")
		b.box(c+Vector3(0,0.76,s*d*0.5),Vector3(w+0.32,0.12,0.34),"trim")
		for x in [-1,1]:
			b.box(c+Vector3(x*w*0.5,0.78,s*d*0.5),Vector3(0.43,0.30,0.43),"stone")
