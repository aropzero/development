shader_type canvas_item;
// Soft cinematic vignette drawn above the 3D world.

uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform vec4 tint : source_color = vec4(0.02, 0.035, 0.07, 1.0);

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    uv.x *= 1.08;
    float v = smoothstep(0.42, 1.32, length(uv));
    COLOR = vec4(tint.rgb, v * strength);
}