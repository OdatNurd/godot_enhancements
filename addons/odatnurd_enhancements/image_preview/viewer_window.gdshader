shader_type canvas_item;

void fragment() {
    vec2 pos = floor(FRAGCOORD.xy / 16.0);
    float pattern = mod(pos.x + pos.y, 2.0);
    COLOR = mix(vec4(0.2, 0.2, 0.2, 1.0), vec4(0.3, 0.3, 0.3, 1.0), pattern);
}