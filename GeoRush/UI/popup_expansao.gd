extends CanvasLayer
class_name PopupExpansao

@export_category("Referências de Nodes")

# --- Áudio ---
@onready var som_expansao: AudioStreamPlayer = $SomExpansao
@onready var som_clique: AudioStreamPlayer = $SomClique 

# --- Interface (Textos) ---
@onready var label_titulo: Label = $PanelContainer/VBoxContainer/Titulo
@onready var label_subtitulo: Label = $PanelContainer/VBoxContainer/Subtitulo


func _ready() -> void:
	if som_expansao:
		som_expansao.play()
		
	# Configura dinamicamente os textos da interface baseando-se 
	# no nível atual do mercado, antes de aplicar a nova expansão.
	if label_titulo and label_subtitulo:
		if EconomyManager.nivel_expansao == 0:
			label_titulo.text = "NOVO SETOR DESBLOQUEADO: BEBIDAS E CONSERVAS!"
			label_subtitulo.text = "Atenção ao novo formato: Cilindro!"
			
		elif EconomyManager.nivel_expansao == 1:
			label_titulo.text = "NOVO SETOR DESBLOQUEADO: LATICÍNIOS E MATINAIS!"
			label_subtitulo.text = "Atenção ao novo formato: Paralelepípedo!"
		
	# Interrompe a execução principal do jogo para focar a atenção do jogador no aviso
	get_tree().paused = true

func _on_button_continuar_pressed() -> void:
	if som_clique:
		som_clique.play()
		# Aguarda o áudio terminar para garantir uma transição suave
		await som_clique.finished 
	
	# Efetiva o aumento do nível do mercado
	EconomyManager.nivel_expansao += 1
	
	# ==========================================
	# --- Desbloqueio 1: Setor de Cilindros ---
	# ==========================================
	if EconomyManager.nivel_expansao == 1:
		CustomerManager.desbloquear_forma(ProductData.ShapeType.CILINDRO)
		EconomyManager.meta_expansao += 5 # Aumenta a dificuldade para alcançar o próximo nível
		
		# Torna o setor físico de cilindros visível e reativa o seu processamento de física/lógica
		var setor_cilindros = get_tree().get_first_node_in_group("setor_cilindros")
		if setor_cilindros:
			setor_cilindros.visible = true
			setor_cilindros.process_mode = Node.PROCESS_MODE_INHERIT 
			
	# ==========================================
	# --- Desbloqueio 2: Setor de Paralelepípedos ---
	# ==========================================
	elif EconomyManager.nivel_expansao == 2:
		CustomerManager.desbloquear_forma(ProductData.ShapeType.PARALELEPIPEDO)
		EconomyManager.meta_expansao += 10 
		
		# Torna o setor físico de paralelepípedos visível e reativa o seu processamento de física/lógica
		var setor_paralelepipedos = get_tree().get_first_node_in_group("setor_paralelepipedos")
		if setor_paralelepipedos:
			setor_paralelepipedos.visible = true
			setor_paralelepipedos.process_mode = Node.PROCESS_MODE_INHERIT 

	# Retoma o tempo do jogo e remove o pop-up da memória
	get_tree().paused = false
	queue_free()
