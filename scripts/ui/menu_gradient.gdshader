shader_type canvas_item;
// Readability gradient used behind the main-menu copy.

void fragment() {
    vec2 uv = UV;
    float left = smoothstep(0.82, 0.10, uv.x);
    float bottom = smoothstep(-0.1, 0.55, uv.y);
    float a = clamp(left * 0.86 + bottom * 0.20, 0.0, 0.94);
    COLOR = vec4(0.018, 0.030, 0.058, a);
}