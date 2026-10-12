shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
void fragment() {
	vec2 p=(floor(UV*12.0)+0.5)/12.0-0.5;
	float r=length(p);
	float ring=step(0.23,r)*(1.0-step(0.40,r));
	ALBEDO=vec3(0.63,0.78,0.88);
	ALPHA=ring*COLOR.a*0.65;
}
