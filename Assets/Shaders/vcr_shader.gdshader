shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

group_uniforms vhs_signal;
uniform vec2 resolution = vec2(480.0, 360.0);
uniform float luma_blur : hint_range(0.0, 3.0) = 1.0;
uniform float chroma_bleed : hint_range(0.0, 12.0) = 5.0;      // escorrimento da cor (em pixels)
uniform float chroma_shift : hint_range(-6.0, 6.0) = 2.0;      // cor deslocada em relação ao brilho
uniform float chroma_saturation : hint_range(0.0, 1.5) = 0.8;

group_uniforms tape_errors;
uniform float wobble : hint_range(0.0, 2.0) = 0.6;             // ondulação lenta
uniform float line_jitter : hint_range(0.0, 2.0) = 0.4;        // tremida por linha
uniform float tracking_strength : hint_range(0.0, 2.0) = 0.8;  // faixa de tracking
uniform float tracking_speed : hint_range(0.0, 1.0) = 0.12;
uniform float head_switching : hint_range(0.0, 2.0) = 0.8;     // distorção na base
uniform float dropout_amount : hint_range(0.0, 0.05) = 0.008;  // riscos brancos

group_uniforms dream;
uniform float haze_amount : hint_range(0.0, 1.0) = 0.5;
uniform float haze_radius : hint_range(1.0, 20.0) = 8.0;
uniform float black_lift : hint_range(0.0, 0.3) = 0.08;
uniform float desaturation : hint_range(0.0, 1.0) = 0.25;
uniform vec3 shadow_tint : source_color = vec3(0.45, 0.35, 0.75);
uniform vec3 highlight_tint : source_color = vec3(1.0, 0.82, 0.9);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.35;
uniform float brightness : hint_range(0.5, 1.5) = 1.05;

group_uniforms analog;
uniform float noise_amount : hint_range(0.0, 0.3) = 0.06;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.2;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;
uniform float curvature : hint_range(0.0, 0.2) = 0.03;
uniform float color_levels : hint_range(4.0, 64.0, 1.0) = 32.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise1d(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(vec2(i, 0.0)), hash(vec2(i + 1.0, 0.0)), f);
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

vec2 curve_uv(vec2 uv, float amount) {
	uv = uv * 2.0 - 1.0;
	vec2 off = abs(uv.yx) * amount;
	uv += uv * off * off;
	return uv * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = curve_uv(SCREEN_UV, curvature);

	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		float line = floor(uv.y * resolution.y);
		float t = TIME;
		float frame_t = floor(t * 24.0);

		// ---------- Erros de fita (deslocamento horizontal) ----------
		float shift = 0.0;

		// ondulação lenta + tremida por linha
		shift += (noise1d(uv.y * 6.0 + t * 0.8) - 0.5) * 0.006 * wobble;
		shift += (hash(vec2(line, frame_t)) - 0.5) * 0.002 * line_jitter;

		// faixa de tracking subindo pela tela
		float band_y = fract(1.0 - t * tracking_speed);
		float band_d = uv.y - band_y;
		float band = smoothstep(0.06, 0.0, abs(band_d));
		shift += band * tracking_strength * 0.04 * (noise1d(uv.y * 80.0 + t * 20.0) - 0.5);

		// head-switching: a base da imagem entorta
		float hs = smoothstep(0.93, 1.0, uv.y);
		shift += hs * head_switching * 0.06 * (noise1d(uv.y * 200.0 + t * 30.0) - 0.3);

		uv.x += shift;

		// pixelização horizontal suave (resolução da fita)
		vec2 px = uv * resolution;
		vec2 puv = vec2((floor(px.x) + 0.5) / resolution.x, uv.y);
		vec2 texel = vec2(1.0 / resolution.x, 0.0);

		// ---------- Luma (levemente borrada) ----------
		float y = rgb2yiq(texture(screen_texture, puv).rgb).x * 0.5;
		y += rgb2yiq(texture(screen_texture, puv - texel * luma_blur).rgb).x * 0.25;
		y += rgb2yiq(texture(screen_texture, puv + texel * luma_blur).rgb).x * 0.25;

		// ---------- Croma (borrada e deslocada, estilo NTSC) ----------
		vec2 iq = vec2(0.0);
		const int TAPS = 8;
		for (int i = 0; i < TAPS; i++) {
			float o = (float(i) / float(TAPS - 1)) * chroma_bleed;
			vec3 s = rgb2yiq(texture(screen_texture, puv - texel * (o + chroma_shift)).rgb);
			iq += s.yz;
		}
		iq /= float(TAPS);
		iq *= chroma_saturation;

		vec3 col = yiq2rgb(vec3(y, iq));

		// ---------- Haze onírico (bloom largo e leitoso) ----------
		vec3 haze = vec3(0.0);
		for (int i = 1; i <= 5; i++) {
			float r = float(i) * haze_radius;
			vec2 ox = vec2(r / resolution.x, 0.0);
			vec2 oy = vec2(0.0, r / resolution.y);
			haze += texture(screen_texture, puv + ox).rgb;
			haze += texture(screen_texture, puv - ox).rgb;
			haze += texture(screen_texture, puv + oy).rgb;
			haze += texture(screen_texture, puv - oy).rgb;
			haze += texture(screen_texture, puv + ox + oy).rgb;
			haze += texture(screen_texture, puv - ox - oy).rgb;
		}
		haze /= 30.0;
		// screen blend: clareia sem estourar
		col = 1.0 - (1.0 - col) * (1.0 - haze * haze_amount);

		// ---------- Color grade dreamcore ----------
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(luma), col, 1.0 - desaturation);
		vec3 tint = mix(shadow_tint, highlight_tint, smoothstep(0.1, 0.9, luma));
		col = mix(col, col * tint * 1.4, tint_strength);
		col = col * (1.0 - black_lift) + black_lift;   // pretos lavados
		col *= brightness;

		// ---------- Dropouts (riscos brancos de fita danificada) ----------
		float dh = hash(vec2(line, floor(t * 12.0)));
		if (dh > 1.0 - dropout_amount) {
			float start = hash(vec2(line, floor(t * 12.0) + 7.0));
			float len = 0.05 + 0.2 * hash(vec2(line, floor(t * 12.0) + 3.0));
			float streak = step(start, uv.x) * step(uv.x, start + len);
			col = mix(col, vec3(1.0), streak * 0.85);
		}

		// ---------- Scanlines suaves + campo entrelaçado ----------
		float field = mod(line + frame_t, 2.0);
		float scan = 0.5 + 0.5 * cos((fract(px.y) - 0.5) * 6.28318);
		col *= mix(1.0, 0.7 + 0.3 * scan, scanline_strength);
		col *= 1.0 - 0.04 * field * scanline_strength;

		// ---------- Ruído de fita ----------
		float n = hash(vec2(floor(px.x * 0.5), line) + frame_t * 17.0) - 0.5;
		// ruído mais forte na faixa de tracking e na base
		float n_boost = 1.0 + band * 4.0 + hs * 3.0;
		col += n * noise_amount * n_boost;

		// ---------- Vinheta suave ----------
		vec2 d = uv - 0.5;
		col *= clamp(1.0 - dot(d, d) * 2.0 * vignette_strength, 0.0, 1.0);

		// ---------- Quantização leve ----------
		float lv = color_levels - 1.0;
		col = floor(clamp(col, 0.0, 1.0) * lv + 0.5) / lv;

		COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
	}
}