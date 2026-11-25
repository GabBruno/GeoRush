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
@export var preco_venda_por_item: float = 5.0 # Valor bruto por produto entregue
@export var multiplicador_gorjeta_tempo: float = 0.25 # Bônus financeiro por segundo restante

@onready var timer_spawn: Timer = $TimerSpawn

var boss_vip_em_cena: bool = false
var clientes_liberados: bool = false

# ==========================================
# --- VARIÁVEIS DE ESTADO DO CAIXA ---
# ==========================================
var cliente_atual: Cliente
var _jogador_na_area: BaseCharacter = null

# ==========================================
# --- SISTEMA DE FILA DE CLIENTES ---
# ==========================================
var fila_de_clientes: Array = []
var posicoes_da_fila: Array[Vector2] = [
	Vector2(145, 224),
	Vector2(202, 224),
	Vector2(259, 224),
	Vector2(316, 224)
]

# ==========================================
# --- CICLO DE VIDA DO OBJETO (LIFECYCLE) ---
# ==========================================

func _ready() -> void:
	add_to_group("caixa_checkout")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	popup_label.visible = false

	CustomerManager.timer_pedido.timeout.connect(_on_tempo_pedido_esgotado)

	if CustomerManager.tutorial_concluido:
		liberar_chegada_clientes()
	else:
		if timer_spawn:
			timer_spawn.stop()


func _process(_delta: float) -> void:
	if fila_de_clientes.size() > 0:
		cliente_atual = fila_de_clientes[0]
	else:
		cliente_atual = null

	if _jogador_na_area:
		if not CustomerManager.tem_pedido_ativo():
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

# ==========================================
# --- CONTROLE DE ÁUDIO DA FASE ---
# ==========================================

func _coletar_players_audio(no: Node, lista: Array[Node]) -> void:
	if no is AudioStreamPlayer or no is AudioStreamPlayer2D:
		lista.append(no)
	for filho in no.get_children():
		_coletar_players_audio(filho, lista)


func _parar_musicas_fase() -> void:
	get_tree().call_group("musica_fase", "stop")
	get_tree().call_group("musica_fundo", "stop")
	get_tree().call_group("musica_boss", "stop")

	var players: Array[Node] = []
	_coletar_players_audio(get_tree().root, players)

	for p in players:
		if not p.playing:
			continue

		var nome_lower: String = p.name.to_lower()
		var caminho_stream: String = ""
		if p.stream:
			caminho_stream = p.stream.resource_path.to_lower()

		var eh_musica: bool = (
			"musica" in nome_lower or "fundo" in nome_lower or "boss" in nome_lower or "bgm" in nome_lower
			or "musica" in caminho_stream or "fundo" in caminho_stream or "boss" in caminho_stream
		)
		if eh_musica:
			print("[Audio] Parando música: ", p.get_path(), " | Arquivo: ", caminho_stream)
			p.stop()


func _ativar_loop_musica(player: Node, eh_boss: bool) -> void:
	if not player or not player.stream:
		return

	if player.stream is AudioStreamMP3 or player.stream is AudioStreamOggVorbis:
		player.stream.loop = true
	elif not player.has_meta("loop_conectado"):
		# Fallback para .wav caso o Loop Mode não tenha sido configurado no Import
		player.set_meta("loop_conectado", true)
		player.finished.connect(func() -> void:
			if not is_instance_valid(player) or get_tree().paused:
				return
			if eh_boss == boss_vip_em_cena:
				player.play()
		)


func _tocar_musica_fase(grupo: String, nome_fallback: String) -> void:
	var eh_boss: bool = (grupo == "musica_boss")
	var nos: Array[Node] = get_tree().get_nodes_in_group(grupo)
	if not nos.is_empty():
		for n in nos:
			_ativar_loop_musica(n, eh_boss)
			n.play()
		return

	var players: Array[Node] = []
	_coletar_players_audio(get_tree().root, players)
	var busca: String = nome_fallback.to_lower()

	for p in players:
		var nome_lower: String = p.name.to_lower()
		var caminho_stream: String = p.stream.resource_path.to_lower() if p.stream else ""
		if nome_lower == busca or (eh_boss and "boss" in caminho_stream) or (not eh_boss and "musica_fundo" in caminho_stream):
			_ativar_loop_musica(p, eh_boss)
			p.play()
			return

