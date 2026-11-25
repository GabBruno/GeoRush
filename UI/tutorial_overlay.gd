extends CanvasLayer
class_name TutorialOverlay

# ==========================================
# --- ESTADOS DO TUTORIAL INTERATIVO ---
# ==========================================
enum Passo {
	BOAS_VINDAS,
	TOUR_PORTA,
	TOUR_CAIXA,
	TOUR_GONDOLAS,
	TOUR_COMPUTADOR,
	ESCOLHA_MODO,
	IR_AO_CAIXA,
	COLETAR_PRODUTOS,
	ENTREGAR_NO_CAIXA,
	CONCLUIDO
}

@export var largura_maxima_caixa: float = 900.0
@export var margem_inferior_caixa: float = 32.0

var passo_atual: Passo = Passo.BOAS_VINDAS
var _jogador: BaseCharacter = null
var _pontos_tutorial: Node = null
var _holofote_tween: Tween
var _raio_padrao: float = 0.20
var _raio_atual: float = 0.20

# ==========================================
# --- REFERÊNCIAS DE NODES ---
# ==========================================
@onready var holofote: ColorRect = $Holofote
@onready var painel_dialogo: PanelContainer = $PainelDialogo
@onready var titulo_label: Label = $PainelDialogo/MarginContainer/VBoxContainer/TituloKratos
@onready var texto_fala: Label = $PainelDialogo/MarginContainer/VBoxContainer/TextoFala
@onready var btn_secundario: Button = $PainelDialogo/MarginContainer/VBoxContainer/Botoes/BotaoSecundario
@onready var btn_principal: Button = $PainelDialogo/MarginContainer/VBoxContainer/Botoes/BotaoPrincipal
@onready var som_clique: AudioStreamPlayer = get_node_or_null("SomClique") as AudioStreamPlayer


# ==========================================
# --- INICIALIZAÇÃO ---
# ==========================================
func _ready() -> void:
	if CustomerManager.tutorial_concluido:
		queue_free()
		return

	add_to_group("tutorial")
	holofote.visible = false
	holofote.modulate.a = 0.0

	if holofote.material is ShaderMaterial:
		var raio_inspector: Variant = holofote.material.get_shader_parameter("raio")
		if raio_inspector != null:
			_raio_padrao = float(raio_inspector)
	_raio_atual = _raio_padrao

	_configurar_limites_painel()
	get_viewport().size_changed.connect(_reajustar_tamanho_painel)

	if not btn_principal.pressed.is_connected(_on_botao_principal_pressed):
		btn_principal.pressed.connect(_on_botao_principal_pressed)
	if not btn_secundario.pressed.is_connected(_on_botao_secundario_pressed):
		btn_secundario.pressed.connect(_on_botao_secundario_pressed)

	# Aguarda 1 frame para garantir que MercadoManager e Atendente já estejam carregados
	await get_tree().process_frame
	_jogador = get_tree().get_first_node_in_group("jogador") as BaseCharacter
	_pontos_tutorial = get_tree().get_first_node_in_group("pontos_tutorial")

	if _jogador:
		_jogador.em_cutscene = true

	_atualizar_interface()


# ==========================================
# --- LIMITES DE LARGURA E QUEBRA DE LINHA ---
# ==========================================
func _configurar_limites_painel() -> void:
	if titulo_label:
		titulo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		titulo_label.custom_minimum_size.x = 0.0
	if texto_fala:
		texto_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto_fala.custom_minimum_size.x = 0.0
	if painel_dialogo:
		# Centro horizontal (0.5) e base da tela (1.0)
		painel_dialogo.anchor_left = 0.5
		painel_dialogo.anchor_right = 0.5
		painel_dialogo.anchor_top = 1.0
		painel_dialogo.anchor_bottom = 1.0
		painel_dialogo.grow_horizontal = Control.GROW_DIRECTION_BOTH
		painel_dialogo.grow_vertical = Control.GROW_DIRECTION_BEGIN

	_reajustar_tamanho_painel()


func _reajustar_tamanho_painel() -> void:
	if not painel_dialogo or not is_inside_tree():
		return

	var tamanho_tela: Vector2 = get_viewport().get_visible_rect().size
	var largura_alvo: float = minf(largura_maxima_caixa, tamanho_tela.x - 64.0)

	painel_dialogo.custom_minimum_size.x = largura_alvo
	painel_dialogo.size.x = largura_alvo
	painel_dialogo.size.y = 0.0
	painel_dialogo.reset_size()

	await get_tree().process_frame
	if not painel_dialogo or not is_inside_tree():
		return

	var altura_atual: float = painel_dialogo.size.y
	painel_dialogo.position = Vector2(
		(tamanho_tela.x - largura_alvo) * 0.5,
		tamanho_tela.y - altura_atual - margem_inferior_caixa
	)


# ==========================================
# --- CONTROLE VISUAL (HOLOFOTE E CÂMERA) ---
# ==========================================
func _aplicar_raio_holofote(valor: float) -> void:
	_raio_atual = valor
	if holofote.material is ShaderMaterial:
		holofote.material.set_shader_parameter("raio", valor)


