extends CharacterBody2D
class_name BaseCharacter

# ==========================================
# --- CONFIGURAÇÕES DE MOVIMENTAÇÃO ---
# ==========================================
@export_category("Variables")
@export var _move_speed: float = 128.0
@export var _run_speed: float = 256.0
@export var _acceleration: float = 800.0 # Controla a suavidade da frenagem e arrancada

# ==========================================
# --- REFERÊNCIAS VISUAIS E DE ANIMAÇÃO ---
# ==========================================
@export_category("Objects")
@export var _sprite2D: Sprite2D
@export var _animation: AnimationPlayer

# ==========================================
# --- ÁUDIO ---
# ==========================================
@export_category("Audio")
@onready var som_passos: AudioStreamPlayer2D = $SomPassos

# ==========================================
# --- REFERÊNCIAS DE INTERFACE (UI) ---
# ==========================================
@onready var notepad: Control = $PlayerUI/Notepad
@onready var notificacao_label: Label = $PlayerUI/Notificacao
@onready var som_abrir_notepad: AudioStreamPlayer = $PlayerUI/Notepad/SomAbrirNotepad
@onready var som_fechar_notepad: AudioStreamPlayer = $PlayerUI/Notepad/SomFecharNotepad

# ==========================================
# --- ESTADO DO JOGADOR E INVENTÁRIO ---
# Variáveis que controlam o carrinho de compras e a orientação do sprite.
# ==========================================
var shopping_cart: Array[ProductData] = []
var _last_direction: String = "down"
var _is_running: bool = false

# ==========================================
# --- CONTROLE DE ANIMAÇÕES DE UI (TWEENS) ---
# ==========================================
var _posicao_original_notificacao: Vector2
var _notificacao_tween: Tween 

var _prancheta_tween: Tween
var _prancheta_aberta: bool = false
var _posicao_original_notepad: Vector2

# ==========================================
# --- CONTROLE DE RITMO DOS PASSOS (ÁUDIO) ---
# ==========================================
var _tempo_passo: float = 0.0
var _intervalo_andando: float = 0.40 # Segundos entre passos ao andar (ajuste a gosto)
var _intervalo_correndo: float = 0.30 # Segundos entre passos ao correr (mais rápido)


# ==========================================
# --- INICIALIZAÇÃO ---
# ==========================================
func _ready() -> void:
	# Inicializa o estado da interface garantindo que os painéis comecem ocultos
	notepad.visible = false
	notificacao_label.visible = false
	
	# Salva as posições originais da UI para as animações de Tween funcionarem corretamente
	_posicao_original_notificacao = notificacao_label.position
	_posicao_original_notepad = notepad.position
	
	# Registra a UI no gerenciador global de clientes
	CustomerManager.ui_lista_de_itens = get_tree().get_first_node_in_group("lista_de_pedidos")


# ==========================================
# --- LOOP FÍSICO PRINCIPAL ---
# ==========================================
func _physics_process(delta: float) -> void:
	_move(delta)
	_animate()
	
	# ==========================================
	# --- SISTEMA DE SOM DE PASSOS ---
	# A propriedade 'velocity' já existe no CharacterBody2D e indica se o jogador está em movimento
	# ==========================================
	if velocity != Vector2.ZERO: 
		_tempo_passo -= delta # O tempo diminui constantemente
		
		# Quando o tempo zera ou fica negativo, é hora de tocar o som!
		if _tempo_passo <= 0.0:
			som_passos.play() # O Randomizer da Godot vai escolher um dos 3 sons sozinho!
			
			# Reinicia o relógio baseando-se no estado atual (caminhando ou correndo)
			if _is_running:
				_tempo_passo = _intervalo_correndo
			else:
				_tempo_passo = _intervalo_andando
	else:
		# Se o jogador parar, zeramos o cronômetro para que o som 
		# toque imediatamente no instante em que ele voltar a andar
		_tempo_passo = 0.0


# ==========================================
# --- LÓGICA DE MOVIMENTAÇÃO ---
# ==========================================
func _move(delta: float) -> void:
	# Captura o input direcional baseado no mapeamento de teclas configurado
	var _direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_is_running = Input.is_action_pressed("run")
	
	var _target_speed = _run_speed if _is_running else _move_speed
	var _target_velocity = _direction * _target_speed
	
	# Interpolação (move_toward) para aplicar uma aceleração e frenagem suaves e evitar movimentos robóticos
	velocity = velocity.move_toward(_target_velocity, _acceleration * delta)
	move_and_slide()


# ==========================================
# --- LÓGICA DE ANIMAÇÃO VISUAL ---
# ==========================================
func _animate() -> void:
	# Retorna ao estado ocioso mantendo a direção que o jogador estava olhando por último
	if velocity == Vector2.ZERO: 
		_animation.play("idle_" + _last_direction)
		return
		
	var _action_prefix: String = "run_" if _is_running else "walk_"
		
	# Define a animação direcional com base no eixo de maior movimento (X ou Y)
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


# ==========================================
# --- INTERAÇÃO COM O CARRINHO DE COMPRAS ---
# ==========================================
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
		

# ==========================================
# --- INTERFACE: CONTROLES DE INPUT E PRANCHETA ---
# ==========================================
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_notepad"):
		alternar_prancheta()

func alternar_prancheta() -> void:
	_prancheta_aberta = not _prancheta_aberta
	
	# 1. Se existir uma animação tocando, nós a cancelamos para não dar conflito
	if _prancheta_tween and _prancheta_tween.is_valid():
		_prancheta_tween.kill()
		
	# 2. Criamos a nova animação de interpolação salvando na nossa variável global
	_prancheta_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	if _prancheta_aberta:
		# Só jogamos a prancheta para baixo com "+ 600" se ela estiver totalmente fechada/invisível.
		# Se ela já estiver visível (você clicou no meio do caminho), ela não dá "teleporte", apenas inverte suavemente!
		if not notepad.visible:
			notepad.position.y = _posicao_original_notepad.y + 600
			
		notepad.visible = true
		
		if som_abrir_notepad:
			som_abrir_notepad.play()
			
		_prancheta_tween.tween_property(notepad, "position", _posicao_original_notepad, 0.4)
	else:
		if som_fechar_notepad:
			som_fechar_notepad.play()
			
		_prancheta_tween.tween_property(notepad, "position:y", _posicao_original_notepad.y + 600, 0.3)
		
		# Oculta a prancheta só depois que a animação terminar (E se for cancelada no meio, isso aqui também é cancelado!)
		_prancheta_tween.tween_callback(func(): notepad.visible = false)
		

# ==========================================
# --- INTERFACE: NOTIFICAÇÕES FLUTUANTES ---
# ==========================================
func mostrar_notificacao(mensagem: String, cor: Color) -> void:
	notificacao_label.text = mensagem
	notificacao_label.add_theme_color_override("font_color", cor)
	
	notificacao_label.modulate.a = 1.0 
	notificacao_label.visible = true
	
	# Interrompe animações anteriores para evitar conflitos visuais no caso de múltiplos itens coletados rapidamente
	if _notificacao_tween and _notificacao_tween.is_valid():
		_notificacao_tween.kill()
		
	_notificacao_tween = create_tween()
	_notificacao_tween.tween_interval(1.0) # Duração da mensagem na tela
	_notificacao_tween.tween_property(notificacao_label, "modulate:a", 0.0, 0.2) # Fade out suave


func abrir_prancheta() -> void:
	# Verifica se a prancheta está fechada.
	# Se já estiver aberta (_prancheta_aberta == true), o código não faz nada e ela continua aberta!
	if not _prancheta_aberta:
		alternar_prancheta()
