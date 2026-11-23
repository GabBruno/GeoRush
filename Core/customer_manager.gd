extends Node

# ==========================================
# --- PROPRIEDADES EXPORTADAS (INSPECTOR) ---
# ==========================================
@export_category("Banco de Dados")
@export var banco_de_produtos: Array[ProductData] = []

# ==========================================
# --- ESTADO E PROGRESSÃO ---
# ==========================================
var formas_liberadas: Array = [ProductData.ShapeType.ESFERA]
var pedido_por_forma: Dictionary = {}
var pedido_atual: Dictionary = {}
var tutorial_concluido: bool = false

# ==========================================
# --- REFERÊNCIAS DE NODES ---
# ==========================================
@export_category("Referências de Nodes")
@onready var timer_pedido: Timer = $TempoPedido
var ui_lista_de_itens: VBoxContainer # Recebe a referência via código de outros scripts

# ==========================================
# --- GERENCIAMENTO DE FORMAS ---
# ==========================================
func desbloquear_forma(nova_forma: ProductData.ShapeType) -> void:
	# Adiciona uma nova forma à lista de formas permitidas, se ainda não existir
	if not formas_liberadas.has(nova_forma):
		formas_liberadas.append(nova_forma)
		
func tem_pedido_ativo() -> bool: 
	return not pedido_atual.is_empty() or not pedido_por_forma.is_empty()	
# ==========================================
# --- LÓGICA DE PEDIDOS ---
# ==========================================
func gerar_novo_pedido(carrinho_do_jogador: Array = []) -> void:
	pedido_por_forma.clear()
	pedido_atual.clear()
	
	# --- PEDIDO FIXO DO TUTORIAL (1º ATENDIMENTO) ---
	if not tutorial_concluido:
		var produto_tutorial: ProductData = null
		for produto in banco_de_produtos:
			if produto.product_name.to_lower().strip_edges() == "maçã":
				produto_tutorial = produto
				break

		# Segurança caso o nome do produto tenha mudado
		if produto_tutorial == null and not banco_de_produtos.is_empty():
			produto_tutorial = banco_de_produtos[0]

		if produto_tutorial != null:
			pedido_atual[produto_tutorial] = 2
			timer_pedido.start(120.0) # Tempo bem folgado para o 1º atendimento
			atualizar_lista_visual(carrinho_do_jogador)
			return
	
	# ==========================================
	# 1. Ajuste Automático de Dificuldade
	# ==========================================
	var min_tipos = 1
	var max_tipos = 2
	var min_quant = 1
	var max_quant = 3
	
	match EconomyManager.nivel_expansao:
		0: # Fase 1 (Inicial)
			min_tipos = 1
			max_tipos = 2
			min_quant = 1
			max_quant = 3
		1: # Fase 2 (Primeira expansão)
			min_tipos = 2
			max_tipos = 3
			min_quant = 1
			max_quant = 4
		2: # Fase 3 (Segunda expansão)
			min_tipos = 3
			max_tipos = 5
			min_quant = 2
			max_quant = 5
		_: # Níveis superiores
			min_tipos = 4
			max_tipos = 6
			min_quant = 3
			max_quant = 5
			
	var quantidade_de_tipos = randi_range(min_tipos, max_tipos)
	
	# ==========================================
	# 2. Sorteio de Produtos
	# ==========================================
	# Filtra os produtos disponíveis garantindo que apenas itens com formas liberadas sejam sorteados
	var produtos_disponiveis: Array[ProductData] = []
	for produto in banco_de_produtos:
		if formas_liberadas.has(produto.shape):
			produtos_disponiveis.append(produto)
	
	# Limpa os itens visuais anteriores da interface (Prancheta)
	if ui_lista_de_itens:
		for filho in ui_lista_de_itens.get_children():
			filho.queue_free()
			
	# Embaralha a lista filtrada para garantir aleatoriedade nos pedidos
	produtos_disponiveis.shuffle() 
	
	# ==========================================
	# 3. Montagem do Pedido e Interface
	# ==========================================
	# Sorteia os produtos baseados na quantidade calculada para a fase atual
	for i in range(min(quantidade_de_tipos, produtos_disponiveis.size())):
		var produto_escolhido = produtos_disponiveis[i]
		
		# Define a quantidade aleatória dinamicamente baseada na fase
		var quantidade = randi_range(min_quant, max_quant) 
		
		pedido_atual[produto_escolhido] = quantidade
		
		# Cria a representação em texto inicial na interface (Notepad)
		if ui_lista_de_itens:
			var texto_item = Label.new()
			var nome_da_forma = _pegar_nome_da_forma(produto_escolhido.shape)
			
			texto_item.text = "- " + produto_escolhido.product_name + " x" + str(quantidade) + " -> Forma: " + nome_da_forma
			texto_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			texto_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			texto_item.custom_minimum_size = Vector2(140, 0) 
			
			# Mantém o design padronizado com o contorno e tamanho que fizemos antes!
			texto_item.add_theme_constant_override("outline_size", 4)
			texto_item.add_theme_color_override("font_outline_color", Color.BLACK)
			texto_item.add_theme_font_size_override("font_size", 24)
			
			ui_lista_de_itens.add_child(texto_item)
				
	# A partir da 1ª expansão, inclui um desafio por forma geométrica
	if EconomyManager.nivel_expansao >= 1: 
		var formas_avancadas := formas_liberadas.filter(func(f): return f != ProductData.ShapeType.ESFERA)
		if not formas_avancadas.is_empty():
			var forma_sorteada = formas_avancadas.pick_random()
			var qtd_forma = randi_range(2, 3)
			pedido_por_forma[forma_sorteada] = qtd_forma
		
	# Inicia o cronômetro base ajustado pela dificuldade (25s na fase 1, 35s na fase 2, etc.)
	var total_unidades := 0
	for qtd in pedido_atual.values(): 
		total_unidades += qtd
	var tempo_base := 5.0 + (EconomyManager.nivel_expansao * 2.0) + (total_unidades * 4.0)
	timer_pedido.start(tempo_base)
	
	# Atualiza a interface visual para o formato definitivo (com ícones e feedback)
	atualizar_lista_visual(carrinho_do_jogador)