func _definir_holofote(ativo: bool) -> Tween:
	if ativo:
		if holofote.visible and holofote.modulate.a >= 0.99 and is_equal_approx(_raio_atual, _raio_padrao):
			return _holofote_tween

		if _holofote_tween and _holofote_tween.is_valid():
			_holofote_tween.kill()

		if not holofote.visible:
			_aplicar_raio_holofote(1.1)
			holofote.modulate.a = 0.0
			holofote.visible = true

		_holofote_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_holofote_tween.tween_property(holofote, "modulate:a", 1.0, 0.4)
		_holofote_tween.tween_method(_aplicar_raio_holofote, _raio_atual, _raio_padrao, 0.5)
		return _holofote_tween
	else:
		if not holofote.visible:
			return null

		if _holofote_tween and _holofote_tween.is_valid():
			_holofote_tween.kill()

		_holofote_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_holofote_tween.tween_method(_aplicar_raio_holofote, _raio_atual, 1.25, 0.6)
		_holofote_tween.tween_property(holofote, "modulate:a", 0.0, 0.55)
		_holofote_tween.chain().tween_callback(func() -> void: holofote.visible = false)
		return _holofote_tween


func _focar_marcador(nome_marcador: String, zoom_extra: float = 1.35) -> void:
	if not _jogador:
		return

	var marcador: Node2D = null
	if _pontos_tutorial:
		marcador = _pontos_tutorial.get_node_or_null(nome_marcador) as Node2D

	if marcador:
		_jogador.focar_posicao_camera(marcador.global_position, zoom_extra)
		_definir_holofote(true)


# ==========================================
# --- ATUALIZAÇÃO DE TEXTOS, BOTÕES E CÂMERA ---
# ==========================================
func _atualizar_interface() -> void:
	match passo_atual:
		Passo.BOAS_VINDAS:
			_definir_holofote(false)
			titulo_label.text = "PRIMEIRO DIA NO GEORUSH!"
			texto_fala.text = "Olá! Sou o Kratos. Vamos fazer um tour rápido pelo mercado antes do turno começar!"
			btn_principal.text = "Próximo"
			btn_principal.visible = true
			btn_secundario.text = "Pular Tutorial"
			btn_secundario.visible = true

		Passo.TOUR_PORTA:
			_focar_marcador("PontoPorta", 1.35)
			titulo_label.text = "1/4 — ENTRADA"
			texto_fala.text = "Os clientes entram por aqui e vão até a fila do caixa aguardando atendimento."
			btn_principal.text = "Próximo"
			btn_principal.visible = true
			btn_secundario.text = "Pular Tutorial"
			btn_secundario.visible = true

		Passo.TOUR_CAIXA:
			_focar_marcador("PontoCaixa", 1.40)
			titulo_label.text = "2/4 — CAIXA"
			texto_fala.text = "Aperte [E] para pegar a lista ([Tab] abre/fecha) e [E] novamente para entregar o pedido."
			btn_principal.text = "Próximo"
			btn_principal.visible = true
			btn_secundario.text = "Pular Tutorial"
			btn_secundario.visible = true

		Passo.TOUR_GONDOLAS:
			_focar_marcador("PontoGondolas", 1.25)
			titulo_label.text = "3/4 — GÔNDOLAS"
			texto_fala.text = "Setores por forma geométrica! [E] pega, [R] devolve ([Shift+R] devolve tudo) e [F] repõe."
			btn_principal.text = "Próximo"
			btn_principal.visible = true
			btn_secundario.text = "Pular Tutorial"
			btn_secundario.visible = true

		Passo.TOUR_COMPUTADOR:
			_focar_marcador("PontoComputador", 1.45)
			titulo_label.text = "4/4 — UPGRADES"
			texto_fala.text = "Aperte [E] aqui para comprar melhorias: Tênis Veloz, Gôndolas Maiores e Repositor."
			btn_principal.text = "Próximo"
			btn_principal.visible = true
			btn_secundario.text = "Pular Tutorial"
			btn_secundario.visible = true

		Passo.ESCOLHA_MODO:
			if _jogador:
				_jogador.focar_posicao_camera(_jogador.global_position, 1.25, 0.55)
			_definir_holofote(true)
			titulo_label.text = "PRONTO PARA COMEÇAR?"
			texto_fala.text = "Prefere fazer o primeiro pedido guiado ou já seguir sozinho?"
			btn_principal.text = "Pedido Guiado"
			btn_principal.visible = true
			btn_secundario.text = "Seguir Sozinho"
			btn_secundario.visible = true

		Passo.IR_AO_CAIXA:
			titulo_label.text = "GUIA (1/3) — VÁ AO CAIXA"
			texto_fala.text = "Use [WASD]/Setas ([Shift] corre) até o caixa e aperte [E] para pegar o pedido."
			btn_principal.visible = false
			btn_secundario.text = "Pular Tutorial"
			btn_secundario.visible = true

		Passo.COLETAR_PRODUTOS:
			titulo_label.text = "GUIA (2/3) — COLETE ESFERAS"
			texto_fala.text = "Vá até a gôndola de Maçãs (Esferas) e aperte [E] duas vezes para pegar 2 Maçãs."
			btn_principal.visible = false
			btn_secundario.text = "Pular Tutorial"
			btn_secundario.visible = true

		Passo.ENTREGAR_NO_CAIXA:
			titulo_label.text = "GUIA (3/3) — ENTREGUE"
			texto_fala.text = "Tudo certo! Volte ao balcão do caixa e aperte [E] para finalizar a entrega."
			btn_principal.visible = false
			btn_secundario.text = "Pular Tutorial"
			btn_secundario.visible = true

		Passo.CONCLUIDO:
			titulo_label.text = "TURNO LIBERADO!"
			texto_fala.text = "Mandou bem! Cuide do tempo e da reputação para expandir o mercado até o Cliente VIP!"
			btn_principal.text = "Começar!"
			btn_principal.visible = true
			btn_secundario.visible = false

	_reajustar_tamanho_painel()


