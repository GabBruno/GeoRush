extends CharacterBody2D
class_name Cliente

signal chegou_no_caixa_vip
signal paciencia_esgotada(cliente: Cliente)

# ==========================================
# --- CONFIGURAÇÕES GERAIS ---
# ==========================================
@export_category("Configurações")
@export var velocidade: float = 100.0
@export var y_corredor_saida: float = 248 # Acima da fila (224) e longe das gôndolas (248+)
@export var x_corredor_saida: float = 346.0 # Faixa paralela à esquerda da entrada (372)

@export_category("Paciência")
@export var paciencia_base: float = 32.0

var eh_vip: bool = false
var indice_na_fila: int = 0
var sendo_atendido: bool = false

var paciencia_maxima: float = 32.0
var paciencia_atual: float = 32.0
var _ja_reclamou_demora: bool = false
var _fala_tween: Tween
var _ultima_fala: String = ""

var _em_dialogo_vip: bool = false
var _pular_fala_vip: bool = false

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
var posicao_recuo_caixa: Vector2 = Vector2(145, 184)
var posicao_corredor_saida: Vector2 = Vector2(346, 184)
var posicao_frente_porta: Vector2 = Vector2(346, 88)

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

@onready var sprite_corpo: Sprite2D = $SpriteCorpo
@onready var sprite_cabelo: Sprite2D = $SpriteCabelo
@onready var sprite_roupa: Sprite2D = $SpriteRoupa
@onready var animacao: AnimationPlayer = $Animation

@onready var balao_fala: Label = $BalaoFala
@onready var emoji_feliz: Node2D = $EmojiFeliz
@onready var emoji_raiva: Node2D = $EmojiRaiva
@onready var relogio_paciencia: ColorRect = get_node_or_null("RelogioPaciencia") as ColorRect


# ==========================================
# --- INICIALIZAÇÃO DO NPC ---
# ==========================================
func _ready() -> void:
	add_to_group("clientes")

	posicao_corredor_saida = Vector2(x_corredor_saida, y_corredor_saida)
	posicao_frente_porta = Vector2(x_corredor_saida, posicao_porta.y)

	paciencia_maxima = paciencia_base * EconomyManager.obter_multiplicador_paciencia()
	paciencia_atual = paciencia_maxima

	if relogio_paciencia:
		relogio_paciencia.visible = false
		relogio_paciencia.pivot_offset = relogio_paciencia.size / 2.0
		if relogio_paciencia.material:
			relogio_paciencia.material = relogio_paciencia.material.duplicate()
			relogio_paciencia.material.set_shader_parameter("progresso", 0.0)

	if sprite_corpo and texturas_corpo.size() > 0:
		sprite_corpo.texture = texturas_corpo.pick_random()
	if sprite_cabelo and texturas_cabelo.size() > 0:
		sprite_cabelo.texture = texturas_cabelo.pick_random()
	if sprite_roupa and texturas_roupa.size() > 0:
		sprite_roupa.texture = texturas_roupa.pick_random()

	global_position = posicao_porta
	animacao.play("walk_down")

	if balao_fala:
		balao_fala.visible = false
		balao_fala.z_index = 40
		_estilizar_balao_comum()


func _estilizar_balao_comum() -> void:
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.08, 0.10, 0.14, 0.85)
	fundo.border_color = Color(1.0, 1.0, 1.0, 0.35)
	fundo.set_border_width_all(1)
	fundo.set_corner_radius_all(4)
	fundo.content_margin_left = 6
	fundo.content_margin_right = 6
	fundo.content_margin_top = 3
	fundo.content_margin_bottom = 3
	balao_fala.add_theme_stylebox_override("normal", fundo)
	balao_fala.add_theme_color_override("font_color", Color.WHITE)
	balao_fala.add_theme_color_override("font_outline_color", Color.BLACK)
	balao_fala.add_theme_constant_override("outline_size", 2)


func _input(event: InputEvent) -> void:
	if not _em_dialogo_vip:
		return
	if event.is_action_pressed("interact_e") or event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		_pular_fala_vip = true
		get_viewport().set_input_as_handled()


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

	var taxa_dreno: float = _obter_taxa_dreno_por_fila()
	paciencia_atual = maxf(0.0, paciencia_atual - (delta * taxa_dreno))
	_atualizar_visual_paciencia()

	var proporcao: float = paciencia_atual / maxf(paciencia_maxima, 1.0)
	if not _ja_reclamou_demora and proporcao <= 0.35 and proporcao > 0.0:
		_ja_reclamou_demora = true
		falar_aleatorio(FALAS_IMPACIENTE, 2.4)

	if paciencia_atual <= 0.0:
		_desistir_por_impaciencia()


