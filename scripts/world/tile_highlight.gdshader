shader_type spatial;
// Animated tile marker used for placement previews and selections.

render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(0.27, 0.87, 0.76, 0.75);
uniform float time = 0.0;
uniform float width = 0.045;

void fragment() {
    vec2 uv = UV;
    vec2 d = min(uv, vec2(1.0) - uv);
    float m = min(d.x, d.y);

    float border = 1.0 - smoothstep(width * 0.35, width, m);
    float fill = smoothstep(width, 0.22, m) * 0.10 * (0.75 + 0.25 * sin(time * 3.2));
    float corner = smoothstep(0.28, 0.0, length(min(uv, vec2(1.0) - uv))) * 0.0;

    float alpha = color.a * max(border * 0.95, fill + corner);
    ALBEDO = color.rgb;
    ALPHA = alpha;
    EMISSION = color.rgb * (1.6 * border + 0.25) * 0.9;
    ROUGHNESS = 0.4;
}