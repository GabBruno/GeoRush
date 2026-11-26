extends Node

# ==========================================
# --- PROPRIEDADES EXPORTADAS (INSPECTOR) ---
# ==========================================
@export_category("Banco de Dados")
@export var banco_de_produtos: Array[ProductData] = []

@export_category("Ícones das Formas (Pixel Art)")
@export var icone_esfera: Texture2D
@export var icone_cilindro: Texture2D
@export var icone_paralelepipedo: Texture2D

@export_category("Frequência de Pedidos por Forma")
@export_range(0.0, 1.0, 0.05) var chance_forma_nivel_0: float = 0.25
@export_range(0.0, 1.0, 0.05) var chance_pedido_por_forma: float = 0.40
@export_range(0.0, 1.0, 0.05) var chance_cliente_vip: float = 0.15
@export var evitar_formas_seguidas: bool = true

# ==========================================
# --- ESTADO E PROGRESSÃO ---
# ==========================================
var formas_liberadas: Array = [ProductData.ShapeType.ESFERA]
var pedido_atual: Dictionary = {}      # ProductData -> int
var pedido_por_forma: Dictionary = {}  # ProductData.ShapeType -> int
var tutorial_concluido: bool = false
var cliente_vip_ativo: bool = false
var ultima_forma_sorteada: int = -1
var ultimo_pedido_teve_forma: bool = false

# ==========================================
# --- REFERÊNCIAS DE NODES ---
# ==========================================
@export_category("Referências de Nodes")
@onready var timer_pedido: Timer = $TempoPedido
var ui_lista_de_itens: VBoxContainer


# ==========================================
# --- FUNÇÕES DE ESTADO ---
# ==========================================
func tem_pedido_ativo() -> bool:
	return not pedido_atual.is_empty() or not pedido_por_forma.is_empty()


func desbloquear_forma(nova_forma: ProductData.ShapeType) -> void:
	if not formas_liberadas.has(nova_forma):
		formas_liberadas.append(nova_forma)


func _normalizar_nome(nome: String) -> String:
	return nome.to_lower().strip_edges()


