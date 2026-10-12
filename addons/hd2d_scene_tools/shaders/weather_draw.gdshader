shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha, shadows_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform float kind = 1.0;
uniform float size_scale = 1.0;
uniform float flip_speed = 1.0;
uniform float particle_lifetime = 26.0;
uniform float visibility = 1.0;
uniform vec3 light_tint = vec3(1.0);
uniform vec3 fall_velocity = vec3(0.0,-18.0,0.0);
varying vec4 state;
varying float particle_fade;
varying float pose_age;
void vertex() {
	state=INSTANCE_CUSTOM;
	// The process shader stores contact age + 1 in w. Freeze the pose at contact,
	// while the live age continues to drive the existing landing fade and lifetime.
	pose_age=state.w>0.5 ? state.w-1.0 : state.x;
	// Derive opacity from the shared particle age, avoiding renderer-dependent COLOR alpha.
	particle_fade=min(state.x*4.0,clamp((particle_lifetime-state.x)*1.8,0.0,1.0));
	if(state.w>0.5) { particle_fade*=clamp(1.0-(state.x-(state.w-1.0))/1.5,0.0,1.0); }
	// Godot collapses inactive particle bases; manual billboarding must honor that mask.
	particle_fade*=step(0.0001,dot(MODEL_MATRIX[0].xyz,MODEL_MATRIX[0].xyz));
	float size = (0.75+state.z*0.5)*size_scale;
	float angle = kind>2.5 ? sin(pose_age*1.2+state.z*30.0)*0.55 + state.z*1.8-0.9 : 0.0;
	vec2 point=mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle)))*VERTEX.xy*size;
	vec3 right=INV_VIEW_MATRIX[0].xyz;
	vec3 up=INV_VIEW_MATRIX[1].xyz;
	if (kind<1.5) {
		vec2 motion=(VIEW_MATRIX*vec4(fall_velocity,0.0)).xy;
		vec2 axis=length(motion)>0.001 ? -normalize(motion) : vec2(0.0,1.0);
		up=INV_VIEW_MATRIX[0].xyz*axis.x+INV_VIEW_MATRIX[1].xyz*axis.y;
		right=INV_VIEW_MATRIX[0].xyz*axis.y-INV_VIEW_MATRIX[1].xyz*axis.x;
	}
	vec3 origin=MODEL_MATRIX[3].xyz;
	if (state.w>0.5) { up=-MODEL_MATRIX[2].xyz;right=MODEL_MATRIX[0].xyz;origin+=MODEL_MATRIX[1].xyz*0.02; }
	POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(origin+right*point.x+up*point.y,1.0);
}
void fragment() {
	vec4 ink;
	if (kind>2.5) {
		float frame=mod(floor(pose_age*6.0*flip_speed*(0.8+state.z*0.4)+state.z*8.0),8.0);
		ink=texture(atlas,(UV+vec2(frame,state.y))/vec2(8.0,3.0));
	} else if(kind>1.5) {
		vec2 cell=floor(UV*7.0);
		float shape=float((abs(cell.x-3.0)<1.0 || abs(cell.y-3.0)<1.0) && length(cell-vec2(3.0))<3.5);
		ink=vec4(vec3(0.91,0.96,1.0),shape);
	} else {
		ink=vec4(0.68,0.82,0.96,float(UV.x>0.28 && UV.x<0.72));
	}
	ALBEDO=ink.rgb*light_tint;
	ALPHA=ink.a*particle_fade*visibility;
	ALPHA_SCISSOR_THRESHOLD=0.16;
}
