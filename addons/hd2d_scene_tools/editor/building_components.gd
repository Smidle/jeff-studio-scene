@tool
extends RefCounted
## Components are authored in a front-facing local frame (+Z), reusable on every facade.
static func window(b, c: Vector3, w: float, h: float, style: String, variant: int) -> void:
	b.mark("layered_window")
	b.box(c,Vector3(w+0.16,h+0.16,0.06),"shadow")
	b.box(c+Vector3(0,0,0.042),Vector3(w-0.13,h-0.13,0.03),"glass")
	b.panel_frame(c+Vector3(0,0,0.11),w,h,0.12,"stone" if style=="desert" else "wood")
	b.box(c+Vector3(0,-h*0.5-0.10,0.13),Vector3(w+0.36,0.14,0.34),"stone" if style=="desert" else "trim")
	b.box(c+Vector3(0,h*0.5+0.10,0.11),Vector3(w+0.28,0.12,0.23),"trim")
	if style=="jiangnan":
		for s in [-1,0,1]: b.box(c+Vector3(s*w*0.24,0,0.14),Vector3(0.036,h-0.1,0.04),"wood")
		for yy in [-0.28,0,0.28]: b.box(c+Vector3(0,yy*h,0.15),Vector3(w-0.1,0.035,0.04),"wood")
		if variant%2==0:
			var r := minf(w,h)*0.24
			for i in 4:
				var a := PI*0.5*i
				b.beam(c+Vector3(sin(a)*r,cos(a)*r,0.18),c+Vector3(sin(a+PI/2)*r,cos(a+PI/2)*r,0.18),0.035,"trim")
	elif style=="forest":
		b.box(c+Vector3(0,0,0.16),Vector3(0.06,h-0.10,0.05),"wood")
		b.box(c+Vector3(0,0.02,0.16),Vector3(w-0.1,0.06,0.05),"wood")
		for s in [-1,1]:
			var shutter := c+Vector3(s*(w*0.5+0.22),0,0.08)
			b.box(shutter,Vector3(0.26,h,0.08),"accent")
			for yy in [-0.32,0.32]: b.box(shutter+Vector3(0,h*yy,0.06),Vector3(0.29,0.06,0.05),"wood")
			b.beam(shutter+Vector3(-0.08,-h*0.3,0.055),shutter+Vector3(0.08,h*0.3,0.055),0.04,"trim")
	else:
		for s in [-1,0,1]: b.box(c+Vector3(s*w*0.23,0,0.16),Vector3(0.035,h-0.1,0.05),"wood")
		for yy in [-0.28,0.28]: b.box(c+Vector3(0,yy*h,0.16),Vector3(w-0.1,0.04,0.05),"wood")
		b.box(c+Vector3(0,h*0.5+0.22,0.12),Vector3(w*0.65,0.10,0.12),"accent")