# ==========================================
# --- LÓGICA DE PEDIDOS (DIFICULDADE PROGRESSIVA) ---
# ==========================================
func gerar_novo_pedido(carrinho_do_jogador: Array = []) -> void:
	pedido_atual.clear()
	pedido_por_forma.clear()
	cliente_vip_ativo = false

	# --- 1. PEDIDO FIXO DO TUTORIAL (1º ATENDIMENTO) ---
	if not tutorial_concluido:
		var produto_tutorial: ProductData = null
		for produto in banco_de_produtos:
			if _normalizar_nome(produto.product_name) == "maçã":
				produto_tutorial = produto
				break
		if produto_tutorial == null and not banco_de_produtos.is_empty():
			produto_tutorial = banco_de_produtos[0]

		if produto_tutorial != null:
			pedido_atual[produto_tutorial] = 2
			timer_pedido.start(120.0)
			atualizar_lista_visual(carrinho_do_jogador)
			return

	# --- 2. AJUSTE DE DIFICULDADE POR EXPANSÃO ---
	var min_tipos: int = 2
	var max_tipos: int = 3
	var min_quant: int = 2
	var max_quant: int = 3

	if EconomyManager.modo_infinito:
		min_tipos = 5; max_tipos = 6; min_quant = 2; max_quant = 4
	else:
		match EconomyManager.nivel_expansao:
			0:
				# Só Esferas liberadas (3 produtos disponíveis)
				min_tipos = 2; max_tipos = 3; min_quant = 2; max_quant = 3
			1:
				# Esferas + Cilindros (6 produtos disponíveis)
				min_tipos = 3; max_tipos = 4; min_quant = 2; max_quant = 3
			_:
				# Todos os 3 setores liberados (9 produtos disponíveis)
				min_tipos = 4; max_tipos = 5; min_quant = 2; max_quant = 4

	# --- 3. SORTEIO DO PEDIDO POR FORMA (ESFERA, CILINDRO OU PARALELEPÍPEDO) ---
	var incluir_pedido_por_forma: bool = false
	var pode_sortear_forma: bool = not (evitar_formas_seguidas and ultimo_pedido_teve_forma)

	if pode_sortear_forma:
		if EconomyManager.nivel_expansao == 0:
			incluir_pedido_por_forma = randf() < chance_forma_nivel_0
		else:
			incluir_pedido_por_forma = randf() < chance_pedido_por_forma

	if incluir_pedido_por_forma and not formas_liberadas.is_empty():
		var formas_candidatas: Array = formas_liberadas.duplicate()

		if formas_candidatas.size() > 1 and ultima_forma_sorteada != -1:
			formas_candidatas.erase(ultima_forma_sorteada)

		var forma_sorteada: int = formas_candidatas.pick_random()
		ultima_forma_sorteada = forma_sorteada

		# No nível 0 o pedido genérico fica sozinho na lista, então pede mais unidades
		if EconomyManager.nivel_expansao == 0:
			pedido_por_forma[forma_sorteada] = randi_range(4, 6)
		elif EconomyManager.nivel_expansao == 1:
			pedido_por_forma[forma_sorteada] = randi_range(3, 4)
		else:
			pedido_por_forma[forma_sorteada] = randi_range(3, 5)

	ultimo_pedido_teve_forma = not pedido_por_forma.is_empty()

	# --- 4. SORTEIO DE PRODUTOS NORMAIS (ESPECÍFICOS) ---
	var produtos_disponiveis: Array[ProductData] = []
	for produto in banco_de_produtos:
		if formas_liberadas.has(produto.shape) and not pedido_por_forma.has(produto.shape):
			produtos_disponiveis.append(produto)

	produtos_disponiveis.shuffle()
	var quantidade_de_tipos: int = randi_range(min_tipos, max_tipos)

	# Se já existe um pedido por forma na lista, ele conta como 1 dos tipos
	if not pedido_por_forma.is_empty():
		quantidade_de_tipos = maxi(1, quantidade_de_tipos - 1)

	for i in range(mini(quantidade_de_tipos, produtos_disponiveis.size())):
		var produto_escolhido: ProductData = produtos_disponiveis[i]
		pedido_atual[produto_escolhido] = randi_range(min_quant, max_quant)

	# --- 5. CÁLCULO DE TEMPO BASEADO EM PRATELEIRAS (TIPOS) + UNIDADES ---
	var total_unidades: int = 0
	for qtd in pedido_atual.values():
		total_unidades += int(qtd)
	for qtd_forma in pedido_por_forma.values():
		total_unidades += int(qtd_forma)

	var total_tipos: int = pedido_atual.size() + pedido_por_forma.size()
	var tempo_base: float = 8.0 + (EconomyManager.nivel_expansao * 2.5) + (total_tipos * 3.2) + (total_unidades * 0.9)
	if EconomyManager.modo_infinito:
		tempo_base = maxf(16.0, tempo_base - 3.0)

	timer_pedido.start(tempo_base)
	atualizar_lista_visual(carrinho_do_jogador)


func gerar_pedido_boss_vip(carrinho_do_jogador: Array = []) -> void:
	pedido_atual.clear()
	pedido_por_forma.clear()
	cliente_vip_ativo = true

	# Coleta todos os produtos únicos do banco (os 9 produtos dos 3 setores)
	var produtos_unicos: Array[ProductData] = []
	var nomes_no_banco: Array[String] = []
	for produto in banco_de_produtos:
		var nome_norm: String = _normalizar_nome(produto.product_name)
		if not nomes_no_banco.has(nome_norm):
			nomes_no_banco.append(nome_norm)
			produtos_unicos.append(produto)

	produtos_unicos.shuffle()
	var total_boss: int = mini(9, produtos_unicos.size())

	# 4 produtos com 2 unidades + 5 produtos com 1 unidade (13 unidades no total)
	for i in range(total_boss):
		pedido_atual[produtos_unicos[i]] = 2 if i < 4 else 1

	# 55 segundos para percorrer todas as 9 gôndolas nos 3 setores e entregar no caixa
	timer_pedido.start(55.0)
	atualizar_lista_visual(carrinho_do_jogador)

	# Garante pelo menos 2 produtos de CADA um dos 3 setores (6 produtos iniciais)
	var escolhidos: Array[ProductData] = []
	var nomes_escolhidos: Array[String] = []
	var formas_boss: Array[int] = [
		ProductData.ShapeType.ESFERA,
		ProductData.ShapeType.CILINDRO,
		ProductData.ShapeType.PARALELEPIPEDO
	]

	for forma in formas_boss:
		var da_forma: Array[ProductData] = []
		for produto in produtos_unicos:
			if produto.shape == forma:
				da_forma.append(produto)
		da_forma.shuffle()

		for i in range(mini(2, da_forma.size())):
			escolhidos.append(da_forma[i])
			nomes_escolhidos.append(_normalizar_nome(da_forma[i].product_name))

	# Completa com os produtos restantes até fechar exatamente 8 produtos diferentes
	var restantes: Array[ProductData] = []
	for produto in produtos_unicos:
		if not nomes_escolhidos.has(_normalizar_nome(produto.product_name)):
			restantes.append(produto)
	restantes.shuffle()

	for produto in restantes:
		if escolhidos.size() >= 8:
			break
		escolhidos.append(produto)

	# Embaralha e distribui quantidades: 4 produtos com 2 un. e 4 produtos com 1 un. (12 un. no total)
	escolhidos.shuffle()
	for i in range(escolhidos.size()):
		pedido_atual[escolhidos[i]] = 2 if i < 4 else 1

	# 50 segundos para percorrer 8 gôndolas nos 3 setores e entregar no caixa
	timer_pedido.start(50.0)
	atualizar_lista_visual(carrinho_do_jogador)


