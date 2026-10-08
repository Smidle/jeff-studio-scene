shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform sampler2D control_texture : filter_linear, repeat_disable;
uniform sampler2D base_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D soil0 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D soil1 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D soil2 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D soil3 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D cloud_texture : filter_linear, repeat_enable;
uniform float clock = 0.0;
uniform float cloud_strength = 0.18;
uniform bool heightfield_uv = false;
uniform vec4 uv_world_rect = vec4(-40.0,-66.7418,80.0,95.6836);
varying vec3 world_position;
void vertex(){ world_position=(MODEL_MATRIX*vec4(VERTEX,1)).xyz; }
float soft_cloud(vec2 uv){
	vec2 r=vec2(0.025);
	return (texture(cloud_texture,uv).a*4.0+texture(cloud_texture,uv+vec2(r.x,0)).a*2.0+texture(cloud_texture,uv-vec2(r.x,0)).a*2.0+texture(cloud_texture,uv+vec2(0,r.y)).a*2.0+texture(cloud_texture,uv-vec2(0,r.y)).a*2.0+texture(cloud_texture,uv+r).a+texture(cloud_texture,uv-r).a+texture(cloud_texture,uv+vec2(r.x,-r.y)).a+texture(cloud_texture,uv+vec2(-r.x,r.y)).a)/16.0;
}
void fragment(){
	vec2 uv=heightfield_uv?vec2(1.0)-(world_position.xz-uv_world_rect.xy)/uv_world_rect.zw:UV;
	vec4 weights=texture(control_texture,uv);
	vec3 base=texture(base_texture,uv*vec2(50.0,30.0)).rgb;
	vec3 c0=texture(soil0,uv*vec2(70.0,50.0)+vec2(0.95,0)).rgb*vec3(1.0,0.9354,0.8349);
	vec3 c1=texture(soil1,uv*vec2(40.0,60.0)).rgb*vec3(1.0,0.9591,0.7877);
	vec3 c2=texture(soil2,uv*vec2(40.0,30.0)).rgb*vec3(0.8169,1.0,0.3725);
	vec3 c3=texture(soil3,uv*vec2(40.0,30.0)+vec2(0.67,0)).rgb*vec3(1.0,0.9435,0.7783);
	vec3 c=mix(base,c0,weights.r); c=mix(c,c1,weights.g); c=mix(c,c2,weights.b); c=mix(c,c3,weights.a);
	if(heightfield_uv){ c=c*COLOR.r+c0*COLOR.g+c1*COLOR.b+c2*COLOR.a; }
	float cloud=soft_cloud(world_position.xz*vec2(0.023,0.028)+vec2(clock*0.003,0.21));
	float shade=mix(1.42,0.53,smoothstep(0.05,0.9,cloud));
	ALBEDO=c*mix(1.0,shade,clamp(cloud_strength/0.18,0.0,2.0))*vec3(1.27,1.24,1.18);
	ROUGHNESS=1.0;
}
