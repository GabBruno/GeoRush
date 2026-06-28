extends CanvasLayer
class_name MenuPausa

@export_category("Referências de Nodes")
@onready var painel_pausa: Control = $PainelPausa
@onready var som_clique: AudioStreamPlayer = $PainelPausa/SomClique

func _ready() -> void:
	# Garante que o menu de pausa comece sempre oculto ao carregar a fase
	painel_pausa.visible = false
	
	# Define o modo de processamento para 'Always' (Sempre), garantindo que
	# este menu e o áudio continuem rodando mesmo quando a SceneTree for pausada.
	self.process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	# Escuta a ação configurada para abrir e fechar o menu
	if event.is_action_pressed("menu"):
		alternar_pausa()

# ==========================================
# --- Lógica Principal ---
# ==========================================

func alternar_pausa() -> void:
	"""
	Alterna o estado de execução da árvore principal (SceneTree)
	e exibe ou oculta a interface do menu de pausa.
	"""
	# Inverte o estado atual (se estiver pausado, despausa; se não, pausa)
	var novo_estado_pausa = not get_tree().paused
	
	get_tree().paused = novo_estado_pausa
	painel_pausa.visible = novo_estado_pausa

# ==========================================
# --- Ações dos Botões ---
# ==========================================

func _on_botao_continuar_pressed() -> void:
	if som_clique:
		som_clique.play()
		
	# Reutiliza a função principal para remover a pausa e esconder a tela
	alternar_pausa()

func _on_botao_menu_principal_pressed() -> void:
	if som_clique:
		som_clique.play()
		await som_clique.finished
		
	# Remove a pausa antes de trocar de cena para evitar travamentos no novo menu
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/menu_principal.tscn")

func _on_botao_sair_pressed() -> void:
	if som_clique:
		som_clique.play()
		await som_clique.finished
		
	get_tree().quit()
