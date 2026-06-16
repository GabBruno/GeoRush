extends MarginContainer

# --- Referências de Nodes (Interface) ---
@onready var label_tempo: Label = $Container/Tempo/LabelTempo
@onready var label_dinheiro: Label = $Container/Dinheiro/LabelDinheiro
@onready var label_reputacao: Label = $Container/Reputacao/LabelReputacao
@onready var barra_expansao: ProgressBar = $Container/Expansao/BarraExpansao

func _process(_delta: float) -> void:
	
	# ==========================================
	# --- 1. Atualização Financeira ---
	# ==========================================
	label_dinheiro.text = "$ %.2f" % EconomyManager.dinheiro
	
	
	# ==========================================
	# --- 2. Atualização de Reputação (Estrelas) ---
	# ==========================================
	var rep = EconomyManager.reputacao
	var estrelas = ""
	
	# Define a quantidade de estrelas baseando-se nos marcos de reputação atingidos
	if rep >= 50:
		estrelas = "⭐⭐⭐⭐⭐"
		label_reputacao.add_theme_color_override("font_color", Color.BLACK)
	elif rep >= 30:
		estrelas = "⭐⭐⭐⭐"
		label_reputacao.add_theme_color_override("font_color", Color.BLACK)
	elif rep >= 15:
		estrelas = "⭐⭐⭐"
		label_reputacao.add_theme_color_override("font_color", Color.BLACK)
	elif rep > 0:
		estrelas = "⭐⭐"
		label_reputacao.add_theme_color_override("font_color", Color.BLACK)
	else:
		estrelas = "⭐"
		label_reputacao.add_theme_color_override("font_color", Color.BLACK)
		
	# Concatena o texto base com as estrelas calculadas
	label_reputacao.text = estrelas
	
	
	# ==========================================
	# --- 3. Atualização da Barra de Expansão ---
	# ==========================================
	if EconomyManager.nivel_expansao < EconomyManager.expansoes_maximas:
		# Atualiza a barra com o progresso atual rumo à próxima meta de clientes
		barra_expansao.max_value = EconomyManager.meta_expansao
		barra_expansao.value = EconomyManager.clientes_atendidos
	else:
		# Trava a barra visualmente em 100% caso o mercado já esteja no nível máximo
		barra_expansao.max_value = 1
		barra_expansao.value = 1
	
	
	# ==========================================
	# --- 4. Atualização do Relógio do Pedido ---
	# ==========================================
	if CustomerManager.pedido_atual.is_empty():
		label_tempo.text = "Aguardando..."
		label_tempo.add_theme_color_override("font_color", Color.WHITE)
	else:
		# Resgata o tempo exato do cronômetro global para exibir na tela
		var tempo = CustomerManager.pegar_tempo_restante()
		
		if tempo > 0:
			label_tempo.text = "%.1fs" % tempo
			
			# Altera a cor do texto para amarelo como alerta de tempo esgotando
			if tempo > 10.0:
				label_tempo.add_theme_color_override("font_color", Color.WHITE)
			if tempo < 5.0:
				label_tempo.add_theme_color_override("font_color", Color.ORANGE_RED)
			else:
				label_tempo.add_theme_color_override("font_color", Color.YELLOW)
		else:
			label_tempo.text = "ESGOTADO!"
			label_tempo.add_theme_color_override("font_color", Color.RED)
