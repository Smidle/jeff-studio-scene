shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment(){
	vec2 p=(UV-0.5)*2.0;
	ALBEDO=vec3(0.075,0.064,0.025);
	ALPHA=(1.0-smoothstep(0.1,1.0,dot(p,p)))*0.28;
}
