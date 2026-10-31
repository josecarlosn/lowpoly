shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

group_uniforms monitor;
uniform vec2 resolution = vec2(640.0, 480.0);        // 320x200 para estilo VGA modo 13h
uniform float curvature : hint_range(0.0, 0.3) = 0.08;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.4;
uniform int phosphor_mode : hint_enum("Colorido", "Verde", "Ambar") = 0;

group_uniforms scanlines;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.45;
uniform float mask_strength : hint_range(0.0, 0.6) = 0.15;

group_uniforms glow;
uniform float blur_width : hint_range(0.0, 2.0) = 0.8;    // borrão horizontal (sinal analógico)
uniform float bloom_amount : hint_range(0.0, 1.0) = 0.35;
uniform float bloom_radius : hint_range(1.0, 8.0) = 3.0;

group_uniforms colors;
uniform float color_levels : hint_range(2.0, 64.0, 1.0) = 64.0;   // 64 = 6 bits por canal (VGA)
uniform float dither_strength : hint_range(0.0, 1.5) = 0.5;
uniform float brightness : hint_range(0.5, 2.0) = 1.15;
uniform float contrast : hint_range(0.5, 1.5) = 1.05;

group_uniforms analog;
uniform float grain : hint_range(0.0, 0.2) = 0.025;
uniform float flicker : hint_range(0.0, 0.1) = 0.012;

const float BAYER[16] = float[16](
	0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
	12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
	3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
	15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 curve_uv(vec2 uv, float amount) {
	uv = uv * 2.0 - 1.0;
	vec2 off = abs(uv.yx) * amount;
	uv += uv * off * off;
	return uv * 0.5 + 0.5;
}

void fragment() {
	vec2 suv = curve_uv(SCREEN_UV, curvature);

	if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// Pixelização na resolução do "modo de vídeo"
		vec2 px = suv * resolution;
		ivec2 p = ivec2(floor(px));
		vec2 uv = (vec2(p) + 0.5) / resolution;
		vec2 texel = vec2(1.0 / resolution.x, 0.0);

		// Borrão horizontal leve (3 taps) simulando o sinal do cabo
		vec3 col = texture(screen_texture, uv).rgb * 0.5;
		col += texture(screen_texture, uv - texel * blur_width).rgb * 0.25;
		col += texture(screen_texture, uv + texel * blur_width).rgb * 0.25;

		// Bloom: brilho que vaza das áreas claras
		vec3 glow = vec3(0.0);
		for (int i = 1; i <= 4; i++) {
			float o = float(i) * bloom_radius / resolution.x;
			float oy = float(i) * bloom_radius / resolution.y;
			glow += texture(screen_texture, uv + vec2(o, 0.0)).rgb;
			glow += texture(screen_texture, uv - vec2(o, 0.0)).rgb;
			glow += texture(screen_texture, uv + vec2(0.0, oy)).rgb;
			glow += texture(screen_texture, uv - vec2(0.0, oy)).rgb;
		}
		glow /= 16.0;
		col += glow * bloom_amount;

		// Modo de fósforo (monocromático opcional)
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		if (phosphor_mode == 1) {
			col = vec3(0.25, 1.0, 0.35) * luma;
		} else if (phosphor_mode == 2) {
			col = vec3(1.0, 0.65, 0.15) * luma;
		}

		col = (col - 0.5) * contrast + 0.5;
		col *= brightness;

		// Scanlines: cada linha do modo de vídeo tem centro claro e borda escura
		float scan = 0.5 + 0.5 * cos((fract(px.y) - 0.5) * 3.14159 * 2.0);
		col *= mix(1.0, 0.35 + 0.65 * scan, scanline_strength);

		// Máscara de fósforo RGB (tríades na resolução real da tela)
		int m = int(mod(FRAGCOORD.x, 3.0));
		vec3 mask = vec3(1.0 - mask_strength);
		if (m == 0) mask.r = 1.0;
		else if (m == 1) mask.g = 1.0;
		else mask.b = 1.0;
		col *= mask * (1.0 + mask_strength * 0.4);

		// Grão fino e cintilação
		float t = floor(TIME * 30.0);
		col += (hash(vec2(p) + t * 13.0) - 0.5) * grain;
		col *= 1.0 + (hash(vec2(t, 4.0)) - 0.5) * flicker * 2.0;

		// Vinheta
		vec2 d = suv - 0.5;
		col *= clamp(1.0 - dot(d, d) * 2.0 * vignette_strength, 0.0, 1.0);

		// Quantização estilo VGA com dithering Bayer
		int idx = (p.x % 4) + (p.y % 4) * 4;
		float threshold = BAYER[idx] - 0.5;
		float lv = color_levels - 1.0;
		col = floor(clamp(col, 0.0, 1.0) * lv + 0.5 + threshold * dither_strength) / lv;

		COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
	}
}