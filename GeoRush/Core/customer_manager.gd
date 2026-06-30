extends Node

@export_category("Banco de Dados")
@export var banco_de_produtos: Array[ProductData] = []

# --- Estado e Progressão ---
var formas_liberadas: Array = [ProductData.ShapeType.ESFERA]
var pedido_atual: Dictionary = {}

@export_category("Referências de Nodes")
@onready var timer_pedido: Timer = $TempoPedido
var ui_lista_de_itens: VBoxContainer # Recebe a referência via código de outros scripts

# --- Gerenciamento de Formas ---
func desbloquear_forma(nova_forma: ProductData.ShapeType) -> void:
	# Adiciona uma nova forma à lista de formas permitidas, se ainda não existir
	if not formas_liberadas.has(nova_forma):
		formas_liberadas.append(nova_forma)
		
# --- Lógica de Pedidos ---
func gerar_novo_pedido(quantidade_de_tipos: int, carrinho_do_jogador: Array = []) -> void:
	pedido_atual.clear()
	
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
	
	# Sorteia os produtos baseados na quantidade solicitada para a fase atual
	for i in range(min(quantidade_de_tipos, produtos_disponiveis.size())):
		var produto_escolhido = produtos_disponiveis[i]
		# Define uma quantidade aleatória (de 1 a 3) para cada produto pedido
		var quantidade = randi_range(1, 3) 
		
		pedido_atual[produto_escolhido] = quantidade
		
		# Cria a representação em texto inicial na interface (Notepad)
		if ui_lista_de_itens:
			var texto_item = Label.new()
			var nome_da_forma = _pegar_nome_da_forma(produto_escolhido.shape)
			
			texto_item.text = "- " + produto_escolhido.product_name + " x" + str(quantidade) + " -> Forma: " + nome_da_forma
			texto_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			texto_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			texto_item.custom_minimum_size = Vector2(140, 0) 
			
			ui_lista_de_itens.add_child(texto_item)
				
	# Inicia o cronômetro base com 30 segundos
	timer_pedido.start(30.0)
	
	# Atualiza a interface visual para o formato definitivo (com ícones e feedback)
	atualizar_lista_visual(carrinho_do_jogador)

func pegar_tempo_restante() -> float:
	return timer_pedido.time_left

# --- Funções Auxiliares e Interface ---
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
			
			if quantidade_no_carrinho > quantidade_pedida:
				texto.add_theme_color_override("font_color", Color.ORANGE)
			elif quantidade_no_carrinho == quantidade_pedida:
				texto.add_theme_color_override("font_color", Color.GREEN)
			else:
				texto.add_theme_color_override("font_color", Color.BLACK)
				
			linha.add_child(texto)
			ui_lista_de_itens.add_child(linha)
			
			
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
			
			# Força a cor vermelha para itens que não deveriam estar ali
			texto_errado.add_theme_color_override("font_color", Color.RED)
			
			linha_errada.add_child(texto_errado)
			ui_lista_de_itens.add_child(linha_errada)