static func door(b, c: Vector3, style: String, variant: int) -> void:
	b.mark("framed_door")
	var w := 1.24;var h := 2.04
	b.box(c+Vector3(0,h*0.5,0.03),Vector3(w+0.18,h+0.16,0.07),"shadow")
	if style=="desert":
		var radius := w*0.5;var spring := h-radius
		var outline := [c+Vector3(-radius,0,0.12),c+Vector3(radius,0,0.12)]
		for i in range(9): outline.append(c+Vector3(cos(PI*i/8)*radius,spring+sin(PI*i/8)*radius,0.12))
		b.face(outline,"wood")
		for i in 8:
			var a := PI*i/8;var z := PI*(i+1)/8
			b.beam(c+Vector3(cos(a)*(radius+0.10),spring+sin(a)*(radius+0.10),0.19),c+Vector3(cos(z)*(radius+0.10),spring+sin(z)*(radius+0.10),0.19),0.21,"stone")
		for s in [-1,1]: b.box(c+Vector3(s*(radius+0.1),spring*0.5,0.17),Vector3(0.20,spring,0.20),"stone")
	else:
		b.box(c+Vector3(0,h*0.5,0.095),Vector3(w,h,0.08),"wood")
		b.panel_frame(c+Vector3(0,h*0.5,0.19),w+0.10,h+0.04,0.17,"wood")
		b.box(c+Vector3(0,h+0.16,0.18),Vector3(w+0.55,0.16,0.24),"trim")
	for s in [-1,1]:
		b.panel_frame(c+Vector3(s*w*0.25,0.65,0.16),w*0.32,0.92,0.055,"trim")
		b.box(c+Vector3(s*0.11,1.0,0.23),Vector3(0.065,0.15,0.08),"metal")
		if style=="jiangnan":
			b.box(c+Vector3(s*w*0.25,1.64,0.15),Vector3(w*0.34,0.5,0.06),"glass")
			for x in [-1,0,1]: b.box(c+Vector3(s*w*0.25+x*0.12,1.64,0.20),Vector3(0.035,0.54,0.04),"wood")
		elif style=="forest":
			for y in [0.35,1.65]: b.box(c+Vector3(s*0.39,y,0.19),Vector3(0.37,0.055,0.04),"metal")
	if variant%2==1 and style=="forest": b.beam(c+Vector3(-0.46,0.28,0.20),c+Vector3(0.46,1.75,0.20),0.09,"trim")

static func rail(b, a: Vector3, z: Vector3, h: float, style: String) -> void:
	b.mark("balustrade")
	b.beam(a+Vector3.UP*h,z+Vector3.UP*h,0.11,"wood")
	b.beam(a+Vector3.UP*0.16,z+Vector3.UP*0.16,0.10,"wood")
	var count := maxi(2,ceili(a.distance_to(z)/0.40))
	for i in range(count+1): b.beam(a.lerp(z,float(i)/count),a.lerp(z,float(i)/count)+Vector3.UP*h,0.055 if i%3 else 0.10,"wood")
	if style=="jiangnan":
		for i in range(0,count,2):
			var q := a.lerp(z,float(i)/count)+Vector3.UP*0.30
			var r := a.lerp(z,float(mini(i+2,count))/count)+Vector3.UP*0.64
			b.beam(q,r,0.038,"trim")

static func lantern(b, c: Vector3, style: String) -> void:
	b.mark("lantern")
	b.beam(c+Vector3(0,0.45,-0.28),c+Vector3(0,0.45,0),0.06,"metal")
	b.beam(c+Vector3(0,0.45,0),c+Vector3(0,0.24,0),0.035,"metal")
	b.cylinder(c,0.17,0.40,"accent" if style=="jiangnan" else "glass",8)
	for y in [-0.24,0.24]: b.cylinder(c+Vector3.UP*y,0.20,0.07,"wood",8)
	for i in 4:
		var offset := Vector3(cos(i*PI/2)*0.16,0,sin(i*PI/2)*0.16)
		b.beam(c+offset-Vector3.UP*0.20,c+offset+Vector3.UP*0.20,0.025,"trim")
	if style=="jiangnan": b.beam(c-Vector3.UP*0.27,c-Vector3.UP*0.49,0.035,"accent")

static func planter(b, c: Vector3, w: float) -> void:
	b.box(c,Vector3(w,0.21,0.29),"wood")
	b.box(c+Vector3.UP*0.115,Vector3(w-0.09,0.035,0.21),"shadow")
	for i in maxi(2,ceili(w/0.16)):
		var x := -w*0.40+i*0.16
		b.box(c+Vector3(x,0.21,0),Vector3(0.15,0.16+(i%3)*0.04,0.19),"accent")

static func signboard(b, c: Vector3, w: float, style: String) -> void:
	b.mark("shop_sign")
	b.box(c,Vector3(w,0.42,0.11),"wood")
	b.panel_frame(c+Vector3(0,0,0.07),w-0.08,0.33,0.045,"trim")
	# Geometric shop emblem, not fake lettering or borrowed artwork.
	for i in 3:
		var x := (i-1)*w*0.22
		b.box(c+Vector3(x,0,0.08),Vector3(0.10,0.19,0.035),"accent" if style=="desert" else "trim")
