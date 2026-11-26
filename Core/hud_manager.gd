extends MarginContainer

# ==========================================
# --- REFERÊNCIAS DE NODES (INTERFACE VISUAL) ---
# ==========================================
@onready var label_tempo: Label = $Container/Tempo/LabelTempo
@onready var label_dinheiro: Label = $Container/Dinheiro/LabelDinheiro
@onready var barra_expansao: TextureProgressBar = $Container/Expansao/BarraExpansao
@onready var estrelas_container: HBoxContainer = $Container/Reputacao/EstrelasContainer
@onready var label_expansao: Label = $Container/Expansao/LabelExpansao

@export var offset_desconto_hud: Vector2 = Vector2(0.0, 18.0)
@export var offset_reputacao_hud: Vector2 = Vector2(0.0, 18.0)

var _tween_pulso_dinheiro: Tween
var _tween_pulso_reputacao: Tween
var _ultimo_frame_rep: int = -1


# ==========================================
# --- INICIALIZAÇÃO ---
# ==========================================
func _ready() -> void:
	add_to_group("hud")
	EconomyManager.reputacao_alterada.connect(_on_reputacao_alterada)
	EconomyManager.game_over_acionado.connect(_on_game_over)


# ==========================================
# --- LOOP DE ATUALIZAÇÃO DA INTERFACE (UI) ---
# ==========================================
func _process(_delta: float) -> void:
	# 1. Atualização financeira
	label_dinheiro.text = "$ %.2f" % EconomyManager.dinheiro

	# 2. Atualização de reputação (1 a 5 estrelas)
	var rep: int = EconomyManager.reputacao
	var qtd_estrelas: int = 1

	if rep >= 50:
		qtd_estrelas = 5
	elif rep >= 30:
		qtd_estrelas = 4
	elif rep >= 15:
		qtd_estrelas = 3
	elif rep > 0:
		qtd_estrelas = 2
	else:
		qtd_estrelas = 1

	if estrelas_container:
		for i in range(estrelas_container.get_child_count()):
			if i < qtd_estrelas:
				estrelas_container.get_child(i).show()
			else:
				estrelas_container.get_child(i).hide()

	# 3. Atualização da barra de expansão
	if EconomyManager.nivel_expansao < EconomyManager.expansoes_maximas:
		label_expansao.text = "Próxima Expansão: "
		barra_expansao.max_value = EconomyManager.meta_expansao
		barra_expansao.value = EconomyManager.clientes_atendidos
	elif not EconomyManager.modo_infinito:
		label_expansao.text = "Chegada do VIP: "
		barra_expansao.max_value = EconomyManager.meta_vitoria
		barra_expansao.value = EconomyManager.clientes_atendidos
	else:
		label_expansao.text = "Modo Infinito: "
		barra_expansao.max_value = 1
		barra_expansao.value = 1

	# 4. Atualização do relógio do pedido
	if not CustomerManager.tem_pedido_ativo():
		label_tempo.text = "Aguardando..."
		label_tempo.add_theme_color_override("font_color", Color.WHITE)
	else:
		var tempo: float = CustomerManager.pegar_tempo_restante()

		if tempo > 0.0:
			label_tempo.text = "%.1fs" % tempo

			if tempo > 10.0:
				label_tempo.add_theme_color_override("font_color", Color.WHITE)
			elif tempo < 5.0:
				label_tempo.add_theme_color_override("font_color", Color.ORANGE_RED)
			else:
				label_tempo.add_theme_color_override("font_color", Color.YELLOW)
		else:
			label_tempo.text = "ESGOTADO!"
			label_tempo.add_theme_color_override("font_color", Color.RED)


# ==========================================
# --- EVENTOS DE SINAIS ---
# ==========================================
func _on_reputacao_alterada(_nova_rep: int, delta: int) -> void:
	animar_variacao_reputacao(delta)


func _on_game_over() -> void:
	var tela: Node = preload("res://UI/tela_game_over.tscn").instantiate()
	get_tree().current_scene.add_child(tela)


# ==========================================
# --- FEEDBACK VISUAL DE DINHEIRO ---
# ==========================================
func animar_gasto_dinheiro(custo: float) -> void:
	if custo <= 0.0:
		return
	_animar_variacao_dinheiro(custo, false)


func animar_ganho_dinheiro(valor: float) -> void:
	if valor <= 0.0:
		return
	_animar_variacao_dinheiro(valor, true)


