extends StaticBody2D
class_name BaseProducts

# ==========================================
# --- PROPRIEDADES EXPORTADAS (INSPECTOR) ---
# ==========================================
@export_category("Configurações do Produto")
@export var product_data: ProductData
@export var custo_por_unidade: float = 1.5
@export var max_stock: int = 5

# ==========================================
# --- REFERÊNCIAS DE NODES (UI E ÁUDIO) ---
# ==========================================
@export_category("Referências de Nodes")
@onready var interaction_area: Area2D = $Area2D
@onready var popup_label: Label = $Label
@onready var som_pegar: AudioStreamPlayer = $SomPegar
@onready var som_devolver: AudioStreamPlayer = $SomDevolver
@onready var som_reposicao: AudioStreamPlayer = $SomReposicao
@onready var product_grid: GridContainer = $"../Visuals/ProductGrid"

# ==========================================
# --- ESTADO DA PRATELEIRA E TEMPORIZADORES ---
# ==========================================
var _max_visual_icons: int = 5
var _current_stock: int = 0
var _products_taken_count: int = 0
var _interact_timer: float = 0.0
var _interact_delay: float = 0.2

# ==========================================
# --- REFERÊNCIAS DO JOGADOR ---
# ==========================================
var _player_in_range: bool = false
var _current_player: BaseCharacter = null
var _jogador_na_area: BaseCharacter = null


# ==========================================
# --- INICIALIZAÇÃO ---
# ==========================================
func _ready() -> void:
	add_to_group("prateleiras")

	popup_label.visible = false
	_max_visual_icons = max_stock # Limite fixo de ícones que cabem sem vazar da gôndola
	_current_stock = max_stock

	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

	update_visuals()


# ==========================================
# --- LOOP DE INTERAÇÃO (INPUTS) ---
# ==========================================
func _process(delta: float) -> void:
	if _player_in_range:
		if _interact_timer > 0.0:
			_interact_timer -= delta

		# --- Lógica de pegar produto ---
		if Input.is_action_pressed("interact_e") and _current_stock > 0 and _interact_timer <= 0.0:
			take_product()
			_interact_timer = _interact_delay

		# --- Lógica de devolver produto (R = 1 item | Shift + R = todos desta prateleira) ---
		elif Input.is_action_pressed("interact_r") and _products_taken_count > 0 and _interact_timer <= 0.0:
			if Input.is_action_pressed("run"):
				while _products_taken_count > 0:
					return_product()
			else:
				return_product()
			_interact_timer = _interact_delay

		elif not Input.is_action_pressed("interact_e") and not Input.is_action_pressed("interact_r"):
			_interact_timer = 0.0

	# --- Lógica de reposição de estoque ---
	if _jogador_na_area and Input.is_action_just_pressed("interact_f"):
		repor_estoque()


# ==========================================
# --- MECÂNICAS PRINCIPAIS (INVENTÁRIO / CARRINHO) ---
# ==========================================

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
	if _products_taken_count > 0:
		_products_taken_count -= 1

		if _current_stock < max_stock:
			_current_stock += 1

		if som_devolver:
			som_devolver.play()

		if _current_player:
			_current_player.remove_from_cart(product_data)

		update_visuals()
		atualizar_texto_do_painel()


# ==========================================
# --- ATUALIZAÇÃO VISUAL (UI DA PRATELEIRA) ---
# ==========================================

func _calcular_icones_visiveis() -> int:
	if _current_stock <= 0:
		return 0
	var limite: int = maxi(1, _max_visual_icons)
	var proporcao: float = float(_current_stock) / float(maxi(1, max_stock))
	return clampi(ceili(proporcao * limite), 1, limite)


func update_visuals() -> void:
	"""Reconstrói os ícones no GridContainer proporcionalmente, sem ultrapassar o tamanho da gôndola."""
	if not product_grid or not product_data:
		return

	for child in product_grid.get_children():
		child.queue_free()

	var qtd_icones: int = _calcular_icones_visiveis()
	for i in range(qtd_icones):
		var icone := TextureRect.new()
		icone.texture = product_data.icon
		icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.custom_minimum_size = Vector2(14, 14)

		product_grid.add_child(icone)


# ==========================================
# --- INTERAÇÕES FÍSICAS (SINAIS DA ÁREA 2D) ---
# ==========================================

func _on_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		_jogador_na_area = body
		atualizar_texto_do_painel()
		_player_in_range = true
		_current_player = body
		update_visuals()

		popup_label.visible = true
		popup_label.scale = Vector2.ZERO
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(popup_label, "scale", Vector2(1, 1), 0.3)


func _on_body_exited(body: Node2D) -> void:
	if body is BaseCharacter:
		_jogador_na_area = null
		_player_in_range = false
		_current_player = null

		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(popup_label, "scale", Vector2.ZERO, 0.2)
		tween.tween_callback(func(): popup_label.visible = false)


# ==========================================
# --- GESTÃO DE ESTOQUE E ECONOMIA ---
# ==========================================

func resetar_itens_pegos() -> void:
	_products_taken_count = 0
	update_visuals()


func repor_estoque() -> void:
	if _current_stock >= max_stock:
		if _jogador_na_area:
			_jogador_na_area.mostrar_notificacao("A prateleira já está cheia!", Color.YELLOW)
		return

	var quantidade_para_repor = max_stock - _current_stock
	var custo_total = quantidade_para_repor * custo_por_unidade

	if EconomyManager.dinheiro >= custo_total:
		EconomyManager.dinheiro -= custo_total
		_current_stock = max_stock
		update_visuals()
		atualizar_texto_do_painel()

		if _jogador_na_area:
			_jogador_na_area.mostrar_notificacao("Estoque reposto! -$" + str(custo_total), Color.GREEN)

		if som_reposicao:
			som_reposicao.play()
	else:
		if _jogador_na_area:
			_jogador_na_area.mostrar_notificacao("Dinheiro insuficiente! Precisa de $" + str(custo_total), Color.RED)


func atualizar_texto_do_painel() -> void:
	popup_label.remove_theme_color_override("font_color")

	var texto_interacao = ""

	if _current_stock == 0:
		texto_interacao += "⚠️ ESTOQUE VAZIO (0/%d) ⚠️\n" % max_stock
		popup_label.add_theme_color_override("font_color", Color.RED)
	else:
		texto_interacao += "Estoque: %d/%d\n" % [_current_stock, max_stock]
		texto_interacao += "[E] Pegar Produto\n"

	if _products_taken_count > 0:
		texto_interacao += "[R] Devolver (%d)\n" % _products_taken_count

	if _current_stock < max_stock:
		var custo_total = (max_stock - _current_stock) * custo_por_unidade
		texto_interacao += "[F] Repor Estoque ($" + str(custo_total) + ")"

	popup_label.text = texto_interacao.strip_edges()


func aumentar_estoque_maximo(extra: int) -> void:
	max_stock += extra
	_current_stock = max_stock
	update_visuals()
	atualizar_texto_do_painel()


func repor_automaticamente() -> bool:
	if _current_stock < max_stock:
		_current_stock = max_stock
		update_visuals()
		atualizar_texto_do_painel()
		return true
	return false
