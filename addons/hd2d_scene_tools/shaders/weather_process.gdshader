shader_type particles;
render_mode disable_force, disable_velocity;
uniform float kind = 1.0;
uniform vec3 extent = vec3(14.0, 9.0, 14.0);
uniform float bottom_y = -3.0;
uniform float speed = 1.0;
uniform float fall_randomness = 0.25;
uniform float leaf_drift = 0.7;
uniform vec2 wind = vec2(0.2, 0.0);
uniform float strength = 1.0;
uniform float weather_clock = 0.0;
uniform int shelter_count = 0;
uniform mat4 shelter_inverse[16];
uniform vec3 shelter_half[16];
uniform sampler2D random_table : filter_nearest, repeat_enable;
void start() {
	vec4 sample_a = texture(random_table, vec2((mod(float(NUMBER),8192.0)+0.5)/8192.0,0.5));
	vec4 sample_b = texture(random_table, vec2((mod(float(NUMBER)+719.0,8192.0)+0.5)/8192.0,0.5));
	CUSTOM = vec4(0.0, floor(sample_b.r * 3.0), sample_b.g, 0.0);
	TRANSFORM = mat4(1.0);
	vec3 local = vec3((sample_a.r-0.5)*extent.x*2.0, sample_a.g*extent.y, (sample_a.b-0.5)*extent.z*2.0);
	TRANSFORM[3] = EMISSION_TRANSFORM * vec4(local, 1.0);
	VELOCITY = vec3(0.0, -(kind < 1.5 ? 14.0 : kind < 2.5 ? 1.9 : kind < 3.5 ? 1.0 : 0.72) * (1.0+(CUSTOM.z*2.0-1.0)*fall_randomness), 0.0);
	COLOR = vec4(1.0);
	if (sample_a.a > strength) { ACTIVE = false; }
}
void process() {
	CUSTOM.x += DELTA;
	vec3 pos = TRANSFORM[3].xyz;
	if (COLLIDED && CUSTOM.w < 0.5) {
		if (kind < 2.5) { ACTIVE = false; }
		else {
			pos += COLLISION_NORMAL * COLLISION_DEPTH;
			vec3 normal = normalize(COLLISION_NORMAL);
			vec3 tangent = abs(normal.y)>0.98 ? vec3(1.0,0.0,0.0) : normalize(cross(vec3(0.0,1.0,0.0),normal));
			TRANSFORM[0].xyz=tangent; TRANSFORM[1].xyz=normal; TRANSFORM[2].xyz=cross(tangent,normal);
			CUSTOM.w = CUSTOM.x + 1.0; VELOCITY = vec3(0.0);
		}
	}
	if (CUSTOM.w < 0.5) {
		float flutter = kind > 2.5 ? leaf_drift : kind > 1.5 ? 0.24 : 0.0;
		vec2 sway = vec2(sin(CUSTOM.x*2.2+CUSTOM.z*19.0), cos(CUSTOM.x*1.6+CUSTOM.z*12.0))*flutter;
		float fall=VELOCITY.y*speed;
		pos += vec3(wind.x+sway.x, fall, wind.y+sway.y)*DELTA;
		if (pos.y < bottom_y) { ACTIVE=false; }
	}
	for (int i=0; i<16; i++) {
		if (i>=shelter_count) { break; }
		vec3 p = (shelter_inverse[i]*vec4(pos,1.0)).xyz;
		if (all(lessThan(abs(p), shelter_half[i]))) { ACTIVE=false; }
	}
	TRANSFORM[3].xyz = pos;
	float fade = min(CUSTOM.x*4.0, min((LIFETIME-CUSTOM.x)*1.8,1.0));
	if (CUSTOM.w>0.5) { fade *= clamp(1.0-(CUSTOM.x-(CUSTOM.w-1.0))/1.5,0.0,1.0); }
	COLOR.a = max(fade,0.0);
	if (CUSTOM.w>0.5 && CUSTOM.x-(CUSTOM.w-1.0)>1.5) { ACTIVE=false; }
}