func _animar_variacao_dinheiro(valor: float, eh_ganho: bool) -> void:
	if not label_dinheiro:
		return

	var cor_pulso: Color = Color(0.55, 1.0, 0.65, 1.0) if eh_ganho else Color(1.0, 0.55, 0.55, 1.0)
	var cor_texto: Color = Color(0.35, 1.0, 0.45, 1.0) if eh_ganho else Color(1.0, 0.35, 0.35, 1.0)

	# 1. Pulso rápido no saldo da HUD
	label_dinheiro.pivot_offset = label_dinheiro.size / 2.0
	if _tween_pulso_dinheiro and _tween_pulso_dinheiro.is_valid():
		_tween_pulso_dinheiro.kill()

	label_dinheiro.scale = Vector2.ONE
	label_dinheiro.modulate = Color.WHITE

	_tween_pulso_dinheiro = create_tween()
	_tween_pulso_dinheiro.tween_property(label_dinheiro, "scale", Vector2(1.15, 1.15), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween_pulso_dinheiro.parallel().tween_property(label_dinheiro, "modulate", cor_pulso, 0.08)
	_tween_pulso_dinheiro.tween_property(label_dinheiro, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_pulso_dinheiro.parallel().tween_property(label_dinheiro, "modulate", Color.WHITE, 0.18)

	# 2. Texto flutuante (+$XX subindo no ganho / -$XX descendo no gasto)
	label_dinheiro.clip_contents = false

	var valor_formatado: String = "%.0f" % valor if is_equal_approx(valor, roundf(valor)) else "%.2f" % valor
	var sinal: String = "+" if eh_ganho else "-"

	var flutuante: Label = Label.new()
	flutuante.text = "%s$%s" % [sinal, valor_formatado]
	flutuante.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flutuante.z_index = 50

	var fonte: Font = label_dinheiro.get_theme_font("font")
	if fonte:
		flutuante.add_theme_font_override("font", fonte)

	var tamanho_fonte: int = label_dinheiro.get_theme_font_size("font_size")
	flutuante.add_theme_font_size_override("font_size", maxi(tamanho_fonte, 12))

	flutuante.add_theme_color_override("font_color", cor_texto)
	flutuante.add_theme_color_override("font_outline_color", Color.BLACK)
	flutuante.add_theme_constant_override("outline_size", 4)

	label_dinheiro.add_child(flutuante)

	var base_pos: Vector2 = Vector2(label_dinheiro.size.x * 0.25, 0.0) + offset_desconto_hud + Vector2(randf_range(-6.0, 6.0), 0.0)
	var y_inicial: float = base_pos.y + 26.0 if eh_ganho else base_pos.y
	var y_final: float = base_pos.y if eh_ganho else base_pos.y + 28.0

	flutuante.position = Vector2(base_pos.x, y_inicial)
	flutuante.modulate.a = 1.0

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flutuante, "position:y", y_final, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(flutuante, "modulate:a", 0.0, 0.45).set_delay(0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(flutuante.queue_free)


# ==========================================
# --- FEEDBACK VISUAL DE REPUTAÇÃO ---
# ==========================================
func animar_variacao_reputacao(delta_rep: int) -> void:
	if delta_rep == 0 or not estrelas_container:
		return

	# Evita duplicidade caso o sinal e o call_group disparem no mesmo frame
	var frame_atual: int = Engine.get_process_frames()
	if frame_atual == _ultimo_frame_rep:
		return
	_ultimo_frame_rep = frame_atual

	var subiu: bool = delta_rep > 0
	var cor_pulso: Color = Color(1.0, 0.90, 0.40, 1.0) if subiu else Color(1.0, 0.45, 0.45, 1.0)
	var cor_texto: Color = Color(1.0, 0.85, 0.25, 1.0) if subiu else Color(1.0, 0.35, 0.35, 1.0)

	# 1. Pulso rápido nas estrelas de reputação
	estrelas_container.pivot_offset = estrelas_container.size / 2.0
	if _tween_pulso_reputacao and _tween_pulso_reputacao.is_valid():
		_tween_pulso_reputacao.kill()

	estrelas_container.scale = Vector2.ONE
	estrelas_container.modulate = Color.WHITE

	_tween_pulso_reputacao = create_tween()
	_tween_pulso_reputacao.tween_property(estrelas_container, "scale", Vector2(1.15, 1.15), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween_pulso_reputacao.parallel().tween_property(estrelas_container, "modulate", cor_pulso, 0.08)
	_tween_pulso_reputacao.tween_property(estrelas_container, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_pulso_reputacao.parallel().tween_property(estrelas_container, "modulate", Color.WHITE, 0.18)

	# 2. Texto flutuante (+5 Rep subindo em dourado / -10 Rep descendo em vermelho)
	var flutuante: Label = Label.new()
	flutuante.text = "+%d Rep" % delta_rep if subiu else "%d Rep" % delta_rep
	flutuante.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flutuante.top_level = true
	flutuante.z_index = 50

	if label_dinheiro:
		var fonte: Font = label_dinheiro.get_theme_font("font")
		if fonte:
			flutuante.add_theme_font_override("font", fonte)
		var tamanho_fonte: int = label_dinheiro.get_theme_font_size("font_size")
		flutuante.add_theme_font_size_override("font_size", maxi(tamanho_fonte, 12))

	flutuante.add_theme_color_override("font_color", cor_texto)
	flutuante.add_theme_color_override("font_outline_color", Color.BLACK)
	flutuante.add_theme_constant_override("outline_size", 4)

	# Adicionado em self com top_level = true para não interferir no HBoxContainer nem no loop de estrelas
	add_child(flutuante)

	var base_pos: Vector2 = estrelas_container.global_position + Vector2(estrelas_container.size.x * 0.25, 0.0) + offset_reputacao_hud + Vector2(randf_range(-6.0, 6.0), 0.0)
	var y_inicial: float = base_pos.y + 24.0 if subiu else base_pos.y
	var y_final: float = base_pos.y if subiu else base_pos.y + 28.0

	flutuante.position = Vector2(base_pos.x, y_inicial)
	flutuante.modulate.a = 1.0

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flutuante, "position:y", y_final, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(flutuante, "modulate:a", 0.0, 0.45).set_delay(0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(flutuante.queue_free)
