extends CharacterBody2D
class_name BaseCharacter

@export_category("Variables")
@export var _move_speed: float = 128.0
@export var _run_speed: float = 256.0
@export var _acceleration: float = 800.0 # Controla a suavidade da frenagem e arrancada

@export_category("Objects")
@export var _sprite2D: Sprite2D
@export var _animation: AnimationPlayer

@export_category("Audio")
@onready var som_passos: AudioStreamPlayer2D = $SomPassos

# --- Referências de Nodes ---
@onready var notepad: Control = $PlayerUI/Notepad
@onready var notificacao_label: Label = $PlayerUI/Notificacao
@onready var som_abrir_notepad: AudioStreamPlayer = $PlayerUI/Notepad/SomAbrirNotepad
@onready var som_fechar_notepad: AudioStreamPlayer = $PlayerUI/Notepad/SomFecharNotepad

# --- Estado do Jogador ---
var shopping_cart: Array[ProductData] = []
var _last_direction: String = "down"
var _is_running: bool = false
var _posicao_original_notificacao: Vector2
var _notificacao_tween: Tween 

var _prancheta_aberta: bool = false
var _posicao_original_notepad: Vector2

# --- Variáveis para controlar o ritmo dos passos ---
var _tempo_passo: float = 0.0
var _intervalo_andando: float = 0.40 # Segundos entre passos ao andar (ajuste a gosto)
var _intervalo_correndo: float = 0.30 # Segundos entre passos ao correr (mais rápido)

func _ready() -> void:
	# Inicializa o estado da interface
	notepad.visible = false
	notificacao_label.visible = false
	_posicao_original_notificacao = notificacao_label.position
	
	_posicao_original_notepad = notepad.position
	
	# Registra a UI no gerenciador global de clientes
	CustomerManager.ui_lista_de_itens = get_tree().get_first_node_in_group("lista_de_pedidos")

func _physics_process(delta: float) -> void:
	_move(delta)
	_animate()
	
	# A propriedade 'velocity' já existe no CharacterBody2D e nos diz se ele está se movendo
	if velocity != Vector2.ZERO: 
		_tempo_passo -= delta # O tempo diminui constantemente
		
		# Quando o tempo zera ou fica negativo, é hora de tocar o som!
		if _tempo_passo <= 0.0:
			som_passos.play() # O Randomizer da Godot vai escolher um dos 3 sons sozinho!
			
			# Reinicia o relógio baseando-se no estado de corrida
			if _is_running:
				_tempo_passo = _intervalo_correndo
			else:
				_tempo_passo = _intervalo_andando
	else:
		# Se o jogador parar, zeramos o cronômetro para que o som 
		# toque imediatamente no instante em que ele voltar a andar
		_tempo_passo = 0.0

func _move(delta: float) -> void:
	var _direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_is_running = Input.is_action_pressed("run")
	
	var _target_speed = _run_speed if _is_running else _move_speed
	var _target_velocity = _direction * _target_speed
	
	# Interpolação para aplicar aceleração/frenagem suave
	velocity = velocity.move_toward(_target_velocity, _acceleration * delta)
	move_and_slide()

func _animate() -> void:
	# Retorna ao estado ocioso se estiver parado
	if velocity == Vector2.ZERO: 
		_animation.play("idle_" + _last_direction)
		return
		
	var _action_prefix: String = "run_" if _is_running else "walk_"
		
	# Define a animação com base no eixo de maior movimento (X ou Y)
	if abs(velocity.x) > abs(velocity.y):
		if velocity.x > 0:
			_animation.play(_action_prefix + "right")
			_last_direction = "right"
		else:
			_animation.play(_action_prefix + "left")
			_last_direction = "left"
	else:
		if velocity.y > 0:
			_animation.play(_action_prefix + "down")
			_last_direction = "down"
		else:
			_animation.play(_action_prefix + "up")
			_last_direction = "up"

func add_to_cart(product: ProductData) -> void:
	shopping_cart.append(product)
	mostrar_notificacao("+ " + product.product_name, Color.GREEN)
	CustomerManager.atualizar_lista_visual(shopping_cart)

func remove_from_cart(product: ProductData) -> void:
	var index = shopping_cart.find(product)
	if index != -1:
		shopping_cart.remove_at(index)
		mostrar_notificacao("- " + product.product_name + " (Devolvido)", Color.ORANGE)
		CustomerManager.atualizar_lista_visual(shopping_cart)
		
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_notepad"):
		alternar_prancheta()

func alternar_prancheta() -> void:
	_prancheta_aberta = not _prancheta_aberta
	
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if _prancheta_aberta:
		notepad.visible = true
		
		# Joga a prancheta 600 pixels para BAIXO (para fora da tela, escondida na parte inferior)
		notepad.position.y = _posicao_original_notepad.y + 600
		
		if som_abrir_notepad:
			som_abrir_notepad.play()
			
		# Anima a prancheta DESLIZANDO PARA CIMA até a posição original (onde ela fica visível) em 0.4s
		tween.tween_property(notepad, "position", _posicao_original_notepad, 0.4)
	else:
		if som_fechar_notepad:
			som_fechar_notepad.play()
			
		# Anima a prancheta deslizando DE VOLTA PARA BAIXO (saindo da tela por baixo)
		tween.tween_property(notepad, "position:y", _posicao_original_notepad.y + 600, 0.3)
		
		# Oculta a prancheta só depois que a animação terminar
		tween.tween_callback(func(): notepad.visible = false)
		
func mostrar_notificacao(mensagem: String, cor: Color) -> void:
	notificacao_label.text = mensagem
	notificacao_label.add_theme_color_override("font_color", cor)
	
	notificacao_label.modulate.a = 1.0 
	notificacao_label.visible = true
	
	# Interrompe animações anteriores para evitar conflitos visuais
	if _notificacao_tween and _notificacao_tween.is_valid():
		_notificacao_tween.kill()
		
	_notificacao_tween = create_tween()
	_notificacao_tween.tween_interval(1.0) # Duração da mensagem na tela
	_notificacao_tween.tween_property(notificacao_label, "modulate:a", 0.0, 0.2) # Fade out
