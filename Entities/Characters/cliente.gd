extends CharacterBody2D
class_name Cliente

signal chegou_no_caixa_vip
signal paciencia_esgotada(cliente: Cliente)

# ==========================================
# --- CONFIGURAÇÕES GERAIS ---
# ==========================================
@export_category("Configurações")
@export var velocidade: float = 100.0

@export_category("Paciência")
@export var paciencia_base: float = 35.0

var eh_vip: bool = false
var indice_na_fila: int = 0
var sendo_atendido: bool = false

var paciencia_maxima: float = 35.0
var paciencia_atual: float = 35.0
var _ja_reclamou_demora: bool = false
var _fala_tween: Tween
var _ultima_fala: String = ""

# ==========================================
# --- BANCO DE FALAS (ALTA VARIÂNCIA) ---
# ==========================================
const FALAS_CHEGADA_CAIXA: Array[String] = [
	"Olá! Vim buscar uns itens geométricos!",
	"Bom dia! Minha lista de formas está pronta!",
	"Opa! Já pode pegar meu pedido?",
	"Hoje quero caprichar nas compras!",
	"E aí, Kratos! Vamos ver essa agilidade!",
	"Trouxe uma listinha bem caprichada hoje.",
	"Adoro como os setores são organizados!",
	"Olá! Preciso de uns itens rapidinho.",
	"Oi! Pode anotar meu pedido, por favor?",
	"Espero que o estoque esteja cheinho!",
	"Dia de mercado! Pode mandar ver!",
	"Cheguei! Estou pronto para fazer o pedido.",
	"Que mercado estiloso! Vamos às compras!",
	"Oi! Vim testar seus conhecimentos de sólidos!"
]

const FALAS_IMPACIENTE: Array[String] = [
	"Nossa, essa fila não anda...",
	"Estou começando a ficar com pressa!",
	"Será que vai demorar muito ainda?",
	"Tic-tac... tenho compromisso logo!",
	"Alô? Tem alguém no caixa?",
	"Meu tempo está acabando aqui!",
	"Acho que vou criar raízes nessa fila...",
	"Que demora para anotar um pedido!",
	"Olhando o relógio pela décima vez...",
	"Puxa, hoje o atendimento está devagar..."
]

const FALAS_SUCESSO: Array[String] = [
	"Perfeito! Geometria nota 10!",
	"Valeu! Atendimento relâmpago!",
	"Tudo certinho! Voltarei com certeza!",
	"Caramba, você manda bem demais!",
	"Exatamente as formas que eu queria!",
	"Cinco estrelas para esse mercado!",
	"Muito obrigado! Excelente serviço!",
	"Nem uma forma fora do lugar. Top!",
	"Rápido e preciso! Até a próxima!",
	"Sensacional! Vou recomendar pros amigos!",
	"Era isso mesmo! Ganhou um cliente fiel!",
	"Aprovadíssimo! Bom trabalho!"
]

const FALAS_ERRO: Array[String] = [
	"Ué... não foi isso que eu pedi!",
	"Faltou atenção nas formas geométricas!",
	"Vish, veio tudo trocado na sacola...",
	"Acho que você confundiu os setores!",
	"Poxa, faltou conferir a prancheta!",
	"Não era bem essa forma que eu queria...",
	"Caramba, vou ter que conferir de novo...",
	"Hoje o atendimento deixou a desejar!",
	"Opa, trocou as bolas — literalmente!",
	"Ficou faltando coisa na minha lista..."
]

const FALAS_DESISTIU: Array[String] = [
	"Desisto! Muita demora!",
	"Não posso esperar o dia todo!",
	"Vou comprar no mercado da esquina!",
	"Cansei de esperar! Tchau!",
	"Sem condições, essa fila não anda!",
	"Perdi meu tempo aqui. Fui!",
	"Outro dia eu volto... talvez!",
	"Que atendimento lento! Estou indo!"
]

