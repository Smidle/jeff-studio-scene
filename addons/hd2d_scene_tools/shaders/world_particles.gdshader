shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.9,0.7,0.65,0.65);
uniform float rise = -1.0;
varying float fade;
void vertex(){
 float phase=fract(INSTANCE_CUSTOM.w+TIME*0.14);
 vec3 center=MODEL_MATRIX[3].xyz;
 center+=vec3(sin(phase*6.283+INSTANCE_CUSTOM.x*6.0)*0.45,rise*phase*2.0,cos(phase*6.283+INSTANCE_CUSTOM.y*6.0)*0.3);
 vec3 right=INV_VIEW_MATRIX[0].xyz;vec3 up=INV_VIEW_MATRIX[1].xyz;
 POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(center+right*VERTEX.x+up*VERTEX.y,1.0);
 fade=sin(phase*3.14159);
}
void fragment(){
 float shape=1.0-smoothstep(0.18,0.49,length(UV-vec2(0.5)));
 ALBEDO=tint.rgb;ALPHA=shape*tint.a*fade;
}
