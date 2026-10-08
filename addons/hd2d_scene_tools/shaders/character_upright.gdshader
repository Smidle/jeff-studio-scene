shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_disabled;

uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_disable;
uniform bool use_lighting = false;
uniform float occlusion_radius = 0.0;
uniform float occlusion_margin = 0.0;
uniform vec3 occlusion_contact_normal = vec3(0.0);

void vertex() {
	// Keep the original full-billboard silhouette, scale and foot pivot.
	vec3 model_scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(model_scale.x, 0.0, 0.0, 0.0), vec4(0.0, model_scale.y, 0.0, 0.0), vec4(0.0, 0.0, model_scale.z, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	vec4 visual_view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION = PROJECTION_MATRIX * visual_view;
	// A tilted sprite otherwise extends behind its upright physics capsule.
	// Use the camera-facing interior of the capsule, not its center plane:
	// small eaves can otherwise cut into the sprite although the body is outside.
	// Stay inside the physical footprint so a contacted wall still hides actors
	// behind it, including thin walls. This changes depth only, never physics.
	// Use only that plane's depth: screen position/UV stay exactly billboarded.
	// Normal depth testing remains enabled, including walls in front of actors.
	vec3 horizontal = vec3(INV_VIEW_MATRIX[2].x, 0.0, INV_VIEW_MATRIX[2].z);
	if (length(horizontal) > 0.05) {
		vec3 plane_normal = normalize(horizontal);
		bool front_contact = false;
		// At oblique wall contact a camera-facing plane can cross the wall at
		// the hat's wide edges. Align with the actual wall instead, while
		// retaining the full billboard's screen silhouette.
		if (length(occlusion_contact_normal) > 0.5) {
			vec3 contact_normal = normalize(occlusion_contact_normal);
			float facing = dot(contact_normal, plane_normal);
			if (abs(facing) > 0.2) {
				plane_normal = contact_normal * sign(facing);
				front_contact = facing > 0.2;
			}
		}
		float front = max(occlusion_radius, 0.0) * min(model_scale.x, model_scale.z) * 0.9;
		// Two source pixels of trim clearance only on the OUTSIDE of a
		// contacted wall. Never give this margin to actors behind a wall.
		if (front_contact) {
			front += max(occlusion_margin, 0.0) * model_scale.y;
		}
		vec3 plane_origin = MODEL_MATRIX[3].xyz + plane_normal * front;
		vec3 visual_world = (INV_VIEW_MATRIX * visual_view).xyz;
		vec3 ray = PROJECTION_MATRIX[3][3] > 0.5 ? -INV_VIEW_MATRIX[2].xyz : normalize(visual_world - INV_VIEW_MATRIX[3].xyz);
		float denominator = dot(plane_normal, ray);
		if (abs(denominator) > 0.05) {
			float travel = dot(plane_normal, plane_origin - visual_world) / denominator;
			vec4 upright_clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(visual_world + ray * travel, 1.0);
			if (upright_clip.w > 0.001) {
				POSITION.z = upright_clip.z / upright_clip.w * POSITION.w;
			}
		}
	}
}

void fragment() {
	vec4 ink = texture(texture_albedo, UV) * COLOR;
	ALPHA = ink.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	ALBEDO = use_lighting ? ink.rgb : vec3(0.0);
	EMISSION = use_lighting ? vec3(0.0) : ink.rgb;
}
