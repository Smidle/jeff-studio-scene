shader_type spatial;
render_mode cull_disabled;
uniform sampler2D base_texture : source_color,filter_nearest_mipmap,repeat_enable;
uniform sampler2D opacity_texture : filter_nearest_mipmap,repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
uniform float opacity = 1.0;
void fragment(){
 vec2 uv=UV*uv_scale+uv_offset;
 vec4 base=texture(base_texture,uv);
 ALBEDO=base.rgb*tint.rgb;
 ALPHA=texture(opacity_texture,uv).r*base.a*opacity*tint.a;
 ALPHA_SCISSOR_THRESHOLD=0.333;
 ROUGHNESS=1.0;
}
