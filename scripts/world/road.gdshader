shader_type spatial;
// Auto-tiling road tile. The tile picks a road shape from a 4-bit connection mask:
// 1 = north, 2 = east, 4 = south, 8 = west.

render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform int mask = 0;
uniform vec3 asphalt : source_color = vec3(0.145, 0.16, 0.195);
uniform vec3 asphalt_light : source_color = vec3(0.21, 0.23, 0.27);
uniform vec3 sidewalk : source_color = vec3(0.58, 0.60, 0.63);
uniform vec3 curb : source_color = vec3(0.74, 0.75, 0.77);
uniform vec3 line_color : source_color = vec3(0.95, 0.86, 0.55);
uniform float road_half_width = 0.235;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 uv = UV;
    float rw = road_half_width;

    bool cn = (mask & 1) != 0;
    bool ce = (mask & 2) != 0;
    bool cs = (mask & 4) != 0;
    bool cw = (mask & 8) != 0;

    float in_x = step(0.5 - rw, uv.x) * step(uv.x, 0.5 + rw);
    float in_y = step(0.5 - rw, uv.y) * step(uv.y, 0.5 + rw);

    float road = 0.0;
    if (cn) road = max(road, in_x * step(uv.y, 0.5));
    if (cs) road = max(road, in_x * step(0.5, uv.y));
    if (ce) road = max(road, in_y * step(0.5, uv.x));
    if (cw) road = max(road, in_y * step(uv.x, 0.5));
    road = max(road, in_x * in_y);

    float grain = hash21(floor(uv * 190.0));
    vec3 col = mix(sidewalk, asphalt, road);
    col = mix(col, asphalt_light, road * grain * 0.32);

    // Fine sidewalk paving joints.
    vec2 suv = uv * 4.0;
    vec2 sf = abs(fract(suv) - 0.5);
    float joint = smoothstep(0.475, 0.5, max(sf.x, sf.y)) * (1.0 - road);
    col = mix(col, col * 0.86, joint * 0.6);

    // Bright curb line between pavement and asphalt.
    float curb_x = (step(0.5 - rw - 0.035, uv.x) - step(0.5 - rw, uv.x))
                 + (step(0.5 + rw, uv.x) - step(0.5 + rw + 0.035, uv.x));
    float curb_y = (step(0.5 - rw - 0.035, uv.y) - step(0.5 - rw, uv.y))
                 + (step(0.5 + rw, uv.y) - step(0.5 + rw + 0.035, uv.y));
    float curb_mask = 0.0;
    if (cn || cs) curb_mask += clamp(curb_x, 0.0, 1.0) * (cn && uv.y < 0.5 ? 1.0 : (cs && uv.y > 0.5 ? 1.0 : 0.0));
    if (ce || cw) curb_mask += clamp(curb_y, 0.0, 1.0) * (ce && uv.x > 0.5 ? 1.0 : (cw && uv.x < 0.5 ? 1.0 : 0.0));
    col = mix(col, curb, clamp(curb_mask, 0.0, 1.0) * 0.85);

    // Dashed centre markings.
    float dash_y = step(0.5, fract(uv.y * 5.0));
    float dash_x = step(0.5, fract(uv.x * 5.0));
    float line_x = (1.0 - smoothstep(0.012, 0.030, abs(uv.x - 0.5))) * dash_y;
    float line_y = (1.0 - smoothstep(0.012, 0.030, abs(uv.y - 0.5))) * dash_x;
    float marks = 0.0;
    if (cn) marks = max(marks, line_x * step(uv.y, 0.5));
    if (cs) marks = max(marks, line_x * step(0.5, uv.y));
    if (ce) marks = max(marks, line_y * step(0.5, uv.x));
    if (cw) marks = max(marks, line_y * step(uv.x, 0.5));
    col = mix(col, line_color, marks * road);

    ALBEDO = col;
    ROUGHNESS = mix(0.93, 0.78, road);
    SPECULAR = 0.22;
}