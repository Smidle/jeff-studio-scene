shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D cloud_texture : filter_linear, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float cutoff = 0.5;
uniform float wind_strength = 0.5;
uniform float sway_amount = 0.036;
uniform float cloud_strength = 0.18;
uniform float clock = 0.0;
varying vec3 world_position;
void vertex(){
	vec3 origin=MODEL_MATRIX[3].xyz;
	float sway=sin(clock*1.7+origin.x*0.41+origin.z*0.23);
	VERTEX.x+=sway*max(VERTEX.y,0.0)*sway_amount*wind_strength;
	world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
}
void fragment(){
	vec4 c=texture(albedo_texture,UV)*tint;
	if(c.a<cutoff) discard;
	// Cloud masks often carry information in ALPHA, not RGB.
	float cloud=texture(cloud_texture,world_position.xz*vec2(0.023,0.028)+vec2(clock*0.003,0.21)).a;
	float shade=mix(1.34,0.72,smoothstep(0.08,0.75,cloud));
	ALBEDO=c.rgb*mix(1.0,shade,clamp(cloud_strength/0.18,0.0,2.0));
	ROUGHNESS=1.0;
	EMISSION=c.rgb*0.10;
}