# ==========================================
# --- CAPTURA E VERIFICAÇÃO DE INPUT ---
# ==========================================

func _input(event: InputEvent) -> void:
	if not _jogador_na_area or _jogador_na_area.em_cutscene:
		return

	var apertou_botao: bool = false

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
				cliente_atual.definir_sendo_atendido(true)

		# --- CASO 2: Entregar a coleta armazenada no inventário ---
		else:
			if _jogador_na_area.shopping_cart.size() > 0:
				validar_compra()

# ==========================================
# --- NÚCLEO DE VALIDAÇÃO COMERCIAL (GAME LOOP) ---
# ==========================================

func validar_compra() -> void:
	var carrinho = _jogador_na_area.shopping_cart
	var resultado = CustomerManager.avaliar_carrinho(carrinho)

	var tempo_sobrou = CustomerManager.pegar_tempo_restante()
	CustomerManager.timer_pedido.stop()

	# ==========================================
	# --- VALIDAÇÃO EXCLUSIVA DO BOSS FINAL (VIP) ---
	# ==========================================
	if CustomerManager.cliente_vip_ativo:
		if resultado["perfeito"] and tempo_sobrou > 0:
			if som_sucesso:
				som_sucesso.play()
			EconomyManager.adicionar_recompensa(300.0, 15)
			get_tree().call_group("hud", "animar_ganho_dinheiro", 300.0)
			get_tree().call_group("hud", "animar_variacao_reputacao", 15)
			atualizar_ritmo_spawn()

			_jogador_na_area.mostrar_notificacao("🏆 BOSS FINAL APROVADO!\nVocê dominou a Geometria!", Color.GOLD)
			if cliente_atual:
				cliente_atual.reagir_e_ir_embora(true)
			_limpar_apos_entrega()
			boss_vip_em_cena = false
			timer_spawn.start()
			_agendar_tela_vitoria()
		else:
			_falhar_boss_vip("❌ O CLIENTE VIP NÃO APROVOU!\nBarra de progresso zerada. Tente novamente!")
		return

	# ==========================================
	# --- SISTEMA DE RECOMPENSAS / PENALIDADES ---
	# ==========================================
	var acionar_expansao: bool = false
	var acionar_boss_vip: bool = false

	if resultado["perfeito"]:
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
			var rep_ganha: int = 10 if eh_vip else 5
			EconomyManager.adicionar_recompensa(recompensa_final, rep_ganha)
			get_tree().call_group("hud", "animar_ganho_dinheiro", recompensa_final)
			get_tree().call_group("hud", "animar_variacao_reputacao", rep_ganha)

			var prefixo = "⭐ VIP SUCESSO!" if eh_vip else "✅ SUCESSO!"
			var texto = "%s (x%s Rep)\n+$%s | +%d Reputação" % [
				prefixo,
				str(multiplicador_rep),
				str(snapped(recompensa_final, 0.1)),
				rep_ganha
			]
			_jogador_na_area.mostrar_notificacao(texto, Color.GOLD if eh_vip else Color.GREEN)
		else:
			var rep_atraso: int = 2 if eh_vip else 1
			EconomyManager.adicionar_recompensa(ganho_pelas_vendas, rep_atraso)
			get_tree().call_group("hud", "animar_ganho_dinheiro", ganho_pelas_vendas)
			get_tree().call_group("hud", "animar_variacao_reputacao", rep_atraso)

			var texto = "⚠️ SUCESSO (Atrasado)!\n+$%s | +%d Reputação" % [
				str(snapped(ganho_pelas_vendas, 0.1)),
				rep_atraso
			]
			_jogador_na_area.mostrar_notificacao(texto, Color.YELLOW)

		if EconomyManager.nivel_expansao < EconomyManager.expansoes_maximas and EconomyManager.clientes_atendidos >= EconomyManager.meta_expansao:
			acionar_expansao = true
		elif not EconomyManager.modo_infinito and not boss_vip_em_cena and EconomyManager.nivel_expansao >= EconomyManager.expansoes_maximas and EconomyManager.clientes_atendidos >= EconomyManager.meta_vitoria:
			acionar_boss_vip = true

		if cliente_atual:
			cliente_atual.reagir_e_ir_embora(true)

	else:
		if som_erro:
			som_erro.play()

		var multa_real: float = minf(10.0, EconomyManager.dinheiro)
		EconomyManager.aplicar_punicao(10.0, 10)
		if multa_real > 0.0:
			get_tree().call_group("hud", "animar_gasto_dinheiro", multa_real)
		get_tree().call_group("hud", "animar_variacao_reputacao", -10)

		var texto = "❌ ERRO NO PEDIDO! (Extras/Errados: %d | Faltando: %d)\nMulta -$10 | -10 Reputação!" % [
			resultado["erros"],
			resultado["faltantes"]
		]
		_jogador_na_area.mostrar_notificacao(texto, Color.RED)

		if cliente_atual:
			cliente_atual.reagir_e_ir_embora(false)

	# ==========================================
	# --- ETAPA DE LIMPEZA E RESET DE DADOS ---
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
	atualizar_ritmo_spawn()
	avancar_fila()

	# Dispara eventos de progressão somente após limpar a entrega e avançar a fila
	if acionar_expansao:
		_agendar_popup_expansao()
	elif acionar_boss_vip:
		_iniciar_chegada_boss_vip()

