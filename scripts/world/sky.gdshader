shader_type sky;
// Horizon City — procedural sky with sun, moon, stars and drifting clouds.

uniform vec3 top_color : source_color = vec3(0.10, 0.24, 0.46);
uniform vec3 horizon_color : source_color = vec3(0.99, 0.72, 0.52);
uniform vec3 bottom_color : source_color = vec3(0.16, 0.20, 0.28);
uniform vec3 sun_dir = vec3(0.4, 0.6, 0.3);
uniform vec3 sun_color : source_color = vec3(1.0, 0.85, 0.62);
uniform vec3 moon_color : source_color = vec3(0.82, 0.89, 1.0);
uniform float sun_size = 0.045;
uniform float night = 0.0;
uniform float time = 0.0;
uniform float cloud_amount = 0.45;
uniform float star_amount = 0.6;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.55;
    for (int i = 0; i < 4; i++) {
        v += a * vnoise(p);
        p = p * 2.03 + vec2(17.1, 9.7);
        a *= 0.5;
    }
    return v;
}

void sky() {
    vec3 dir = normalize(EYEDIR);
    float up = dir.y;

    vec3 col = mix(horizon_color, top_color, smoothstep(-0.02, 0.62, up));
    col = mix(bottom_color, col, smoothstep(-0.28, 0.02, up));

    // Warm belt near the horizon at sunset.
    float belt = exp(-abs(up) * 7.0);
    col += horizon_color * belt * 0.12 * (1.0 - night);

    vec3 sd = normalize(sun_dir);
    float sdot = dot(dir, sd);

    // Sun disk + halo.
    float disk = smoothstep(1.0 - sun_size, 1.0 - sun_size * 0.55, sdot);
    float halo = pow(max(sdot, 0.0), 90.0);
    col += sun_color * disk * (1.0 - night) * 2.1;
    col += sun_color * halo * 0.55 * (1.0 - night);
    col += sun_color * pow(max(sdot, 0.0), 8.0) * 0.10 * (1.0 - night);

    // Moon opposite the sun.
    vec3 md = -sd;
    float mdot = dot(dir, md);
    float moon = smoothstep(0.9992, 0.99975, mdot);
    float moon_halo = pow(max(mdot, 0.0), 220.0);
    col += moon_color * moon * night * 2.2;
    col += moon_color * moon_halo * 0.35 * night;

    // Stars (hashed points, denser high in the sky).
    float star_mask = smoothstep(0.02, 0.22, up) * night * star_amount;
    if (star_mask > 0.001) {
        vec2 suv = vec2(atan(dir.z, dir.x) * 60.0, dir.y * 110.0);
        vec2 cell = floor(suv);
        float h = hash21(cell);
        float s = smoothstep(0.9955, 1.0, h) * star_mask;
        if (s > 0.001) {
            vec2 f = fract(suv) - 0.5;
            float twinkle = 0.55 + 0.45 * sin(time * 2.4 + h * 60.0);
            col += vec3(0.85, 0.92, 1.0) * s * twinkle * (1.0 - smoothstep(0.0, 0.42, length(f)));
        }
    }

    // Clouds projected onto a virtual dome.
    if (up > 0.005) {
        vec2 cuv = dir.xz / (up + 0.12) * 0.85 + vec2(time * 0.006, time * 0.0035);
        float c = fbm(cuv * 1.25);
        c = smoothstep(0.52, 0.86, c) * cloud_amount;
        vec3 cloud_col = mix(vec3(0.98, 0.86, 0.76), vec3(1.0, 1.0, 1.0), clamp(up, 0.0, 1.0));
        cloud_col = mix(cloud_col, vec3(0.16, 0.19, 0.29), night * 0.82);
        cloud_col += sun_color * pow(max(sdot, 0.0), 12.0) * 0.20 * (1.0 - night);
        col = mix(col, cloud_col, c * smoothstep(0.0, 0.12, up));
    }

    COLOR = col;
}