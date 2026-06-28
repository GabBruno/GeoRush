extends Area2D
class_name CaixaCheckout

@export_category("Configurações")
@export var cena_cliente: PackedScene

@export_category("Referências de Nodes")
@onready var popup_label: Label = $Label
@onready var som_cliente_chegou: AudioStreamPlayer = $SomClienteChegou
@onready var som_sucesso: AudioStreamPlayer = $SomSucesso
@onready var som_erro: AudioStreamPlayer = $SomErro 

# --- Estado do Caixa ---
var cliente_atual: Cliente
var _jogador_na_area: BaseCharacter = null

# --- Sistema de Fila ---
var fila_de_clientes: Array = []
var posicoes_da_fila: Array[Vector2] = [
	Vector2(145, 224),
	Vector2(210, 224), 
	Vector2(275, 224), 
	Vector2(340, 224) 
]

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	popup_label.visible = false
	
	# Inicia a fila gerando o primeiro cliente
	gerar_novo_cliente()

func _process(_delta: float) -> void:
	# Assegura que o caixa referencie sempre o primeiro cliente da fila
	if fila_de_clientes.size() > 0:
		cliente_atual = fila_de_clientes[0]
	else:
		cliente_atual = null

	# Atualiza a interface (Pop-up) baseada no estado do pedido e carrinho do jogador
	if _jogador_na_area:
		if CustomerManager.pedido_atual.is_empty():
			if cliente_atual and cliente_atual.estado == "esperando":
				popup_label.text = "[E] Pegar Pedido"
				popup_label.remove_theme_color_override("font_color")
			else:
				popup_label.text = "(Aguardando Cliente)"
				popup_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			if _jogador_na_area.shopping_cart.size() > 0:
				popup_label.text = "[E] Entregar Produtos"
				popup_label.remove_theme_color_override("font_color")
			else:
				popup_label.text = "(Carrinho Vazio)"
				popup_label.add_theme_color_override("font_color", Color.RED)

func _input(event: InputEvent) -> void:
	if _jogador_na_area:
		# Verifica interação pela ação configurada ou diretamente pela tecla 'E'
		var apertou_botao = false
		
		if event.is_action_pressed("interact_e"):
			apertou_botao = true
		elif event is InputEventKey and event.keycode == Key.KEY_E and event.pressed and not event.echo:
			apertou_botao = true
			
		if apertou_botao:
			# Caso 1: Jogador solicita um novo pedido ao cliente
			if CustomerManager.pedido_atual.is_empty():
				if cliente_atual and cliente_atual.estado == "esperando":
					var quantidade_tipos = randi_range(1, 3) 
					CustomerManager.gerar_novo_pedido(quantidade_tipos)
					
					# Define o tempo baseando-se na quantidade de tipos de itens solicitados
					var tempo_calculado = 5.0 + (quantidade_tipos * 2.0)
					CustomerManager.timer_pedido.wait_time = tempo_calculado
					CustomerManager.timer_pedido.start()
					
					_jogador_na_area.mostrar_notificacao("Novo Pedido Recebido! Abra a lista de compras! (Tab)", Color.CYAN)
			
			# Caso 2: Jogador entrega os itens que estão no carrinho
			else:
				if _jogador_na_area.shopping_cart.size() > 0:
					validar_compra()