# ==========================================
# --- INTERAÇÃO FÍSICA (SINAIS DA ÁREA 2D) ---
# ==========================================

func _on_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		_jogador_na_area = body

		popup_label.visible = true
		popup_label.scale = Vector2.ZERO

		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(popup_label, "scale", Vector2(1, 1), 0.3)


func _on_body_exited(body: Node2D) -> void:
	if body is BaseCharacter:
		_jogador_na_area = null

		var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.tween_property(popup_label, "scale", Vector2.ZERO, 0.2)
		tween.tween_callback(func(): popup_label.visible = false)

# ==========================================
# --- LOGÍSTICA DE RECRUTAMENTO DE FILA (NPCs) ---
# ==========================================

func _on_timer_spawn_timeout() -> void:
	if boss_vip_em_cena or not clientes_liberados or not CustomerManager.tutorial_concluido:
		return
	if fila_de_clientes.size() < posicoes_da_fila.size():
		gerar_novo_cliente()


func gerar_novo_cliente() -> void:
	if cena_cliente:
		var novo_cliente = cena_cliente.instantiate()

		get_parent().add_child.call_deferred(novo_cliente)

		var posicao_na_fila = fila_de_clientes.size()
		novo_cliente.posicao_caixa = posicoes_da_fila[posicao_na_fila]
		fila_de_clientes.append(novo_cliente)

		novo_cliente.definir_indice_fila(fila_de_clientes.size() - 1)
		novo_cliente.paciencia_esgotada.connect(_on_cliente_sem_paciencia)
		atualizar_ritmo_spawn()

		if som_cliente_chegou:
			som_cliente_chegou.play()


func avancar_fila() -> void:
	if fila_de_clientes.size() > 0:
		fila_de_clientes.pop_front()
		_reorganizar_fila()

# ==========================================
# ---       SISTEMA DE EXPANSÃO          ---
# ==========================================
func _agendar_popup_expansao() -> void:
	await get_tree().create_timer(0.3).timeout

	var cena_popup = preload("res://UI/popup_expansao.tscn").instantiate()
	get_tree().current_scene.add_child(cena_popup)

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
	if CustomerManager.cliente_vip_ativo and boss_vip_em_cena:
		_falhar_boss_vip("⏰ TEMPO ESGOTADO! O Cliente VIP foi embora!\nBarra de progresso zerada.")


func _falhar_boss_vip(mensagem: String) -> void:
	if som_erro:
		som_erro.play()

	EconomyManager.clientes_atendidos = 0
	EconomyManager.aplicar_punicao(0, 5)
	get_tree().call_group("hud", "animar_variacao_reputacao", -5)
	atualizar_ritmo_spawn()

	var jogador = _jogador_na_area if _jogador_na_area else get_tree().get_first_node_in_group("jogador")
	if jogador:
		jogador.mostrar_notificacao(mensagem, Color.RED)

	if cliente_atual:
		cliente_atual.reagir_e_ir_embora(false)

	_limpar_apos_entrega()
	boss_vip_em_cena = false

	# Só religa a música normal e os clientes se a reputação não zerou (sem Game Over)
	if EconomyManager.reputacao > 0:
		_parar_musicas_fase()
		_tocar_musica_fase("musica_fundo", "MusicaFundo")
		timer_spawn.start()
		gerar_novo_cliente()