func pegar_tempo_restante() -> float:
	return timer_pedido.time_left


# ==========================================
# --- FONTE ÚNICA DE VERDADE (PRANCHETA + CAIXA) ---
# ==========================================
func avaliar_carrinho(carrinho_do_jogador: Array) -> Dictionary:
	var atendido_produtos: Dictionary = {}
	var excesso_produtos: Dictionary = {}
	var atendido_formas: Dictionary = {}
	var excesso_formas: Dictionary = {}
	var itens_nao_pedidos: Dictionary = {}

	for prod in pedido_atual.keys():
		atendido_produtos[prod] = 0
		excesso_produtos[prod] = 0
	for forma in pedido_por_forma.keys():
		atendido_formas[forma] = 0
		excesso_formas[forma] = 0

	var sobras_passo1: Array = []
	for item in carrinho_do_jogador:
		var nome_item: String = _normalizar_nome(str(item.product_name))
		var alocado: bool = false
		for prod in pedido_atual.keys():
			if _normalizar_nome(str(prod.product_name)) == nome_item:
				if atendido_produtos[prod] < pedido_atual[prod]:
					atendido_produtos[prod] += 1
					alocado = true
				break
		if not alocado:
			sobras_passo1.append(item)

	var sobras_passo2: Array = []
	for item in sobras_passo1:
		var forma_item: int = item.shape
		if pedido_por_forma.has(forma_item) and atendido_formas[forma_item] < pedido_por_forma[forma_item]:
			atendido_formas[forma_item] += 1
		else:
			sobras_passo2.append(item)

	var erros: int = sobras_passo2.size()
	for item in sobras_passo2:
		var nome_item: String = _normalizar_nome(str(item.product_name))
		var marcado_excesso: bool = false

		for prod in pedido_atual.keys():
			if _normalizar_nome(str(prod.product_name)) == nome_item:
				excesso_produtos[prod] += 1
				marcado_excesso = true
				break

		if marcado_excesso:
			continue

		var forma_item: int = item.shape
		if pedido_por_forma.has(forma_item):
			excesso_formas[forma_item] += 1
			continue

		var chave_existente: ProductData = null
		for k in itens_nao_pedidos.keys():
			if _normalizar_nome(str(k.product_name)) == nome_item:
				chave_existente = k
				break
		if chave_existente != null:
			itens_nao_pedidos[chave_existente] += 1
		else:
			itens_nao_pedidos[item] = 1

	var faltantes: int = 0
	for prod in pedido_atual.keys():
		faltantes += pedido_atual[prod] - atendido_produtos[prod]
	for forma in pedido_por_forma.keys():
		faltantes += pedido_por_forma[forma] - atendido_formas[forma]

	return {
		"atendido_produtos": atendido_produtos,
		"excesso_produtos": excesso_produtos,
		"atendido_formas": atendido_formas,
		"excesso_formas": excesso_formas,
		"itens_nao_pedidos": itens_nao_pedidos,
		"erros": erros,
		"faltantes": faltantes,
		"perfeito": (erros == 0 and faltantes == 0)
	}


# ==========================================
# --- INTERFACE VISUAL (PRANCHETA) ---
# ==========================================
func _pegar_nome_da_forma(shape_enum: int) -> String:
	match shape_enum:
		ProductData.ShapeType.ESFERA: return "Esfera"
		ProductData.ShapeType.CILINDRO: return "Cilindro"
		ProductData.ShapeType.PARALELEPIPEDO: return "Paralelepípedo"
	return "Desconhecida"


func _pegar_icone_da_forma(shape_enum: int) -> Texture2D:
	match shape_enum:
		ProductData.ShapeType.ESFERA: return icone_esfera
		ProductData.ShapeType.CILINDRO: return icone_cilindro
		ProductData.ShapeType.PARALELEPIPEDO: return icone_paralelepipedo
	return null