# ==========================================
# --- ESTADO E POSIÇÕES (WAYPOINTS) ---
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
@onready var balao_fala: Label = $BalaoFala
@onready var emoji_feliz: Node2D = $EmojiFeliz
@onready var emoji_raiva: Node2D = $EmojiRaiva
@onready var relogio_paciencia: ColorRect = get_node_or_null("RelogioPaciencia")


# ==========================================
# --- INICIALIZAÇÃO DO NPC ---
# ==========================================
func _ready() -> void:
	paciencia_maxima = paciencia_base * EconomyManager.obter_multiplicador_paciencia()
	paciencia_atual = paciencia_maxima

	if relogio_paciencia:
		relogio_paciencia.visible = false
		relogio_paciencia.pivot_offset = relogio_paciencia.size / 2.0
		if relogio_paciencia.material:
			relogio_paciencia.material = relogio_paciencia.material.duplicate()
			relogio_paciencia.material.set_shader_parameter("progresso", 0.0)

	# 1. Geração do visual único
	if sprite_corpo and texturas_corpo.size() > 0:
		sprite_corpo.texture = texturas_corpo.pick_random()
	if sprite_cabelo and texturas_cabelo.size() > 0:
		sprite_cabelo.texture = texturas_cabelo.pick_random()
	if sprite_roupa and texturas_roupa.size() > 0:
		sprite_roupa.texture = texturas_roupa.pick_random()

	# 2. Inicia o comportamento original
	global_position = posicao_porta
	animacao.play("walk_down")

	if balao_fala:
		balao_fala.visible = false
		balao_fala.z_index = 20


# ==========================================
# --- CONTROLE DE PACIÊNCIA ---
# ==========================================
func _process(delta: float) -> void:
	if eh_vip or sendo_atendido or estado != "esperando":
		if relogio_paciencia and relogio_paciencia.visible:
			relogio_paciencia.visible = false
		return

	if not CustomerManager.tutorial_concluido:
		if relogio_paciencia:
			relogio_paciencia.visible = false
		return

	var jogador = get_tree().get_first_node_in_group("jogador")
	if jogador and jogador.em_cutscene:
		return

	if relogio_paciencia and not relogio_paciencia.visible:
		relogio_paciencia.visible = true

	var taxa_dreno := _obter_taxa_dreno_por_fila()
	paciencia_atual = maxf(0.0, paciencia_atual - (delta * taxa_dreno))
	_atualizar_visual_paciencia()

	var proporcao := paciencia_atual / maxf(paciencia_maxima, 1.0)
	if not _ja_reclamou_demora and proporcao <= 0.35 and proporcao > 0.0:
		_ja_reclamou_demora = true
		falar_aleatorio(FALAS_IMPACIENTE, 2.4)

	if paciencia_atual <= 0.0:
		_desistir_por_impaciencia()

func _atualizar_visual_paciencia() -> void:
	if not relogio_paciencia or not (relogio_paciencia.material is ShaderMaterial):
		return

	# Começa em 0.0 (branco) e vai até 1.0 (todo vermelho) conforme a paciência acaba
	var progresso_vermelho := 1.0 - (paciencia_atual / maxf(paciencia_maxima, 1.0))
	relogio_paciencia.material.set_shader_parameter("progresso", clampf(progresso_vermelho, 0.0, 1.0))

func _obter_taxa_dreno_por_fila() -> float:
	match indice_na_fila:
		0: return 1.0
		1: return 0.80
		2: return 0.65
		_: return 0.55


