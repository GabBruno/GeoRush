shader_type canvas_item;

uniform float progresso : hint_range(0.0, 1.0) = 0.0;
uniform int resolucao_pixels : hint_range(11, 25, 2) = 15;
uniform vec4 cor_fundo : source_color = vec4(0.96, 0.96, 0.92, 1.0);
uniform vec4 cor_vermelho : source_color = vec4(0.90, 0.18, 0.18, 1.0);
uniform vec4 cor_borda : source_color = vec4(0.12, 0.12, 0.15, 1.0);

void fragment() {
	// Quantiza o UV em uma grade fixa para gerar pixels nítidos em qualquer zoom
	float res = float(resolucao_pixels);
	vec2 uv_pixel = (floor(UV * res) + vec2(0.5)) / res;
	vec2 p = uv_pixel - vec2(0.5);
	float d = length(p);

	if (d > 0.49) {
		discard;
	}

	if (d > 0.41) {
		COLOR = cor_borda;
	} else {
		// Ângulo no sentido horário começando às 12h (0.0 a 1.0)
		float angulo = atan(p.x, -p.y);
		if (angulo < 0.0) {
			angulo += 6.2831853;
		}
		float angulo_norm = angulo / 6.2831853;

		// Preenche de vermelho conforme a paciência se esgota
		vec4 cor = (angulo_norm <= progresso && progresso > 0.001) ? cor_vermelho : cor_fundo;

		// Ponteiro acompanhando o preenchimento vermelho
		float rad = progresso * 6.2831853;
		vec2 dir = vec2(sin(rad), -cos(rad));
		float proj = clamp(dot(p, dir), 0.0, 0.32);
		float dist_ponteiro = length(p - dir * proj);

		if (dist_ponteiro < 0.042 || d < 0.06) {
			cor = cor_borda;
		}

		COLOR = cor;
	}
}