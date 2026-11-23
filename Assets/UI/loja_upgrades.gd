extends CanvasLayer
class_name LojaUpgrades

signal upgrade_comprado(tipo: String)

const CUSTO_VELOCIDADE := 100.0
const CUSTO_ESTOQUE := 150.0
const CUSTO_REPOSITOR := 250.0
const ESCALA_MINIMA := 0.001

var nivel_velocidade: int = 0
var nivel_estoque: int = 0
var repositor_contratado: bool = false
var _ultimo_saldo_exibido: float = -1.0

var _loja_aberta: bool = false
var _loja_tween: Tween

@onready var label_saldo: Label = $PanelContainer/MarginContainer/VBoxContainer/LabelSaldo
@onready var btn_vel: Button = $PanelContainer/MarginContainer/VBoxContainer/BotaoVelocidade
@onready var btn_est: Button = $PanelContainer/MarginContainer/VBoxContainer/BotaoEstoque
@onready var btn_rep: Button = $PanelContainer/MarginContainer/VBoxContainer/BotaoRepositor
@onready var btn_fechar: Button = $PanelContainer/MarginContainer/VBoxContainer/BotaoFechar

@onready var som_abrir: AudioStreamPlayer = get_node_or_null("SomAbrir")
@onready var som_fechar: AudioStreamPlayer = get_node_or_null("SomFechar")
@onready var som_comprar: AudioStreamPlayer = get_node_or_null("SomComprar")

func _ready() -> void:
	add_to_group("loja_upgrades")
	visible = false
	_loja_aberta = false
	
	btn_vel.pressed.connect(_comprar_velocidade)
	btn_est.pressed.connect(_comprar_estoque)
	btn_rep.pressed.connect(_comprar_repositor)
	btn_fechar.pressed.connect(fechar_loja)

func _process(_delta: float) -> void:
	if _loja_aberta and not is_equal_approx(_ultimo_saldo_exibido, EconomyManager.dinheiro):
		_atualizar_ui()

func _input(event: InputEvent) -> void:
	if _loja_aberta and event.is_action_pressed("menu"):
		fechar_loja()
		get_viewport().set_input_as_handled()

func _aplicar_escala_centralizada(escala: float) -> void:
	# Mantém o crescimento/encolhimento exatamente a partir do centro da tela
	var s := maxf(escala, ESCALA_MINIMA)
	var centro := get_viewport().get_visible_rect().size / 2.0
	scale = Vector2(s, s)
	offset = centro * (1.0 - s)

func abrir_loja() -> void:
	if _loja_aberta:
		return
		
	_loja_aberta = true
	_atualizar_ui()
	
	if _loja_tween and _loja_tween.is_valid():
		_loja_tween.kill()
		
	var escala_inicial := scale.x if visible else ESCALA_MINIMA
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
	_loja_tween.tween_callback(func(): visible = false)

func _atualizar_ui() -> void:
	_ultimo_saldo_exibido = EconomyManager.dinheiro
	label_saldo.text = "Saldo atual: $ %.2f" % EconomyManager.dinheiro
	
	btn_vel.disabled = nivel_velocidade >= 3 or EconomyManager.dinheiro < CUSTO_VELOCIDADE
	btn_vel.text = "Tênis Veloz (%d/3) - $%.0f" % [nivel_velocidade, CUSTO_VELOCIDADE] if nivel_velocidade < 3 else "Tênis Veloz (MÁX)"
	
	btn_est.disabled = nivel_estoque >= 2 or EconomyManager.dinheiro < CUSTO_ESTOQUE
	btn_est.text = "Gôndolas Maiores (%d/2) - $%.0f" % [nivel_estoque, CUSTO_ESTOQUE] if nivel_estoque < 2 else "Gôndolas Maiores (MÁX)"
	
	btn_rep.disabled = repositor_contratado or EconomyManager.dinheiro < CUSTO_REPOSITOR
	btn_rep.text = "Repositor Automático (ATIVO)" if repositor_contratado else "Contratar Repositor - $%.0f" % CUSTO_REPOSITOR

func _comprar_velocidade() -> void:
	if EconomyManager.dinheiro < CUSTO_VELOCIDADE or nivel_velocidade >= 3:
		return
	EconomyManager.dinheiro -= CUSTO_VELOCIDADE
	nivel_velocidade += 1
	if som_comprar:
		som_comprar.play()
	get_tree().call_group("jogador", "aumentar_velocidade", 25.0)
	_atualizar_ui()

func _comprar_estoque() -> void:
	if EconomyManager.dinheiro < CUSTO_ESTOQUE or nivel_estoque >= 2:
		return
	EconomyManager.dinheiro -= CUSTO_ESTOQUE
	nivel_estoque += 1
	if som_comprar:
		som_comprar.play()
	get_tree().call_group("prateleiras", "aumentar_estoque_maximo", 3)
	_atualizar_ui()

func _comprar_repositor() -> void:
	if EconomyManager.dinheiro < CUSTO_REPOSITOR or repositor_contratado:
		return
	EconomyManager.dinheiro -= CUSTO_REPOSITOR
	repositor_contratado = true
	if som_comprar:
		som_comprar.play()
	upgrade_comprado.emit("repositor")
	_atualizar_ui()
