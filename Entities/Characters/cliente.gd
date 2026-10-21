extends CharacterBody2D
class_name Cliente

# ==========================================
# --- CONFIGURAÇÕES GERAIS ---
# ==========================================
@export_category("Configurações")
@export var velocidade: float = 100.0

# ==========================================
# --- ESTADO E POSIÇÕES (WAYPOINTS) ---
# Coordenadas que definem o caminho lógico (NavMesh simplificado) do cliente pelo cenário.
# ==========================================
var estado: String = "entrando_passo1"
var posicao_porta: Vector2 = Vector2(372, 88)
var posicao_caixa: Vector2 = Vector2(145, 224)
var posicao_meio_ida: Vector2 = Vector2(372, 224)
var posicao_recuo_caixa: Vector2 = Vector2(145, 248) 
var posicao_corredor_saida: Vector2 = Vector2(352, 248) 
var posicao_frente_porta: Vector2 = Vector2(372, 88) 

# ==========================================
# --- GERAÇÃO PROCEDURAL (VISUAIS DO CLIENTE) ---
# Arrays que guardam as diferentes texturas para montar um NPC único a cada spawn.
# ==========================================
@export_category("Visuais do Cliente")
@export var texturas_corpo: Array[Texture2D] = []
@export var texturas_cabelo: Array[Texture2D] = []
@export var texturas_roupa: Array[Texture2D] = []

# ==========================================
# --- REFERÊNCIAS DE NODES ---
# ==========================================
@export_category("Referências de Nodes")
@onready var som_chegou_caixa: AudioStreamPlayer = $SomChegouCaixa

# Partes do corpo (Layered Sprites)
@onready var sprite_corpo: Sprite2D = $SpriteCorpo
@onready var sprite_cabelo: Sprite2D = $SpriteCabelo
@onready var sprite_roupa: Sprite2D = $SpriteRoupa
@onready var animacao: AnimationPlayer = $Animation 

# Elementos de Interface do NPC
#@onready var balao_fala: Label = $BalaoFala 
@onready var emoji_feliz: Node2D = $EmojiFeliz
@onready var emoji_raiva: Node2D = $EmojiRaiva


# ==========================================
# --- INICIALIZAÇÃO DO NPC ---
# ==========================================
func _ready() -> void:
	# ==========================================
	# 1. GERAÇÃO DO VISUAL ÚNICO (Sorteio dos PNGs)
	# Monta o boneco pegando uma textura aleatória de cada lista configurada no Inspector.
	# ==========================================
	
	# Escolhe um tom de pele aleatório
	if sprite_corpo and texturas_corpo.size() > 0:
		sprite_corpo.texture = texturas_corpo.pick_random()
		
	# Escolhe um cabelo aleatório
	if sprite_cabelo and texturas_cabelo.size() > 0:
		sprite_cabelo.texture = texturas_cabelo.pick_random()
		
	# Escolhe uma roupa aleatória
	if sprite_roupa and texturas_roupa.size() > 0:
		sprite_roupa.texture = texturas_roupa.pick_random()

	# ==========================================
	# 2. INICIA O COMPORTAMENTO ORIGINAL
	# ==========================================
	global_position = posicao_porta 
	animacao.play("walk_down")
	
	# Garante que os feedbacks comecem invisíveis
	#if balao_fala:
		#balao_fala.visible = false


# ==========================================
# --- LOOP FÍSICO E NAVEGAÇÃO ---
# ==========================================
func _physics_process(delta: float) -> void:
	
	# ==========================================
	# --- SINCRONIZAÇÃO DE ANIMAÇÃO (LAYERED SPRITES) ---
	# Garante que a roupa e o cabelo acompanhem exatamente o mesmo frame do corpo.
	# Isso evita a necessidade de criar um AnimationPlayer para cada peça de roupa!
	# ==========================================
	if sprite_corpo:
		if sprite_cabelo:
			sprite_cabelo.frame = sprite_corpo.frame 
		if sprite_roupa:
			sprite_roupa.frame = sprite_corpo.frame 
	
	
	# ==========================================
	# --- ROTA DE IDA (Em direção ao caixa) ---
	# ==========================================
	if estado == "entrando_passo1":
		global_position = global_position.move_toward(posicao_meio_ida, velocidade * delta)
		
		# Checa se chegou no ponto intermediário. 
		# Usar '< 1.0' em vez de '==' previne bugs de precisão decimal (float precision) na Godot.
		if global_position.distance_to(posicao_meio_ida) < 1.0:
			global_position = posicao_meio_ida
			estado = "entrando_passo2"
			animacao.play("walk_left") 
			
	elif estado == "entrando_passo2":
		global_position = global_position.move_toward(posicao_caixa, velocidade * delta)
		
		# Momento exato em que o cliente encosta no destino final da sua posição no caixa
		if global_position == posicao_caixa:
			estado = "esperando"
			
			# Toca o som de campainha apenas se ele for o cliente principal (da ponta da fila)
			if posicao_caixa == Vector2(145, 224):
				if som_chegou_caixa:
					som_chegou_caixa.play()
					
			animacao.play("idle_down")
			
			
	# ==========================================
	# --- ROTA DE VOLTA (Saindo do mercado) ---
	# ==========================================
	elif estado == "saindo_passo1":
		global_position = global_position.move_toward(posicao_recuo_caixa, velocidade * delta)
		
		if global_position.distance_to(posicao_recuo_caixa) < 1.0:
			global_position = posicao_recuo_caixa
			estado = "saindo_passo2"
			animacao.play("walk_right") 
			
	elif estado == "saindo_passo2":
		global_position = global_position.move_toward(posicao_corredor_saida, velocidade * delta)
		
		if global_position.distance_to(posicao_corredor_saida) < 1.0:
			global_position = posicao_corredor_saida
			estado = "saindo_passo3"
			animacao.play("walk_up") 
			
	elif estado == "saindo_passo3":
		global_position = global_position.move_toward(posicao_frente_porta, velocidade * delta)
		
		if global_position.distance_to(posicao_frente_porta) < 1.0:
			global_position = posicao_frente_porta
			estado = "saindo_passo4"
			animacao.play("walk_right")
			
	elif estado == "saindo_passo4":
		global_position = global_position.move_toward(posicao_porta, velocidade * delta)
		
		# Ao encostar na porta de saída, o cliente concluiu seu ciclo e é removido da memória
		if global_position.distance_to(posicao_porta) < 1.0:
			queue_free() 


# ==========================================
# --- EVENTOS DE FEEDBACK ---
# Chamada pelo CaixaCheckout após a validação da compra.
# ==========================================
func reagir_e_ir_embora(sucesso: bool) -> void:
	
	# Exibe o balão de fala com o feedback da compra para o jogador (Sistema Opcional)
	#if balao_fala:
		#balao_fala.visible = true
		
	if sucesso:
		#balao_fala.text = "Muito obrigado!"
		if emoji_feliz: 
			emoji_feliz.visible = true 
	else:
		#balao_fala.text = "Que absurdo!"
		if emoji_raiva: 
			emoji_raiva.visible = true 
		
	# Inicia a sequência de animação de saída alterando a máquina de estados
	estado = "saindo_passo1"
	animacao.play("walk_down")
