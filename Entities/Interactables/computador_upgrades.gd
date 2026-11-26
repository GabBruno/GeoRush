extends Area2D

@onready var popup_label: Label = $Label
@onready var loja: LojaUpgrades = $LojaUpgrades
@onready var timer_repositor: Timer = $TimerRepositor

var _jogador_na_area: BaseCharacter = null
var _popup_tween: Tween

func _ready() -> void:
	popup_label.visible = false
	# Centraliza o pivô automaticamente para a animação crescer a partir do meio do texto
	popup_label.pivot_offset = popup_label.size / 2.0

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	loja.upgrade_comprado.connect(_on_upgrade_comprado)
	timer_repositor.timeout.connect(_on_timer_repositor_timeout)

func _input(event: InputEvent) -> void:
	if _jogador_na_area and not _jogador_na_area.em_cutscene and not loja._loja_aberta and event.is_action_pressed("interact_e"):
		loja.abrir_loja()

func _on_body_entered(body: Node2D) -> void:
	if body is BaseCharacter:
		_jogador_na_area = body

		# Cancela animação anterior caso o jogador entre e saia rapidamente da área
		if _popup_tween and _popup_tween.is_valid():
			_popup_tween.kill()

		popup_label.visible = true
		popup_label.scale = Vector2.ZERO
		_popup_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_popup_tween.tween_property(popup_label, "scale", Vector2(1, 1), 0.3)

func _on_body_exited(body: Node2D) -> void:
	if body is BaseCharacter:
		_jogador_na_area = null

		if loja.visible:
			loja.fechar_loja()

		if _popup_tween and _popup_tween.is_valid():
			_popup_tween.kill()

		_popup_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_popup_tween.tween_property(popup_label, "scale", Vector2.ZERO, 0.2)
		_popup_tween.tween_callback(func(): popup_label.visible = false)

func _on_upgrade_comprado(tipo: String) -> void:
	if tipo == "repositor":
		timer_repositor.start()

func _on_timer_repositor_timeout() -> void:
	for prateleira in get_tree().get_nodes_in_group("prateleiras"):
		if prateleira.has_method("repor_automaticamente") and prateleira.repor_automaticamente():
			get_tree().call_group("jogador", "mostrar_notificacao", "Repositor reabasteceu uma prateleira!", Color.CYAN)
			break
