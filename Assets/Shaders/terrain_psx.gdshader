shader_type spatial;
render_mode diffuse_lambert, specular_disabled, cull_back;

// =============================================================================
// HTERRAIN — Uniforms obrigatórios (não remova)
// =============================================================================
uniform sampler2D u_terrain_heightmap;
uniform sampler2D u_terrain_normalmap;
uniform sampler2D u_terrain_colormap   : source_color;
uniform sampler2D u_terrain_splatmap;
uniform mat4      u_terrain_inverse_transform;
uniform mat3      u_terrain_normal_basis;

// Texturas do terreno (4 slots de pintura)
uniform sampler2D u_ground_albedo_bump_0 : source_color;
uniform sampler2D u_ground_albedo_bump_1 : source_color;
uniform sampler2D u_ground_albedo_bump_2 : source_color;
uniform sampler2D u_ground_albedo_bump_3 : source_color;

// =============================================================================
// EFEITOS PSX — Ajuste no Inspector do HTerrain
// =============================================================================

// Resolucao do vertex snapping. Menor = mais "tremido" estilo PS1
uniform float snap : hint_range(8.0, 256.0, 1.0) = 64.0;

// Escala de tiling das texturas pintadas no terreno
uniform float tex_scale : hint_range(1.0, 128.0, 0.5) = 24.0;

// Intensidade da luz ambiente (clareia sombras escuras)
uniform float ambient : hint_range(0.0, 1.0) = 0.3;

// Intensidade geral da luz direcional
uniform float light_power : hint_range(0.0, 2.0) = 0.8;

// Cor de névoa PSX (distancia controlada pelo WorldEnvironment)
uniform vec4 fog_color : source_color = vec4(0.5, 0.5, 0.6, 1.0);
uniform float fog_start : hint_range(0.0, 500.0) = 40.0;
uniform float fog_end   : hint_range(0.0, 1000.0) = 120.0;

// =============================================================================
// Varyings
// =============================================================================
varying vec3 v_world_pos;
varying float v_fog_factor;

// =============================================================================
// VERTEX
// =============================================================================
void vertex() {
	// --- 1. Coordenadas do heightmap em espaço local do terreno
	vec2 hmap_uv = (u_terrain_inverse_transform * vec4(VERTEX, 1.0)).xz;

	// --- 2. Altura vinda do heightmap
	float h = texture(u_terrain_heightmap, hmap_uv).r;
	VERTEX.y = h;

	// --- 3. Normal baked pelo HTerrain
	vec3 n = texture(u_terrain_normalmap, hmap_uv).xyz * 2.0 - 1.0;
	NORMAL = normalize(u_terrain_normal_basis * n);

	// --- 4. Posição mundial (antes do snap, para UVs corretos)
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// --- 5. PSX Vertex Snapping (em clip space)
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	clip.xyz  /= clip.w;
	clip.xy    = floor(clip.xy * snap + 0.5) / snap;
	clip.xyz  *= clip.w;
	POSITION   = clip;

	// --- 6. Fator de névoa (calculado no vertex para ser "flat" estilo PS1)
	float cam_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	v_fog_factor   = clamp((cam_dist - fog_start) / (fog_end - fog_start), 0.0, 1.0);
}

// =============================================================================
// FRAGMENT
// =============================================================================
void fragment() {
	// --- Coordenadas do terreno para amostrar splat e colormap
	vec2 hmap_uv = (u_terrain_inverse_transform * vec4(v_world_pos, 1.0)).xz;

	// --- Pesos do splatmap (qual textura domina em cada ponto)
	vec4 splat = texture(u_terrain_splatmap, hmap_uv);

	// --- UV mundial para as texturas do chão (sem distorção)
	vec2 ground_uv = v_world_pos.xz / tex_scale;

	// --- Amostragem das 4 texturas de chão
	vec3 t0 = texture(u_ground_albedo_bump_0, ground_uv).rgb;
	vec3 t1 = texture(u_ground_albedo_bump_1, ground_uv).rgb;
	vec3 t2 = texture(u_ground_albedo_bump_2, ground_uv).rgb;
	vec3 t3 = texture(u_ground_albedo_bump_3, ground_uv).rgb;

	// --- Mistura das texturas pelos pesos do splatmap
	vec3 ground = t0 * splat.r
	            + t1 * splat.g
	            + t2 * splat.b
	            + t3 * splat.a;

	// --- Colormap pintado pelo artista
	vec3 colormap = texture(u_terrain_colormap, hmap_uv).rgb;

	// --- Cor final antes da névoa
	vec3 color = ground * colormap;

	// --- Névoa PSX aplicada no fragment (flat por chunk = visual PS1)
	color = mix(color, fog_color.rgb, v_fog_factor);

	ALBEDO    = color;
	ROUGHNESS = 1.0;
	SPECULAR  = 0.0;
}

// =============================================================================
// LIGHT — Iluminação flat estilo PS1
// =============================================================================
void light() {
	float ndotl = max(dot(NORMAL, LIGHT), 0.0);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * ndotl * light_power;
	// Luz ambiente constante para evitar preto total nas sombras
	DIFFUSE_LIGHT += ALBEDO * ambient;
}
