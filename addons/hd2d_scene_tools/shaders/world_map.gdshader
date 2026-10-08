shader_type spatial;
render_mode cull_disabled;
uniform sampler2D layer_0 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D layer_1 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D layer_2 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D layer_3 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D layer_4 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D layer_5 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D layer_6 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D layer_7 : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D layer_8 : source_color, filter_nearest_mipmap, repeat_enable;
uniform float tile_scale = 2.0;
uniform float cloud_strength = 0.12;
uniform bool surface_enabled = true;
varying vec4 extra_weights;
varying float ninth_weight;
varying vec3 world_pos;
void vertex() {
	extra_weights=CUSTOM0;
	ninth_weight=UV2.x;
	world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec2 uv=UV/max(tile_scale,0.01);
	float total=max(dot(COLOR,vec4(1.0))+dot(extra_weights,vec4(1.0))+ninth_weight,0.001);
	vec4 a=COLOR/total;
	vec4 b=extra_weights/total;
	vec3 color=texture(layer_0,uv).rgb*a.x+texture(layer_1,uv).rgb*a.y;
	color+=texture(layer_2,uv).rgb*a.z+texture(layer_3,uv).rgb*a.w;
	color+=texture(layer_4,uv).rgb*b.x+texture(layer_5,uv).rgb*b.y;
	color+=texture(layer_6,uv).rgb*b.z+texture(layer_7,uv).rgb*b.w;
	color+=texture(layer_8,uv).rgb*ninth_weight/total;
	float cloud=smoothstep(0.25,0.9,sin(world_pos.x*0.06+TIME*0.025)*sin(world_pos.z*0.04+TIME*0.018));
	ALBEDO=(surface_enabled?color:vec3(0.45,0.48,0.36))*(1.0-cloud*cloud_strength);
	ROUGHNESS=0.95;
}
