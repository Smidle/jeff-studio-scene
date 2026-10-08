shader_type spatial;
render_mode cull_disabled;
uniform sampler2D art_nearest : source_color, filter_nearest, repeat_disable;
uniform sampler2D art_linear : source_color, filter_linear_mipmap, repeat_disable;
uniform bool nearest = true;
uniform bool billboard_y = false;
uniform float cutoff = 0.5;
uniform float wind_amount = 0.08;
uniform float wind_strength = 0.5;
uniform float cloud_strength = 0.18;
uniform vec4 uv_region = vec4(0.0,0.0,1.0,1.0);
uniform vec2 source_pixel = vec2(0.001);
uniform vec2 sheet_grid = vec2(1.0);
uniform int sheet_start = 0;
uniform int sheet_count = 1;
uniform float sheet_fps = 8.0;
uniform bool color_key_enabled = false;
uniform vec4 key_color : source_color = vec4(0.1294,0.1294,0.1294,1.0);
uniform float key_tolerance = 0.005;
varying vec3 world_pos;
void vertex(){
	vec3 origin = MODEL_MATRIX[3].xyz;
	VERTEX.x += sin(TIME*1.8+origin.x*0.7+origin.z*0.4)*wind_amount*wind_strength*pow(1.0-UV.y,2.0);
	if(billboard_y){
		vec3 right=normalize(vec3(INV_VIEW_MATRIX[0].x,0.0,INV_VIEW_MATRIX[0].z));
		vec3 up=vec3(0.0,1.0,0.0);
		vec3 back=cross(right,up);
		MODELVIEW_MATRIX=VIEW_MATRIX*mat4(vec4(right*length(MODEL_MATRIX[0].xyz),0.0),vec4(up*length(MODEL_MATRIX[1].xyz),0.0),vec4(back*length(MODEL_MATRIX[2].xyz),0.0),MODEL_MATRIX[3]);
		MODELVIEW_NORMAL_MATRIX=mat3(MODELVIEW_MATRIX);
	}
	world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){
	float frame=float(sheet_start)+mod(floor(TIME*sheet_fps),float(max(sheet_count,1)));
	vec2 cell_size=uv_region.zw/sheet_grid;
	vec2 cell_origin=uv_region.xy+vec2(mod(frame,sheet_grid.x),floor(frame/sheet_grid.x))*cell_size;
	vec2 sample_uv=clamp(cell_origin+UV*cell_size,cell_origin+source_pixel*0.5,cell_origin+cell_size-source_pixel*0.5);
	vec4 art=nearest?texture(art_nearest,sample_uv):texture(art_linear,sample_uv);
	if(color_key_enabled){
		float difference=max(max(abs(art.r-key_color.r),abs(art.g-key_color.g)),abs(art.b-key_color.b));
		if(difference<=key_tolerance){art.a=0.0;}
	}
	float cloud=smoothstep(0.1,0.9,sin(world_pos.x*0.11+TIME*0.15)*sin(world_pos.z*0.13+TIME*0.105));
	ALBEDO=art.rgb*(1.0-cloud*cloud_strength);
	ALPHA=art.a;
	ALPHA_SCISSOR_THRESHOLD=cutoff;
	ROUGHNESS=0.95;
}
