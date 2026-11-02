shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

group_uniforms resolution;
uniform vec2 resolution = vec2(240.0, 180.0);     // quanto menor, mais "esticado"
uniform float softness : hint_range(0.0, 3.0) = 1.2;

group_uniforms compression;
uniform float sharpen : hint_range(0.0, 2.0) = 0.6;          // halo ao redor das bordas
uniform float blur_radius : hint_range(1.0, 6.0) = 2.5;
uniform float block_size : hint_range(4.0, 16.0, 1.0) = 8.0;  // blocos JPEG
uniform float block_strength : hint_range(0.0, 3.0) = 1.0;
uniform float chroma_blur : hint_range(0.0, 1.0) = 0.7;       // cor mais borrada que o brilho
uniform float chroma_levels : hint_range(4.0, 40.0, 1.0) = 14.0;
uniform float color_levels : hint_range(8.0, 64.0, 1.0) = 40.0;

group_uniforms dream;
uniform float bloom : hint_range(0.0, 1.0) = 0.35;
uniform float desaturation : hint_range(0.0, 1.0) = 0.2;
uniform float cool_tint : hint_range(0.0, 1.0) = 0.5;
uniform float contrast : hint_range(0.7, 1.3) = 0.95;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.25;
uniform float noise_amount : hint_range(0.0, 0.1) = 0.015;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 rgb2yiq(vec3 c) {
	return vec3(
		dot(c, vec3(0.299, 0.587, 0.114)),
		dot(c, vec3(0.596, -0.274, -0.322)),
		dot(c, vec3(0.211, -0.523, 0.312))
	);
}

vec3 yiq2rgb(vec3 c) {
	return vec3(
		c.x + 0.956 * c.y + 0.621 * c.z,
		c.x - 0.272 * c.y - 0.647 * c.z,
		c.x - 1.106 * c.y + 1.703 * c.z
	);
}

// Um "pixel" da baixa resolução: média de 4 amostras da tela
vec3 cell(vec2 id) {
	vec2 uv = (id + 0.5) / resolution;
	vec2 h = vec2(0.5 * softness) / resolution;
	vec3 c = texture(screen_texture, uv + vec2(-h.x, -h.y)).rgb;
	c += texture(screen_texture, uv + vec2(h.x, -h.y)).rgb;
	c += texture(screen_texture, uv + vec2(-h.x, h.y)).rgb;
	c += texture(screen_texture, uv + vec2(h.x, h.y)).rgb;
	return c * 0.25;
}

void fragment() {
	vec2 suv = SCREEN_UV;

	// ---- Baixa resolução com interpolação bilinear (o "esticado") ----
	vec2 p = suv * resolution - 0.5;
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec3 c = mix(
		mix(cell(i), cell(i + vec2(1.0, 0.0)), f.x),
		mix(cell(i + vec2(0.0, 1.0)), cell(i + vec2(1.0, 1.0)), f.x),
		f.y
	);

	// ---- Versão borrada (para halo e bloom) ----
	vec3 blur = vec3(0.0);
	for (int k = 0; k < 8; k++) {
		float a = float(k) * 0.785398;
		vec2 o = vec2(cos(a), sin(a)) * blur_radius / resolution;
		blur += texture(screen_texture, suv + o).rgb;
	}
	blur /= 8.0;

	// ---- Nitidez exagerada: cria o halo claro/escuro nas bordas ----
	c = clamp(c + (c - blur) * sharpen, 0.0, 1.0);

	// ---- Compressão: croma borrada/quantizada + erro por bloco ----
	vec3 yiq = rgb2yiq(c);
	yiq.yz = mix(yiq.yz, rgb2yiq(blur).yz, chroma_blur);
	yiq.yz = floor(yiq.yz * chroma_levels + 0.5) / chroma_levels;

	vec2 b = floor(suv * resolution / block_size);
	float k = block_strength * 0.03;
	yiq.x += (hash(b) - 0.5) * k;
	yiq.y += (hash(b + 3.1) - 0.5) * k;
	yiq.z += (hash(b + 7.7) - 0.5) * k;

	vec3 col = yiq2rgb(yiq);

	// ---- Brilho leitoso só nas áreas claras ----
	vec3 glow = max(blur - 0.45, 0.0);
	col = 1.0 - (1.0 - col) * (1.0 - glow * bloom);

	// ---- Cor ----
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, 1.0 - desaturation);
	col += vec3(-0.015, 0.0, 0.035) * cool_tint;
	col = (col - 0.5) * contrast + 0.5;

	// ---- Ruído leve e vinheta ----
	float t = floor(TIME * 12.0);
	col += (hash(floor(suv * resolution) + t) - 0.5) * noise_amount;
	vec2 d = suv - 0.5;
	col *= clamp(1.0 - dot(d, d) * 2.0 * vignette_strength, 0.0, 1.0);

	// ---- Banding leve ----
	float lv = color_levels - 1.0;
	col = floor(clamp(col, 0.0, 1.0) * lv + 0.5) / lv;

	COLOR = vec4(col, 1.0);
}