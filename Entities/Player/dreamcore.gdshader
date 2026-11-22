shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

group_uniforms cores;
// Níveis por canal (2 = só preto/branco, 256 = sem efeito)
uniform int levels_all : hint_range(2, 256) = 16;
uniform bool separate_channels = false;
uniform int levels_r : hint_range(2, 256) = 16;
uniform int levels_g : hint_range(2, 256) = 16;
uniform int levels_b : hint_range(2, 256) = 16;
// 0 = Round, 1 = Floor, 2 = Ceil
uniform int rounding_mode : hint_enum("Round", "Floor", "Ceil") = 0;
// Mistura entre imagem original e imagem limitada
uniform float crush_mix : hint_range(0.0, 1.0) = 1.0;

group_uniforms ajuste_antes;
uniform float brightness : hint_range(-0.5, 0.5) = 0.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float gamma : hint_range(0.3, 3.0) = 1.0;

group_uniforms dither;
uniform bool dither_enabled = true;
// 1.0 = dither completo de um degrau
uniform float dither_strength : hint_range(0.0, 1.0) = 0.5;
// Tamanho do padrão em pixels da tela
uniform float dither_pixel_size : hint_range(1.0, 8.0) = 1.0;

const float BAYER[16] = float[16](
	0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
	12.0/16.0, 4.0/16.0, 14.0/16.0,  6.0/16.0,
	3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
	15.0/16.0, 7.0/16.0, 13.0/16.0,  5.0/16.0
);

float quantize(float v, int lv, float threshold) {
	float steps = float(lv) - 1.0;
	float x = v * steps + threshold;
	if (rounding_mode == 0) {
		x = floor(x + 0.5);
	} else if (rounding_mode == 1) {
		x = floor(x);
	} else {
		x = ceil(x);
	}
	return clamp(x / steps, 0.0, 1.0);
}

void fragment() {
	vec3 original = texture(screen_tex, SCREEN_UV).rgb;
	vec3 col = original;

	// ajustes antes de limitar
	col += brightness;
	col = (col - 0.5) * contrast + 0.5;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);
	col = pow(max(col, 0.0), vec3(1.0 / gamma));

	// dither ordenado (Bayer 4x4)
	float threshold = 0.0;
	if (dither_enabled) {
		ivec2 p = ivec2(floor(FRAGCOORD.xy / dither_pixel_size)) % 4;
		threshold = (BAYER[p.y * 4 + p.x] - 0.5) * dither_strength;
	}

	// limitador de cores
	int lr = separate_channels ? levels_r : levels_all;
	int lg = separate_channels ? levels_g : levels_all;
	int lb = separate_channels ? levels_b : levels_all;

	vec3 crushed;
	crushed.r = quantize(col.r, lr, threshold);
	crushed.g = quantize(col.g, lg, threshold);
	crushed.b = quantize(col.b, lb, threshold);

	COLOR = vec4(mix(original, crushed, crush_mix), 1.0);
}