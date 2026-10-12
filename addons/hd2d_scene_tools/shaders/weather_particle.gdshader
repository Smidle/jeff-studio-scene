shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never, fog_disabled;
uniform bool snow = false;
uniform bool sand = false;
uniform vec3 fall_velocity = vec3(0.0, -14.0, 0.0);
void vertex() {
	// Camera-facing planes preserve particle size in perspective and orthographic views.
	vec2 up = vec2(0.0, 1.0);
	vec2 motion = (VIEW_MATRIX * vec4(fall_velocity, 0.0)).xy;
	if ((!snow && !sand) && length(motion) > 0.001) up = -normalize(motion);
	vec2 right = vec2(up.y, -up.x);
	mat4 facing = mat4(INV_VIEW_MATRIX[0] * right.x + INV_VIEW_MATRIX[1] * right.y,
		INV_VIEW_MATRIX[0] * up.x + INV_VIEW_MATRIX[1] * up.y, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	facing[0].xyz *= length(MODEL_MATRIX[0].xyz);
	facing[1].xyz *= length(MODEL_MATRIX[1].xyz);
	facing[2].xyz *= length(MODEL_MATRIX[2].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
}
void fragment() {
	vec2 pixel = floor(UV * 8.0);
	if (snow && !(abs(pixel.x - 3.5) < 1.1 || abs(pixel.y - 3.5) < 1.1)) discard;
	float dust = 1.0;
	if (sand) {
		vec2 p = (floor(UV * 16.0) + 0.5) / 16.0 - 0.5;
		dust = smoothstep(0.50, 0.05, length(p));
		if (dust < 0.02) discard;
	}
	ALBEDO = sand ? vec3(0.70, 0.47, 0.22) : (snow ? vec3(0.92, 0.96, 1.0) : vec3(0.70, 0.82, 0.94));
	ALPHA = COLOR.a * dust * (sand ? 0.13 : (snow ? 0.88 : 0.62));
}