func validar_compra() -> void:
	var carrinho = _jogador_na_area.shopping_cart
	var pedido_restante = CustomerManager.pedido_atual.duplicate()
	var erros = 0
	
	# Verifica a correspondência entre os itens do carrinho e os itens do pedido
	for item in carrinho:
		var item_correto_encontrado = false
		for produto_pedido in pedido_restante.keys():
			var nome_pedido = str(produto_pedido.product_name).to_lower().strip_edges()
			var nome_carrinho = str(item.product_name).to_lower().strip_edges()
			
			if nome_pedido == nome_carrinho:
				if pedido_restante[produto_pedido] > 0:
					pedido_restante[produto_pedido] -= 1
					item_correto_encontrado = true
					break
		if not item_correto_encontrado:
			erros += 1 
			
	var faltantes = 0
	for quantidade_restante in pedido_restante.values():
		faltantes += quantidade_restante
		
	# Registra o tempo restante exato antes de parar o cronômetro
	var tempo_sobrou = CustomerManager.pegar_tempo_restante()
	CustomerManager.timer_pedido.stop()

	# --- Avaliação da Compra (Sucesso ou Erro) ---
	if erros == 0 and faltantes == 0:
		
		if som_sucesso:
			som_sucesso.play()
			
		if tempo_sobrou > 0:
			var pagamento_total = 10.0 + (tempo_sobrou * 1.0)
			EconomyManager.adicionar_recompensa(pagamento_total, 5)
			var texto = "✅ SUCESSO!\n+$" + str(snapped(pagamento_total, 0.1)) + " | +5 Reputação"
			_jogador_na_area.mostrar_notificacao(texto, Color.GREEN)
			
			# Instancia o popup APENAS se não estiver no nível máximo E a meta de clientes foi atingida!
			if EconomyManager.nivel_expansao < EconomyManager.expansoes_maximas and EconomyManager.clientes_atendidos >= EconomyManager.meta_expansao:
				var cena_popup = preload("res://UI/popup_expansao.tscn").instantiate()
				get_tree().current_scene.add_child(cena_popup)
				EconomyManager.clientes_atendidos = 0
				EconomyManager.meta_expansao += 5
		else:
			EconomyManager.adicionar_recompensa(10.0, 1)
			var texto = "⚠️ SUCESSO (Atrasado)!\n+$10.0 | +1 Reputação"
			_jogador_na_area.mostrar_notificacao(texto, Color.YELLOW)
			
			# Instancia o popup APENAS se não estiver no nível máximo E a meta de clientes foi atingida!
			if EconomyManager.nivel_expansao < EconomyManager.expansoes_maximas and EconomyManager.clientes_atendidos >= EconomyManager.meta_expansao:
				var cena_popup = preload("res://UI/popup_expansao.tscn").instantiate()
				get_tree().current_scene.add_child(cena_popup)
				EconomyManager.clientes_atendidos = 0
				EconomyManager.meta_expansao += 5
		
		if cliente_atual:
			cliente_atual.reagir_e_ir_embora(true)
			
	else:
		if som_erro:
			som_erro.play()
			
		EconomyManager.dinheiro += 5.0
		EconomyManager.aplicar_punicao(0, 10) 
		var texto = "❌ ERRO NO PEDIDO!\nGanhou apenas $5.0 | Perdeu 10 Reputação!"
		_jogador_na_area.mostrar_notificacao(texto, Color.RED)
		
		if cliente_atual:
			cliente_atual.reagir_e_ir_embora(false)
		
	# --- Limpeza Pós-Transação ---
	_jogador_na_area.shopping_cart.clear()
	get_tree().call_group("prateleiras", "resetar_itens_pegos")
	CustomerManager.pedido_atual.clear()
	
	# Remove a lista visual da UI do jogador
	if CustomerManager.ui_lista_de_itens:
		for child in CustomerManager.ui_lista_de_itens.get_children():
			child.queue_free()
	
	avancar_fila()

# --- Sinais da Área 2D ---
func _on_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		_jogador_na_area = body
		popup_label.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body is BaseCharacter:
		_jogador_na_area = null
		popup_label.visible = false

# --- Lógica de Fila ---
func _on_timer_spawn_timeout() -> void:
	if fila_de_clientes.size() < posicoes_da_fila.size():
		gerar_novo_cliente()

func gerar_novo_cliente() -> void:
	if cena_cliente:
		var novo_cliente = cena_cliente.instantiate()
		
		# Adiciona o cliente na árvore de cena de forma segura (call_deferred)
		get_parent().add_child.call_deferred(novo_cliente)
		
		var posicao_na_fila = fila_de_clientes.size()
		novo_cliente.posicao_caixa = posicoes_da_fila[posicao_na_fila]
		fila_de_clientes.append(novo_cliente)
		
		if som_cliente_chegou:
			som_cliente_chegou.play()

func avancar_fila() -> void:
	if fila_de_clientes.size() > 0:
		# Remove o cliente que já foi atendido do controle da fila
		fila_de_clientes.pop_front()

	# Move todos os clientes restantes para a próxima posição
	for i in range(fila_de_clientes.size()):
		var cliente = fila_de_clientes[i]
		cliente.posicao_caixa = posicoes_da_fila[i]
		
		if cliente.estado == "esperando":
			cliente.estado = "entrando_passo2"
			cliente.animacao.play("walk_left")