func _criar_icone_prancheta(textura: Texture2D, tamanho: Vector2) -> TextureRect:
	var icone := TextureRect.new()
	icone.texture = textura
	icone.custom_minimum_size = tamanho
	icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icone


func atualizar_lista_visual(carrinho_do_jogador: Array) -> void:
	if not ui_lista_de_itens:
		return

	for child in ui_lista_de_itens.get_children():
		child.queue_free()

	var resultado: Dictionary = avaliar_carrinho(carrinho_do_jogador)
	var total_linhas: int = pedido_atual.size() + pedido_por_forma.size() + resultado["itens_nao_pedidos"].size()

	# Modo compacto automático para listas grandes (como o Boss com 8 produtos) caberem na prancheta
	var tamanho_icone: Vector2 = Vector2(22, 22) if total_linhas > 5 else Vector2(32, 32)
	var tamanho_fonte: int = 12 if total_linhas > 5 else 14

	for produto in pedido_atual.keys():
		var qtd_pedida: int = pedido_atual[produto]
		var qtd_atual: int = resultado["atendido_produtos"][produto] + resultado["excesso_produtos"][produto]
		var nome_forma: String = _pegar_nome_da_forma(produto.shape)

		var linha := HBoxContainer.new()
		if produto.icon:
			linha.add_child(_criar_icone_prancheta(produto.icon, tamanho_icone))

		var texto := Label.new()
		texto.text = "%s (%s): %d / %d" % [produto.product_name, nome_forma, qtd_atual, qtd_pedida]
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		texto.add_theme_font_size_override("font_size", tamanho_fonte)

		if qtd_atual > qtd_pedida:
			texto.add_theme_color_override("font_color", Color.ORANGE)
		elif qtd_atual == qtd_pedida:
			texto.add_theme_color_override("font_color", Color.GREEN)
		else:
			texto.add_theme_color_override("font_color", Color.BLACK)

		linha.add_child(texto)
		ui_lista_de_itens.add_child(linha)

	for forma in pedido_por_forma.keys():
		var qtd_pedida: int = pedido_por_forma[forma]
		var qtd_atual: int = resultado["atendido_formas"][forma] + resultado["excesso_formas"][forma]
		var nome_forma: String = _pegar_nome_da_forma(forma)
		var textura_forma: Texture2D = _pegar_icone_da_forma(forma)

		var linha_forma := HBoxContainer.new()
		if textura_forma:
			linha_forma.add_child(_criar_icone_prancheta(textura_forma, tamanho_icone))

		var texto := Label.new()
		texto.text = "Qualquer %s: %d / %d" % [nome_forma, qtd_atual, qtd_pedida]
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		texto.add_theme_font_size_override("font_size", tamanho_fonte)

		if qtd_atual > qtd_pedida:
			texto.add_theme_color_override("font_color", Color.ORANGE)
		elif qtd_atual == qtd_pedida:
			texto.add_theme_color_override("font_color", Color.GREEN)
		else:
			texto.add_theme_color_override("font_color", Color.DARK_BLUE)

		linha_forma.add_child(texto)
		ui_lista_de_itens.add_child(linha_forma)

	for produto_errado in resultado["itens_nao_pedidos"].keys():
		var qtd_errada: int = resultado["itens_nao_pedidos"][produto_errado]
		var nome_forma: String = _pegar_nome_da_forma(produto_errado.shape)

		var linha_errada := HBoxContainer.new()
		if produto_errado.icon:
			linha_errada.add_child(_criar_icone_prancheta(produto_errado.icon, tamanho_icone))

		var texto_errado := Label.new()
		texto_errado.text = "%s (%s): %d (Não Pedido!)" % [produto_errado.product_name, nome_forma, qtd_errada]
		texto_errado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto_errado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texto_errado.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		texto_errado.add_theme_font_size_override("font_size", tamanho_fonte)
		texto_errado.add_theme_color_override("font_color", Color.RED)

		linha_errada.add_child(texto_errado)
		ui_lista_de_itens.add_child(linha_errada)


# ==========================================
# --- RESET DE DADOS ---
# ==========================================
func resetar_clientes() -> void:
	formas_liberadas = [ProductData.ShapeType.ESFERA]
	pedido_atual.clear()
	pedido_por_forma.clear()
	tutorial_concluido = false
	cliente_vip_ativo = false
	ultima_forma_sorteada = -1
	ultimo_pedido_teve_forma = false

	if timer_pedido:
		timer_pedido.stop()

	if ui_lista_de_itens:
		for filho in ui_lista_de_itens.get_children():
			filho.queue_free()