func _atualizar_visual_paciencia() -> void:
	if not relogio_paciencia or not (relogio_paciencia.material is ShaderMaterial):
		return

	var progresso_vermelho: float = 1.0 - (paciencia_atual / maxf(paciencia_maxima, 1.0))
	relogio_paciencia.material.set_shader_parameter("progresso", clampf(progresso_vermelho, 0.0, 1.0))


func _obter_taxa_dreno_por_fila() -> float:
	match indice_na_fila:
		0: return 1.0
		1: return 0.85
		2: return 0.70
		_: return 0.60


# ==========================================
# --- PREVENÇÃO DE COLISÃO / ATRAVESSAMENTO ---
# ==========================================
func _tem_cliente_bloqueando(destino: Vector2, estou_saindo: bool) -> bool:
	var vetor_mov: Vector2 = destino - global_position
	if vetor_mov.length_squared() < 1.0:
		return false

	var dir: Vector2 = vetor_mov.normalized()
	var distancia_segura: float = 40.0 if estou_saindo else 46.0

	for outro in get_tree().get_nodes_in_group("clientes"):
		if outro == self or not is_instance_valid(outro):
			continue
		var c: Cliente = outro as Cliente
		if not c:
			continue

		if estou_saindo and not c.estado.begins_with("saindo"):
			continue

		var rel: Vector2 = c.global_position - global_position
		var dist: float = rel.length()
		if dist < distancia_segura and dist > 0.1:
			var alinhamento: float = rel.normalized().dot(dir)
			if alinhamento > 0.45:
				return true

	return false


func _mover_com_seguranca(destino: Vector2, anim_andar: String, delta: float, estou_saindo: bool) -> bool:
	if _tem_cliente_bloqueando(destino, estou_saindo):
		if animacao.current_animation != "idle_down":
			animacao.play("idle_down")
		return false

	if animacao.current_animation != anim_andar:
		animacao.play(anim_andar)

	global_position = global_position.move_toward(destino, velocidade * delta)
	if global_position.distance_to(destino) < 1.0:
		global_position = destino
		return true
	return false


# ==========================================
# --- LOOP FÍSICO E NAVEGAÇÃO ---
# ==========================================
func _physics_process(delta: float) -> void:
	if sprite_corpo:
		if sprite_cabelo:
			sprite_cabelo.frame = sprite_corpo.frame
		if sprite_roupa:
			sprite_roupa.frame = sprite_corpo.frame

	# Rota de ida (entra pela direita e vai para a fila em Y = 224)
	if estado == "entrando_passo1":
		if _mover_com_seguranca(posicao_meio_ida, "walk_down", delta, false):
			estado = "entrando_passo2"

	elif estado == "entrando_passo2":
		if _mover_com_seguranca(posicao_caixa, "walk_left", delta, false):
			estado = "esperando"
			animacao.play("idle_down")

			if indice_na_fila == 0:
				if som_chegou_caixa:
					som_chegou_caixa.play()
				if not eh_vip:
					falar_aleatorio(FALAS_CHEGADA_CAIXA, 2.5)

			if eh_vip:
				chegou_no_caixa_vip.emit()

	# Rota de volta (sobe para Y = 184, vai para a direita e segue reto até a porta)
	elif estado == "saindo_passo1":
		var anim_recuo: String = "walk_up" if posicao_recuo_caixa.y < global_position.y else "walk_down"
		if _mover_com_seguranca(posicao_recuo_caixa, anim_recuo, delta, true):
			estado = "saindo_passo2"

	elif estado == "saindo_passo2":
		if _mover_com_seguranca(posicao_corredor_saida, "walk_right", delta, true):
			estado = "saindo_passo3"

	elif estado == "saindo_passo3":
		if _mover_com_seguranca(posicao_frente_porta, "walk_up", delta, true):
			queue_free()


