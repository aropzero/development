shader_type spatial;
// Animated stylised ocean that surrounds the island.

render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform vec3 deep_color : source_color = vec3(0.035, 0.20, 0.30);
uniform vec3 shallow_color : source_color = vec3(0.10, 0.52, 0.62);
uniform vec3 foam_color : source_color = vec3(0.86, 0.95, 1.0);
uniform vec3 sky_tint : source_color = vec3(0.58, 0.78, 0.95);
uniform float time = 0.0;
uniform float island_half = 20.0;
uniform float shore_width = 2.6;
uniform float wave_strength = 0.045;

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

void vertex() {
    wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float w = sin(wpos.x * 0.42 + time * 0.85) * 0.5
            + cos(wpos.z * 0.51 + time * 0.66) * 0.35
            + sin((wpos.x + wpos.z) * 0.21 + time * 0.42) * 0.55;
    VERTEX.y += w * wave_strength;
    wnrm = normalize(vec3(
        cos(wpos.x * 0.42 + time * 0.85) * 0.10,
        1.0,
        -sin(wpos.z * 0.51 + time * 0.66) * 0.10
    ));
}

void fragment() {
    float d = max(abs(wpos.x), abs(wpos.z));
    float shore = 1.0 - smoothstep(island_half, island_half + shore_width * 2.0, d);
    float n = vnoise(wpos.xz * 0.22 + vec2(time * 0.045, time * 0.03));
    float n2 = vnoise(wpos.xz * 0.9 - vec2(time * 0.11, time * 0.07));

    vec3 col = mix(deep_color, shallow_color, n * 0.55 + shore * 0.55);
    col += vec3(0.02, 0.05, 0.06) * n2;

    float fres = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 3.0);
    col = mix(col, sky_tint, fres * 0.55);

    // Foam ring hugging the shoreline.
    float band = smoothstep(island_half - 0.1, island_half + 0.45, d)
               * (1.0 - smoothstep(island_half + 0.55, island_half + 2.4, d));
    float foamy = band * (0.35 + 0.75 * n2);
    col = mix(col, foam_color, clamp(foamy, 0.0, 0.9));

    // Sparkles.
    float sparkle = smoothstep(0.86, 1.0, n2) * (0.25 + 0.35 * shore);
    col += vec3(0.4, 0.6, 0.7) * sparkle;

    ALBEDO = col;
    ROUGHNESS = 0.12;
    METALLIC = 0.0;
    SPECULAR = 0.72;
}