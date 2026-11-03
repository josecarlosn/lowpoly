shader_type sky;

// ---------- Céu ----------
uniform vec4 sky_top_color : source_color = vec4(0.385, 0.454, 0.55, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.646, 0.656, 0.67, 1.0);
uniform float inv_sky_curve : hint_range(1, 100) = 4.0;
uniform vec4 ground_bottom_color : source_color = vec4(0.2, 0.169, 0.133, 1.0);
uniform vec4 ground_horizon_color : source_color = vec4(0.646, 0.656, 0.67, 1.0);
uniform float inv_ground_curve : hint_range(1, 100) = 30.0;
uniform float sun_angle_max = 0.877;
uniform float inv_sun_curve : hint_range(1, 100) = 22.78;
uniform float exposure : hint_range(0, 128) = 1.0;

// ---------- Nuvens ----------
uniform vec4 cloud_light_color : source_color = vec4(0.92, 0.93, 0.95, 1.0);
uniform vec4 cloud_shadow_color : source_color = vec4(0.38, 0.42, 0.50, 1.0);
uniform float cloud_scale : hint_range(0.3, 8.0) = 1.6;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.55;
uniform float cloud_softness : hint_range(0.05, 0.8) = 0.35;
uniform float cloud_height : hint_range(0.1, 2.0) = 0.5;
uniform float cloud_warp : hint_range(0.0, 2.0) = 0.6;
uniform vec2 cloud_speed = vec2(0.006, 0.003);
uniform float cloud_horizon_fade : hint_range(0.0, 0.5) = 0.12;
uniform float light_offset : hint_range(0.01, 0.5) = 0.12;   // alcance do sombreamento
uniform float shadow_strength : hint_range(0.0, 4.0) = 1.8;

// ---------- Estilo PS1 / Puppet Combo ----------
uniform float pixel_density : hint_range(20.0, 400.0) = 110.0; // pixels por radiano (menor = mais pixelado)
uniform float color_levels : hint_range(2.0, 32.0) = 7.0;      // níveis de cor por canal
uniform float dither_strength : hint_range(0.0, 1.0) = 0.9;
uniform float grain : hint_range(0.0, 0.2) = 0.03;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
	           mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6)) * p + vec2(7.1, 3.7);
		a *= 0.5;
	}
	return v;
}

// cobertura contínua 0..1 (usada para forma e sombreamento)
float cloud_cov(vec2 p) {
	vec2 w = vec2(fbm(p + vec2(3.2, 1.7)), fbm(p + vec2(8.3, 2.8)));
	float n = fbm(p + (w - 0.5) * cloud_warp * 2.0);
	return clamp((n - (1.0 - cloud_coverage)) / cloud_softness + 0.5, 0.0, 1.0);
}

float bayer4(ivec2 c) {
	int x = c.x & 3;
	int y = c.y & 3;
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

vec3 posterize(vec3 c, float d) {
	float l = color_levels - 1.0;
	return floor(c * l + d) / l;
}

vec3 apply_sun(vec3 sky, vec3 eyedir, vec3 ldir, vec3 lcolor, float lenergy, float lsize) {
	float sun_angle = dot(ldir, eyedir);
	float sun_size = cos(lsize);
	if (sun_angle > sun_size) {
		sky = lcolor * lenergy;
	} else if (sun_angle > sun_angle_max) {
		float c2 = (sun_size - sun_angle) / (sun_size - sun_angle_max);
		sky = mix(sky, lcolor * lenergy, clamp(pow(1.0 - c2, inv_sun_curve), 0.0, 1.0));
	}
	return sky;
}

void sky() {
	float v_angle = clamp(EYEDIR.y, -1.0, 1.0);
	vec3 sky = mix(sky_top_color.rgb, sky_horizon_color.rgb, clamp(pow(1.0 - v_angle, inv_sky_curve), 0.0, 1.0));

	if (EYEDIR.y > 0.0) {
		// grade ANGULAR: pixels do mesmo tamanho na tela em qualquer direção
		float az = atan(EYEDIR.x, EYEDIR.z);
		float el = asin(clamp(EYEDIR.y, -1.0, 1.0));
		vec2 cell = floor(vec2(az, el) * pixel_density);
		vec2 q = (cell + 0.5) / pixel_density;

		vec3 dq = vec3(cos(q.y) * sin(q.x), sin(q.y), cos(q.y) * cos(q.x));
		vec2 uv = dq.xz / (dq.y + cloud_height);
		vec2 p = uv * cloud_scale + TIME * cloud_speed;

		float cov = cloud_cov(p);

		// sombreamento: amostra em direção ao sol
		vec3 L = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.4, 0.7, 0.3));
		vec2 ldir2 = normalize(L.xz + vec2(0.0001));
		float cov_sun = cloud_cov(p + ldir2 * light_offset);
		float shadow = clamp((cov_sun - cov) * shadow_strength + 0.5, 0.0, 1.0);

		// miolo das nuvens fica mais escuro, bordas mais claras
		float thick = smoothstep(0.5, 1.0, cov);
		float lit = clamp(shadow * (1.0 - thick * 0.45), 0.0, 1.0);
		vec3 ccol = mix(cloud_shadow_color.rgb, cloud_light_color.rgb, lit);

		// dithering ordenado + posterização (só nas nuvens, na grade de pixels)
		float d = (bayer4(ivec2(cell)) - 0.5) * dither_strength + 0.5;
		ccol = posterize(ccol, d);
		float g = (hash21(cell + floor(TIME * 12.0)) - 0.5) * grain;
		ccol += g;

		// alpha também dithered -> bordas serrilhadas estilo PS1
		float fade = smoothstep(0.0, cloud_horizon_fade, EYEDIR.y);
		float a = cov * fade;
		a = step(bayer4(ivec2(cell) + ivec2(2, 1)) * dither_strength, a) * a;
		a = floor(a * 4.0 + 0.5) / 4.0;

		sky = mix(sky, ccol, a);
	}

	if (LIGHT0_ENABLED) sky = apply_sun(sky, EYEDIR, LIGHT0_DIRECTION, LIGHT0_COLOR, LIGHT0_ENERGY, LIGHT0_SIZE);
	if (LIGHT1_ENABLED) sky = apply_sun(sky, EYEDIR, LIGHT1_DIRECTION, LIGHT1_COLOR, LIGHT1_ENERGY, LIGHT1_SIZE);
	if (LIGHT2_ENABLED) sky = apply_sun(sky, EYEDIR, LIGHT2_DIRECTION, LIGHT2_COLOR, LIGHT2_ENERGY, LIGHT2_SIZE);
	if (LIGHT3_ENABLED) sky = apply_sun(sky, EYEDIR, LIGHT3_DIRECTION, LIGHT3_COLOR, LIGHT3_ENERGY, LIGHT3_SIZE);

	vec3 ground = mix(ground_bottom_color.rgb, ground_horizon_color.rgb, clamp(pow(1.0 + v_angle, inv_ground_curve), 0.0, 1.0));
	COLOR = mix(ground, sky, step(0.0, EYEDIR.y)) * exposure;
}