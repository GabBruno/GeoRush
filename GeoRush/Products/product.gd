extends StaticBody2D
class_name BaseProducts

@export_category("Configurações do Produto")
@export var product_data: ProductData 
@export var custo_reposicao: float = 5.0
@export var max_stock: int = 5        

@export_category("Referências de Nodes")
@onready var interaction_area: Area2D = $Area2D
@onready var popup_label: Label = $Label 
@onready var som_pegar: AudioStreamPlayer = $SomPegar
@onready var som_devolver: AudioStreamPlayer = $SomDevolver
@onready var product_grid: GridContainer = $"../Visuals/ProductGrid"

# --- Estado da Prateleira ---
var _current_stock: int = 0            
var _products_taken_count: int = 0 
var _interact_timer: float = 0.0
var _interact_delay: float = 0.2

# --- Referências de Jogador ---
var _player_in_range: bool = false
var _current_player: BaseCharacter = null
var _jogador_na_area: BaseCharacter = null

func _ready() -> void:
	add_to_group("prateleiras")
	
	popup_label.visible = false
	_current_stock = max_stock 
	
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	
	# Inicializa a interface visual das prateleiras
	update_visuals()

func _process(delta: float) -> void:
	if _player_in_range:
		if _interact_timer > 0.0:
			_interact_timer -= delta
			
		# Lógica de pegar produto
		if Input.is_action_pressed("interact_e") and _current_stock > 0 and _interact_timer <= 0.0:
			take_product()
			_interact_timer = _interact_delay 
			
		# Lógica de devolver produto
		elif Input.is_action_pressed("interact_r") and _products_taken_count > 0 and _interact_timer <= 0.0:
			return_product()
			_interact_timer = _interact_delay
			
		# Zera o delay se nenhuma ação de interação estiver sendo pressionada
		elif not Input.is_action_pressed("interact_e") and not Input.is_action_pressed("interact_r"):
			_interact_timer = 0.0
			
	# Lógica de reposição de estoque
	if _jogador_na_area and Input.is_action_just_pressed("interact_f"):
		repor_estoque()

func take_product() -> void:
	"""Processa a retirada de um item da prateleira e o envia para o carrinho."""
	_products_taken_count += 1
	_current_stock -= 1
	
	if som_pegar:
		som_pegar.play()
		
	if _current_player:
		_current_player.add_to_cart(product_data)
		
	update_visuals()
	atualizar_texto_do_painel()

func return_product() -> void:
	"""Processa a devolução de um item do carrinho de volta para a prateleira."""
	# Autoriza a devolução apenas de itens coletados nesta mesma interação
	if _products_taken_count > 0:
		_products_taken_count -= 1
		
		# Repõe fisicamente na prateleira caso haja espaço
		if _current_stock < max_stock:
			_current_stock += 1
			
		if som_devolver:
			som_devolver.play()
			
		if _current_player:
			_current_player.remove_from_cart(product_data)
			
		update_visuals()
		atualizar_texto_do_painel()

func update_visuals() -> void:
	"""Reconstrói os ícones no GridContainer baseando-se no estoque atual."""
	# Remove os ícones antigos
	for child in product_grid.get_children():
		child.queue_free()
		
	# Instancia e configura os novos ícones
	for i in range(_current_stock):
		var icone = TextureRect.new()
		icone.texture = product_data.icon
		
		# Configuração de redimensionamento e proporção do ícone
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE 
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED 
		icone.custom_minimum_size = Vector2(14, 14) 
		
		product_grid.add_child(icone)

# --- Interações de Área ---
func _on_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		_jogador_na_area = body
		atualizar_texto_do_painel()
		_player_in_range = true
		_current_player = body 
		update_visuals()
		popup_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is BaseCharacter:
		_jogador_na_area = null 
		_player_in_range = false
		_current_player = null 
		popup_label.visible = false
		
# --- Gestão de Estoque ---
func resetar_itens_pegos() -> void:
	"""Zera a contagem de itens retidos temporariamente após a validação no caixa."""
	_products_taken_count = 0
	update_visuals()
	
func repor_estoque() -> void:
	"""
	Garante as regras de reposição de estoque, cobrando o valor da economia global
	e impedindo transações desnecessárias ou trapaças no processo de devolução.
	"""
	# Bloqueia a reposição caso o jogador possua itens pendentes para devolução
	if _products_taken_count > 0:
		if _jogador_na_area:
			_jogador_na_area.mostrar_notificacao("Devolva o item antes de repor!", Color.YELLOW)
		return

	# Impede gasto em prateleiras que já estão no limite
	if _current_stock >= max_stock:
		if _jogador_na_area:
			_jogador_na_area.mostrar_notificacao("A prateleira já está cheia!", Color.YELLOW)
		return
		
	# Avalia a economia para debitar o valor e reabastecer
	if EconomyManager.dinheiro >= custo_reposicao:
		EconomyManager.dinheiro -= custo_reposicao
		_current_stock = max_stock
		update_visuals()
		print("📦 Estoque reposto! Você pagou $", custo_reposicao)
	else:
		print("❌ Dinheiro insuficiente! Você precisa de $", custo_reposicao, " para repor o estoque.")
		
func atualizar_texto_do_painel() -> void:
	"""Atualiza dinamicamente as instruções no painel flutuante de interação."""
	# Reseta cores de alerta prévias
	popup_label.remove_theme_color_override("font_color")
	
	var texto_interacao = ""
	
	# 1. Regra de Estoque Vazio: Adiciona o alerta vermelho no topo
	if _current_stock == 0:
		texto_interacao += "⚠️ ESTOQUE VAZIO ⚠️\n"
		popup_label.add_theme_color_override("font_color", Color.RED)
		
	# 2. Regra para Pegar: Exibe apenas se houver produto disponível
	if _current_stock > 0:
		texto_interacao += "[E] Pegar Produto\n"
		
	# 3. Regra para Devolver: Exibe apenas se o jogador possuir itens desta prateleira
	if _products_taken_count > 0:
		texto_interacao += "[R] Devolver (" + str(_products_taken_count) + ")\n"
		
	# 4. Regra para Repor: Exibe apenas se a prateleira comportar mais itens
	if _current_stock < max_stock:
		texto_interacao += "[F] Repor Estoque ($" + str(custo_reposicao) + ")"
		
	# Aplica o texto final removendo quebras de linha excedentes
	popup_label.text = texto_interacao.strip_edges()
