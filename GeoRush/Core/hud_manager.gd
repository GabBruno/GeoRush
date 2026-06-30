extends MarginContainer

# --- Referências de Nodes (Interface) ---
@onready var label_tempo: Label = $Container/Tempo/LabelTempo
@onready var label_dinheiro: Label = $Container/Dinheiro/LabelDinheiro
@onready var barra_expansao: TextureProgressBar = $Container/Expansao/BarraExpansao
@onready var estrelas_container: HBoxContainer = $Container/Reputacao/EstrelasContainer

func _process(_delta: float) -> void:
	
	# ==========================================
	# --- 1. Atualização Financeira ---
	# ==========================================
	label_dinheiro.text = "$ %.2f" % EconomyManager.dinheiro
	
	
	# ==========================================
	# --- 2. Atualização de Reputação (Estrelas Visuais em Pixel Art) ---
	# ==========================================
	var rep = EconomyManager.reputacao
	var qtd_estrelas = 1
	
	# Define a quantidade de estrelas baseando-se nos marcos de reputação atingidos
	if rep >= 50:
		qtd_estrelas = 5
	elif rep >= 30:
		qtd_estrelas = 4
	elif rep >= 15:
		qtd_estrelas = 3
	elif rep > 0:
		qtd_estrelas = 2
	else:
		qtd_estrelas = 1
		
	# Percorre as 5 imagens no container e mostra apenas a quantidade calculada
	if estrelas_container:
		for i in range(estrelas_container.get_child_count()):
			if i < qtd_estrelas:
				estrelas_container.get_child(i).show()
			else:
				estrelas_container.get_child(i).hide()
	
	
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
			elif tempo < 5.0:
				label_tempo.add_theme_color_override("font_color", Color.ORANGE_RED)
			else:
				label_tempo.add_theme_color_override("font_color", Color.YELLOW)
		else:
			label_tempo.text = "ESGOTADO!"
			label_tempo.add_theme_color_override("font_color", Color.RED)
