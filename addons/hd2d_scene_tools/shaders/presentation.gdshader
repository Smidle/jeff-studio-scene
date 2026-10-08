shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float vignette_amount = 0.36;
uniform float zone_blur = 1.0;
uniform float contrast = 1.11;
uniform float saturation = 1.10;
uniform vec3 tint = vec3(1.03,1.01,0.95);
uniform float pixel_size = 1.0;
uniform float region_strength = 0.0;
uniform vec3 region_saturation = vec3(1.0);
uniform vec3 region_contrast = vec3(1.0);
uniform vec3 region_gamma = vec3(1.0);
uniform vec3 region_gain = vec3(1.0);
uniform vec3 region_shadow_gamma = vec3(1.0);
uniform vec3 region_tint = vec3(1.0);
void fragment(){
	vec2 uv=SCREEN_UV;
	if(pixel_size>1.0){vec2 cell=SCREEN_PIXEL_SIZE*pixel_size;uv=(floor(uv/cell)+0.5)*cell;}
	float near_blur=smoothstep(0.79,1.0,uv.y)*2.7;
	float far_blur=(1.0-smoothstep(0.27,0.48,uv.y))*1.25;
	vec3 c=textureLod(screen_texture,uv,max(near_blur,far_blur)*zone_blur).rgb;
	vec3 regional=mix(vec3(dot(c,vec3(0.2126,0.7152,0.0722))),c,region_saturation);
	regional=max((regional-0.5)*region_contrast+0.5,vec3(0.0));
	regional=pow(regional,vec3(1.0)/max(region_gamma,vec3(0.25)))*region_gain;
	regional=mix(regional,pow(max(regional,vec3(0.0)),vec3(1.0)/max(region_shadow_gamma,vec3(0.25))),0.3*(1.0-smoothstep(0.2,0.9,dot(regional,vec3(0.333)))));
	c=mix(c,regional,region_strength);
	c=(c-0.5)*contrast+0.5;
	float luma=dot(c,vec3(0.2126,0.7152,0.0722));
	c=mix(vec3(luma),c,saturation)*tint*region_tint;
	vec2 d=(uv-vec2(0.5))*vec2(1.3,1.0);
	c*=1.0-vignette_amount*smoothstep(0.3,0.78,length(d));
	COLOR=vec4(c,1.0);
}