func pegar_tempo_restante() -> float:
	return timer_pedido.time_left

# ==========================================
# --- FUNÇÕES AUXILIARES E INTERFACE ---
# ==========================================
func _pegar_nome_da_forma(shape_enum: int) -> String:
	"""
	Converte o Enum (inteiro) armazenado na Godot para uma String legível.
	Utilizado para exibir o nome da forma geométrica na interface do jogador.
	"""
	match shape_enum:
		ProductData.ShapeType.ESFERA: return "Esfera"
		ProductData.ShapeType.CILINDRO: return "Cilindro"
		ProductData.ShapeType.PARALELEPIPEDO: return "Paralelepípedo"
		ProductData.ShapeType.CUBO: return "Cubo"
	return "Desconhecida"
	
func atualizar_lista_visual(carrinho_do_jogador: Array) -> void:
	# Limpa os itens visuais antigos para reconstruir a lista atualizada
	var sobras_carrinho := carrinho_do_jogador.duplicate()
	if ui_lista_de_itens:
		for child in ui_lista_de_itens.get_children():
			child.queue_free()
			
		# ==========================================
		# 1. DESENHA OS ITENS QUE O CLIENTE PEDIU
		# ==========================================
		for produto in pedido_atual.keys():
			var quantidade_pedida = pedido_atual[produto]
			
			var quantidade_no_carrinho = 0
			for item in carrinho_do_jogador:
				if item.product_name == produto.product_name:
					quantidade_no_carrinho += 1
					
			var nome_forma = _pegar_nome_da_forma(produto.shape)
			
			var linha = HBoxContainer.new()
			
			if produto.icon:
				var icone = TextureRect.new()
				icone.texture = produto.icon
				icone.custom_minimum_size = Vector2(32, 32)
				icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				linha.add_child(icone)
				
			var texto = Label.new()
			texto.text = str(produto.product_name) + " (" + nome_forma + "): " + str(quantidade_no_carrinho) + " / " + str(quantidade_pedida)
			texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			#texto.add_theme_constant_override("outline_size", 8) # Tamanho do contorno 
			#texto.add_theme_color_override("font_outline_color", Color.BLACK) # Cor do contorno	
			texto.add_theme_font_size_override("font_size", 14)
			
			if quantidade_no_carrinho > quantidade_pedida:
				texto.add_theme_color_override("font_color", Color.ORANGE)
			elif quantidade_no_carrinho == quantidade_pedida:
				texto.add_theme_color_override("font_color", Color.GREEN)
			else:
				texto.add_theme_color_override("font_color", Color.BLACK)
				
			linha.add_child(texto)
			ui_lista_de_itens.add_child(linha)
			
			
		# Desenha pedidos por forma geométrica (aceita qualquer produto daquela forma)
		for forma in pedido_por_forma.keys():
			var qtd_pedida = pedido_por_forma[forma]
			var qtd_no_carrinho = 0
			for item in sobras_carrinho:
				if item.shape == forma:
					qtd_no_carrinho += 1

			var texto = Label.new()
			var nome_forma = _pegar_nome_da_forma(forma)
			texto.text = "Qualquer " + nome_forma + ": " + str(qtd_no_carrinho) + " / " + str(qtd_pedida)
			texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			texto.add_theme_font_size_override("font_size", 14)

			if qtd_no_carrinho > qtd_pedida:
				texto.add_theme_color_override("font_color", Color.ORANGE)
			elif qtd_no_carrinho == qtd_pedida:
				texto.add_theme_color_override("font_color", Color.GREEN)
			else:
				texto.add_theme_color_override("font_color", Color.DARK_BLUE)

			ui_lista_de_itens.add_child(texto)
		
		# ==========================================
		# 2. IDENTIFICA E DESENHA ITENS ERRADOS/EXTRAS
		# ==========================================
		# Cria um dicionário temporário para agrupar e contar os produtos errados
		var itens_errados = {} 
		
		for item in carrinho_do_jogador:
			var faz_parte_do_pedido = false
			
			# Checa se o item que está na mão faz parte das chaves do pedido
			for produto_pedido in pedido_atual.keys():
				if item.product_name == produto_pedido.product_name:
					faz_parte_do_pedido = true
					break
			
			# Se não faz parte, adiciona na nossa contagem de intrusos
			if not faz_parte_do_pedido:
				if itens_errados.has(item):
					itens_errados[item] += 1
				else:
					itens_errados[item] = 1
					
		# Agora cria as linhas visuais para avisar o jogador dos erros
		for produto_errado in itens_errados.keys():
			var quantidade_errada = itens_errados[produto_errado]
			var nome_forma = _pegar_nome_da_forma(produto_errado.shape)
			
			var linha_errada = HBoxContainer.new()
			
			if produto_errado.icon:
				var icone = TextureRect.new()
				icone.texture = produto_errado.icon
				icone.custom_minimum_size = Vector2(32, 32)
				icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				linha_errada.add_child(icone)
				
			var texto_errado = Label.new()
			# Adiciona a tag "(Não Pedido!)" para deixar claro o motivo de estar vermelho
			texto_errado.text = str(produto_errado.product_name) + " (" + nome_forma + "): " + str(quantidade_errada) + " (Não Pedido!)"
			
			texto_errado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			texto_errado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			#texto_errado.add_theme_constant_override("outline_size", 4)
			#texto_errado.add_theme_color_override("font_outline_color", Color.BLACK)
			
			texto_errado.add_theme_font_size_override("font_size", 14)
			
			# Força a cor vermelha para itens que não deveriam estar ali
			texto_errado.add_theme_color_override("font_color", Color.RED)
			
			linha_errada.add_child(texto_errado)
			ui_lista_de_itens.add_child(linha_errada)

# ==========================================
# --- RESET DE DADOS ---
# ==========================================
func resetar_clientes() -> void:
	""" Limpa os pedidos antigos e bloqueia as formas avançadas novamente. """
	
	pedido_por_forma.clear()
	
	# Volta a ter apenas a Esfera liberada (Fase 1)
	formas_liberadas = [ProductData.ShapeType.ESFERA] 
	pedido_atual.clear()
	
	# Para o cronômetro se ele estiver rodando
	if timer_pedido:
		timer_pedido.stop()
		
	# Limpa a interface visual da prancheta se houver textos sobrando
	if ui_lista_de_itens:
		for filho in ui_lista_de_itens.get_children():
			filho.queue_free()
			
	
	tutorial_concluido = false