# ==========================================
# --- AÇÕES DOS BOTÕES ---
# ==========================================
func _tocar_clique() -> void:
	if som_clique:
		som_clique.play()


func _on_botao_principal_pressed() -> void:
	_tocar_clique()
	btn_principal.release_focus()

	match passo_atual:
		Passo.BOAS_VINDAS:
			passo_atual = Passo.TOUR_PORTA
			_atualizar_interface()
		Passo.TOUR_PORTA:
			passo_atual = Passo.TOUR_CAIXA
			_atualizar_interface()
		Passo.TOUR_CAIXA:
			passo_atual = Passo.TOUR_GONDOLAS
			_atualizar_interface()
		Passo.TOUR_GONDOLAS:
			passo_atual = Passo.TOUR_COMPUTADOR
			_atualizar_interface()
		Passo.TOUR_COMPUTADOR:
			passo_atual = Passo.ESCOLHA_MODO
			_atualizar_interface()
		Passo.ESCOLHA_MODO:
			btn_principal.disabled = true
			btn_secundario.disabled = true
			get_tree().call_group("caixa_checkout", "chamar_cliente_tutorial")

			var tween_saida: Tween = _definir_holofote(false)
			if _jogador:
				await _jogador.finalizar_cutscene_camera()
			if tween_saida and tween_saida.is_running():
				await tween_saida.finished

			btn_principal.disabled = false
			btn_secundario.disabled = false
			passo_atual = Passo.IR_AO_CAIXA
			_atualizar_interface()
		Passo.CONCLUIDO:
			CustomerManager.tutorial_concluido = true
			get_tree().call_group("caixa_checkout", "liberar_chegada_clientes")
			queue_free()


func _on_botao_secundario_pressed() -> void:
	_tocar_clique()
	_encerrar_tutorial_agora()


func _encerrar_tutorial_agora() -> void:
	btn_principal.disabled = true
	btn_secundario.disabled = true
	CustomerManager.tutorial_concluido = true
	painel_dialogo.visible = false

	get_tree().call_group("caixa_checkout", "liberar_chegada_clientes")

	var tween_saida: Tween = _definir_holofote(false)
	if _jogador:
		await _jogador.finalizar_cutscene_camera()
	if tween_saida and tween_saida.is_running():
		await tween_saida.finished

	queue_free()


# ==========================================
# --- EVENTOS DO 1º PEDIDO GUIADO ---
# ==========================================
func avancar_passo(evento: String) -> void:
	match evento:
		"pegou_pedido":
			if passo_atual == Passo.IR_AO_CAIXA:
				passo_atual = Passo.COLETAR_PRODUTOS
				_atualizar_interface()
		"entregou_pedido":
			if passo_atual == Passo.COLETAR_PRODUTOS or passo_atual == Passo.ENTREGAR_NO_CAIXA:
				passo_atual = Passo.CONCLUIDO
				_atualizar_interface()


func verificar_coleta(carrinho: Array[ProductData]) -> void:
	if passo_atual != Passo.COLETAR_PRODUTOS:
		return

	var qtd_corretos: int = 0
	var tem_item_errado: bool = false

	for item in carrinho:
		if item.product_name.to_lower().strip_edges() == "maçã":
			qtd_corretos += 1
		else:
			tem_item_errado = true

	if tem_item_errado or qtd_corretos > 2:
		texto_fala.text = "Ops! Item errado ou a mais. Encoste na prateleira e aperte [R] para devolver!"
		_reajustar_tamanho_painel()
	elif qtd_corretos == 2:
		passo_atual = Passo.ENTREGAR_NO_CAIXA
		_atualizar_interface()
	else:
		texto_fala.text = "Ótimo! Pegue mais %d Maçã(s) na gôndola apertando [E]." % (2 - qtd_corretos)
		_reajustar_tamanho_painel()
