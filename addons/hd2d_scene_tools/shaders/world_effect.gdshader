shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;
uniform sampler2D base_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_texture = false;
uniform int effect_kind = 0;
uniform vec4 tint : source_color = vec4(0.91,0.94,0.89,0.6);
uniform float speed = 0.01;
uniform float animation_rate = 1.0;
varying vec3 world_position;
// Authored effect colors are sRGB. Forward+/Mobile ALBEDO expects linear RGB.
vec3 effect_color(vec3 color){
 if(OUTPUT_IS_SRGB){return color;}
 return mix(pow((color+vec3(0.055))/1.055,vec3(2.4)),color/12.92,lessThanEqual(color,vec3(0.04045)));
}
float noise(vec2 p){
 vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 vec4 n=fract(sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+1.0,vec2(127.1,311.7))))*43758.5453);
 return mix(mix(n.x,n.y,f.x),mix(n.z,n.w,f.x),f.y);
}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 uv=UV;float clock=TIME*animation_rate;
 float wave=sin(world_position.x*1.4+world_position.z*0.45+clock*0.9)*0.5+0.5;
 if(effect_kind==2){
  vec2 p=floor(world_position.xz*12.0)/12.0;
  float broad=noise(p*0.11+vec2(clock*0.012,0.0));
  float ripple=smoothstep(0.76,0.89,noise(p*vec2(1.1,3.7)+vec2(clock*0.05,clock*0.13)))*0.025;
  ALBEDO=effect_color(mix(vec3(0.23,0.30,0.29),vec3(0.31,0.37,0.34),broad)+ripple);
  ALPHA=0.97;
 }else if(effect_kind==3){
  float streak=sin(UV.x*87.0+sin(UV.y*13.0+clock*3.0))*0.5+0.5;
  float foam=sin(UV.y*18.0+clock*4.0)*0.5+0.5;
  ALBEDO=effect_color(mix(vec3(0.57,0.69,0.69),vec3(0.89,0.94,0.90),streak*0.6+foam*0.4));
  ALPHA=smoothstep(0.0,0.08,UV.x)*smoothstep(0.0,0.08,1.0-UV.x)*0.85;
 }else{
  uv+=vec2(clock*speed,0.0);
  vec4 tex=has_texture?texture(base_texture,uv):vec4(vec3(1.0),0.55+0.2*sin(uv.x*15.0+sin(uv.y*21.0)));
  float edge=smoothstep(0.0,0.15,UV.x)*smoothstep(0.0,0.15,UV.y)*smoothstep(0.0,0.15,1.0-UV.x)*smoothstep(0.0,0.15,1.0-UV.y);
  ALBEDO=tex.rgb*tint.rgb;
  ALPHA=tex.a*tint.a*edge;
 }
}