# ==========================================
# --- EVENTOS DE FEEDBACK E ESTADOS ---
# ==========================================
func _iniciar_rota_saida() -> void:
	posicao_recuo_caixa = Vector2(global_position.x, y_corredor_saida)
	posicao_corredor_saida = Vector2(x_corredor_saida, y_corredor_saida)
	posicao_frente_porta = Vector2(x_corredor_saida, posicao_porta.y)
	estado = "saindo_passo1"
	animacao.play("walk_up" if y_corredor_saida < global_position.y else "walk_down")


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

	_iniciar_rota_saida()


func configurar_como_vip() -> void:
	eh_vip = true
	velocidade = 75.0
	modulate = Color(1.0, 0.92, 0.55)
	scale = Vector2(1.12, 1.12)


# ==========================================
# --- CAIXA DE DIÁLOGO DE ALTO CONTRASTE (BOSS VIP) ---
# ==========================================
func falar_sequencia_vip(falas: Array[String]) -> void:
	if balao_fala:
		balao_fala.visible = false

	var camada := CanvasLayer.new()
	camada.layer = 95
	get_tree().current_scene.add_child(camada)

	var tamanho_tela: Vector2 = get_viewport().get_visible_rect().size
	var largura: float = minf(560.0, tamanho_tela.x - 64.0)
	var largura_interna: float = largura - 36.0

	var painel := PanelContainer.new()
	painel.visible = false
	painel.custom_minimum_size.x = largura
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.06, 0.08, 0.13, 0.95)
	estilo.border_color = Color(1.0, 0.82, 0.25, 1.0)
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(8)
	estilo.content_margin_left = 18
	estilo.content_margin_right = 18
	estilo.content_margin_top = 12
	estilo.content_margin_bottom = 12
	painel.add_theme_stylebox_override("panel", estilo)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	painel.add_child(vbox)

	var titulo := Label.new()
	titulo.text = "⭐ CRÍTICO SUPREMO ⭐"
	titulo.custom_minimum_size.x = largura_interna
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 16)
	titulo.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30, 1.0))
	titulo.add_theme_color_override("font_outline_color", Color.BLACK)
	titulo.add_theme_constant_override("outline_size", 4)
	vbox.add_child(titulo)

	var label_fala := Label.new()
	label_fala.custom_minimum_size.x = largura_interna
	label_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_fala.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_fala.add_theme_font_size_override("font_size", 18)
	label_fala.add_theme_color_override("font_color", Color.WHITE)
	label_fala.add_theme_color_override("font_outline_color", Color.BLACK)
	label_fala.add_theme_constant_override("outline_size", 3)
	vbox.add_child(label_fala)

	var dica := Label.new()
	dica.text = "Aperte [E] ou [Espaço] para avançar"
	dica.custom_minimum_size.x = largura_interna
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dica.add_theme_font_size_override("font_size", 11)
	dica.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88, 0.85))
	vbox.add_child(dica)

	if balao_fala:
		var fonte: Font = balao_fala.get_theme_font("font")
		if fonte:
			titulo.add_theme_font_override("font", fonte)
			label_fala.add_theme_font_override("font", fonte)
			dica.add_theme_font_override("font", fonte)

	camada.add_child(painel)
	_em_dialogo_vip = true

	for frase in falas:
		label_fala.text = frase
		painel.size = Vector2(largura, 0.0)
		painel.reset_size()
		await get_tree().process_frame
		painel.reset_size()

		painel.position = Vector2(
			(tamanho_tela.x - painel.size.x) * 0.5,
			tamanho_tela.y - painel.size.y - 34.0
		)
		painel.pivot_offset = painel.size / 2.0
		painel.visible = true
		painel.scale = Vector2(0.92, 0.92)
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(painel, "scale", Vector2.ONE, 0.22)

		_pular_fala_vip = false
		await get_tree().create_timer(0.35).timeout
		_pular_fala_vip = false

		var decorrido: float = 0.0
		while decorrido < 3.6 and not _pular_fala_vip:
			await get_tree().create_timer(0.05).timeout
			decorrido += 0.05

	_em_dialogo_vip = false
	camada.queue_free()


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
	_fala_tween.tween_callback(func() -> void: balao_fala.visible = false)


func _desistir_por_impaciencia() -> void:
	if estado.begins_with("saindo"):
		return

	if relogio_paciencia:
		relogio_paciencia.visible = false
	if emoji_raiva:
		emoji_raiva.visible = true

	modulate = Color(1.0, 0.65, 0.65)
	falar_aleatorio(FALAS_DESISTIU, 2.2)

	_iniciar_rota_saida()
	paciencia_esgotada.emit(self)
