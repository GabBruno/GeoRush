extends StaticBody2D
class_name BaseProducts

# ==========================================
# --- PROPRIEDADES EXPORTADAS (INSPECTOR) ---
# ==========================================
@export_category("Configurações do Produto")
@export var product_data: ProductData 
@export var custo_por_unidade: float = 5.0
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
	# Define o grupo para chamadas globais (ex: resetar prateleiras via CaixaCheckout)
	add_to_group("prateleiras")
	
	popup_label.visible = false
	_current_stock = max_stock 
	
	# Conecta os sinais de colisão para detectar a aproximação do jogador
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	
	# Inicializa a interface visual das prateleiras (ícones no Grid)
	update_visuals()


# ==========================================
# --- LOOP DE INTERAÇÃO (INPUTS) ---
# ==========================================
func _process(delta: float) -> void:
	if _player_in_range:
		# Temporizador para evitar múltiplas interações simultâneas (spam de teclas)
		if _interact_timer > 0.0:
			_interact_timer -= delta
			
		# --- Lógica de pegar produto ---
		if Input.is_action_pressed("interact_e") and _current_stock > 0 and _interact_timer <= 0.0:
			take_product()
			_interact_timer = _interact_delay 
			
		# --- Lógica de devolver produto ---
		elif Input.is_action_pressed("interact_r") and _products_taken_count > 0 and _interact_timer <= 0.0:
			return_product()
			_interact_timer = _interact_delay
			
		# Zera o delay se nenhuma ação de interação estiver sendo pressionada, permitindo cliques rápidos e responsivos
		elif not Input.is_action_pressed("interact_e") and not Input.is_action_pressed("interact_r"):
			_interact_timer = 0.0
			
	# --- Lógica de reposição de estoque ---
	# Isolada do fluxo pegar/devolver para garantir prioridade de processamento
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
	# Autoriza a devolução apenas de itens coletados nesta mesma interação (evita exploits de devolução em outras gôndolas)
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


# ==========================================
# --- ATUALIZAÇÃO VISUAL (UI DA PRATELEIRA) ---
# ==========================================

func update_visuals() -> void:
	"""Reconstrói os ícones no GridContainer baseando-se no estoque atual."""
	# Remove os ícones antigos antes de desenhar os novos
	for child in product_grid.get_children():
		child.queue_free()
		
	# Instancia e configura os novos ícones dinamicamente no espaço 3D/2D
	for i in range(_current_stock):
		var icone = TextureRect.new()
		icone.texture = product_data.icon
		
		# Configuração de redimensionamento e proporção do ícone para não quebrar a UI
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
		
		# Exibe a janela flutuante com efeito elástico de crescimento (Tween)
		popup_label.visible = true
		popup_label.scale = Vector2.ZERO
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(popup_label, "scale", Vector2(1, 1), 0.3)


func _on_body_exited(body: Node2D) -> void:
	if body is BaseCharacter:
		_jogador_na_area = null 
		_player_in_range = false
		_current_player = null 
		
		# Recolhe a janela flutuante suavemente antes de ocultá-la
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(popup_label, "scale", Vector2.ZERO, 0.2)
		tween.tween_callback(func(): popup_label.visible = false)
		

# ==========================================
# --- GESTÃO DE ESTOQUE E ECONOMIA ---
# ==========================================

func resetar_itens_pegos() -> void:
	"""
	Zera a contagem de itens retidos temporariamente após a validação no caixa.
	Chamado através de Call Group quando a transação do cliente é finalizada.
	"""
	_products_taken_count = 0
	update_visuals()
	

func repor_estoque() -> void:
	"""
	Garante as regras de reposição de estoque, cobrando o valor da economia global
	e impedindo transações desnecessárias ou trapaças no processo de devolução.
	"""
	# Bloqueia a reposição caso o jogador possua itens pendentes para devolução (evita bugs de duplicação)
	if _products_taken_count > 0:
		if _jogador_na_area:
			_jogador_na_area.mostrar_notificacao("Devolva o item antes de repor!", Color.YELLOW)
		return

	# Impede gasto financeiro desnecessário em prateleiras que já estão cheias
	if _current_stock >= max_stock:
		if _jogador_na_area:
			_jogador_na_area.mostrar_notificacao("A prateleira já está cheia!", Color.YELLOW)
		return
		
	# Descobre quantos produtos exatamente estão faltando para a reposição
	var quantidade_para_repor = max_stock - _current_stock
	
	# Calcula o valor total multiplicando a falta pelo preço unitário configurado
	var custo_total = quantidade_para_repor * custo_por_unidade
	
	# Avalia a economia global para debitar o valor exato e reabastecer
	if EconomyManager.dinheiro >= custo_total:
		EconomyManager.dinheiro -= custo_total
		_current_stock = max_stock
		update_visuals()
		
		# Mostra a notificação verde com o valor total descontado (Feedback de Caixa)
		if _jogador_na_area:
			_jogador_na_area.mostrar_notificacao("Estoque reposto! -$" + str(custo_total), Color.GREEN)
		
		# Toca o som que configuramos anteriormente!
		if som_reposicao: # (Ou som_devolver, caso tenha mantido o outro)
			som_reposicao.play()
			
	else:
		# Mostra o erro em vermelho e avisa exatamente quanto o jogador precisa para aquela ação
		if _jogador_na_area:
			_jogador_na_area.mostrar_notificacao("Dinheiro insuficiente! Precisa de $" + str(custo_total), Color.RED)
		

func atualizar_texto_do_painel() -> void:
	"""Atualiza dinamicamente as instruções no painel flutuante de interação no mundo."""
	# Reseta cores de alerta prévias para não vazar a cor vermelha para as mensagens padrão
	popup_label.remove_theme_color_override("font_color")
	
	var texto_interacao = ""
	
	# 1. Regra de Estoque Vazio: Adiciona o alerta vermelho no topo caso os itens acabem
	if _current_stock == 0:
		texto_interacao += "⚠️ ESTOQUE VAZIO ⚠️\n"
		popup_label.add_theme_color_override("font_color", Color.RED)
		
	# 2. Regra para Pegar: Exibe ação primária apenas se houver produto disponível
	if _current_stock > 0:
		texto_interacao += "[E] Pegar Produto\n"
		
	# 3. Regra para Devolver: Exibe apenas se o jogador possuir itens do inventário vinculados a esta prateleira
	if _products_taken_count > 0:
		texto_interacao += "[R] Devolver (" + str(_products_taken_count) + ")\n"
		
	# 4. Regra para Repor: Exibe o custo calculando a diferença até o estoque máximo exigido
	if _current_stock < max_stock:
		var custo_total = (max_stock - _current_stock) * custo_por_unidade
		texto_interacao += "[F] Repor Estoque ($" + str(custo_total) + ")"
		
	# Aplica o texto final removendo quebras de linha (\n) excedentes na última string
	popup_label.text = texto_interacao.strip_edges()
