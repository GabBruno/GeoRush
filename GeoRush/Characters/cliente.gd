extends CharacterBody2D
class_name Cliente

@export_category("Configurações")
@export var velocidade: float = 100.0

# --- Estado e Posições (Waypoints) ---
var estado: String = "entrando_passo1"
var posicao_porta: Vector2 = Vector2(372, 88)
var posicao_caixa: Vector2 = Vector2(145, 224)
var posicao_meio_ida: Vector2 = Vector2(372, 224)
var posicao_recuo_caixa: Vector2 = Vector2(145, 248) 
var posicao_corredor_saida: Vector2 = Vector2(352, 248) 
var posicao_frente_porta: Vector2 = Vector2(372, 88) 

@export_category("Referências de Nodes")
@onready var som_chegou_caixa: AudioStreamPlayer = $SomChegouCaixa
@onready var animacao: AnimationPlayer = $Animation 
@onready var balao_fala: Label = $BalaoFala 
@onready var emoji_feliz: Node2D = $EmojiFeliz
@onready var emoji_raiva: Node2D = $EmojiRaiva

func _ready() -> void:
	# Define a posição inicial na porta e inicia a caminhada
	global_position = posicao_porta 
	animacao.play("walk_down") 
	
	if balao_fala:
		balao_fala.visible = false

func _physics_process(delta: float) -> void:
	# ==========================================
	# --- ROTA DE IDA (Em direção ao caixa) ---
	# ==========================================
	if estado == "entrando_passo1":
		global_position = global_position.move_toward(posicao_meio_ida, velocidade * delta)
		
		# Checa se chegou no ponto intermediário (ignorando frações de pixel)
		if global_position.distance_to(posicao_meio_ida) < 1.0:
			global_position = posicao_meio_ida
			estado = "entrando_passo2"
			animacao.play("walk_left") 
			
	elif estado == "entrando_passo2":
		global_position = global_position.move_toward(posicao_caixa, velocidade * delta)
		
		# Momento exato em que o cliente encosta no destino final do caixa
		if global_position == posicao_caixa:
			estado = "esperando"
			
			# Toca o som apenas se ele for o cliente da posição principal de atendimento
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
		
		# Ao encostar na porta de saída, o cliente é removido da cena
		if global_position.distance_to(posicao_porta) < 1.0:
			queue_free() 

func reagir_e_ir_embora(sucesso: bool) -> void:
	# Exibe o balão de fala com o feedback da compra para o jogador
	if balao_fala:
		balao_fala.visible = true
		
	if sucesso:
		balao_fala.text = "Muito obrigado!"
		if emoji_feliz: 
			emoji_feliz.visible = true 
	else:
		balao_fala.text = "Que absurdo!"
		if emoji_raiva: 
			emoji_raiva.visible = true 
		
	# Inicia a sequência de animação de saída
	estado = "saindo_passo1"
	animacao.play("walk_down")
