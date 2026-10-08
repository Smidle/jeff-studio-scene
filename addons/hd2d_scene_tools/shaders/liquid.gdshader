shader_type spatial;
render_mode cull_disabled;
uniform bool lava = false;
uniform vec4 surface_color : source_color = vec4(0.05,0.3,0.4,1.0);
uniform float animation_speed = 0.35;
uniform float emission_energy = 0.7;
uniform vec2 extent = vec2(64.0);
float noise_value(vec2 p){
	vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	vec4 h=fract(sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+vec2(1,1),vec2(127.1,311.7))))*43758.5453);
	return mix(mix(h.x,h.y,f.x),mix(h.z,h.w,f.x),f.y);
}
void fragment(){
	if(lava && length(UV-vec2(0.5))>0.49){ discard; }
	vec2 p=floor(UV*extent*12.0)/12.0;
	float t=TIME*animation_speed;
	float wave=sin(p.x*0.75+p.y*1.2+t+sin(p.x*0.5-p.y*0.4+t*0.3)*2.0);
	float bands=floor((wave*0.5+0.5)*5.0)/5.0;
	if(lava){
		float crust=smoothstep(0.42,0.63,noise_value(p*1.1+vec2(t*0.15,-t*0.09)));
		vec3 hot=surface_color.rgb*(0.7+0.3*sin(t+wave));
		ALBEDO=mix(vec3(0.055,0.035,0.03),hot,crust);
		EMISSION=hot*crust*emission_energy;
		ROUGHNESS=0.85;
	}else{
		ALBEDO=surface_color.rgb*(0.94+bands*0.12)+vec3(0.025)*smoothstep(0.95,1.0,wave);
		NORMAL=normalize(NORMAL+vec3(wave*0.008,0,cos(p.y*1.2+t)*0.008));
		ROUGHNESS=0.42;
		SPECULAR=0.3;
	}
}
