shader_type spatial;
// Island ground: soft grass, sandy shore and a subtle build grid.

render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform vec3 grass_dark : source_color = vec3(0.16, 0.38, 0.22);
uniform vec3 grass_light : source_color = vec3(0.32, 0.58, 0.30);
uniform vec3 sand_color : source_color = vec3(0.86, 0.78, 0.58);
uniform vec3 cliff_a : source_color = vec3(0.32, 0.29, 0.24);
uniform vec3 cliff_b : source_color = vec3(0.17, 0.16, 0.14);
uniform float buildable_half = 16.0;
uniform float island_half = 20.0;
uniform float tile = 2.0;

varying vec3 wpos;
varying vec3 wnrm;

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
        p = p * 2.07 + vec2(11.3, 7.1);
        a *= 0.5;
    }
    return v;
}

void vertex() {
    wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
    float edge = max(abs(wpos.x), abs(wpos.z));
    float n = fbm(wpos.xz * 0.28);
    float n2 = vnoise(wpos.xz * 1.7);

    if (wnrm.y > 0.45) {
        // Gentle diagonal mowing stripes keep the lawn from looking flat.
        float stripe = sin((wpos.x + wpos.z) * 0.9) * 0.5 + 0.5;
        vec3 col = mix(grass_dark, grass_light, n * 0.75 + stripe * 0.12 + n2 * 0.10);

        // Sandy beach around the rim.
        float sandmix = smoothstep(island_half - 2.6, island_half - 0.15, edge);
        col = mix(col, sand_color * (0.9 + 0.16 * n2), sandmix * 0.92);

        // Build grid (only on the buildable plateau).
        if (edge < buildable_half - 0.02) {
            vec2 g = abs(fract((wpos.xz + buildable_half) / tile) - 0.5);
            float line = smoothstep(0.455, 0.497, max(g.x, g.y));
            col = mix(col, col * 0.80, line * 0.42);
            // A soft glow in tile centres so taps feel magnetic.
            float center = smoothstep(0.36, 0.0, length(g));
            col += vec3(0.03, 0.05, 0.03) * center;
        }

        ALBEDO = col;
    } else {
        float band = sin(wpos.y * 4.2 + n * 3.0) * 0.5 + 0.5;
        vec3 col = mix(cliff_b, cliff_a, smoothstep(-3.2, 0.0, wpos.y));
        col = mix(col, col * (0.7 + band * 0.45), 0.55);
        col *= 0.88 + 0.22 * n2;
        ALBEDO = col;
    }
    ROUGHNESS = 0.94;
    SPECULAR = 0.15;
}