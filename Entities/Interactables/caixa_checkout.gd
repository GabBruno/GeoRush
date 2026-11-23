extends Area2D
class_name CaixaCheckout

# ==========================================
# --- PROPRIEDADES EXPORTADAS (INSPECTOR) ---
# ==========================================
@export_category("Configurações")
@export var cena_cliente: PackedScene

@export_category("Referências de Nodes")
@onready var popup_label: Label = $Label
@onready var som_cliente_chegou: AudioStreamPlayer = $SomClienteChegou
@onready var som_sucesso: AudioStreamPlayer = $SomSucesso
@onready var som_erro: AudioStreamPlayer = $SomErro 

@export_category("Economia")
@export var preco_venda_por_item: float = 10.0 # Valor bruto por produto entregue
@export var multiplicador_gorjeta_tempo: float = 2.0 # Bônus financeiro por segundo restante

@onready var timer_spawn: Timer = $TimerSpawn

var boss_vip_em_cena: bool = false

# ==========================================
# --- VARIÁVEIS DE ESTADO DO CAIXA ---
# ==========================================
var cliente_atual: Cliente
var _jogador_na_area: BaseCharacter = null

# ==========================================
# --- SISTEMA DE FILA DE CLIENTES ---
# Coordenadas espaciais fixas para onde os clientes caminharão na fila do caixa.
# ==========================================
var fila_de_clientes: Array = []
var posicoes_da_fila: Array[Vector2] = [
	Vector2(145, 224),
	Vector2(210, 224), 
	Vector2(275, 224), 
	Vector2(340, 224) 
]

# ==========================================
# --- CICLO DE VIDA DO OBJETO (LIFECYCLE) ---
# ==========================================

func _ready() -> void:
	
	CustomerManager.timer_pedido.timeout.connect(_on_tempo_pedido_esgotado)
	
	# Conecta os sinais de colisão da Área 2D para identificar a presença do atendente
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	popup_label.visible = false
	
	# Inicia a fila de jogabilidade gerando o primeiro cliente na porta
	gerar_novo_cliente()


func _process(_delta: float) -> void:
	# Garante que o caixa esteja processando e referenciando sempre o primeiro cliente da fila
	if fila_de_clientes.size() > 0:
		cliente_atual = fila_de_clientes[0]
	else:
		cliente_atual = null

	# ==========================================
	# --- MÁQUINA DE ESTADO VISUAL DO POP-UP (UI) ---
	# Controla dinamicamente as mensagens flutuantes com base no progresso do nível.
	# ==========================================
	if _jogador_na_area:
		if not CustomerManager.tem_pedido_ativo():
			# Cenário: Não há nenhum pedido ativo sendo recolhido
			if cliente_atual and cliente_atual.estado == "esperando":
				popup_label.text = "[E] Pegar Pedido"
				popup_label.remove_theme_color_override("font_color")
			else:
				popup_label.text = "(Aguardando Cliente)"
				popup_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			# Cenário: Jogador já possui uma prancha com metas de sólidos geométricos
			if _jogador_na_area.shopping_cart.size() > 0:
				popup_label.text = "[E] Entregar Produtos"
				popup_label.remove_theme_color_override("font_color")
			else:
				popup_label.text = "(Carrinho Vazio)"
				popup_label.add_theme_color_override("font_color", Color.RED)

# ==========================================
# --- CAPTURA E VERIFICAÇÃO DE INPUT ---
# ==========================================

func _input(event: InputEvent) -> void:
	
	if not _jogador_na_area or _jogador_na_area.em_cutscene:
		return
		
	if _jogador_na_area:
		var apertou_botao = false
		
		# Suporte híbrido: mapeamento de ações da Godot ou detecção direta da tecla física 'E'
		if event.is_action_pressed("interact_e"):
			apertou_botao = true
		elif event is InputEventKey and event.keycode == Key.KEY_E and event.pressed and not event.echo:
			apertou_botao = true
			
		if apertou_botao:
			# --- CASO 1: Pegar nova lista com o cliente da vez ---
			if not CustomerManager.tem_pedido_ativo():
				if cliente_atual and cliente_atual.estado == "esperando":
					if cliente_atual.eh_vip:
						CustomerManager.gerar_pedido_boss_vip(_jogador_na_area.shopping_cart)
						_jogador_na_area.abrir_prancheta()
						_jogador_na_area.mostrar_notificacao("⭐ DESAFIO DO BOSS FINAL!\nEntregue todas as formas no prazo!", Color.GOLD)
					else:
						CustomerManager.gerar_novo_pedido(_jogador_na_area.shopping_cart)
						_jogador_na_area.abrir_prancheta()
						_jogador_na_area.mostrar_notificacao("Novo Pedido Recebido! Abra a lista de compras! (Tab)", Color.CYAN)
					get_tree().call_group("tutorial", "avancar_passo", "pegou_pedido")
			
			# --- CASO 2: Entregar a coleta armazenada no inventário ---
			else:
				if _jogador_na_area.shopping_cart.size() > 0:
					validar_compra()

