shader_type spatial;

// Item na mão com textura. O vertex() encolhe o item em direção à câmera,
// para luz e profundidade ficarem do lado do player (sem viewmodel).
// Mantenha o ItemHand na posição/escala originais e cast_shadow = off.

uniform float k : hint_range(0.05, 1.0) = 0.12;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_vertex_color = false;

uniform sampler2D texture_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;

uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;

uniform vec4 emission_color : source_color = vec4(1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 0.0;

void vertex() {
	if (!IN_SHADOW_PASS) {
		vec3 view_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		VERTEX = (inverse(MODELVIEW_MATRIX) * vec4(view_pos * k, 1.0)).xyz;
	}
}

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	vec3 base = tex.rgb * albedo_color.rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	ALBEDO = base;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
	NORMAL_MAP = texture(texture_normal, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	EMISSION = emission_color.rgb * emission_energy;
}