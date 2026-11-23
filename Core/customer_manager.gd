extends Node

# ==========================================
# --- PROPRIEDADES EXPORTADAS (INSPECTOR) ---
# ==========================================
@export_category("Banco de Dados")
@export var banco_de_produtos: Array[ProductData] = []

@export_category("Frequência de Pedidos por Forma")
@export_range(0.0, 1.0, 0.05) var chance_forma_nivel_0: float = 0.25
@export_range(0.0, 1.0, 0.05) var chance_pedido_por_forma: float = 0.30
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
# --- LÓGICA DE PEDIDOS (GERAÇÃO INTELIGENTE) ---
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

	# --- 2. AJUSTE DE DIFICULDADE POR FASE ---
	var min_tipos := 1
	var max_tipos := 2
	var min_quant := 1
	var max_quant := 3

	match EconomyManager.nivel_expansao:
		0:
			min_tipos = 1; max_tipos = 2; min_quant = 1; max_quant = 3
		1:
			min_tipos = 1; max_tipos = 2; min_quant = 1; max_quant = 3
		2:
			min_tipos = 2; max_tipos = 3; min_quant = 1; max_quant = 4
		_:
			min_tipos = 2; max_tipos = 4; min_quant = 2; max_quant = 4

	# --- 3. SORTEIO DO PEDIDO POR FORMA (ESFERA, CILINDRO OU PARALELEPÍPEDO) ---
	var incluir_pedido_por_forma := false
	var pode_sortear_forma := not (evitar_formas_seguidas and ultimo_pedido_teve_forma)

	if pode_sortear_forma:
		if EconomyManager.nivel_expansao == 0:
			# Nível 0 (só Esfera liberada): usa a chance configurada para "Qualquer Esfera"
			incluir_pedido_por_forma = randf() < chance_forma_nivel_0
		else:
			# Nível 1+: usa apenas a chance de pedido misto (Forma + Produtos Normais)
			incluir_pedido_por_forma = randf() < chance_pedido_por_forma

	if incluir_pedido_por_forma and not formas_liberadas.is_empty():
		var formas_candidatas: Array = formas_liberadas.duplicate()

		# Evita sortear a mesma forma genérica duas vezes seguidas quando há mais de 1 setor
		if formas_candidatas.size() > 1 and ultima_forma_sorteada != -1:
			formas_candidatas.erase(ultima_forma_sorteada)

		var forma_sorteada: int = formas_candidatas.pick_random()
		ultima_forma_sorteada = forma_sorteada
		pedido_por_forma[forma_sorteada] = randi_range(2, 3)

	ultimo_pedido_teve_forma = not pedido_por_forma.is_empty()

	# --- 4. SORTEIO DE PRODUTOS NORMAIS (ESPECÍFICOS) ---
	# Entra junto com o pedido por forma usando produtos dos OUTROS setores liberados
	if not cliente_vip_ativo:
		var produtos_disponiveis: Array[ProductData] = []
		for produto in banco_de_produtos:
			if formas_liberadas.has(produto.shape) and not pedido_por_forma.has(produto.shape):
				produtos_disponiveis.append(produto)

		produtos_disponiveis.shuffle()
		var quantidade_de_tipos := randi_range(min_tipos, max_tipos)

		for i in range(min(quantidade_de_tipos, produtos_disponiveis.size())):
			var produto_escolhido := produtos_disponiveis[i]
			pedido_atual[produto_escolhido] = randi_range(min_quant, max_quant)

	# --- 5. CÁLCULO DO TEMPO CONSIDERANDO PRODUTOS + FORMAS ---
	var total_unidades := 0
	for qtd in pedido_atual.values():
		total_unidades += qtd
	for qtd_forma in pedido_por_forma.values():
		total_unidades += qtd_forma

	var tempo_base := 25.0 + (EconomyManager.nivel_expansao * 10.0) + (total_unidades * 4.0)
	timer_pedido.start(tempo_base)

	atualizar_lista_visual(carrinho_do_jogador)