# ==========================================
# --- NÚCLEO DE VALIDAÇÃO COMERCIAL (GAME LOOP) ---
# Compara os recursos coletados no carrinho do jogador com as exigências matemáticas do NPC.
# ==========================================

func validar_compra() -> void:
	var carrinho = _jogador_na_area.shopping_cart
	var resultado = CustomerManager.avaliar_carrinho(carrinho)

	# Captura o estado cronometrado antes de pausar o relógio global
	var tempo_sobrou = CustomerManager.pegar_tempo_restante()
	CustomerManager.timer_pedido.stop()

	# ==========================================
	# --- VALIDAÇÃO EXCLUSIVA DO BOSS FINAL (VIP) ---
	# ==========================================
	if CustomerManager.cliente_vip_ativo:
		if resultado["perfeito"] and tempo_sobrou > 0:
			# VITÓRIA! Finalizou o jogo!
			if som_sucesso:
				som_sucesso.play()
			EconomyManager.adicionar_recompensa(300.0, 15)
			_jogador_na_area.mostrar_notificacao("🏆 BOSS FINAL APROVADO!\nVocê dominou a Geometria!", Color.GOLD)
			if cliente_atual:
				cliente_atual.reagir_e_ir_embora(true)
			_limpar_apos_entrega()
			boss_vip_em_cena = false
			timer_spawn.start() # Já fica pronto caso escolha Modo Infinito
			_agendar_tela_vitoria()
		else:
			# FALHOU NO BOSS: barra volta a 0, mantém setores desbloqueados
			_falhar_boss_vip("❌ O CLIENTE VIP NÃO APROVOU!\nBarra de progresso zerada. Tente novamente!")
		return
		
	# ==========================================
	# --- SISTEMA DE RECOMPENSAS / PENALIDADES ---
	# ==========================================
	if resultado["perfeito"]:
		# --- CENÁRIO DE SUCESSO ABSOLUTO (LISTA PERFEITA) ---
		if som_sucesso:
			som_sucesso.play()

		var multiplicador_rep = EconomyManager.obter_multiplicador_reputacao()
		var eh_vip = CustomerManager.cliente_vip_ativo
		var multiplicador_vip = 2.0 if eh_vip else 1.0

		var total_de_itens = carrinho.size()
		var ganho_pelas_vendas = total_de_itens * preco_venda_por_item * multiplicador_rep * multiplicador_vip
		var ganho_pelo_tempo = tempo_sobrou * multiplicador_gorjeta_tempo * multiplicador_rep * multiplicador_vip
		var recompensa_final = ganho_pelas_vendas + ganho_pelo_tempo

		if tempo_sobrou > 0:
			# Atendimento dentro do prazo: valor integral + gorjeta + reputação (dobrada se VIP)
			var rep_ganha = 10 if eh_vip else 5
			EconomyManager.adicionar_recompensa(recompensa_final, rep_ganha)

			var prefixo = "⭐ VIP SUCESSO!" if eh_vip else "✅ SUCESSO!"
			var texto = "%s (x%s Rep)\n+$%s | +%d Reputação" % [
				prefixo,
				str(multiplicador_rep),
				str(snapped(recompensa_final, 0.1)),
				rep_ganha
			]
			_jogador_na_area.mostrar_notificacao(texto, Color.GOLD if eh_vip else Color.GREEN)
		else:
			# Atendimento em atraso (Tempo esgotado): valor base + reputação reduzida
			var rep_atraso = 2 if eh_vip else 1
			EconomyManager.adicionar_recompensa(ganho_pelas_vendas, rep_atraso)

			var texto = "⚠️ SUCESSO (Atrasado)!\n+$%s | +%d Reputação" % [
				str(snapped(ganho_pelas_vendas, 0.1)),
				rep_atraso
			]
			_jogador_na_area.mostrar_notificacao(texto, Color.YELLOW)

		# Verifica progresso de expansão ou vitória (vale para entrega no prazo ou atrasada)
		if EconomyManager.nivel_expansao < EconomyManager.expansoes_maximas and EconomyManager.clientes_atendidos >= EconomyManager.meta_expansao:
			_agendar_popup_expansao()
		elif not EconomyManager.modo_infinito and not boss_vip_em_cena and EconomyManager.nivel_expansao >= EconomyManager.expansoes_maximas and EconomyManager.clientes_atendidos >= EconomyManager.meta_vitoria:
			_iniciar_chegada_boss_vip()

		# Libera o NPC cliente com feedback positivo
		if cliente_atual:
			cliente_atual.reagir_e_ir_embora(true)

	else:
		# --- CENÁRIO DE FALHA (PRODUTO INCORRETO OU EM FALTA) ---
		if som_erro:
			som_erro.play()

		# Aplica uma taxa mínima de consolação, mas pune severamente a reputação da loja (-10)
		EconomyManager.dinheiro += 5.0
		EconomyManager.aplicar_punicao(0, 10)
		var texto = "❌ ERRO NO PEDIDO! (Extras/Errados: %d | Faltando: %d)\nGanhou apenas $5.0 | Perdeu 10 Reputação!" % [
			resultado["erros"],
			resultado["faltantes"]
		]
		_jogador_na_area.mostrar_notificacao(texto, Color.RED)

		# Libera o NPC cliente com feedback de insatisfação/irritação
		if cliente_atual:
			cliente_atual.reagir_e_ir_embora(false)

	# ==========================================
	# --- ETAPA DE LIMPEZA E RESET DE DADOS ---
	# Limpa buffers e prepara as estruturas de UI para o próximo cliente da fila.
	# ==========================================
	_jogador_na_area.shopping_cart.clear()
	get_tree().call_group("prateleiras", "resetar_itens_pegos")
	CustomerManager.pedido_atual.clear()
	CustomerManager.pedido_por_forma.clear()
	CustomerManager.cliente_vip_ativo = false

	if CustomerManager.ui_lista_de_itens:
		for child in CustomerManager.ui_lista_de_itens.get_children():
			child.queue_free()

	get_tree().call_group("tutorial", "avancar_passo", "entregou_pedido")

	# Desloca a fila de espera do mercado
	avancar_fila()

