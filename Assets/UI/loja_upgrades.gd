extends CanvasLayer
class_name LojaUpgrades

signal upgrade_comprado(tipo: String)
@export var offset_desconto: Vector2 = Vector2(0.0, -8.0)

# Tabela de preços progressivos por nível (o tamanho do array define o nível máximo)
const CUSTOS_VELOCIDADE: Array[float] = [90.0, 160.0, 240.0]
const CUSTOS_ESTOQUE: Array[float] = [150.0, 250.0]
const CUSTO_REPOSITOR: float = 250.0
const ESCALA_MINIMA: float = 0.001

# Cores aplicadas sobre a textura em pixel art do Theme
const COR_DISPONIVEL: Color = Color(0.45, 0.92, 0.50, 1.0)
const COR_DISPONIVEL_HOVER: Color = Color(0.60, 1.0, 0.65, 1.0)
const COR_DISPONIVEL_PRESSED: Color = Color(0.32, 0.72, 0.36, 1.0)
const COR_BLOQUEADO: Color = Color(0.65, 0.42, 0.42, 0.85)
const COR_COMPRADO: Color = Color(1.0, 0.85, 0.35, 1.0)

const COR_TEXTO_DISPONIVEL: Color = Color(1.0, 1.0, 1.0, 1.0)
const COR_TEXTO_BLOQUEADO: Color = Color(0.85, 0.78, 0.78, 0.75)
const COR_TEXTO_COMPRADO: Color = Color(1.0, 0.98, 0.85, 1.0)
const COR_DESCONTO_FLUTUANTE: Color = Color(1.0, 0.35, 0.35, 1.0)

var nivel_velocidade: int = 0
var nivel_estoque: int = 0
var repositor_contratado: bool = false
var _ultimo_saldo_exibido: float = -1.0

var _loja_aberta: bool = false
var _loja_tween: Tween
var _tweens_pulso: Dictionary = {}

var _estilo_disp_normal: StyleBox
var _estilo_disp_hover: StyleBox
var _estilo_disp_pressed: StyleBox
var _estilo_bloqueado: StyleBox
var _estilo_comprado: StyleBox

# Referências via Unique Names (%) — independentes da hierarquia de containers
@onready var label_vel: Label = %LabelVelocidade
@onready var btn_vel: Button = %BotaoVelocidade

@onready var label_est: Label = %LabelEstoque
@onready var btn_est: Button = %BotaoEstoque

@onready var label_rep: Label = %LabelRepositor
@onready var btn_rep: Button = %BotaoRepositor

@onready var btn_fechar: Button = %BotaoFechar

# Áudios (filhos diretos da raiz LojaUpgrades)
@onready var som_abrir: AudioStreamPlayer = get_node_or_null("SomAbrir") as AudioStreamPlayer
@onready var som_fechar: AudioStreamPlayer = get_node_or_null("SomFechar") as AudioStreamPlayer
@onready var som_comprar: AudioStreamPlayer = get_node_or_null("SomComprar") as AudioStreamPlayer


func _ready() -> void:
	add_to_group("loja_upgrades")
	visible = false
	_loja_aberta = false

	btn_vel.pressed.connect(_comprar_velocidade)
	btn_est.pressed.connect(_comprar_estoque)
	btn_rep.pressed.connect(_comprar_repositor)
	btn_fechar.pressed.connect(fechar_loja)

	_preparar_estilos_botoes()


func _process(_delta: float) -> void:
	if _loja_aberta and not is_equal_approx(_ultimo_saldo_exibido, EconomyManager.dinheiro):
		_atualizar_ui()


func _input(event: InputEvent) -> void:
	if _loja_aberta and event.is_action_pressed("menu"):
		fechar_loja()
		get_viewport().set_input_as_handled()


# ==========================================
# --- CÁLCULO DE CUSTO PROGRESSIVO ---
# ==========================================
func _obter_custo_atual(tabela: Array[float], nivel: int) -> float:
	if nivel >= tabela.size():
		return 0.0
	return tabela[nivel]