func gerar_pedido_boss_vip(carrinho_do_jogador: Array = []) -> void:
	pedido_atual.clear()
	pedido_por_forma.clear()
	cliente_vip_ativo = true

	# Desafio Final: exige itens das 3 formas geométricas (aceita qualquer produto de cada setor)
	pedido_por_forma[ProductData.ShapeType.ESFERA] = 2
	pedido_por_forma[ProductData.ShapeType.CILINDRO] = 2
	pedido_por_forma[ProductData.ShapeType.PARALELEPIPEDO] = 2

	# Tempo justo mas tenso para percorrer os 3 setores (ajuste se precisar)
	timer_pedido.start(55.0)

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

	# PASSO 1: Atende primeiro os produtos específicos (independente da ordem de coleta)
	var sobras_passo1: Array = []
	for item in carrinho_do_jogador:
		var nome_item := _normalizar_nome(str(item.product_name))
		var alocado := false
		for prod in pedido_atual.keys():
			if _normalizar_nome(str(prod.product_name)) == nome_item:
				if atendido_produtos[prod] < pedido_atual[prod]:
					atendido_produtos[prod] += 1
					alocado = true
				break
		if not alocado:
			sobras_passo1.append(item)

	# PASSO 2: Usa apenas as sobras para atender os pedidos genéricos por forma
	var sobras_passo2: Array = []
	for item in sobras_passo1:
		var forma_item: int = item.shape
		if pedido_por_forma.has(forma_item) and atendido_formas[forma_item] < pedido_por_forma[forma_item]:
			atendido_formas[forma_item] += 1
		else:
			sobras_passo2.append(item)

	# PASSO 3: Classifica o que sobrou (excesso de item pedido, excesso de forma ou item intruso)
	var erros: int = sobras_passo2.size()
	for item in sobras_passo2:
		var nome_item := _normalizar_nome(str(item.product_name))
		var marcado_excesso := false

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

		# Agrupa itens não pedidos pelo nome
		var chave_existente: ProductData = null
		for k in itens_nao_pedidos.keys():
			if _normalizar_nome(str(k.product_name)) == nome_item:
				chave_existente = k
				break
		if chave_existente != null:
			itens_nao_pedidos[chave_existente] += 1
		else:
			itens_nao_pedidos[item] = 1

	# PASSO 4: Calcula quantos itens ainda faltam
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
		ProductData.ShapeType.CUBO: return "Cubo"
	return "Desconhecida"

func atualizar_lista_visual(carrinho_do_jogador: Array) -> void:
	if not ui_lista_de_itens:
		return

	for child in ui_lista_de_itens.get_children():
		child.queue_free()

	var resultado := avaliar_carrinho(carrinho_do_jogador)

	# 1. Desenha produtos específicos
	for produto in pedido_atual.keys():
		var qtd_pedida: int = pedido_atual[produto]
		var qtd_atual: int = resultado["atendido_produtos"][produto] + resultado["excesso_produtos"][produto]
		var nome_forma := _pegar_nome_da_forma(produto.shape)

		var linha := HBoxContainer.new()
		if produto.icon:
			var icone := TextureRect.new()
			icone.texture = produto.icon
			icone.custom_minimum_size = Vector2(32, 32)
			icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			linha.add_child(icone)

		var texto := Label.new()
		texto.text = "%s (%s): %d / %d" % [produto.product_name, nome_forma, qtd_atual, qtd_pedida]
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texto.add_theme_font_size_override("font_size", 14)

		if qtd_atual > qtd_pedida:
			texto.add_theme_color_override("font_color", Color.ORANGE)
		elif qtd_atual == qtd_pedida:
			texto.add_theme_color_override("font_color", Color.GREEN)
		else:
			texto.add_theme_color_override("font_color", Color.BLACK)

		linha.add_child(texto)
		ui_lista_de_itens.add_child(linha)

	# 2. Desenha pedidos genéricos por forma geométrica
	for forma in pedido_por_forma.keys():
		var qtd_pedida: int = pedido_por_forma[forma]
		var qtd_atual: int = resultado["atendido_formas"][forma] + resultado["excesso_formas"][forma]
		var nome_forma := _pegar_nome_da_forma(forma)

		var texto := Label.new()
		texto.text = "📐 Qualquer %s: %d / %d" % [nome_forma, qtd_atual, qtd_pedida]
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto.add_theme_font_size_override("font_size", 14)

		if qtd_atual > qtd_pedida:
			texto.add_theme_color_override("font_color", Color.ORANGE)
		elif qtd_atual == qtd_pedida:
			texto.add_theme_color_override("font_color", Color.GREEN)
		else:
			texto.add_theme_color_override("font_color", Color.DARK_BLUE)

		ui_lista_de_itens.add_child(texto)

	# 3. Desenha itens não pedidos (intrusos)
	for produto_errado in resultado["itens_nao_pedidos"].keys():
		var qtd_errada: int = resultado["itens_nao_pedidos"][produto_errado]
		var nome_forma := _pegar_nome_da_forma(produto_errado.shape)

		var linha_errada := HBoxContainer.new()
		if produto_errado.icon:
			var icone := TextureRect.new()
			icone.texture = produto_errado.icon
			icone.custom_minimum_size = Vector2(32, 32)
			icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			linha_errada.add_child(icone)

		var texto_errado := Label.new()
		texto_errado.text = "%s (%s): %d (Não Pedido!)" % [produto_errado.product_name, nome_forma, qtd_errada]
		texto_errado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto_errado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texto_errado.add_theme_font_size_override("font_size", 14)
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
