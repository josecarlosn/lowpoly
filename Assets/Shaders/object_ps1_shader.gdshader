
shader_type spatial;
render_mode skip_vertex_transform, diffuse_lambert, specular_schlick_ggx;

// ==========================================
// UNIFORMS DO EFEITO PS1
// ==========================================
group_uniforms PS1_Effects;

uniform float u_jitter_resolution : hint_range(0.0, 1024.0, 1.0) = 128.0;
uniform float u_affine_intensity : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float u_affine_z_bias : hint_range(0.0, 0.01, 0.0001) = 0.0005;


// ==========================================
// UNIFORMS DO OBJETO
// ==========================================
group_uniforms Object_Properties;

uniform sampler2D texture_albedo : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);

uniform sampler2D texture_normal : hint_normal, filter_nearest, repeat_enable;
uniform float normal_scale : hint_range(0.0, 1.0) = 1.0;

uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);


// ==========================================
// VARYINGS
// ==========================================
varying vec2 v_uv;
varying vec2 v_uv_affine;
varying float v_w_correction;
varying float v_affine_intensity;


// ==========================================
// VERTEX SHADER
// ==========================================
void vertex() {

    // Posição original em View Space
    vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

    // Transformação das normais
    NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    BINORMAL = normalize((MODELVIEW_MATRIX * vec4(BINORMAL, 0.0)).xyz);
    TANGENT = normalize((MODELVIEW_MATRIX * vec4(TANGENT, 0.0)).xyz);

    // Projeção original
    vec4 clip_pos = PROJECTION_MATRIX * view_pos;


    // ======================================
    // IDENTIFICAÇÃO DA CÂMERA PRINCIPAL
    // ======================================

    bool is_main_camera_pass =
        distance(
            INV_VIEW_MATRIX[3].xyz,
            MAIN_CAM_INV_VIEW_MATRIX[3].xyz
        ) < 0.01;


    // ======================================
    // VERTEX SNAPPING
    // SOMENTE NA CÂMERA PRINCIPAL
    // ======================================

    vec4 snapped_pos = clip_pos;

    if (is_main_camera_pass) {

        if (u_jitter_resolution > 0.0) {

            snapped_pos.xyz /= snapped_pos.w;

            snapped_pos.x =
                floor(snapped_pos.x * u_jitter_resolution)
                / u_jitter_resolution;

            snapped_pos.y =
                floor(snapped_pos.y * u_jitter_resolution)
                / u_jitter_resolution;

            snapped_pos.xyz *= snapped_pos.w;
        }

        POSITION = snapped_pos;
    }


    // ======================================
    // AFFINE TEXTURE
    // ======================================

    float w_val = clip_pos.w;

    v_uv = UV;
    v_uv_affine = UV * w_val;
    v_w_correction = w_val + u_affine_z_bias;
    v_affine_intensity = u_affine_intensity;


    // ======================================
    // POSIÇÃO ORIGINAL
    // PRESERVADA PARA ILUMINAÇÃO
    // ======================================

    VERTEX = view_pos.xyz;
}


// ==========================================
// FRAGMENT SHADER
// ==========================================
void fragment() {

    // ======================================
    // MIX ENTRE UV PERSPECTIVA E UV AFIM
    // ======================================

    vec2 uv_perspective = v_uv;
    vec2 uv_affine = v_uv_affine / v_w_correction;

    vec2 actual_uv = mix(
        uv_perspective,
        uv_affine,
        v_affine_intensity
    );


    // ======================================
    // ESCALA E OFFSET
    // ======================================

    actual_uv = actual_uv * uv_scale + uv_offset;


    // ======================================
    // ALBEDO
    // ======================================

    vec4 tex_color = texture(texture_albedo, actual_uv);
    vec4 final_color = tex_color * albedo;

    ALBEDO = final_color.rgb;

    // Cutout
    if (final_color.a < 0.5) {
        discard;
    }


    // ======================================
    // NORMAL MAP
    // ======================================

    NORMAL_MAP = texture(texture_normal, actual_uv).rgb;
    NORMAL_MAP_DEPTH = normal_scale;
}
