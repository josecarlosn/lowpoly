shader_type spatial;

// skip_vertex_transform é necessário para o jitter manual
render_mode skip_vertex_transform, diffuse_lambert, specular_schlick_ggx;

// ==========================================
// UNIFORMS DO EFEITO PS1
// ==========================================
group_uniforms PS1_Effects;
// Intensidade do Jitter (0 = desativado)
uniform float u_jitter_resolution : hint_range(0.0, 1024.0, 1.0) = 128.0;
// Intensidade da distorção Affine (0.0 = Moderno, 1.0 = PS1 Puro)
uniform float u_affine_intensity : hint_range(0.0, 1.0, 0.01) = 0.5;
// Z-Bias: Controla onde a distorção começa.
uniform float u_affine_z_bias : hint_range(0.0, 10.0, 0.0001) = 0.0005;

// ==========================================
// UNIFORMS DO OBJETO
// ==========================================
group_uniforms Object_Properties;
uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D texture_normal : hint_normal, filter_nearest;
uniform float normal_scale : hint_range(0.0, 1.0) = 1.0;

// ==========================================
// VARYINGS
// ==========================================
varying vec2 v_uv;
varying float v_w_correction;

// ==========================================
// VERTEX SHADER
// ==========================================
void vertex() {
	// Transformação manual para o espaço de visão (necessário por causa do skip_vertex_transform)
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	
	// Passamos a normal para o fragment shader corretamente
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	BINORMAL = normalize((MODELVIEW_MATRIX * vec4(BINORMAL, 0.0)).xyz);
	TANGENT = normalize((MODELVIEW_MATRIX * vec4(TANGENT, 0.0)).xyz);
	
	// Posição no espaço de clip
	vec4 clip_pos = PROJECTION_MATRIX * view_pos;
	
	// Jitter (Vertex Snapping)
	vec4 snapped_pos = clip_pos;
	if (u_jitter_resolution > 0.0) {
		snapped_pos.xyz /= snapped_pos.w; 
		snapped_pos.x = floor(snapped_pos.x * u_jitter_resolution) / u_jitter_resolution;
		snapped_pos.y = floor(snapped_pos.y * u_jitter_resolution) / u_jitter_resolution;
		snapped_pos.xyz *= snapped_pos.w; 
	}
	
	POSITION = snapped_pos; 
	
	// MÉTODO AFFINE ESTÁVEL:
	// No Godot 4, o comportamento de interpolação pode variar. 
	// Multiplicamos o UV pelo W original para simular a falta de correção de perspectiva.
	float w_val = snapped_pos.w;
	v_uv = UV * w_val;
	
	// O v_w_correction é o que o fragment vai usar para dividir.
	v_w_correction = mix(w_val, w_val + u_affine_z_bias, u_affine_intensity);
	
	// Atribuímos a posição da VIEW para o Godot processar luzes corretamente
	VERTEX = view_pos.xyz;
}

// ==========================================
// FRAGMENT SHADER
// ==========================================
void fragment() {
	// Cálculo do UV Afine
	float correction_factor = v_w_correction;
	vec2 actual_uv = v_uv / correction_factor;
	
	// Textura Albedo
	vec4 tex_color = texture(texture_albedo, actual_uv);
	vec4 final_color = tex_color * albedo;
	
	ALBEDO = final_color.rgb;
	ALPHA = final_color.a;
	
	// Descarte de pixels para transparência (comum em árvores/folhas)
	if (ALPHA < 0.5) {
		discard;
	}
	
	// Normal Map
	vec3 normal_map = texture(texture_normal, actual_uv).rgb;
	NORMAL_MAP = normal_map;
	NORMAL_MAP_DEPTH = normal_scale;
}
