shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width = 0.06;
uniform float outline_glow = 1.0;

varying vec3 local_pos;

void vertex() {
    // VERTEX в MultiMeshInstance3D уже в локальных координатах инстанса.
    // Стандартный куб Godot: от -0.5 до 0.5. Приводим к 0..1.
    local_pos = VERTEX + vec3(0.5);
}

void fragment() {
    vec3 p = clamp(local_pos, 0.0, 1.0);

    // Расстояние до ближайшей грани по каждой оси.
    vec3 d = min(p, vec3(1.0) - p);

    // Определяем, к какой грани принадлежит фрагмент (наименьшее d).
    // Используем step, чтобы избежать сравнения float на равенство.
    vec3 is_face = step(d, vec3(min(min(d.x, d.y), d.z)) + vec3(1e-5));
    // is_face будет содержать 1.0 по «прижатой» оси.

    // Две оставшиеся оси — по ним считаем расстояние до рёбер.
    vec2 edge_d;
    if (is_face.x > 0.5) {
        edge_d = d.yz;
    } else if (is_face.y > 0.5) {
        edge_d = d.xz;
    } else {
        edge_d = d.xy;
    }

    float e = min(edge_d.x, edge_d.y);
    float outline = 1.0 - smoothstep(outline_width * 0.5, outline_width, e);

    // Внутри грани — прозрачно, по краю — обводка.
    ALBEDO = tint.rgb * outline_glow;
    ALPHA = outline * tint.a;

    // Отсекаем полностью прозрачные пиксели, чтобы не писали в буфер.
    if (ALPHA < 0.01) {
        discard;
    }
}