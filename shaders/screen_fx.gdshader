// Полноэкранный оверлей ScreenFX: читает уже нарисованный экран и накладывает
// тонировку, обесцвечивание, хроматическую аберрацию и виньетку.
// Все параметры — итог смешивания активных пресетов, выставляются из screen_fx.gd.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.0;
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float aberration : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - 0.5;

	// Аберрация: R и B сдвигаются от центра в разные стороны — сильнее к краям.
	vec2 shift = dir * aberration * 0.02;
	vec3 col;
	col.r = texture(screen_tex, uv + shift).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - shift).b;

	float gray = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(gray), desaturate);
	col = mix(col, tint_color.rgb, tint_amount);

	// Виньетка: 0 в центре, растёт к краям (с поправкой на широкий экран).
	float d = length(dir * vec2(1.0, 0.7)) * 1.8;
	float v = clamp(smoothstep(0.35, 1.0, d) * vignette_amount, 0.0, 1.0);
	col = mix(col, vignette_color.rgb, v);

	COLOR = vec4(col, 1.0);
}
