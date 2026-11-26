shader_type canvas_item;

uniform float raio : hint_range(0.05, 0.6) = 0.20;
uniform float suavidade : hint_range(0.01, 0.4) = 0.14;
uniform float opacidade : hint_range(0.0, 0.95) = 0.62;
uniform float intensidade_anel : hint_range(0.0, 1.0) = 0.55;
uniform vec4 cor_anel : source_color = vec4(1.0, 0.85, 0.25, 1.0);

void fragment() {
	float alpha_node = COLOR.a;

	// Corrige a proporção da tela para o destaque ser um círculo perfeito
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float dist = distance((UV - vec2(0.5, 0.5)) * aspect, vec2(0.0));

	// Pulso suave no anel de destaque
	float pulso = sin(TIME * 4.0) * 0.008;
	float r = raio + pulso;

	// Sombra ao redor do item focado
	float mascara = smoothstep(r, r + suavidade, dist);
	vec4 fundo = vec4(0.0, 0.0, 0.0, mascara * opacidade);

	// Brilho circular sutil em volta do foco
	float anel = exp(-pow((dist - r) / 0.014, 2.0)) * intensidade_anel;
	vec4 cor_final = mix(fundo, cor_anel, anel);
	cor_final.a = max(fundo.a, anel) * alpha_node;

	COLOR = cor_final;
}