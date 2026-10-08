shader_type spatial;
render_mode cull_disabled;
// Cooked UE normals are DirectX tangent-space maps. Convert at sampling time;
// the original texture file remains byte-for-byte unchanged.
uniform sampler2D art : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D normal_art : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float cutoff : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 pixel = texture(art, UV);
	if (pixel.a < cutoff) { discard; }
	ALBEDO = pixel.rgb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
	vec3 tangent_normal = texture(normal_art, UV).rgb;
	tangent_normal.g = 1.0 - tangent_normal.g;
	NORMAL_MAP = tangent_normal;
}
