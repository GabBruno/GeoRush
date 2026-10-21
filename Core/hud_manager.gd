extends MarginContainer

# ==========================================
# --- REFERÊNCIAS DE NODES (INTERFACE VISUAL) ---
# ==========================================
@onready var label_tempo: Label = $Container/Tempo/LabelTempo
@onready var label_dinheiro: Label = $Container/Dinheiro/LabelDinheiro
@onready var barra_expansao: TextureProgressBar = $Container/Expansao/BarraExpansao
@onready var estrelas_container: HBoxContainer = $Container/Reputacao/EstrelasContainer

# ==========================================
# --- INICIALIZAÇÃO DA MARCA D'ÁGUA ---
# ==========================================
func _ready() -> void:
	var camada_wip = CanvasLayer.new()
	camada_wip.layer = 128 # Garante que fique acima de tudo
	
	var texto_wip = Label.new()
	texto_wip.text = "PROJETO EM DESENVOLVIMENTO"
	
	# Estilo: Cinza com 50% de transparência
	texto_wip.add_theme_font_size_override("font_size", 16)
	texto_wip.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.5)) 
	texto_wip.add_theme_constant_override("outline_size", 4)
	texto_wip.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	
	camada_wip.add_child(texto_wip)
	
	# Adiciona diretamente na raiz do jogo (ignora os bloqueios do HUD)
	get_tree().root.call_deferred("add_child", camada_wip)
	
	# Aguarda 1 frame para a Godot calcular o tamanho real do texto na tela
	await get_tree().process_frame
	
	# Calcula a posição matematicamente em pixels (Meio da tela no X, Base da tela no Y)
	var tamanho_tela = get_viewport_rect().size
	texto_wip.position = Vector2(
		(tamanho_tela.x / 2.0) - (texto_wip.size.x / 2.0), # Centraliza no X
		tamanho_tela.y - 30.0 # Posiciona 30 pixels acima do final da tela no Y
	)

# ==========================================
# --- LOOP DE ATUALIZAÇÃO DA INTERFACE (UI) ---
# Sincroniza os dados dos AutoLoads (Managers) com os elementos visuais na tela a cada frame.
# ==========================================
func _process(_delta: float) -> void:
	
	# ==========================================
	# --- 1. ATUALIZAÇÃO FINANCEIRA ---
	# Exibe o saldo atual do mercado formatado com duas casas decimais.
	# ==========================================
	label_dinheiro.text = "$ %.2f" % EconomyManager.dinheiro
	
	
	# ==========================================
	# --- 2. ATUALIZAÇÃO DE REPUTAÇÃO (ESTRELAS VISUAIS) ---
	# Converte o valor numérico de reputação em um feedback visual de 1 a 5 estrelas.
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
	# --- 3. ATUALIZAÇÃO DA BARRA DE EXPANSÃO ---
	# Mostra o progresso de clientes atendidos em relação à meta para evoluir o mercado.
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
	# --- 4. ATUALIZAÇÃO DO RELÓGIO DO PEDIDO ---
	# Feedback dinâmico de cor que aumenta a urgência visual conforme o tempo acaba.
	# ==========================================
	if CustomerManager.pedido_atual.is_empty():
		label_tempo.text = "Aguardando..."
		label_tempo.add_theme_color_override("font_color", Color.WHITE)
	else:
		# Resgata o tempo exato do cronômetro global para exibir na tela
		var tempo = CustomerManager.pegar_tempo_restante()
		
		if tempo > 0:
			label_tempo.text = "%.1fs" % tempo
			
			# Altera a cor do texto para amarelo como alerta de tempo esgotando, e vermelho em urgência máxima
			if tempo > 10.0:
				label_tempo.add_theme_color_override("font_color", Color.WHITE)
			elif tempo < 5.0:
				label_tempo.add_theme_color_override("font_color", Color.ORANGE_RED)
			else:
				label_tempo.add_theme_color_override("font_color", Color.YELLOW)
		else:
			label_tempo.text = "ESGOTADO!"
			label_tempo.add_theme_color_override("font_color", Color.RED)