# ==========================================
# --- INTERAÇÃO FÍSICA ( SINAIS DA ÁREA 2D ) ---
# Animações em Tween para suavizar a entrada/saída da janela de diálogo do caixa.
# ==========================================

func _on_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		_jogador_na_area = body
		
		popup_label.visible = true
		popup_label.scale = Vector2.ZERO
		
		# Efeito elástico (TRANS_BACK) ao surgir na tela
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(popup_label, "scale", Vector2(1, 1), 0.3)


func _on_body_exited(body: Node2D) -> void:
	if body is BaseCharacter:
		_jogador_na_area = null
		
		# Encolhe o elemento de UI antes de desativar sua visibilidade
		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(popup_label, "scale", Vector2.ZERO, 0.2)
		tween.tween_callback(func(): popup_label.visible = false)

# ==========================================
# --- LOGÍSTICA DE RECRUTAMENTO DE FILA (NPCs) ---
# ==========================================

func _on_timer_spawn_timeout() -> void:
	if boss_vip_em_cena:
		return
	if fila_de_clientes.size() < posicoes_da_fila.size():
		gerar_novo_cliente()


func gerar_novo_cliente() -> void:
	if cena_cliente:
		var novo_cliente = cena_cliente.instantiate()
		
		# Aloca o objeto de forma segura na hierarquia para evitar conflitos de ciclo de física
		get_parent().add_child.call_deferred(novo_cliente)
		
		# Atribui o waypoint correto ao cliente baseado na quantidade de pessoas paradas
		var posicao_na_fila = fila_de_clientes.size()
		novo_cliente.posicao_caixa = posicoes_da_fila[posicao_na_fila]
		fila_de_clientes.append(novo_cliente)
		
		if som_cliente_chegou:
			som_cliente_chegou.play()


func avancar_fila() -> void:
	if fila_de_clientes.size() > 0:
		# Descarta o primeiro elemento (atendido) da estrutura de dados
		fila_de_clientes.pop_front()

	# Varre os clientes restantes na fila e reconfigura o destino de seus caminhos (Waypoints)
	for i in range(fila_de_clientes.size()):
		var cliente = fila_de_clientes[i]
		cliente.posicao_caixa = posicoes_da_fila[i]
		
		# Se o cliente já estava aguardando, acorda o estado para fazê-lo andar até a nova vaga da frente
		if cliente.estado == "esperando":
			cliente.estado = "entrando_passo2"
			cliente.animacao.play("walk_left")