func _aguardar_loja_vazia(tempo_maximo: float = 9.0) -> void:
	var decorrido: float = 0.0
	while decorrido < tempo_maximo:
		var ativos: int = 0
		for n in get_tree().get_nodes_in_group("clientes"):
			if is_instance_valid(n) and not n.is_queued_for_deletion():
				ativos += 1
		if ativos == 0:
			break
		await get_tree().create_timer(0.15).timeout
		decorrido += 0.15


func _iniciar_chegada_boss_vip() -> void:
	boss_vip_em_cena = true
	timer_spawn.stop()

	# Dispensa todos os clientes restantes da fila
	for c in fila_de_clientes:
		if is_instance_valid(c):
			c.reagir_e_ir_embora(true)
	fila_de_clientes.clear()
	cliente_atual = null

	# Aguarda todos os clientes saírem completamente do mercado antes do Boss entrar
	await _aguardar_loja_vazia(9.0)

	var jogador = get_tree().get_first_node_in_group("jogador")
	if not cena_cliente or not jogador:
		boss_vip_em_cena = false
		timer_spawn.start()
		return

	# Troca para a música de tensão do Boss garantindo que a música de fundo pare
	_parar_musicas_fase()
	_tocar_musica_fase("musica_boss", "MusicaBoss")

	var vip: Cliente = cena_cliente.instantiate()
	vip.configurar_como_vip()
	vip.posicao_caixa = posicoes_da_fila[0]
	get_parent().add_child(vip)
	fila_de_clientes.append(vip)

	if som_cliente_chegou:
		som_cliente_chegou.play()

	await jogador.iniciar_cutscene_camera(vip)

	if vip.estado != "esperando":
		await vip.chegou_no_caixa_vip

	await jogador.focar_zoom_cutscene(1.2)
	await vip.falar_sequencia_vip([
		"Com licença... Sou o Crítico Supremo!",
		"Ouvi dizer que vocês dominam todas as formas.",
		"Complete meu pedido perfeito e vença o jogo!",
		"Vamos lá, Kratos. Pegue minha lista!"
	])

	await jogador.finalizar_cutscene_camera()

	jogador.mostrar_notificacao("⭐ O CLIENTE VIP TE AGUARDA NO CAIXA! Aperte [E]", Color.GOLD)


func chamar_cliente_tutorial() -> void:
	# Chama apenas 1 cliente para o pedido guiado e mantém o spawn pausado até clicar em "Começar!"
	if fila_de_clientes.is_empty():
		gerar_novo_cliente()
	if timer_spawn:
		timer_spawn.stop()


func liberar_chegada_clientes() -> void:
	if clientes_liberados:
		return

	clientes_liberados = true
	atualizar_ritmo_spawn()
	if fila_de_clientes.is_empty():
		gerar_novo_cliente()
	if timer_spawn:
		timer_spawn.start()


func atualizar_ritmo_spawn() -> void:
	if timer_spawn:
		timer_spawn.wait_time = EconomyManager.obter_intervalo_spawn_clientes()


func _reorganizar_fila() -> void:
	for i in range(fila_de_clientes.size()):
		var c: Cliente = fila_de_clientes[i]
		if not is_instance_valid(c):
			continue
		c.definir_indice_fila(i)
		c.posicao_caixa = posicoes_da_fila[i]
		if c.estado == "esperando" and c.global_position.distance_to(c.posicao_caixa) > 2.0:
			c.estado = "entrando_passo2"

	if not fila_de_clientes.is_empty():
		cliente_atual = fila_de_clientes[0]
	else:
		cliente_atual = null


func _on_cliente_sem_paciencia(cliente_desistente: Cliente) -> void:
	if not fila_de_clientes.has(cliente_desistente):
		return

	fila_de_clientes.erase(cliente_desistente)
	_reorganizar_fila()

	if som_erro:
		som_erro.play()

	EconomyManager.aplicar_punicao(0, 5)
	get_tree().call_group("hud", "animar_variacao_reputacao", -5)
	atualizar_ritmo_spawn()

	var jogador = _jogador_na_area if _jogador_na_area else get_tree().get_first_node_in_group("jogador")
	if jogador:
		jogador.mostrar_notificacao("😠 Um cliente perdeu a paciência e foi embora!\n-5 Reputação", Color.ORANGE_RED)