# ==========================================
# --- LOOP FÍSICO E NAVEGAÇÃO ---
# ==========================================
func _physics_process(delta: float) -> void:
	# Sincronização dos Layered Sprites
	if sprite_corpo:
		if sprite_cabelo:
			sprite_cabelo.frame = sprite_corpo.frame
		if sprite_roupa:
			sprite_roupa.frame = sprite_corpo.frame

	# Rota de ida (em direção ao caixa)
	if estado == "entrando_passo1":
		global_position = global_position.move_toward(posicao_meio_ida, velocidade * delta)

		if global_position.distance_to(posicao_meio_ida) < 1.0:
			global_position = posicao_meio_ida
			estado = "entrando_passo2"
			animacao.play("walk_left")

	elif estado == "entrando_passo2":
		if animacao.current_animation != "walk_left":
			animacao.play("walk_left")

		global_position = global_position.move_toward(posicao_caixa, velocidade * delta)

		if global_position.distance_to(posicao_caixa) < 1.0:
			global_position = posicao_caixa
			estado = "esperando"
			animacao.play("idle_down")

			if indice_na_fila == 0:
				if som_chegou_caixa:
					som_chegou_caixa.play()
				if not eh_vip:
					falar_aleatorio(FALAS_CHEGADA_CAIXA, 2.5)

			if eh_vip:
				chegou_no_caixa_vip.emit()

	# Rota de volta (saindo do mercado)
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

		if global_position.distance_to(posicao_porta) < 1.0:
			queue_free()


# ==========================================
# --- EVENTOS DE FEEDBACK E ESTADOS ---
# ==========================================
func reagir_e_ir_embora(sucesso: bool) -> void:
	if relogio_paciencia:
		relogio_paciencia.visible = false
	if not eh_vip:
		falar_aleatorio(FALAS_SUCESSO if sucesso else FALAS_ERRO, 2.0)

	if sucesso:
		if emoji_feliz:
			emoji_feliz.visible = true
	else:
		if emoji_raiva:
			emoji_raiva.visible = true

	posicao_recuo_caixa = Vector2(global_position.x, 248.0)
	estado = "saindo_passo1"
	animacao.play("walk_down")

func configurar_como_vip() -> void:
	eh_vip = true
	velocidade = 75.0
	modulate = Color(1.0, 0.92, 0.55)
	scale = Vector2(1.12, 1.12)

func falar_sequencia_vip(falas: Array[String]) -> void:
	if not balao_fala:
		return

	balao_fala.visible = true
	for frase in falas:
		balao_fala.text = frase
		balao_fala.scale = Vector2.ZERO
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(balao_fala, "scale", Vector2.ONE, 0.25)
		await get_tree().create_timer(2.6).timeout

	balao_fala.visible = false

func definir_indice_fila(novo_indice: int) -> void:
	indice_na_fila = novo_indice

func definir_sendo_atendido(ativo: bool) -> void:
	sendo_atendido = ativo
	if ativo and relogio_paciencia:
		relogio_paciencia.visible = false

func falar_aleatorio(banco: Array[String], duracao: float = 2.4) -> void:
	if banco.is_empty() or not balao_fala:
		return

	var frase: String = banco.pick_random()
	if banco.size() > 1 and frase == _ultima_fala:
		frase = banco[(banco.find(frase) + 1) % banco.size()]
	_ultima_fala = frase

	if _fala_tween and _fala_tween.is_valid():
		_fala_tween.kill()

	balao_fala.text = frase
	balao_fala.visible = true
	balao_fala.scale = Vector2.ZERO

	_fala_tween = create_tween()
	_fala_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fala_tween.tween_property(balao_fala, "scale", Vector2.ONE, 0.25)
	_fala_tween.tween_interval(duracao)
	_fala_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_fala_tween.tween_property(balao_fala, "scale", Vector2.ZERO, 0.2)
	_fala_tween.tween_callback(func(): balao_fala.visible = false)

func _desistir_por_impaciencia() -> void:
	if estado.begins_with("saindo"):
		return

	if relogio_paciencia:
		relogio_paciencia.visible = false
	if emoji_raiva:
		emoji_raiva.visible = true

	modulate = Color(1.0, 0.65, 0.65)
	falar_aleatorio(FALAS_DESISTIU, 2.2)

	posicao_recuo_caixa = Vector2(global_position.x, 248.0)
	estado = "saindo_passo1"
	animacao.play("walk_down")
	paciencia_esgotada.emit(self)