# ==========================================
# --- FEEDBACK VISUAL (PULSO E DESCONTO) ---
# ==========================================
func _pulsar_elemento(alvo: Control, escala_pico: float = 1.14, cor_flash: Color = Color(1.35, 1.35, 1.35, 1.0)) -> void:
	if not alvo:
		return

	alvo.pivot_offset = alvo.size / 2.0

	var tween_anterior: Tween = _tweens_pulso.get(alvo) as Tween
	if tween_anterior and tween_anterior.is_valid():
		tween_anterior.kill()

	alvo.scale = Vector2.ONE
	alvo.modulate = Color.WHITE

	var tween: Tween = create_tween()
	_tweens_pulso[alvo] = tween

	tween.tween_property(alvo, "scale", Vector2(escala_pico, escala_pico), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(alvo, "modulate", cor_flash, 0.08)

	tween.tween_property(alvo, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(alvo, "modulate", Color.WHITE, 0.18)


# ==========================================
# --- ESTILIZAÇÃO DINÂMICA DOS BOTÕES ---
# ==========================================
func _criar_estilo_tingido(origem: StyleBox, cor: Color) -> StyleBox:
	var copia: StyleBox = origem.duplicate() as StyleBox
	if copia is StyleBoxTexture:
		(copia as StyleBoxTexture).modulate_color = cor
	elif copia is StyleBoxFlat:
		(copia as StyleBoxFlat).bg_color = cor
	return copia


func _preparar_estilos_botoes() -> void:
	var base_normal: StyleBox = btn_vel.get_theme_stylebox("normal")
	var base_hover: StyleBox = btn_vel.get_theme_stylebox("hover")
	var base_pressed: StyleBox = btn_vel.get_theme_stylebox("pressed")
	var base_disabled: StyleBox = btn_vel.get_theme_stylebox("disabled")

	var base_para_bloqueado: StyleBox = base_disabled if base_disabled is StyleBoxTexture else base_normal

	_estilo_disp_normal = _criar_estilo_tingido(base_normal, COR_DISPONIVEL)
	_estilo_disp_hover = _criar_estilo_tingido(base_hover, COR_DISPONIVEL_HOVER)
	_estilo_disp_pressed = _criar_estilo_tingido(base_pressed, COR_DISPONIVEL_PRESSED)
	_estilo_bloqueado = _criar_estilo_tingido(base_para_bloqueado, COR_BLOQUEADO)
	_estilo_comprado = _criar_estilo_tingido(base_normal, COR_COMPRADO)


func _aplicar_estado_botao(btn: Button, comprado: bool, pode_comprar: bool, custo: float, texto_comprado: String) -> void:
	if comprado:
		btn.text = texto_comprado
		btn.disabled = true
		btn.add_theme_stylebox_override("disabled", _estilo_comprado)
		btn.add_theme_color_override("font_disabled_color", COR_TEXTO_COMPRADO)
	elif pode_comprar:
		btn.text = "Comprar\n$%.0f" % custo
		btn.disabled = false
		btn.add_theme_stylebox_override("normal", _estilo_disp_normal)
		btn.add_theme_stylebox_override("hover", _estilo_disp_hover)
		btn.add_theme_stylebox_override("pressed", _estilo_disp_pressed)
		btn.add_theme_color_override("font_color", COR_TEXTO_DISPONIVEL)
	else:
		btn.text = "Comprar\n$%.0f" % custo
		btn.disabled = true
		btn.add_theme_stylebox_override("disabled", _estilo_bloqueado)
		btn.add_theme_color_override("font_disabled_color", COR_TEXTO_BLOQUEADO)


# ==========================================
# --- ABERTURA, FECHAMENTO E ATUALIZAÇÃO ---
# ==========================================
func _aplicar_escala_centralizada(escala: float) -> void:
	var s: float = maxf(escala, ESCALA_MINIMA)
	var centro: Vector2 = get_viewport().get_visible_rect().size / 2.0
	scale = Vector2(s, s)
	offset = centro * (1.0 - s)


func abrir_loja() -> void:
	if _loja_aberta:
		return

	_loja_aberta = true
	_atualizar_ui()

	if _loja_tween and _loja_tween.is_valid():
		_loja_tween.kill()

	var escala_inicial: float = scale.x if visible else ESCALA_MINIMA
	if not visible:
		_aplicar_escala_centralizada(ESCALA_MINIMA)
		visible = true

	if som_abrir:
		som_abrir.play()

	_loja_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_loja_tween.tween_method(_aplicar_escala_centralizada, escala_inicial, 1.0, 0.3)


func fechar_loja() -> void:
	if not _loja_aberta:
		return

	_loja_aberta = false

	if _loja_tween and _loja_tween.is_valid():
		_loja_tween.kill()

	if som_fechar:
		som_fechar.play()

	_loja_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_loja_tween.tween_method(_aplicar_escala_centralizada, scale.x, ESCALA_MINIMA, 0.2)
	_loja_tween.tween_callback(func() -> void: visible = false)


func _atualizar_ui() -> void:
	_ultimo_saldo_exibido = EconomyManager.dinheiro
	# Tênis Veloz
	var vel_max: bool = nivel_velocidade >= CUSTOS_VELOCIDADE.size()
	var custo_vel: float = _obter_custo_atual(CUSTOS_VELOCIDADE, nivel_velocidade)
	label_vel.text = "Tênis Veloz [MÁX]" if vel_max else "Tênis Veloz [%d/%d]" % [nivel_velocidade, CUSTOS_VELOCIDADE.size()]
	_aplicar_estado_botao(btn_vel, vel_max, EconomyManager.dinheiro >= custo_vel, custo_vel, "MÁX")

	# Gôndolas Maiores
	var est_max: bool = nivel_estoque >= CUSTOS_ESTOQUE.size()
	var custo_est: float = _obter_custo_atual(CUSTOS_ESTOQUE, nivel_estoque)
	label_est.text = "Gôndolas Maiores [MÁX]" if est_max else "Gôndolas Maiores [%d/%d]" % [nivel_estoque, CUSTOS_ESTOQUE.size()]
	_aplicar_estado_botao(btn_est, est_max, EconomyManager.dinheiro >= custo_est, custo_est, "MÁX")

	# Repositor Automático
	label_rep.text = "Repositor Automático"
	_aplicar_estado_botao(btn_rep, repositor_contratado, EconomyManager.dinheiro >= CUSTO_REPOSITOR, CUSTO_REPOSITOR, "ATIVO")


# ==========================================
# --- AÇÕES DE COMPRA ---
# ==========================================
func _feedback_compra(btn: Button, custo: float) -> void:
	_atualizar_ui()
	_pulsar_elemento(btn, 1.14, Color(1.35, 1.35, 1.35, 1.0))
	get_tree().call_group("hud", "animar_gasto_dinheiro", custo)


func _comprar_velocidade() -> void:
	if nivel_velocidade >= CUSTOS_VELOCIDADE.size():
		return
	var custo: float = _obter_custo_atual(CUSTOS_VELOCIDADE, nivel_velocidade)
	if EconomyManager.dinheiro < custo:
		return
	EconomyManager.dinheiro -= custo
	nivel_velocidade += 1
	if som_comprar:
		som_comprar.play()
	get_tree().call_group("jogador", "aumentar_velocidade", 25.0)
	_feedback_compra(btn_vel, custo)


func _comprar_estoque() -> void:
	if nivel_estoque >= CUSTOS_ESTOQUE.size():
		return
	var custo: float = _obter_custo_atual(CUSTOS_ESTOQUE, nivel_estoque)
	if EconomyManager.dinheiro < custo:
		return
	EconomyManager.dinheiro -= custo
	nivel_estoque += 1
	if som_comprar:
		som_comprar.play()
	get_tree().call_group("prateleiras", "aumentar_estoque_maximo", 3)
	_feedback_compra(btn_est, custo)


func _comprar_repositor() -> void:
	if EconomyManager.dinheiro < CUSTO_REPOSITOR or repositor_contratado:
		return
	EconomyManager.dinheiro -= CUSTO_REPOSITOR
	repositor_contratado = true
	if som_comprar:
		som_comprar.play()
	upgrade_comprado.emit("repositor")
	_feedback_compra(btn_rep, CUSTO_REPOSITOR)