# ==========================================
# ---       SISTEMA DE EXPANSÃO          ---
# ==========================================
func _agendar_popup_expansao() -> void:
	# Aguarda 0.3 segundos para garantir que o som do caixa toque até o fim 
	# e a barra chegue em 100% no HUD antes do popup pausar o jogo.
	await get_tree().create_timer(0.3).timeout
	
	var cena_popup = preload("res://UI/popup_expansao.tscn").instantiate()
	get_tree().current_scene.add_child(cena_popup)
	
	# O reset da barra ocorre somente quando a tela de expansão já estiver visível
	EconomyManager.clientes_atendidos = 0

func _agendar_tela_vitoria() -> void:
	await get_tree().create_timer(0.3).timeout
	var tela = preload("res://UI/tela_vitoria.tscn").instantiate()
	get_tree().current_scene.add_child(tela)

func _limpar_apos_entrega() -> void:
	var jogador = _jogador_na_area if _jogador_na_area else get_tree().get_first_node_in_group("jogador")
	if jogador:
		jogador.shopping_cart.clear()
	get_tree().call_group("prateleiras", "resetar_itens_pegos")
	CustomerManager.pedido_atual.clear()
	CustomerManager.pedido_por_forma.clear()
	CustomerManager.cliente_vip_ativo = false

	if CustomerManager.ui_lista_de_itens:
		for child in CustomerManager.ui_lista_de_itens.get_children():
			child.queue_free()

	avancar_fila()

func _on_tempo_pedido_esgotado() -> void:
	# Se o tempo zerar durante o desafio do Boss, já encerra e reseta a barra
	if CustomerManager.cliente_vip_ativo and boss_vip_em_cena:
		_falhar_boss_vip("⏰ TEMPO ESGOTADO! O Cliente VIP foi embora!\nBarra de progresso zerada.")

func _falhar_boss_vip(mensagem: String) -> void:
	if som_erro:
		som_erro.play()

	# Zera apenas a barra de progresso, mantendo nivel_expansao (setores desbloqueados) intacto!
	EconomyManager.clientes_atendidos = 0
	EconomyManager.aplicar_punicao(0, 5)

	var jogador = _jogador_na_area if _jogador_na_area else get_tree().get_first_node_in_group("jogador")
	if jogador:
		jogador.mostrar_notificacao(mensagem, Color.RED)

	if cliente_atual:
		cliente_atual.reagir_e_ir_embora(false)

	_limpar_apos_entrega()
	boss_vip_em_cena = false
	timer_spawn.start()
	gerar_novo_cliente()

func _iniciar_chegada_boss_vip() -> void:
	boss_vip_em_cena = true
	timer_spawn.stop()

	# Dispensa clientes comuns restantes da fila para abrir caminho ao Boss
	for c in fila_de_clientes:
		if is_instance_valid(c):
			c.reagir_e_ir_embora(true)
	fila_de_clientes.clear()

	await get_tree().create_timer(0.6).timeout

	var jogador = get_tree().get_first_node_in_group("jogador")
	if not cena_cliente or not jogador:
		boss_vip_em_cena = false
		timer_spawn.start()
		return

	# Instancia o Cliente VIP na porta
	var vip: Cliente = cena_cliente.instantiate()
	vip.configurar_como_vip()
	vip.posicao_caixa = posicoes_da_fila[0]
	get_parent().add_child(vip)
	fila_de_clientes.append(vip)

	if som_cliente_chegou:
		som_cliente_chegou.play()

	# CUTSCENE: câmera vai até o VIP e o acompanha andando até o caixa
	await jogador.iniciar_cutscene_camera(vip)

	# Aguarda o VIP encostar no balcão do caixa
	if vip.estado != "esperando":
		await vip.chegou_no_caixa_vip

	# Dá um leve zoom e exibe as falas do Boss Final
	await jogador.focar_zoom_cutscene(1.2)
	await vip.falar_sequencia_vip([
		"Com licença... Sou o Crítico Supremo!",
		"Ouvi dizer que vocês dominam todas as formas.",
		"Complete meu pedido perfeito e vença o jogo!",
		"Vamos lá, Kratos. Pegue minha lista!"
	])

	# CUTSCENE: câmera retorna suavemente para o Kratos
	await jogador.finalizar_cutscene_camera()

	jogador.mostrar_notificacao("⭐ O CLIENTE VIP TE AGUARDA NO CAIXA! Aperte [E]", Color.GOLD)
