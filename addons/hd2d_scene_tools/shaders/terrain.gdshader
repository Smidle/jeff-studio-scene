shader_type spatial;
render_mode cull_disabled;
uniform sampler2D layer_0 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D layer_1 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D layer_2 : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D layer_3 : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint_0 : source_color = vec4(0.45,0.45,0.22,1);
uniform vec4 tint_1 : source_color = vec4(0.7,0.55,0.32,1);
uniform vec4 tint_2 : source_color = vec4(0.3,0.4,0.15,1);
uniform vec4 tint_3 : source_color = vec4(0.4,0.4,0.42,1);
uniform vec4 has_texture = vec4(0);
uniform float tile_scale = 2.0;
uniform float cloud_strength = 0.15;
uniform float cloud_speed = 0.15;
uniform float travel = 0.0;
varying vec3 world_pos;
void vertex(){ world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
uniform vec4 pixel_layers = vec4(0);
uniform vec4 pixel_layers_extra = vec4(0);
vec2 pixel_uv(vec2 uv, vec2 size, float on){ return mix(uv,(floor(uv*size)+0.5)/size,on); }
void fragment(){
	vec2 uv=(UV+vec2(travel,0))/tile_scale;
	vec4 w=COLOR/max(dot(COLOR,vec4(1)),0.001);
	vec3 a=mix(tint_0.rgb,textureGrad(layer_0,pixel_uv(uv,vec2(textureSize(layer_0,0)),pixel_layers.x),dFdx(uv),dFdy(uv)).rgb,has_texture.x);
	vec3 b=mix(tint_1.rgb,textureGrad(layer_1,pixel_uv(uv,vec2(textureSize(layer_1,0)),pixel_layers.y),dFdx(uv),dFdy(uv)).rgb,has_texture.y);
	vec3 c=mix(tint_2.rgb,textureGrad(layer_2,pixel_uv(uv,vec2(textureSize(layer_2,0)),pixel_layers.z),dFdx(uv),dFdy(uv)).rgb,has_texture.z);
	vec3 d=mix(tint_3.rgb,textureGrad(layer_3,pixel_uv(uv,vec2(textureSize(layer_3,0)),pixel_layers.w),dFdx(uv),dFdy(uv)).rgb,has_texture.w);
	float cloud=smoothstep(0.1,0.9,sin(world_pos.x*0.11+TIME*cloud_speed)*sin(world_pos.z*0.13+TIME*cloud_speed*0.7));
	ALBEDO=(a*w.x+b*w.y+c*w.z+d*w.w)*(1.0-cloud*cloud_strength);
	ROUGHNESS=0.95;
}
